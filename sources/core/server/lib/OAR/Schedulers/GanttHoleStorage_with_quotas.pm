# $Id$
package OAR::Schedulers::GanttHoleStorage_with_quotas;
require Exporter;
use OAR::Schedulers::ResourceTree;
use OAR::Schedulers::QuotaStorage;
use OAR::Modules::Judas qw(oar_debug oar_warn oar_error set_current_log_category);
use POSIX ":sys_wait_h";
use POSIX qw(strftime);
use Storable qw(store_fd fd_retrieve dclone);
use DateTime;
use warnings;
use strict;
use Data::Dumper;
use Carp qw(cluck);

# Note : All dates are in seconds
# Resources are integer so we store them in bit vectors
# Warning : this gantt cannot manage overlaping time slots

# 2^32 is infinity in 32 bits stored time
my $Infinity = 4294967296;

# Prototypes
# gantt chart management
sub new($$);
sub new_with_1_hole($$$$$$);
sub add_1_hole($$$$);
sub to_strips($);
sub from_strips($$$$$);
sub compute_constraints($$$);
sub clone_with_constraints($$);
sub clone_union($$);
sub manage_gantt_hierarchy($$$$$$);
sub fill_gantt_hierarchy($$$$$$$$$);
sub add_new_resources($$);
sub set_occupation($$$$);
sub get_free_resources($$$);
sub find_first_hole($$$$$$$$$$$$);
sub gantt2str($);
sub strips2str($);
sub get_infinity_value();

###############################################################################

sub get_infinity_value(){
    return($Infinity);
}

