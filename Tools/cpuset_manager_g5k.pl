# $Id$
# 
# The cpuset_manager script is a perl script that oar server deploys on nodes 
# to manage cpusets
# In addition this version open ssh access on the nodes if the special job type
# (see $Allow_SSH_type var) is used and if the related job only uses whole
# nodes.
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
use strict;
use Fcntl ':flock';
use Data::Dumper;

# Constants
use constant LOGMSG => qw( error info debug );
use constant {
    ERROR => 1,
    INFO => 2,
    DEBUG => 3,
};
use constant {
    OK => 0,
    PARAMS => 1,
    FILE => 2,
    LOCK => 3,
    CPUSET => 4,
    SSH => 5
};

my $Cpuset;
my $Log_level;
my $Cpuset_path = "oar";
my $Allow_SSH_type = "allow_classic_ssh";
die "Invalid cpuset_path: $Cpuset_path.\n" if $Cpuset_path =~ /\//;
my $Security_pam_file = "$ENV{HOME}/access.conf";
my $Security_pam_file_tmp = "$ENV{HOME}/access.conf.tmp";
my $Cpuset_lock_file = "$ENV{HOME}/cpuset.lock.";

my $tmp = "";
while (<STDIN>){
    $tmp .= $_;
}
$Cpuset = eval($tmp);
$Log_level = $Cpuset->{log_level};

if (!defined $Log_level) {
    warn("[error] bad parameter structure\n");
    exit(PARAMS);
}

# message functions
sub message(@) {
    my $level=shift();
    if ($level <= $Log_level) {
        warn("[".(LOGMSG)[$level]."] ",@_);
    }
}


# Get the data structure only for this node
my $Cpuset_name = $Cpuset->{name};
my @Cpuset_cpus = @{$Cpuset->{nodes}->{$ENV{TAKTUK_HOSTNAME}}};
if (!defined($Cpuset_name)){
    message(ERROR,"bad parameter structure\n");
    exit(PARAMS);
}

# From now, "Cpuset" is of the form: 
# $Cpuset = {
#               name => "cpuset name",
#               nodes => hostname => [array with all cpus of this cpuset]
#           }
#
# $Cpuset_name is the name of the cpuset
# @Cpuset_cpus is the list of the cpuset DB field for this host

if ($ARGV[0] eq "init"){
    # Initialize cpuset for this node
    # First, create the tmp oar directory
    if (!(((-d $Cpuset->{oar_tmp_directory}) and (-O $Cpuset->{oar_tmp_directory})) or (mkdir($Cpuset->{oar_tmp_directory})))){
        message(ERROR,"directory $Cpuset->{oar_tmp_directory} does not exist and cannot be created\n");
        exit(FILE);
    }

    message(DEBUG,"name = $Cpuset_name ; cpus = @Cpuset_cpus\n");
    
    if (open(LOCKFILE,"> $Cpuset->{oar_tmp_directory}/job_manager_lock_file")){
        if (! flock(LOCKFILE,LOCK_EX)) {
            message(ERROR,"flock failed: $!\n"));
            exit(LOCK);
        }
        if (system('sudo mount -t cpuset | grep " /dev/cpuset " > /dev/null 2>&1')){
            if (system('sudo mkdir -p /dev/cpuset && sudo mount -t cpuset none /dev/cpuset 2> /dev/null')){
                message(ERROR,"system cpuset initialization failed: $!\n"));
                exit(CPUSET);
            }
        }
        if (!(-d '/dev/cpuset/'.$Cpuset_path)){
            if (system( 'sudo mkdir -p /dev/cpuset/'.$Cpuset_path.' &&'. 
                        'sudo chown -R oar /dev/cpuset/'.$Cpuset_path.' &&'.
                        '/bin/echo 0 | cat > /dev/cpuset/'.$Cpuset_path.'/notify_on_release && '.
                        '/bin/echo 0 | cat > /dev/cpuset/'.$Cpuset_path.'/cpu_exclusive && '.
                        'cat /dev/cpuset/mems > /dev/cpuset/'.$Cpuset_path.'/mems &&'.
                        'cat /dev/cpuset/cpus > /dev/cpuset/'.$Cpuset_path.'/cpus'
                      )){
                message(ERROR,"job cpuset initialization failed: $!\n"));
                exit(CPUSET);
            }
        }
        if (! flock(LOCKFILE,LOCK_UN)) {
           message(ERROR,"flock failed: $!\n");
           exit(LOCK);
        }
        close(LOCKFILE);
    }else{
        message(ERROR,"failed to open or create $Cpuset->{oar_tmp_directory}/job_manager_lock_file $!\n");
        exit(LOCK);
    }
    
