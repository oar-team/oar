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

my $Old_umask = sprintf("%lo",umask());
umask(oct("022"));

my $Cpuset;

my $tmp = "";
while (<STDIN>){
    $tmp .= $_;
}
$Cpuset = eval($tmp);

# Get the data structure only for this node
if (!defined($Cpuset->{name})){
    print("[job_resource_manager] Bad SSH hashtable transfered\n");
    exit(2);
}
my $Cpuset_path;
my @Cpuset_cpus;
if (defined($Cpuset->{cpuset_path})){
    $Cpuset_path = $Cpuset->{cpuset_path}.'/'.$Cpuset->{name};
    @Cpuset_cpus = @{$Cpuset->{nodes}->{$ENV{TAKTUK_HOSTNAME}}};
}


# From now, "Cpuset" is of the form: 
# $Cpuset = {
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
#           }

if ($ARGV[0] eq "init"){
    # Initialize cpuset for this node

#    if (defined($Cpuset->{job_uid})){
#        adduser --quiet --system --home /var/lib/oar --ingroup oar --shell /bin/bash oar
#    }

    if (defined($Cpuset_path)){
        if (system('oardodo mount -t cpuset | grep " /dev/cpuset " > /dev/null 2>&1')){
            if (system('oardodo mkdir -p /dev/cpuset && oardodo mount -t cpuset none /dev/cpuset')){
                exit(4);
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
                exit(4);
            }
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
            exit(5);
        }
    }

    # Copy ssh key files
    if ($Cpuset->{ssh_keys}->{private}->{key} ne ""){
        # First, create the tmp oar directory
        if (!(((-d $Cpuset->{oar_tmp_directory}) and (-O $Cpuset->{oar_tmp_directory})) or (mkdir($Cpuset->{oar_tmp_directory})))){
            print("[job_resource_manager] Directory $Cpuset->{oar_tmp_directory} does not exist and cannot be created\n");
            exit(13);
        }
        # private key
        if (open(PRIV, ">".$Cpuset->{ssh_keys}->{private}->{file_name})){
            chmod(0600,$Cpuset->{ssh_keys}->{private}->{file_name});
            if (!print(PRIV $Cpuset->{ssh_keys}->{private}->{key})){
                warn("[job_resource_manager] Error writing $Cpuset->{ssh_keys}->{private}->{file_name} \n");
                unlink($Cpuset->{ssh_keys}->{private}->{file_name});
                exit(8);
            }
            close(PRIV);
            if (defined($Cpuset->{job_uid})){
                if (system("ln -s $Cpuset->{ssh_keys}->{private}->{file_name} $Cpuset->{oar_tmp_directory}/$Cpuset->{job_user}.jobkey")){
                    warn("[job_resource_manager] Error ln -s $Cpuset->{ssh_keys}->{private}->{file_name} $Cpuset->{oar_tmp_directory}/$Cpuset->{job_user}.jobkey \n");
                    unlink($Cpuset->{ssh_keys}->{private}->{file_name});
                    exit(8);
                }
            }
        }else{
            warn("[job_resource_manager] Error opening $Cpuset->{ssh_keys}->{private}->{file_name} \n");
            exit(7);
        }

        # public key
        if (open(PUB,"+<",$Cpuset->{ssh_keys}->{public}->{file_name})){
            flock(PUB,LOCK_EX) or die "flock failed: $!\n";
            seek(PUB,0,0) or die "seek failed: $!\n";
            my $out = "\n".$Cpuset->{ssh_keys}->{public}->{key}."\n";
            while (<PUB>){
                if ($_ =~ /environment=\"OAR_KEY=1\"/){
                    # We are reading a OAR key
                    $_ =~ /(ssh-dss|ssh-rsa)\s+([^\s^\n]+)/;
                    my $oar_key = $2;
                    $Cpuset->{ssh_keys}->{public}->{key} =~ /(ssh-dss|ssh-rsa)\s+([^\s^\n]+)/;
                    my $curr_key = $2;
                    if ($curr_key eq $oar_key){
                        warn("[job_resource_manager] ERROR: the user has specified the same ssh key than used by the user oar.\n");
                        exit(13);
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
                warn("[job_resource_manager] Error writing $Cpuset->{ssh_keys}->{public}->{file_name} \n");
                exit(9);
            }
            flock(PUB,LOCK_UN) or die "flock failed: $!\n";
            close(PUB);
        }else{
            unlink($Cpuset->{ssh_keys}->{private}->{file_name});
            warn("[job_resource_manager] Error opening $Cpuset->{ssh_keys}->{public}->{file_name} \n");
            exit(10);
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
            flock(PUB,LOCK_EX) or die "flock failed: $!\n";
            seek(PUB,0,0) or die "seek failed: $!\n";
            #Change file on the fly
            my $out = "";
            while (<PUB>){
                if (($_ ne "\n") and ($_ ne $Cpuset->{ssh_keys}->{public}->{key})){
                    $out .= $_;
                }
            }
            if (!(seek(PUB,0,0) and print(PUB $out) and truncate(PUB,tell(PUB)))){
                warn("[job_resource_manager] Error changing $Cpuset->{ssh_keys}->{public}->{file_name} \n");
                exit(12);
            }
            flock(PUB,LOCK_UN) or die "flock failed: $!\n";
            close(PUB);
        }else{
            warn("[job_resource_manager] Error opening $Cpuset->{ssh_keys}->{public}->{file_name} \n");
            exit(11);
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
            exit(6);
        }
    }
}else{
    print("[job_resource_manager] Bad command line argument $ARGV[0].\n");
    exit(3);
}

exit(0);

