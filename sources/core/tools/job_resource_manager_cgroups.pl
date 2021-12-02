# The job_resource_manager_cgroups script is a perl script that oar server
# deploys on nodes to manage cpusets, users, job keys, ...
#
# In this script some cgroup Linux features are incorporated:
#     - [cpuset]  Restrict the job processes to use only the reserved cores;
#                 And restrict the allowed memory nodes to those directly
#                 attached to the cores (see the command "numactl -H")
#     - [cpu]     Nothing is done with this cgroup feature. By default each
#                 cgroup have cpu.shares=1024 (no priority)
#     - [cpuacct] Allow to have an accounting of the cpu times used by the
#                 job processes
#     - [freezer] Permit to suspend or resume the job processes.
#                 This is used by the suspend/resume of OAR (oarhold/oarresume)
#     - [memory]  Permit to restrict the amount of RAM that can be used by the
#                 job processes (ratio of job_nb_cores / total_nb_cores).
#                 This is useful for OOM problems (kill only tasks inside the
#                 cgroup where OOM occurs)
#                 DISABLED by default: there are maybe some performance issues
#                 (need to do some benchmarks)
#                 You can ENABLE this feature by putting 'my $Enable_mem_cg =
#                 "YES";' in the following code
#     - [devices] Allow or deny the access of devices for each job processes
#                 (By default every devices are allowed)
#                 You can ENABLE this feature to manage NVIDIA GPUs by putting
#                 'my $Enable_devices_cg = "YES";' in the following code.
#                 Also there must be a resource property named 'gpudevice'
#                 configured. This property must contain the GPU id which is
#                 allowed to be used (id on the compute node).
#     - [blkio]   Put an IO share corresponding to the ratio between reserved
#                 cores and the number of the node (this is disabled by default
#                 due to bad behaviour seen. More tests have to be done)
#                 There are some interesting accounting data available.
#                 You can ENABLE this feature by putting 'my $Enable_blkio_cg =
#                 "YES";' in the following code
#     - [net_cls] Tag each network packet from processes of this job with the
#                 class id = $OAR_JOB_ID.
#                 You can ENABLE this feature by putting 'my $Enable_net_cls_cg
#                 = "YES";' in the following code.
#     - [perf_event] You can ENABLE this feature by putting
#                 'my $Enable_perf_event_cg = "YES";' in the following code.
#     - [max_uptime] You can set '$max_uptime = <seconds>' to automaticaly
#                 reboot the node at the end of the last job past this uptime
#
# Usage:
# This script is deployed from the server and executed as oar on the nodes
# ARGV[0] can have two different values:
#     - "init": then this script must create the right cpuset and assign
#                 corresponding cpus
#     - "clean": then this script must kill all processes in the cpuset and
#                 clean the cpuset structure

# TAKTUK_HOSTNAME environment variable must be defined and must be a key
# of the transfered hash table ($Cpuset variable).
use strict;
use warnings;
use Fcntl ':flock';

sub exit_myself($$);
sub print_log($$);
sub system_with_log($);

###############################################################################
# Script configuration start
###############################################################################
# Put YES if you want to use the memory cgroup
my $Enable_mem_cg = "NO";
# Put YES if you want to use the device cgroup (supports nvidia devices only for now)
my $Enable_devices_cg = "NO";
# Put YES if you want to use the blkio cgroup
my $Enable_blkio_cg = "NO";
# Put YES if you want to use the net_cls cgroup
my $Enable_net_cls_cg = "NO";
# Put YES if you want to use the perf_event cgroup
my $Enable_perf_event_cg = "NO";
# Set which memory nodes should be given to any job in the cpuset cgroup
# "all": all the memory nodes, even if the cpu which the memory node is attached to is not in the job
# "cpu": only the memory nodes associated to cpus which are in the job
my $Cpuset_cg_mem_nodes = "cpu";
# Where the OS mounts by itself the cgroups
my $OS_cgroups_path = "/sys/fs/cgroup";
# Directories where files of the job user will be deleted after the end of the
# job if there is not other running job of the same user on the node
my @Tmp_dir_to_clear = ('/tmp/.','/dev/shm/.','/var/tmp/.');
# SSD trim command path
my $Fstrim_cmd = "/sbin/fstrim";
# Groups location for OAR, if not mounted by the system
my $Cgroup_mount_point = "/dev/oar_cgroups";
# Directory where the cgroup mount points are linked to. Useful to have each
# cgroups in the same place with the same hierarchy.
my $Cgroup_directory_collection_links = "/dev/oar_cgroups_links";
# Max uptime for automatic reboot (disabled if 0)
my $max_uptime = 259200;
###############################################################################
# Script configuration end
###############################################################################