sub gantt2str($){
    my $gantt = shift;
    my $str = "";
    my @bits = split(//, unpack("b*", $gantt->[0]->[2]));
    $str .= "@bits\n";
    foreach my $g (@{$gantt}){
        $str .= "BEGIN: $g->[0](".strftime("%F %T",localtime($g->[0])).")\n";
        foreach my $h (@{$g->[1]}){
            @bits = split(//, unpack("b*", $h->[1]));
            $str .= "  $h->[0](".strftime("%F %T",localtime($h->[0]))."): @bits\n";
        }
        $str .= "\n";
    }
    return($str);
}

sub strips2str($){
    my $strips = shift;
    my $str = "";
    foreach my $s (sort {$a <=> $b} keys(%$strips)) {
        my @bits = split(//, unpack("b*", $strips->{$s}));
        $str .= "  $s(".strftime("%f_%t",localtime($s))."): @bits\n";
    }
    return($str);
}  

# Creates an empty Gantt
# arg : number of the max resource id
sub new($$){
    my $max_resource_number = shift;
    my $minimum_hole_duration = shift;

    $minimum_hole_duration = 0 if (!defined($minimum_hole_duration));

    my $empty_vec = '';
    vec($empty_vec, $max_resource_number, 1) = 0;

    my $result =[                               # Gantt structure: a Gantt is defined as the list of the biggest holes
                    [                           # (rectange shapes) where a job could be placed (holes obviously can overlap)
                        0,                      # Each item of this subarray is a set of holes beginning a same time: t_start
                        [                       # The set is stored as a sub-subarray of holes sorted by end time
                            [                   # Holes are stored as arrays of 2 elements, with:
                                $Infinity,      # - t_end: end time for the hole
                                $empty_vec      # - vec: resource vector for the hole
                            ]
                        ],                      # The next 4 fields are only set in the first hole set (apply to the gantt):
                        $empty_vec,             # - base resources vector for the gantt
                        $empty_vec,             # - reference empty vec (filled with 0)
                        $minimum_hole_duration, # - minimum duration time for a hole (see oar.conf)
                        [$Infinity,$Infinity]   # - [t_start,t_end] of the last hole which was checked in the last find_first_hole
                    ]                           #   call, if a timeout was triggered.
                ];
    
    return($result);
}


# Creates a Gantt with 1 hole
# arg : number of the max resource id
sub new_with_1_hole($$$$$$){
    my $max_resource_number = shift;
    my $minimum_hole_duration = shift;
    my $date = shift;
    my $duration = shift;
    my $resources_vec = shift;
    my $all_resources_vec = shift;

    my $gantt = OAR::Schedulers::GanttHoleStorage_with_quotas::new($max_resource_number, $minimum_hole_duration);

    # initiate the first hole with a fake date (ensure to keep it intact with all the configuration)
    $gantt->[0]->[1]->[0]->[0] = 86400;
   
    # Init the whole resource list directly
    $gantt->[0]->[2] = $all_resources_vec;
    # Feed vector with enough 0
    $resources_vec |= $gantt->[0]->[3];

    # Create the only hole
    $gantt->[1]->[0] = $date;
    $gantt->[1]->[1] = [[($date + $duration), $resources_vec]];

    return($gantt);
}

# Add 1 hole to a Gantt
# arg : gantt, date, duration, resource_vec
sub add_1_hole($$$$) {
    my $gantt = shift;
    my $date = shift;
    my $duration = shift;
    my $resources_vec = shift;
    my $all_resources_vec = $gantt->[0]->[2];
    my $max_resource_number = (length($all_resources_vec) - 1) * 8;
    my $minimum_hole_duration = $gantt->[0]->[4];

    my $new_gantt_with_1_hole = new_with_1_hole($max_resource_number, $minimum_hole_duration, $date, $duration, $resources_vec, $all_resources_vec);
    return clone_union($gantt, $new_gantt_with_1_hole);
}

sub to_strips($) {
    my $gantt = shift;
    # Initialize the stipes by retrieving all holes start and end times in the gantt
    my $empty_vec = $gantt->[0]->[3];
    my $strips = {};
    foreach my $h (@$gantt) {
        $strips->{$h->[0]} =  $empty_vec;
        foreach my $hh (@{$h->[1]}) {
            $strips->{$hh->[0]} = $empty_vec;
        }
    }
    
    # compute the vectors for every strips
    foreach my $h (@$gantt) {
        my $t0 = $h->[0];
        foreach my $hh (@{$h->[1]}) {
            my $t1 = $hh->[0];
            foreach my $l (sort {$a <=> $b} keys(%$strips)) {
                if ($t0 < $l and $l <= $t1) {
                    $strips->{$l} |= ($hh->[1]);
                }
            }
        }
    }

    return $strips;
}

sub from_strips($$$$$) {
    my $strips = shift;
    my $base_resources_vec = shift;
    my $empty_vec = shift;
    my $minimum_hole_duration = shift;
    my $last_checked_hole = shift;

    # Convert the stript gantt back to the original structure
    my $gantt = [];
    my @times=sort {$a <=> $b} keys(%$strips);
    # Try and find new hole start time for every strip
    for(my $t=0;$t<$#times;$t++) {
        my $holes = [];
        #print("test possible hole starting at $t (".strftime("%F_%T",localtime($times[$t])).") ? : ".unpack("b*", (~ $strips->{$times[$t]} & $strips->{$times[$t+1]}))."\n");
        # We have a new hole if for any resource r, vec(r,t-1)=1 and vec(r,t)=0
        if ((~ $strips->{$times[$t]} & $strips->{$times[$t+1]}) ne $empty_vec) {
            #print "YES: hole at starttime: t=$t l=".$times[$t]." (".strftime("%F_%T",localtime($times[$t])).")\n";
            my $vec = $strips->{$times[$t+1]};
            # Compute all holes with this start time, as long as the hole vector is not empty
            while ($vec ne $empty_vec) {
                #print("vec= ".unpack("b*", $vec)." \@t=".($t+1)." l=".$times[$t+1]." (".strftime("%F_%T",localtime($times[$t+1])).")\n");
                my $tt = $t+1;
                # Try and extend the hole to the next strips: ok if for any r, vec(r,current_hole) => vec(r,tt+1)
                while (($tt < $#times) and ((~ $vec | $strips->{$times[$tt+1]}) eq ~ $empty_vec)) {
                    #print("ok-> ".unpack("b*", $strips->{$times[$tt]})." tt=".($tt+1)." l=".$times[$tt+1]." (".strftime("%F_%T",localtime($times[$tt+1])).")\n");
                    $tt++;
                }
                # We now reached the end time for this hole
                #print "endtime: $tt l=".$times[$tt]." (".strftime("%F_%T",localtime($times[$tt])).")\n";
                push @$holes, [$times[$tt], $vec];
                # Test if we did not reach the end of the strips
                if ($tt < $#times) {
                    $vec &= $strips->{$times[$tt+1]};
                } else {
                    $vec = $empty_vec;
                }
            }
            # Store the new start time with its holes
            push @$gantt, [$times[$t], $holes, undef, undef, undef, undef ];
        #} else {
        #    print "NOP: no hole at starttime: t=$t l=".$times[$t]." (".strftime("%F_%T",localtime($times[$t])).")\n";
        }
    }
    # Well done, now fill the global values of the gantt and return
    $gantt->[0]->[2] = $base_resources_vec;
    $gantt->[0]->[3] = $empty_vec;
    $gantt->[0]->[4] = $minimum_hole_duration;
    $gantt->[0]->[5] = $last_checked_hole;
    #print gantt2str($gantt);
    return $gantt;
}

sub compute_constraints($$$) {
    my $constraint_str = shift;
    my $init_date = shift;
    my $iterations = shift;

    my $now = DateTime->from_epoch(epoch => $init_date);
    my $constraints = {};
    # parse constraints
    foreach (split(/\s*,\s*/,$constraint_str)) {
        if (/^(\d+)\/(\d?\d):(\d\d)\/(\d+)(?::(\d\d))?$/) {
            # Compute intervals, given the current date (e.g. what time interval is next tuesday, starting at 14:00 for 10 hours)
            my $c = { days => $1, start => { h => $2, m => $3 }, duration => { h => $4, m => defined($5)?$5:0 } };
            my $h = { map { $_ => 1 } split(//,$c->{days}) }; # make days unique
            my @days = keys (%$h);
            foreach my $d (@days) {
                my $start = $now->clone();
                $start->add(days => ($d - $now->day_of_week) % 7);
                $start->set(hour => $c->{start}->{h}, minute => $c->{start}->{m}, second => 0);
                my $stop = $start->clone();
                $stop->add(hours => $c->{duration}->{h}, minutes => $c->{duration}->{m});
                if ($stop < $now) {
                    $start->add(days => 7);
                    $stop->add(days => 7);
                }
                # Compute $w week iterations of each constraint
                my $w =  $iterations;
                while ($w--) {
                    my $a = $start->epoch();
                    my $b = $stop->epoch();
                    if (not exists($constraints->{$a}) or $constraints->{$a} < $b) {
                        $constraints->{$a} = $b;
                    }
                    $start->add(days => 7);
                    $stop->add(days => 7);
                }
            }
        }
    }
    # Merge constraints intervals in case of overlaps.
    my @starts = sort {$a <=> $b} keys(%$constraints);
    my $i = shift @starts;
    my @result = ([0,84600]); # initialize with a fake first constraint, as required by the find_first_hole function
    my $max_constraint_duration = 0;
    while (defined $i) {
        my $j = shift @starts;
        while (defined($j) and $constraints->{$i} > $constraints->{$j}) {
            $j = shift @starts;
        }
        while (defined($j) and $constraints->{$i} > $j) {
            $constraints->{$i} = $constraints->{$j};
            $j = shift @starts;
        }
        my $d = $constraints->{$i} - $i;
        if ($d > $max_constraint_duration) {
            $max_constraint_duration = $d;
        }
        push @result,[$i , $constraints->{$i}];
        $i = $j;
    }
    return (\@result, $max_constraint_duration);
}

# Build a new gantt by applying constraint to an existing gantt
sub clone_with_constraints($$) {
    my ($gantt, $constraints) = @_;
    # convert gantt to strips
    my $empty_vec = $gantt->[0]->[3];
    my $strips = to_strips($gantt);

    #print strips2str($strips);

    my @strip_times = sort {$a <=> $b} keys(%$strips);
    # filter out the strips which are outside the constraints
    my $e = shift(@strip_times);
    foreach my $c (@$constraints) {
        # delete strips before constraint start
        while ( defined($e) and $e < $c->[0] ) { 
            delete $strips->{$e};
            $e = shift(@strip_times);
        }
        # add new strip at t = constraint start
        $strips->{$c->[0]} = $empty_vec;
        while ( defined($e) and $e < $c->[1] ) { 
            # strip is within constraint, keeping it
            $e = shift(@strip_times);
        }
        # add new strip at t = constraint end
        $strips->{$c->[1]} = $strips->{$e};
    }

    # delete strips after the last constraint end time
    while ( defined($e) ) { 
        delete $strips->{$e};
        $e = shift(@strip_times) 
    }

    #print strips2str($strips);

    # filter out doubles: delete every next strips if same vec value)
    @strip_times = sort {$a <=> $b} keys(%$strips);
    my $next = shift(@strip_times);
    my $current = $next;
    while (defined($next = shift (@strip_times))) {
        if ($strips->{$next} eq $strips->{$current}) {
            delete $strips->{$current};
        }
        $current = $next;
    }
    # TODO? filter out holes which are smaller than $minimun_hole_duration

    #print strips2str($strips);

    # Convert strips back to a gantt.
    return from_strips($strips, $gantt->[0]->[2], $gantt->[0]->[3], $gantt->[0]->[4], $gantt->[0]->[5])
}

# Build a new gantt from the union of the holes of two existing gantts
# Algo:  
# (1) First convert the gantts to strips defined by the start and end times of all holes
#     The 2 stripd gantts are then easy merged: for every holes, gantt_strip(t) |= strip(hole, t)
# (2) Then convert the stripd gantt back to the original gantt structure
# arg : gantt ref1, gantt ref2
sub clone_union($$) {
    my ($gantt1,$gantt2) = @_;
    #print gantt2str($gantt1);
    #print gantt2str($gantt2);

    # Sanity check: are those 2 gantts compatible ?
    if ($gantt1->[0]->[2] ne $gantt2->[0]->[2]) {
        return dclone($gantt1);
    }

    # convert gantts to strips
    my $strips = to_strips([ @$gantt1, @$gantt2 ]);
    my $union = from_strips($strips, $gantt1->[0]->[2], $gantt1->[0]->[3], $gantt1->[0]->[4], $gantt1->[0]->[5]);
    return $union;
}

# Manage the different gantts used in the schedulers handling container, timesharing and placeholder
# See oar_sched_gantt_with_timesharing_and_placeholder
# This allows to factorize code since this function is called in the 2 phases (running jobs, and to schedule jobs)
sub manage_gantt_hierarchy($$$$$$) {
    my $gantt = shift;
    my $job_name = shift;
    my $job_user = shift;
    my $types = shift;
    my $constraints = shift;
    my $log_prefix = shift;

    my $gantt_name = "default";
    my $placeholder_name = "";
    my $allowed_name = "";
    my $timesharing_user = "";
    my $timesharing_name = "";
    if (defined($types->{inner})){
        $gantt_name = "container:$types->{inner}";
        if (defined($gantt->{$gantt_name}->{""}->{""}->{""})){ # even if the actual gantt to use is a timesharing/placeholer gantt, the "raw" gantt should exist 
            oar_debug("$log_prefix inner job, using gantt: ($gantt_name,...)\n");
        }else{ # Existing jobs are placed in the default gantt if the container does not exist, but new jobs will actually not be scheduled, but it's handled outside this file
            oar_debug("$log_prefix inner job, using gantt: (default,...), because gantt: ($gantt_name,...) does not exist anymore.\n");
            $gantt_name = "default";
        }
    } elsif (defined($constraints) and defined($types->{constraints})) {
        # $constraint should only be defined if we are called in a scheduling phase. Computing gantt with constraints is indeed useless when handling jobs which are already scheduled.
        $gantt_name = "constraints:$types->{constraints}";
        oar_debug("$log_prefix constraint job, using gantt: ($gantt_name,...)\n");
    }
    if (defined($types->{placeholder})){ # the placeholder job type is incompatible with allowed and timesharing types 
        $placeholder_name = $types->{placeholder};
        oar_debug("$log_prefix placeholder job, using gantt: ($gantt_name,...)\n");
        if (not defined($gantt->{$gantt_name}->{$placeholder_name}->{""}->{""})){
            oar_debug("$log_prefix placeholder job, cloning new gantt ($gantt_name,$placeholder_name,,) from ($gantt_name,,,)\n");
            $gantt->{$gantt_name}->{$placeholder_name}->{""}->{""} = dclone($gantt->{$gantt_name}->{""}->{""}->{""});
        }
    } else {
        if (defined($types->{allowed})){
            $allowed_name = $types->{allowed};
        }
        if (defined($types->{timesharing})){
            $timesharing_user = "*";
            $timesharing_name = "*";
            foreach my $s (split(',', $types->{timesharing})){
                if ($s =~ m/^\s*([\w\*]+)\s*$/m){
                    if ($1 eq "user"){
                        $timesharing_user = $job_user;
                    }elsif ($1 eq "name") {
                        if (defined($job_name)){
                            $timesharing_name = $job_name;
                        } else {
                            oar_debug("$log_prefix job name not set, cannot restrict timesharing on name\n");
                        }
                    }
                }
            }
        }
        oar_debug("$log_prefix scheduling job in gantt: ($gantt_name,$allowed_name,$timesharing_name,$timesharing_user)\n");
        my @gantt_name_list=($gantt_name);
        if ($gantt_name =~ /^constraints:/) {
            if (not defined($gantt->{$gantt_name}->{""}->{""}->{""})) {
                oar_debug("$log_prefix cloning new gantt: ($gantt_name,,,) from applying constraints to (default,,,)\n");
                $gantt->{$gantt_name}->{""}->{""}->{""} = clone_with_constraints($gantt->{default}->{""}->{""}->{""}, $constraints->{$types->{constraints}});
            }
            if (defined($gantt->{default}->{$allowed_name}->{""}->{""}) and not defined($gantt->{$gantt_name}->{$allowed_name}->{""}->{""})) {
                oar_debug("$log_prefix cloning new gantt: ($gantt_name,$allowed_name,,) from applying constraints to (default,$allowed_name,,)\n");
                $gantt->{$gantt_name}->{$allowed_name}->{""}->{""} = clone_with_constraints($gantt->{default}->{$allowed_name}->{""}->{""}, $constraints->{$types->{constraints}});
            }
            if (defined($gantt->{default}->{""}->{$timesharing_name}->{$timesharing_user}) and not defined($gantt->{$gantt_name}->{""}->{$timesharing_name}->{$timesharing_user})) {
                oar_debug("$log_prefix cloning new gantt: ($gantt_name,,$timesharing_name,$timesharing_user) from applying constraints to (default,,$timesharing_name,$timesharing_user)\n");
                $gantt->{$gantt_name}->{""}->{$timesharing_name}->{$timesharing_user} = clone_with_constraints($gantt->{default}->{""}->{$timesharing_name}->{$timesharing_user}, $constraints->{$types->{constraints}});
            }
            # we do not compute ($gantt_name,$allowed_name,$timesharing_name,$timesharing_user) here, build it below with the union of the above created gantts
            # missing gantts are built below.
            @gantt_name_list=("default", $gantt_name);
        }
        foreach my $g (@gantt_name_list) {
            if (not defined($gantt->{$gantt_name}->{$allowed_name}->{$timesharing_name}->{$timesharing_user})) {
                if (not defined($gantt->{$gantt_name}->{$allowed_name}->{""}->{""}) and not defined($gantt->{$gantt_name}->{""}->{$timesharing_name}->{$timesharing_name})) {
                    oar_debug("$log_prefix cloning new gantt: ($gantt_name,$allowed_name,$timesharing_name,$timesharing_user) from ($gantt_name,,,)\n");
                    $gantt->{$gantt_name}->{$allowed_name}->{$timesharing_name}->{$timesharing_user} = dclone($gantt->{$gantt_name}->{""}->{""}->{""});
                    if ($allowed_name ne "") {
                        oar_debug("$log_prefix cloning new gantt: ($gantt_name,$allowed_name,,) from ($gantt_name,,,)\n");
                        $gantt->{$gantt_name}->{$allowed_name}->{""}->{""} = dclone($gantt->{$gantt_name}->{""}->{""}->{""});
                    }
                    if ($timesharing_name ne "" or $timesharing_user ne "") {
                        oar_debug("$log_prefix cloning new gantt: ($gantt_name,,$timesharing_name,$timesharing_user) from ($gantt_name,,,)\n");
                        $gantt->{$gantt_name}->{""}->{$timesharing_name}->{$timesharing_user} = dclone($gantt->{$gantt_name}->{""}->{""}->{""});
                    }
                } elsif (not defined($gantt->{$gantt_name}->{$allowed_name}->{""}->{""})) { # but G($g,,$u,$n) is defined
                    oar_debug("$log_prefix cloning new gantt: ($gantt_name,$allowed_name,,) from ($gantt_name,,,)\n");
                    $gantt->{$gantt_name}->{$allowed_name}->{""}->{""} = dclone($gantt->{$gantt_name}->{""}->{""}->{""});
                    if ($timesharing_name ne "" and $timesharing_user ne "") {
                        oar_debug("$log_prefix cloning gantt: ($gantt_name,$allowed_name,$timesharing_name,$timesharing_user) from ($gantt_name,,$timesharing_name,$timesharing_user)\n");
                        $gantt->{$gantt_name}->{$allowed_name}->{$timesharing_name}->{$timesharing_user} = dclone($gantt->{$gantt_name}->{""}->{$timesharing_name}->{$timesharing_user});
                    }
                } elsif (not defined($gantt->{$gantt_name}->{""}->{$timesharing_name}->{$timesharing_user})) { # but G($i,$p,,) is defined
                    oar_debug("$log_prefix cloning gantt: ($gantt_name,,$timesharing_name,$timesharing_user) from ($gantt_name,,,)\n");
                    $gantt->{$gantt_name}->{""}->{$timesharing_name}->{$timesharing_user} = dclone($gantt->{$gantt_name}->{""}->{""}->{""});
                    if ($allowed_name ne "") {
                        oar_debug("$log_prefix cloning gantt ($gantt_name,$allowed_name,$timesharing_name,$timesharing_user) from ($gantt_name,$allowed_name,,)\n");
                        $gantt->{$gantt_name}->{$allowed_name}->{$timesharing_name}->{$timesharing_user} = dclone($gantt->{$gantt_name}->{$allowed_name}->{""}->{""});
                    }
                } else { # Both G($i,$p,,) and G($i,,$u,$n) are defined. We need to merge (union) them to create G($i,$p,$u,$n) 
                    oar_debug("$log_prefix cloning gantt ($gantt_name,$allowed_name,$timesharing_name,$timesharing_user) from the union of ($gantt_name,$allowed_name,,) and ($gantt_name,,$timesharing_name,$timesharing_user)\n");
                    $gantt->{$gantt_name}->{$allowed_name}->{$timesharing_name}->{$timesharing_user} = clone_union($gantt->{$gantt_name}->{$allowed_name}->{""}->{""},$gantt->{$gantt_name}->{""}->{$timesharing_name}->{$timesharing_user});
                }
            }
        }
    }
    #print gantt2str( $gantt->{$gantt_name}->{$allowed_name}->{$timesharing_name}->{$timesharing_user});
    return ($gantt_name, $placeholder_name, $allowed_name, $timesharing_name, $timesharing_user);
}

# Fill the gantts different gantts used in the schedulers handling container, timesharing and placeholder
# See oar_sched_gantt_with_timesharing_and_placeholder
# This allows to factorize code since this function is called in the 2 phases (running jobs, and to schedule jobs)
sub fill_gantt_hierarchy($$$$$$$$$) {
    my $gantt = shift;
    my $date = shift;
    my $duration = shift;
    my $resources_vec = shift;
    my $gantt_name = shift;
    my $placeholder_name = shift;
    my $timesharing_name = shift;
    my $timesharing_user = shift;
    my $log_prefix = shift;
    
    my @gantt_name_list=($gantt_name);
    if ($gantt_name =~ /^constraints:/) {
        if (exists($gantt->{$gantt_name})) {
            @gantt_name_list=("default", $gantt_name);
        } else {
            # $gantt->{constraints:...} do not exist if we are just handling existing jobs
            @gantt_name_list=("default");
        }
    }

    foreach my $g (@gantt_name_list) {
        foreach my $p (keys(%{$gantt->{$g}})){
            foreach my $n (keys(%{$gantt->{$g}->{$p}})){
                foreach my $u (keys(%{$gantt->{$g}->{$p}->{$n}})){
                    if (not (($p ne "" and $p eq $placeholder_name) or ($u ne "" and $u eq $timesharing_user and $n ne "" and $n eq $timesharing_name))){
                        oar_debug("$log_prefix add job occupation in gantt: ($g,$p,$n,$u)\n");
                        set_occupation( $gantt->{$g}->{$p}->{$n}->{$u}, $date, $duration, $resources_vec);
                    } else {
                        if ($placeholder_name ne "") {
                            oar_debug("$log_prefix skip job occupation in gantt: ($g,$p,$n,$u) (placeholder)\n");
                        } else {
                            oar_debug("$log_prefix skip job occupation in gantt: ($g,$p,$n,$u) (timesharing)\n");
                        }
                    }
                }
            }
        }
    }
}

# Adds and initializes new resources in the gantt
# args : gantt ref, bit vector of resources
sub add_new_resources($$) {
    my ($gantt, $resources_vec) = @_;

    # Feed vector with enough 0
    $resources_vec |= $gantt->[0]->[3]; 
    
    # Verify which resources are not already inserted
    my $resources_to_add_vec = $resources_vec & (~ $gantt->[0]->[2]);
   
    if (unpack("%32b*",$resources_to_add_vec) > 0){
        # We need to insert new resources on all hole
        my $g = 0;
        while ($g <= $#{$gantt}){
            # Add resources
            if ($gantt->[$g]->[1]->[$#{$gantt->[$g]->[1]}]->[0] == $Infinity){
                $gantt->[$g]->[1]->[$#{$gantt->[$g]->[1]}]->[1] |= $resources_to_add_vec;
            }else{
                push(@{$gantt->[$g]->[1]}, [$Infinity, $resources_vec]);
            }
            $g++;
        }
        # Keep already inserted resources in mind
        $gantt->[0]->[2] |= $resources_vec;
    }
}


# Inserts in the gantt new resource occupations
# args : gantt ref, start slot date, slot duration, resources bit vector
sub set_occupation($$$$){
    my ($gantt, $date, $duration, $resources_vec) = @_;

    # Feed vector with enough 0
    $resources_vec |= $gantt->[0]->[3];

    # If a resource was not initialized
    add_new_resources($gantt,$resources_vec); # If it is not yet done

    my $new_hole = [
                        $date + $duration + 1,
                        []
                    ];
    
    my $g = 0;
    while (($g <= $#{$gantt}) and ($gantt->[$g]->[0] <= $new_hole->[0])){
        my $slot_deleted = 0;
        # Look at all holes that are before the end of the occupation
        if (($#{$gantt->[$g]->[1]} >= 0) and ($gantt->[$g]->[1]->[$#{$gantt->[$g]->[1]}]->[0] >= $date)){
            # Look at holes with a bigger slot >= $date
            my $h = 0;
            my $slot_date_here = 0;
            while ($h <= $#{$gantt->[$g]->[1]}){
                # Look at all slots
                $slot_date_here = 1 if ($gantt->[$g]->[1]->[$h]->[0] == $date);
                if ($gantt->[$g]->[1]->[$h]->[0] > $date){
                    # This slot ends after $date
                    
                    #print("-->[1]\n ".($date - $gantt->[$g]->[0])." -- $gantt->[0]->[4]\n<--[1]\n");
                    
                    if (($gantt->[$g]->[0] < $date) and ($slot_date_here == 0) and ($date - $gantt->[$g]->[0] > $gantt->[0]->[4])){
                        # We must create a smaller slot (hole start time < $date)
                        splice(@{$gantt->[$g]->[1]}, $h, 0, [ $date , $gantt->[$g]->[1]->[$h]->[1] ]);
                        $h++;   # Go to the slot that we were on it before the splice
                        $slot_date_here = 1;

                        #print("-->[2]\n ".gantt2str($gantt)."<--[2]\n");

                    }
                    # Add new slots in the new hole
                    if (($new_hole->[0] < $gantt->[$g]->[1]->[$h]->[0]) and ($gantt->[$g]->[1]->[$h]->[0] - $new_hole->[0] > $gantt->[0]->[4])){
                        # copy slot in the new hole if needed
                        my $slot = 0;
                        while (($slot <= $#{$new_hole->[1]}) and ($new_hole->[1]->[$slot]->[0] < $gantt->[$g]->[1]->[$h]->[0])){
                            # Find right index in the sorted slot array
                            $slot++;
                        }
                        if ($slot <= $#{$new_hole->[1]}){
                            if ($new_hole->[1]->[$slot]->[0] == $gantt->[$g]->[1]->[$h]->[0]){
                                # If the slot already exists
                                $new_hole->[1]->[$slot]->[1] |= $gantt->[$g]->[1]->[$h]->[1];
                            }else{
                                # Insert the new slot
                                splice(@{$new_hole->[1]}, $slot, 0, [$gantt->[$g]->[1]->[$h]->[0], $gantt->[$g]->[1]->[$h]->[1]]);
                            }
                        }elsif ($new_hole->[0] < $gantt->[$g]->[1]->[$h]->[0]){
                            # There is no slot so we create one
                            push(@{$new_hole->[1]}, [ $gantt->[$g]->[1]->[$h]->[0], $gantt->[$g]->[1]->[$h]->[1] ]);
                            
                            #print("-->[3]\n Add new hole $new_hole->[0]: $gantt->[$g]->[1]->[$h]->[0]:\n".Dumper($new_hole)."\n -->[3]\n");
                        
                        }
                    }
                    # Remove new occupied resources from the current slot
                    $gantt->[$g]->[1]->[$h]->[1] &= (~ $resources_vec) ;
                    if (unpack("%32b*",$gantt->[$g]->[1]->[$h]->[1]) == 0){
                        # There is no free resource on this slot so we delete it
                        
                        #print("-->[4]\n Delete slot: $gantt->[$g]->[0],$gantt->[$g]->[1]->[$h]->[0] \n<--[4]\n");
                        
                        splice(@{$gantt->[$g]->[1]}, $h, 1);
                        $h--;
                        $slot_deleted = 1;

                        #print("-->[5]\n ".gantt2str($gantt)."<--[5]\n");

                    }elsif ($h > 0){
                        # check if this is the same hole than the previous one
                        my $tmp_vec = $gantt->[$g]->[1]->[$h-1]->[1] ^ $gantt->[$g]->[1]->[$h]->[1];
                        if (unpack("%32b*",$tmp_vec) == 0){
                            splice(@{$gantt->[$g]->[1]}, $h-1, 1);
                            $h--;
                        }
                    }
                }
                # Go to the next slot
                $h++;
            }
        }
        if (($slot_deleted == 1) and ($#{$gantt->[$g]->[1]} < 0)){
            # There is no free slot on the current hole so we delete it
            splice(@{$gantt}, $g, 1);
            $g--;
        }elsif($g > 0){
            # Test if there is a same hole
            my $different = 0;

            #print("-->[6]\n ".gantt2str($gantt)."<--[6]\n");
            #print("-->[7]\nG-1=$gantt->[$g - 1]->[0]       G=$gantt->[$g]->[0] \n<--[7]\n");
            
            if ($#{$gantt->[$g - 1]->[1]} != $#{$gantt->[$g]->[1]}){
                $different = 1;
            }
            my $tmp_h = 0;
            while (($different == 0) and (defined($gantt->[$g]->[1]->[$tmp_h]))){
                if ($gantt->[$g - 1]->[1]->[$tmp_h]->[0] != $gantt->[$g]->[1]->[$tmp_h]->[0]){
                    $different = 1;
                }else{
                    my $tmp_vec = $gantt->[$g - 1]->[1]->[$tmp_h]->[1] ^ $gantt->[$g]->[1]->[$tmp_h]->[1];
                    if (unpack("%32b*",$tmp_vec) != 0){
                        $different = 1;
                    }
                }
                $tmp_h++;
            }
            if ($different == 0){
                
                #print("-->[8]\n Delete Hole: $gantt->[$g]->[0] \n-->[8]\n");
                
                splice(@{$gantt}, $g, 1);
                $g--;
            }
        }
        # Go to the next hole
        $g++;
    }
    
    #print("-->[9]\n ".gantt2str($gantt)."<--[9]\n");
    
    if ($#{$new_hole->[1]} >= 0){
        # Add the new hole
        if (($g > 0) and ($g - 1 <= $#{$gantt}) and ($gantt->[$g - 1]->[0] == $new_hole->[0])){
            # Verify if the hole does not already exist
            splice(@{$gantt}, $g - 1, 1, $new_hole);
        }else{
            splice(@{$gantt}, $g, 0, $new_hole);
        }
    }
}

# Find the first hole in the data structure that can fit the given slot
sub find_hole($$$){
    my ($gantt, $begin_date, $duration) = @_;

    my $end_date = $begin_date + $duration;
    my $g = 0;
    while (($g < $#{$gantt}) and (($gantt->[$g+1]->[0] <= $begin_date) or (($g <= $#{$gantt}) and ($gantt->[$g]->[0] < $begin_date) and ($gantt->[$g]->[1]->[$#{$gantt->[$g]->[1]}]->[0] < $end_date)))){
        $g++
    }

    return($g);
}

# Returns the vector of the maximum free resources at the given date for the given duration
sub get_free_resources($$$){
    my ($gantt, $begin_date, $duration) = @_;
    
    my $end_date = $begin_date + $duration;
    my $hole_index = 0;
    # search the nearest hole
    while (($hole_index <= $#{$gantt}) and ($gantt->[$hole_index]->[0] < $begin_date) and
            (($gantt->[$hole_index]->[1]->[$#{$gantt->[$hole_index]->[1]}]->[0] < $end_date) or 
                (($hole_index + 1 <= $#{$gantt}) and $gantt->[$hole_index + 1]->[0] < $begin_date))){
        $hole_index++;
    }
    return($gantt->[0]->[4]) if ($hole_index > $#{$gantt});
    
    my $h = 0;
    while (($h <= $#{$gantt->[$hole_index]->[1]}) and ($gantt->[$hole_index]->[1]->[$h]->[0] < $end_date)){
        $h++;
    }
    return($gantt->[$hole_index]->[1]->[$h]->[1]);
}


# Take a list of resource trees and find a hole that fit
# args : gantt ref, initial time from which the search will begin, job duration, list of resource trees
sub find_first_hole($$$$$$$$$$$$){
    my ($gantt,
        $initial_time,
        $duration,
        $tree_description_list,
        $timeout,
        $job_queue,
        $job_project,
        $job_types_arrayref,
        $job_user,
        $gantt_quotas,
        $accounting,
        $only_default_type_resource_vec) = @_;

    # $tree_description_list->[0]  --> First resource group corresponding tree
    # $tree_description_list->[1]  --> Second resource group corresponding tree
    # ...

    # Test if all groups are populated
    my $comment = "no_matching_slot";
    my $return_infinity = 0;
    my $g = 0;
    while (($return_infinity == 0) and ($g <= $#$tree_description_list)){
        if (!defined($tree_description_list->[$g])){
            $return_infinity = 1;
        }
        $g++;
    }
    return ($Infinity, $comment, ()) if ($return_infinity > 0);

    my @result_tree_list = ();
    my $end_loop = 0;
    my $current_time = $initial_time;
    my $timeout_initial_time = time();
    # begin research at the first potential hole
    my $current_hole_index = find_hole($gantt, $initial_time, $duration);
    my $h = 0;
    while ($end_loop == 0){
        # Go to a right hole
        while (($current_hole_index <= $#{$gantt}) and
                (($gantt->[$current_hole_index]->[0] + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0]) or
                   (($initial_time > $gantt->[$current_hole_index]->[0]) and
                        ($initial_time + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0])))){
            while (($h <= $#{$gantt->[$current_hole_index]->[1]}) and
                    (($gantt->[$current_hole_index]->[0] + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0]) or
                        (($initial_time > $gantt->[$current_hole_index]->[0]) and
                        ($initial_time + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0])))){
                $h++;
            }
            if ($h > $#{$gantt->[$current_hole_index]->[1]}){
                # in this hole no slot fits so we must search in the next hole
                $h = 0;
                $current_hole_index++;
            }
        }
        if ($current_hole_index > $#{$gantt}){
            # no hole fits
            $current_time = $Infinity;
            @result_tree_list = ();
            $end_loop = 1;
        }else{
            #print("Treate hole $current_hole_index, $h : $gantt->[$current_hole_index]->[0] --> $gantt->[$current_hole_index]->[1]->[$h]->[0]\n");
            $current_time = $gantt->[$current_hole_index]->[0] if ($initial_time < $gantt->[$current_hole_index]->[0]);
            #Check all trees
            my $i = 0;
            # Initiate already used resources with the empty vector
            my $already_occupied_resources_vec = $gantt->[0]->[3]; 
            my $accounted_used_resources_vec = '';
            my $tmp_leafs_vec = '';
            my $tmp_leafs_hashref = {};
            my $tree_clone;
            do{
                $already_occupied_resources_vec |= $tmp_leafs_vec;
                # clone the tree, so we can work on it without damage
                $tree_clone = OAR::Schedulers::ResourceTree::clone($tree_description_list->[$i]);
                my $tree_clone_bck = $tree_clone;
                
                #print(Dumper($tree_clone));
                $tree_clone = OAR::Schedulers::ResourceTree::delete_tree_nodes_with_not_enough_resources_and_unnecessary_subtrees(
                                    $tree_clone,
                                    $gantt->[$current_hole_index]->[1]->[$h]->[1] & ~ $already_occupied_resources_vec);
                
                ## QUOTAS
                # $current_time : start date of the hole
                # $gantt->[$current_hole_index]->[1]->[$h]->[0] : stop date of the hole
                if (defined($tree_clone)){
                    # Keep in mind the number of resources used by previous groups of the job
                    ($tmp_leafs_vec, $tmp_leafs_hashref) = OAR::Schedulers::ResourceTree::get_tree_leafs_vec($tree_clone);
                    $accounted_used_resources_vec |= $tmp_leafs_vec;
                    my $gantt_next_hole_date_start = $Infinity;
                    $gantt_next_hole_date_start = $gantt->[$current_hole_index+1]->[0] if ($current_hole_index < $#{$gantt});
                    ($current_time,$comment) = OAR::Schedulers::QuotaStorage::check_quotas(
                                                    $accounting,
                                                    $gantt_quotas,
                                                    $current_time,
                                                    $gantt->[$current_hole_index]->[1]->[$h]->[0],
                                                    $gantt_next_hole_date_start,
                                                    $duration,
                                                    $job_queue,$job_project,$job_types_arrayref,$job_user,
                                                    unpack("%32b*", $accounted_used_resources_vec & $only_default_type_resource_vec)
                                                                                           );
                    if (($current_time + $duration >= $gantt->[$current_hole_index]->[1]->[$h]->[0])
                        or (($current_hole_index < $#{$gantt}) and ($gantt->[$current_hole_index+1]->[0] <= $current_time))
                       ){
                        $tree_clone = undef;
                        # Free memory
                        OAR::Schedulers::ResourceTree::destroy($tree_clone_bck);
                    }
                }else{
                    # Free memory
                    OAR::Schedulers::ResourceTree::destroy($tree_clone_bck);
                }
                ## QUOTAS
                my @tmpa = keys(%{$tmp_leafs_hashref});
                $result_tree_list[$i] = [$tree_clone, $tmp_leafs_vec, \@tmpa];
                $i ++;
            }while(defined($tree_clone) && ($i <= $#$tree_description_list));
            if (defined($tree_clone)){
                # We find the first hole
                $end_loop = 1;
            }else{
                # Free memory
                foreach my $t (@{result_tree_list}){
                    OAR::Schedulers::ResourceTree::destroy($t->[0]);
                }
                # Go to the next slot
                if (($h >= $#{$gantt->[$current_hole_index]->[1]})
                     or (($current_hole_index < $#{$gantt}) and ($gantt->[$current_hole_index+1]->[0] <= $current_time))
                   ){
                    $h = 0;
                    $current_hole_index++;
                }else{
                    $h++;
                }
            }
        }
        # Check timeout
        if (($current_hole_index <= $#{$gantt})
            and (((time() - $timeout_initial_time) >= $timeout)
                 or (($gantt->[$current_hole_index]->[0] == $gantt->[0]->[5]->[0])
                     and ($gantt->[$current_hole_index]->[1]->[$h]->[0] >= $gantt->[0]->[5]->[1]))
                 or ($gantt->[$current_hole_index]->[0] > $gantt->[0]->[5]->[0]))
            and ($gantt->[$current_hole_index]->[0] > $initial_time)
           ){
            if (($gantt->[0]->[5]->[0] == $gantt->[$current_hole_index]->[0]) and
                ($gantt->[0]->[5]->[1] > $gantt->[$current_hole_index]->[1]->[$h]->[0])){
                $gantt->[0]->[5]->[1] = $gantt->[$current_hole_index]->[1]->[$h]->[0];
            }elsif ($gantt->[0]->[5]->[0] > $gantt->[$current_hole_index]->[0]){
                $gantt->[0]->[5]->[0] = $gantt->[$current_hole_index]->[0];
                $gantt->[0]->[5]->[1] = $gantt->[$current_hole_index]->[1]->[$h]->[0];
            }
            #print("TTTTTTT $gantt->[0]->[5]->[0] $gantt->[0]->[5]->[1] -- $gantt->[$current_hole_index]->[0] $gantt->[$current_hole_index]->[1]->[$h]->[0]\n");
            $current_time = $Infinity;
            @result_tree_list = ();
            $comment = "TIMEOUT";
            $end_loop = 1;
        }
    }

    return($current_time, $comment, \@result_tree_list);
}

