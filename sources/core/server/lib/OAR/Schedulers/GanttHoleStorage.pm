# $Id$
package OAR::Schedulers::GanttHoleStorage;
require Exporter;
use OAR::Schedulers::ResourceTree;
use OAR::Modules::Judas qw(oar_debug oar_warn oar_info oar_error set_current_log_category);
use Data::Dumper;
use POSIX ":sys_wait_h";
use POSIX qw(strftime);
use Storable qw(store_fd fd_retrieve dclone);
use warnings;
use strict;

# Note: All dates are in seconds
# Resources are integer so we store them in bit vectors
# Warning: this gantt cannot manage overlaping time slots

# 2^32 is infinity in 32 bits stored time
my $Infinity = 4294967296;

# Prototypes
# gantt chart management
sub new($$);
sub new_with_1_hole($$$$$$);
sub add_new_resources($$);
sub set_occupation($$$$);
sub get_free_resources($$$);
sub find_first_hole($$$$$);
sub pretty_print($);
sub get_infinity_value();

###############################################################################

sub get_infinity_value(){
    return($Infinity);
}

sub pretty_print($){
    my $gantt = shift;

    print("--------------------------------------------------------------------\n");
    my @bits = split(//, unpack("b*", $gantt->[0]->[2]));
    print("@bits\n");
    foreach my $g (@{$gantt}){
        print("BEGIN: $g->[0](".strftime("%F %T",localtime($g->[0])).")\n");
        foreach my $h (@{$g->[1]}){
            @bits = split(//, unpack("b*", $h->[1]));
            print("    $h->[0](".strftime("%F %T",localtime($h->[0]))."): @bits\n");
        }
        print("\n");
    }
    print("--------------------------------------------------------------------\n");
}

# Creates an empty Gantt
# arg: number of the max resource id
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
                        [$Infinity,$Infinity]   # - [t_start,t_end] of the last hole inpected in the previous find_first_hole
                    ]                           #   calls, if a timeout was triggered.
                ];

    return($result);
}