my $Old_umask = sprintf("%lo",umask());
umask(oct("022"));

my $Log_level;
my $Cpuset_lock_file = "$ENV{HOME}/cpuset.lock.";
my $Cpuset;
# Retrieve parameters from STDIN in the "Cpuset" structure which looks like:
# $Cpuset = {
#               job_id => id of the corresponding job,
#               name => "cpuset name",
#               cpuset_path => "relative path in the cpuset FS",
#               nodes => hostname => [array with the content of the database cpuset field],
#               ssh_keys => {
#                               public => {
#                                           file_name => "~oar/.ssh/authorized_keys",
#                                           key => "public key content",
#                                         },
#                               private => {
#                                           file_name => "directory where to store the private key",
#                                           key => "private key content",
#                                          },
#                           },
#               oar_tmp_directory => "path to the temp directory",
#               user => "user name",
#               job_user => "job user",
#               types => {hashtable with job types as keys},
#               resources => [ {property_name => value}, ],
#               node_file_db_fields => NODE_FILE_DB_FIELD,
#               node_file_db_fields_distinct_values => NODE_FILE_DB_FIELD_DISTINCT_VALUES,
#               array_id => job array id,
#               array_index => job index in the array,
#               stdout_file => stdout file name,
#               stderr_file => stderr file name,
#               launching_directory => launching directory,
#               job_name => job name,
#               walltime_seconds => job walltime in seconds,
#               walltime => job walltime,
#               project => job project name,
#               log_level => debug level number,
#           }

# Compute uptime
my $uptime = 0;
open UPTIME, "/proc/uptime" or die "Couldn't open /proc/uptime!";
($uptime, my $junk)=split(/\./, <UPTIME>);
close UPTIME;

my $tmp = "";
while (<STDIN>){
    $tmp .= $_;
}
$Cpuset = eval($tmp);

if (!defined($Cpuset->{log_level})){
    exit_myself(2,"Bad SSH hashtable transfered");
}
$Log_level = $Cpuset->{log_level};
my $Cpuset_path_job;
my @Cpuset_cpus;
my $Oardocker_node_cg_path = "";
# Get the data structure only for this node
if (defined($Cpuset->{cpuset_path})){
    if (-e $OS_cgroups_path.'/cpuset/oardocker') {
        # We are in oardocker, set the oardocker_node_path to /oardocker/<node_name>
        $Oardocker_node_cg_path = "/oardocker/$ENV{TAKTUK_HOSTNAME}";
        print_log(3,"Oardocker_node_cg_path=$Oardocker_node_cg_path");
    }
    $Cpuset_path_job = $Cpuset->{cpuset_path}.'/'.$Cpuset->{name};
    foreach my $l (@{$Cpuset->{nodes}->{$ENV{TAKTUK_HOSTNAME}}}){
        push(@Cpuset_cpus, split(/[,\s]+/, $l));
    }
}

