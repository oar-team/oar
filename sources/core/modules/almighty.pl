#!/usr/bin/perl

use strict;
use Data::Dumper;
use IO::Socket::INET;
use OAR::Modules::Judas qw(oar_debug oar_warn oar_error send_log_by_email set_current_log_category);
use OAR::Conf qw(init_conf dump_conf get_conf is_conf get_conf_with_default_param);
use OAR::Tools;
use OAR::Modules::Hulot;
use POSIX qw(:signal_h :errno_h :sys_wait_h);

# Log category
set_current_log_category('main');

my $Old_umask = sprintf("%lo",umask());
umask(oct("022"));

my $oldfh = select(STDERR); $| = 1; select($oldfh);
$oldfh = select(STDOUT); $| = 1; select($oldfh);

#Everything is run by oar user
$ENV{OARDO_UID}=$<;

my $Redirect_STD_process = OAR::Modules::Judas::redirect_everything();
my $Module_name = "Almighty";
my $Session_id = $$;

oar_warn($Module_name, "Start Almighty\n", $Session_id);
send_log_by_email("Start OAR server","[Almighty] Start Almighty");

# Signal handle system
my $finishTag = 0;
sub signalHandler(){
    $finishTag = 1;
}

#To avoid zombie processes
$SIG{CHLD} = 'IGNORE';

$SIG{USR1}  = \&signalHandler;
$SIG{INT}  = \&signalHandler;
$SIG{TERM}  = \&signalHandler;

init_conf($ENV{OARCONFFILE});
my $binpath;
if (defined($ENV{OARDIR})){
    $binpath = $ENV{OARDIR}."/";
}else{
    oar_error($Module_name, "OARDIR env variable must be defined\n", $Session_id);
    exit(1);
}