#'for c in '."@Cpuset_cpus".';do cat /sys/devices/system/cpu/cpu$c/topology/physical_package_id > /dev/cpuset/'.$Cpuset_name.'/mems; done && '.

    if (open(LOCKFILE,">", $Cpuset_lock_file.$Cpuset->{user})){
        if (! flock(LOCKFILE,LOCK_EX)) {
            message(ERROR,"flock failed: $!\n"));
            exit(LOCK);
        }
# Be careful with the physical_package_id. Is it corresponding to the memory bank?
        if (system( 'sudo mkdir -p /dev/cpuset/'.$Cpuset_path.'/'.$Cpuset_name.' && '.
                    'sudo chown -R oar /dev/cpuset/'.$Cpuset_path.'/'.$Cpuset_name.' && '.
                    '/bin/echo 0 | cat > /dev/cpuset/'.$Cpuset_path.'/'.$Cpuset_name.'/notify_on_release && '.
                    '/bin/echo 0 | cat > /dev/cpuset/'.$Cpuset_path.'/'.$Cpuset_name.'/cpu_exclusive && '.
                    'cat /dev/cpuset/mems > /dev/cpuset/'.$Cpuset_path.'/'.$Cpuset_name.'/mems && '.
                    '/bin/echo '.join(",",@Cpuset_cpus).' | cat > /dev/cpuset/'.$Cpuset_path.'/'.$Cpuset_name.'/cpus'
                  )){
            exit(CPUSET);
        }
        if (! flock(LOCKFILE,LOCK_UN)) {
           message(ERROR,"flock failed: $!\n");
           exit(LOCK);
        }
        close(LOCKFILE);
    }else{
        message(ERROR,"failed to open $Cpuset_lock_file $!\n");
        exit(LOCK);
    }

    # PAM part
    if (!defined($Cpuset->{types}->{timesharing})){
        my $file_str = "# File generated by OAR.\n";
        if (defined($Cpuset->{types}->{$Allow_SSH_type}) and ! system('diff /dev/cpuset/'.$Cpuset_path.'/'.$Cpuset_name.'/cpus /dev/cpuset/'.$Cpuset_path.'/cpus > /dev/null 2>&1')){
            $file_str .= "+:".$Cpuset->{user}.":ALL\n";
        }
        $file_str .= "-:ALL:ALL\n";
        if (open(ACCESS, "> $Security_pam_file_tmp")){
            print(ACCESS "$file_str");
            close(ACCESS);
        }else{
            message(ERROR,"failed to open $Security_pam_file_tmp: $!\n");
            exit(FILE);
        }
        if (! rename($Security_pam_file_tmp,$Security_pam_file)) {
            message(ERROR,"cannot replace access.conf file: $!\n";
            exit(FILE);
        }
    }
    # PAM part

    # Copy ssh key files
    if ($Cpuset->{ssh_keys}->{private}->{key} ne ""){
        # private key
        if (open(PRIV, ">".$Cpuset->{ssh_keys}->{private}->{file_name})){
            chmod(0600,$Cpuset->{ssh_keys}->{private}->{file_name});
            if (!print(PRIV $Cpuset->{ssh_keys}->{private}->{key})){
                message(ERROR,"failed to write $Cpuset->{ssh_keys}->{private}->{file_name}\n");
                unlink($Cpuset->{ssh_keys}->{private}->{file_name});
                exit(FILE);
            }
            close(PRIV);
        }else{
            message(ERROR,"failed to open $Cpuset->{ssh_keys}->{private}->{file_name}\n");
            exit(FILE);
        }

        # public key
        if (open(PUB,"+<",$Cpuset->{ssh_keys}->{public}->{file_name})){
            if (! flock(PUB,LOCK_EX)) {
                message(ERROR, "flock failed: $!\n");
                exit(LOCK);
            }
            my $out = "\n".$Cpuset->{ssh_keys}->{public}->{key}."\n";
            while (<PUB>){
                if ($_ =~ /environment=\"OAR_KEY=1\"/){
                    # We are reading a OAR key
                    $_ =~ /(ssh-dss|ssh-rsa)\s+([^\s^\n]+)/;
                    my $oar_key = $2;
                    $Cpuset->{ssh_keys}->{public}->{key} =~ /(ssh-dss|ssh-rsa)\s+([^\s^\n]+)/;
                    my $curr_key = $2;
                    if ($curr_key eq $oar_key){
                        message(ERROR,"user specified the same ssh key as the one used by the oar user.\n");
                        exit(SSH);
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
                message(ERROR,"failed to write $Cpuset->{ssh_keys}->{public}->{file_name}\n");
                exit(FILE);
            }
            if (! flock(PUB,LOCK_UN)) {
                message(ERROR,"flock failed: $!\n");
                exit(LOCK);
            }
            close(PUB);
        }else{
            unlink($Cpuset->{ssh_keys}->{private}->{file_name});
            message(ERROR,"failed to open $Cpuset->{ssh_keys}->{public}->{file_name}\n");
            exit(FILE);
        }
    }
}elsif ($ARGV[0] eq "clean"){
    # delete ssh key files
    if ($Cpuset->{ssh_keys}->{private}->{key} ne ""){
        # private key
        unlink($Cpuset->{ssh_keys}->{private}->{file_name});

        # public key
        if (open(PUB,"+<", $Cpuset->{ssh_keys}->{public}->{file_name})){
            if (! flock(PUB,LOCK_EX)) {
                message(ERROR,"flock failed: $!\n");
                exit(LOCK);
            }
            #Change file on the fly
            my $out = "";
            while (<PUB>){
                if (($_ ne "\n") and ($_ ne $Cpuset->{ssh_keys}->{public}->{key})){
                    $out .= $_;
                }
            }
            if (!(seek(PUB,0,0) and print(PUB $out) and truncate(PUB,tell(PUB)))){
                message(ERROR,"failed to update $Cpuset->{ssh_keys}->{public}->{file_name}\n");
                exit(FILE);
            }
            if (! flock(PUB,LOCK_UN)) {
                message(ERROR,"flock failed: $!\n");
                exit(LOCK);
            }
            close(PUB);
        }else{
            message(ERROR,"failed to open $Cpuset->{ssh_keys}->{public}->{file_name}\n");
            exit(FILE);
        }
    }

    # PAM part
    if (!defined($Cpuset->{types}->{timesharing})){
        my $file_str = "# File generated by OAR.\n";
        $file_str .= "-:ALL:ALL\n";
        if (open(ACCESS, "> $Security_pam_file_tmp")){
            print(ACCESS "$file_str");
            close(ACCESS);
        }else{
            exit(FILE);
        }
        if (! rename($Security_pam_file_tmp,$Security_pam_file)) {
            message(ERROR,"cannot replace access.conf file.";
            exit(FILE);
        }
        if (defined($Cpuset->{types}->{$Allow_SSH_type}) and ! system('diff /dev/cpuset/'.$Cpuset_path.'/'.$Cpuset_name.'/cpus /dev/cpuset/'.$Cpuset_path.'/cpus > /dev/null 2>&1')){
            if (! $Cpuset->{user} eq "root" or $Cpuset->{user} eq "oar") {
                system("sudo -u $Cpuset->{user} kill -9 -1");
            }
        }
    }
    # PAM part

    # Clean cpuset on this node
    system('PROCESSES=$(cat /dev/cpuset/'.$Cpuset_path.'/'.$Cpuset_name.'/tasks)
            while [ "$PROCESSES" != "" ]
            do
                sudo kill -9 $PROCESSES
                PROCESSES=$(cat /dev/cpuset/'.$Cpuset_path.'/'.$Cpuset_name.'/tasks)
            done'
          );

    if (open(LOCKFILE,">", $Cpuset_lock_file.$Cpuset->{user})){
        if (! flock(LOCKFILE,LOCK_EX)) {
            message(ERROR,"flock failed: $!\n");
            exit(LOCK);
        }
        if (system('sudo rmdir /dev/cpuset/'.$Cpuset_path.'/'.$Cpuset_name)){
            # Uncomment this line if you want to use several network_address properties
            # which are the same physical computer (linux kernel)
            # exit(OK);
            exit(CPUSET);
        }
        my @cpusets = ();
        if (opendir(DIR, "/dev/cpuset/".$Cpuset_path.'/')) {
            @cpusets = grep { /^$Cpuset->{user}_\d+$/ } readdir(DIR);
            closedir DIR;
        } else {
            message(ERROR,"can't opendir: /dev/cpuset/$Cpuset_path\n");
            exit(CPUSET);
        }
        if ($#cpusets < 0) {
            my $useruid=getpwnam($Cpuset->{user});
            my $ipcrm_args="";
            if (open(IPCMSG,"< /proc/sysvipc/msg")) {
                <IPCMSG>;
                while (<IPCMSG>) {
                    if (/\s+\d+\s+(\d+)(?:\s+\d+){5}\s+$useruid(?:\s+\d+){6}$/) {
                        $ipcrm_args .= " -q $1";
                    }
                }
                close (IPCMSG);
            } else {
                message(INFO,"Cannot open /proc/sysvipc/msg: $!\n");
            }
            if (open(IPCSHM,"< /proc/sysvipc/shm")) {
                <IPCSHM>;
                while (<IPCSHM>) {
                    if (/\s+\d+\s+(\d+)(?:\s+\d+){5}\s+$useruid(?:\s+\d+){6}$/) {
                        $ipcrm_args .= " -m $1";
                    }
                }
                close (IPCSHM);
            } else {
                message(INFO,"Cannot open /proc/sysvipc/shm: $!\n");
            }
            if (open(IPCSEM,"< /proc/sysvipc/sem")) {
                <IPCSEM>;
                while (<IPCSEM>) {
                    if (/\s+\d+\s+(\d+)(?:\s+\d+){2}\s+$useruid(?:\s+\d+){5}$/) {
                        $ipcrm_args .= " -s $1";
                    }
                }
                close (IPCSEM);
            } else {
                message(INFO,"Cannot open /proc/sysvipc/sem: $!\n");
            }
            if ($ipcrm_args) {
                message(DEBUG,"Purging SysV IPC: ipcrm $ipcrm_args\n");
                system("sudo -u $Cpuset->{user} ipcrm $ipcrm_args"); 
            }
            message(DEBUG,"Purging /tmp...\n");
            if ($Log_level < DEBUG) {
                 system("sudo find /tmp/. -user $Cpuset->{user} -delete"); 
            } else {
                 system("sudo find /tmp/. -user $Cpuset->{user} -delete -print"); 
            }
        } else {
            message(INFO,"Not purging SysV IPC and /tmp as $Cpuset->{user} still has a job running on this host.\n");
        }
        if (! flock(LOCKFILE,LOCK_UN)) {
            message(ERROR,"flock failed: $!\n");
            exit(LOCK);
        }
        close(LOCKFILE);
    }else{
        message(ERROR,"failed to open $Cpuset_lock_file\n");
        exit(LOCK);
    }
}else{
    message(ERROR,"unknown action \"$ARGV[0]\".\n");
    exit(PARAMS);
}

exit(OK);

