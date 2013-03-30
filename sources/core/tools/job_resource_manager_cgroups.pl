# $Id$
# 
# The job_resource_manager_cgroups script is a perl script that oar server
# deploys on nodes to manage cpusets, users, job keys, ...
#
# In this script some cgroup Linux features are added in addition to cpuset:
#     - Tag each network packet from processes of this job with the class id =
#       $OAR_JOB_ID
#     - Put an IO share corresponding to the ratio between reserved cpus and
#       the number of the node
#
# Usage:
# This script is deployed from the server and executed as oar on the nodes
# ARGV[0] can have two different values:
#     - "init"  : then this script must create the right cpuset and assign
#                 corresponding cpus
#     - "clean" : then this script must kill all processes in the cpuset and
#                 clean the cpuset structure

# TAKTUK_HOSTNAME environment variable must be defined and must be a name
# that we will be able to find in the transfered hashtable ($Cpuset variable).
use Fcntl ':flock';
#use Data::Dumper;

sub exit_myself($$);
sub print_log($$);

# Put YES if you want to use the memory cgroup
# This is useful for OOM problems (kill only tasks inside the same cgroup
my $ENABLE_MEMCG = "NO";

my $Old_umask = sprintf("%lo",umask());
umask(oct("022"));

my $Cgroup_mount_point = "/dev/oar_cgroups";
my $Cpuset;
my $Log_level;
my $Cpuset_lock_file = "$ENV{HOME}/cpuset.lock.";
my $OS_cgroups_path = "/sys/fs/cgroup";  # Where the OS mount by itself the cgroups

# directory where are the links to the cgroup mount points (if directly handled
# by the OS)
my $Cgroup_directory_collection_links = "/dev/oar_cgroups_links";

