package Gantt_2;
require Exporter;
use oar_resource_tree;
use Data::Dumper;
use warnings;
use strict;

# Note : All dates are in seconds
# Resources are integer so we store them in bit vectors
# Warning : this gantt cannot manage overlaping time slots

# 2^32 is infinity in 32 bits stored time
my $Infinity = 4294967296;

# Prototypes
# gantt chart management
sub new($);
sub add_new_resources($$);
sub set_occupation($$$$);
sub is_resources_free($$$$);
sub find_first_hole($$$$);
sub pretty_print($);

###############################################################################

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
sub new($){
    my $max_resource_number = shift;

    my $empty_vec = '';
    vec($empty_vec, $max_resource_number, 1) = 0;
    
    my $result =[
                    [
                        0,                              # start time of this hole
                        [                               # ref of a structure which contains hole stop times and corresponding resources (ordered by end time)
                            [$Infinity, $empty_vec]
                        ],
                        $empty_vec,                             # Store all inserted resources (Only for the first Gantt hole)
                        $empty_vec                      # Store empty vec with enough 0 (Only for the first hole)
                    ]
                ];
    
    return($result);
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
        while ($g <= $#{@{$gantt}}){
            # Add resources
            if ($gantt->[$g]->[1]->[$#{@{$gantt->[$g]->[1]}}]->[0] == $Infinity){
                $gantt->[$g]->[1]->[$#{@{$gantt->[$g]->[1]}}]->[1] |= $resources_to_add_vec;
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
    while (($g <= $#{@{$gantt}}) and ($gantt->[$g]->[0] <= $new_hole->[0])){
        my $slot_deleted = 0;
        # Look at all holes that are before the end of the occupation
        if (($#{@{$gantt->[$g]->[1]}} >= 0) and ($gantt->[$g]->[1]->[$#{@{$gantt->[$g]->[1]}}]->[0] >= $date)){
            # Look at holes with a biggest slot >= $date
            my $h = 0;
            my $slot_date_here = 0;
            while ($h <= $#{@{$gantt->[$g]->[1]}}){
                # Look at all slots
                $slot_date_here = 1 if ($gantt->[$g]->[1]->[$h]->[0] == $date);
                if ($gantt->[$g]->[1]->[$h]->[0] > $date){
                    # This slot ends after $date
                    if (($gantt->[$g]->[0] < $date) and ($slot_date_here == 0)){
                        # We must create a smaller slot (hole start time < $date)
                        splice(@{$gantt->[$g]->[1]}, $h, 0, [ $date , $gantt->[$g]->[1]->[$h]->[1] ]);
                        $h++;   # Go to the slot that we were on it before the splice
                        $slot_date_here = 1;
                    }
                    # Add new slots in the new hole
                    if ($new_hole->[0] < $gantt->[$g]->[1]->[$h]->[0]){
                        # copy slot in the new hole if needed
                        my $slot = 0;
                        while (($slot <= $#{@{$new_hole->[1]}}) and ($new_hole->[1]->[$slot]->[0] < $gantt->[$g]->[1]->[$h]->[0])){
                            # Find right index in the sorted slot array
                            $slot++;
                        }
                        if ($slot <= $#{@{$new_hole->[1]}}){
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
                    $gantt->[$g]->[1]->[$h]->[1] &= (~ $resources_vec);
                    if (unpack("%32b*",$gantt->[$g]->[1]->[$h]->[1]) == 0){
                        # There is no free resource on this slot so we delete it
                        splice(@{$gantt->[$g]->[1]}, $h, 1);
                        $h--;
                        $slot_deleted = 1;
                    }
                }
                # Go to the next slot
                $h++;
            }
        }
        if (($slot_deleted == 1) and ($#{@{$gantt->[$g]->[1]}} < 0)){
            # There is no free slot on the current hole so we delete it
            splice(@{$gantt}, $g, 1);
            $g--;
        }
        # Go to the next hole
        $g++;
    }
    if ($#{@{$new_hole->[1]}} >= 0){
        # Add the new hole
        
        if (($g > 0) and ($g - 1 <= $#{@{$gantt}}) and ($gantt->[$g - 1]->[0] == $new_hole->[0])){
            # Verify if the hole does not already exist
            splice(@{$gantt}, $g - 1, 1, $new_hole);
        }else{
            splice(@{$gantt}, $g, 0, $new_hole);
        }
    }
}


sub find_hole($$$){
    my ($gantt, $begin_date, $duration) = @_;

    my $end_date = $begin_date + $duration;
    my $g = 0;
    while (($g <= $#{@{$gantt}}) and ($gantt->[$g]->[0] < $begin_date) and ($gantt->[$g]->[1]->[$#{@{$gantt->[$g]->[1]}}]->[0] < $end_date)){
        $g++
    }

    return($g);
}

# Returns 1 if the specified time slot is empty for the given resources. Otherwise it returns 0
# args : gantt ref, start date, duration, bits resources vector
sub is_resources_free($$$$){
    my ($gantt, $begin_date, $duration, $resources_vec) = @_;
    
    # Feed vector with enough 0
    $resources_vec |= $gantt->[0]->[3];
    
    my $hole_index = find_hole($gantt, $begin_date, $duration);
    return(0) if ($hole_index > $#{@{$gantt}});

    my $end_date = $begin_date + $duration;
    my $h = 0;
    while (($h <= $#{@{$gantt->[$hole_index]->[1]}}) and ($gantt->[$hole_index]->[1]->[$h]->[0] < $end_date)){
        $h++;
    }
    my $free_resources_vec = $gantt->[$hole_index]->[1]->[$h]->[1];
    my $result_vec = ($free_resources_vec & $resources_vec) ^ $resources_vec;
    if (unpack("%32b*",$result_vec) == 0){
        return(1);
    }else{
        return(0);
    }
}


# Take a list of resource trees and find a hole that fit
# args : gantt ref, initial time from which the search will begin, job duration, list of resource trees
sub find_first_hole($$$$){
    my ($gantt, $initial_time, $duration, $tree_description_list) = @_;

    # $tree_description_list->[0]  --> First resource group corresponding tree
    # $tree_description_list->[1]  --> Second resource group corresponding tree
    # ...

    return ($Infinity, ()) if (!defined($tree_description_list->[0]));

    my @result_tree_list = ();
    my $end_loop = 0;
    # Tuples sorted by begin date
    my $current_time = $initial_time;
    my $current_hole_index = find_hole($gantt, $initial_time, $duration);
    my $h = 0;
    while ($end_loop == 0){
        # Go to a right hole
        print("[GANTT] 1\n");
        while (($current_hole_index <= $#{@{$gantt}}) and
                (($gantt->[$current_hole_index]->[0] + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0]) or
                   (($initial_time > $gantt->[$current_hole_index]->[0]) and
                        ($initial_time + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0])))){
        print("[GANTT] 2\n");
            while (($h <= $#{@{$gantt->[$current_hole_index]->[1]}}) and
                    (($gantt->[$current_hole_index]->[0] + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0]) or
                        (($initial_time > $gantt->[$current_hole_index]->[0]) and
                        ($initial_time + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0])))){
        print("[GANTT] 3\n");
                $h++;
            }
            if ($h > $#{@{$gantt->[$current_hole_index]->[1]}}){
            #if (($gantt->[$current_hole_index]->[0] + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0]) or
            #        (($initial_time > $gantt->[$current_hole_index]->[0]) and
            #         ($initial_time + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0]))){
                $h = 0;
                $current_hole_index++;
        print("[GANTT] 4\n");
            }
        }
        if ($current_hole_index > $#{@{$gantt}}){
        print("[GANTT] 5\n");
            $current_time = $Infinity;
            @result_tree_list = ();
            $end_loop = 1;
        }else{
        print("[GANTT] 6\n");
            $current_time = $gantt->[$current_hole_index]->[0] if ($initial_time < $gantt->[$current_hole_index]->[0]);
            #Check all trees
            my $tree_clone;
            my $i = 0;
            do{
        print("[GANTT] 7\n");
                $tree_clone = oar_resource_tree::clone($tree_description_list->[$i]);
                #Remove tree leafs that are not free
                foreach my $l (oar_resource_tree::get_tree_leafs($tree_clone)){
                    #print(oar_resource_tree::get_current_resource_value($l)."\n");
                    if (!vec($gantt->[$current_hole_index]->[1]->[$h]->[1],oar_resource_tree::get_current_resource_value($l),1)){
                        #print("delete subtree $l\n");
                        oar_resource_tree::delete_subtree($l);
                    }
                }
                $tree_clone = oar_resource_tree::delete_tree_nodes_with_not_enough_resources($tree_clone);
                #print(Dumper($tree_clone));
                $result_tree_list[$i] = $tree_clone;
                $i ++;
            }while(defined($tree_clone) && ($i <= $#$tree_description_list));
            if (defined($tree_clone)){
                # We find the first hole
                $end_loop = 1;
            }else{
                if ($h >= $#{@{$gantt->[$current_hole_index]->[1]}}){
                    $h = 0;
                    $current_hole_index++;
                }else{
                    $h++;
                }
            }
        print("[GANTT] 8\n");
        }
        print("[GANTT] 9\n");
    }

        print("[GANTT] 10\n");
    return($current_time, \@result_tree_list);
}

return 1;
