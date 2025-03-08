# The job_resource_manager_cgroups script is a perl script that oar server
# deploys on nodes to manage cpusets, users, job keys, ...
#
# In this script some cgroup Linux features are incorporated:
#     - [cpuset]  Restrict the job processes to use only the reserved cores;
#                 And restrict the allowed memory nodes to those directly
#                 attached to the cores (see the command "numactl -H")
#     - [cpu]     Nothing is done with this cgroup feature. By default each
#                 cgroup have cpu.shares=1024 (no priority)
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
#     - [max_uptime] You can set '$max_uptime = <seconds>' to automaticaly
#                 reboot the node at the end of the last job past this uptime
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

# Set which memory nodes should be given to any job in the cpuset cgroup
# "all": all the memory nodes, even if the cpu which the memory node is attached to is not in the job
# "cpu": only the memory nodes associated to cpus which are in the job
my $Cpuset_cg_mem_nodes = "cpu";

# Directories where files of the job user will be deleted after the end of the
# job if there is not other running job of the same user on the node
my @Tmp_dir_to_clear = ('/tmp/.', '/dev/shm/.', '/var/tmp/.');

# SSD trim command path
my $Fstrim_cmd = "/sbin/fstrim";

# Directory where the cgroup mount points are linked to. Useful to have each
# cgroups in the same place with the same hierarchy.
my $Cgroup_directory_collection_links = "/dev/oar_cgroups_links";

# Max uptime for automatic reboot (disabled if 0)
my $max_uptime = 259200;

###############################################################################
# Script configuration end
###############################################################################

my $Old_umask = sprintf("%lo", umask());
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
open UPTIME, "/proc/uptime" or exit_myself(1, 'Failed to open /proc/uptime');
($uptime, ) = split(/\./, <UPTIME>);
close UPTIME;

my $tmp = "";
while (<STDIN>) {
    $tmp .= $_;
}
$Cpuset = eval($tmp);

if (!defined($Cpuset->{log_level})) {
    exit_myself(2, "Bad SSH hashtable transfered");
}
$Log_level = $Cpuset->{log_level};

# Features override per node
if (-e '/etc/oar/exclude_from_mem_cg') {
    $Enable_mem_cg = "NO";
    print_log(3, "File /etc/oar/exclude_from_mem_cg found. Force disabled mem cgroup.");
}
if (-e '/etc/oar/exclude_from_devices_isolation') {
    $Enable_devices_cg = "NO";
    print_log(3,
        "File /etc/oar/exclude_from_devices_isolation found. Force disabled GPU isolation.");
}
if (-e "/etc/oar/disable_numa_nodes") {
    $Cpuset_cg_mem_nodes = "all";
    print_log(3, "File /etc/oar/disable_numa_nodes found: all numa nodes will be allowed.");
}

my $Cpuset_path_job;
my @Cpuset_list;
# Systemd prefix is typically "oar" (CPUSET_PATH is typically "/oar")
my $Systemd_prefix = $Cpuset->{cpuset_path};
$Systemd_prefix =~ s#^/##;

# Get the data structure only for this node
if (defined($Cpuset->{cpuset_path})) {
    foreach my $l (@{ $Cpuset->{nodes}->{ $ENV{TAKTUK_HOSTNAME} } }) {
        push(@Cpuset_list, split(/[+,\s]+/, $l));
    }
}

my $Cpuset_user_id = getpwnam($Cpuset->{user});

my $Systemd_oar_slice = "$Systemd_prefix";
my $Systemd_user_slice = "$Systemd_oar_slice-u$Cpuset_user_id";
my $Systemd_job_slice = "$Systemd_user_slice-j$Cpuset->{job_id}";

my $Hwloc_pu = join(' ', map { "pu:$_" } @Cpuset_list);
my $Systemd_allowed_cpus_cmd = "hwloc-calc --cof systemd-dbus-api --pi $Hwloc_pu";
my $Systemd_allowed_memory_nodes_cmd = "hwloc-calc --nof systemd-dbus-api --pi $Hwloc_pu";

my $Cgroup_root_path;
open MOUNTS, '/proc/mounts' or exit_myself(3, 'Failed to open /proc/mounts.');
while (<MOUNTS>) {
    last if ($Cgroup_root_path) = /^[^ ]+ ([^ ]+) cgroup2 .*$/;
}
close MOUNTS;