print_log(3,"$ARGV[0]");
if ($ARGV[0] eq "init"){
###############################################################################
# Node initialization: run on all the nodes of the job before the job starts
###############################################################################
    # Initialize cpuset for this node
    # First, create the tmp oar directory
    if (!(((-d $Cpuset->{oar_tmp_directory}) and (-O $Cpuset->{oar_tmp_directory})) or (mkdir($Cpuset->{oar_tmp_directory})))){
        exit_myself(13,"Directory $Cpuset->{oar_tmp_directory} does not exist and cannot be created");
    }

    if (defined($Cpuset_path_job)){
        if (open(LOCKFILE,"> $Cpuset->{oar_tmp_directory}/job_manager_lock_file")){
            flock(LOCKFILE,LOCK_EX) or exit_myself(17,"flock failed: $!");
            if (!(-r $Cgroup_directory_collection_links.'/cpuset/tasks')){
                my @cgroup_list = ("cpuset","cpu","cpuacct","devices","freezer");
                push(@cgroup_list, "memory") if ($Enable_mem_cg eq "YES");
                push(@cgroup_list, "blkio") if ($Enable_blkio_cg eq "YES");
                push(@cgroup_list, "net_cls") if ($Enable_net_cls_cg eq "YES");
                push(@cgroup_list, "perf_event") if ($Enable_perf_event_cg eq "YES");
                if (!(-r $OS_cgroups_path.'/cpuset/tasks')){
                    system_with_log('set -e
                                     oardodo mkdir -p '.$Cgroup_mount_point.'
                                     oardodo mount -t cgroup -o '.join(',',@cgroup_list).' none '.$Cgroup_mount_point.'
                                     oardodo rm -f /dev/cpuset
                                     oardodo ln -s '.$Cgroup_mount_point.' /dev/cpuset
                                     oardodo mkdir -p '.$Cgroup_directory_collection_links.'
                                     for cg in '.join(' ',@cgroup_list).'; do
                                         oardodo ln -s '.$Cgroup_mount_point.' '.$Cgroup_directory_collection_links.'/$cg
                                     done')
                    and exit_myself(4,"Failed to mount cgroup pseudo filesystem");
                }else{
                    # Cgroups already mounted by the OS
                    system_with_log('set -e
                                     oardodo rm -f /dev/cpuset
                                     oardodo ln -s '.$OS_cgroups_path.'/cpuset'.$Oardocker_node_cg_path.' /dev/cpuset
                                     oardodo mkdir -p '.$Cgroup_directory_collection_links.'
                                     for cg in '.join(' ',@cgroup_list).'; do
                                         oardodo ln -s '.$OS_cgroups_path.'/$cg'.$Oardocker_node_cg_path.' '.$Cgroup_directory_collection_links.'/$cg
                                     done')
                    and exit_myself(4,"Failed to link existing OS cgroup pseudo filesystem");
                }
            }
            if (!(-d $Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path})){
                # Populate default oar cgroup
                system_with_log('set -e
                                 for d in '.$Cgroup_directory_collection_links.'/*; do
                                     oardodo mkdir -p $d/'.$Cpuset->{cpuset_path}.'
                                     oardodo chown -R oar $d/'.$Cpuset->{cpuset_path}.'
                                     /bin/echo 0 | cat > $d/'.$Cpuset->{cpuset_path}.'/notify_on_release
                                 done
                                 /bin/echo 0 | cat > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.cpu_exclusive
                                 cat '.$Cgroup_directory_collection_links.'/cpuset/cpuset.mems > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.mems
                                 cat '.$Cgroup_directory_collection_links.'/cpuset/cpuset.cpus > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.cpus')
                and exit_myself(4,"Failed to create cgroup $Cpuset->{cpuset_path}");
                if ($Enable_blkio_cg eq "YES") {
                    system_with_log('/bin/echo 1000 | cat > '.$Cgroup_directory_collection_links.'/blkio/'.$Cpuset->{cpuset_path}.'/blkio.weight')
                    and exit_myself(4,"Failed to create cgroup $Cpuset->{cpuset_path}");
                }
            }
            flock(LOCKFILE,LOCK_UN) or exit_myself(17,"flock failed: $!");
            close(LOCKFILE);
        }else{
            exit_myself(16,"Failed to open or create $Cpuset->{oar_tmp_directory}/job_manager_lock_file");
        }

        # Be careful with the physical_package_id. Is it corresponding to the memory bank?
        # Create job cgroup
        # Locking around the creation of the cpuset for that user, to prevent race condition during the dirty-user-based cleanup
        if (open(LOCK,">", $Cpuset_lock_file.$Cpuset->{user})){
            flock(LOCK,LOCK_EX) or die "flock failed: $!\n";
            # @Cpuset_cpus is an array of string containing either "1" or "1,17,33,49" if multiple logicial cpus / threads
            # are set in the cpuset field of the OAR DB (but not interval, e.g. '1-3').
            # The cpuset.cpus special file can be set using an unorder, redondant list of comma separated values, possibly
            # also including intervals (e.g. the thread siblings list could be '1-3').
            # No need to sort or transform intervals, e.g. "1,5-8,2,6" is ok. Retrieving the actual content of the file
            # after setting it will give "1-2,5-8"
            my $job_cpuset_cpus_cmd = '/bin/echo '.join(",",@Cpuset_cpus).' | cat > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/cpuset.cpus';
            if (exists($Cpuset->{'compute_thread_siblings'}) and lc($Cpuset->{'compute_thread_siblings'}) eq "yes") {
                # If COMPUTE_THREAD_SIBLINGS="yes" in oar.conf, that means that the OAR DB has not info about the
                # HT threads siblings, so we have compute it here.
                $job_cpuset_cpus_cmd = 'for i in '.join(" ", map {s/,/ /gr} @Cpuset_cpus).'; do cat /sys/devices/system/cpu/cpu$i/topology/thread_siblings_list; done | paste -sd, - > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/cpuset.cpus';
            }
            system_with_log('set -e
                             for d in '.$Cgroup_directory_collection_links.'/*; do
                                 oardodo mkdir -p $d/'.$Cpuset_path_job.'
                                 oardodo chown -R oar $d/'.$Cpuset_path_job.'
                                 /bin/echo 0 | cat > $d/'.$Cpuset_path_job.'/notify_on_release
                             done
                             /bin/echo 0 | cat > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/cpuset.cpu_exclusive
                             '.$job_cpuset_cpus_cmd)
            and exit_myself(5,"Failed to create and feed the cpuset cpus $Cpuset_path_job");
            if ($Cpuset_cg_mem_nodes eq "all"){
                system_with_log('cat '.$Cgroup_directory_collection_links.'/cpuset/cpuset.mems > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/cpuset.mems')
                and exit_myself(5,"Failed to feed the mem nodes to cpuset $Cpuset_path_job");
            } else {
                system_with_log('set -e
                        for d in '.$Cgroup_directory_collection_links.'/*; do
                            MEM=
                            for c in '."@Cpuset_cpus".'; do
                                for n in /sys/devices/system/node/node* ; do
                                    if [ -r "$n/cpu$c" ]; then
                                        MEM=$(basename $n | sed s/node//g),$MEM
                                    fi
                                done
                            done
                        done
                        echo $MEM > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/cpuset.mems')
                and exit_myself(5,"Failed to feed the mem nodes to cpuset $Cpuset_path_job");
            }
            flock(LOCK,LOCK_UN) or die "flock failed: $!\n";
            close(LOCK);
        } else {
            exit_myself(16,"[cpuset_manager] Error opening $Cpuset_lock_file");
        }

        # Compute the actual job cpus (@Cpuset_cpus may not have the HT included, depending on the OAR resources definiton)
        my @job_cpus;
        if (open(CPUS, $Cgroup_directory_collection_links."/cpuset/".$Cpuset_path_job."/cpuset.cpus")){
            my $str = <CPUS>;
            chop($str);
            $str =~ s/\-/\.\./g;
            @job_cpus = eval($str);
            close(CPUS);
        }else{
            exit_myself(5,"Failed to retrieve the cpu list of the job $Cgroup_directory_collection_links/cpuset/$Cpuset_path_job/cpuset.cpus");
        }
        # Get all the cpus of the node
        my @node_cpus;
        if (open(CPUS, $Cgroup_directory_collection_links."/cpuset/cpuset.cpus")){
            my $str = <CPUS>;
            chop($str);
            $str =~ s/\-/\.\./g;
            @node_cpus = eval($str);
            close(CPUS);
        }else{
            exit_myself(5,"Failed to retrieve the cpu list of the node $Cgroup_directory_collection_links/cpuset/cpuset.cpus");
        }

        # Tag network packets from processes of this job
        if ($Enable_net_cls_cg eq "YES") {
            system_with_log( '/bin/echo '.$Cpuset->{job_id}.' | cat > '.$Cgroup_directory_collection_links.'/net_cls/'.$Cpuset_path_job.'/net_cls.classid')
            and exit_myself(5,"Failed to tag network packets of the cgroup $Cpuset_path_job");
        }
        # Put a share for IO disk corresponding of the ratio between the number
        # of cpus of this cgroup and the number of cpus of the node
        if ($Enable_blkio_cg eq "YES") {
            my $IO_ratio = sprintf("%.0f",(($#job_cpus + 1) / ($#node_cpus + 1) * 1000)) ;
            # TODO: Need to do more tests to validate so remove this feature
            #       Some values are not working when echoing, force value to 1000 for now.
            $IO_ratio = 1000;
            system_with_log( '/bin/echo '.$IO_ratio.' | cat > '.$Cgroup_directory_collection_links.'/blkio/'.$Cpuset_path_job.'/blkio.weight')
            and exit_myself(5,"Failed to set the blkio.weight to $IO_ratio");
        }
        # Manage GPU devices
        if ($Enable_devices_cg eq "YES"){
            # Nvidia GPU
            my @devices_deny = ();
            opendir(my($dh), "/dev") or exit_myself(5,"Failed to open /dev directory for Enable_devices_cg feature");
            my @files = grep { /nvidia/ } readdir($dh);
            foreach (@files){
                if ($_ =~ /nvidia(\d+)/){
                    push (@devices_deny, $1);
                }
            }
            closedir($dh);
            if ($#devices_deny > -1){
                # now remove from denied devices our reserved devices
                foreach my $r (@{$Cpuset->{'resources'}}){
                    if (($r->{type} eq "default") and
                        ($r->{network_address} eq "$ENV{TAKTUK_HOSTNAME}") and
                        ($r->{'gpudevice'} ne '')
                       ){
                        @devices_deny = grep { $_ !=  $r->{'gpudevice'} } @devices_deny;
                    }
                }
                print_log(3,"Deny NVIDIA GPUs: @devices_deny");
                my $devices_cgroup = $Cgroup_directory_collection_links."/devices/".$Cpuset_path_job."/devices.deny";
                foreach my $dev (@devices_deny){
                    system_with_log("oardodo /bin/echo 'c 195:$dev rwm' > $devices_cgroup")
                    and exit_myself(5,"Failed to set the devices.deny to c 195:$dev rwm");
                }
            }
            # Other GPU
            if (opendir($dh, "/dev/dri")) {
                @devices_deny = ();
                @files = grep { /renderD/ } readdir($dh);
                foreach (@files){
                    if ($_ =~ /renderD(\d+)/){
                        push (@devices_deny, $1-128);
                    }
                }
                closedir($dh);
                if ($#devices_deny > -1){
                    # now remove from denied devices our reserved devices
                    foreach my $r (@{$Cpuset->{'resources'}}){
                        if (($r->{type} eq "default") and
                            ($r->{network_address} eq "$ENV{TAKTUK_HOSTNAME}") and
                            ($r->{'gpudevice'} ne '')
                           ){
                            @devices_deny = grep { $_ !=  $r->{'gpudevice'} } @devices_deny;
                        }
                    }
                    print_log(3,"Deny other GPUs: @devices_deny");
                    my $devices_cgroup = $Cgroup_directory_collection_links."/devices/".$Cpuset_path_job."/devices.deny";
                    foreach my $dev (@devices_deny){
                        system_with_log("oardodo /bin/echo 'c 226:$dev rwm' > $devices_cgroup")
                        and exit_myself(5,"Failed to set the devices.deny to c 226:$dev rwm");
                        my $renderdev = $dev + 128;
                        system_with_log("oardodo /bin/echo 'c 226:$renderdev rwm' > $devices_cgroup")
                        and exit_myself(5,"Failed to set the devices.deny to c 226:$renderdev rwm");
                    }
                }
            }
        }

        # Assign the corresponding share of memory if memory cgroup enabled.
        if ($Enable_mem_cg eq "YES"){
            my $mem_global_kb;
            if (open(MEM, "/proc/meminfo")){
                while (my $line = <MEM>){
                    if ($line =~ /^MemTotal:\s+(\d+)\skB$/){
                        $mem_global_kb = $1 * 1024;
                        last;
                    }
                }
                close(MEM);
            }else{
                exit_myself(5,"Failed to retrieve the global memory from /proc/meminfo");
            }
            exit_myself(5,"Failed to parse /proc/meminfo to retrive MemTotal") if (!defined($mem_global_kb));
            my $mem_kb = sprintf("%.0f", (($#job_cpus + 1) / ($#node_cpus + 1) * $mem_global_kb));
            system_with_log('/bin/echo '.$mem_kb.' | cat > '.$Cgroup_directory_collection_links.'/memory/'.$Cpuset_path_job.'/memory.limit_in_bytes')
            and exit_myself(5,"Failed to set the memory.limit_in_bytes to $mem_kb");
        }

        # Create file used in the user jobs (environment variables, node files, ...)
        ## Feed the node file
        my @tmp_res;
        my %tmp_already_there;
        foreach my $r (@{$Cpuset->{resources}}){
            if (($r->{$Cpuset->{node_file_db_fields}} ne "") and ($r->{type} eq "default")){
                if (($r->{$Cpuset->{node_file_db_fields_distinct_values}} ne "") and (!defined($tmp_already_there{$r->{$Cpuset->{node_file_db_fields_distinct_values}}}))){
                    push(@tmp_res, $r->{$Cpuset->{node_file_db_fields}});
                    $tmp_already_there{$r->{$Cpuset->{node_file_db_fields_distinct_values}}} = 1;
                }
            }
        }
        if (open(NODEFILE, "> $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}")){
            foreach my $f (sort(@tmp_res)){
                print(NODEFILE "$f\n") or exit_myself(19,"Failed to write in node file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}");
            }
            close(NODEFILE);
        }else{
            exit_myself(19,"Failed to create node file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}");
        }
        ## create resource set file
        if (open(RESFILE, "> $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources")){
            foreach my $r (@{$Cpuset->{resources}}){
                my $line = "";
                foreach my $p (keys(%{$r})){
                    $r->{$p} = "" if (!defined($r->{$p}));
                    $line .= " $p = '$r->{$p}' ,"
                }
                chop($line);
                print(RESFILE "$line\n") or exit_myself(19,"Failed to write in resource file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources");
            }
            close(RESFILE);
        }else{
            exit_myself(19,"Failed to create resource file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources");
        }
        ## Write environment file
        if (open(ENVFILE, "> $Cpuset->{oar_tmp_directory}/$Cpuset->{name}.env")){
            my $job_name = "";
            $job_name = $Cpuset->{job_name} if defined($Cpuset->{job_name});
            my $filecontent = <<"EOF";
export OAR_JOBID='$Cpuset->{job_id}'
export OAR_ARRAYID='$Cpuset->{array_id}'
export OAR_ARRAYINDEX='$Cpuset->{array_index}'
export OAR_USER='$Cpuset->{user}'
export OAR_WORKDIR='$Cpuset->{launching_directory}'
export OAR_JOB_NAME='$job_name'
export OAR_PROJECT_NAME='$Cpuset->{project}'
export OAR_STDOUT='$Cpuset->{stdout_file}'
export OAR_STDERR='$Cpuset->{stderr_file}'
export OAR_FILE_NODES='$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}'
export OAR_RESOURCE_PROPERTIES_FILE='$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources'
export OAR_JOB_WALLTIME='$Cpuset->{walltime}'
export OAR_JOB_WALLTIME_SECONDS='$Cpuset->{walltime_seconds}'
export OAR_NODEFILE=\$OAR_FILE_NODES
export OAR_NODE_FILE=\$OAR_FILE_NODES
export OAR_RESOURCE_FILE=\$OAR_RESOURCE_PROPERTIES_FILE
export OAR_O_WORKDIR=\$OAR_WORKDIR
export OAR_WORKING_DIRECTORY=\$OAR_WORKDIR
export OAR_JOB_ID=\$OAR_JOBID
export OAR_ARRAY_ID=\$OAR_ARRAYID
export OAR_ARRAY_INDEX=\$OAR_ARRAYINDEX
EOF
            print(ENVFILE "$filecontent") or exit_myself(19,"Failed to write in file ");
        }else{
            exit_myself(19,"Failed to create file ");
        }
    }

    # Copy ssh key files
    if ($Cpuset->{ssh_keys}->{private}->{key} ne ""){
        # private key
        if (open(PRIV, ">".$Cpuset->{ssh_keys}->{private}->{file_name})){
            chmod(0600,$Cpuset->{ssh_keys}->{private}->{file_name});
            if (!print(PRIV $Cpuset->{ssh_keys}->{private}->{key})){
                unlink($Cpuset->{ssh_keys}->{private}->{file_name});
                exit_myself(8,"Error writing $Cpuset->{ssh_keys}->{private}->{file_name}");
            }
            close(PRIV);
        }else{
            exit_myself(7,"Error opening $Cpuset->{ssh_keys}->{private}->{file_name}");
        }

        # public key
        if (open(PUB,"+<",$Cpuset->{ssh_keys}->{public}->{file_name})){
            flock(PUB,LOCK_EX) or exit_myself(17,"flock failed: $!");
            seek(PUB,0,0) or exit_myself(18,"seek failed: $!");
            my $out = "\n".$Cpuset->{ssh_keys}->{public}->{key}."\n";
            while (<PUB>){
                if ($_ =~ /environment=\"OAR_KEY=1\"/){
                    # We are reading a OAR key
                    $_ =~ /(ssh-dss|ssh-rsa)\s+([^\s^\n]+)/;
                    my $oar_key = $2;
                    $Cpuset->{ssh_keys}->{public}->{key} =~ /(ssh-dss|ssh-rsa)\s+([^\s^\n]+)/;
                    my $curr_key = $2;
                    if ($curr_key eq $oar_key){
                        exit_myself(13,"ERROR: the user has specified the same ssh key than used by the user oar");
                    }
                    $out .= $_;
                }elsif ($_ =~ /environment=\"OAR_CPUSET=([\w\/]+)\"/){
                    # Remove from authorized keys outdated keys (typically after a reboot)
                    if (-d "/dev/cpuset/$1"){
                        $out .= $_;
                    }
                }else{
                    $out .= $_;
                }
            }
            if (!(seek(PUB,0,0) and print(PUB $out) and truncate(PUB,tell(PUB)))){
                exit_myself(9,"Error writing $Cpuset->{ssh_keys}->{public}->{file_name}");
            }
            flock(PUB,LOCK_UN) or exit_myself(17,"flock failed: $!");
            close(PUB);
        }else{
            unlink($Cpuset->{ssh_keys}->{private}->{file_name});
            exit_myself(10,"Error opening $Cpuset->{ssh_keys}->{public}->{file_name}");
        }
    }
}elsif ($ARGV[0] eq "clean"){
###############################################################################
# Node cleaning: run on all the nodes of the job after the job ends
###############################################################################
    # delete ssh key files
    if ($Cpuset->{ssh_keys}->{private}->{key} ne ""){
        # private key
        unlink($Cpuset->{ssh_keys}->{private}->{file_name});

        # public key
        if (open(PUB,"+<", $Cpuset->{ssh_keys}->{public}->{file_name})){
            flock(PUB,LOCK_EX) or exit_myself(17,"flock failed: $!");
            seek(PUB,0,0) or exit_myself(18,"seek failed: $!");
            #Change file on the fly
            my $out = "";
            while (<PUB>){
                if (($_ ne "\n") and ($_ ne $Cpuset->{ssh_keys}->{public}->{key})){
                    $out .= $_;
                }
            }
            if (!(seek(PUB,0,0) and print(PUB $out) and truncate(PUB,tell(PUB)))){
                exit_myself(12,"Error changing $Cpuset->{ssh_keys}->{public}->{file_name}");
            }
            flock(PUB,LOCK_UN) or exit_myself(17,"flock failed: $!");
            close(PUB);
        }else{
            exit_myself(11,"Error opening $Cpuset->{ssh_keys}->{public}->{file_name}");
        }
    }

    # Clean cpuset on this node
    if (defined($Cpuset_path_job)){
        system_with_log('echo THAWED > '.$Cgroup_directory_collection_links.'/freezer/'.$Cpuset_path_job.'/freezer.state
                         for d in '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/* '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'; do
                             if [ -d $d ]; then
                                 PROCESSES=$(cat $d/tasks)
                                 while [ "$PROCESSES" != "" ]; do
                                     oardodo kill -9 $PROCESSES > /dev/null 2>&1
                                     PROCESSES=$(cat $d/tasks)
                                 done
                             fi
                         done');

        # Locking around the cleanup of the cpuset for that user, to prevent a creation to occure at the same time
        # which would allow race condition for the dirty-user-based clean-up mechanism
        if (open(LOCK,">", $Cpuset_lock_file.$Cpuset->{user})){
            flock(LOCK,LOCK_EX) or die "flock failed: $!\n";
            system_with_log('if [ -w '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/memory.force_empty ]; then
                                 echo 0 > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/memory.force_empty
                             fi
                             for d in '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/* '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'; do
                                 if [ -d $d ]; then
                                     [ -w $d/memory.force_empty ] && echo 0 > $d/memory.force_empty
                                     while ! oardodo rmdir $d ; do
                                         cat $d/tasks | xargs -n1 ps -fh -p 1>&2
                                         echo retry in 1s... 1>&2
                                         sleep 1
                                     done
                                 fi
                             done
                             for d in '.$Cgroup_directory_collection_links.'/*/'.$Cpuset_path_job.'/* '.$Cgroup_directory_collection_links.'/*/'.$Cpuset_path_job.'; do
                                 if [ -d $d ]; then
                                     [ -w $d/memory.force_empty ] && echo 0 > $d/memory.force_empty
                                     oardodo rmdir $d > /dev/null 2>&1
                                 fi
                             done')
            # Uncomment this line if you want to use several network_address properties
            # which are the same physical computer (linux kernel)
            # and exit(0)
            and exit_myself(6,"Failed to delete the cpuset $Cpuset_path_job");

            # dirty-user-based cleanup: do cleanup only if that is the last job of the user on that host.
            my @cpusets = ();
            my @other_cpusets = ();
            if (opendir(DIR, $Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/')) {
                @cpusets = grep { /^$Cpuset->{user}_\d+$/ } readdir(DIR);
                closedir DIR;
            } else {
                exit_myself(18,"Can't opendir: $Cgroup_directory_collection_links/cpuset/$Cpuset->{cpuset_path}");
            }
            if (opendir(DIR, $Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/')) {
                @other_cpusets = grep { /^.*_\d+$/ } readdir(DIR);
                closedir DIR;
            } else {
                exit_myself(18,"Can't opendir: $Cgroup_directory_collection_links/cpuset/$Cpuset->{cpuset_path}");
            }

            if ($#cpusets < 0) {
                # No other jobs on this node at this time

                # Reboot if uptime > max_uptime
                if ( $#other_cpusets < 0 and $uptime > $max_uptime and $max_uptime > 0 and not -e "/etc/oar/dont_reboot") {
                  print_log(3,"Max uptime reached, rebooting node.");
                  system("/usr/lib/oar/oardodo/oardodo /sbin/reboot");
                  exit(0);
                }

                my $useruid=getpwnam($Cpuset->{user});
                if (not defined($useruid)){
                    print_log(3,"Cannot get information from user '$Cpuset->{user}' job #'$Cpuset->{job_id}' (line 481)");
                }
                my $ipcrm_args="";
                if (open(IPCMSG,"< /proc/sysvipc/msg")) {
                    <IPCMSG>;
                    while (<IPCMSG>) {
                        if (/^\s*\d+\s+(\d+)(?:\s+\d+){5}\s+$useruid(?:\s+\d+){6}/) {
                            $ipcrm_args .= " -q $1";
                            print_log(3,"Found IPC MSG for user $useruid: $1.");
                        }
                    }
                    close (IPCMSG);
                } else {
                    print_log(3,"Cannot open /proc/sysvipc/msg: $!.");
                }
                if (open(IPCSHM,"< /proc/sysvipc/shm")) {
                    <IPCSHM>;
                    while (<IPCSHM>) {
                        if (/^\s*\d+\s+(\d+)(?:\s+\d+){5}\s+$useruid(?:\s+\d+){6}/) {
                            $ipcrm_args .= " -m $1";
                            print_log(3,"Found IPC SHM for user $useruid: $1.");
                        }
                    }
                    close (IPCSHM);
                } else {
                    print_log(3,"Cannot open /proc/sysvipc/shm: $!.");
                }
                if (open(IPCSEM,"< /proc/sysvipc/sem")) {
                    <IPCSEM>;
                    while (<IPCSEM>) {
                        if (/^\s*[\d\-]+\s+(\d+)(?:\s+\d+){2}\s+$useruid(?:\s+\d+){5}/) {
                            $ipcrm_args .= " -s $1";
                            print_log(3,"Found IPC SEM for user $useruid: $1.");
                        }
                    }
                    close (IPCSEM);
                } else {
                    print_log(3,"Cannot open /proc/sysvipc/sem: $!.");
                }
                if ($ipcrm_args) {
                    print_log (3,"Purging SysV IPC: ipcrm $ipcrm_args.");
                    system_with_log("OARDO_BECOME_USER=$Cpuset->{user} oardodo ipcrm $ipcrm_args");
                }
                print_log (3,"Purging @Tmp_dir_to_clear.");
                system_with_log('for d in '."@Tmp_dir_to_clear".'; do
                                     oardodo find $d -user '.$Cpuset->{user}.' -delete
                                     [ -x '.$Fstrim_cmd.' ] && oardodo '.$Fstrim_cmd.' $d > /dev/null 2>&1
                                 done
                                ');
            } else {
                print_log(3,"Not purging SysV IPC and /tmp as $Cpuset->{user} still has a job running on this host.");
            }
            flock(LOCK,LOCK_UN) or die "flock failed: $!\n";
            close(LOCK);
        }
        print_log(3,"Remove file $Cpuset->{oar_tmp_directory}/$Cpuset->{name}.env");
        unlink("$Cpuset->{oar_tmp_directory}/$Cpuset->{name}.env");
        print_log(3,"Remove file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}");
        unlink("$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}");
        print_log(3,"Remove file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources");
        unlink("$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources");
    }
}else{
    exit_myself(3,"Bad command line argument $ARGV[0]");
}

exit(0);

# Print error message and exit
sub exit_myself($$){
    my $exit_code = shift;
    my $str = shift;

    warn("[job_resource_manager_cgroups][$Cpuset->{job_id}][$ENV{TAKTUK_HOSTNAME}][ERROR] $str\n");
    exit($exit_code);
}

# Print log message depending on the LOG_LEVEL config value
sub print_log($$){
    my $l = shift;
    my $str = shift;

    if ($l <= $Log_level){
        print("[job_resource_manager_cgroups][$Cpuset->{job_id}][$ENV{TAKTUK_HOSTNAME}][DEBUG] $str\n");
    }
}
# Run a command after printing it in the logs if OAR log level ≥ 4
sub system_with_log($) {
    my $command = shift;
    if (4 <= $Log_level){
        # Remove extra leading spaces in the command for the log, but preserve indentation
        my $log = $command;
        my @leading_spaces_lenghts = map {length($_)} ($log =~ /^( +)/mg);
        my $leading_spaces_to_remove = (sort {$a<=>$b} @leading_spaces_lenghts)[0];
        if (defined($leading_spaces_to_remove)){
            $log =~ s/^ {$leading_spaces_to_remove}//mg;
        }
        print_log(4, "System command:\n".$log);
    }
    return system($command);
}
