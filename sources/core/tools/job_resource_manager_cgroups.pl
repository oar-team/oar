# $Id$
# 
# The "job_resource_manager_cgroups.pl" script is a perl script that oar server
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
#     - [devices] Allow or deny the access of devices for each job processes
#                 (By default every devices are allowed)
#     - [freezer] Permit to suspend or resume the job processes.
#                 This is used by the suspend/resume of OAR (oarhold/oarresume)
#     - [blkio]   Put an IO share corresponding to the ratio between reserved
#                 cores and the number of the node (this is disabled by default
#                 due to bad behaviour seen. More tests have to be done)
#                 There are some interesting accounting data available.
#     - [memory]  Permit to restrict the amount of RAM that can be used by the
#                 job processes (ratio of job_nb_cores / total_nb_cores).
#                 This is useful for OOM problems (kill only tasks inside the
#                 cgroup where OOM occurs)
#                 DISABLED by default: there are maybe some performance issues
#                 (need to do some benchmarks)
#                 You can ENABLE this feature by putting 'my $ENABLE_MEMCG =
#                 "YES";' in the following code
#
# Usage:
# This script is deployed from the server and executed as oar on the nodes.
# ARGV[0] can have two different values:
#     - "init"  : then this script must create the right cpuset and assign
#                 corresponding cpus
#     - "clean" : then this script must kill all processes in the cpuset and
#                 clean the cpuset structure

# TAKTUK_HOSTNAME environment variable must be defined and must be a key
# of the transfered hash table ($Cpuset variable).
use Fcntl ':flock';

sub exit_myself($$);
sub print_log($$);

# Put YES if you want to use the memory cgroup
my $ENABLE_MEMCG = "NO";

my $OS_cgroups_path = "/sys/fs/cgroup";  # Where the OS mounts by itself the cgroups
                                         # (systemd for example

# Directories where files of the job user will be deleted at the end if there
# is not an other running job of the same user
my @TMP_DIRECTORIES_TO_CLEAR = ('/tmp/.','/dev/shm/.','/var/tmp/.');
my $FSTRIM_CMD = "/sbin/fstrim";

my $Old_umask = sprintf("%lo",umask());
umask(oct("022"));

my $Cgroup_mount_point = "/dev/oar_cgroups";
my $Cpuset;
my $Log_level;
my $Cpuset_lock_file = "$ENV{HOME}/cpuset.lock.";

# Directory where the cgroup mount points are linked to. Useful to have each
# cgroups in the same place with the same hierarchy.
my $Cgroup_directory_collection_links = "/dev/oar_cgroups_links";

# Retrieve parameters from STDIN in the "Cpuset" structure which looks like: 
# $Cpuset = {
#               job_id => id of the corresponding job
#               name => "cpuset name"
#               cpuset_path => "relative path in the cpuset FS"
#               nodes => hostname => [array with the content of the database cpuset field]
#               ssh_keys => {
#                               public => {
#                                           file_name => "~oar/.ssh/authorized_keys"
#                                           key => "public key content"
#                                         }
#                               private => {
#                                           file_name => "directory where to store the private key"
#                                           key => "private key content"
#                                          }
#                           }
#               oar_tmp_directory => "path to the temp directory"
#               user => "user name"
#               job_user => "job user"
#               types => hashtable with job types as keys
#               resources => [ {property_name => value} ]
#               node_file_db_fields => NODE_FILE_DB_FIELD
#               node_file_db_fields_distinct_values => NODE_FILE_DB_FIELD_DISTINCT_VALUES
#               array_id => job array id
#               array_index => job index in the array
#               stdout_file => stdout file name
#               stderr_file => stderr file name
#               launching_directory => launching directory
#               job_name => job name
#               walltime_seconds => job walltime in seconds
#               walltime => job walltime
#               project => job project name
#               log_level => debug level number
#           }
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
# Get the data structure only for this node
if (defined($Cpuset->{cpuset_path})){
    $Cpuset_path_job = $Cpuset->{cpuset_path}.'/'.$Cpuset->{name};
    foreach my $l (@{$Cpuset->{nodes}->{$ENV{TAKTUK_HOSTNAME}}}){
        foreach my $c (split("[, \+]",$l)){
            push(@Cpuset_cpus, $c);
        }
    }
}



