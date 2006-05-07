{
package oar_Tools;

use IO::Socket::INET;
use strict;

# Constants
my $Default_leon_soft_walltime = 20;
my $Default_leon_walltime = 60;
my $Timeout_ssh = 30;
my $Default_server_prologue_epilogue_Timeout = 60;
my $bipbip_oarexec_hashtable_send_timeout = 30;
my $Default_Dead_switch_time = 0;
my $Default_oarexec_directory = "/tmp/oar/";
my $Oarexec_pid_file_name = "pid_of_oarexec_for_jobId_";
my $Default_prologue_epilogue_timeout = 60;
my $Ssh_rendez_vous = "oarexec is initialized and ready to do the job\n";

# Prototypes
sub get_all_process_childs();
sub get_one_process_childs($);
sub notify_tcp_socket($$$);
sub signal_oarexec($$$$$);
sub get_default_oarexec_directory();
sub get_oar_pid_file_name($);
sub get_ssh_timeout();
sub get_default_leon_soft_walltime();
sub get_default_leon_walltime();
sub get_default_dead_switch_time();
sub check_client_host_ip($$);
sub fork_no_wait($$);
sub launch_command($);
sub get_default_prologue_epilogue_timeout();
sub get_default_server_prologue_epilogue_timeout();
sub get_bipbip_ssh_hashtable_send_timeout();
sub get_oarexecuser_script_for_oarexec($$$$$$$@);
sub get_oarexecuser_script_for_oarsub($$$$$$);
sub get_bipbip_oarexec_rendez_vous();

# Get default value for PROLOGUE_EPILOGUE_TIMEOUT
sub get_default_prologue_epilogue_timeout(){
    return($Default_prologue_epilogue_timeout);
}

# Get default value for SERVER_PROLOGUE_EPILOGUE_TIMEOUT
sub get_default_server_prologue_epilogue_timeout(){
    return($Default_server_prologue_epilogue_Timeout);
}

# Get value for ssh hashtable timeout
sub get_bipbip_ssh_hashtable_send_timeout(){
    return($bipbip_oarexec_hashtable_send_timeout);
}

# Get default value for DEAD_SWITCH_TIME tag
sub get_default_dead_switch_time(){
    return($Default_Dead_switch_time);
}

# Get default Leon walltime value for Sarko
sub get_default_leon_soft_walltime(){
    return($Default_leon_soft_walltime);
}


# Get default Leon soft walltime value for Sarko
sub get_default_leon_walltime(){
    return($Default_leon_walltime);
}


# return a hashtable of all child in arrays
sub get_all_process_childs(){
    my %process_hash;
    open(CMD, "ps -e -o pid,ppid |");
    while (<CMD>){
        chomp($_);
        $_ =~ /(\d+)\s+(\d+)/;
        if (defined($1) && defined($2)){
            if (!defined($process_hash{$2})){
                $process_hash{$2} = [$1];
            }else{
                push(@{$process_hash{$2}}, $1);
            }
        }
    }
    close(CMD);

    return(%process_hash);
}


# return an array of childs
sub get_one_process_childs($){
    my $one_father = shift;

    my %process_hash = get_all_process_childs();
    my @child_pids;
    my @potential_father;
    while (defined($one_father)){
        push(@child_pids, $one_father);
        #Get childs of this process
        foreach my $i (@{$process_hash{$one_father}}){
            push(@potential_father, $i);
        }
        $one_father = shift(@potential_father);
    }

    return(@child_pids);
}


# Send a Tag on a socket
# args = hostname, socket port, Tag 
sub notify_tcp_socket($$$){
    my $almighty_host = shift;
    my $almighty_port = shift;
    my $tag = shift;

    my $socket = IO::Socket::INET->new(PeerAddr => $almighty_host,
                                       PeerPort => $almighty_port,
                                       Proto => "tcp",
                                       Type  => SOCK_STREAM)
             or return("Could not connect to the socket $almighty_host:$almighty_port");
    print($socket "$tag\n");
    close($socket);

    return(undef);
}


# Return the constant SSH timeout to use
sub get_ssh_timeout(){
    return($Timeout_ssh);
}


sub get_default_oarexec_directory(){
    return($Default_oarexec_directory);
}


# Get the name of the file which contains the pid of oarexec
# arg : job id
sub get_oar_pid_file_name($){
    my $job_id = shift;

    return($Default_oarexec_directory."/".$Oarexec_pid_file_name.$job_id);
}


# Send the given signal to the right oarexec process
# args : host name, job id, signal, wait or not (0 or 1), DB ref (to close it in the child process)
# return an array with exit values
sub signal_oarexec($$$$$){
    my $host = shift;
    my $job_id = shift;
    my $signal = shift;
    my $wait = shift;
    my $base = shift;

    my $file = get_oar_pid_file_name($job_id);
    my $cmd = "ssh $host \"test -e $file && cat $file | xargs kill -s $signal\"";
    my $pid = fork();
    if($pid == 0){
        #CHILD
        undef($base);
        my $exit_code;
        my $ssh_pid;
        eval{
            $SIG{ALRM} = sub { die "alarm\n" };
            alarm(get_ssh_timeout());
            $ssh_pid = fork();
            if ($ssh_pid == 0){
                exec($cmd);
            }
            my $wait_res = 0;
            # Avaoid to be disrupted by a signal
            while ($wait_res != $ssh_pid){
                $wait_res = waitpid($ssh_pid,0);
            }
            alarm(0);
            $exit_code  = $?;
        };
        if ($@){
            if ($@ eq "alarm\n"){
                if (defined($ssh_pid)){
                    my @childs = get_one_process_childs($ssh_pid);
                    kill(9,@childs);
                }
            }
        }
        # Exit from child
        exit($exit_code);
    }
    if ($wait > 0){
        waitpid($pid,0);
        my $exit_value  = $? >> 8;
        my $signal_num  = $? & 127;
        my $dumped_core = $? & 128;

        return($exit_value,$signal_num,$dumped_core);
    }else{
        return(undef);
    }
}


# Check if a client socket is authorized to connect to us
# args : client socket, ref of an array of authorized networks
# return 1 for success else 0
sub check_client_host_ip($$){
    my $client = shift;
    my $ref_array = shift;

    my @authorized_hosts = @{$ref_array};

    my @logs;
    my $extrem = getpeername($client);
    my ($remote_port,$addr_in) = unpack_sockaddr_in($extrem);
    my $remote_host = inet_ntoa($addr_in);
    push(@logs, "[checkClientHostIP] Remote host = $remote_host ; remote port = $remote_port\n");
    $remote_host =~ m/^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$/m;
    $remote_host = ($1 << 24)+($2 << 16)+($3 << 8)+$4;
    my $i = 0;
    my $host_allow = 0;
    while (($host_allow == 0) && ($#authorized_hosts >= $i)){
        my $str = "Check host with $authorized_hosts[$i]->[0].$authorized_hosts[$i]->[1].$authorized_hosts[$i]->[2].$authorized_hosts[$i]->[3]/$authorized_hosts[$i]->[4] --> ";
        my $network = ($authorized_hosts[$i]->[0] << 24)+($authorized_hosts[$i]->[1] << 16)+($authorized_hosts[$i]->[2] << 8)+$authorized_hosts[$i]->[3];
        my $mask = 2**32 - 2**(32-$authorized_hosts[$i]->[4]);
        if (($remote_host & $mask) == $network){
            $str .= "OK";
            $host_allow = 1;
        }else{
            $str .= "BAD";
            push(@logs, "[checkClientHostIP] $str\n");
        }
        push(@logs, "[checkClientHostIP] $str\n");
        $i++;
    }
    return($host_allow,@logs);
}


# exec a command and do not wait its end
# arg : command, DB ref (to close it in the child)
sub fork_no_wait($$){
    my $cmd = shift;
    my $base = shift;

    $ENV{PATH}="/bin:/usr/bin:/usr/local/bin";
    my $pid;
    $pid = fork();
    if(defined($pid)){
        if($pid == 0){
            #child
            undef($base);
            exec($cmd);
        }
    }
    return($pid);
}


# exec a command, wait its end and return exit codes
# arg : command
sub launch_command($){
    my $command = shift;

    $ENV{PATH}="/bin:/usr/bin:/usr/local/bin:$ENV{OARDIR}";
    system($command);
    my $exit_value  = $? >> 8;
    my $signal_num  = $? & 127;
    my $dumped_core = $? & 128;
        
    return($exit_value,$signal_num,$dumped_core);
}


# Create the shell script used to execute right command for the user
# The resulting script can be launched with : sh -c 'script'
sub get_oarexecuser_script_for_oarexec($$$$$$$@){
    my ($node_file,
        $job_id,
        $user,
        $shell,
        $launching_directory,
        $stdout_file,
        $stderr_file,
        @cmd) = @_;

    my $script = '
if [ "a$TERM" == "a" ] || [ "$TERM" == "unknown" ]
then
    export TERM=xterm
fi

export OAR_FILE_NODES='.$node_file.'
export OAR_JOBID='.$job_id.'
export OAR_USER='.$user.'
export OAR_WORKDIR='.$launching_directory.'

export OAR_NODEFILE=$OAR_FILE_NODES
export OAR_O_WORKDIR=$OAR_WORKDIR
export OAR_NODE_FILE=$OAR_FILE_NODES
export OAR_RESOURCE_FILE=$OAR_FILE_NODES
export OAR_WORKING_DIRECTORY=$OAR_WORKDIR
export OAR_JOB_ID=$OAR_JOBID

if ( cd $OAR_WORKING_DIRECTORY &> /dev/null )
then
    cd $OAR_WORKING_DIRECTORY
else
    #Can not go into working directory
    exit 1
fi

export OAR_STDOUT='.$stdout_file.'
export OAR_STDERR='.$stderr_file.'
    
#Test if we can write into stout and stderr files
if ! ( > $OAR_STDOUT ) &> /dev/null || ! ( > $OAR_STDERR ) &> /dev/null
then
    exit 2
fi
('."@cmd".' > $OAR_STDOUT) >& $OAR_STDERR

exit 0
';

    return($script);
}


# Create the shell script used to execute right command for the user
# The resulting script can be launched with : sh -c 'script'
sub get_oarexecuser_script_for_oarsub($$$$$$){
    my ($node_file,
        $job_id,
        $user,
        $shell,
        $launching_directory,
        $display) = @_;

    my $script = '
if [ \"a$TERM\" == \"a\" ] || [ \"$TERM\" == \"unknown\" ]
then
    export TERM=xterm
fi

export OAR_FILE_NODES='.$node_file.'
export OAR_JOBID='.$job_id.'
export OAR_USER='.$user.'
export OAR_WORKDIR='.$launching_directory.'
export DISPLAY='.$display.'

export OAR_NODEFILE=\$OAR_FILE_NODES
export OAR_O_WORKDIR=\$OAR_WORKDIR
export OAR_NODE_FILE=\$OAR_FILE_NODES
export OAR_RESOURCE_FILE=\$OAR_FILE_NODES
export OAR_WORKING_DIRECTORY=\$OAR_WORKDIR
export OAR_JOB_ID=\$OAR_JOBID

if ( cd \$OAR_WORKING_DIRECTORY &> /dev/null )
then
    cd \$OAR_WORKING_DIRECTORY
else
    #Can not go into working directory
    exit 1
fi

'.$shell.'

exit 0
';

    return($script);
}

sub get_bipbip_oarexec_rendez_vous(){
    return($Ssh_rendez_vous);
}

1;
}