my $Cgroup_oar_path = "$Cgroup_root_path/$Systemd_oar_slice.slice";
my $Cgroup_user_path = "$Cgroup_oar_path/$Systemd_user_slice.slice";
my $Cgroup_job_path = "$Cgroup_user_path/$Systemd_job_slice.slice";

my $Cgroup_oar_cpus_path = "$Cgroup_root_path/cpuset.cpus.effective";
my $Cgroup_job_cpus_path  = "$Cgroup_job_path/cpuset.cpus.effective";

print_log(3, "$ARGV[0]");
if ($ARGV[0] eq "init") {
###############################################################################
    # Node initialization: run on all the nodes of the job before the job starts
###############################################################################
    # Initialize cpuset for this node
    # First, create the tmp oar directory
    if (
        !(  ((-d $Cpuset->{oar_tmp_directory}) and (-O $Cpuset->{oar_tmp_directory})) or
            (mkdir($Cpuset->{oar_tmp_directory})))
    ) {
        exit_myself(13,
            "Directory $Cpuset->{oar_tmp_directory} does not exist and cannot be created");
    }

    if (defined($Cpuset->{cpuset_path})) {
        # SYSTEMD
        print_log(3, "Using systemd, cgroup fs already in place");

        # Be careful with the physical_package_id. Is it corresponding to the memory bank?
        # Locking around the creation of the cpuset for that user, to prevent race condition during the dirty-user-based cleanup
        if (open(LOCK, '>', $Cpuset_lock_file . $Cpuset->{user})) {
            flock(LOCK, LOCK_EX) or die "flock failed: $!\n";

            print_log(3, "Creating $Cpuset->{name} systemd slice");
            system_with_log(
                'oardodo busctl call -q org.freedesktop.systemd1 /org/freedesktop/systemd1 '
                . "org.freedesktop.systemd1.Manager StartUnit ss $Systemd_job_slice.slice fail"
                . ' && while oardodo busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1'
                . " org.freedesktop.systemd1.Manager ListJobs | grep -q $Systemd_job_slice; do sleep 0.1; done"
            ) and exit_myself(5, "Failed to create systemd slice $Systemd_job_slice.slice");
            system_with_log("oardodo test -d $Cgroup_job_path") and exit_myself(5, "Failed to create systemd slice $Systemd_job_slice.slice");
            print_log(4, "Systemd allowed cpus command: $Systemd_allowed_cpus_cmd");
            my $systemd_allowed_cpus_str = `$Systemd_allowed_cpus_cmd`;
            chomp($systemd_allowed_cpus_str);
            exit_myself(5, "Unexpected output from $Systemd_allowed_cpus_cmd") if ($systemd_allowed_cpus_str !~ /^ay 0x[[:xdigit:]]{4}( 0x[[:xdigit:]]{2})+$/);
            if ($Cpuset_cg_mem_nodes eq 'cpu') {
                print_log(4, "Systemd allowed memory nodes command: $Systemd_allowed_memory_nodes_cmd");
                my $systemd_allowed_memory_nodes_str = `$Systemd_allowed_memory_nodes_cmd`;
                chomp($systemd_allowed_memory_nodes_str);
                exit_myself(5, "Unexpected output from $Systemd_allowed_memory_nodes_cmd") if ($systemd_allowed_memory_nodes_str !~ /^ay 0x[[:xdigit:]]{4}( 0x[[:xdigit:]]{2})+$/);
                system_with_log(
                    'oardodo busctl call -q org.freedesktop.systemd1 /org/freedesktop/systemd1'
                    . ' org.freedesktop.systemd1.Manager SetUnitProperties'
                    . " 'sba(sv)' $Systemd_job_slice.slice 1 2"
                    . " AllowedCPUs $systemd_allowed_cpus_str"
                    . " AllowedMemoryNodes $systemd_allowed_memory_nodes_str"
                ) and exit_myself(5, "Failed to set AllowedCPUs and AllowedMemoryNodes properties of systemd $Systemd_job_slice.slice");
            } elsif ($Cpuset_cg_mem_nodes eq 'all') {
                system_with_log(
                    'oardodo busctl call -q org.freedesktop.systemd1 /org/freedesktop/systemd1 '
                    . ' org.freedesktop.systemd1.Manager SetUnitProperties'
                    . " 'sba(sv)' $Systemd_job_slice.slice 1 1"
                    . " AllowedCPUs $systemd_allowed_cpus_str"
                ) and exit_myself(5, "Failed to set AllowedCPUs property of systemd $Systemd_job_slice.slice");
            } else {
                exit_myself(5, "Unsupported cg mem nodes spec: $Cpuset_cg_mem_nodes");
            }
        }

        # Compute the actual job cpus (@Cpuset_list may not have the HT included, depending on the OAR resources definiton)
        my @job_cpus;
        if (open(CPUS, $Cgroup_job_cpus_path)) {
            my $str = <CPUS>;
            chop($str);
            $str =~ s/\-/\.\./g;
            @job_cpus = eval($str);
            close(CPUS);
        } else {
            exit_myself(5, "Failed to retrieve the cpu list of the job from $Cgroup_job_cpus_path");
        }

        # Get all the cpus of the node
        my @node_cpus;
        if (open(CPUS, $Cgroup_oar_cpus_path)) {
            my $str = <CPUS>;
            chop($str);
            $str =~ s/\-/\.\./g;
            @node_cpus = eval($str);
            close(CPUS);
        } else {
            exit_myself(5, "Failed to retrieve the cpu list of the node from $Cgroup_oar_cpus_path");
        }

        # Put a share for IO disk corresponding of the ratio between the number
        # of cpus of this cgroup and the number of cpus of the node
        if ($Enable_blkio_cg eq "YES") {
            # Not yet tested! (check if it works and if it has not the problems reported with cgroup v1).
            # Default value is 100 = IOWeight(1 logical cpu), max value is 10000 = IOWeight(all logical cpus)
            my $ioweight = int($#job_cpus * 9900 / $#node_cpus + 100);
            system_with_log(
                'oardodo busctl call -q org.freedesktop.systemd1 /org/freedesktop/systemd1 '
                . ' org.freedesktop.systemd1.Manager SetUnitProperties'
                . " 'sba(sv)' $Systemd_prefix-u$Cpuset_user_id-j$Cpuset->{job_id}.slice 1 1"
                . " IOWeight t $ioweight"
            ) and exit_myself(5, "Failed to set IOWweight property of systemd $Systemd_job_slice.slice");
        }

        # Manage GPU devices
        if ($Enable_devices_cg eq "YES") {
            if (grep { ($_->{type} eq "default") and
                ($_->{network_address} eq "$ENV{TAKTUK_HOSTNAME}") and
                exists($_->{'gpudevice'}) and
                ($_->{'gpudevice'} ne '') } @{ $Cpuset->{'resources'} }) {
                print_log(5, "GPU found on node $ENV{TAKTUK_HOSTNAME}");
                my @deny_dev_array;
                # Nvidia GPUs
                opendir(my $dh, "/dev") or exit_myself(5, "Failed opening /dev");
                push(@deny_dev_array, map { "/dev/$_" } grep { /^nvidia\d+$/ } readdir($dh));
                close($dh);

                # Nvidia vGPUs (MIG)
                # https://docs.nvidia.com/datacenter/tesla/mig-user-guide/#dev-based-nvidia-capabilities
                # nvidia-cap1 and nvidia-cap2 should always be denied (config and monitor)
                if (opendir(my $dh, "/dev/nvidia-caps")) {
                    push(@deny_dev_array, map { "/dev/nvidia-caps/$_" } grep { /^nvidia-cap\d+$/ } readdir($dh));
                    close($dh);
                }

                # AMD GPUs
                if (opendir(my $dh, "/dev/dri")) {
                    push(@deny_dev_array, map { "/dev/dri/$_" } grep { /^(?:card|renderD)\d+$/ } readdir($dh));
                    close($dh);
                }

                my %deny_dev_hash = map { $_ => 1 } @deny_dev_array;

                foreach my $r (@{ $Cpuset->{'resources'} }) {
                    if (($r->{type} eq "default") and
                        ($r->{network_address} eq "$ENV{TAKTUK_HOSTNAME}") and
                        exists($r->{'gpudevice'}) and
                        ($r->{'gpudevice'} ne '')) {
                        foreach my $dev (split(/[,+\s]+/, $r->{'gpudevice'})) {
                            delete(%deny_dev_hash{$dev});
                        }
                    }
                }
                system_with_log("oardodo /usr/lib/oar/oarcgdev $Cgroup_job_path " . join(" ", keys(%deny_dev_hash)))
                    and exit_myself(5, "Failed to deny access to devices in $Systemd_job_slice.slice");
            } else {
                print_log(5, "No GPU on node $ENV{TAKTUK_HOSTNAME}");
            }
        }    # if ($Enable_devices_cg eq "YES")

        # Assign the corresponding share of memory if memory cgroup enabled.
        if ($Enable_mem_cg eq "YES") {
            my $mem_total;
            if (open(MEM, "/proc/meminfo")) {
                while (<MEM>) {
                    if (/^MemTotal:\s+(\d+)\skB$/) {
                        $mem_total = $1 * 1024;
                        last;
                    }
                }
                close(MEM);
            } else {
                exit_myself(5, "Failed to retrieve the global memory from /proc/meminfo");
            }
            if (!defined($mem_total)) {
                exit_myself(5, "Failed to parse /proc/meminfo to retrive MemTotal")
            }
            my $mem = int(($#job_cpus + 1) * $mem_total / ($#node_cpus + 1));

            system_with_log(
                'oardodo busctl call -q org.freedesktop.systemd1 /org/freedesktop/systemd1 '
                . ' org.freedesktop.systemd1.Manager SetUnitProperties'
                . " 'sba(sv)' $Systemd_prefix-u$Cpuset_user_id-j$Cpuset->{job_id}.slice 1 1"
                . " MemoryMax t $mem"
            ) and exit_myself(5, "Failed to set MemoryMax property of systemd $Systemd_job_slice.slice");
        }    # End else ($Enable_mem_cg eq "YES")

        # Create file used in the user jobs (environment variables, node files, ...)
        ## Feed the node file
        my @tmp_res;
        my %tmp_already_there;
        foreach my $r (@{ $Cpuset->{resources} }) {
            if (($r->{ $Cpuset->{node_file_db_fields} } ne "") and ($r->{type} eq "default")) {
                if (($r->{ $Cpuset->{node_file_db_fields_distinct_values} } ne "") and
                    (
                        !defined(
                            $tmp_already_there{
                                $r->{ $Cpuset->{node_file_db_fields_distinct_values} } }))
                ) {
                    push(@tmp_res, $r->{ $Cpuset->{node_file_db_fields} });
                    $tmp_already_there{ $r->{ $Cpuset->{node_file_db_fields_distinct_values} } } =
                      1;
                }
            }
        }
        if (open(NODEFILE, "> $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}")) {
            foreach my $f (sort(@tmp_res)) {
                print(NODEFILE "$f\n") or
                  exit_myself(19,
                    "Failed to write in node file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}");
            }
            close(NODEFILE);
        } else {
            exit_myself(19,
                "Failed to create node file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}");
        }
        ## create resource set file
        if (open(RESFILE, "> $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources")) {
            foreach my $r (@{ $Cpuset->{resources} }) {
                my $line = "";
                foreach my $p (keys(%{$r})) {
                    $r->{$p} = "" if (!defined($r->{$p}));
                    $line .= " $p = '$r->{$p}' ,";
                }
                chop($line);
                print(RESFILE "$line\n") or
                  exit_myself(19,
                    "Failed to write in resource file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources"
                  );
            }
            close(RESFILE);
        } else {
            exit_myself(19,
                "Failed to create resource file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources"
            );
        }
        ## Write environment file
        if (open(ENVFILE, "> $Cpuset->{oar_tmp_directory}/$Cpuset->{name}.env")) {
            my $job_name = "";
            $job_name = $Cpuset->{job_name} if defined($Cpuset->{job_name});
            my $filecontent = <<"EOF";
export OAR_JOBID='$Cpuset->{job_id}'
export OAR_JOB_ID='$Cpuset->{job_id}'
export OAR_ARRAYID='$Cpuset->{array_id}'
export OAR_ARRAY_ID='$Cpuset->{array_id}'
export OAR_ARRAYINDEX='$Cpuset->{array_index}'
export OAR_ARRAY_INDEX='$Cpuset->{array_index}'
export OAR_USER='$Cpuset->{user}'
export OAR_WORKDIR='$Cpuset->{launching_directory}'
export OAR_O_WORKDIR='$Cpuset->{launching_directory}'
export OAR_WORKING_DIRECTORY='$Cpuset->{launching_directory}'
export OAR_JOB_NAME='$job_name'
export OAR_PROJECT_NAME='$Cpuset->{project}'
export OAR_STDOUT='$Cpuset->{stdout_file}'
export OAR_STDERR='$Cpuset->{stderr_file}'
export OAR_FILE_NODES='$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}'
export OAR_NODEFILE='$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}'
export OAR_NODE_FILE='$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}'
export OAR_RESOURCE_PROPERTIES_FILE='$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources'
export OAR_RESOURCE_FILE='$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources'
export OAR_JOB_WALLTIME='$Cpuset->{walltime}'
export OAR_JOB_WALLTIME_SECONDS='$Cpuset->{walltime_seconds}'
EOF
            print(ENVFILE "$filecontent") or exit_myself(19, "Failed to write in file ");
        } else {
            exit_myself(19, "Failed to create file ");
        }
    }

    # Copy ssh key files
    if ($Cpuset->{ssh_keys}->{private}->{key} ne "") {

        # private key
        if (open(PRIV, ">" . $Cpuset->{ssh_keys}->{private}->{file_name})) {
            chmod(0600, $Cpuset->{ssh_keys}->{private}->{file_name});
            if (!print(PRIV $Cpuset->{ssh_keys}->{private}->{key})) {
                unlink($Cpuset->{ssh_keys}->{private}->{file_name});
                exit_myself(8, "Error writing $Cpuset->{ssh_keys}->{private}->{file_name}");
            }
            close(PRIV);
        } else {
            exit_myself(7, "Error opening $Cpuset->{ssh_keys}->{private}->{file_name}");
        }

        # public key
        if (open(PUB, "+<", $Cpuset->{ssh_keys}->{public}->{file_name})) {
            flock(PUB, LOCK_EX) or exit_myself(17, "flock failed: $!");
            seek(PUB, 0, 0)     or exit_myself(18, "seek failed: $!");
            my $out = "\n" . $Cpuset->{ssh_keys}->{public}->{key} . "\n";
            while (<PUB>) {
                if ($_ =~ /environment=\"OAR_KEY=1\"/) {

                    # We are reading a OAR key
                    $_ =~ /(ssh-dss|ssh-rsa)\s+([^\s^\n]+)/;
                    my $oar_key = $2;
                    $Cpuset->{ssh_keys}->{public}->{key} =~ /(ssh-dss|ssh-rsa)\s+([^\s^\n]+)/;
                    my $curr_key = $2;
                    if ($curr_key eq $oar_key) {
                        exit_myself(13,
                            "ERROR: the user has specified the same ssh key than used by the user oar"
                        );
                    }
                    $out .= $_;
                } elsif ($_ =~ /environment=\"OAR_CPUSET=([\w\/]+)\"/) {

                    # Remove from authorized keys outdated keys (typically after a reboot)
                    if (-d "/dev/cpuset/$1") {
                        $out .= $_;
                    }
                } else {
                    $out .= $_;
                }
            }
            if (!(seek(PUB, 0, 0) and print(PUB $out) and truncate(PUB, tell(PUB)))) {
                exit_myself(9, "Error writing $Cpuset->{ssh_keys}->{public}->{file_name}");
            }
            flock(PUB, LOCK_UN) or exit_myself(17, "flock failed: $!");
            close(PUB);
        } else {
            unlink($Cpuset->{ssh_keys}->{private}->{file_name});
            exit_myself(10, "Error opening $Cpuset->{ssh_keys}->{public}->{file_name}");
        }
    }

###############################################################################
    # Node cleaning: run on all the nodes of the job after the job ends
###############################################################################

} elsif ($ARGV[0] eq "clean") {

    # delete ssh key files
    if ($Cpuset->{ssh_keys}->{private}->{key} ne "") {

        # private key
        unlink($Cpuset->{ssh_keys}->{private}->{file_name});

        # public key
        if (open(PUB, "+<", $Cpuset->{ssh_keys}->{public}->{file_name})) {
            flock(PUB, LOCK_EX) or exit_myself(17, "flock failed: $!");
            seek(PUB, 0, 0)     or exit_myself(18, "seek failed: $!");

            #Change file on the fly
            my $out = "";
            while (<PUB>) {
                if (($_ ne "\n") and ($_ ne $Cpuset->{ssh_keys}->{public}->{key})) {
                    $out .= $_;
                }
            }
            if (!(seek(PUB, 0, 0) and print(PUB $out) and truncate(PUB, tell(PUB)))) {
                exit_myself(12, "Error changing $Cpuset->{ssh_keys}->{public}->{file_name}");
            }
            flock(PUB, LOCK_UN) or exit_myself(17, "flock failed: $!");
            close(PUB);
        } else {
            exit_myself(11, "Error opening $Cpuset->{ssh_keys}->{public}->{file_name}");
        }
    }

    if (defined($Cpuset->{cpuset_path})) {
        # SYSTEMD
        # Kill tasks on this node
        print_log(2, "Systemd cleaning...");

        # Locking around the cleanup of the cpuset for that user, to prevent a creation to occur at the same time
        # which would allow race condition for the dirty-user-based clean-up mechanism
        if (open(LOCK, ">", $Cpuset_lock_file . $Cpuset->{user})) {
            flock(LOCK, LOCK_EX) or die "flock failed: $!\n";

            # (disabled as it caused timeouts... need more test with frozen cgroups)
            #system_with_log('oardodo systemctl thaw '.$Cpuset->{name}.'.slice')
            #  and exit_myself(6,'Failed to thaw processes of '.$Cpuset->{name}.'.slice');
            print_log(3, "Thawing $Cpuset->{name} systemd slice (resuming)");
            system_with_log(
                'oardodo busctl call -q org.freedesktop.systemd1 /org/freedesktop/systemd1 '
                . "org.freedesktop.systemd1.Manager ThawUnit s $Systemd_job_slice.slice"
            ) and exit_myself(6, "Failed to Thaw systemd $Systemd_job_slice.slice");

            print_log(3, "Killing $Cpuset->{name} systemd slice (killing processes)");
            system_with_log(
                'oardodo busctl call -q org.freedesktop.systemd1 /org/freedesktop/systemd1 '
                . "org.freedesktop.systemd1.Manager KillUnit ssi $Systemd_job_slice.slice all 9"
            ) and exit_myself(6, "Failed to kill systemd $Systemd_job_slice.slice");

            print_log(3, "Stopping $Cpuset->{name} systemd slice (removing)");
            system_with_log(
                'oardodo busctl call -q org.freedesktop.systemd1 /org/freedesktop/systemd1 '
                . "org.freedesktop.systemd1.Manager StopUnit ss $Systemd_job_slice.slice fail"
                . ' && while oardodo busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1'
                . " org.freedesktop.systemd1.Manager ListJobs | grep -q $Systemd_job_slice; do sleep 0.1; done"
            ) and exit_myself(6, "Failed to stop systemd $Systemd_job_slice.slice");
        }

       # dirty-user-based cleanup: do cleanup only if that is the last job of the user on that host.
        my $systemd_oar_units = `oardodo busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager ListUnitsByPatterns 'asas' 0 1 '$Systemd_oar_slice-u*-*'`;
        $systemd_oar_units =~ s/^[^\s]+\s+(\d+).*$/$1/;
        chomp $systemd_oar_units;
        print_log(4, "Systemd_oar_units: $systemd_oar_units");
        if ($systemd_oar_units < 1 and
            $max_uptime > 0 and
            $uptime > $max_uptime and
            not -e "/etc/oar/dont_reboot") {
            print_log(3, "Max uptime reached, rebooting node.");
            system_with_log('oardodo busctl call -q org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager Reboot');
            exit(0);
        }

        my $systemd_user_units = `oardodo busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager ListUnitsByPatterns 'asas' 0 1 '$Systemd_user_slice-*'`;
        $systemd_user_units =~ s/^[^\s]+\s+(\d+).*$/$1/;
        chomp $systemd_user_units;
        print_log(4, "Systemd_user_units: $systemd_user_units");
        if ($systemd_user_units < 1) {
            system_with_log(
                'oardodo busctl call -q org.freedesktop.systemd1 /org/freedesktop/systemd1 '
                . "org.freedesktop.systemd1.Manager StopUnit ss $Systemd_user_slice.slice fail"
            ) and exit_myself(6, "Failed to stop systemd $Systemd_user_slice.slice");
            my $ipcrm_args = "";
            if (open(IPCMSG, "< /proc/sysvipc/msg")) {
                <IPCMSG>;
                while (<IPCMSG>) {
                    if (/^\s*\d+\s+(\d+)(?:\s+\d+){5}\s+$Cpuset_user_id(?:\s+\d+){6}/) {
                        $ipcrm_args .= " -q $1";
                        print_log(3, "Found IPC MSG for user $Cpuset_user_id: $1.");
                    }
                }
                close(IPCMSG);
            } else {
                print_log(3, "Cannot open /proc/sysvipc/msg: $!.");
            }
            if (open(IPCSHM, "< /proc/sysvipc/shm")) {
                <IPCSHM>;
                while (<IPCSHM>) {
                    if (/^\s*\d+\s+(\d+)(?:\s+\d+){5}\s+$Cpuset_user_id(?:\s+\d+){6}/) {
                        $ipcrm_args .= " -m $1";
                        print_log(3, "Found IPC SHM for user $Cpuset_user_id: $1.");
                    }
                }
                close(IPCSHM);
            } else {
                print_log(3, "Cannot open /proc/sysvipc/shm: $!.");
            }
            if (open(IPCSEM, "< /proc/sysvipc/sem")) {
                <IPCSEM>;
                while (<IPCSEM>) {
                    if (/^\s*[\d\-]+\s+(\d+)(?:\s+\d+){2}\s+$Cpuset_user_id(?:\s+\d+){5}/) {
                        $ipcrm_args .= " -s $1";
                        print_log(3, "Found IPC SEM for user $Cpuset_user_id: $1.");
                    }
                }
                close(IPCSEM);
            } else {
                print_log(3, "Cannot open /proc/sysvipc/sem: $!.");
            }
            if ($ipcrm_args) {
                print_log(3, "Purging SysV IPC: ipcrm $ipcrm_args.");
                system_with_log("OARDO_BECOME_USER=$Cpuset->{user} oardodo ipcrm $ipcrm_args");
            }
            print_log(3, "Purging @Tmp_dir_to_clear.");
            system_with_log(
                "for d in @Tmp_dir_to_clear; do oardodo find " . '$d' . " -user $Cpuset->{user} -delete; "
                . "[ -x $Fstrim_cmd ] && oardodo $Fstrim_cmd " . '$d > /dev/null 2>&1; done'
            );
        } else {
            print_log(3,
                "Not purging SysV IPC and /tmp as $Cpuset->{user} still has a job running on this host."
            );
        }
        flock(LOCK, LOCK_UN) or die "flock failed: $!\n";
        close(LOCK);
    }
    print_log(3, "Remove file $Cpuset->{oar_tmp_directory}/$Cpuset->{name}.env");
    unlink("$Cpuset->{oar_tmp_directory}/$Cpuset->{name}.env");
    print_log(3, "Remove file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}");
    unlink("$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}");
    print_log(3, "Remove file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources");
    unlink("$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources");
} else {
    exit_myself(3, "Bad command line argument $ARGV[0]");
}

exit(0);

# Print error message and exit
sub exit_myself($$) {
    my $exit_code = shift;
    my $str       = shift;

    warn("[job_resource_manager][$Cpuset->{job_id}][$ENV{TAKTUK_HOSTNAME}][ERROR] $str\n");
    exit($exit_code);
}

# Print log message depending on the LOG_LEVEL config value
sub print_log($$) {
    my $l   = shift;
    my $str = shift;

    if ($l <= $Log_level) {
        print(
            "[job_resource_manager][$Cpuset->{job_id}][$ENV{TAKTUK_HOSTNAME}][INFO] $str\n"
        );
    }
}

# Run a command after printing it in the logs if OAR log level ≥ 4
sub system_with_log($) {
    my $command = shift;
    if (4 <= $Log_level) {

        # Remove extra leading spaces in the command for the log, but preserve indentation
        my $log                      = $command;
        my @leading_spaces_lenghts   = map { length($_) } ($log =~ /^( +)/mg);
        my $leading_spaces_to_remove = (sort { $a <=> $b } @leading_spaces_lenghts)[0];
        if (defined($leading_spaces_to_remove)) {
            $log =~ s/^ {$leading_spaces_to_remove}//mg;
        }
        print_log(4, "System command:\n" . $log);
    }
    return system($command);
}
