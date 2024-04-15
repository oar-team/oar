# $Id: oarmonitor_sensor.pl 598 2007-07-05 08:13:30Z neyron $
#
# This file is executed on each nodes and retrive all data for the specified
# cpuset name.

use Data::Dumper;

my $Old_umask = sprintf("%lo", umask());
umask(oct("022"));

$| = 1;

my $Job_id = $ARGV[0];

my $Cpuset_name = "/dev/cpuset/";
$Cpuset_name .= $ARGV[1] if (defined($ARGV[1]));

# Get names of cpus inside into the cpuset
my @Cpus;
if (!open(CPUS, "$Cpuset_name/cpus")) {
    if (!open(CPUS, "$Cpuset_name/cpuset.cpus")) {
        warn("ERROR: Cannot open $Cpuset_name/cpus neither $Cpuset_name/cpuset.cpus\n");
        print("ERROR\n");
        exit(3);
    }
}
my $str = <CPUS>;
chop($str);
$str =~ s/\-/\.\./g;
@Cpus = eval($str);
close(CPUS);

warn("Starting sensor on the cpuset $Cpuset_name for the job $Job_id\n");

my $cpuset_processes;
my $cpus_data;
my $network_interfaces;
my $tic = "";
while ((-r "$Cpuset_name/tasks") and ($tic = <STDIN>) and ($tic ne "STOP\n")) {
    chop($tic);

    $cpuset_processes   = get_info_on_cpuset_tasks($Cpuset_name, $cpuset_processes);
    $cpus_data          = get_info_on_cpus($cpus_data);
    $network_interfaces = get_network_data($network_interfaces);

    # print the DB table name and the values for each fields to store
    my $cpu_res = calculate_cpu_percentages($cpus_data, $cpuset_processes, \@Cpus);
    print(
        "generic $tic network_address=$ENV{TAKTUK_HOSTNAME} type=global_cpu_percent value=$cpu_res->{ALL}->{CPUPERCENT} subtype=nb_forks subvalue=$cpu_res->{ALL}->{NEWPROCESSES}\n"
    ) if (defined($cpu_res->{ALL}));

    foreach my $c (keys(%{ $cpu_res->{EACH} })) {
        print(
            "generic $tic network_address=$ENV{TAKTUK_HOSTNAME} type=cpu value=$c subtype=cpu_percent subvalue=$cpu_res->{EACH}->{$c}->{CPUPERCENT}\n"
        );
    }

    print(
        "generic $tic network_address=$ENV{TAKTUK_HOSTNAME} type=job_id value=$Job_id subtype=cpuset_vsize subvalue=$cpu_res->{CPUSET}->{VSIZE}\n"
    ) if (defined($cpu_res->{CPUSET}->{VSIZE}));
    print(
        "generic $tic network_address=$ENV{TAKTUK_HOSTNAME} type=job_id value=$Job_id subtype=cpuset_cpu_percent subvalue=$cpu_res->{CPUSET}->{CPUPERCENT}\n"
    ) if (defined($cpu_res->{CPUSET}->{CPUPERCENT}));

    my $net_consumption = calculate_network_percentages($network_interfaces);
    foreach my $i (keys(%{$net_consumption})) {
        $i =~ /^(\D+)(\d+)$/;
        print(
            "generic $tic network_address=$ENV{TAKTUK_HOSTNAME} type=network_$1 value=$2 subtype=download subvalue=$net_consumption->{$i}->{DOWN}\n"
        );
        print(
            "generic $tic network_address=$ENV{TAKTUK_HOSTNAME} type=network_$1 value=$2 subtype=upload subvalue=$net_consumption->{$i}->{UP}\n"
        );
    }

    print("END\n");

    # avoid to become crazy
    select(undef, undef, undef, 0.2);
}

if ($tic eq "STOP\n") {
    warn("Stopping sensor as requested.\n");
    print("STOP_REQUESTED\n");
    exit(0);
} elsif (!-r "$Cpuset_name/tasks") {
    warn("Stopping sensor, the cpuset $Cpuset_name does not exist anymore.\n");
    print("STOP\n");
    exit(1);
} else {
    warn("ERROR: out of the loop.\n");
    print("ERROR\n");
    exit(2);
}