print_log(3,"$ARGV[0]");
if ($ARGV[0] eq "init"){
    # Initialize cpuset for this node
    # First, create the tmp oar directory
    if (!(((-d $Cpuset->{oar_tmp_directory}) and (-O $Cpuset->{oar_tmp_directory})) or (mkdir($Cpuset->{oar_tmp_directory})))){
        exit_myself(13,"Directory $Cpuset->{oar_tmp_directory} does not exist and cannot be created");
    }

    if (defined($Cpuset_path_job)){
        if (open(LOCKFILE,"> $Cpuset->{oar_tmp_directory}/job_manager_lock_file")){
            flock(LOCKFILE,LOCK_EX) or exit_myself(17,"flock failed: $!");
            if (!(-r $Cgroup_directory_collection_links.'/cpuset/tasks')){
                if (!(-r $OS_cgroups_path.'/cpuset/tasks')){
                    my $cgroup_list = "cpuset,cpu,cpuacct,devices,freezer,blkio";
                    $cgroup_list .= ",memory" if ($ENABLE_MEMCG eq "YES");
                    if (system('oardodo mkdir -p '.$Cgroup_mount_point.' &&
                                oardodo mount -t cgroup -o '.$cgroup_list.' none '.$Cgroup_mount_point.' || exit 1
                                oardodo rm -f /dev/cpuset
                                oardodo ln -s '.$Cgroup_mount_point.' /dev/cpuset &&
                                oardodo mkdir -p '.$Cgroup_directory_collection_links.' &&
                                oardodo ln -s '.$Cgroup_mount_point.' '.$Cgroup_directory_collection_links.'/cpuset &&
                                oardodo ln -s '.$Cgroup_mount_point.' '.$Cgroup_directory_collection_links.'/cpu &&
                                oardodo ln -s '.$Cgroup_mount_point.' '.$Cgroup_directory_collection_links.'/cpuacct &&
                                oardodo ln -s '.$Cgroup_mount_point.' '.$Cgroup_directory_collection_links.'/devices &&
                                oardodo ln -s '.$Cgroup_mount_point.' '.$Cgroup_directory_collection_links.'/freezer &&
                                oardodo ln -s '.$Cgroup_mount_point.' '.$Cgroup_directory_collection_links.'/blkio &&
                                [ "'.$ENABLE_MEMCG.'" =  "YES" ] && oardodo ln -s '.$Cgroup_mount_point.' '.$Cgroup_directory_collection_links.'/memory || true
                               ')){
                        exit_myself(4,"Failed to mount cgroup pseudo filesystem");
                    }
                }else{
                    # Cgroups already mounted by the OS
                    if (system('oardodo rm -f /dev/cpuset
                                oardodo ln -s '.$OS_cgroups_path.'/cpuset /dev/cpuset &&
                                oardodo mkdir -p '.$Cgroup_directory_collection_links.' &&
                                oardodo ln -s '.$OS_cgroups_path.'/cpuset '.$Cgroup_directory_collection_links.'/cpuset &&
                                oardodo ln -s '.$OS_cgroups_path.'/cpu '.$Cgroup_directory_collection_links.'/cpu &&
                                oardodo ln -s '.$OS_cgroups_path.'/cpuacct '.$Cgroup_directory_collection_links.'/cpuacct &&
                                oardodo ln -s '.$OS_cgroups_path.'/devices '.$Cgroup_directory_collection_links.'/devices &&
                                oardodo ln -s '.$OS_cgroups_path.'/freezer '.$Cgroup_directory_collection_links.'/freezer &&
                                oardodo ln -s '.$OS_cgroups_path.'/blkio '.$Cgroup_directory_collection_links.'/blkio &&
                                [ "'.$ENABLE_MEMCG.'" =  "YES" ] && oardodo ln -s '.$OS_cgroups_path.'/memory '.$Cgroup_directory_collection_links.'/memory || true
                               ')){
                        exit_myself(4,"Failed to link existing OS cgroup pseudo filesystem");
                    }
                }
            }
            if (!(-d $Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path})){
                # Populate default oar cgroup
                if (system( 'for d in '.$Cgroup_directory_collection_links.'/*; do
                               oardodo mkdir -p $d/'.$Cpuset->{cpuset_path}.' || exit 1
                               oardodo chown -R oar $d/'.$Cpuset->{cpuset_path}.' || exit 2
                               /bin/echo 0 | cat > $d/'.$Cpuset->{cpuset_path}.'/notify_on_release || exit 3
                             done
                             /bin/echo 0 | cat > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.cpu_exclusive &&
                             cat '.$Cgroup_directory_collection_links.'/cpuset/cpuset.mems > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.mems &&
                             cat '.$Cgroup_directory_collection_links.'/cpuset/cpuset.cpus > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.cpus &&
                             /bin/echo 1000 | cat > '.$Cgroup_directory_collection_links.'/blkio/'.$Cpuset->{cpuset_path}.'/blkio.weight
                            ')){
                    exit_myself(4,"Failed to create cgroup $Cpuset->{cpuset_path}");
                }
            }
            flock(LOCKFILE,LOCK_UN) or exit_myself(17,"flock failed: $!");
            close(LOCKFILE);
        }else{
            exit_myself(16,"Failed to open or create $Cpuset->{oar_tmp_directory}/job_manager_lock_file");
        }

        # Be careful with the physical_package_id. Is it corresponding to the memory banch?
        # Create job cgroup
        if (system( 'for d in '.$Cgroup_directory_collection_links.'/*; do
                       oardodo mkdir -p $d/'.$Cpuset_path_job.' || exit 1
                       oardodo chown -R oar $d/'.$Cpuset_path_job.' || exit 2
                       /bin/echo 0 | cat > $d/'.$Cpuset_path_job.'/notify_on_release || exit 3
                     done
                     /bin/echo 0 | cat > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/cpuset.cpu_exclusive &&
                     MEM=
                     for c in '."@Cpuset_cpus".'; do
                       for n in /sys/devices/system/node/node* ; do
                         if [ -r "$n/cpu$c" ]; then
                           MEM=$(basename $n | sed s/node//g),$MEM
                         fi
                       done
                     done
                     echo $MEM > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/cpuset.mems &&
                     /bin/echo '.join(",",@Cpuset_cpus).' | cat > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/cpuset.cpus
                    ')){
            exit_myself(5,"Failed to create and feed the cpuset $Cpuset_path_job");
        }

        # Put a share of disk IO corresponding of the ratio between the number
        # of cores of this job cgroup and the number of cores of the node
        my @cpu_cgroup_uniq_list;
        my %cpu_cgroup_name_hash;
        foreach my $i (@Cpuset_cpus){
            if (!defined($cpu_cgroup_name_hash{$i})){
                $cpu_cgroup_name_hash{$i} = 1;
                push(@cpu_cgroup_uniq_list, $i);
            }
        }
        # Get the whole cores of the node
        my @node_cpus;
        if (open(CPUS, "$Cgroup_directory_collection_links/cpuset/cpuset.cpus")){
            my $str = <CPUS>;
            chop($str);
            $str =~ s/\-/\.\./g;
            @node_cpus = eval($str);
            close(CPUS);
        }else{
            exit_myself(5,"Failed to retrieve the cpu list of the node $Cgroup_directory_collection_links/cpuset/cpuset.cpus");
        }
        my $IO_ratio = sprintf("%.0f",(($#cpu_cgroup_uniq_list + 1) / ($#node_cpus + 1) * 1000)) ;
        # TODO: Need to do more tests to validate so remove this feature
        #       Some values are not working when echoing
        $IO_ratio = 1000;
        if (system( '/bin/echo '.$IO_ratio.' | cat > '.$Cgroup_directory_collection_links.'/blkio/'.$Cpuset_path_job.'/blkio.weight')){
            exit_myself(5,"Failed to set the blkio.weight to $IO_ratio");
        }

        # Assign the corresponding share of memory if memory cgroup enabled.
        if ($ENABLE_MEMCG eq "YES"){
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
            my $mem_kb = sprintf("%.0f", (($#cpu_cgroup_uniq_list + 1) / ($#node_cpus + 1) * $mem_global_kb));
            if (system( '/bin/echo '.$mem_kb.' | cat > '.$Cgroup_directory_collection_links.'/memory/'.$Cpuset_path_job.'/memory.limit_in_bytes')){
                exit_myself(5,"Failed to set the memory.limit_in_bytes to $mem_kb");
            }
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
            my $filecontent = <<"EOF";
export OAR_JOBID='$Cpuset->{job_id}'
export OAR_ARRAYID='$Cpuset->{array_id}'
export OAR_ARRAYINDEX='$Cpuset->{array_index}'
export OAR_USER='$Cpuset->{user}'
export OAR_WORKDIR='$Cpuset->{launching_directory}'
export OAR_JOB_NAME='$Cpuset->{job_name}'
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
        system('echo THAWED > '.$Cgroup_directory_collection_links.'/freezer/'.$Cpuset_path_job.'/freezer.state
                PROCESSES=$(cat '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/tasks)
                while [ "$PROCESSES" != "" ]
                do
                    oardodo kill -9 $PROCESSES > /dev/null 2>&1
                    PROCESSES=$(cat '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/tasks)
                done'
              );

        # Locking around the cleanup of the cpuset for that user, to prevent a creation to occure at the same time
        # which would allow race condition for the user-based clean-up mechanism
        if (open(LOCK,">", $Cpuset_lock_file.$Cpuset->{user})){
            flock(LOCK,LOCK_EX) or die "flock failed: $!\n";
            if (system('if [ -w '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/memory.force_empty ]; then
                          echo 0 > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/memory.force_empty
                        fi
                        oardodo rmdir '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.' &&
                        for d in '.$Cgroup_directory_collection_links.'/*/'.$Cpuset_path_job.'; do
                          [ -w $d/memory.force_empty ] && echo 0 > $d/memory.force_empty
                          if [ -d $d ]; then
                            oardodo rmdir $d > /dev/null 2>&1 || exit 1
                          fi
                        done
                       ')){
                # Uncomment this line if you want to use several network_address properties
                # which are the same physical computer (linux kernel)
                #exit(0);
                exit_myself(6,"Failed to delete the cpuset $Cpuset_path_job");
            }
            # user-based cleanup: do cleanup only if that is the last job of the user on that host.
            my @cpusets = ();
            if (opendir(DIR, $Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/')) {
                @cpusets = grep { /^$Cpuset->{user}_\d+$/ } readdir(DIR);
                closedir DIR;
            } else {
              exit_myself(18,"Can't opendir: $Cgroup_directory_collection_links/cpuset/$Cpuset->{cpuset_path}");
            }
            if ($#cpusets < 0) {
                # No other jobs on this node at this time
                my $useruid=getpwnam($Cpuset->{user});
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
                    system("OARDO_BECOME_USER=$Cpuset->{user} oardodo ipcrm $ipcrm_args"); 
                }
                print_log (3,"Purging @TMP_DIRECTORIES_TO_CLEAR.");
                system('for d in '."@TMP_DIRECTORIES_TO_CLEAR".'; do
                            oardodo find $d -user '.$Cpuset->{user}.' -delete
                            [ -x '.$FSTRIM_CMD.' ] && oardodo '.$FSTRIM_CMD.' $d > /dev/null 2>&1
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

    warn("[job_resource_manager_cgroups][$Cpuset->{job_id}][ERROR] ".$str."\n");
    exit($exit_code);
}

# Print log message depending on the LOG_LEVEL config value
sub print_log($$){
    my $l = shift;
    my $str = shift;

    if ($l <= $Log_level){
        print("[job_resource_manager_cgroups][$Cpuset->{job_id}][DEBUG] $str\n");
    }
}

