#!/usr/bin/perl

use IO::Socket::INET;
use Getopt::Long;
use POSIX qw(strftime :sys_wait_h);

$SIG{INT} = 'IGNORE';

###############################################################################
# Global variables
###############################################################################

# Socket port opened when everything works
my $Socket_port = 8888;

# Timeout of the global test execution
my $Timeout = 10;

# Time between each check campaign
my $Check_interval = 10;

###############################################################################
# Initialization part
###############################################################################

Getopt::Long::Configure ("gnu_getopt");
my $sos;
GetOptions ("help|h" => \$sos,
            "port|p=i" => \$Socket_port,
            "timeout|t=i" => \$Timeout,
            "check_interval|c=i" => \$Check_interval
           );

if (defined($sos) or ($#ARGV < 0)){
    print <<EOS;
This command uses several program given in argument to check if all computer
services are running correctly and then open a socket (usefull to check
remotely if the computer is alive. Example of a remote check :
nmap -p 8888 -n -T5 -oG - node_address
)
Usage: $0 [-h|[[-p][-t]] "cmd1 args" "cmd2 args" "cmd3"...
  -h, --help            display this help message
  -p, --port            specify the socket port to use (default is 8888)
  -c, --check_interval  specify the amount of time between each check
  -t, --timeout         specify the maximum time given to each command
                        (default is 10) this time is also used to wait between
                        each checking campaign 
EOS
    exit(0);
}

# Init the pipe to talk with the socket manager process
if(!(pipe (TATA, YOYO))){
    warn("[SYSTEM-ERROR] Cannot open pipe !!!\n");
    exit(1);
}

autoflush TATA 1;
autoflush YOYO 1;

# Create the socket manager process
my $pid = fork();
if (!defined($pid)){
    warn("[SYSTEM-ERROR] Cannot fork a process.\n");
    exit(2);
}elsif ($pid == 0){
    #CHILD
    launch_child($Socket_port);
    exit(0);
}

close(TATA);

# pid of a user command currently launched
my $cmd_pid = 0;

# This command terminates on a signal INT or TERM
sub sig_handler(){
    kill('SIGKILL', $cmd_pid) if ($cmd_pid > 0);
    print(YOYO "EXIT\n");
    close(YOYO);
    wait();
    print("Exit normally\n");
    exit(0);
}

$SIG{INT} = \&sig_handler;
$SIG{TERM} = \&sig_handler;

###############################################################################
# Test part
#
# You have 3 possible actions:
#     - OPEN : open the socket
#     - CLOSE : close the scoket
#     - EXIT : close the socket and exit from child processus
###############################################################################

# Permit to display directly if the socket could not be opened (when user test
# it interactively)
send_socket_cmd("OPEN");
send_socket_cmd("CLOSE");

while (1){
    # specify if we must exit from the loop immediately
    my $end_test_cmds = 0;
    my $i = 0;
    while (($i <= $#ARGV) and ($end_test_cmds == 0)){
        # user command to launch
        my $cmd = $ARGV[$i];
        print("[".strftime("%F %T", localtime)."] Launch command : $cmd\n");

        my $exit_status = 0;
            
        $cmd_pid = fork();
        if (!defined($cmd_pid)){
            warn("[SYSTEM-ERROR] Cannot fork a process to launch the command : $cmd. So we close the socket.\n");
            $end_test_cmds = 1;
            send_socket_cmd("CLOSE");
        }elsif ($cmd_pid == 0){
            #CHILD
            exec($cmd);
        }else{
            # Wait the end of the user command or the timeout
            my $initial_time = time;
            my $result_wait = 0;
            while (($result_wait != $cmd_pid) and (time - $initial_time <= $Timeout)){
                if (($result_wait = waitpid($cmd_pid, WNOHANG)) > 0){
                    $exit_status = $?;
                }
                select(undef,undef,undef,0.25);
            }
            if ($result_wait != $cmd_pid){
                print("[".strftime("%F %T", localtime)."] [ERROR] Timeout ($Timeout s) of the command '$cmd' SO we close the socket.\n");
                kill('SIGKILL', $cmd_pid);
                send_socket_cmd("CLOSE");
                $end_test_cmds = 1;
            }elsif($exit_status != 0){
                print("[".strftime("%F %T", localtime)."] [ERROR] The command '$cmd' has returned an exit code != 0 ($exit_status) SO we close the socket.\n");
                send_socket_cmd("CLOSE");
                $end_test_cmds = 1;
            }
        }
        $cmd_pid = 0;

        # Go to the next user command
        $i++;
    }

    if ($end_test_cmds == 0){
        print("[".strftime("%F %T", localtime)."] [SUCCESS] Tests are a success so we open the socket.\n");
        send_socket_cmd("OPEN");
    }

    print("[".strftime("%F %T", localtime)."] We are waiting $Check_interval s before the next check.\n");
    sleep($Check_interval);
}

###############################################################################
# Internal functions
###############################################################################
sub send_socket_cmd($){
    my $str = shift;
    if (! print(YOYO "$str\n")){
        warn("[SYSTEM-ERROR] The socket manager process seems to be died. It is not normal so I am exiting");
        kill('SIGKILL', $cmd_pid) if ($cmd_pid > 0);
        exit(4);
    }
}

sub open_socket($$){
    my $server_port = shift;
    my $server_max_connect = shift;
    
    my $server = IO::Socket::INET->new(LocalPort=> $server_port,
                                   Type => SOCK_STREAM,
                                   Reuse => 1,
                                   Listen => $server_max_connect);

    if (!defined($server)){
        warn("[SYSTEM-ERROR] Cannot open a socket on the port $server_port.\n");
        return(undef);
    }

    my $pid = fork();
    if (!defined($pid)){
        warn("[SYSTEM-ERROR] Cannot fork a process to listen on the socket.\n");
        return(undef);
    }elsif ($pid == 0){
        #CHILD
        $SIG{INT} = sub {$server->close()};

        while (my $client=$server->accept()){
            $client->close();
        }
        exit(0);
    }
    
    return($server,$pid);
}

# This is the socket manager
sub launch_child($){
    my $port = shift;

    $SIG{USR1}  = 'IGNORE';
    $SIG{INT}  = 'IGNORE';
    $SIG{TERM}  = 'IGNORE';

    close(YOYO);

    my $socket;
    my $pid;
    
    my $end_loop = 0;
    while($end_loop == 0){
        my $cmd = <TATA>;
        chop($cmd);
        
        #print("[CMD] $cmd\n");
        if ($cmd eq "EXIT"){
            if (defined($socket)){
                kill('SIGINT', $pid);
                $socket->close();
            }
            $end_loop = 1;
        }elsif ($cmd eq "CLOSE"){
            if (defined($socket)){
                kill('SIGINT', $pid);
                waitpid($pid,0);
                $socket->close();
                $socket = undef;
            }
        }elsif ($cmd eq "OPEN"){
            if (!defined($socket)){
                ($socket,$pid) = open_socket($port, 10) ;
            }else{
                warn("[INFO] Socket already opened.\n");
            }
        }else{
            warn("[WARNING] Unknown tag : $cmd; so exiting\n");
            if (defined($socket)){
                kill('SIGINT', $pid);   
                $socket->close();
            }
            $end_loop = 1;
        }
    }
    close(TATA);
}