# Creates a Gantt with 1 hole
# arg: number of the max resource id
sub new_with_1_hole($$$$$$){
    my $max_resource_number = shift;
    my $minimum_hole_duration = shift;
    my $date = shift;
    my $duration = shift;
    my $resources_vec = shift;
    my $all_resources_vec = shift;

    my $gantt = new($max_resource_number, $minimum_hole_duration);

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

# Build a new gantt from the merger of two existing gantts
# Algo:
# (1) First convert the gantts to stripes defined by the start and end times of all jobs
#     The 2 striped gantts are then easy merged: for every jobs, gantt_stripe(t) |= stripe(job, t)
# (2) Then convert the striped gantt back to the original gantt structure
# arg: gantt ref1, gantt ref2
sub merge_clone($$) {
    my ($gantt1,$gantt2) = @_;
    #pretty_print($gantt1);
    #pretty_print($gantt2);

    # Sanity check: are those 2 gantts compatible ?
    if ($gantt1->[0]->[2] ne $gantt2->[0]->[2]) {
    }

    # Initialize the stipes by retrieving all jobs start and end times.
    my $empty_vec = $gantt1->[0]->[3];
    my $stripes = {};
    foreach my $h (@$gantt1,@$gantt2) {
        $stripes->{$h->[0]} =  $empty_vec;
        foreach my $hh (@{$h->[1]}) {
            $stripes->{$hh->[0]} = $empty_vec;
        }
    }
    #foreach my $l (sort keys(%$stripes)) {
    #   print(strftime("%F_%T",localtime($l)).": ".unpack("b*", $stripes->{$l})."\n");
    #}

    # Fill the strips with all jobs
    foreach my $h (@$gantt1,@$gantt2) {
        my $t0 = $h->[0];
        foreach my $hh (@{$h->[1]}) {
            my $t1 = $hh->[0];
            foreach my $l (sort keys(%$stripes)) {
                if ($t0 < $l and $l <= $t1) {
                    #print("-> ".strftime("%F_%T",localtime($l))." in ]".strftime("%F_%T",localtime($t0)).", ".strftime("%F_%T",localtime($t1))."] = ".unpack("b*", $stripes->{$l})." | ".unpack("b*", $hh->[1])."\n");
                    $stripes->{$l} |= ($hh->[1]);
                    #foreach my $l (sort keys(%$stripes)) {
                    #    print(strftime("%F_%T",localtime($l)).": ".unpack("b*", $stripes->{$l})."\n");
                    #}
                }
            }
        }
    }
    #print("emtpy_vec= ".unpack("b*", $empty_vec)."\n");
    #my $t=0;
    #foreach my $l (sort keys(%$stripes)) {
    #    print("t=".$t++." l=".strftime("%F_%T",localtime($l)).": ".unpack("b*", $stripes->{$l})."\n");
    #}

    # Convert the striped gantt back to the original structure
    my $merged_gantt = [];
    my @times=sort keys(%$stripes);
    # Try and find new hole start time for every stripe
    for(my $t=0;$t<$#times;$t++) {
        my $holes = [];
        #print("test possible hole starting at $t (".strftime("%F_%T",localtime($times[$t])).") ? : ".unpack("b*", (~ $stripes->{$times[$t]} & $stripes->{$times[$t+1]}))."\n");
        # We have a new hole if for any resource r, vec(r,t-1)=1 and vec(r,t)=0
        if ((~ $stripes->{$times[$t]} & $stripes->{$times[$t+1]}) ne $empty_vec) {
            #print "YES: hole at starttime: t=$t l=".$times[$t]." (".strftime("%F_%T",localtime($times[$t])).")\n";
            my $vec = $stripes->{$times[$t+1]};
            # Compute all holes with this start time, as long as the hole vector is not empty
            while ($vec ne $empty_vec) {
                #print("vec= ".unpack("b*", $vec)." \@t=".($t+1)." l=".$times[$t+1]." (".strftime("%F_%T",localtime($times[$t+1])).")\n");
                my $tt = $t+1;
                # Try and extend the hole to the next stripes: ok if for any r, vec(r,current_hole) => vec(r,tt+1)
                while (($tt < $#times) and ((~ $vec | $stripes->{$times[$tt+1]}) eq ~ $empty_vec)) {
                    #print("ok-> ".unpack("b*", $stripes->{$times[$tt]})." tt=".($tt+1)." l=".$times[$tt+1]." (".strftime("%F_%T",localtime($times[$tt+1])).")\n");
                    $tt++;
                }
                # We now reached the end time for this hole
                #print "endtime: $tt l=".$times[$tt]." (".strftime("%F_%T",localtime($times[$tt])).")\n";
                push @$holes, [$times[$tt], $vec];
                # Test if we did not reach the end of the stripes
                if ($tt < $#times) {
                    $vec &= $stripes->{$times[$tt+1]};
                } else {
                    $vec = $empty_vec;
                }
            }
            # Store the new start time with its holes
            push @$merged_gantt, [$times[$t], $holes, undef, undef, undef, undef ];
        #} else {
        #    print "NOP: no hole at starttime: t=$t l=".$times[$t]." (".strftime("%F_%T",localtime($times[$t])).")\n";
        }
    }
    # Well done, now fill the global values of the gantt and return
    $merged_gantt->[0]->[2] = $gantt1->[0]->[2];
    $merged_gantt->[0]->[3] = $gantt1->[0]->[3];
    $merged_gantt->[0]->[4] = $gantt1->[0]->[4];
    $merged_gantt->[0]->[5] = $gantt1->[0]->[5];
    #pretty_print($merged_gantt);
    return $merged_gantt;
}

# Helper function to test if a Gantt is defined, without side effect
sub defined_gantt($$$$$) {
    my $gantt = shift;
    my $container = shift;
    my $placeholder = shift;
    my $user = shift;
    my $name = shift;
    return (exists($gantt->{$container}) and defined($gantt->{$container})
        and exists($gantt->{$container}->{$placeholder}) and defined($gantt->{$container}->{$placeholder})
        and exists($gantt->{$container}->{$placeholder}->{$user}) and defined($gantt->{$container}->{$placeholder}->{$user})
        and exists($gantt->{$container}->{$placeholder}->{$user}->{$name}) and defined($gantt->{$container}->{$placeholder}->{$user}->{$name}));
}

# Manage the different gantts used in the schedulers handling container, timesharing and placeholder
# See oar_sched_gantt_with_timesharing_and_placeholder
# This allows to factorize code since this function is called in the 2 phases (running jobs, and to schedule jobs)
sub manage_gantt_for_timesharing_and_placeholder($$$$$$$$) {
    my $Gantt = shift;
    my $job_user = shift;
    my $job_name = shift;
    my $types = shift;
    my $inner_id = shift;
    my $module_name = shift;
    my $session_id = shift;
    my $job_id = shift;
    my $placeholder_name = "";
    my $allowed_name = "";
    my $timesharing_user = "";
    my $timesharing_name = "";

    if (defined($types->{placeholder})){ # A placeholder job cannot be allowed or timesharing.
        $placeholder_name = $types->{placeholder};
        oar_info($module_name, "job is ($inner_id,$placeholder_name,,)\n", $session_id, $job_id);
        if (not defined_gantt($Gantt,$inner_id,$placeholder_name,"","")){
            $Gantt->{$inner_id}->{$placeholder_name}->{""}->{""} = dclone($Gantt->{$inner_id}->{""}->{""}->{""});
            oar_info($module_name, "placeholder job: cloned gantt ($inner_id,$placeholder_name,,) from ($inner_id,,,)\n", $session_id, $job_id);
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
                        if (defined($job_name) and $job_name ne "") {
                            $timesharing_name = $job_name;
                        } else {
                            oar_info($module_name, "timesharing on name but no job name defined, using *\n", $session_id, $job_id);
                        }
                    }
                }
            }
        }
        oar_info($module_name, "job is ($inner_id,$allowed_name,$timesharing_user,$timesharing_name)\n", $session_id, $job_id);
        if (not defined_gantt($Gantt,$inner_id,$allowed_name,$timesharing_user,$timesharing_name)) {
            if (not defined_gantt($Gantt,$inner_id,$allowed_name,"","") and not defined_gantt($Gantt,$inner_id,"",$timesharing_user,$timesharing_name)) {
                $Gantt->{$inner_id}->{$allowed_name}->{$timesharing_user}->{$timesharing_name} = dclone($Gantt->{$inner_id}->{""}->{""}->{""});
                oar_info($module_name, "allowed/timesharing job: cloned gantt ($inner_id,$allowed_name,$timesharing_user,$timesharing_name) from ($inner_id,,,)\n", $session_id, $job_id);
                if ($allowed_name ne "") {
                    $Gantt->{$inner_id}->{$allowed_name}->{""}->{""} = dclone($Gantt->{$inner_id}->{""}->{""}->{""});
                    oar_info($module_name, "allowed/timesharing job: cloned gantt ($inner_id,$allowed_name,,) from ($inner_id,,,)\n", $session_id, $job_id);
                }
                if ($timesharing_user ne "" or $timesharing_name ne "") {
                    $Gantt->{$inner_id}->{""}->{$timesharing_user}->{$timesharing_name} = dclone($Gantt->{$inner_id}->{""}->{""}->{""});
                    oar_info($module_name, "allowed/timesharing job: cloned gantt ($inner_id,,$timesharing_user,$timesharing_name) from ($inner_id,,,)\n", $session_id, $job_id);
                }
            } elsif (not defined_gantt($Gantt,$inner_id,$allowed_name,"","")) { #G($i,,$u,$n) is defined
                $Gantt->{$inner_id}->{$allowed_name}->{""}->{""} = dclone($Gantt->{$inner_id}->{""}->{""}->{""});
                oar_info($module_name, "allowed/timesharing job: cloned gantt ($inner_id,$allowed_name,,) from ($inner_id,,,)\n", $session_id, $job_id);
                if ($timesharing_user ne "" and $timesharing_name ne "") {
                    $Gantt->{$inner_id}->{$allowed_name}->{$timesharing_user}->{$timesharing_name} = dclone($Gantt->{$inner_id}->{""}->{$timesharing_user}->{$timesharing_name});
                    oar_info($module_name, "allowed/timesharing job: cloned gantt ($inner_id,$allowed_name,$timesharing_user,$timesharing_name) from ($inner_id,,$timesharing_user,$timesharing_name)\n", $session_id, $job_id);
                }
            } elsif (not defined_gantt($Gantt,$inner_id,"",$timesharing_user,$timesharing_name)) { # G($i,$p,,) is defined
                $Gantt->{$inner_id}->{""}->{$timesharing_user}->{$timesharing_name} = dclone($Gantt->{$inner_id}->{""}->{""}->{""});
                oar_info($module_name, "allowed/timesharing job: cloned gantt ($inner_id,,$timesharing_user,$timesharing_name) from ($inner_id,,,)\n", $session_id, $job_id);
                if ($allowed_name ne "") {
                    $Gantt->{$inner_id}->{$allowed_name}->{$timesharing_user}->{$timesharing_name} = dclone($Gantt->{$inner_id}->{$allowed_name}->{""}->{""});
                    oar_info($module_name, "allowed/timesharing job: cloned gantt ($inner_id,$allowed_name,$timesharing_user,$timesharing_name) from ($inner_id,$allowed_name,,)\n", $session_id, $job_id);
                }
            } else { # Both G($i,$p,,) and G($i,,$u,$n) are defined. We need to merge them to create G($i,$p,$u,$n)
                $Gantt->{$inner_id}->{$allowed_name}->{$timesharing_user}->{$timesharing_name} = merge_clone($Gantt->{$inner_id}->{$allowed_name}->{""}->{""},$Gantt->{$inner_id}->{""}->{$timesharing_user}->{$timesharing_name});
                oar_info($module_name, "allowed/timesharing job: merged gantt ($inner_id,$allowed_name,$timesharing_user,$timesharing_name) from ($inner_id,$allowed_name,,) and ($inner_id,,$timesharing_user,$timesharing_name)\n", $session_id, $job_id);
            }
        }
    }
    return ($placeholder_name, $allowed_name, $timesharing_user, $timesharing_name);
}

