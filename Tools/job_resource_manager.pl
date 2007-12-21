# $Id$
# 
# The job_resource_manager script is a perl script that oar server deploys on nodes 
# to manage cpusets, users, job keys, ...
#
# Usage:
# Script is executed as oar
# ARGV[0] can have two different values:
#     - "init"  : then this script must create the right cpuset and assign
#                 corresponding cpus
#     - "clean" : then this script must kill all processes in the cpuset and
#                 clean the cpuset structure

# TAKTUK_HOSTNAME envirionment variable must be defined and must be a name
# that we will be able to find in the transfered hashtable.
use Fcntl ':flock';
#use Data::Dumper;

sub exit_myself($$);
sub print_log($$);

my $Old_umask = sprintf("%lo",umask());
umask(oct("022"));

my $Cpuset;
my $Log_level;

my $tmp = "";
while (<STDIN>){
    $tmp .= $_;
}
$Cpuset = eval($tmp);

if (!defined($Cpuset->{log_level})){
    exit_myself(2,"Bad SSH hashtable transfered");
}
$Log_level = $Cpuset->{log_level};
my $Cpuset_path;
my @Cpuset_cpus;
# Get the data structure only for this node
if (defined($Cpuset->{cpuset_path})){
    $Cpuset_path = $Cpuset->{cpuset_path}.'/'.$Cpuset->{name};
    @Cpuset_cpus = @{$Cpuset->{nodes}->{$ENV{TAKTUK_HOSTNAME}}};
}


# From now, "Cpuset" is of the form: 
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

