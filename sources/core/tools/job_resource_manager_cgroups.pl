# The job resource manager script is a perl script that oar server deploys on
# nodes to manage cpusets, users, job keys, ...
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
#     - [blkio]   Put an IO share corresponding to the ratio between reserved
#                 cores and the number of the node (this is disabled by default
#                 due to bad behaviour seen. More tests have to be done)
#                 There are some interesting accounting data available.
#     - [memory]  Permit to restrict the amount of RAM which can be used by the
#                 job processes (ratio of job_nb_cores / total_nb_cores).
#                 This is useful for OOM problems (kill only tasks inside the
#                 cgroup where OOM occurs). The functionality is disabled by 
#                 default, because it might cause a performance drop.
#                 To enable the functionality, set 'my $ENABLE_MEMCG = 1;'
#                 below.
#     - [devices] Grant or deny access to some devices for processes of the
#                 job (by default, access to all devices is granted).
#                 To enable the functionality, set 'my $ENABLE_DEVICESCG = 1;'
#                 below.
#                 Also there must be a resource property named 'gpudevice'
#                 configured. This property must contain the GPU id which is
#                 allowed to be used (id on the compute node).
#
# Usage:
# This script is deployed from the server and executed as oar on the nodes.
# ARGV[0] can have two different values:
#     - "init"  : then this script must create the right cpuset and assign
#                 corresponding cpus
#     - "clean" : then this script must kill all processes in the cpuset and
#                 clean the cpuset structure

# TAKTUK_HOSTNAME environment variable must be defined and must be a key
# of the transfered hash table ($Job_data variable).
use strict;
use warnings;
use Data::Dumper;

use Fcntl qw(:flock);

$Data::Dumper::Terse = 1;

sub exit_myself($$);
sub print_log($$);
sub logstr($$);
sub get_memtotal();
sub get_cpuset_cpulist($);
sub get_data_cpulist(@);
sub get_extensible_jobs_data();
sub get_job_nodes(@);
sub get_job_resources(@);
sub get_job_env($$);
sub uniq(@);
sub get_job_env_x($@);
sub create_job_files($@);
sub remove_job_files($);
sub configure_job_cpuset($);
sub unconfigure_job_cpuset();

my $Script_name = "job_resource_manager_cgroup";

# Set to 1 if you want to use the memory cgroup
my $ENABLE_MEMCG = 1;
# Set to 1 if you want to use the device cgroup (currently, only nvidia devices are supported)
my $ENABLE_DEVICESCG = 1;

my $OS_cgroups_path = "/sys/fs/cgroup";  # Where the OS mounts by itself the cgroups
my $Cgroup_mount_point = "/dev/oar_cgroups";
                                         # (systemd for example
# Directories where files of the job user will be deleted at the end if there
# is not an other running job of the same user
my @Dir_to_clean = ('/tmp/.','/dev/shm/.','/var/tmp/.');
my $Fstrim_cmd = "/sbin/fstrim";

my $Old_umask = sprintf("%lo",umask());
umask(oct("022"));

my $Job_data;

# Directory where the cgroup mount points are linked to. Useful to have each
# cgroups in the same place with the same hierarchy.
my $Cgroup_directory_collection_links = "/dev/oar_cgroups_links";

# Retrieve parameters from STDIN in the "Data" structure which looks like:
# $Job_data = {
#               job_id => id of the corresponding job,
#               array_id => job array id
#               array_index => job index in the array
#               job_name => job name
#               project => job project name
#               cpuset_name => "cpuset name",
#               cpuset_path => "relative path in the cpuset FS",
#               nodes => hostname => [array with the content of the database cpuset field]
#               resources => [ {property_name => value} ]
#               property_nodes => NODE_FILE_DB_FIELD
#               property_distinct_resources => NODE_FILE_DB_FIELD_DISTINCT_VALUES
#               stdout_file => stdout file name
#               stderr_file => stderr file name
#               launching_directory => launching directory
#               ssh_keys => {
#                               public => "public key blob"
#                               private => "private key blob"
#                           }
#               oar_tmp_directory => "path to the temp directory"
#               user => "user name"
#               types => hashtable with job types as keys
#               walltime_seconds => job walltime in seconds
#               walltime => job walltime
#               log_level => debug level number
#           }
my $slurp = do { local $/; <STDIN> };
$Job_data = eval($slurp);

if (!defined($Job_data->{log_level})) {
    exit_myself(2,"Bad hashtable transfered");
}
print_log(4,Dumper($Job_data));

my $Lock_file = "$Job_data->{oar_tmp_directory}/job_resource_manager.lock_file";
my $Job_cpuset_dir = (defined($Job_data->{cpuset_path}))?"$Job_data->{cpuset_path}/$Job_data->{cpuset_name}":"";
my $Job_data_dir = "$Job_data->{oar_tmp_directory}/$Job_data->{cpuset_name}";
my $Job_file_env = "env";
my $Job_file_resources = "resources";
my $Job_file_nodes = "nodes";
my $Job_x_dir_prefix = "";
my $Job_file_data = "data";
my $Job_key_dir = "$Job_data_dir".(($Job_data->{cpuset_name} =~ /,j=X$/)?"/$Job_x_dir_prefix$Job_data->{job_id}":"");
my $Ssh_authorized_keys = ".ssh/authorized_keys";

