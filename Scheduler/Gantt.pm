package Gantt;
require Exporter;
use oar_Judas qw(oar_debug oar_warn oar_error);
use oar_resource_tree;
use Data::Dumper;
use warnings;
use strict;

# Note : All dates are in seconds

# Prototypes
# gant chart management
sub new($);
sub add_new_resource($$);
sub set_occupation($$$$);
sub is_resource_free($$$$);
sub find_first_hole($$$);

# A gantt chart is a 4 linked tuple list. Each tuple has got the reference to:
#   - previous end busy interval (last end occupation)
#   - next end busy interval (next end occupation)
#   - previous busy interval for the same resource
#   - next busy interval for the same resource

sub get_tuple_resource($){
    my ($tuple_ref) = @_;

    #Name of the resource
    return $tuple_ref->{resource};
}

sub get_tuple_begin_date($){
    my ($tuple_ref) = @_;
    
    # Date in seconds
    return $tuple_ref->{begin_date};
}

sub get_tuple_end_date($){
    my ($tuple_ref) = @_;

    #Date in seconds
    return $tuple_ref->{end_date};
}

sub get_tuple_previous_same_resource($){
    my ($tuple_ref) = @_;

    #Ref of a tuple
    return $tuple_ref->{previous_resource};
}

sub get_tuple_next_same_resource($){
    my ($tuple_ref) = @_;
    
    #Ref of a tuple
    return $tuple_ref->{next_resource};
}

sub get_tuple_previous_sorted_end($){
    my ($tuple_ref) = @_;

    #Ref of a tuple
    return $tuple_ref->{previous_sorted}
}

sub get_tuple_next_sorted_end($){
    my ($tuple_ref) = @_;

    #Ref of a tuple
    return $tuple_ref->{next_sorted}
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

    my $result = "All sortedby end date\n\n";
    my $indentation = "";
    my $current_tuple = $gantt->{sorted_root};
    #Follow the chain
    while (defined(get_tuple_next_sorted_end($current_tuple))){
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
        while (defined(get_tuple_next_same_resource($current_tuple))){
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
sub new($){
    my ($now) = @_;
    
    my $result = {
                    now_date => $now,
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
    while (defined(get_tuple_begin_date(get_tuple_next_same_resource($current_tuple))) && ($date > get_tuple_begin_date(get_tuple_next_same_resource($current_tuple)))){
        $current_tuple = get_tuple_next_same_resource($current_tuple);
    }
    add_resource_tuple_after($current_tuple, $new_tuple);

    $current_tuple = $gantt->{sorted_root};
    # Search the good position in the global resource chained list
    while (defined(get_tuple_begin_date(get_tuple_next_sorted_end($current_tuple))) && ($date + $duration > get_tuple_end_date(get_tuple_next_sorted_end($current_tuple)))){
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

    if (!defined($gantt->{resource_list}->{$resource_name})){
        #This resource name was not initialized; use add_new_resource before
        return(0);
    }
    my $end_date = $begin_date + $duration;
    my $current_tuple = get_tuple_next_same_resource($gantt->{resource_list}->{$resource_name});
    #Search between which tuples is this interval
    while (defined(get_tuple_begin_date($current_tuple)) && !($begin_date > get_tuple_end_date(get_tuple_previous_same_resource($current_tuple)) && $end_date < get_tuple_begin_date($current_tuple))){
        $current_tuple = get_tuple_next_same_resource($current_tuple);
    }
    if ($begin_date > get_tuple_end_date(get_tuple_previous_same_resource($current_tuple))){
        return(1);
    }else{
        return(0);
    }
}


#
sub find_first_hole($$$){
    my ($gantt, $duration, $tree_description_list) = @_;

    # $tree_description_list->[0]  --> First resource group corresponding tree
    # $tree_description_list->[1]  --> Second resource group corresponding tree
    # ...

    my @current_free_resources;
    my $current_time = $gantt->{now_date};
    my $current_tuple = $gantt->{sorted_root};
    while (defined($current_tuple) && ($current_time <= get_tuple_end_date($current_tuple))){
        #Insert tuple in the free current resources arry at the good place
        
        my $i = 0;
        while(($i <= $#current_free_resources) && ($current_free_resources[$i]->[0] < ){
            
        }
        $current_time = get_tuple_end_date($current_tuple);
        $current_tuple = get_tuple_next_sorted_end($current_tuple);
    }
}

return 1;
