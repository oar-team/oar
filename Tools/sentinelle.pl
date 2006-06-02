#!/usr/bin/perl
#
# sentinelle, version in Perl
#
# Description : execute a commande on several nodes with a connector like ssh or
#               rsh in parrallel. There is a window which limits the number of
#               processus at the same time; usefull in a cluster
# Author      : nicolas.capit@imag.fr
# Copyright   : 2005 - Laboratoire Informatique et Distribution (ID-IMAG)
# License     : GNU GPL version 2
#

use Getopt::Long;
use Data::Dumper;
use strict;
use warnings;
use POSIX ":sys_wait_h";

# Try to load high precision time module
my $useTime = 1;
my $timeStart;
my $timeEnd;
unless (eval "use Time::HiRes qw(gettimeofday tv_interval);1"){
    $useTime = 0;
}


# Print help message
sub usage(){
    print <<EOU;
Usage sentinelle.pl -h | [-m node] [-f node_file] [-c connector] [-w window_size] [-t timeout] [-p program] [-v]
    -h display this help message
    -m specify the node to contact (use several -m options for several nodes)
    -f give the name of a file which contains the node list (1 node per line)(use several -f options for several files)
    -c connector to use (default is ssh). If you want to change the user name, specify that in the connector (ex: -c "ssh -l user")
    -w window size (number of fork at the same time; default is 5)
    -t timeout for each command in second
    -p programm to run (default is "true")
    -v verbose mode

    The command returns for each node the tag BAD or GOOD with 3 numbers : exit code, signal number and core dump. If these 3 numbers are equal to 0 then the return tag is GOOD.
EOU
                                    
}

my @nodes;
my $command = "true";
my $window_size = 5;
my $connector = "ssh";
my $timeout = 30;
my $verbose;
my $sos;
my @files;

# Get command line informations
Getopt::Long::Configure ("gnu_getopt");
GetOptions ("machine|m=s" => \@nodes,
            "program|p=s" => \$command,
            "connector|c=s" => \$connector,
            "timeout|t=i" => \$timeout,
            "window|w=i" => \$window_size,
            "verbose|v" => \$verbose,
            "file|f=s" => \@files,
            "help|h" => \$sos
           );

# Treate -h or --help option
if (defined($sos)){
    usage();
    exit(0);
}

# Treate -f or --file option (load node names from the file)
foreach my $fileName (@files){
    open(FILE, "$fileName") or die("/!\\ Can not open file $fileName.\n");
    while (<FILE>){
        # Remove commentaries
        $_ =~ s/#.*$//s;
        if ($_ =~ m/^\s*(\S+)\s*$/m){
            push(@nodes, $1);
        }
    }
}


# Check if there is at least one node to connect to
if ($#nodes < 0){
    die("/!\\ No node specified (use -h option for more explanations)\n");
}

# Check window size integrity
if ($window_size < 1){
    die("/!\\ Window size $window_size too small; minimum is 1!\n");
}

select STDOUT;
$| = 1;



my $nbNodes = $#nodes + 1;
my $index = 0;
my %running_processes;
my $nb_running_processes = 0;
my %finished_processes;
my %processDuration;

# Treate finished processes
sub register_wait_results($$){
    my $pid = shift;
    my $returnCode = shift;
    
    my $exit_value = $returnCode >> 8;
    my $signal_num  = $returnCode & 127;
    my $dumped_core = $returnCode & 128;
    if ($pid > 0){
        if (defined($running_processes{$pid})){
            $processDuration{$running_processes{$pid}}->{"end"} = [gettimeofday()] if ($useTime == 1);
            print("[VERBOSE] Child process $pid ended : exit_value = $exit_value, signal_num = $signal_num, dumped_core = $dumped_core \n") if ($verbose);
            $finished_processes{$running_processes{$pid}} = [$exit_value,$signal_num,$dumped_core];
            delete($running_processes{$pid});
            $nb_running_processes--;
        }
    }  
}

$timeStart = [gettimeofday()] if ($useTime == 1);

# Start to launch subprocesses with the window limitation
my @timeout;
my $pid;
while (($index <= $#nodes) or ($#timeout >= 0)){
    # Check if window is full or not
    while((($nb_running_processes) < $window_size) and ($index <= $#nodes)){
        print("[VERBOSE] fork process for the node $nodes[$index]\n") if ($verbose);
        $processDuration{$index}->{"start"} = [gettimeofday()] if ($useTime == 1);
        
        $pid = fork();
        if (defined($pid)){
            $running_processes{$pid} = $index;
            $nb_running_processes++;
            push(@timeout, [$pid,time()+$timeout]);
            if ($pid == 0){
                #In the child
	    	my $cmd = "$connector $nodes[$index] $command";
                print("[VERBOSE] Execute command : $cmd\n") if ($verbose);
                exec($cmd);
            }
        }else{
            warn("/!\\ fork system call failed for node $nodes[$index].\n");
        }
        $index++;
    }
    while(($pid = waitpid(-1, WNOHANG)) > 0) {
        register_wait_results($pid, $?);
    }

    my $t = 0;
    while(defined($timeout[$t]) and (($timeout[$t]->[1] < time()) or (!defined($running_processes{$timeout[$t]->[0]})))){
        if (!defined($running_processes{$timeout[$t]->[0]})){
            splice(@timeout,$t,1);
        }else{
            if ($timeout[$t]->[1] <= time()){
                kill(9,$timeout[$t]->[0]);
            }
        }
        $t++;
    }
    select(undef,undef,undef,0.1) if ($t == 0);
}


my $exit_code = 0;
# Print summary for each nodes
foreach my $i (keys(%finished_processes)){
    my $verdict = "BAD";
    if (($finished_processes{$i}->[0] == 0) && ($finished_processes{$i}->[1] == 0) && ($finished_processes{$i}->[2] == 0)){
        $verdict = "GOOD";
    }else{
        $exit_code = 1;
    }
    print("$nodes[$i] : $verdict ($finished_processes{$i}->[0],$finished_processes{$i}->[1],$finished_processes{$i}->[2]) ");

    if ($useTime == 1){
        my $duration = tv_interval($processDuration{$i}->{"start"}, $processDuration{$i}->{"end"});
        printf("%.3f s",$duration);
    }

    print("\n");
}

foreach my $i (keys(%running_processes)){
    print("$nodes[$running_processes{$i}] : BAD (-1,-1,-1) -1 s process disappeared\n");
    $exit_code = 1;
}

# Print global duration
if ($useTime == 1){
    $timeEnd = [gettimeofday()];
    printf("Total duration : %.3f s (%d nodes)\n", tv_interval($timeStart, $timeEnd), $nbNodes);
}


exit($exit_code);
