#!/usr/bin/perl
# $Id$

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

# Number of // connections accepted
my $Socket_max_connections = 10;

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
                        (default is 10 s)
  -t, --timeout         specify the maximum time given to each command
                        (default is 10 s) this time is also used to wait
                        between each checking campaign 
EOS
    exit(0);
}

my $Socket_process_pid = 0;

# pid of a user command currently launched
my $cmd_pid = 0;

# This command terminates on a signal INT or TERM
sub sig_handler(){
    kill('SIGKILL', $cmd_pid) if ($cmd_pid > 0);
    close_socket();
    print("Exit normally\n");
    exit(0);
}

$SIG{INT} = \&sig_handler;
$SIG{TERM} = \&sig_handler;

###############################################################################
# Test part
###############################################################################

# Permit to display directly if the socket could not be opened (when user test
# it interactively)
open_socket($Socket_port, $Socket_max_connections);
close_socket();

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
            close_socket();
        }elsif ($cmd_pid == 0){
            #CHILD
            exec($cmd);
            warn("[ERROR] Cannot find $cmd\n");
            exit(-1);
        }else{
            # Wait the end of the user command or the timeout
            my $initial_time = time;
            my $result_wait = 0;
            while (($result_wait != $cmd_pid) and (time - $initial_time <= $Timeout)){
                # Also avoid zombies
                if (($result_wait = waitpid(-1, WNOHANG)) > 0){
                    $exit_status = $?;
                }
                select(undef,undef,undef,0.5);
            }
            if ($result_wait != $cmd_pid){
                print("[".strftime("%F %T", localtime)."] [ERROR] Timeout ($Timeout s) of the command '$cmd' SO we close the socket.\n");
                kill('SIGKILL', $cmd_pid);
                close_socket();
                $end_test_cmds = 1;
            }elsif($exit_status != 0){
                print("[".strftime("%F %T", localtime)."] [ERROR] The command '$cmd' has returned an exit code != 0 ($exit_status) SO we close the socket.\n");
                close_socket();
                $end_test_cmds = 1;
            }
        }
        $cmd_pid = 0;

        # Go to the next user command
        $i++;
    }

    if ($end_test_cmds == 0){
        print("[".strftime("%F %T", localtime)."] [SUCCESS] Tests are a success so we open the socket.\n");
        open_socket($Socket_port, $Socket_max_connections);
    }

    print("[".strftime("%F %T", localtime)."] We are waiting $Check_interval s before the next check.\n");
    sleep($Check_interval);
}

###############################################################################
# Internal functions
###############################################################################


sub open_socket($$){
    my $server_port = shift;
    my $server_max_connect = shift;

    if ($Socket_process_pid == 0){
        $Socket_process_pid = manage_socket($server_port, $server_max_connect) ;
    }else{
        warn("[INFO] Socket already opened.\n");
    }
}

sub close_socket(){
    if ($Socket_process_pid != 0){
        kill('SIGINT', $Socket_process_pid);
        #waitpid($Socket_process_pid,0);
        $Socket_process_pid = 0;
    }else{
        warn("[INFO] Socket already closed.\n");
    }
}
sub manage_socket($$){
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
    
    return($pid);
}