# Fill the gantts different gantts used in the schedulers handling container, timesharing and placeholder
# See oar_sched_gantt_with_timesharing_and_placeholder
# This allows to factorize code since this function is called in the 2 phases (running jobs, and to schedule jobs)
sub fill_gantts($$$$$$$$$$$$) {
    my $Gantt = shift;
    my $date = shift;
    my $duration = shift;
    my $resources_vec = shift;
    my $inner_id = shift;
    my $placeholder_name = shift;
    my $allowed_name = shift;
    my $timesharing_user = shift;
    my $timesharing_name = shift;
    my $module_name = shift;
    my $session_id = shift;
    my $job_id = shift;

    foreach my $p (keys(%{$Gantt->{$inner_id}})){
        foreach my $u (keys(%{$Gantt->{$inner_id}->{$p}})){
            foreach my $n (keys(%{$Gantt->{$inner_id}->{$p}->{$u}})){
                if (not (($p ne "" and $p eq $placeholder_name) or ($u ne "" and $u eq $timesharing_user and $n ne "" and $n eq $timesharing_name))){
                    oar_info($module_name, "add job occupation in gantt ($inner_id,$p,$u,$n)\n", $session_id, $job_id);
                    set_occupation( $Gantt->{$inner_id}->{$p}->{$u}->{$n}, $date, $duration, $resources_vec);
                } else {
                    if ($placeholder_name ne "") {
                        oar_info($module_name, "skip job occupation in gantt ($inner_id,$p,$u,$n) because job is ($inner_id,$placeholder_name,,)\n", $session_id, $job_id);
                    } else {
                        oar_info($module_name, "skip job occupation in gantt ($inner_id,$p,$u,$n) because job is ($inner_id,$allowed_name,$timesharing_user,$timesharing_name)\n", $session_id, $job_id);
                    }
                }
            }
        }
    }
}