my $bashcmd;
print_log(2,"$Script_name $ARGV[0] (log level=$Job_data->{log_level})");
if ($ARGV[0] eq "init") {
    # Initialize cpuset for this node
    # First, create the tmp oar directory
    if (!(((-d $Job_data->{oar_tmp_directory}) and (-O $Job_data->{oar_tmp_directory})) or (mkdir($Job_data->{oar_tmp_directory})))) {
        exit_myself(13,"Directory $Job_data->{oar_tmp_directory} does not exist and cannot be created");
    }

    if (defined($Job_data->{cpuset_path})) {
        # Global cgroup/cpuset setup
        print_log(4,"Locking $Lock_file.global");
        open(LOCKFILE,"> $Lock_file.global") or exit_myself(16,"Failed to open global lock file: $!");
        flock(LOCKFILE,LOCK_EX) or exit_myself(17,"flock failed: $!");
        print_log(4,"Locked $Lock_file.global");
        if (!(-r $Cgroup_directory_collection_links.'/cpuset/tasks')) {
            my $cgroup_list = "cpuset,cpu,cpuacct,devices,freezer,blkio";
            if (!(-r $OS_cgroups_path.'/cpuset/tasks')) {
                $cgroup_list .= ",memory" if ($ENABLE_MEMCG);
                $bashcmd =
                    'oardodo mkdir -p '.$Cgroup_mount_point.'; '.
                    'oardodo mount -t cgroup -o '.$cgroup_list.' none '.$Cgroup_mount_point.'; '.
                    'oardodo rm -f /dev/cpuset; '.
                    'oardodo ln -s '.$Cgroup_mount_point.' /dev/cpuset; '.
                    'oardodo mkdir -p '.$Cgroup_directory_collection_links.'; '.
                    'for cg in {'.$cgroup_list.'}; do '.
                        'oardodo ln -s '.$Cgroup_mount_point.' '.$Cgroup_directory_collection_links.'/$cg; '.
                    'done; ';
                print_log(4, "$bashcmd");
                if (system("bash -e -c '$bashcmd'")) {
                    exit_myself(4,"Failed to mount cgroup pseudo filesystem");
                } else {
                    print_log(4, "OK");
                }
            }else{
                # Cgroups already mounted by the OS
                $bashcmd =
                    'oardodo rm -f /dev/cpuset; '.
                    'oardodo ln -s '.$OS_cgroups_path.'/cpuset /dev/cpuset; '.
                    'oardodo mkdir -p '.$Cgroup_directory_collection_links.'; '.
                    'for cg in {'.$cgroup_list.'}; do '.
                        'oardodo ln -s '.$OS_cgroups_path.'/cpu '.$Cgroup_directory_collection_links.'/$cg; '.
                    'done; ';
                print_log(4, "$bashcmd");
                if (system("bash -e -c '$bashcmd'")) {
                    exit_myself(4,"Failed to link existing OS cgroup pseudo filesystem");
                } else {
                    print_log(4, "OK");
                }
            }
        }
        # Populate default oar cgroup
        $bashcmd =
            'shopt -s nullglob; '.
            'for d in '.$Cgroup_directory_collection_links.'/*; do '.
               'oardodo mkdir -p $d'.$Job_data->{cpuset_path}.'; '.
               'oardodo chown -R oar $d'.$Job_data->{cpuset_path}.'; '.
               '/bin/echo 0 > $d'.$Job_data->{cpuset_path}.'/notify_on_release; '.
            'done; '.
            '/bin/echo 0 > '.$Cgroup_directory_collection_links.'/cpuset'.$Job_data->{cpuset_path}.'/cpuset.cpu_exclusive; '.
            'cat '.$Cgroup_directory_collection_links.'/cpuset/cpuset.mems > '.$Cgroup_directory_collection_links.'/cpuset'.$Job_data->{cpuset_path}.'/cpuset.mems; '.
            'cat '.$Cgroup_directory_collection_links.'/cpuset/cpuset.cpus > '.$Cgroup_directory_collection_links.'/cpuset'.$Job_data->{cpuset_path}.'/cpuset.cpus; '.
            '/bin/echo 1000 > '.$Cgroup_directory_collection_links.'/blkio'.$Job_data->{cpuset_path}.'/blkio.weight; ';
        print_log(4, "$bashcmd");
        if (system("bash -e -c '$bashcmd'")) {
            exit_myself(4,'Failed to create cgroup '.$Job_data->{cpuset_path});
        } else {
            print_log(4, "OK");
        }
        flock(LOCKFILE,LOCK_UN) or exit_myself(17,"flock failed: $!");
        close(LOCKFILE);
        print_log(4,"Unlocked $Lock_file.global");

        # Job cgroup/cpuset setup
        if ($Job_data->{cpuset_name} =~ /,j=X$/) {
            # need a look in case of extensible job
            print_log(4,"Locking extensible job using $Lock_file.$Job_data->{cpuset_name}");
            open(LOCKFILE,"> $Lock_file.$Job_data->{cpuset_name}") or exit_myself(16,"Failed to open extensible job lock file: $!");
            flock(LOCKFILE,LOCK_EX) or exit_myself(17,"flock failed: $!");
            print_log(4,"Locked extensible job using $Lock_file.$Job_data->{cpuset_name}");

            # retrieve data from existing extensible jobs 
            my $data_x;
            if (-e $Job_data_dir) {
                $data_x = get_extensible_jobs_data();
            } else {
                mkdir($Job_data_dir) or exit_myself(99,"Failed to create directory $Job_data_dir: $!\n");
            }

            # add data form the current job to the extensible job hash
            $data_x->{$Job_data->{job_id}} = $Job_data;
            # save data from the current job data to filesystem
            my $job_x_dir = "$Job_data_dir/$Job_x_dir_prefix$Job_data->{job_id}";
            my $job_x_data = "$job_x_dir/$Job_file_data";
            mkdir($job_x_dir) or exit_myself(99,"Failed to create directory: $job_x_dir\n");
            open(FILE, "> $job_x_data") or exit_myself(19,"Failed to create the data file $job_x_data");
            print(FILE Dumper($Job_data)) or exit_myself(19,"Failed to write to the data file $job_x_data");
            close(FILE);

            create_job_files($job_x_dir,$Job_data);
            create_job_files($Job_data_dir,values(%$data_x));

            my @job_cpulist = get_data_cpulist(values(%$data_x));
            print_log(4,"Extensible job cpulist: ".join(",",@job_cpulist)." (current: ".join(",",get_data_cpulist($Job_data)).")");
            configure_job_cpuset(\@job_cpulist);
            flock(LOCKFILE,LOCK_UN) or exit_myself(17,"flock failed: $!");
            close(LOCKFILE);
            print_log(4,"Unlocked extensible job using $Lock_file.$Job_data->{cpuset_name}");
        } else {
            # Normal job, no need for a lock here
            mkdir("$Job_data_dir") or exit_myself(99,"Failed to create directory: $Job_data_dir\n");
            my @job_cpulist = get_data_cpulist($Job_data);
            print_log(4,"Job cpulist: ".join(",",@job_cpulist));
            configure_job_cpuset(\@job_cpulist);
        }
    } else {
        # Handle the case where cpuset/cgroup are not in use
        mkdir("$Job_data_dir") or exit_myself(99,"Failed to create directory: $Job_data_dir\n");
    }

    # Create the job files (nodes file, resources file, environment variables)
    # The case of extensible jobs is handled above in the locked block
    if (not (defined($Job_data->{cpuset_path}) and ($Job_data->{cpuset_name} =~ /,j=X$/))) {
        create_job_files($Job_data_dir,$Job_data);
    }

    # Copy ssh key files
    if ($Job_data->{ssh_keys}->{private} ne "") {
        # private key
        if (open(PRIV,">","$Job_key_dir/key")) {
            chmod(0600,"$Job_key_dir/key");
            if (!print(PRIV $Job_data->{ssh_keys}->{private})) {
                unlink("$Job_key_dir/key");
                exit_myself(8,"Error writing $Job_key_dir/key");
            }
            close(PRIV);
        }else{
            exit_myself(7,"Error opening $Job_key_dir/key");
        }

        # public key
        if (open(PUB,"+<",$Ssh_authorized_keys)) {
            print_log(4,"Locking $Ssh_authorized_keys");
            flock(PUB,LOCK_EX) or exit_myself(17,"flock failed: $!");
            print_log(4,"Locked authorized_key $Ssh_authorized_keys");
            seek(PUB,0,0) or exit_myself(18,"seek failed: $!");
            my $out = "\n".$Job_data->{ssh_keys}->{public}."\n";
            while (<PUB>) {
                if ($_ =~ /environment=\"OAR_KEY=1\"/) {
                    # We are reading a OAR key
                    my ($oar_key) = $_ =~ /(?:ssh-dss|ssh-rsa)\s+([^\s^\n]+)/;
                    my ($curr_key) = $Job_data->{ssh_keys}->{public} =~ /(?:ssh-dss|ssh-rsa)\s+([^\s^\n]+)/;
                    if ($curr_key eq $oar_key) {
                        exit_myself(13,"Error: user's ssh key cannot be the same as oar's");
                    }
                    $out .= $_;
                }elsif ($_ =~ /environment=\"OAR_CPUSET=([\w\/]+)\"/) {
                    # Remove from authorized keys outdated keys (typically after a reboot)
                    if (-d "$Job_data->{oar_tmp_directory}/$1") {
                        $out .= $_;
                    }
                }else{
                    $out .= $_;
                }
            }
            if (!(seek(PUB,0,0) and print(PUB $out) and truncate(PUB,tell(PUB)))) {
                exit_myself(9,"Error writing $Ssh_authorized_keys");
            }
            flock(PUB,LOCK_UN) or exit_myself(17,"flock failed: $!");
            close(PUB);
            print_log(4,"Unlocked pub key $Ssh_authorized_keys");
        }else{
            unlink($Ssh_authorized_keys);
            exit_myself(10,"Error opening $Ssh_authorized_keys");
        }
    }
}elsif ($ARGV[0] eq "clean") {
    # delete ssh key files
    if ($Job_data->{ssh_keys}->{private} ne "") {
        # private key
        unlink("$Job_key_dir/key");

        # public key
        if (open(PUB,"+<", $Ssh_authorized_keys)) {
            print_log(4,"Locking $Ssh_authorized_keys");
            flock(PUB,LOCK_EX) or exit_myself(17,"flock failed: $!");
            print_log(4,"Locked $Ssh_authorized_keys");
            seek(PUB,0,0) or exit_myself(18,"seek failed: $!");
            #Change file on the fly
            my $out = "";
            while (<PUB>) {
                if (($_ ne "\n") and ($_ ne $Job_data->{ssh_keys}->{public})) {
                    $out .= $_;
                }
            }
            if (!(seek(PUB,0,0) and print(PUB $out) and truncate(PUB,tell(PUB)))) {
                exit_myself(12,"Error changing $Ssh_authorized_keys");
            }
            flock(PUB,LOCK_UN) or exit_myself(17,"flock failed: $!");
            close(PUB);
            print_log(4,"Unlocked $Ssh_authorized_keys");
        }else{
            exit_myself(11,"Error opening $Ssh_authorized_keys");
        }
    }

    # Clean cpuset on this node
    if (defined($Job_data->{cpuset_path})) {
        (-e $Job_data_dir) or exit_myself(99,"Error: Job directory does not exist: $Job_data_dir");
        if ($Job_data->{cpuset_name} =~ /,j=X$/) {
            print_log(4,"Locking extensible job using $Lock_file.$Job_data->{cpuset_name}");
            open(LOCKFILE,"> $Lock_file.$Job_data->{cpuset_name}") or exit_myself(16,"Failed to open extensible job lock file: $!");
            flock(LOCKFILE,LOCK_EX) or exit_myself(17,"flock failed: $!");
            print_log(4,"Locked extensible job using $Lock_file.$Job_data->{cpuset_name}");

            # remove current job's data file
            my $job_x_dir = "$Job_data_dir/$Job_x_dir_prefix$Job_data->{job_id}";
            my $job_x_data = "$job_x_dir/$Job_file_data";
            (-e $job_x_dir) or exit_myself(99,"Error: Job directory does not exist: $job_x_dir");
            (-e $job_x_data) or exit_myself(99,"Error: Job data file does not exist: $job_x_data");
            unlink($job_x_data) or exit_myself(99,"Failed to remove file: $job_x_data: $!");
            remove_job_files($job_x_dir);

            # retrieve data from remaining extensible jobs if any
            my $data_x = get_extensible_jobs_data();
            if (keys(%$data_x) > 0) {
                print_log(3,"Not killing any process since extensible jobs are running: ".join(", ",keys(%$data_x)));
                # update job files
                create_job_files($Job_data_dir, values(%$data_x));

                my @job_cpulist = get_data_cpulist(values(%$data_x));
                print_log(4,"Updated extensible job cpulist to: ".join(",",@job_cpulist));
                configure_job_cpuset(\@job_cpulist);
            } else {
                # no more extensible job, cleaning up everything
                print_log(3,"No more extensible job, cleaning up everything");
                unconfigure_job_cpuset();
                remove_job_files($Job_data_dir);
            }
            flock(LOCKFILE,LOCK_UN) or exit_myself(17,"flock failed: $!");
            close(LOCKFILE);
            print_log(4,"Unlocked extensible job using $Lock_file.$Job_data->{cpuset_name}");
        } else {
            unconfigure_job_cpuset();
        }
        # Create the job files (nodes file, resources file, environment variables)
        # The case of extensible jobs is handled above in the locked block
        if (not (defined($Job_data->{cpuset_path}) and ($Job_data->{cpuset_name} =~ /,j=X$/))) {
            remove_job_files($Job_data_dir);
        }

        # Locking around the cleanup of the cpuset for that user, to prevent a creation to occure at the same time
        # which would allow race condition for the user-based clean-up mechanism
        print_log(4,"Locking job user using $Lock_file.$Job_data->{user}");
        open(LOCKFILE,"> $Lock_file.$Job_data->{user}") or exit_myself(16,"Failed to open user lock file: $!");
        flock(LOCKFILE,LOCK_EX) or die "flock failed: $!\n";
        print_log(4,"Locked job user using $Lock_file.$Job_data->{user}");
        # user-based cleanup: do cleanup only if that is the last job of the user on that host.
        my @cpusets = ();
        if (opendir(DIR, $Cgroup_directory_collection_links.'/cpuset'.$Job_data->{cpuset_path}.'/')) {
            @cpusets = grep { /^oar.u=$Job_data->{user},/ } readdir(DIR);
            closedir DIR;
        } else {
          exit_myself(18,'Can\'t opendir: '.$Cgroup_directory_collection_links.'/cpuset'.$Job_data->{cpuset_path});
        }
        if ($#cpusets < 0) {
            # No other jobs on this node at this time
            my $useruid=getpwnam($Job_data->{user});
            my $ipcrm_args="";
            if (open(IPCMSG,"< /proc/sysvipc/msg")) {
                <IPCMSG>;
                while (<IPCMSG>) {
                    if (/^\s*\d+\s+(\d+)(?:\s+\d+) {5}\s+$useruid(?:\s+\d+) {6}/) {
                        $ipcrm_args .= " -q $1";
                        print_log(3,"Found IPC MSG for user $useruid: $1");
                    }
                }
                close (IPCMSG);
            } else {
                print_log(3,"Cannot open /proc/sysvipc/msg: $!");
            }
            if (open(IPCSHM,"< /proc/sysvipc/shm")) {
                <IPCSHM>;
                while (<IPCSHM>) {
                    if (/^\s*\d+\s+(\d+)(?:\s+\d+) {5}\s+$useruid(?:\s+\d+) {6}/) {
                        $ipcrm_args .= " -m $1";
                        print_log(3,"Found IPC SHM for user $useruid: $1");
                    }
                }
                close (IPCSHM);
            } else {
                print_log(3,"Cannot open /proc/sysvipc/shm: $!");
            }
            if (open(IPCSEM,"< /proc/sysvipc/sem")) {
                <IPCSEM>;
                while (<IPCSEM>) {
                    if (/^\s*[\d\-]+\s+(\d+)(?:\s+\d+) {2}\s+$useruid(?:\s+\d+) {5}/) {
                        $ipcrm_args .= " -s $1";
                        print_log(3,"Found IPC SEM for user $useruid: $1");
                    }
                }
                close (IPCSEM);
            } else {
                print_log(3,"Cannot open /proc/sysvipc/sem: $!");
            }
            if ($ipcrm_args) {
                print_log (3,"Purging SysV IPC: ipcrm $ipcrm_args");
                system("OARDO_BECOME_USER=$Job_data->{user} oardodo ipcrm $ipcrm_args"); 
            }
            print_log (3,"Purging @Dir_to_clean");
            system('for d in '."@Dir_to_clean".'; do
                        oardodo find $d -user '.$Job_data->{user}.' -delete
                        [ -x '.$Fstrim_cmd.' ] && oardodo '.$Fstrim_cmd.' $d > /dev/null 2>&1
                    done
                   ');
        } else {
            print_log(3,"Not purging SysV IPC and /tmp as $Job_data->{user} still has a job running on this host");
        }
        flock(LOCKFILE,LOCK_UN) or die "flock failed: $!\n";
        close(LOCKFILE);
        print_log(4,"Unlocked job user using $Lock_file.$Job_data->{user}");
    }
}else{
    exit_myself(3,"Bad command line argument $ARGV[0]");
}

exit(0);

# Print error message and exit
sub exit_myself($$) {
    my $exit_code = shift;
    my $str = shift;

    warn("[job_resource_manager_cgroups][$Job_data->{job_id}][$ENV{TAKTUK_HOSTNAME}] Error: ".$str."\n");
    exit($exit_code);
}

# Print log message depending on the LOG_LEVEL config value
sub print_log($$) {
    my $l = shift;
    my $str = shift;

    if ($l <= $Job_data->{log_level}) {
        warn("[$Job_data->{job_id}] [$ENV{TAKTUK_HOSTNAME}] $str\n");
    }
}

# return the total memory of the system
sub get_memtotal() {
    open(MEM, "< /proc/meminfo") or
        exit_myself(5,"Failed to retrieve the global memory from /proc/meminfo");
    my $mem_global_kb;
    while (my $line = <MEM>) {
        if ($line =~ /^MemTotal:\s+(\d+)\skB$/) {
            $mem_global_kb = $1 * 1024;
            last;
        }
    }
    close(MEM);
    defined($mem_global_kb) or
        exit_myself(5,"Failed to parse /proc/meminfo to retrive MemTotal");
    return $mem_global_kb;
}

# return an array with all the cpus of a cpuset, from the cpuset fs
# in scalare context: return the number of cpus (= $#cpulist+1)
sub get_cpuset_cpulist($) {
    my $cpuset_path = shift;
    open(CPUS, "< $cpuset_path/cpuset.cpus") or 
        exit_myself(5,"Failed to retrieve the cpulist of $cpuset_path");
    my $cpustr = <CPUS>;
    close(CPUS);
    chomp($cpustr);
    $cpustr =~ s/-/../g;
    my @cpulist= eval($cpustr);
    return @cpulist;
}

# return an array with all the cpus defined in one or more data structures
# e.g transform ("0,4","1,5","2,6","3,7") in (0,1,2,3,4,5,6,7) + make sure cpus are unique
# in scalare context: return the number of cpus (= $#cpulist+1)
sub get_data_cpulist(@) {
    my @cpulist;
    my $hash = {};
    foreach my $data (@_) {
        foreach my $cpu (map {s/\s*//g;split(",",$_)} @{$data->{nodes}->{$ENV{TAKTUK_HOSTNAME}}}) {
            $hash->{$cpu} = 1;
        }
    }
    @cpulist = sort(keys(%$hash));
    return @cpulist;
}

# return the data structures of all the existing extensible jobs
sub get_extensible_jobs_data() {
    my $data_x = {};
    opendir(DIR, $Job_data_dir) or exit_myself(18,"Failed to open directory $Job_data_dir: $!");
    foreach my $x (readdir(DIR)) {
        if (my ($job_id) = $x =~ /^$Job_x_dir_prefix(\d+)$/) {; 
            my $data_file = "$Job_data_dir/$x/$Job_file_data";
            open(FILE,"< $data_file") or exit_myself(99,"Failed to open file $data_file: $!");
            $slurp = do { local $/; <FILE> };
            $data_x->{$job_id} = eval ($slurp);
        }
    }
    closedir DIR;
    return $data_x;
}

# retrieve the nodes list from one or more data structures
# with as many duplicates as there are distinct resources (e.g. resource_ids)
sub get_job_nodes(@) {
    my $resource_node_hash = {};
    my $distinct_property;
    foreach my $data (@_) {
        if (not defined($distinct_property) or (defined($data->{property_distinct_resources}) and ($distinct_property ne $data->{property_distinct_resources}))) {
            foreach my $r (@{$data->{resources}}) {
                $resource_node_hash->{$r->{$data->{property_distinct_resources}}} = $r->{$data->{property_nodes}};
            }
        } else {
            print_log(2,"Warning: extensible job nodes could not be merged correctly");  
        }
    }
    return join("\n",values(%$resource_node_hash))."\n";
}

# retrieve the resources list from one or more data structures
# with merge if extensible job
sub get_job_resources(@) {
    my $resources_lines_hash = {};
    my $distinct_property;
    foreach my $data (@_) {
        if (not defined($distinct_property) or (defined($data->{property_distinct_resources}) and ($distinct_property eq $data->{property_distinct_resources}))) {
            $distinct_property = $data->{property_distinct_resources};
            foreach my $r (@{$data->{resources}}) {
                $resources_lines_hash->{$r->{$data->{property_distinct_resources}}} = join(",",map { "$_ = '$r->{$_}'" } keys(%$r));
            }
        } else {
            print_log(2,"Warning: extensible job resources could not be merged correctly");  
        }
    }
    return join("\n",values(%$resources_lines_hash))."\n";
}

# retrieve the env file of a job from one data structure
sub get_job_env($$) {
    my $dir=shift();
    my $data = shift;
    my $env = {};
    $env->{OAR_JOBID} = $data->{job_id};
    $env->{OAR_JOB_ID} = $data->{job_id};
    $env->{OAR_ARRAYID} = $data->{array_id};
    $env->{OAR_ARRAY_ID} = $data->{array_id};
    $env->{OAR_ARRAYINDEX} = $data->{array_index};
    $env->{OAR_ARRAY_INDEX} = $data->{array_index};
    $env->{OAR_USER} = $data->{user};
    $env->{OAR_JOB_NAME} = $data->{job_name};
    $env->{OAR_WORKDIR} = $data->{launching_directory};
    $env->{OAR_O_WORKDIR} = $data->{launching_directory};
    $env->{OAR_WORKING_DIRECTORY} = $data->{launching_directory};
    $env->{OAR_PROJECT_NAME} = $data->{project};
    $env->{OAR_STDOUT} = $data->{stdout_file};
    $env->{OAR_STDERR} = $data->{stderr_file};
    $env->{OAR_WALLTIME} = $data->{walltime};
    $env->{OAR_WALLTIME_SECONDS} = $data->{walltime_seconds};
    $env->{OAR_NODEFILE} = "$dir/$Job_file_nodes";
    $env->{OAR_NODE_FILE} = "$dir/$Job_file_nodes";
    $env->{OAR_FILE_NODES} = "$dir/$Job_file_nodes";
    $env->{OAR_RESOURCE_PROPERTIES_FILE} = "$dir/$Job_file_resources";
    $env->{OAR_RESOURCE_FILE} = "$dir/$Job_file_resources";
    my $bashcmd = "";
    foreach my $key (sort(keys(%$env))){
       $bashcmd .= "export $key='".$env->{$key}."'\n";
    }
    return $bashcmd;
}

# take an array and return an new array with only uniq values
sub uniq(@) {
    my $hash;
    map { $hash->{$_} = 1 } @_;
    return keys(%$hash);
}

# retrieve the env file from one or more data structures (extensible jobs)
sub get_job_env_x($@) {
    my $dir=shift();
    my $env = {};
    foreach my $data (@_) {
        my $job_id = $data->{job_id};
        $env->{OAR_JOBID}->{$job_id} = $job_id;
        $env->{OAR_JOB_ID}->{$job_id} = $job_id;
        $env->{OAR_ARRAYID}->{$job_id} = $data->{array_id};
        $env->{OAR_ARRAY_ID}->{$job_id} = $data->{array_id};
        $env->{OAR_ARRAYINDEX}->{$job_id} = $data->{array_index};
        $env->{OAR_ARRAY_INDEX}->{$job_id} = $data->{array_index};
        $env->{OAR_USER}->{$job_id} = $data->{user};
        $env->{OAR_JOB_NAME}->{$job_id} = $data->{job_name};
        $env->{OAR_WORKDIR}->{$job_id} = $data->{launching_directory};
        $env->{OAR_O_WORKDIR}->{$job_id} = $data->{launching_directory};
        $env->{OAR_WORKING_DIRECTORY}->{$job_id} = $data->{launching_directory};
        $env->{OAR_PROJECT_NAME}->{$job_id} = $data->{project};
        $env->{OAR_STDOUT}->{$job_id} = $data->{stdout_file};
        $env->{OAR_STDERR}->{$job_id} = $data->{stderr_file};
        $env->{OAR_WALLTIME}->{$job_id} = $data->{walltime};
        $env->{OAR_WALLTIME_SECONDS}->{$job_id} = $data->{walltime_seconds};
        $env->{OAR_NODEFILE}->{$job_id} = "$dir/$Job_x_dir_prefix$job_id/$Job_file_nodes";
        $env->{OAR_NODE_FILE}->{$job_id} = "$dir/$Job_x_dir_prefix$job_id/$Job_file_nodes";
        $env->{OAR_FILE_NODES}->{$job_id} = "$dir/$Job_x_dir_prefix$job_id/$Job_file_nodes";
        $env->{OAR_RESOURCE_PROPERTIES_FILE}->{$job_id} = "$dir/$Job_x_dir_prefix$job_id/$Job_file_resources";
        $env->{OAR_RESOURCE_FILE}->{$job_id} = "$dir/$Job_x_dir_prefix$job_id/$Job_file_resources";
        $env->{OAR_JOB_ENV_FILE}->{$job_id} = "$dir/$Job_x_dir_prefix$job_id/$Job_file_env";
    }
    my $bashcmd = "export OAR_X_JOB_ID=\"(".join(" ",map {"'$_'" } values(%{$env->{OAR_JOB_ID}})).")\"\n";
    my @users = uniq(values(%{$env->{OAR_USER}}));
    if (@users > 1) {
        exit_myself(99,"Extensible jobs cannot belong to different users: ".join(", ",@users));
    }
    $bashcmd .= "export OAR_USER='".$users[0]."'\n";
    delete($env->{OAR_USER});

    my @names = uniq(values(%{$env->{OAR_JOB_NAME}}));
    if (@names > 1) {
        exit_myself(99,"Extensible jobs cannot have different names: ".join(", ",@names));
    }
    $bashcmd .= "export OAR_JOB_NAME='".$names[0]."'\n";
    delete($env->{OAR_JOB_NAME});

    foreach my $var (keys(%$env)) {
        $bashcmd .= "unset $var\n";
    }
    $bashcmd .= <<EOS;
if [ \${SHELL##*/} == "bash" ] && [ -z "\$OAR_X_ENV_VAR" -o "\$OAR_X_ENV_VAR" == "yes" ]; then
  if [ -z "\$OAR_X_ENV_VAR" ]; then
    cat <<EOF
# Warning:
# OAR environment variables are set but won't be exported to child processes, 
# because data of extensible jobs are stored in bash arrays which cannot be exported. 
# Set "OAR_X_ENV_VAR=no" to get the basic variables only, but exported.
# Set "OAR_X_ENV_VAR=yes" to prevent the display of this message.
EOF
  fi
EOS
    # Warning: with bash arrays, a == a[0], but bash array cannot be exported
    foreach my $var (keys(%$env)) {
        while (my ($key,$value) = each(%{$env->{$var}})){
            $bashcmd .= "  $var"."[$key]='$value'\n";
        }
    }
    $bashcmd .= <<EOS;
  OAR_JOBID='X'
  OAR_JOB_ID='X'
  OAR_ARRAYID='X'
  OAR_ARRAY_ID='X'
  OAR_ARRAYINDEX='X'
  OAR_ARRAY_INDEX='X'
  OAR_NODEFILE='$dir/$Job_file_nodes'
  OAR_NODE_FILE='$dir/$Job_file_nodes'
  OAR_FILE_NODES='$dir/$Job_file_nodes'
  OAR_RESOURCE_PROPERTIES_FILE='$dir/$Job_file_resources'
  OAR_RESOURCE_FILE='$dir/$Job_file_resources'
  OAR_JOB_ENV_FILE='$dir/$Job_file_env'
  OAR_WORKDIR=\"\$HOME\"
  OAR_O_WORKDIR=\"\$HOME\"
  OAR_WORKING_DIRECTORY=\"\$HOME\"
  OAR_STDOUT='X'
  OAR_STDERR='X'
else
  export OAR_JOBID='X'
  export OAR_JOB_ID='X'
  export OAR_ARRAYID='X'
  export OAR_ARRAY_ID='X'
  export OAR_ARRAYINDEX='X'
  export OAR_ARRAY_INDEX='X'
  export OAR_NODEFILE='$dir/$Job_file_nodes'
  export OAR_NODE_FILE='$dir/$Job_file_nodes'
  export OAR_FILE_NODES='$dir/$Job_file_nodes'
  export OAR_RESOURCE_PROPERTIES_FILE='$dir/$Job_file_resources'
  export OAR_RESOURCE_FILE='$dir/$Job_file_resources'
  export OAR_JOB_ENV_FILE='$dir/$Job_file_env'
  export OAR_WORKDIR=\"\$HOME\"
  export OAR_O_WORKDIR=\"\$HOME\"
  export OAR_WORKING_DIRECTORY=\"\$HOME\"
  export OAR_STDOUT='X'
  export OAR_STDERR='X'
fi
EOS
    return $bashcmd;
}

# create the nodes, resources and env files.
# input can be one or more Data structues.
sub create_job_files($@) {
    my $dir = shift();
    my @data = @_;
    ( -e $dir ) or mkdir($dir) or exit_myself(99,"Failed to create the directory $dir: $!");

    # create the nodes file
    my $nodes_file = "$dir/$Job_file_nodes";
    print_log(4,"Create file $nodes_file");
    open(FILE, "> $nodes_file") or exit_myself(19,"Failed to create the nodes file $nodes_file: $!");
    print(FILE get_job_nodes(@data)) or exit_myself(19,"Failed to write to the nodes file $nodes_file: $!");
    close(FILE);

    # create resources file

    my $resources_file = "$dir/$Job_file_resources";
    print_log(4,"Create file $resources_file");
    open(FILE, "> $resources_file") or exit_myself(19,"Failed to create the resources file $resources_file");
    print(FILE get_job_resources(@data)) or exit_myself(19,"Failed to write to the resources file $resources_file");
    close(FILE);

    # create env file
    my $env_file = "$dir/$Job_file_env";
    print_log(4,"Create file $env_file");
    open(FILE, "> $env_file") or exit_myself(19,"Failed to create the env file $env_file");
    if ($dir =~ /X$/) {
        # extensible job main env file
        print(FILE get_job_env_x($dir,@data)) or exit_myself(19,"Failed to write to the env file $env_file");
    } elsif(@data == 1) {
        # here @data should only have one element
        print(FILE get_job_env($dir,shift(@data))) or exit_myself(19,"Failed to write to the env file $env_file");
    } else {
        exit_myself(99,"Unexepected error when generating the job env file\n");
    }
    close(FILE);
}

# remove job data files;
sub remove_job_files($) {
    my $dir = shift();

    my $nodes_file = "$dir/$Job_file_nodes";
    print_log(4,"Remove file $nodes_file");
    unlink($nodes_file) or exit_myself(99,"Failed to remove nodes file $nodes_file: $!");

    my $resources_file = "$dir/$Job_file_resources";
    print_log(4,"Remove file $resources_file");
    unlink($resources_file) or exit_myself(99,"Failed to remove resources file: $resources_file: $!");

    my $env_file = "$dir/$Job_file_env";
    print_log(4,"Remove file $env_file");
    unlink($env_file) or exit_myself(99,"Failed to remove env file: $env_file");

    print_log(4,"Remove dir $dir");
    rmdir($dir) or exit_myself(99,"Failed to remove directory $dir: $!");
}

# configure the cgroup filesystem for the job
sub configure_job_cpuset($) {
    my $job_cpulist = shift;
    my $bashcmd =
        'for d in '.$Cgroup_directory_collection_links.'/*; do '.
            'oardodo mkdir -p $d'.$Job_cpuset_dir.'; '.
            'oardodo chown -R oar $d'.$Job_cpuset_dir.'; '.
            '/bin/echo 0 > $d'.$Job_cpuset_dir.'/notify_on_release; '.
        'done; '.
        '/bin/echo 0 > '.$Cgroup_directory_collection_links.'/cpuset'.$Job_cpuset_dir.'/cpuset.cpu_exclusive; '.
        '/bin/echo '.join(",",@$job_cpulist).' > '.$Cgroup_directory_collection_links.'/cpuset'.$Job_cpuset_dir.'/cpuset.cpus; ';
    print_log(4, "$bashcmd");
    if (system("bash -e -c '$bashcmd'")) {
        exit_myself(4,'Failed to create cpuset '.$Job_cpuset_dir);
    } else {
        print_log(4, "ok");
    }
    # Compute and set the memory nodes for the extensible cpuset
    my @base_cpulist = get_cpuset_cpulist($Cgroup_directory_collection_links.'/cpuset/');
    $bashcmd =
        'shopt -s nullglob; '.
        'M=$(for f in /sys/devices/system/cpu/cpu{'.join(",",@$job_cpulist).',}/node*; do n=${f##*node}; a[$n]=$n; done; IFS=","; echo "${a[*]}"); '.
        '/bin/echo $M > '.$Cgroup_directory_collection_links.'/cpuset'.$Job_cpuset_dir.'/cpuset.mems; ';
    #my $io_ratio = sprintf("%.0f",@$job_cpulist / @base_cpulist * 1000) ;
    # TODO: Need to do more tests to validate so remove this feature
    #       Some values are not working when echoing
    #       => using default value for now
    my $io_ratio = 1000;
    $bashcmd .=
        '/bin/echo '.$io_ratio.' > '.$Cgroup_directory_collection_links.'/blkio'.$Job_cpuset_dir.'/blkio.weight; ';
    if ($ENABLE_MEMCG) {
        my $mem_kb = sprintf("%.0f", @$job_cpulist / @base_cpulist * get_memtotal());
        $bashcmd .=
            '/bin/echo '.$mem_kb.' > '.$Cgroup_directory_collection_links.'/memory'.$Job_cpuset_dir.'/memory.limit_in_bytes; ';
    }

    if ($ENABLE_DEVICESCG){
        my @devices_deny = ();
        opendir(my($dh), "/dev") or exit_myself(5,"Failed to open /dev to retrieve the nvidia devices");
        my @files = grep { /nvidia/ } readdir($dh);
        foreach (@files){
            if ($_ =~ /nvidia(\d+)/){
                push (@devices_deny, $1);
            }
        }
        closedir($dh);
        if (@devices_deny){
            # now remove from denied devices our reserved devices
            foreach my $r (@{$Job_data->{'resources'}}){
                if (($r->{type} eq "default") and
                    ($r->{network_address} eq "$ENV{TAKTUK_HOSTNAME}") and
                    ($r->{'gpudevice'} ne '')
                   ){
                    @devices_deny = grep { $_ !=  $r->{'gpudevice'} } @devices_deny;
                }
            }
            print_log(3,"Deny NVIDIA GPUs: @devices_deny");
            my $devices_cgroup = $Cgroup_directory_collection_links."/devices/".$Job_cpuset_dir."/devices.deny";
            foreach my $dev (@devices_deny){
                $bashcmd .= 'oardodo /bin/echo "c 195:'.$dev.' rwm" > $devices_cgroup';
            }
        }
    }

    print_log(4, "$bashcmd");
    if (system("bash -e -c '$bashcmd'")) {
        exit_myself(5,"Failed to set the cpuset.mems/blkio.weight/memory.limit/devices.deny");
    } else {
        print_log(4, "OK");
    }
}

# unconfigure the cgroup filesystem for the job
sub unconfigure_job_cpuset() {
    my $bashcmd = 
        'echo THAWED > '.$Cgroup_directory_collection_links.'/freezer'.$Job_cpuset_dir.'/freezer.state; '.
        'PROCESSES=$(< '.$Cgroup_directory_collection_links.'/cpuset'.$Job_cpuset_dir.'/tasks); '.
        'while [ "$PROCESSES" != "" ]; do '.
            'echo $PROCESSES | xargs echo "killing processes:"; '.
            'oardodo kill -9 $PROCESSES; '.
            'PROCESSES=$(< '.$Cgroup_directory_collection_links.'/cpuset'.$Job_cpuset_dir.'/tasks); '.
        'done; '.
        'if [ -w '.$Cgroup_directory_collection_links.'/cpuset'.$Job_cpuset_dir.'/memory.force_empty ]; then '.
            'echo 0 > '.$Cgroup_directory_collection_links.'/cpuset'.$Job_cpuset_dir.'/memory.force_empty; '.
        'fi; '.
        'rmdir '.$Cgroup_directory_collection_links.'/cpuset'.$Job_cpuset_dir.'; '.
        'for d in '.$Cgroup_directory_collection_links.'/*/'.$Job_cpuset_dir.'; do '.
            '[ -w $d/memory.force_empty ] && echo 0 > $d/memory.force_empty;' .
            'oardodo rmdir $d > /dev/null 2>&1; ' .
        'done; ';
    print_log(4, "$bashcmd");
    if (system("bash -c '$bashcmd'")) {
        exit_myself(6,"Failed to delete the cpuset $Job_cpuset_dir");
    } else {
        print_log(4, "OK");
    }
}

