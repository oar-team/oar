# The job resource manager script is a perl script that oar server deploys on
# nodes to manage cpusets, users, job keys, ...
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
sub logstr($$);

my $Old_umask = sprintf("%lo",umask());
umask(oct("022"));

my $Cpuset;
my $Log_level;
my $Cpuset_lock_file = "$ENV{HOME}/cpuset.lock.";

# Retrieve parameters from STDIN in the "Cpuset" structure which looks like:
# $Cpuset = {
#               job_id => id of the corresponding job,
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
    @Cpuset_cpus = map {s/\s*//g;split(/","/,$_)} @{$Cpuset->{nodes}->{$ENV{TAKTUK_HOSTNAME}}};
}



print_log(3,"$ARGV[0]\n");
if ($ARGV[0] eq "init"){
    # Initialize cpuset for this node
    # First, create the tmp oar directory
    if (!(((-d $Cpuset->{oar_tmp_directory}) and (-O $Cpuset->{oar_tmp_directory})) or (mkdir($Cpuset->{oar_tmp_directory})))){
        exit_myself(13,"Directory $Cpuset->{oar_tmp_directory} does not exist and cannot be created");
    }

    if (defined($Cpuset_path_job)){
        if (open(LOCKFILE,"> $Cpuset->{oar_tmp_directory}/job_manager_lock_file")){
            flock(LOCKFILE,LOCK_EX) or exit_myself(17,"flock failed: $!");
            if (system('oardodo grep " /dev/cpuset " /proc/mounts > /dev/null 2>&1')){
                if (system('oardodo mkdir -p /dev/cpuset && oardodo mount -t cpuset none /dev/cpuset')){
                    exit_myself(4,"Failed to mount cpuset pseudo filesystem");
                }
            }
            # if (!(-d '/dev/cpuset/'.$Cpuset->{cpuset_path})){
                my $bashcmd='oardodo mkdir -p /dev/cpuset/'.$Cpuset->{cpuset_path}.' && '.
                            'oardodo chown -R oar /dev/cpuset/'.$Cpuset->{cpuset_path}.' &&'.
                            '/bin/echo 0  > /dev/cpuset/'.$Cpuset->{cpuset_path}.'/notify_on_release && '.
                            '/bin/echo 0  > /dev/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.cpu_exclusive && '.
                            'cat /dev/cpuset/cpuset.mems > /dev/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.mems &&'.
                            'cat /dev/cpuset/cpuset.cpus > /dev/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.cpus &&'.
                            'C="'.join(",",@Cpuset_cpus).'" &&';
                if ($Cpuset_path_job =~ /,j=X$/) {
                    $bashcmd.=
                            'mkdir -p /dev/cpuset/'.$Cpuset_path_job.'/oar.j='.$Cpuset->{job_id}.' &&'.
                            'CX=$(< /dev/cpuset/'.$Cpuset_path_job.'/cpuset.cpus) &&' .
                            '/bin/echo ${CX:+$CX,}$C > /dev/cpuset/'.$Cpuset_path_job.'/cpuset.cpus &&' .
                            '/bin/echo $C > /dev/cpuset/'.$Cpuset_path_job.'/oar.j='.$Cpuset->{job_id}.'/cpuset.cpus &&' .
                            'cat /dev/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.mems > /dev/cpuset/'.$Cpuset_path_job.'/cpuset.mems && '.
                            'cat /dev/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.mems > /dev/cpuset/'.$Cpuset_path_job.'/oar.j='.$Cpuset->{job_id}.'/cpuset.mems';
                } else {
                    $bashcmd.=
                            'mkdir -p /dev/cpuset/'.$Cpuset_path_job.' &&'.
                            '/bin/echo $C > /dev/cpuset/'.$Cpuset_path_job.'/cpuset.cpus &&' .
                            'cat /dev/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.mems > /dev/cpuset/'.$Cpuset_path_job.'/cpuset.mems';
                }
                print_log(4, "$bashcmd\n");
                if (system("bash -c '$bashcmd'")){
                    exit_myself(4,'Failed to create cpuset '.$Cpuset->{cpuset_path}.'/oar.user='.$Cpuset->{user}.'/oar.name='.$Cpuset->{job_name}.'/oar.jobid='.$Cpuset->{job_id});
                }
            #}
            flock(LOCKFILE,LOCK_UN) or exit_myself(17,"flock failed: $!");
            close(LOCKFILE);
        }else{
            exit_myself(16,"Failed to open or create $Cpuset->{oar_tmp_directory}/job_manager_lock_file");
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
        if (open(LOCK,">", $Cpuset_lock_file.$Cpuset->{user})){
            flock(LOCK,LOCK_EX) or die "flock failed: $!\n";
            if ($Cpuset_path_job =~ /,j=X$/) {
                my $bashcmd = 
                    'J=$(find /dev/cpuset/'.$Cpuset_path_job.' -type d -name "oar.j=*" -a \! -name "oar.j='.$Cpuset->{job_id}.'");'.
                    'if [ -z "$J" ]; then'.
                    '  PROCESSES=$(cat /dev/cpuset/'.$Cpuset_path_job.'/tasks);'.
                    '  while [ "$PROCESSES" != "" ]; do'.
                    '      echo $PROCESSES | xargs echo "killing processes:";'.
                    '      oardodo kill -9 $PROCESSES;'.
                    '      PROCESSES=$(cat /dev/cpuset/'.$Cpuset_path_job.'/tasks);'.
                    '  done;'.
                    'else'.
                    '  echo $J |grep -o "j=[[:digit:]]\+" |xargs echo "Not killing processes, extensible jobs still running:";'.
                    'fi &&'.
                    'rmdir /dev/cpuset'.$Cpuset_path_job.'/oar.j='.$Cpuset->{job_id}.' &&'.
                    'shopt -s nullglob &&'.
                    'C="" && for f in /dev/cpuset'.$Cpuset_path_job.'/oar.j=*/cpuset.cpus; do'.
                    '  C=${C:+$C,}$(< $f);'.
                    'done &&'.
                    'if [ -n "$C" ]; then'.
                    '  while ! /bin/echo $C 2> /dev/null > /dev/cpuset'.$Cpuset_path_job.'/cpuset.cpus; do'.
                    '    sleep 0.05;'.
                    '  done;'.
                    'else'.
                    '  rmdir /dev/cpuset'.$Cpuset_path_job.';'.
                    'fi';
                print_log(4, "$bashcmd\n");
                if (system("bash -c '$bashcmd'")){
                    exit_myself(6,"Failed to clear the cpuset $Cpuset_path_job");
                }
            } else {
                my $bashcmd = 
                    'PROCESSES=$(cat /dev/cpuset/'.$Cpuset_path_job.'/tasks);'.
                    'while [ "$PROCESSES" != "" ]; do'.
                    '  echo "killing processes: $PROCESSES";'.
                    '  oardodo kill -9 $PROCESSES;'.
                    '  PROCESSES=$(cat /dev/cpuset/'.$Cpuset_path_job.'/tasks);'.
                    'done && '.
                    'rmdir /dev/cpuset'.$Cpuset_path_job;
                print_log(4, "$bashcmd\n");
                if (system("bash -c '$bashcmd'")){
                    exit_myself(6,"Failed to clear the cpuset $Cpuset_path_job");
                }
            }
            if (not defined($Cpuset->{job_uid})){
                # dirty-user-based cleanup: do cleanup only if that is the last job of the user on that host.
                my @cpusets = ();
                if (not -e '/dev/cpuset/'.$Cpuset->{cpuset_path}.'/oar.user='.$Cpuset->{user}) {
                    # No other jobs for user on this node at this time
                    my $useruid=getpwnam($Cpuset->{user});
                    my $ipcrm_args="";
                    if (open(IPCMSG,"< /proc/sysvipc/msg")) {
                        <IPCMSG>;
                        while (<IPCMSG>) {
                            if (/^\s*\d+\s+(\d+)(?:\s+\d+){5}\s+$useruid(?:\s+\d+){6}/) {
                                $ipcrm_args .= " -q $1";
                                print_log(3,"Found IPC MSG for user $useruid: $1\n");
                            }
                        }
                        close (IPCMSG);
                    } else {
                        print_log(3,"Cannot open /proc/sysvipc/msg: $!\n");
                    }
                    if (open(IPCSHM,"< /proc/sysvipc/shm")) {
                        <IPCSHM>;
                        while (<IPCSHM>) {
                            if (/^\s*\d+\s+(\d+)(?:\s+\d+){5}\s+$useruid(?:\s+\d+){6}/) {
                                $ipcrm_args .= " -m $1";
                                print_log(3,"Found IPC SHM for user $useruid: $1\n");
                            }
                        }
                        close (IPCSHM);
                    } else {
                        print_log(3,"Cannot open /proc/sysvipc/shm: $!\n");
                    }
                    if (open(IPCSEM,"< /proc/sysvipc/sem")) {
                        <IPCSEM>;
                        while (<IPCSEM>) {
                            if (/^\s*[\d\-]+\s+(\d+)(?:\s+\d+){2}\s+$useruid(?:\s+\d+){5}/) {
                                $ipcrm_args .= " -s $1";
                                print_log(3,"Found IPC SEM for user $useruid: $1\n");
                            }
                        }
                        close (IPCSEM);
                    } else {
                        print_log(3,"Cannot open /proc/sysvipc/sem: $!.")."\n";
                    }
                    if ($ipcrm_args) {
                        print_log (3,"Purging SysV IPC: ipcrm $ipcrm_args\n");
                        system("OARDO_BECOME_USER=$Cpuset->{user} oardodo ipcrm $ipcrm_args");
                    }
                    print_log (3,"Purging /tmp /dev/shm /var/tmp...\n");
                    system("oardodo find /tmp/. /dev/shm/. /var/tmp/. -user $Cpuset->{user} -delete");
                } else {
                    print_log(2,"Not purging SysV IPC and files in /tmp, /dev/shm and /var/tmp because $Cpuset->{user} still has a job running on this host\n");
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
                    print_log(3,"Cannot parse IPC MSG: $_\n");
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
                    print_log(3,"Cannot parse IPC SHM: $_\n");
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
                    print_log(3,"Cannot parse IPC SEM: $_\n");
                }
            }
            close (IPCSEM);
        }else{
            exit_myself(14,"Cannot open /proc/sysvipc/sem: $!");
        }
        if ($ipcrm_args) {
            print_log(3,"Purging SysV IPC: ipcrm $ipcrm_args\n");
            if(system("oardodo ipcrm $ipcrm_args")){
                exit_myself(14,"Failed to purge IPC: ipcrm $ipcrm_args");
            }
        }
        print_log(3,"Purging /tmp, /dev/shm and /var/tmp...\n");
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

    warn("[job_resource_manager][$Cpuset->{job_id}][ERROR] ".$str."\n");
    exit($exit_code);
}

# Print log message depending on the LOG_LEVEL config value
sub print_log($$){
    my $l = shift;
    my $str= shift;
    my $logstr=logstr($l,$str);
    defined($logstr) and print $logstr;
}
sub logstr($$){
    my $l = shift;
    my $str = shift;
    ($l <= $Log_level) and return("[job_resource_manager][$Cpuset->{job_id}][DEBUG] $str");
}