###############################################################################

sub get_info_on_cpus($) {
    my $cpu_hash = shift();

    $cpu_hash->{PREV} = $cpu_hash->{CURR} if (defined($cpu_hash->{CURR}));
    delete($cpu_hash->{CURR});
    my $cpu_percent;
    my $cpu_cpuset_percent;
    if (open(CPU, "/proc/stat")) {
        my $stat_line;
        while ($stat_line = <CPU>) {
            if ($stat_line =~
                /^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
                $cpu_hash->{CURR}->{ALL}->{ALLTIME}  = $1 + $2 + $3 + $4 + $5 + $6 + $7 + $8;
                $cpu_hash->{CURR}->{ALL}->{IDLETIME} = $4 + $5;
            } elsif ($stat_line =~
                /^cpu(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
                $cpu_hash->{CURR}->{EACH}->{$1}->{ALLTIME}  = $2 + $3 + $4 + $5 + $6 + $7 + $8 + $9;
                $cpu_hash->{CURR}->{EACH}->{$1}->{IDLETIME} = $5 + $6;
            } elsif ($stat_line =~ /^processes\s(\d+)/) {
                $cpu_hash->{CURR}->{ALL}->{PROCESSES} = $1;
            }
        }
        close(CPU);
    }

    return ($cpu_hash);
}

# arg1: cpuset name
# arg2: previous cpuset data structure to update
sub get_info_on_cpuset_tasks($$) {
    my $task_path    = shift() . "/tasks";
    my $cpuset_tasks = shift();

    $cpuset_tasks->{PREV} = $cpuset_tasks->{CURR} if (defined($cpuset_tasks->{CURR}));
    delete($cpuset_tasks->{CURR});
    if (open(TASKS, "$task_path")) {
        my $task;
        while ($task = <TASKS>) {
            chop($task);
            if (open(PROCESSSTAT, "/proc/$task/stat")) {
                my @stats = split(' ', <PROCESSSTAT>);
                $cpuset_tasks->{CURR}->{$task}->{STAT} = \@stats;
                close(PROCESSSTAT);
            }
        }
        close(TASKS);
    }
    return ($cpuset_tasks);
}

# arg1: cpus hash
# arg2: cpuset hash
# arg3: cpuset cpus list
sub calculate_cpu_percentages($$$) {
    my $cpus_hash   = shift;
    my $cpuset_hash = shift;
    my $cpus        = shift;

    my $results;
    if ((defined($cpus_hash->{CURR}->{ALL})) and (defined($cpus_hash->{PREV}->{ALL}))) {
        $results->{ALL}->{CPUPERCENT} =
          $cpus_hash->{CURR}->{ALL}->{ALLTIME} - $cpus_hash->{PREV}->{ALL}->{ALLTIME};
        if ($results->{ALL}->{CPUPERCENT} > 0) {
            $results->{ALL}->{CPUPERCENT} = sprintf(
                "%.0f",
                (
                    100 - (
                        100 * (
                            $cpus_hash->{CURR}->{ALL}->{IDLETIME} -
                              $cpus_hash->{PREV}->{ALL}->{IDLETIME}
                        ) / $results->{ALL}->{CPUPERCENT})));
            $results->{ALL}->{CPUPERCENT} = 100 if ($results->{ALL}->{CPUPERCENT} > 100);
            $results->{ALL}->{CPUPERCENT} = 0   if ($results->{ALL}->{CPUPERCENT} < 0);
        } else {
            $results->{ALL}->{CPUPERCENT} = 0;
        }

        $results->{ALL}->{NEWPROCESSES} =
          $cpus_hash->{CURR}->{ALL}->{PROCESSES} - $cpus_hash->{PREV}->{ALL}->{PROCESSES};
    }

    my $cumul_prev_cpus_all = 0;
    my $cumul_curr_cpus_all = 0;
    foreach my $c (@{$cpus}) {
        if ((defined($cpus_hash->{CURR}->{EACH}->{$c})) and
            (defined($cpus_hash->{PREV}->{EACH}->{$c}))) {
            $results->{EACH}->{$c}->{CPUPERCENT} = $cpus_hash->{CURR}->{EACH}->{$c}->{ALLTIME} -
              $cpus_hash->{PREV}->{EACH}->{$c}->{ALLTIME};
            if ($results->{EACH}->{$c}->{CPUPERCENT} > 0) {
                $results->{EACH}->{$c}->{CPUPERCENT} = sprintf(
                    "%.0f",
                    (
                        100 - (
                            100 * (
                                $cpus_hash->{CURR}->{EACH}->{$c}->{IDLETIME} -
                                  $cpus_hash->{PREV}->{EACH}->{$c}->{IDLETIME}
                            ) / $results->{EACH}->{$c}->{CPUPERCENT})));
                $results->{EACH}->{$c}->{CPUPERCENT} = 100
                  if ($results->{EACH}->{$c}->{CPUPERCENT} > 100);
                $results->{EACH}->{$c}->{CPUPERCENT} = 0
                  if ($results->{EACH}->{$c}->{CPUPERCENT} < 0);
            } else {
                $results->{EACH}->{$c}->{CPUPERCENT} = 0;
            }
            $cumul_curr_cpus_all += $cpus_hash->{CURR}->{EACH}->{$c}->{ALLTIME};
            $cumul_prev_cpus_all += $cpus_hash->{PREV}->{EACH}->{$c}->{ALLTIME};
        }
    }

    # Track percentages for all processes from the cpuset
    my $curr_cumul_process_all_time = 0;
    my $prev_cumul_process_all_time = 0;
    foreach my $p (keys(%{ $cpuset_hash->{CURR} })) {
        if (defined($cpuset_hash->{PREV}->{$p}->{STAT})) {

            # add jiffies in user and kernel mode
            $curr_cumul_process_all_time +=
              $cpuset_hash->{CURR}->{$p}->{STAT}->[13] + $cpuset_hash->{CURR}->{$p}->{STAT}->[14];
            $prev_cumul_process_all_time +=
              $cpuset_hash->{PREV}->{$p}->{STAT}->[13] + $cpuset_hash->{PREV}->{$p}->{STAT}->[14];
        }
        $results->{CPUSET}->{VSIZE} += $cpuset_hash->{CURR}->{$p}->{STAT}->[22];
    }
    my $cpuset_cpus_all_time = $cumul_curr_cpus_all - $cumul_prev_cpus_all;
    if ($cpuset_cpus_all_time > 0) {
        $results->{CPUSET}->{CPUPERCENT} = sprintf(
            "%.0f",
            (   100 * ($curr_cumul_process_all_time - $prev_cumul_process_all_time) /
                  $cpuset_cpus_all_time
            ));
        $results->{CPUSET}->{CPUPERCENT} = 100 if ($results->{CPUSET}->{CPUPERCENT} > 100);
        $results->{CPUSET}->{CPUPERCENT} = 0   if ($results->{CPUSET}->{CPUPERCENT} < 0);
    }

    return ($results);
}

# Get network interfaces data
sub get_network_data($) {
    my $network_data = shift();

    $network_data->{PREV} = $network_data->{CURR} if (defined($network_data->{CURR}));
    delete($network_data->{CURR});
    if (open(NET, "/proc/net/dev")) {
        while ($_ = <NET>) {
            if ($_ =~ /^\s+(\w+):\s*(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)/) {
                $network_data->{CURR}->{$1}->{DOWN} = $2;
                $network_data->{CURR}->{$1}->{UP}   = $3;
            }
        }
        close(NET);
    }

    return ($network_data);
}

sub calculate_network_percentages($) {
    my $network_data = shift();

    my $results;
    foreach my $i (keys(%{ $network_data->{CURR} })) {
        if ($i ne "lo") {
            if ((defined($network_data->{PREV}->{$i}->{DOWN})) and
                (defined($network_data->{PREV}->{$i}->{UP}))) {
                $results->{$i}->{DOWN} =
                  $network_data->{CURR}->{$i}->{DOWN} - $network_data->{PREV}->{$i}->{DOWN};
                $results->{$i}->{UP} =
                  $network_data->{CURR}->{$i}->{UP} - $network_data->{PREV}->{$i}->{UP};
            }
        }
    }

    return ($results);
}
