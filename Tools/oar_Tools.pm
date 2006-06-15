{
package oar_Tools;

use IO::Socket::INET;
use strict;
use POSIX ":sys_wait_h";

# Constants
my $Default_leon_soft_walltime = 20;
my $Default_leon_walltime = 60;
my $Timeout_ssh = 30;
my $Default_server_prologue_epilogue_Timeout = 60;
my $bipbip_oarexec_hashtable_send_timeout = 30;
my $Default_Dead_switch_time = 0;
my $Default_oarexec_directory = "/tmp/oar/";
my $Oarexec_pid_file_name = "pid_of_oarexec_for_jobId_";
my $Oarsub_file_name_prefix = "oarsub_connections_";
my $Default_prologue_epilogue_timeout = 60;
my $Ssh_rendez_vous = "oarexec is initialized and ready to do the job\n";
my $Default_openssh_cmd = "ssh";

# Prototypes
sub get_all_process_children();
sub get_one_process_children($);
sub notify_tcp_socket($$$);
sub signal_oarexec($$$$$$);
sub get_default_oarexec_directory();
sub get_default_openssh_cmd();
sub get_oar_pid_file_name($);
sub get_oarsub_connections_file_name($);
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
sub get_bipbip_oarexec_rendez_vous();
sub sentinelle($$$);
sub get_cpuset_script($$);
sub get_cpuset_clean_script($);

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

# Get default value for OPENSSH_CMD tag
sub get_default_openssh_cmd(){
    return($Default_openssh_cmd);
}

# return a hashtable of all child in arrays and a hashtable with process command names
sub get_all_process_children(){
    my %process_hash;
    my %process_cmd_hash;
    open(CMD, "ps -e -o pid,ppid,args |");
    while (<CMD>){
        chomp($_);
        if ($_ =~ /^\s*(\d+)\s+(\d+)\s+(.+)$/){
            if (!defined($process_hash{$2})){
                $process_hash{$2} = [$1];
            }else{
                push(@{$process_hash{$2}}, $1);
            }
            $process_cmd_hash{$1} = $3;
        }
    }
    close(CMD);

    return(\%process_hash,\%process_cmd_hash);
}


# return an array of children
sub get_one_process_children($){
    my $pid = shift;

    my $one_father = $pid;
    my ($tmp1,$pid_cmd_hash) = get_all_process_children();
    my %process_hash = %{$tmp1};
    my @child_pids;
    my @potential_father;
    while (defined($one_father)){
        push(@child_pids, $one_father);
        #Get children of this process
        foreach my $i (@{$process_hash{$one_father}}){
            push(@potential_father, $i);
        }
        $one_father = shift(@potential_father);
    }

    return(\@child_pids,$pid_cmd_hash->{$pid});
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


# Get the name of the file which contains parent pids of oarsub connections
# arg : job id
sub get_oarsub_connections_file_name($){
    my $job_id = shift;

    return($Default_oarexec_directory."/".$Oarsub_file_name_prefix.$job_id);
}


# Send the given signal to the right oarexec process
# args : host name, job id, signal, wait or not (0 or 1), DB ref (to close it in the child process)
# return an array with exit values
sub signal_oarexec($$$$$$){
    my $host = shift;
    my $job_id = shift;
    my $signal = shift;
    my $wait = shift;
    my $base = shift;
    my $ssh_cmd = shift;

    my $file = get_oar_pid_file_name($job_id);
    my $cmd = "$ssh_cmd -x -T $host \"test -e $file && cat $file | xargs kill -s $signal\"";
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
                    my ($children,$cmd_name) = get_one_process_children($ssh_pid);
                    kill(9,@{$children});
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
            $SIG{USR1} = 'IGNORE';
            $SIG{INT}  = 'IGNORE';
            $SIG{TERM} = 'IGNORE';
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
sub get_oarexecuser_script_for_oarexec($$$$$$$$@){
    my ($node_file,
        $job_id,
        $user,
        $shell,
        $launching_directory,
        $stdout_file,
        $stderr_file,
        $resource_file,
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
export OAR_RESOURCE_PROPERTIES_FILE='.$resource_file.'

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
    
#Test if we can write into stdout and stderr files
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
sub get_oarexecuser_script_for_oarsub($$$$$$$$){
    my ($node_file,
        $job_id,
        $user,
        $shell,
        $launching_directory,
        $display,
        $cpuset_name,
        $resource_file) = @_;

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
export OAR_CPUSET='.$cpuset_name.'
export OAR_RESOURCE_PROPERTIES_FILE='.$resource_file.'

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
    #Cannot go into working directory
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

# Execute comands with a specified timeout and a maximum number in the same time : window.
# Aavoid to overload the computer.
# args : window size, timeout, command to execute
sub sentinelle($$$){
    my $window = shift;
    my $timeout = shift;
    my $nodes = shift;

    my @bad_nodes;
    my $index = 0;
    my %running_processes;
    my $nb_running_processes = 0;
    my %finished_processes;


    # Start to launch subprocesses with the window limitation
    my @timeout;
    my $pid;
    while (($index <= $#$nodes) or ($#timeout >= 0)){
        # Check if window is full or not
        while((($nb_running_processes) < $window) and ($index <= $#$nodes)){
            $pid = fork();
            if (defined($pid)){
                $running_processes{$pid} = $index;
                $nb_running_processes++;
                push(@timeout, [$pid,time()+$timeout]);
                if ($pid == 0){
                    #In the child
                    exec($nodes->[$index]);
                }
            }else{
                push(@bad_nodes, $index);
            }
            $index++;
        }
        # Check ended proceses
        while(($pid = waitpid(-1, WNOHANG)) > 0) {
            my $exit_value = $? >> 8;
            my $signal_num  = $? & 127;
            my $dumped_core = $? & 128;
            if ($pid > 0){
                if (defined($running_processes{$pid})){
                    if (($exit_value != 0) or ($signal_num != 0) or ($dumped_core != 0)){
                        push(@bad_nodes, $running_processes{$pid});
                    }
                    delete($running_processes{$pid});
                    $nb_running_processes--;
                }
            } 
        }

        my $t = 0;
        while(defined($timeout[$t]) and (($timeout[$t]->[1] <= time()) or (!defined($running_processes{$timeout[$t]->[0]})))){
            if (!defined($running_processes{$timeout[$t]->[0]})){
                splice(@timeout,$t,1);
            }else{
                if ($timeout[$t]->[1] <= time()){
                    # DRING, timeout !!!
                    kill(9,$timeout[$t]->[0]);
                }
            }
            $t++;
        }
        select(undef,undef,undef,0.1) if ($t == 0);
    }
    
    return(@bad_nodes);
}

sub get_cpuset_script($$){
    my $cpus = shift;
    my $cpuset_name = shift;

    my $cpus_str = '';
    foreach my $c (@{$cpus}){
        $cpus_str .= "$c,";
    }
    chop($cpus_str);

    my $script = '
mount -t cpuset | grep \" /dev/cpuset \" > /dev/null 2>&1
if [ \$? != 0 ]
then
    mkdir -p /dev/cpuset && mount -t cpuset none /dev/cpuset
    RES=$?
    [ \$RES != 0 ] && exit \$RES
fi

mkdir -p /dev/cpuset/'.$cpuset_name.' &&\
  /bin/echo 0 | cat > /dev/cpuset/'.$cpuset_name.'/notify_on_release &&\
  /bin/echo 0 | cat > /dev/cpuset/'.$cpuset_name.'/cpu_exclusive &&\
  cat /dev/cpuset/mems > /dev/cpuset/'.$cpuset_name.'/mems &&\
  /bin/echo '.$cpus_str.' | cat > /dev/cpuset/'.$cpuset_name.'/cpus &&\
  chown oar /dev/cpuset/'.$cpuset_name.'/tasks

exit \$?
';

    return($script);
}

sub get_cpuset_clean_script($){
    my $cpuset_name = shift;

    my $script = '
PROCESSES=$(cat /dev/cpuset/'.$cpuset_name.'/tasks)
while [ "$PROCESSES" != "" ]
do
    sudo kill -9 $PROCESSES
    PROCESSES=$(cat /dev/cpuset/'.$cpuset_name.'/tasks)
done

sudo rmdir /dev/cpuset/'.$cpuset_name.'
exit $?
';

    return($script);
}

1;
}
