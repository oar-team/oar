package Gantt;
require Exporter;
use oar_Judas qw(oar_debug oar_warn oar_error);
use oar_resource_tree;
use Data::Dumper;
use warnings;
use strict;

# Prototypes
# gant chart management
sub new($);
sub add_new_resource($$);
sub set_occupation($$$$);
sub is_resource_free($$$$);
sub find_first_hole($$$);

# A gant chart is a 4 linked tuple list. Each tuple has got the reference of:
#   - previous free interval
#   - next free interval
#   - previous free interval for the same resource
#   - next free interval for the same resource

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

sub get_tuple_previous_sorted($){
    my ($tuple_ref) = @_;

    #Ref of a tuple
    return $tuple_ref->{previous_sorted}
}

sub get_tuple_next_sorted($){
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

sub set_tuple_previous_sorted($$){
    my ($tuple_ref,$value) = @_;

    $tuple_ref->{previous_sorted} = $value;
}

sub set_tuple_next_sorted($$){
    my ($tuple_ref,$value) = @_;

    $tuple_ref->{next_sorted} = $value;
}

sub pretty_print($){
    my ($gantt) = @_;

    my $result = "All sorted resources\n\n";
    my $indentation = "";
    my $current_tuple = $gantt->{sorted_root};
    while (defined(get_tuple_next_sorted($current_tuple))){
        $result .= $indentation."name = ".get_tuple_resource($current_tuple)."\n";
        $result .= $indentation."begin = ".get_tuple_begin_date($current_tuple)."\n";
        $result.= $indentation."end = ".get_tuple_end_date($current_tuple)."\n";
        $indentation .= "\t";
        $current_tuple = get_tuple_next_sorted($current_tuple);
    }
    
    $result .= "\nSame resource sorted\n\n";
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


# insert the already "allocated" tuple after the $prev_tuple
sub add_resource_tuple_after($$){
  my ($previous_tuple_ref,$current_tuple_ref) = @_;

  $current_tuple_ref->{previous_resource} = $previous_tuple_ref;
  $current_tuple_ref->{next_resource} = $previous_tuple_ref->{next_resource};
  $current_tuple_ref->{next_resource}->{previous_resource} = $current_tuple_ref;
  $previous_tuple_ref->{next_resource} = $current_tuple_ref;
}

# remove the tuple indicated by $current_tuple
sub remove_resource_tuple($){
  my ($tuple_ref) = @_;

  my $previous_tuple = $tuple_ref->{previous_resource};
  my $next_tuple = $tuple_ref->{next_resource};
  $next_tuple->{previous_resource} = $previous_tuple;
  $previous_tuple->{next_resource} = $next_tuple;
}

sub add_sorted_tuple_after($$){
  my ($previous_tuple_ref,$current_tuple_ref) = @_;

  $current_tuple_ref->{previous_sorted} = $previous_tuple_ref;
  $current_tuple_ref->{next_sorted} = $previous_tuple_ref->{next_sorted};
  $current_tuple_ref->{next_sorted}->{previous_sorted} = $current_tuple_ref;
  $previous_tuple_ref->{next_sorted} = $current_tuple_ref;
}

sub remove_sorted_tuple($){
  my ($tuple_ref) = @_;

  my $previous_tuple = $tuple_ref->{previous_sorted};
  my $next_tuple = $tuple_ref->{next_sorted};
  $next_tuple->{previous_sorted} = $previous_tuple;
  $previous_tuple->{next_sorted} = $next_tuple;
}

#Allocates a new tuple
sub allocate_new_tuple($$$){
    my ($resource_name, $begin_date, $end_date) = @_;
    
    my $result_tuple = {};
    set_tuple_resource($result_tuple, $resource_name);
    set_tuple_begin_date($result_tuple, $begin_date);
    set_tuple_end_date($result_tuple, $end_date);

    set_tuple_previous_same_resource($result_tuple, undef);
    set_tuple_next_same_resource($result_tuple, undef);
    set_tuple_previous_sorted($result_tuple, undef);
    set_tuple_next_sorted($result_tuple, undef);

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


# Insert in the gantt chained list a new occupation time slot
# args : gantt ref, start slot date, slot duration, resource name
sub set_occupation($$$$){
    my ($gantt, $date, $duration, $resource_name) = @_;
  
    add_new_resource($gantt,$resource_name);
  
    my $new_tuple = allocate_new_tuple($resource_name, $date, $date + $duration);
    my $current_tuple = $gantt->{resource_list}->{$resource_name};
    while (defined(get_tuple_begin_date(get_tuple_next_same_resource($current_tuple))) && ($date > get_tuple_begin_date(get_tuple_next_same_resource($current_tuple)))){
        $current_tuple = get_tuple_next_same_resource($current_tuple);
    }
    add_resource_tuple_after($current_tuple, $new_tuple);

    $current_tuple = $gantt->{sorted_root};
    while (defined(get_tuple_begin_date(get_tuple_next_sorted($current_tuple))) && ($date > get_tuple_begin_date(get_tuple_next_sorted($current_tuple)))){
        $current_tuple = get_tuple_next_sorted($current_tuple);
    }
    add_sorted_tuple_after($current_tuple, $new_tuple);
    
    return($new_tuple);
}


# Returns 1 if the specified time slot is empty for the given resource. Otherwise it returns 0
# args : gantt ref, start date, duration, resource name
sub is_resource_free($$$$){
    my ($gantt, $begin_date, $duration, $resource_name) = @_;

    if (!defined($gantt->{resource_list}->{$resource_name})){
        return(0);
    }
    my $end_date = $begin_date + $duration;
    my $old_tuple = $gantt->{resource_list}->{$resource_name};
    my $current_tuple = get_tuple_next_same_resource($old_tuple);
    while (defined(get_tuple_begin_date($current_tuple)) && !($begin_date > get_tuple_end_date(get_tuple_previous_sorted($current_tuple)) && $end_date < get_tuple_begin_date($current_tuple))){
        $old_tuple = $current_tuple;
        $current_tuple = get_tuple_next_same_resource($current_tuple);
    }
    if ($begin_date > get_tuple_end_date($old_tuple)){
        return(1);
    }else{
        return(0);
    }
}


#
sub find_first_hole($$$){
    my ($gantt, $duration, $tree_description_list) = @_;

    # $tree_description_list->[0]->{resources}->[0]->{resource}
    # $tree_description_list->[0]->{resources}->[0]->{value}
    # $tree_description_list->[0]->{tree}
    # ...

    my $result = [undef, undef]; # Date + resource list

    # Calculate the minimum number of needed resources (speed up the tests)
    my $minimum_resource_number = 0;
    foreach my $i (@{$tree_description_list}){
        my $tmp = 1;
        foreach my $r (@{$i->{resources}}){
            print("TT".Dumper($r));
            $tmp = $tmp * $r->{value};
            print("res : $r->{resource} --> $r->{value}\n");
        }
        $minimum_resource_number += $tmp;
    }
    print("$minimum_resource_number\n"); 
    my $current_time = $gantt->{now_date};
    
}

return 1;
