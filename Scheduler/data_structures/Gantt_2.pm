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

my $Max_resource_number = 1000000;

#my $Empty = '';
#vec($Empty, 1,1) = 0;
#my $Full = ~ $Empty;

# Prototypes
# gantt chart management
sub new();
sub add_new_resources($$);
sub set_occupation($$$$);
sub is_resource_free($$$$);
sub find_first_hole($$$$);

###############################################################################

# Creates an empty Gantt
# arg : gantt reference
sub new(){
    my $empty_vec = '';
    my $result = [
                    undef,                          # ref of the previous hole
                    undef,                          # ref of the next hole
                    0,                              # start time of this hole
                    [                               # ref of a structure which contains hole stop time and corresponding resources
                        [$Infinity, $empty_vec]
                    ],
                    ''                              # Store all inserted resources
                 ];
    
    vec($result->[4], $Max_resource_number, 1) = 0; # Init bit vector of all resources
    return($result);
}


# Adds and initializes new resources in the gantt
# args : gantt ref, bit vector of resources
sub add_new_resource($$) {
    my ($gantt, $resource_vec) = @_;

    # Verify which resources are not already inserted
    my $resources_to_add_vec = $resource_vec & (~ $gantt->[4]);
   
    if (unpack("%2b*",$resources_to_add_vec) > 0){
        my $current_hole = $gantt;
        do{
            # Add resources
            $current_hole->[3]->[$#{@{$current_hole->[3]}}]->[1] |= $resources_to_add_vec;
            $current_hole = $current_hole->[1];
        }while(defined($current_hole));
        $gantt->[4] |= $resource_vec;
    }
}


# Inserts in the gantt chained list a new occupation time slot
# args : gantt ref, start slot date, slot duration, resource name
sub set_occupation($$$$){
    my ($gantt, $date, $duration, $resource_name) = @_;
  
    add_new_resource($gantt,$resource_name); # If it is not yet done
  
    my $new_tuple = allocate_new_tuple($resource_name, $date, $date + $duration);
    my $current_tuple = $gantt->{resource_list}->{$resource_name};
    # Search the good position in the same resource chained list
    while ( defined(get_tuple_begin_date(get_tuple_next_same_resource($current_tuple)))
            && ($date > get_tuple_begin_date(get_tuple_next_same_resource($current_tuple)))){
        $current_tuple = get_tuple_next_same_resource($current_tuple);
    }
    add_resource_tuple_after($current_tuple, $new_tuple);

    $current_tuple = $gantt->{sorted_root};
    # Search the good position in the global resource chained list
    while ( defined(get_tuple_begin_date(get_tuple_next_sorted_end($current_tuple)))
            && ($date + $duration > get_tuple_end_date(get_tuple_next_sorted_end($current_tuple)))){
        $current_tuple = get_tuple_next_sorted_end($current_tuple);
    }
    add_sorted_tuple_end_after($current_tuple, $new_tuple);
    
    return($new_tuple);
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
