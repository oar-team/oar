package Gantt;
require Exporter;
use oar_Judas qw(oar_debug oar_warn oar_error);
use oar_resource_tree;
use sorted_chained_list;
use Data::Dumper;
use warnings;
use strict;

# Note : All dates are in seconds

# Prototypes
# gant chart management
sub new();
sub add_new_resource($$);
sub set_occupation($$$$);
sub is_resource_free($$$$);
sub find_first_hole($$$$);

# A gantt chart is a 4 linked tuple list. Each tuple has got the reference to:
#   - previous end busy interval (last end occupation)
#   - next end busy interval (next end occupation)
#   - previous busy interval for the same resource
#   - next busy interval for the same resource


# 2^32 is infinity in 32 bits stored time
my $Infinity = 4294967296;

sub get_tuple_resource($){
    my ($tuple_ref) = @_;

    #Name of the resource
    return($tuple_ref->{resource});
}

sub get_tuple_begin_date($){
    my ($tuple_ref) = @_;
    
    # Date in seconds
    return($tuple_ref->{begin_date});
}

sub get_tuple_end_date($){
    my ($tuple_ref) = @_;

    #Date in seconds
    return($tuple_ref->{end_date});
}

sub get_tuple_previous_same_resource($){
    my ($tuple_ref) = @_;

    #Ref of a tuple
    return($tuple_ref->{previous_resource});
}

sub get_tuple_next_same_resource($){
    my ($tuple_ref) = @_;
    
    #Ref of a tuple
    return($tuple_ref->{next_resource});
}

sub get_tuple_previous_sorted_end($){
    my ($tuple_ref) = @_;

    #Ref of a tuple
    return($tuple_ref->{previous_sorted});
}

sub get_tuple_next_sorted_end($){
    my ($tuple_ref) = @_;

    #Ref of a tuple
    return($tuple_ref->{next_sorted});
}

sub set_tuple_resource($$){
    my ($tuple_ref,$value) = @_;

    $tuple_ref->{resource} = $value;
}

sub set_tuple_begin_date($$){
    my ($tuple_ref,$value) = @_;

    $tuple_ref->{begin_date} = $value;
}

sub set_tuple_end_date($$){
    my ($tuple_ref,$value) = @_;

    $tuple_ref->{end_date} = $value;
}

sub set_tuple_previous_same_resource($$){
    my ($tuple_ref,$value) = @_;

    $tuple_ref->{previous_resource} = $value;
}

sub set_tuple_next_same_resource($$){
    my ($tuple_ref,$value) = @_;

    $tuple_ref->{next_resource} = $value;
}

sub set_tuple_previous_sorted_end($$){
    my ($tuple_ref,$value) = @_;

    $tuple_ref->{previous_sorted} = $value;
}

sub set_tuple_next_sorted_end($$){
    my ($tuple_ref,$value) = @_;

    $tuple_ref->{next_sorted} = $value;
}

# Print all chained lists in a human readable format
# arg : gantt ref
sub pretty_print($){
    my ($gantt) = @_;

    my $result = "All sorted by end date\n\n";
    my $indentation = "";
    my $current_tuple = $gantt->{sorted_root};
    #Follow the chain
    while (defined(get_tuple_begin_date($current_tuple))){
        $result .= $indentation."name = ".get_tuple_resource($current_tuple)."\n";
        $result .= $indentation."begin = ".get_tuple_begin_date($current_tuple)."\n";
        $result.= $indentation."end = ".get_tuple_end_date($current_tuple)."\n";
        $indentation .= "\t";
        $current_tuple = get_tuple_next_sorted_end($current_tuple);
    }
    
    $result .= "\nSame resource sorted\n\n";
    #Follow all chains for each resources
    foreach my $r (keys(%{$gantt->{resource_list}})){
        $indentation = "";
        $current_tuple = $gantt->{resource_list}->{$r};
        while (defined(get_tuple_begin_date($current_tuple))){
            $result .= $indentation."name = ".get_tuple_resource($current_tuple)."\n";
            $result .= $indentation."begin = ".get_tuple_begin_date($current_tuple)."\n";
            $result .= $indentation."end = ".get_tuple_end_date($current_tuple)."\n";
            $indentation .= "\t";
            $current_tuple = get_tuple_next_same_resource($current_tuple);
        }
        $result .= "\n";
    }
    return($result);
}


# Insert the already "allocated" tuple after the $previous_tuple in the same resource chain
# arg : previous tuple ref, tuple to insert after
sub add_resource_tuple_after($$){
  my ($previous_tuple_ref,$current_tuple_ref) = @_;

  $current_tuple_ref->{previous_resource} = $previous_tuple_ref;
  $current_tuple_ref->{next_resource} = $previous_tuple_ref->{next_resource};
  $current_tuple_ref->{next_resource}->{previous_resource} = $current_tuple_ref;
  $previous_tuple_ref->{next_resource} = $current_tuple_ref;
}

# Remove the tuple indicated by $tuple_ref in the same resource chain
# arg = tuple ref to remove
sub remove_resource_tuple($){
  my ($tuple_ref) = @_;

  my $previous_tuple = $tuple_ref->{previous_resource};
  my $next_tuple = $tuple_ref->{next_resource};
  $next_tuple->{previous_resource} = $previous_tuple;
  $previous_tuple->{next_resource} = $next_tuple;
}