print_log(3,"$ARGV[0]");
if ($ARGV[0] eq "init"){
    # Initialize cpuset for this node
    # First, create the tmp oar directory
    if (!(((-d $Cpuset->{oar_tmp_directory}) and (-O $Cpuset->{oar_tmp_directory})) or (mkdir($Cpuset->{oar_tmp_directory})))){
        exit_myself(13,"Directory $Cpuset->{oar_tmp_directory} does not exist and cannot be created");
    }

    if (defined($Cpuset->{job_uid})){
        my $prevuser = getpwuid($Cpuset->{job_uid});
        system("oardodo deluser --quiet $prevuser") if (defined($prevuser));
        my @tmp = getpwnam($Cpuset->{user});
        if ($#tmp < 0){
            exit_myself(15,"Cannot get information from user '$Cpuset->{user}'");
        }
        if (system("oardodo adduser --disabled-password --gecos 'OAR temporary user' --no-create-home --force-badname --quiet --home $tmp[7] --gid $tmp[3] --shell $tmp[8] --uid $Cpuset->{job_uid} $Cpuset->{job_user}")){
            exit_myself(15,"Failed to create $Cpuset->{job_user} with uid $Cpuset->{job_uid} and home $tmp[7] and group $tmp[3] and shell $tmp[8]");
        }
    }

    if (defined($Cpuset_path)){
        if (open(LOCKFILE,"> $Cpuset->{oar_tmp_directory}/job_manager_lock_file")){
            flock(LOCKFILE,LOCK_EX) or exit_myself(17,"flock failed: $!");
            if (system('oardodo mount -t cpuset | grep " /dev/cpuset " > /dev/null 2>&1')){
                if (system('oardodo mkdir -p /dev/cpuset && oardodo mount -t cpuset none /dev/cpuset')){
                    exit_myself(4,"Failed to mount cpuset pseudo filesystem");
                }
            }
            if (!(-d '/dev/cpuset/oar')){
                if (system( 'oardodo mkdir -p /dev/cpuset/'.$Cpuset->{cpuset_path}.' &&'. 
                            'oardodo chown -R oar /dev/cpuset/'.$Cpuset->{cpuset_path}.' &&'.
                            '/bin/echo 0 | cat > /dev/cpuset/'.$Cpuset->{cpuset_path}.'/notify_on_release && '.
                            '/bin/echo 0 | cat > /dev/cpuset/'.$Cpuset->{cpuset_path}.'/cpu_exclusive && '.
                            'cat /dev/cpuset/mems > /dev/cpuset/'.$Cpuset->{cpuset_path}.'/mems &&'.
                            'cat /dev/cpuset/cpus > /dev/cpuset/'.$Cpuset->{cpuset_path}.'/cpus'
                        )){
                    exit_myself(4,"Failed to create cpuset $Cpuset->{cpuset_path}");
                }
            }
            flock(LOCKFILE,LOCK_UN) or exit_myself(17,"flock failed: $!");
            close(LOCKFILE);
        }else{
            exit_myself(16,"Failed to open or create $Cpuset->{oar_tmp_directory}/job_manager_lock_file");
        }
#'for c in '."@Cpuset_cpus".';do cat /sys/devices/system/cpu/cpu$c/topology/physical_package_id > /dev/cpuset/'.$Cpuset_path.'/mems; done && '.

# Be careful with the physical_package_id. Is it corresponding to the memory banc?
        if (system( 'oardodo mkdir -p /dev/cpuset/'.$Cpuset_path.' && '.
                    'oardodo chown -R oar /dev/cpuset/'.$Cpuset_path.' && '.
                    '/bin/echo 0 | cat > /dev/cpuset/'.$Cpuset_path.'/notify_on_release && '.
                    '/bin/echo 0 | cat > /dev/cpuset/'.$Cpuset_path.'/cpu_exclusive && '.
                    'cat /dev/cpuset/mems > /dev/cpuset/'.$Cpuset_path.'/mems && '.
                    '/bin/echo '.join(",",@Cpuset_cpus).' | cat > /dev/cpuset/'.$Cpuset_path.'/cpus'
                  )){
            exit_myself(5,"Failed to create and feed the cpuset $Cpuset_path");
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
    if (defined($Cpuset_path)){
        system('PROCESSES=$(cat /dev/cpuset/'.$Cpuset_path.'/tasks)
                while [ "$PROCESSES" != "" ]
                do
                    oardodo kill -9 $PROCESSES
                    PROCESSES=$(cat /dev/cpuset/'.$Cpuset_path.'/tasks)
                done'
              );

        if (system('oardodo rmdir /dev/cpuset'.$Cpuset_path)){
            # Uncomment this line if you want to use several network_address properties
            # which are the same physical computer (linux kernel)
            #exit(0);
            exit_myself(6,"Failed to delete the cpuset $Cpuset_path");
        }
    }
    if (defined($Cpuset->{job_uid})){
        print_log(3,"Purging /tmp...");
        system("sudo find /tmp -user $Cpuset->{job_user} -exec rm -rfv {} \\;");
        my $ipcrm_args="";
        if (open(IPCMSG,"< /proc/sysvipc/msg")) {
            <IPCMSG>;
            while (<IPCMSG>) {
                if (/\s+\d+\s+(\d+)(?:\s+\d+){5}\s+$Cpuset->{job_uid}(?:\s+\d+){6}$/) {
                    $ipcrm_args .= " -q $1";
                }
            }
            close (IPCMSG);
        }else{
            exit_myself(14,"Cannot open /proc/sysvipc/msg: $!");
        }
        if (open(IPCSHM,"< /proc/sysvipc/shm")) {
            <IPCSHM>;
            while (<IPCSHM>) {
                if (/\s+\d+\s+(\d+)(?:\s+\d+){5}\s+$Cpuset->{job_uid}(?:\s+\d+){6}$/) {
                    $ipcrm_args .= " -m $1";
                }
            }
            close (IPCSHM);
        }else{
            exit_myself(14,"Cannot open /proc/sysvipc/shm: $!");
        }
        if (open(IPCSEM,"< /proc/sysvipc/sem")) {
            <IPCSEM>;
            while (<IPCSEM>) {
                if (/\s+\d+\s+(\d+)(?:\s+\d+){2}\s+$Cpuset->{job_uid}(?:\s+\d+){5}$/) {
                    $ipcrm_args .= " -s $1";
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
        system("oardodo deluser --quiet $Cpuset->{job_user}");
    }
}else{
    exit_myself(3,"Bad command line argument $ARGV[0]");
}

exit(0);

# Print error message and exit
sub exit_myself($$){
    my $exit_code = shift;
    my $str = shift;

    warn("[job_resource_manager][$Cpuset->{job_id}][ERROR] ".$str."\n");
    exit($exit_code);
}

# Print log message depending on the LOG_LEVEL config value
sub print_log($$){
    my $l = shift;
    my $str = shift;

    if ($l <= $Log_level){
        print("[job_resource_manager][$Cpuset->{job_id}][DEBUG] $str\n");
    }
}