my $meta_sched_command = get_conf_with_default_param("META_SCHED_CMD", "oar_meta_sched");
my $scheduler_command = (($meta_sched_command =~ /^\//)?"":$binpath).$meta_sched_command;
my $check_for_villains_command = $binpath."sarko";
my $check_for_node_changes = $binpath."finaud";
my $leon_command = $binpath."Leon";
my $nodeChangeState_command = $binpath."NodeChangeState";
my $bipbip_command = $binpath."bipbip";

my $server;
my $serverport;
if (is_conf("SERVER_PORT")){
    $serverport = get_conf("SERVER_PORT");
}else{
    oar_error($Module_name, "You must have a oar.conf file with a valid SERVER_PORT tag\n", $Session_id);
    exit(1);
}
my $servermaxconnect=100;

# This timeout is used by appendice to prevent a client to block
# reception by letting a connection opened
# should be left at a positive value
my $appendice_connection_timeout = 5;

# This timeout is used to slowdown the main automaton when the
# command queue is empty, it correspond to a blocking read of
# new commands. A High value is likely to reduce the CPU usage of
# the Almighty.
# Setting it to 0 or a low value is not likely to improve performance
# dramatically (because it blocks only when nothing else is to be done).
# Nevertheless it is closely related to the precision at which the
# internal counters are checked
my $read_commands_timeout = 10;

# This parameter sets the number of pending commands read from
# appendice before proceeding with internal work
# should not be set at a too high value as this would make the
# Almighty weak against flooding
my $max_successive_read = 100;

# Max waiting time before new scheduling attempt (in the case of
# no notification)
my $schedulertimeout = 60;
# Min waiting time before 2 scheduling attempts
my $scheduler_min_time_between_2_calls = get_conf_with_default_param("SCHEDULER_MIN_TIME_BETWEEN_2_CALLS", 5);
my $scheduler_wanted = 0; # 1 if the scheduler must be run next time update

# Max waiting time before check for jobs whose time allowed has elapsed
my $villainstimeout = 10;

# Max waiting time before check node states
my $checknodestimeout = get_conf_with_default_param("FINAUD_FREQUENCY", 300);

# Max number of concurrent bipbip processes
my $Max_bipbip_processes = get_conf_with_default_param("MAX_CONCURRENT_JOBS_STARTING_OR_TERMINATING", 25);
my $Detach_oarexec = get_conf_with_default_param("DETACH_JOB_FROM_SERVER",0);

# Maximum duration a a bipbip process (after that time the process is killed)
my $Max_bipbip_process_duration = 30*60;

my $Log_file = get_conf_with_default_param("LOG_FILE", "/var/log/oar.log");

# Regexp of the notification received from oarexec processes
#   $1: job id
#   $2: oarexec exit code
#   $3: job script exit code
#   $4: secret string that identifies the oarexec process (for security)
my $OAREXEC_REGEXP = 'OAREXEC_(\d+)_(\d+)_(\d+|N)_(\d+)';

# Regexp of the notification received when a job must be launched
#   $1: job id
my $OARRUNJOB_REGEXP = 'OARRUNJOB_(\d+)';

# Regexp of the notification received when a job must be exterminate
#   $1: job id
my $LEONEXTERMINATE_REGEXP = 'LEONEXTERMINATE_(\d+)';


# Internal stuff, not relevant for average user
my $lastscheduler;
my $lastvillains;
my $lastchecknodes;
my @internal_command_file;
my $appendice_pid;
my $energy_pid;

# launch the command line passed in parameter
sub launch_command($){
        my $command = shift;
        oar_debug($Module_name, "Launching command: [$command]\n", $Session_id);
        #$ENV{PATH}="/bin:/usr/bin:/usr/local/bin";
####### THE LINE BELOW SHOULD NOT BE COMMENTED IN NORMAL USE #####
        $SIG{CHLD} = 'DEFAULT';
        #system $command;
        my $pid=0;
        $pid=fork;
        if($pid==0){
            #CHILD
            $SIG{USR1} = 'IGNORE';
            $SIG{INT}  = 'IGNORE';
            $SIG{TERM} = 'IGNORE';
            $0="Almighty: $command";
            exec($command); 
        }
        my $kid;
        while ($kid != $pid){
            #release zombie and check the end of $command
            $kid = wait();
        }
        $SIG{CHLD} = 'IGNORE';
        my $exit_value  = $? >> 8;
        my $signal_num  = $? & 127;
        my $dumped_core = $? & 128;
        oar_debug($Module_name, "$command terminated with exit value: $exit_value ; signal num: $signal_num ; core dumped: $dumped_core\n", $Session_id);
        if ($signal_num || $dumped_core){
            oar_error($Module_name, "Something wrong occured (signal or core dumped) when trying to call [$command] command\n", $Session_id);
            $finishTag = 1;
            #exit(2);
        }
        return $exit_value;
}

# listening procedure used by the appendice, a forked process dedicated
# to the listening of commands
sub qget_appendice(){
        my $answer;
        my $rin = '';
        my $res;
        my $carac;
        my $client=$server->accept();
        oar_debug($Module_name, "Appendice received a connection\n", $Session_id);
        if (!defined($client)){
            oar_error($Module_name, "End of appendice listening: the socket disappeared\n", $Session_id);
            exit(16);
        }
        # non-blocking read
        $rin = '';
        my $rinTmp = '';
        vec($rin,fileno($client),1) = 1;
        $res = select($rinTmp = $rin, undef, undef, $appendice_connection_timeout);
        $carac="A";
        while (($res > 0) && ($carac ne "\n")){
            if (!defined(sysread($client, $carac, 1))){
                oar_warn($Module_name, "End of appendice listening for the current client, client socket is undef; MAYBE SOMEONE USE NMAP ON THE SERVER SOCKET !!!\n", $Session_id);
                #exit(3);
                $res = 0;
            }elsif ($carac eq ""){
                #something wrong occured, we quit this loop. socket was closed
                $res = 0;
            }elsif ($carac ne "\n"){
                $answer = $answer.$carac;
                $res = select($rinTmp = $rin, undef, undef, $appendice_connection_timeout);
            }
        }

        # cleans the answer of all unwanted trailing characters
        $carac=chop $answer;
        while ($answer && $carac !~ '[a-zA-Z0-9]'){
            $carac=chop $answer;
        }
        $answer = $answer.$carac;
        # with nmap these lines crash the appendice
        #print $client "Your request [$answer] was received\n";
        close($client);

        return $answer;
}

# main body of the appendice, a forked process dedicated
# to the listening of commands
# the interest of such a forked process is to ensure that clients get their
# notification as soon as possible (i.e. reactivity) even if the almighty is
# performing some other internal task in the meantime
sub comportement_appendice(){
    close READ;

    # Initialize bipbip process handler
    ## pipe to communicate with the "Almighty: bipbip" process that launches
    ## and manages bipbip processes
    pipe(pipe_bipbip_read,pipe_bipbip_write);
    autoflush pipe_bipbip_write 1;
    autoflush pipe_bipbip_read 1;

    my $bipbip_launcher_pid=0;
    $bipbip_launcher_pid=fork();
    if ($bipbip_launcher_pid==0){
        #CHILD
        oar_debug($Module_name, "Start bipbip handler process\n", $Session_id);
        close(pipe_bipbip_write);
        $SIG{USR1} = 'IGNORE';
        $SIG{INT}  = 'IGNORE';
        $SIG{TERM} = 'IGNORE';
        $0="Almighty: bipbip";
        # Pipe to handle children ending
        pipe(pipe_bipbip_children_read,pipe_bipbip_children_write);
        autoflush pipe_bipbip_children_write 1;
        autoflush pipe_bipbip_children_read 1;
        # Handle finished bipbip processes
        sub bipbip_child_signal_handler {
            $SIG{CHLD} = \&bipbip_child_signal_handler;
            my $wait_pid_ret ;
            while (($wait_pid_ret = waitpid(-1,WNOHANG)) > 0){
                my $exit_value = $? >> 8;
                print(pipe_bipbip_children_write "$wait_pid_ret $exit_value\n");
            }
        }
        $SIG{CHLD} = \&bipbip_child_signal_handler;

        my $rin_pipe = '';
        vec($rin_pipe,fileno(pipe_bipbip_read),1) = 1;
        my $rin_sig = '';
        vec($rin_sig,fileno(pipe_bipbip_children_read),1) = 1;
        my $rin = $rin_pipe | $rin_sig;
        my $rin_tmp;
        my $stop = 0;
        my %bipbip_children = (); my %bipbip_current_processing_jobs = ();
        my @bipbip_processes_to_run = ();
        while ($stop == 0){ 
            select($rin_tmp = $rin, undef, undef, undef);
            my $current_time = time();
            if (vec($rin_tmp, fileno(pipe_bipbip_children_read), 1)){
                my ($res_read,$line_read) = OAR::Tools::read_socket_line(\*pipe_bipbip_children_read,1);
                if ($line_read =~ m/(\d+) (\d+)/m){
                    my $process_duration = $current_time -  $bipbip_current_processing_jobs{$bipbip_children{$1}}->[1];
                    oar_debug($Module_name, "Process $1 for the job $bipbip_children{$1} ends with exit_code=$2, duration=${process_duration}s\n", $Session_id);
                    delete($bipbip_current_processing_jobs{$bipbip_children{$1}});
                    delete($bipbip_children{$1});
                }else{
                    oar_warn($Module_name, "Read a malformed string in pipe_bipbip_children_read: $line_read\n", $Session_id);
                }
            }elsif (vec($rin_tmp, fileno(pipe_bipbip_read), 1)){
                my ($res_read,$line_read) = OAR::Tools::read_socket_line(\*pipe_bipbip_read,1);
                if (($res_read == 1) and ($line_read eq "")){
                    $stop = 1;
                    oar_warn($Module_name, "Father pipe closed so we stop the process\n", $Session_id);
                }elsif (($line_read =~ m/$OAREXEC_REGEXP/m) or
                        ($line_read =~ m/$OARRUNJOB_REGEXP/m) or
                        ($line_read =~ m/$LEONEXTERMINATE_REGEXP/m)){
                    if (!grep(/^$line_read$/,@bipbip_processes_to_run)){
                        oar_debug($Module_name, "Read on pipe: $line_read\n", $Session_id);
                        push(@bipbip_processes_to_run, $line_read);
                    }
                }else{
                    oar_warn($Module_name, "Read a bad string: $line_read\n", $Session_id);
                }
            }
            my @bipbip_processes_to_requeue = ();
            while(($stop == 0) and ($#bipbip_processes_to_run >= 0) and (keys(%bipbip_children) < $Max_bipbip_processes)){
                my $str = shift(@bipbip_processes_to_run);
                my $cmd_to_run;
                my $bipbip_job_id = 0;
                if ($str =~ m/$OAREXEC_REGEXP/m){
                    $cmd_to_run = "$bipbip_command $1 $2 $3 $4";
                    $bipbip_job_id = $1;
                }elsif ($str =~ m/$OARRUNJOB_REGEXP/m){
                    $cmd_to_run = "$bipbip_command $1";
                    $bipbip_job_id = $1;
                }elsif ($str =~ m/$LEONEXTERMINATE_REGEXP/m){
                    $cmd_to_run = "$leon_command $1";
                    $bipbip_job_id = $1;
                }
                if ($bipbip_job_id > 0){
                    if (defined($bipbip_current_processing_jobs{$bipbip_job_id})){
                        if (!grep(/^$str$/,@bipbip_processes_to_run)){
                            oar_debug($Module_name, "A process is already running for the job $bipbip_job_id. We requeue: $str\n", $Session_id);
                            push(@bipbip_processes_to_requeue, $str);
                        }
                    }else{
                        my $pid=0;
                        $pid=fork;
                        if (!defined($pid)){
                            oar_error($Module_name, "Fork failed, I kill myself\n", $Session_id);
                            exit(2);
                        }
                        if($pid==0){
                            #CHILD
                            $SIG{USR1} = 'IGNORE';
                            $SIG{INT}  = 'IGNORE';
                            $SIG{TERM} = 'IGNORE';
                            $SIG{CHLD} = 'DEFAULT';
                            open (STDIN, "</dev/null");
                            open (STDOUT, ">> $Log_file");
                            open (STDERR, ">&STDOUT");
                            exec("$cmd_to_run");
                            oar_error($Module_name, "failed exec: $cmd_to_run\n", $Session_id);
                            exit(1);
                        }
                        $bipbip_current_processing_jobs{$bipbip_job_id} = [$pid, $current_time];
                        $bipbip_children{$pid} = $bipbip_job_id;
                        oar_debug($Module_name, "Run process: $cmd_to_run\n", $Session_id);
                    }
                }else{
                    oar_warn($Module_name, "Bad string read in the bipbip queue: $str\n", $Session_id);
                }
            }
            push(@bipbip_processes_to_run, @bipbip_processes_to_requeue);
            oar_debug($Module_name, "Nb running bipbip: ".keys(%bipbip_children)."/$Max_bipbip_processes; Waiting processes(".($#bipbip_processes_to_run + 1)."): @bipbip_processes_to_run\n", $Session_id);
            # Check if some bipbip processes are blocked; this must never happen
            if ($Detach_oarexec != 0){
                foreach my $b (keys(%bipbip_current_processing_jobs)){
                    my $process_duration = $current_time -  $bipbip_current_processing_jobs{$b}->[1];
                    oar_debug($Module_name, "Check bipbip process duration: job=$b, pid=$bipbip_current_processing_jobs{$b}->[0], time=$bipbip_current_processing_jobs{$b}->[1], current_time=$current_time, duration=${process_duration}s\n", $Session_id);
                    if ($bipbip_current_processing_jobs{$b}->[1] < ($current_time - $Max_bipbip_process_duration)){
                        oar_warn($Module_name, "Max duration for the bipbip process $bipbip_current_processing_jobs{$b}->[0] reached (${Max_bipbip_process_duration}s); job $b\n", $Session_id);
                        kill(9, $bipbip_current_processing_jobs{$b}->[0]);
                    }
                }
            }
        }
        oar_warn($Module_name, "End of process\n", $Session_id);
        exit(1);
    }

    close(pipe_bipbip_read);
    while (1){
        my $answer = qget_appendice();
        oar_debug($Module_name, "Appendice has read on the socket: $answer\n", $Session_id);
        if (($answer =~ m/$OAREXEC_REGEXP/m) or
            ($answer =~ m/$OARRUNJOB_REGEXP/m) or
            ($answer =~ m/$LEONEXTERMINATE_REGEXP/m)){
            if (! print pipe_bipbip_write "$answer\n"){
                oar_error($Module_name, "Appendice cannot communicate with bipbip_launcher process, I kill myself\n", $Session_id);
                exit(2);
            }
            flush pipe_bipbip_write;
        }elsif ($answer ne ""){
            print WRITE "$answer\n";
            flush WRITE;
        }else{
            oar_debug($Module_name, "A connection was opened but nothing was written in the socket\n", $Session_id);
            #sleep(1);
        }
    }
}

# hulot module forking
sub start_hulot(){
    $energy_pid = fork();
    if(!defined($energy_pid)){
        oar_error($Module_name, "Cannot fork Hulot, the energy saving module\n", $Session_id);
        exit(6);
    }
    if (!$energy_pid){
        $SIG{CHLD} = 'DEFAULT';
        $SIG{USR1}  = 'IGNORE';
        $SIG{INT}  = 'IGNORE';
        $SIG{TERM}  = 'IGNORE';
        $0="Almighty: hulot";
        OAR::Modules::Hulot::start_energy_loop();
        oar_error($Module_name, "Energy saving loop (hulot) exited. This should not happen.\n", $Session_id);
        exit(7);
    }
}

# check the hulot process
sub check_hulot(){
  return kill 0, $energy_pid;
}

# Clean ipcs
sub ipc_clean(){
        open(IPCS,"/proc/sysvipc/msg");
        my @oar = getpwnam('oar');
        while (<IPCS>) {
        my @ipcs=split;
          if ($ipcs[7] eq $oar[2]) {
            my $ipc=$ipcs[1];
            oar_debug($Module_name, "cleaning ipc $ipc\n", $Session_id);
            `/usr/bin/ipcrm -q $ipc`;
          }
        }
        close(IPCS);
}
 
# initial stuff that has to be done
sub init(){
    if(!(pipe (READ, WRITE))){
        oar_error($Module_name, "Cannot open pipe !!!\n", $Session_id);
        exit(5);
    }

    autoflush READ 1;
    autoflush WRITE 1;

    $server = IO::Socket::INET->new(LocalPort=> $serverport,
                                    Type => SOCK_STREAM,
                                    Reuse => 1,
                                    Listen => $servermaxconnect);
    #or die "ARG.... Can't open server socket\n";
    if (!defined($server)){
        warn("ARG.... Cannot open server socket, an Almighty process must be already started\n");
        oar_error($Module_name, "ARG.... Cannot open server socket, an Almighty process must be already started\n", $Session_id);
        exit(4);
    }

    $SIG{PIPE}  = 'IGNORE'; #Must be catch otherwise the appendice can finish abnormally
    $appendice_pid = fork();

    if(!defined($appendice_pid)){
        oar_error($Module_name, "Cannot fork appendice (fork process dedicated to the listening of commands from clients)\n", $Session_id);
        exit(6);
    }
    if (!$appendice_pid){
        $SIG{USR1}  = 'IGNORE';
        $SIG{INT}  = 'IGNORE';
        $SIG{TERM}  = 'IGNORE';
        $0="Almighty: appendice";
        comportement_appendice();
        oar_error($Module_name, "Returned from comportement_appendice, this should not happen (infinite loop for listening messages on the server socket)\n", $Session_id);
        exit(7);
    }
    close WRITE;
    close $server;

    # Starting of Hulot, the Energy saving module
    if (get_conf_with_default_param("ENERGY_SAVING_INTERNAL", "no") eq "yes") {
      start_hulot();
   }

    $lastscheduler= 0;
    $lastvillains= 0;
    $lastchecknodes= 0;
    @internal_command_file = ();
    oar_debug($Module_name, "Init done\n", $Session_id);
}

# function used by the main automaton to get notifications pending
# inside the appendice
sub qget($){
    my $timeout = shift;
    my $answer="";
    my $rin = '';
    my $rinTmp = '';
    my $carac;
    vec($rin,fileno(READ),1) = 1;
    my $res = select($rinTmp = $rin, undef, undef, $timeout);
    if ($res > 0){
        $carac="OAR";
        while ($carac ne "\n"){
            if ((!defined(sysread(READ, $carac, 1))) || ($carac eq "")){
                oar_error($Module_name, "Error while reading in pipe: I guess Appendice has died\n", $Session_id);
                exit(8);
            }
            if ($carac ne "\n"){
                $answer = $answer.$carac;
            }
        }
    }elsif ($res < 0){
        if ($finishTag == 1){
            oar_debug($Module_name, "Premature end of select cmd. res = $res. It is normal, Almighty is stopping\n", $Session_id);
            $answer = "Time";
        }else{
            oar_error($Module_name, "Error while reading in pipe: I guess Appendice has died, the result code of select = $res\n", $Session_id);
            exit(15);
        }
    }else{
        $answer = "Time";
    }
    return $answer;
}

# functions for managing the file of commands pending
sub add_command($){
    my $command = shift;

    # as commands are just notifications that will
    # handle all the modifications in the base up to now, we should
    # avoid duplication in the command file
    if (!grep(/^$command$/,@internal_command_file)){
        push @internal_command_file, $command;
    }
}

# read commands until reaching the maximal successive read value or
# having read all of the pending commands
sub read_commands($){
    my $timeout = shift;
    my $command = "";
    my $remaining = $max_successive_read;

    while (($command ne "Time") && $remaining){
        if ($remaining != $max_successive_read){
                $timeout = 0;
        }
        $command = qget($timeout);
        add_command($command);
        $remaining--;
        oar_debug($Module_name, "Got command $command, $remaining remaining\n", $Session_id);
    }
    
    # The special case of the Time command
    # semantic: the queue is empty so the Almighty should go
    # directly to the state of updating of its internal counters
    push @internal_command_file,"Time"
    unless scalar @internal_command_file;
}

# functions associated with each state of the automaton
sub scheduler(){
    return launch_command $scheduler_command;
}

sub time_update(){
    my $current = time;

    oar_debug($Module_name, "Timeouts check: $current\n", $Session_id);
    # check timeout for scheduler
    if (($current>=($lastscheduler+$schedulertimeout))
        or (($scheduler_wanted >= 1) and ($current>=($lastscheduler+$scheduler_min_time_between_2_calls)))
       ){
        oar_debug($Module_name, "Scheduling timeout\n", $Session_id);
        #$lastscheduler = $current + $schedulertimeout;
        add_command("Scheduling");
    }
    if ($current>=($lastvillains+$villainstimeout)){
        oar_debug($Module_name, "Villains check timeout\n", $Session_id);
        #$lastvillains = $current + $villainstimeout;
        add_command("Villains");
    }
    if (($current>=($lastchecknodes+$checknodestimeout)) and ($checknodestimeout > 0)){
        oar_debug($Module_name, "Node check timeout\n", $Session_id);
        #$lastchecknodes = $current + $checknodestimeout;
        add_command("Finaud");
    }
}

sub check_for_villains(){
    return launch_command $check_for_villains_command;
}

sub check_nodes(){
    return launch_command $check_for_node_changes;
}

sub leon(){
    return launch_command "$leon_command";
}

sub nodeChangeState(){
    return launch_command $nodeChangeState_command;
}

# MAIN PROGRAM: Almighty AUTOMATON
my $state= "Init";
my $command;
my $id;
my $node;
my $pid;

while (1){
    oar_debug($Module_name, "Current state [$state]\n", $Session_id);
    #We stop Almighty and its child
    if ($finishTag == 1){
        if (defined($energy_pid)) {
          oar_debug($Module_name, "kill child process $energy_pid\n", $Session_id);
          kill(9,$energy_pid);
        }
        oar_debug($Module_name, "kill child process $appendice_pid\n", $Session_id);
        kill(9,$appendice_pid);
        kill(9,$Redirect_STD_process) if ($Redirect_STD_process > 0);
        ipc_clean();
        oar_warn($Module_name, "Stop Almighty\n", $Session_id);
        send_log_by_email("Stop OAR server","[Almighty] Stop Almighty");
        exit(10);
    }

    # We check Hulot
    if (defined($energy_pid) && !check_hulot()) {
      oar_warn($Module_name, "Energy saving module (hulot) died. Restarting it.\n", $Session_id);
      sleep 5;
      ipc_clean();
      start_hulot();
    }

    # INIT
    if($state eq "Init"){
        init();
        $state="Qget";
    }

    # QGET
    elsif($state eq "Qget"){
        if (scalar @internal_command_file){
            read_commands(0);
        }else{
            read_commands($read_commands_timeout);
        }

        oar_debug($Module_name, "Command queue: @internal_command_file\n", $Session_id);
        my $current_command = shift(@internal_command_file);
        my ($command,$arg1,$arg2,$arg3) = split(/ /,$current_command);

        oar_debug($Module_name, "Qtype = [$command]\n", $Session_id);
        if (($command eq "Qsub") ||
        ($command eq "Term") ||
        ($command eq "BipBip") ||
        ($command eq "Scheduling") ||
        ($command eq "Qresume") ||
        ($command eq "Walltime")
        ){
            $state="Scheduler";
        }elsif( $command eq "Qdel"){
            $state="Leon";
        }elsif($command eq "Villains"){
            $state="Check for villains";
        }elsif($command eq "Finaud"){
            $state="Check node states";
        }elsif ($command eq "Time"){
            $state="Time update";
        }elsif ($command eq "ChState"){
            $state="Change node state";
        }else{
            oar_debug($Module_name, "Unknown command found in queue: $command\n", $Session_id);
        }
    }

    # SCHEDULER
    elsif($state eq "Scheduler"){
        my $current_time = time();
        if ($current_time >= ($lastscheduler+$scheduler_min_time_between_2_calls)){
            $scheduler_wanted = 0;
            # First, check pending events
            my $check_result=nodeChangeState();
            if ($check_result == 2){
                $state="Leon";
                add_command("Term");
            }elsif ($check_result == 1){
                $state="Scheduler";
            }elsif ($check_result == 0){
                #Launch the scheduler 
                   # We check Hulot just before starting the scheduler
                   # because if the pipe is not read, it may freeze oar
                   if (defined($energy_pid) && !check_hulot()) {
                     oar_warn($Module_name, "Energy saving module (hulot) died. Restarting it.\n", $Session_id);
                     sleep 5;
                     ipc_clean();
                     start_hulot();
                   }
                my $scheduler_result=scheduler();
                $lastscheduler = time();
                if ($scheduler_result == 0){
                    $state="Time update";
                }elsif ($scheduler_result == 1){
                    $state="Scheduler";
                }elsif ($scheduler_result == 2){
                    $state="Leon";
                }else{
                    oar_error($Module_name, "Scheduler returned an unknown value: $scheduler_result\n", $Session_id);
                    $finishTag = 1;
                }
            }else{
                oar_error($Module_name, "$nodeChangeState_command returned an unknown value\n", $Session_id);
                $finishTag = 1;
            }
        }else{
            $scheduler_wanted = 1;
            $state="Time update";
            oar_debug($Module_name, "Scheduler call too early, waiting... ($current_time >= ($lastscheduler + $scheduler_min_time_between_2_calls)\n", $Session_id);
        }
    }

    # TIME UPDATE
    elsif($state eq "Time update"){
        time_update();
        $state="Qget";
    }

    # CHECK FOR VILLAINS
    elsif($state eq "Check for villains"){
        my $check_result=check_for_villains();
        $lastvillains = time();
        if ($check_result == 1){
            $state="Leon";
        }elsif ($check_result == 0){
            $state="Time update";
        }else{
            oar_error($Module_name, "$check_for_villains_command returned an unknown value: $check_result\n", $Session_id);
            $finishTag = 1;
        }
    }

    # CHECK NODE STATES
    elsif($state eq "Check node states"){
        my $check_result=check_nodes();
        $lastchecknodes = time();
        if ($check_result == 1){
            $state="Change node state";
        }elsif ($check_result == 0){
            $state="Time update";
        }else{
            oar_error($Module_name, "$check_for_node_changes returned an unknown value\n", $Session_id);
            $finishTag = 1;
        }
    }

    # LEON
    elsif($state eq "Leon"){
        my $check_result = leon();
        $state="Time update";
        if ($check_result == 1){
            add_command("Term");
        }
    }

    # Change state for dynamic nodes
    elsif($state eq "Change node state"){
        my $check_result=nodeChangeState();
        if ($check_result == 2){
            $state="Leon";
            add_command("Term");
        }elsif ($check_result == 1){
            $state="Scheduler";
        }elsif ($check_result == 0){
            $state="Time update";
        }else{
            oar_error($Module_name, "$nodeChangeState_command returned an unknown value\n", $Session_id);
            $finishTag = 1;
        }
    }else{
        oar_warn($Module_name, "Critical bug !!!!\n", $Session_id);
        oar_error($Module_name, "Almighty just falled into an unknown state !!!\n", $Session_id);
        $finishTag = 1;
    }
}
