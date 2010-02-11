# $Id$
package Gantt_hole_storage;
require Exporter;
use oar_resource_tree;
use Data::Dumper;
use POSIX ":sys_wait_h";
use Storable qw(store_fd fd_retrieve);
use warnings;
use strict;

# Note : All dates are in seconds
# Resources are integer so we store them in bit vectors
# Warning : this gantt cannot manage overlaping time slots

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
   
    my @bits = split(//, unpack("b*", $gantt->[0]->[2]));
    print("@bits\n");
    foreach my $g (@{$gantt}){
        print("BEGIN : $g->[0]\n");
        foreach my $h (@{$g->[1]}){
            @bits = split(//, unpack("b*", $h->[1]));
            print("    $h->[0] : @bits\n");
        }
        print("\n");
    }
}

# Creates an empty Gantt
# arg : number of the max resource id
sub new($$){
    my $max_resource_number = shift;
    my $minimum_hole_duration = shift;

    $minimum_hole_duration = 0 if (!defined($minimum_hole_duration));

    my $empty_vec = '';
    vec($empty_vec, $max_resource_number, 1) = 0;
    
    my $result =[
                    [
                        0,                              # start time of this hole
                        [                               # ref of a structure which contains hole stop times and corresponding resources (ordered by end time)
                            [$Infinity, $empty_vec]
                        ],
                        $empty_vec,                     # Store all inserted resources (Only for the first Gantt hole)
                        $empty_vec,                     # Store empty vec with enough 0 (Only for the first hole)
                        $minimum_hole_duration,         # minimum time for a hole
                        [$Infinity,$Infinity]           # times that find_first_hole must not go after
                    ]
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

    my $gantt = Gantt_hole_storage::new($max_resource_number, $minimum_hole_duration);

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
            # Look at holes with a biggest slot >= $date
            my $h = 0;
            my $slot_date_here = 0;
            while ($h <= $#{$gantt->[$g]->[1]}){
                # Look at all slots
                $slot_date_here = 1 if ($gantt->[$g]->[1]->[$h]->[0] == $date);
                if ($gantt->[$g]->[1]->[$h]->[0] > $date){
                    # This slot ends after $date
                    #print($date - $gantt->[$g]->[0]." -- $gantt->[0]->[4]\n");
                    if (($gantt->[$g]->[0] < $date) and ($slot_date_here == 0) and ($date - $gantt->[$g]->[0] > $gantt->[0]->[4])){
                        # We must create a smaller slot (hole start time < $date)
                        splice(@{$gantt->[$g]->[1]}, $h, 0, [ $date , $gantt->[$g]->[1]->[$h]->[1] ]);
                        $h++;   # Go to the slot that we were on it before the splice
                        $slot_date_here = 1;
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
                        }
                    }
                    # Remove new occupied resources from the current slot
                    $gantt->[$g]->[1]->[$h]->[1] &= (~ $resources_vec) ;
                    if (unpack("%32b*",$gantt->[$g]->[1]->[$h]->[1]) == 0){
                        # There is no free resource on this slot so we delete it
                        splice(@{$gantt->[$g]->[1]}, $h, 1);
                        $h--;
                        $slot_deleted = 1;
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
            if ($#{$gantt->[$g - 1]->[1]} != $#{$gantt->[$g]->[1]}){
                $different = 1;
            }
            my $tmp_h = 0;
            while (($different == 0) and (defined($gantt->[$g]->[1]->[$tmp_h]))){
                my $tmp_vec = $gantt->[$g - 1]->[1]->[$tmp_h]->[1] ^ $gantt->[$g]->[1]->[$tmp_h]->[1];
                if (unpack("%32b*",$tmp_vec) != 0){
                    $different = 1;
                }
                $tmp_h++;
            }
            if ($different == 0){
                splice(@{$gantt}, $g, 1);
                $g--;
            }
        }
        # Go to the next hole
        $g++;
    }
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
    while (($g <= $#{$gantt}) and ($gantt->[$g]->[0] < $begin_date) and ($gantt->[$g]->[1]->[$#{$gantt->[$g]->[1]}]->[0] < $end_date)){
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
            #print("Treate hole $current_hole_index, $h : $gantt->[$current_hole_index]->[0] --> $gantt->[$current_hole_index]->[1]->[$h]->[0]\n");
            $current_time = $gantt->[$current_hole_index]->[0] if ($initial_time < $gantt->[$current_hole_index]->[0]);
            #Check all trees
            my $tree_clone;
            my $i = 0;
            # Initiate already used resources with the empty vector
            my $already_occupied_resources_vec = $gantt->[0]->[3]; 
            do{
                foreach my $l (oar_resource_tree::get_tree_leafs($tree_clone)){
                    vec($already_occupied_resources_vec, oar_resource_tree::get_current_resource_value($l), 1) = 1;
                }
                # clone the tree, so we can work on it without damage
                $tree_clone = oar_resource_tree::clone($tree_description_list->[$i]);
                #Remove tree leafs that are not free
                foreach my $l (oar_resource_tree::get_tree_leafs($tree_clone)){
                    if ((!vec($gantt->[$current_hole_index]->[1]->[$h]->[1],oar_resource_tree::get_current_resource_value($l),1)) or
                        (vec($already_occupied_resources_vec,oar_resource_tree::get_current_resource_value($l),1))
                       ){
                        oar_resource_tree::delete_subtree($l);
                    }
                }
                #print(Dumper($tree_clone));
                $tree_clone = oar_resource_tree::delete_tree_nodes_with_not_enough_resources($tree_clone);
                $tree_clone = oar_resource_tree::delete_unnecessary_subtrees($tree_clone);
                
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
# args : gantt ref, initial time from which the search will begin, job duration, list of resource trees
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
                    #print "PID $$ : $process_index ($current_hole_index)\n";
                    #print("Treate hole $current_hole_index, $h : $gantt->[$current_hole_index]->[0] --> $gantt->[$current_hole_index]->[1]->[$h]->[0]\n");
                    $current_time = $gantt->[$current_hole_index]->[0] if ($initial_time < $gantt->[$current_hole_index]->[0]);
                    #Check all trees
                    my $tree_clone;
                    my $tree_list;
                    my $i = 0;
                    # Initiate already used resources with the empty vector
                    my $already_occupied_resources_vec = $gantt->[0]->[3]; 
                    do{
                        foreach my $l (oar_resource_tree::get_tree_leafs($tree_clone)){
                            vec($already_occupied_resources_vec, oar_resource_tree::get_current_resource_value($l), 1) = 1;
                        }
                        $tree_clone = $tree_description_list->[$i];
                        #Remove tree leafs that are not free
                        foreach my $l (oar_resource_tree::get_tree_leafs($tree_clone)){
                            if ((!vec($gantt->[$current_hole_index]->[1]->[$h]->[1],oar_resource_tree::get_current_resource_value($l),1)) or
                                (vec($already_occupied_resources_vec,oar_resource_tree::get_current_resource_value($l),1))
                               ){
                                oar_resource_tree::delete_subtree($l);
                            }
                        }
                        #print(Dumper($tree_clone));
                        $tree_clone = oar_resource_tree::delete_tree_nodes_with_not_enough_resources($tree_clone);
                        $tree_clone = oar_resource_tree::delete_unnecessary_subtrees($tree_clone);

                        $tree_list->[$i] = $tree_clone;
                        $i ++;
                    }while(defined($tree_clone) && ($i <= $#$tree_description_list));

                    my %result = (
                        process_index => $process_index,
                        current_time => $current_time,
                        current_hole_index => $current_hole_index
                    );
                    if (defined($tree_clone)){
                        #print "PID $$; INDEX $process_index : I found a hole\n";
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