# Insert the already "allocated" tuple after the $previous_tuple in the global sorted chain
# arg : previous tuple ref, tuple to insert after
sub add_sorted_tuple_end_after($$){
  my ($previous_tuple_ref,$current_tuple_ref) = @_;

  $current_tuple_ref->{previous_sorted} = $previous_tuple_ref;
  $current_tuple_ref->{next_sorted} = $previous_tuple_ref->{next_sorted};
  $current_tuple_ref->{next_sorted}->{previous_sorted} = $current_tuple_ref;
  $previous_tuple_ref->{next_sorted} = $current_tuple_ref;
}

# Remove the tuple indicated by $tuple_ref in the global sorted chain
# arg = tuple ref to remove
sub remove_sorted_end_tuple($){
  my ($tuple_ref) = @_;

  my $previous_tuple = $tuple_ref->{previous_sorted};
  my $next_tuple = $tuple_ref->{next_sorted};
  $next_tuple->{previous_sorted} = $previous_tuple;
  $previous_tuple->{next_sorted} = $next_tuple;
}

# Allocates a new tuple
# args : resource name, start busy slot date, end busy slot date
# return the new tuple
sub allocate_new_tuple($$$){
    my ($resource_name, $begin_date, $end_date) = @_;
    
    my $result_tuple = {};
    set_tuple_resource($result_tuple, $resource_name);
    set_tuple_begin_date($result_tuple, $begin_date);
    set_tuple_end_date($result_tuple, $end_date);

    set_tuple_previous_same_resource($result_tuple, undef);
    set_tuple_next_same_resource($result_tuple, undef);
    set_tuple_previous_sorted_end($result_tuple, undef);
    set_tuple_next_sorted_end($result_tuple, undef);

    return($result_tuple);
}

# Creates an empty Gantt
# arg : gantt reference date
sub new(){
    my $result = {
                    resource_list => {}
                 };
  
    return($result);
}


# Adds and initializes a new resource in the gantt chained list
# args : gantt ref, resource name
# return the tuple reference
sub add_new_resource($$) {
    my ($gantt, $resource_name) = @_;

    return(undef) if defined($gantt->{resource_list}->{$resource_name});
      
    my $t = allocate_new_tuple($resource_name, 0, 0);
    $gantt->{resource_list}->{$resource_name} = $t;

    if (!defined($gantt->{sorted_root})){
        $gantt->{sorted_root} = $t;
    }else{
        add_sorted_tuple_end_after($gantt->{sorted_root}, $t);
    }
    
    return($t);
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


# If we can fuse the tuple with the previous or/and the next, we do it.
# arg : tuple ref
sub fuse_tuple_if_we_can($){
    
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
    if ($begin_date > get_tuple_end_date(get_tuple_previous_same_resource($current_tuple))){
        return(1);
    }else{
        return(0);
    }
}


# Take a list of resoure trees and find a hole that fit
# args : gantt ref, initial time from which the search will begin, job duration, list of resource trees
sub find_first_hole($$$$){
    my ($gantt, $initial_time, $duration, $tree_description_list) = @_;

    # $tree_description_list->[0]  --> First resource group corresponding tree
    # $tree_description_list->[1]  --> Second resource group corresponding tree
    # ...

    my @result_tree_list = ();

    my $end_loop = 0;
    # Tuples sorted by begin date
    my $current_free_resources = sorted_chained_list::new();
    my $current_time = $initial_time;
    my $current_tuple = $gantt->{sorted_root};
    while ($end_loop == 0){
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

        #Remove current free resources with not enough time
        my $current_element = sorted_chained_list::get_next($current_free_resources);
        while ( defined(sorted_chained_list::get_value($current_element))
                && (sorted_chained_list::get_value($current_element) <= $current_time + $duration + 1)){
            sorted_chained_list::remove_element($current_free_resources,$current_element);
            $current_element = sorted_chained_list::get_next($current_element);
        }

        #print(sorted_chained_list::pretty_print($current_free_resources)."\n");

        #Get current free resource names and store it in a vector
        my $free_resources_vector = '';
        $current_element = sorted_chained_list::get_next($current_free_resources);
        while (defined(sorted_chained_list::get_value($current_element))){
            vec($free_resources_vector,get_tuple_resource(sorted_chained_list::get_stored_ref($current_element)),1) = 1;
            $current_element = sorted_chained_list::get_next($current_element);
        }
        
        #Check all trees
        my $tree_clone;
        my $i = 0;
        do{
            $tree_clone = oar_resource_tree::clone($tree_description_list->[$i]);
            #Remove tree leafs that are not free
            foreach my $l (oar_resource_tree::get_tree_leafs($tree_clone)){
                #print(oar_resource_tree::get_current_resource_value($l)."\n");
                if (!vec($free_resources_vector,oar_resource_tree::get_current_resource_value($l),1)){
                    #print("delete subtree $l\n");
                    oar_resource_tree::delete_subtree($l);
                }
            }
            $tree_clone = oar_resource_tree::delete_tree_nodes_with_not_enough_resources($tree_clone);
            #print(Dumper($tree_clone));
            $result_tree_list[$i] = $tree_clone;
            $i ++;
        }while(defined($tree_clone) && ($i <= $#{@{$tree_description_list}}));
        
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

    return($current_time, \@result_tree_list);
}

return 1;