# Adds and initializes new resources in the gantt
# args: gantt ref, bit vector of resources
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
# args: gantt ref, start slot date, slot duration, resources bit vector
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
            # Look at holes with a biggest slot >= $date
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

                        #print("-->[2]\n "); pretty_print($gantt); print("<--[2]\n");

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

                        #print("-->[5]\n "); pretty_print($gantt); print("<--[5]\n");

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

            #print("-->[6]\n ");pretty_print($gantt);print("<--[6]\n");
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

    #print("-->[9]\n "); pretty_print($gantt); print("<--[9]\n");

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
# args: gantt ref, initial time from which the search will begin, job duration, list of resource trees
sub find_first_hole($$$$$){
    my ($gantt, $initial_time, $duration, $tree_description_list, $timeout) = @_;

    # $tree_description_list->[0]  --> First resource group corresponding tree
    # $tree_description_list->[1]  --> Second resource group corresponding tree
    # ...

    # Test if all groups are populated
    my $return_infinity = 0;
    my $g = 0;
    while (($return_infinity == 0) and ($g <= $#$tree_description_list)){
        if (!defined($tree_description_list->[$g])){
            $return_infinity = 1;
        }
        $g++;
    }
    return ($Infinity, ()) if ($return_infinity > 0);

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
            #print("Treate hole $current_hole_index, $h: $gantt->[$current_hole_index]->[0] --> $gantt->[$current_hole_index]->[1]->[$h]->[0]\n");
            $current_time = $gantt->[$current_hole_index]->[0] if ($initial_time < $gantt->[$current_hole_index]->[0]);
            #Check all trees
            my $tree_clone;
            my $i = 0;
            # Initiate already used resources with the empty vector
            my $already_occupied_resources_vec = $gantt->[0]->[3];
            do{
                foreach my $l (OAR::Schedulers::ResourceTree::get_tree_leafs($tree_clone)){
                    vec($already_occupied_resources_vec, OAR::Schedulers::ResourceTree::get_current_resource_value($l), 1) = 1;
                }
                # clone the tree, so we can work on it without damage
                $tree_clone = OAR::Schedulers::ResourceTree::clone($tree_description_list->[$i]);
                #Remove tree leafs that are not free
                foreach my $l (OAR::Schedulers::ResourceTree::get_tree_leafs($tree_clone)){
                    if ((!vec($gantt->[$current_hole_index]->[1]->[$h]->[1],OAR::Schedulers::ResourceTree::get_current_resource_value($l),1)) or
                        (vec($already_occupied_resources_vec,OAR::Schedulers::ResourceTree::get_current_resource_value($l),1))
                       ){
                        OAR::Schedulers::ResourceTree::delete_subtree($l);
                    }
                }
                #print(Dumper($tree_clone));
                $tree_clone = OAR::Schedulers::ResourceTree::delete_tree_nodes_with_not_enough_resources($tree_clone);
                $tree_clone = OAR::Schedulers::ResourceTree::delete_unnecessary_subtrees($tree_clone);

#$Data::Dumper::Purity = 0;
#$Data::Dumper::Terse = 0;
#$Data::Dumper::Indent = 1;
#$Data::Dumper::Deepcopy = 0;
#                print(Dumper($tree_clone));

                $result_tree_list[$i] = $tree_clone;
                $i ++;
            }while(defined($tree_clone) && ($i <= $#$tree_description_list));
            if (defined($tree_clone)){
                # We find the first hole
                $end_loop = 1;
            }else{
                # Go to the next slot of this hole
                if ($h >= $#{$gantt->[$current_hole_index]->[1]}){
                    $h = 0;
                    $current_hole_index++;
                }else{
                    $h++;
                }
            }
        }
        # Check timeout
        if (($current_hole_index <= $#{$gantt}) and
            (((time() - $timeout_initial_time) >= $timeout) or
            (($gantt->[$current_hole_index]->[0] == $gantt->[0]->[5]->[0]) and ($gantt->[$current_hole_index]->[1]->[$h]->[0] >= $gantt->[0]->[5]->[1])) or
            ($gantt->[$current_hole_index]->[0] > $gantt->[0]->[5]->[0])) and
            ($gantt->[$current_hole_index]->[0] > $initial_time)){
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
            $end_loop = 1;
        }
    }

    return($current_time, \@result_tree_list);
}

# Take a list of resource trees and find a hole that fit
# args: gantt ref, initial time from which the search will begin, job duration, list of resource trees
sub find_first_hole_parallel($$$$$$){
    my ($gantt, $initial_time, $duration, $tree_description_list, $timeout, $max_children) = @_;

    # $tree_description_list->[0]  --> First resource group corresponding tree
    # $tree_description_list->[1]  --> Second resource group corresponding tree
    # ...

    # Test if all groups are populated
    my $return_infinity = 0;
    my $g = 0;
    while (($return_infinity == 0) and ($g <= $#$tree_description_list)){
        if (!defined($tree_description_list->[$g])){
            $return_infinity = 1;
        }
        $g++;
    }
    return ($Infinity, ()) if ($return_infinity > 0);


    my @result_tree_list = ();
    my $end_loop = 0;
    my $current_time = $initial_time;
    my $timeout_initial_time = time();
    my %children;
    my $process_index = 0;
    my $process_index_to_check = 0;
    my @result_children;
    # begin research at the first potential hole
    my $current_hole_index = find_hole($gantt, $initial_time, $duration);
    my $current_process_hole_index = 0;
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
        if (($current_hole_index > $#{$gantt}) and (keys(%children) <= 0)){
            # no hole fits
            $current_time = $Infinity;
            @result_tree_list = ();
            $end_loop = 1;
        }else{
            my $select_timeout = 0.1;
            if (($current_hole_index <= $#{$gantt}) and (keys(%children) < $max_children)){
                $select_timeout = 0;
                $current_process_hole_index = $current_hole_index if ($process_index == 0);
                my $P1;
                my $P2;
                pipe($P1,$P2);
                my $pid = fork();
                if ($pid == 0){
                    #Child
                    close($P1);
                    #print "PID $$: $process_index ($current_hole_index)\n";
                    #print("Treate hole $current_hole_index, $h: $gantt->[$current_hole_index]->[0] --> $gantt->[$current_hole_index]->[1]->[$h]->[0]\n");
                    $current_time = $gantt->[$current_hole_index]->[0] if ($initial_time < $gantt->[$current_hole_index]->[0]);
                    #Check all trees
                    my $tree_clone;
                    my $tree_list;
                    my $i = 0;
                    # Initiate already used resources with the empty vector
                    my $already_occupied_resources_vec = $gantt->[0]->[3];
                    do{
                        foreach my $l (OAR::Schedulers::ResourceTree::get_tree_leafs($tree_clone)){
                            vec($already_occupied_resources_vec, OAR::Schedulers::ResourceTree::get_current_resource_value($l), 1) = 1;
                        }
                        $tree_clone = $tree_description_list->[$i];
                        #Remove tree leafs that are not free
                        foreach my $l (OAR::Schedulers::ResourceTree::get_tree_leafs($tree_clone)){
                            if ((!vec($gantt->[$current_hole_index]->[1]->[$h]->[1],OAR::Schedulers::ResourceTree::get_current_resource_value($l),1)) or
                                (vec($already_occupied_resources_vec,OAR::Schedulers::ResourceTree::get_current_resource_value($l),1))
                               ){
                                OAR::Schedulers::ResourceTree::delete_subtree($l);
                            }
                        }
                        #print(Dumper($tree_clone));
                        $tree_clone = OAR::Schedulers::ResourceTree::delete_tree_nodes_with_not_enough_resources($tree_clone);
                        $tree_clone = OAR::Schedulers::ResourceTree::delete_unnecessary_subtrees($tree_clone);

                        $tree_list->[$i] = $tree_clone;
                        $i ++;
                    }while(defined($tree_clone) && ($i <= $#$tree_description_list));

                    my %result = (
                        process_index => $process_index,
                        current_time => $current_time,
                        current_hole_index => $current_hole_index
                    );
                    if (defined($tree_clone)){
                        #print "PID $$; INDEX $process_index: I found a hole\n";
                        $result{result_tree_list} = $tree_list;
                    }else{
                        $result{result_tree_list} = undef;
                    }
                    select($P2);
                    $| = 1;
                    store_fd(\%result, $P2);
                    close($P2);
                    exit(0);
                }
                #Father
                $children{$pid} = {
                                    process_index => $process_index,
                                    pipe_read => $P1
                                  };
                $process_index++;
                # Go to the next slot of this hole
                if ($h >= $#{$gantt->[$current_hole_index]->[1]}){
                    $h = 0;
                    $current_hole_index++;
                }else{
                    $h++;
                }
            }
            # check children results
            my $rin = '';
            foreach my $p (keys(%children)){
                vec($rin, fileno($children{$p}->{pipe_read}), 1) = 1;
            }
            my $rout;
            if (select($rout=$rin, undef, undef, $select_timeout)){
                foreach my $p (keys(%children)){
                    if (vec($rout,fileno($children{$p}->{pipe_read}),1)){
                        my $fh = $children{$p}->{pipe_read};
                        my $hash = fd_retrieve($fh);
                        #print "MASTER child $children{$p}->{process_index} FINISHED\n";
                        $result_children[$children{$p}->{process_index}] = $hash;
                        delete($children{$p});
                        close($fh);
                    }
                }
            }

            while ((defined($result_children[$process_index_to_check])) and ($end_loop == 0)){
                if (defined($result_children[$process_index_to_check]->{result_tree_list})){
                    # We find the first hole
                    #print "MASTER using hole from process index $process_index_to_check\n";
                    $current_time = $result_children[$process_index_to_check]->{current_time};
                    @result_tree_list = @{$result_children[$process_index_to_check]->{result_tree_list}};
                    $end_loop = 1;
                }
                $current_process_hole_index = $result_children[$process_index_to_check]->{current_hole_index};
                $process_index_to_check++;
            }
            # Avoid zombies
            my $kid = 1;
            while ($kid > 0){
                $kid = waitpid(-1, WNOHANG);
            }

            # Check timeout
            #print "CURRENT HOLE: $current_process_hole_index\n";
            if (($end_loop == 0) and ($current_process_hole_index <= $#{$gantt}) and
                (((time() - $timeout_initial_time) >= $timeout) or
                (($gantt->[$current_process_hole_index]->[0] == $gantt->[0]->[5]->[0]) and ($gantt->[$current_process_hole_index]->[1]->[$h]->[0] >= $gantt->[0]->[5]->[1])) or
                ($gantt->[$current_process_hole_index]->[0] > $gantt->[0]->[5]->[0])) and
                ($gantt->[$current_process_hole_index]->[0] > $initial_time)){
                if (($gantt->[0]->[5]->[0] == $gantt->[$current_process_hole_index]->[0]) and
                    ($gantt->[0]->[5]->[1] > $gantt->[$current_process_hole_index]->[1]->[$h]->[0])){
                    $gantt->[0]->[5]->[1] = $gantt->[$current_process_hole_index]->[1]->[$h]->[0];
                }elsif ($gantt->[0]->[5]->[0] > $gantt->[$current_process_hole_index]->[0]){
                    $gantt->[0]->[5]->[0] = $gantt->[$current_process_hole_index]->[0];
                    $gantt->[0]->[5]->[1] = $gantt->[$current_process_hole_index]->[1]->[$h]->[0];
                }
                #print("TTTTTTT $gantt->[0]->[5]->[0] $gantt->[0]->[5]->[1] -- $gantt->[$current_hole_index]->[0] $gantt->[$current_hole_index]->[1]->[$h]->[0]\n");
                $current_time = $Infinity;
                @result_tree_list = ();
                $end_loop = 1;
            }
        }
    }

    kill(9,keys(%children));
    # Avoid zombies
    my $kid = 1;
    while ($kid > 0){
        $kid = waitpid(-1, WNOHANG);
    }
    return($current_time, \@result_tree_list);
}


return 1;
