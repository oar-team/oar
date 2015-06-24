{
package OAR::Tools;

use IO::Socket::INET;
use strict;
use POSIX ":sys_wait_h";
use IPC::Open2;
use Data::Dumper;
use Fcntl;

# Constants
my $Default_leon_soft_walltime = 20;
my $Default_leon_walltime = 300;
my $Timeout_ssh = 120;
my $Default_server_prologue_epilogue_Timeout = 60;
my $bipbip_oarexec_hashtable_send_timeout = 30;
my $Default_Dead_switch_time = 0;
my $Default_oarexec_directory = "/tmp/oar_runtime/";
my $Oarexec_pid_file_name = "pid_of_oarexec_for_jobId_";
my $Oarsub_file_name_prefix = "oarsub_connections_";
my $Default_prologue_epilogue_timeout = 60;
my $Default_suspend_resume_script_timeout = 60;
my $Ssh_rendez_vous = "oarexec is initialized and ready to do the job\n";
my $Default_openssh_cmd = "ssh";
my $Default_cpuset_file_manager = "/etc/oar/job_resource_manager.pl";
my $Default_monitor_file_sensor = "/etc/oar/oarmonitor_sensor.pl";
my $Default_suspend_resume_file_manager = "/etc/oar/suspend_resume_manager.pl";
my $Default_oar_ssh_authorized_keys_file = ".ssh/authorized_keys";
my $Default_node_file_db_field = "network_address";
my $Default_node_file_db_field_distinct_values = "resource_id";
my $Default_notify_tcp_socket_enabled = 1;

# Prototypes
sub get_all_process_children();
sub get_one_process_children($);
sub notify_tcp_socket($$$);
sub signal_oarexec($$$$$$$);
sub get_default_oarexec_directory();
sub set_default_oarexec_directory($);
sub get_default_openssh_cmd();
sub get_oar_pid_file_name($);
sub get_oar_user_signal_file_name($);
sub get_oarsub_connections_file_name($);
sub get_ssh_timeout();
sub get_taktuk_timeout();
sub get_default_leon_soft_walltime();
sub get_default_leon_walltime();
sub get_default_dead_switch_time();
sub fork_no_wait($$);
sub launch_command($);
sub get_default_prologue_epilogue_timeout();
sub get_default_server_prologue_epilogue_timeout();
sub get_default_suspend_resume_file();
sub get_bipbip_ssh_hashtable_send_timeout();
sub get_bipbip_oarexec_rendez_vous();
sub sentinelle($$$$$);
sub check_resource_property($);
sub check_resource_system_property($);
sub get_private_ssh_key_file_name($);
sub format_ssh_pub_key($$$);
sub get_default_oar_ssh_authorized_keys_file();
sub get_default_node_file_db_field();
sub get_default_node_file_db_field_distinct_values();
sub replace_jobid_tag_in_string($$);
sub inhibit_notify_tcp_socket();
sub enable_notify_tcp_socket();
sub read_socket_line($$);

# Get default value for PROLOGUE_EPILOGUE_TIMEOUT
sub get_default_prologue_epilogue_timeout(){
    return($Default_prologue_epilogue_timeout);
}

# Get default value for SERVER_PROLOGUE_EPILOGUE_TIMEOUT
sub get_default_server_prologue_epilogue_timeout(){
    return($Default_server_prologue_epilogue_Timeout);
}

# Get default value for SUSPEND_RESUME_SCRIPT_TIMEOUT
sub get_default_suspend_resume_script_timeout(){
    return($Default_suspend_resume_script_timeout);
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

# Get default value for JOB_RESOURCE_MANAGER_FILE tag
sub get_default_cpuset_file(){
    return($Default_cpuset_file_manager);
}

# Get default value for SUSPEND_RESUME_FILE tag
sub get_default_suspend_resume_file(){
    return($Default_suspend_resume_file_manager);
}

# Get then file name where are stored all oar ssh public keys
sub get_default_oar_ssh_authorized_keys_file(){
    return($Default_oar_ssh_authorized_keys_file);
}

# Get the name of the DB field to use to fill the OAR_NODE_FILE
sub get_default_node_file_db_field(){
    return($Default_node_file_db_field);
}

# Get the name of the DB field to use to fill the OAR_NODE_FILE
sub get_default_node_file_db_field_distinct_values(){
    return($Default_node_file_db_field_distinct_values);
}

# Get default value for OARMONITOR_SENSOR_FILE tag
sub get_default_monitor_sensor_file(){
    return($Default_monitor_file_sensor);
}

# Get the name of the file of the private ssh key for the given cpuset name
sub get_private_ssh_key_file_name($){
    my $cpuset_name = shift;

    return($Default_oarexec_directory.'/'.$cpuset_name.".jobkey");
}

# Add right environment variables to the given public key
sub format_ssh_pub_key($$$){
    my $key = shift;
    my $cpuset = shift;
    my $job_user = shift;

    $cpuset = "undef" if (!defined($cpuset));
    return('environment="OAR_CPUSET='.$cpuset.'",environment="OAR_JOB_USER='.$job_user.'" '.$key."\n");
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

# Disable notify_tcp_socket of Almighty
sub inhibit_notify_tcp_socket(){
    $Default_notify_tcp_socket_enabled = 0;
}
# Enable notify_tcp_socket of Almighty
sub enable_notify_tcp_socket(){
    $Default_notify_tcp_socket_enabled = 1;
}

# Send a Tag on a socket
# args = hostname, socket port, Tag 
sub notify_tcp_socket($$$){
    return(undef) if ($Default_notify_tcp_socket_enabled == 0);
    my $almighty_host = shift;
    my $almighty_port = shift;
    my $tag = shift;

    my $socket = IO::Socket::INET->new(PeerAddr => $almighty_host,
                                       PeerPort => $almighty_port,
                                       Proto => "tcp",
                                       Type  => SOCK_STREAM)
             or return("Could not connect to the socket $almighty_host:$almighty_port");
    print($socket "$tag\n") or return("Print $tag failed to $almighty_host:$almighty_port");
    close($socket) or return("Socket close failed: $almighty_host:$almighty_port");

    return(undef);
}


# Return the constant SSH timeout to use
sub get_ssh_timeout(){
    return($Timeout_ssh);
}

sub set_ssh_timeout($){
    $Timeout_ssh = shift;
}

sub get_taktuk_timeout(){
    return($Timeout_ssh * 2);
}

sub get_default_oarexec_directory(){
    return($Default_oarexec_directory);
}

sub set_default_oarexec_directory($){
    $Default_oarexec_directory = shift;
}

# Get the name of the file which contains the pid of oarexec
# arg : job id
sub get_oar_pid_file_name($){
    my $job_id = shift;

    return($Default_oarexec_directory."/".$Oarexec_pid_file_name.$job_id);
}

# Get the name of the file which contains the signal given by the user
# arg : job id
sub get_oar_user_signal_file_name($){
    my $job_id = shift;

    return($Default_oarexec_directory."/USER_SIGNAL_".$job_id);
}

# Get the name of the file which contains parent pids of oarsub connections
# arg : job id
sub get_oarsub_connections_file_name($){
    my $job_id = shift;

    return($Default_oarexec_directory."/".$Oarsub_file_name_prefix.$job_id);
}

# Replace %jobid% in the string by the given job id
# args: string, job id
sub replace_jobid_tag_in_string($$){
    my $str = shift;
    my $job_id = shift;

    $str =~ s/%jobid%/$job_id/g;
    return($str);
}

# Send the given signal to the right oarexec process
# args : host name, job id, signal, wait or not (0 or 1), 
# DB ref (to close it in the child process), ssh cmd, user defined signal 
# for oardel -s (null by default if not used)
# return an array with exit values
sub signal_oarexec($$$$$$$){
    my $host = shift;
    my $job_id = shift;
    my $signal = shift;
    my $wait = shift;
    my $base = shift;
    my $ssh_cmd = shift;
    my $user_signal = shift;

    my $file = get_oar_pid_file_name($job_id);
    #my $cmd = "$ssh_cmd -x -T $host \"test -e $file && cat $file | xargs kill -s $signal\"";
    #my $cmd = "$ssh_cmd -x -T $host bash -c \"test -e $file && PROC=\\\$(cat $file) && kill -s CONT \\\$PROC && kill -s $signal \\\$PROC\"";
    my ($cmd_name,@cmd_opts) = split(" ",$ssh_cmd);
    my @cmd;
    my $c = 0;
    $cmd[$c] = $cmd_name;$c++;
    foreach my $p (@cmd_opts){
        $cmd[$c] = $p;$c++;
    }
    $cmd[$c] = "-x";$c++;
    $cmd[$c] = "-T";$c++;
    $cmd[$c] = $host;$c++;
    if (defined($user_signal) && $user_signal ne ''){
        my $signal_file = OAR::Tools::get_oar_user_signal_file_name($job_id);
	    $cmd[$c] = "bash -c 'echo $user_signal > $signal_file && test -e $file && PROC=\$(cat $file) && kill -s CONT \$PROC && kill -s $signal \$PROC'";$c++;
    }
    else {
    	$cmd[$c] = "bash -c 'test -e $file && PROC=\$(cat $file) && kill -s CONT \$PROC && kill -s $signal \$PROC'";$c++;
    }
    $SIG{PIPE}  = 'IGNORE';
    my $pid = fork();
    if($pid == 0){
        #CHILD
        undef($base);
        my $exit_code;
        my $ssh_pid;
        eval{
            $SIG{PIPE}  = 'IGNORE';
            $SIG{ALRM} = sub { die "alarm\n" };
            alarm(get_ssh_timeout());
            $ssh_pid = fork();
            if ($ssh_pid == 0){
                exec({$cmd_name} @cmd);
                warn("[ERROR] Cannot find @cmd\n");
                exit(-1);
            }
            my $wait_res = -1;
            # Avaoid to be disrupted by a signal
            while ((defined($ssh_pid)) and ($wait_res != $ssh_pid)){
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


# exec a command and do not wait its end
# arg : command, DB ref (to close in the child)
sub fork_no_wait($$){
    my $cmd = shift;
    my $base = shift;

#    $ENV{PATH}="/bin:/usr/bin:/usr/local/bin";
    my $pid;
    $SIG{PIPE}  = 'IGNORE';
    $pid = fork();
    if(defined($pid)){
        if($pid == 0){
            #child
            undef($base);
            $SIG{USR1} = 'IGNORE';
            $SIG{INT}  = 'IGNORE';
            $SIG{TERM} = 'IGNORE';
            exec($cmd);
            warn("[ERROR] Cannot find $cmd\n");
            exit(-1);
        }
    }
    return($pid);
}


# exec a command and feed its STDIN
# arg : command, data to send, DB ref (to close it in the child)
sub fork_and_feed_stdin($$$){
    my $cmd = shift;
    my $timeout = shift;
    my $feed = shift;

    my $ret;
    my $pid;
    eval{
        $SIG{ALRM} = sub { die "alarm\n" };
        alarm($timeout);
        $pid = open(CMDTOFEED, "| $cmd");
        foreach my $s (@{$feed}){
            print(CMDTOFEED "$s\n");
        }
        $ret = close(CMDTOFEED);
        alarm(0);
    };
    if ($@){
        if ($@ eq "alarm\n"){
            if (defined($pid)){
                my ($children,$cmd_name) = get_one_process_children($pid);
                kill(9,@{$children});
            }
        }
    }
    return($ret);
}


# exec a command, wait its end and return exit codes
# arg : command
sub launch_command($){
    my $command = shift;

#    $ENV{PATH}="/bin:/usr/bin:/usr/local/bin:$ENV{OARDIR}";
    system($command);
    my $exit_value  = $? >> 8;
    my $signal_num  = $? & 127;
    my $dumped_core = $? & 128;
        
    return($exit_value,$signal_num,$dumped_core);
}


# Create the script used to execute the job command as the job user
sub get_oarexec_user_script($$$$$$$){
    my $job_data = shift;
    my $job_file_nodes = shift;
    my $job_file_resources = shift;
    my $job_file_env = shift;
    my $shell = shift;
    my $use_job_resource_manager = shift;
    my $is_interactive_session = shift;

    my $script = "set -e;\n";
    if ($use_job_resource_manager) {
        $script .= <<EOF;
if ! [ -r "$job_file_env" ]; then
    exit 1;
fi;
source "$job_file_env";
EOF
    } else {
        $script .= <<EOF;
export OAR_JOBID="$job_data->{job_id}";
export OAR_JOB_ID="$job_data->{job_id}";
export OAR_ARRAYID="$job_data->{array_id}";
export OAR_ARRAY_ID="$job_data->{array_id}";
export OAR_ARRAYINDEX="$job_data->{array_index}";
export OAR_ARRAY_INDEX="$job_data->{array_index}";
export OAR_USER="$job_data->{user}";
export OAR_JOB_NAME="$job_data->{job_name}";
export OAR_WORKDIR="$job_data->{launching_directory}";
export OAR_O_WORKDIR="$job_data->{launching_directory}";
export OAR_PROJECT_NAME="$job_data->{project}";
export OAR_STDOUT="$job_data->{stdout_file}";
export OAR_STDERR="$job_data->{stderr_file}";
export OAR_JOB_WALLTIME="$job_data->{walltime}";
export OAR_JOB_WALLTIME_SECONDS="$job_data->{walltime_seconds}";
export OAR_NODEFILE="$job_file_nodes";
export OAR_NODE_FILE="$job_file_nodes";
export OAR_FILE_NODES="$job_file_nodes";
export OAR_RESOURCE_PROPERTIES_FILE="$job_file_resources";
export OAR_RESOURCE_FILE="$job_file_resources";
EOF
    }
    $script .= <<EOF;
if ! [ -n "\$OAR_NODEFILE" -a -r "\$OAR_NODEFILE" -a -n "\$OAR_RESOURCE_FILE" -a -r "\$OAR_RESOURCE_FILE" ]; then
    exit 2;
fi;
if ! [ -n "\$OAR_WORKING_DIRECTORY" ] || ! cd \$OAR_WORKING_DIRECTORY; then
    exit 3;
fi;
if ! [ -n "\$OAR_STDOUT" -a -n "\$OAR_STDERR" ]; then
    exit 4;
fi;

export SHELL="$shell";
EOF
    if ($is_interactive_session) {
        $script .= <<EOF;
if [ -n "\$TERM" -o "\$TERM" == "unknown" ]; then
    TERM="xterm";
fi;
SHLVL=1;
( exec -a -\${SHELL##*/} \$SHELL );
exit 0;
EOF
    } else {
        $script .= <<EOF;
TERM="unknown";
unset SSH_CLIENT;
unset SSH2_CLIENT;
SHLVL=0;
BASH_ENV="~oar/.batch_job_bashrc";
declare -a CMD;
read -a CMD;
(
    set -e;
    exec 1> \$OAR_STDOUT;
    exec 2> \$OAR_STDERR;
    exec -a -\${SHELL##*/} \$SHELL -c "\${CMD[*]}";
) &
echo "USER_CMD_PID=\$!";
wait %1;
echo "EXIT_CODE \$?";
exit 0;
EOF
    }
    return $script;
}

sub get_bipbip_oarexec_rendez_vous(){
    return($Ssh_rendez_vous);
}

# Execute comands with a specified timeout and a maximum number in the same time : window.
# Aavoid to overload the computer.
# args : window size, timeout, command to execute
sub sentinelle($$$$$){
    my $window = shift;
    my $timeout = shift;
    my $nodes = shift;
    my $input_string = shift;
    my $base = shift;

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
            $SIG{PIPE}  = 'IGNORE';
            $pid = fork();
            if (defined($pid)){
                $running_processes{$pid} = $index;
                $nb_running_processes++;
                push(@timeout, [$pid,time()+$timeout]);
                if ($pid == 0){
                    #In the child
                    undef($base);
                    if (defined($input_string)){
                        my $cmd_pid = open(HANDLE, "| $nodes->[$index]");
                        $SIG{USR2} = sub {kill(9,$cmd_pid)};
                        print(HANDLE $input_string);
                        close(HANDLE);
                        my $exit_value = $? >> 8;
                        my $signal_num  = $? & 127;
                        my $dumped_core = $? & 128;
                        if (($exit_value != 0) or ($signal_num != 0) or ($dumped_core != 0)){
                            exit(1);
                        }else{
                            exit(0);
                        }
                    }else{
                        exec($nodes->[$index]);
                        warn("[ERROR] Cannot find $nodes->[$index]\n");
                        exit(-1);
                    }
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
                    if (defined($input_string)){
                        kill(12,$timeout[$t]->[0]);
                    }else{
                        kill(9,$timeout[$t]->[0]);
                    }
                }
            }
            $t++;
        }
        select(undef,undef,undef,0.1) if ($t == 0);
    }
    
    return(@bad_nodes);
}


# Check if a property can be deleted or created by a user
# return 0 if all is good otherwise return 1
sub check_resource_property($){
    my $prop = shift;

    if ($prop =~ /^(resource_id|network_address|state|state_num|next_state|finaud_decision|next_finaud_decision|besteffort|desktop_computing|deploy|expiry_date|last_job_date|available_upto|walltime|nodes|type|suspended_jobs|scheduler_priority)$/){
        return(1);
    }else{
        return(0);
    }
}


# Check if a property can be manipulated by a user
# return 0 if all is good otherwise return 1
sub check_resource_system_property($){
    my $prop = shift;

    if ($prop =~ /^(resource_id|state|state_num|next_state|finaud_decision|next_finaud_decision|last_job_date|suspended_jobs|expiry_date|scheduler_priority)$/ ) {
        return(1);
    }else{
        return(0);
    }
}


# Manage commands on several nodes like cpuset or suspend job
# args : array of host to connect to, hashtable to transfer, name of the file containing the perl script, action to perform (start or stop), SSH command to use, taktuk cmd or undef, database ref
sub manage_remote_commands($$$$$$$){
    my $connect_hosts = shift;
    my $data_hash = shift;
    my $manage_file = shift;
    my $action = shift;
    my $ssh_cmd = shift;
    my $taktuk_cmd = shift;
    my $base = shift;
    
    my @bad;
    $ssh_cmd = $Default_openssh_cmd if (!defined($ssh_cmd));
    # Prepare commands to run on each node
    my $string_to_transfer;
    open(FILE, $manage_file) or return(0,undef);
    while(<FILE>){
        $string_to_transfer .= $_;
    }
    close(FILE);
    $string_to_transfer .= "__END__\n";
    # suitable Data::Dumper configuration for serialization
    $Data::Dumper::Purity = 1;
    $Data::Dumper::Terse = 1;
    $Data::Dumper::Indent = 0;
    $Data::Dumper::Deepcopy = 1;

    $string_to_transfer .= Dumper($data_hash);

    if (!defined($taktuk_cmd)){
        # Dispatch via sentinelle
        my @node_commands;
        my @node_corresponding;
        foreach my $n (@{$connect_hosts}){
            my $cmd = "$ssh_cmd -x -T $n TAKTUK_HOSTNAME=$n perl - $action";
            push(@node_commands, $cmd);
            push(@node_corresponding, $n);
        }
        my @bad_tmp = sentinelle(10,get_ssh_timeout(), \@node_commands, $string_to_transfer,$base);
        foreach my $b (@bad_tmp){
            push(@bad, $node_corresponding[$b]);
        }
    }else{
        # Dispatch via taktuk
        my %tmp_node_hash;

        pipe(tak_node_read,tak_node_write);
        pipe(tak_stdin_read,tak_stdin_write);
        pipe(tak_stdout_read,tak_stdout_write);
        my $pid = fork;
        if($pid == 0){
            #CHILD
            $SIG{CHLD} = 'DEFAULT';
            $SIG{TERM} = 'DEFAULT';
            $SIG{INT}  = 'DEFAULT';
            $SIG{QUIT} = 'DEFAULT';
            $SIG{USR1} = 'DEFAULT';
            $SIG{USR2} = 'DEFAULT';
            my $cmd = "$taktuk_cmd -c '$ssh_cmd' ".'-o status=\'"STATUS $host $line\n"\''." -f '<&=".fileno(tak_node_read)."' broadcast exec [ perl - $action ], broadcast input file [ - ], broadcast input close";
            fcntl(tak_node_read, F_SETFD, 0);
            close(tak_node_write);
            close(tak_stdout_read);
            close(STDOUT);
            # Redirect taktuk output into the pipe
            open(STDOUT, ">& tak_stdout_write");
        
            # Use the child STDIN to send the user command
            close(tak_stdin_write);
            close(STDIN);
            open(STDIN, "<& tak_stdin_read");

            exec($cmd);
            warn("[ERROR] Cannot execute $cmd\n");
            exit(-1);
        }
        close(tak_node_read);
        close(tak_stdin_read);
        close(tak_stdout_write);

        # Send node list
        foreach my $n (@{$connect_hosts}){
            $tmp_node_hash{$n} = 1;
            print(tak_node_write "$n\n");
        }
        close(tak_node_write);
       
        eval{
            $SIG{ALRM} = sub { kill(19,$pid); die "alarm\n" };
            alarm(OAR::Tools::get_taktuk_timeout());     
            # Send data structure to all nodes
            print(tak_stdin_write $string_to_transfer);
            close(tak_stdin_write);
            # Check good nodes from the stdout taktuk
            while(<tak_stdout_read>){
                if ($_ =~ /^STATUS ([\w\.\-\d]+) (\d+)$/){
                    if ($2 == 0){
                        delete($tmp_node_hash{$1}) if (defined($tmp_node_hash{$1}));
                    }
                }else{
                    print("[TAKTUK OUTPUT] $_");
                }
            }
            close(tak_stdout_read);
            waitpid($pid,0);
            alarm(0);
        };
        if ($@){
            if (defined($pid)){
                # Kill all taktuk children
                my ($children,$cmd_name) = get_one_process_children($pid);
                kill(9,@{$children});
            }
        }
        @bad = keys(%tmp_node_hash);
    }

    return(1,@bad);
}

# read a line on a socket
# arg1 --> socket
# arg2 --> timeout
# return 0 if the read times out
sub read_socket_line($$){
    my $sock = shift;
    my $timeout = shift;

    my $char = "a";
    my $res = 1;
    my $rin = '';
    my $line;
    vec($rin,fileno($sock),1) = 1;
    my $rin_tmp;
    while (($res > 0) && ($char ne "\n") && ($char ne "")){
        $res = select($rin_tmp = $rin, undef, undef, $timeout);
        if ($res > 0){
            sysread($sock,$char,1);
            if ($char ne "\n"){
                $line .= $char;
            }
        }
    }
    return($res,$line);
}

1;
}