# Retrieve parameters from STDIN in the "Cpuset" structure which looks like: 
# $Cpuset = {
#               job_id => id of the corresponding job
#               name => "cpuset name",
#               cpuset_path => "relative path in the cpuset FS",
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
#               job_uid => "job uid for the job_user if needed"
#               types => hashtable with job types as keys
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

    if (defined($Cpuset->{job_uid})){
        my $prevuser = getpwuid($Cpuset->{job_uid});
        system("oardodo /usr/sbin/userdel -f $prevuser") if (defined($prevuser));
        my @tmp = getpwnam($Cpuset->{user});
        if ($#tmp < 0){
            exit_myself(15,"Cannot get information from user '$Cpuset->{user}'");
        }
        if (system("oardodo /usr/sbin/adduser --disabled-password --gecos 'OAR temporary user' --no-create-home --force-badname --quiet --home $tmp[7] --gid $tmp[3] --shell $tmp[8] --uid $Cpuset->{job_uid} $Cpuset->{job_user}")){
            exit_myself(15,"Failed to create $Cpuset->{job_user} with uid $Cpuset->{job_uid} and home $tmp[7] and group $tmp[3] and shell $tmp[8]");
        }
    }

    if (defined($Cpuset_path_job)){
        if (open(LOCKFILE,"> $Cpuset->{oar_tmp_directory}/job_manager_lock_file")){
            flock(LOCKFILE,LOCK_EX) or exit_myself(17,"flock failed: $!");
            if (!(-r $Cgroup_directory_collection_links.'/cpuset/tasks')){
                if (!(-r $OS_cgroups_path.'/cpuset/tasks')){
                    my $cgroup_list = "cpuset,cpu,cpuacct,devices,freezer,net_cls,blkio";
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
                                oardodo ln -s '.$Cgroup_mount_point.' '.$Cgroup_directory_collection_links.'/net_cls &&
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
                                oardodo ln -s '.$OS_cgroups_path.'/net_cls '.$Cgroup_directory_collection_links.'/net_cls &&
                                oardodo ln -s '.$OS_cgroups_path.'/blkio '.$Cgroup_directory_collection_links.'/blkio &&
                                [ "'.$ENABLE_MEMCG.'" =  "YES" ] && oardodo ln -s '.$OS_cgroups_path.'/memory '.$Cgroup_directory_collection_links.'/memory || true
                               ')){
                        exit_myself(4,"Failed to link existing OS cgroup pseudo filesystem");
                    }
                }
            }
            if (!(-d $Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path})){
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

        # Tag network packets from processes of this job
        if (system( '/bin/echo '.$Cpuset->{job_id}.' | cat > '.$Cgroup_directory_collection_links.'/net_cls/'.$Cpuset_path_job.'/net_cls.classid'
                  )){
            exit_myself(5,"Failed to tag network packets of the cgroup $Cpuset_path_job");
        }
        # Put a share for IO disk corresponding of the ratio between the number
        # of cpus of this cgroup and the number of cpus of the node
        my @cpu_cgroup_uniq_list;
        my %cpu_cgroup_name_hash;
        foreach my $i (@Cpuset_cpus){
            if (!defined($cpu_cgroup_name_hash{$i})){
                $cpu_cgroup_name_hash{$i} = 1;
                push(@cpu_cgroup_uniq_list, $i);
            }
        }
        # Get the whole cpus of the node
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
            if (defined($Cpuset->{job_uid})){
                system("ln -s $Cpuset->{ssh_keys}->{private}->{file_name} $Cpuset->{oar_tmp_directory}/$Cpuset->{job_user}.jobkey");
            }
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
        if (defined($Cpuset->{job_uid})){
            unlink("$Cpuset->{oar_tmp_directory}/$Cpuset->{job_user}.jobkey");
        }

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
                    oardodo kill -9 $PROCESSES
                    PROCESSES=$(cat '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/tasks)
                done'
              );

        # Locking around the cleanup of the cpuset for that user, to prevent a creation to occure at the same time
        # which would allow race condition for the dirty-user-based clean-up mechanism
        if (open(LOCK,">", $Cpuset_lock_file.$Cpuset->{user})){
            flock(LOCK,LOCK_EX) or die "flock failed: $!\n";
            if (system('if [ -w '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/memory.force_empty ]; then
                          echo 0 > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/memory.force_empty
                        fi
                        oardodo rmdir '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.' &&
                        for d in '.$Cgroup_directory_collection_links.'/*/'.$Cpuset_path_job.'; do
                          [ -w $d/memory.force_empty ] && echo 0 > $d/memory.force_empty
                          if [ -d $d ]; then
                            oardodo rmdir $d >& /dev/null || exit 1
                          fi
                        done
                       ')){
                # Uncomment this line if you want to use several network_address properties
                # which are the same physical computer (linux kernel)
                #exit(0);
                exit_myself(6,"Failed to delete the cpuset $Cpuset_path_job");
            }
            if (not defined($Cpuset->{job_uid})){
                # dirty-user-based cleanup: do cleanup only if that is the last job of the user on that host.
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
		            print_log (3,"Purging /tmp /dev/shm /var/tmp...");
		            system("oardodo find /tmp/. /dev/shm/. /var/tmp/. -user $Cpuset->{user} -delete"); 
		        } else {
		            print_log(2,"Not purging SysV IPC and /tmp as $Cpuset->{user} still has a job running on this host.");
		        }
            }
	        flock(LOCK,LOCK_UN) or die "flock failed: $!\n";
	        close(LOCK);
        } 
    }


    if (defined($Cpuset->{job_uid})){
        my $ipcrm_args="";
        if (open(IPCMSG,"< /proc/sysvipc/msg")) {
            <IPCMSG>;
            while (<IPCMSG>) {
                if (/^\s*\d+\s+(\d+)(?:\s+\d+){5}\s+$Cpuset->{job_uid}(?:\s+\d+){6}$/) {
                    $ipcrm_args .= " -q $1";
                } else {
                    print_log(3,"Cannot parse IPC MSG: $_.");
                }
            }
            close (IPCMSG);
        }else{
            exit_myself(14,"Cannot open /proc/sysvipc/msg: $!");
        }
        if (open(IPCSHM,"< /proc/sysvipc/shm")) {
            <IPCSHM>;
            while (<IPCSHM>) {
                if (/^\s*\d+\s+(\d+)(?:\s+\d+){5}\s+$Cpuset->{job_uid}(?:\s+\d+){6}$/) {
                    $ipcrm_args .= " -m $1";
                } else {
                    print_log(3,"Cannot parse IPC SHM: $_.");
                }
            }
            close (IPCSHM);
        }else{
            exit_myself(14,"Cannot open /proc/sysvipc/shm: $!");
        }
        if (open(IPCSEM,"< /proc/sysvipc/sem")) {
            <IPCSEM>;
            while (<IPCSEM>) {
                if (/^\s*\d+\s+(\d+)(?:\s+\d+){2}\s+$Cpuset->{job_uid}(?:\s+\d+){5}$/) {
                    $ipcrm_args .= " -s $1";
                } else {
                    print_log(3,"Cannot parse IPC SEM: $_.");
                }
            }
            close (IPCSEM);
        }else{
            exit_myself(14,"Cannot open /proc/sysvipc/sem: $!");
        }
        if ($ipcrm_args) {
            print_log(3,"Purging SysV IPC: ipcrm $ipcrm_args");
            if(system("oardodo ipcrm $ipcrm_args")){
                exit_myself(14,"Failed to purge IPC: ipcrm $ipcrm_args");
            }
        }
        print_log(3,"Purging /tmp...");
        #system("oardodo find /tmp/ -user $Cpuset->{job_user} -exec rm -rfv {} \\;");
        system("oardodo find /tmp/. /dev/shm/. /var/tmp/. -user $Cpuset->{job_user} -delete");
        system("oardodo /usr/sbin/userdel -f $Cpuset->{job_user}");
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

