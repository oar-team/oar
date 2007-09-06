#!/usr/bin/perl
# $Id: oarmonitor_sensor.pl 598 2007-07-05 08:13:30Z neyron $
#
# This file is executed on each nodes and retrive all data for the specified
# cpuset name.

use POSIX qw(ceil);
use Data::Dumper;
$| = 1;

my $Job_id = $ARGV[0];

my $Cpuset_name = "/dev/cpuset/";
$Cpuset_name .= $ARGV[1] if (defined($ARGV[1]));

# Get names of cpus inside into the cpuset
my @Cpus;
if (open(CPUS, "$Cpuset_name/cpus")){
    my $str = <CPUS>;
    chop($str);
    $str =~ s/\-/\.\./g;
    @Cpus = eval($str);
    close(CPUS);
}

warn("Starting sensor on the cpuset $Cpuset_name for the job $Job_id\n");

my $cpuset_processes;
my $network_interfaces;
my $tic = "";
while ((-r "$Cpuset_name/tasks") and ($tic = <STDIN>) and ($tic ne "STOP\n")){
    chop($tic);

    $cpuset_processes = get_info_on_cpuset_tasks($Cpuset_name,$cpuset_processes);
    # print the DB table name and the values for each fields to store
    my ($cpu,$cpuset_cpu) = get_cpu_percentages($cpuset_processes);
    print("generic $tic network_address=$ENV{TAKTUK_HOSTNAME} type=global_cpu_percent value=$cpu subtype=nb_forks subvalue=todo\n")
        if (defined($cpu));

    my $vsize = 0;
    foreach my $p (keys(%{$cpuset_processes->{CURR}})){
        $vsize += $cpuset_processes->{CURR}->{$p}->{STAT}->[22];
    }
    print("generic $tic network_address=$ENV{TAKTUK_HOSTNAME} type=job_id value=$Job_id subtype=cpuset_vsize subvalue=$vsize\n")
        if (defined($cpuset_processes->{CURR}));
    print("generic $tic network_address=$ENV{TAKTUK_HOSTNAME} type=job_id value=$Job_id subtype=cpuset_cpu_percent subvalue=$cpuset_cpu\n")
        if (defined($cpuset_cpu));

    my $net_consumption;
    ($network_interfaces,$net_consumption) = get_network_data($network_interfaces);
    foreach my $i (keys(%{$net_consumption})){
        if ($i ne "lo"){
            print("generic $tic network_address=$ENV{TAKTUK_HOSTNAME} type=network value=$i subtype=download subvalue=$net_consumption->{$i}->{DOWN}\n");
            print("generic $tic network_address=$ENV{TAKTUK_HOSTNAME} type=network value=$i subtype=upload subvalue=$net_consumption->{$i}->{UP}\n");
        }
    }
    
    print("END\n");

    # avoid to become crazy
    select(undef,undef,undef,0.2);
}

if ($tic eq "STOP\n"){
    warn("Stopping sensor as requested.\n");
    print("STOP_REQUESTED\n");
    exit(0);
}elsif (! -r "$Cpuset_name/tasks"){
    warn("Stopping sensor, the cpuset $Cpuset_name does not exist anymore.\n");
    print("STOP\n");
    exit(1);
}else{
    warn("ERROR: out of the loop.\n");
    print("ERROR\n");
    exit(2);
}

###############################################################################
# Global variables to keep previous values

# For get_cpu_percentages()
my $prev_cpu_all_time = 0;
my $prev_cpu_idle_time = 0;

sub get_cpu_percentages($){
    my $cpuset_tasks = shift();

    my $cpu_percent;
    my $cpu_cpuset_percent;
    if (open(CPU, "/proc/stat")){
        my $stat_line = <CPU>;
        close(CPU);
        if ($stat_line =~ /^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/){
            my $curr_all_time = $1 + $2 + $3 + $4 + $5 + $6 + $7 + $8;
            my $curr_idle_time = $4 + $5;
            my $value = $curr_all_time - $prev_cpu_all_time;
            if ($value > 0){
                $cpu_percent = ceil(100 - (100 * ($curr_idle_time - $prev_cpu_idle_time) / $value));
                $cpu_percent = 100 if ($cpu_percent > 100);
                $cpu_percent = 0 if ($cpu_percent < 0);
                $prev_cpu_idle_time = $curr_idle_time;
                $prev_cpu_all_time = $curr_all_time;
            
                # Track percentages for all processes from the cpuset
                my $curr_cumul_process_all_time = 0;
                my $prev_cumul_process_all_time = 0;
                foreach my $p (keys(%{$cpuset_tasks->{CURR}})){
                    if (defined($cpuset_tasks->{PREV}->{$p}->{STAT})){
                        # add jiffies in user and kernel mode
                        $curr_cumul_process_all_time += $cpuset_tasks->{CURR}->{$p}->{STAT}->[13] + $cpuset_tasks->{CURR}->{$p}->{STAT}->[14];
                        $prev_cumul_process_all_time += $cpuset_tasks->{PREV}->{$p}->{STAT}->[13] + $cpuset_tasks->{PREV}->{$p}->{STAT}->[14];
                    }
                }
                $cpu_cpuset_percent = ceil(100 * ($curr_cumul_process_all_time - $prev_cumul_process_all_time) / $value);
                $cpu_cpuset_percent = 100 if ($cpu_cpuset_percent > 100);
                $cpu_cpuset_percent = 0 if ($cpu_cpuset_percent < 0);
            }
        }
    }

    return($cpu_percent,$cpu_cpuset_percent);
}

# arg1: cpuset name
# arg2: previous cpuset data structure to update
sub get_info_on_cpuset_tasks($$){
    my $task_path = shift()."/tasks";
    my $cpuset_tasks = shift();

    $cpuset_tasks->{PREV} = $cpuset_tasks->{CURR} if (defined($cpuset_tasks->{CURR}));
    delete($cpuset_tasks->{CURR});
    if (open(TASKS, "$task_path")){
        my $task;
        while ($task = <TASKS>){
            chop($task);
            if (open(PROCESSSTAT, "/proc/$task/stat")){
                my @stats = split(' ',<PROCESSSTAT>);
                $cpuset_tasks->{CURR}->{$task}->{STAT} = \@stats;
                close(PROCESSSTAT);
            }
        }
        close(TASKS);
    }
    return($cpuset_tasks);
}


# Get network interfaces data
sub get_network_data($){
    my $network_data = shift();

    my $results;
    $network_data->{PREV} = $network_data->{CURR} if (defined($network_data->{CURR}));
    delete($network_data->{CURR});
    if (open(NET, "/proc/net/dev")){
        while ($_ = <NET>){
            if ($_ =~ /^\s+(\w+):\s*(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)/){
                $network_data->{CURR}->{$1}->{DOWN} = $2;
                $network_data->{CURR}->{$1}->{UP} = $3;
                if ((defined($network_data->{PREV}->{$1}->{DOWN})) and (defined($network_data->{PREV}->{$1}->{UP}))){
                    $results->{$1}->{DOWN} = $network_data->{CURR}->{$1}->{DOWN} - $network_data->{PREV}->{$1}->{DOWN};
                    $results->{$1}->{UP} = $network_data->{CURR}->{$1}->{UP} - $network_data->{PREV}->{$1}->{UP};
                }
            }
        }
        close(NET);
    }
    
    return($network_data,$results);
}
