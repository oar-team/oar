#!/usr/bin/perl
# $Id: oarmonitor_sensor.pl 598 2007-07-05 08:13:30Z neyron $
#
# This file is executed on each nodes and retrive all data for the specified
# cpuset name.

use POSIX qw(strftime ceil);
use Time::HiRes qw(gettimeofday tv_interval);

my $Cpuset_name = "/dev/cpuset";
$Cpuset_name = $ARGV[0] if (defined($ARGV[0]));

warn("Starting $0 on the cpuset $Cpuset_name\n");

my $tic = "";
while ((-r "$Cpuset_name/tasks") and ($tic = <STDIN>) and ($tic ne "STOP\n")){
    chop($tic);

    print("$tic by_host name=cpu_percentage value=".get_global_cpu_percentage()."\n");

    print("$tic END\n");

    # avoid to become crazy
    select(undef,undef,undef,0.5);
}

if ($tic eq "STOP\n"){
    warn("Stopping $0 as requested.\n");
    print("STOP_REQUESTED\n");
    exit(0);
}elsif (! -r "$Cpuset_name/tasks"){
    warn("Stopping $0, the cpuset $Cpuset_name does not exist anymore.\n");
    print("STOP\n");
    exit(1);
}else{
    warn("ERROR: out of the loop.\n");
    print("ERROR\n");
    exit(2);
}

###############################################################################
# Global variables to keep previous values

# For get_global_cpu_percentage()
my $prev_cpu_glob_time = 0;
my $prev_cpu_all_time = 0;
my $prev_cpu_idle_time = 0;

sub get_global_cpu_percentage(){
    my $cpu_time = [gettimeofday()];
    if (open(CPU, "/proc/stat")){
        my $stat_line = <CPU>;
        if ($stat_line =~ /^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/){
            my $curr_all_time = $1 + $2 + $3 + $4 + $5 + $6 + $7 + $8;
            my $curr_idle_time = $4 + $5;
            my $value = $curr_all_time - $prev_cpu_all_time;
            if ($value > 0){
                $value = ceil(100 - (100 * ($curr_idle_time - $prev_cpu_idle_time) / $value));
                $value = 100 if ($value > 100);
                $value = 0 if ($value < 0);
                $prev_cpu_idle_time = $curr_idle_time;
                $prev_cpu_all_time = $curr_all_time;
                $prev_cpu_value = $value;
            }
        }
        close(CPU);
    }
    $prev_cpu_glob_time = $cpu_time;
        
    return($prev_cpu_value);
}
