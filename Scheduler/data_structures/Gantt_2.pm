package Gantt_2;
require Exporter;
use oar_resource_tree;
use Data::Dumper;
use warnings;
use strict;

# Note : All dates are in seconds
# Resources are integer so we store them in bit vectors

# 2^32 is infinity in 32 bits stored time
my $Infinity = 4294967296;

#my $Max_resource_number = 1000000;

#my $Empty = '';
#vec($Empty, 1,1) = 0;
#my $Full = ~ $Empty;

# Prototypes
# gantt chart management
sub new($);
sub add_new_resources($$);
sub set_occupation($$$$);
sub is_resource_free($$$$);
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
    while (($g <= $#{@{$gantt}}) and ($gantt->[$g]->[0] < $new_hole->[0])){
        # Look at all holes that are before the end of the occupation
        if ($gantt->[$g]->[1]->[$#{@{$gantt->[$g]->[1]}}]->[0] >= $date){
            # Look at holes with a biggest slot >= $date
            my $h = 0;
            while ($h <= $#{@{$gantt->[$g]->[1]}}){
                # Look at all slots
                if ($gantt->[$g]->[1]->[$h]->[0] >= $date){
                    # This slot ends after $date
                    if ($gantt->[$g]->[0] < $date){
                        # We must create a smaller slot (hole start time < $date)
                        splice(@{$gantt->[$g]->[1]}, $h, 0, [ $date , $gantt->[$g]->[1]->[$h]->[1] ]);
                        $h++;   # Go to the slot that we were on it before the splice
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
                        splice(@{$gantt->[$g]->[1]}, $h);
                        if ($#{@{$gantt->[$g]->[1]}} < 0){
                            # There is no free slot on the current hole so we delete it
                            splice(@{$gantt}, $g);
                        }
                    }
                }
                # Go to the next slot
                $h++;
            }
        }
        # Go to the next hole
        $g++;
    }
    # Add the new hole
    splice(@{$gantt}, $g, 0, $new_hole);
    #Verifier que le prochain trou n a pas la meme date de debut....
}


# Returns 1 if the specified time slot is empty for the given resource. Otherwise it returns 0
# args : gantt ref, start date, duration, resource name
sub is_resource_free($$$$){
    my ($gantt, $begin_date, $duration, $resource_name) = @_;

    #if (!defined($gantt->{resource_list}->{$resource_name})){
    #    #This resource name was not initialized; use add_new_resource before
    #    return(0);
    #}
    add_new_resource($gantt,$resource_name); # If it is not yet done
    
    my $end_date = $begin_date + $duration;
    my $current_tuple = get_tuple_next_same_resource($gantt->{resource_list}->{$resource_name});
    #Search between which tuples is this interval
    while ( defined(get_tuple_begin_date($current_tuple))
            && !($begin_date > get_tuple_end_date(get_tuple_previous_same_resource($current_tuple))
            && $end_date < get_tuple_begin_date($current_tuple))){
        $current_tuple = get_tuple_next_same_resource($current_tuple);
    }
    if (!defined(get_tuple_end_date(get_tuple_previous_same_resource($current_tuple))) or ($begin_date > get_tuple_end_date(get_tuple_previous_same_resource($current_tuple)))){
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
    my $current_free_resources = sorted_chained_list::new();
    my $current_time = $initial_time;
    my $current_tuple = $gantt->{sorted_root};
    while ($end_loop == 0){
        #print("[GANTT] 1 ".gettimeofday."\n");
        # Add in the sorted chain, tuples that will begin just after the current time 
        while ( defined(get_tuple_end_date($current_tuple))
                && ($current_time >= get_tuple_end_date($current_tuple))){
            if (!defined(get_tuple_begin_date(get_tuple_next_same_resource($current_tuple)))){
                # store empty resource until the infinity
                sorted_chained_list::add_element($current_free_resources,$Infinity,$current_tuple);
            }else{
                sorted_chained_list::add_element($current_free_resources,get_tuple_begin_date(get_tuple_next_same_resource($current_tuple)),$current_tuple);
            }
            $current_tuple = get_tuple_next_sorted_end($current_tuple);
        }
        #print(sorted_chained_list::pretty_print($current_free_resources)."\n");
        #print("[GANTT] 2 ".gettimeofday."\n");

        #Remove current free resources with not enough time
        my $current_element = sorted_chained_list::get_next($current_free_resources);
        while ( defined(sorted_chained_list::get_value($current_element))
                && (sorted_chained_list::get_value($current_element) <= $current_time + $duration + 1)){
            sorted_chained_list::remove_element($current_free_resources,$current_element);
            $current_element = sorted_chained_list::get_next($current_element);
        }
        #print("[GANTT] 3 ".gettimeofday."\n");

        #print(sorted_chained_list::pretty_print($current_free_resources)."\n");

        #Get current free resource names and store it in a vector
        my $free_resources_vector = '';
        $current_element = sorted_chained_list::get_next($current_free_resources);
        while (defined(sorted_chained_list::get_value($current_element))){
            vec($free_resources_vector,get_tuple_resource(sorted_chained_list::get_stored_ref($current_element)),1) = 1;
            $current_element = sorted_chained_list::get_next($current_element);
        }
        #print("[GANTT] 4 ".gettimeofday."\n");
        
        #Check all trees
        my $tree_clone;
        my $i = 0;
        do{
        #print("[GANTT] 5 ".gettimeofday."\n");
            $tree_clone = oar_resource_tree::clone($tree_description_list->[$i]);
        #print("[GANTT] 6 ".gettimeofday."\n");
            #Remove tree leafs that are not free
            foreach my $l (oar_resource_tree::get_tree_leafs($tree_clone)){
                #print(oar_resource_tree::get_current_resource_value($l)."\n");
                if (!vec($free_resources_vector,oar_resource_tree::get_current_resource_value($l),1)){
                    #print("delete subtree $l\n");
                    oar_resource_tree::delete_subtree($l);
                }
            }
        #print("[GANTT] 7 ".gettimeofday."\n");
            $tree_clone = oar_resource_tree::delete_tree_nodes_with_not_enough_resources($tree_clone);
        #print("[GANTT] 8 ".gettimeofday."\n");
            #print(Dumper($tree_clone));
            $result_tree_list[$i] = $tree_clone;
            $i ++;
        }while(defined($tree_clone) && ($i <= $#$tree_description_list));
        
        if (defined($tree_clone)){
            # We find the first hole
            $end_loop = 1;
        }else{
            # We search the next time with at least one free resource added
            #my $initial_current_time = $current_time;
            #while (($current_time <= $initial_current_time) && defined(get_tuple_end_date($current_tuple))){
                $current_time = get_tuple_end_date($current_tuple) if (defined($current_tuple));
            #}
            if (!defined(get_tuple_end_date($current_tuple))){
                $end_loop = 1;
                @result_tree_list = ();
                $current_time = $Infinity;
            }else{
                $current_time = get_tuple_end_date($current_tuple);
            }
        }
    }

        #print("[GANTT] 9 ".gettimeofday."\n");
    return($current_time, \@result_tree_list);
}

return 1;
