#!/usr/bin/perl

use strict;
use Data::Dumper;
use IO::Socket::INET;
use oar_Judas qw(oar_debug oar_warn oar_error send_log_by_email set_current_log_category);
use oar_conflib qw(init_conf dump_conf get_conf is_conf get_conf_with_default_param);
use oar_Tools;
use oar_Hulot;

# Log category
set_current_log_category('main');

my $Old_umask = sprintf("%lo",umask());
umask(oct("022"));

my $oldfh = select(STDERR); $| = 1; select($oldfh);
$oldfh = select(STDOUT); $| = 1; select($oldfh);

#Everything is run by oar user
$ENV{OARDO_UID}=$<;

my $Redirect_STD_process = oar_Judas::redirect_everything();

oar_warn("[Almighty] Start Almighty\n");
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
    oar_error("[Almighty] OARDIR env variable must be defined\n");
    exit(1);
}


my $scheduler_command = $binpath."oar_meta_sched";
my $runner_command = $binpath."runner";
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
    oar_error("[Almighty] You must have a oar.conf file with a valid SERVER_PORT tag\n");
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

# Max waiting time before check for jobs whose time allowed has elapsed
my $villainstimeout = 10;

# Max waiting time before check node states
my $checknodestimeout = get_conf_with_default_param("FINAUD_FREQUENCY", 300);

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
        oar_debug("[Almighty] Launching command : [$command]\n");
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
        oar_debug("[Almighty] $command terminated :\n");
        oar_debug("[Almighty] Exit value : $exit_value\n");
        oar_debug("[Almighty] Signal num : $signal_num\n");
        oar_debug("[Almighty] Core dumped : $dumped_core\n");
        if ($signal_num || $dumped_core){
            oar_error("[Almighty] Something wrong occured (signal or core dumped) when trying to call [$command] command\n");
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
        oar_debug("[Almighty] Appendice received a connection\n");
        if (!defined($client)){
            oar_error("[Almighty] End of appendice listening : the socket disappeared\n");
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
                oar_warn("[Almighty] End of appendice listening for the current client, client socket is undef; MAYBE SOMEONE USE NMAP ON THE SERVER SOCKET !!!\n");
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

        while (1){
            my $answer = qget_appendice();
            if ($answer =~ m/OAREXEC_(\d+)_(\d+)_(\d+|N)_(\d+)/m){
                my $pid=0;
                $pid=fork;
                if($pid==0){
                    #CHILD
                    $SIG{USR1} = 'IGNORE';
                    $SIG{INT}  = 'IGNORE';
                    $SIG{TERM} = 'IGNORE';
                    $0="Almighty: bipbip";
                    exec("$bipbip_command $1 $2 $3 $4");
                }
                oar_debug("[Almighty] called bipbip with params: $1 $2 $3 $4\n");
                #launch_command("$bipbip_command $1 ATTACH &");
            }elsif ($answer ne ""){
                oar_debug("[Almighty] Appendice has read on the socket : $answer\n");
                print WRITE "$answer\n";
                flush WRITE;
            }else{
                oar_debug("[Almighty] A connection was opened but nothing was written in the socket\n");
                #sleep(1);
            }
        }
}

# hulot module forking
sub start_hulot(){
    $energy_pid = fork();
    if(!defined($energy_pid)){
        oar_error("[Almighty] Cannot fork Hulot, the energy saving module\n");
        exit(6);
    }
    if (!$energy_pid){
        $SIG{CHLD} = 'DEFAULT';
        $SIG{USR1}  = 'IGNORE';
        $SIG{INT}  = 'IGNORE';
        $SIG{TERM}  = 'IGNORE';
        $0="Almighty: hulot";
        oar_Hulot::start_energy_loop();
        oar_error("[Almighty] Energy saving loop (hulot) exited. This should not happen.\n");
        exit(7);
    }
}

# check the hulot process
sub check_hulot(){
  return kill 0, $energy_pid;
}
 
# initial stuff that has to be done
sub init(){
    if(!(pipe (READ, WRITE))){
        oar_error("[Almighty] Cannot open pipe !!!\n");
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
        oar_error("[Almighty] ARG.... Cannot open server socket, an Almighty process must be already started\n");
        exit(4);
    }

    $SIG{PIPE}  = 'IGNORE'; #Must be catch otherwise the appendice can finish abnormally
    $appendice_pid = fork();

    if(!defined($appendice_pid)){
        oar_error("[Almighty] Cannot fork appendice (fork process dedicated to the listening of commands from clients)\n");
        exit(6);
    }
    if (!$appendice_pid){
        $SIG{USR1}  = 'IGNORE';
        $SIG{INT}  = 'IGNORE';
        $SIG{TERM}  = 'IGNORE';
        $0="Almighty: appendice";
        comportement_appendice();
        oar_error("[Almighty] Returned from comportement_appendice, this should not happen (infinite loop for listening messages on the server socket)\n");
        exit(7);
    }
    close WRITE;
    close $server;

    # Starting of Hulot, the Energy saving module
    if (get_conf_with_default_param("ENERGY_SAVING_INTERNAL", "no") eq "yes") {
      start_hulot();
   }

    $lastscheduler= time;
    $lastvillains= time;
    $lastchecknodes= time;
    @internal_command_file = ();
    oar_debug("[Almighty] Init done\n");
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
                oar_error("[Almighty] Error while reading in pipe : I guess Appendice has died\n");
                exit(8);
            }
            if ($carac ne "\n"){
                $answer = $answer.$carac;
            }
        }
    }elsif ($res < 0){
        if ($finishTag == 1){
            oar_debug("[Almighty] Premature end of select cmd. res = $res. It is normal, Almighty is stopping\n");
            $answer = "Time";
        }else{
            oar_error("[Almighty] Error while reading in pipe : I guess Appendice has died, the result code of select = $res\n");
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
        oar_debug("[Almighty] Got command $command, $remaining remaining\n");
    }
    
    # The special case of the Time command
    # semantic : the queue is empty so the Almighty should go
    # directly to the state of updating of its internal counters
    push @internal_command_file,"Time"
    unless scalar @internal_command_file;
}

# functions associated with each state of the automaton
sub scheduler(){
    return launch_command $scheduler_command;
}

sub runner(){
    return launch_command $runner_command;
}

sub time_update(){
    my $current = time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($current);

    $year+=1900;
    $mon+=1;
    oar_debug("[Almighty] Timeouts check : $year-$mon-$mday $hour:$min:$sec\n");
    # check timeout for scheduler
    if ($current>=($lastscheduler+$schedulertimeout)){
        oar_debug("[Almighty] Scheduling timeout\n");
        #$lastscheduler = $lastscheduler+$schedulertimeout;
        $lastscheduler = $current + $schedulertimeout;
        add_command("Scheduling");
    }
    if ($current>=($lastvillains+$villainstimeout)){
        oar_debug("[Almighty] Villains check timeout\n");
        #$lastvillains = $lastvillains+$villainstimeout;
        $lastvillains = $current + $villainstimeout;
        add_command("Villains");
    }
    if (($current>=($lastchecknodes+$checknodestimeout)) and ($checknodestimeout > 0)){
        oar_debug("[Almighty] Node check timeout\n");
        #$lastchecknodes = $lastchecknodes+$checknodestimeout;
        $lastchecknodes = $current + $checknodestimeout;
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

# MAIN PROGRAM : Almighty AUTOMATON
my $state= "Init";
my $command;
my $id;
my $node;
my $pid;

while (1){
    oar_debug("[Almighty] Current state [$state]\n");
    #We stop Almighty and its child
    if ($finishTag == 1){
        if (defined($energy_pid)) {
          oar_debug("[Almighty] kill child process $energy_pid\n");
          kill(9,$energy_pid);
        }
        oar_debug("[Almighty] kill child process $appendice_pid\n");
        kill(9,$appendice_pid);
        kill(9,$Redirect_STD_process) if ($Redirect_STD_process > 0);
        # Clean ipcs
        open(IPCS,"/proc/sysvipc/msg");
        my @oar = getpwnam('oar');
        while (<IPCS>) {
        my @ipcs=split;
          if ($ipcs[7] eq $oar[2]) {
            my $ipc=$ipcs[1];
            oar_debug("[Almighty] cleaning ipc $ipc\n");
            `/usr/bin/ipcrm -q $ipc`;
          }
        }
        oar_warn("[Almighty] Stop Almighty\n");
        send_log_by_email("Stop OAR server","[Almighty] Stop Almighty");
        exit(10);
    }

    # We check Hulot
    if (defined($energy_pid) && !check_hulot()) {
      oar_warn("[Almighty] Energy saving module (hulot) died. Restarting it.\n");
      sleep 5;
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

        oar_debug("[Almighty] Command queue : @internal_command_file\n");
        my $current_command = shift(@internal_command_file);
        my ($command,$arg1,$arg2,$arg3) = split(/ /,$current_command);

        oar_debug("[Almighty] Qtype = [$command]\n");
        if (($command eq "Qsub") ||
        ($command eq "Term") ||
        ($command eq "BipBip") ||
        ($command eq "Scheduling") ||
        ($command eq "Qresume")
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
            oar_debug("[Almighty] Unknown command found in queue : $command\n");
        }
    }

    # SCHEDULER
    elsif($state eq "Scheduler"){
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
                 oar_warn("[Almighty] Energy saving module (hulot) died. Restarting it.\n");
                 sleep 5;
                 ipc_clean();
                 start_hulot();
               }
            my $scheduler_result=scheduler();
            if ($scheduler_result == 1){
                $state="Runner";
            }elsif ($scheduler_result == 0){
                $state="Time update";
            }elsif ($scheduler_result == 2){
                $state="Leon";
            }else{
                oar_error("[Almighty] Scheduler returned an unknown value : $scheduler_result\n");
                $finishTag = 1;
            }
        }else{
            oar_error("[Almighty] $nodeChangeState_command returned an unknown value\n");
            $finishTag = 1;
        }
    }

    # RUNNER
    elsif($state eq "Runner"){
        my $check_result=runner();
        if ($check_result == 1){
            $state="Leon";
        }elsif ($check_result == 2){
            $state="Scheduler";
        }else{
            $state="Time update";
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
        if ($check_result == 1){
            $state="Leon";
        }elsif ($check_result == 0){
            $state="Time update";
        }else{
            oar_error("[Almighty] $check_for_villains_command returned an unknown value : $check_result\n");
            $finishTag = 1;
        }
    }

    # CHECK NODE STATES
    elsif($state eq "Check node states"){
        my $check_result=check_nodes();
        if ($check_result == 1){
            $state="Change node state";
        }elsif ($check_result == 0){
            $state="Time update";
        }else{
            oar_error("[Almighty] $check_for_node_changes returned an unknown value\n");
            $finishTag = 1;
        }
    }

    # LEON
    elsif($state eq "Leon"){
        my $check_result = leon();
        $state="Time update";
        if ($check_result == 1){
            add_command("Term");
        }elsif($check_result == 2){
            $state = "Change node state";
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
            oar_error("[Almighty] $nodeChangeState_command returned an unknown value\n");
            $finishTag = 1;
        }
    }else{
        oar_warn("[Almighty] Critical bug !!!!\n");
        oar_error("[Almighty] Almighty just falled into an unknown state !!!\n");
        $finishTag = 1;
    }
}
