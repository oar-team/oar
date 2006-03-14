package sorted_chained_list;
require Exporter;
use warnings;
use strict;


# Creates an empty chained list
# returns the ref of an empty chained list
sub new(){
    return( {
                "value"      => undef,
                "stored_ref" => undef,
                "next"       => undef,
                "previous"   => undef,
                "counter"    => 0
            }
          );
}

# Get the ref stored in the element
# arg : element ref
# return a ref
sub get_stored_ref($){
    my ($element_ref) = @_;

    return($element_ref->{stored_ref});
}

# Get the value which describe the element
# arg : element ref
# return an integer or undef (means positive endless)
sub get_value($){
    my ($element_ref) = @_;
    
    return($element_ref->{value});
}

# Get the ref of the next sorted element
# arg : element ref
# return an element ref or undef
sub get_next($){
    my ($element_ref) = @_;

    return($element_ref->{next});
}

# Get the ref of the previous sorted element
# arg : element ref
# return an element ref
sub get_previous($){
    my ($element_ref) = @_;

    return($element_ref->{previous});
}


# Print all chained lists in a human readable format
# arg : chain ref
sub pretty_print($){
    my ($chain_ref) = @_;

    my $result = "Number of elements = $chain_ref->{counter}\n";
    my $indentation = "";
    my $current_element = get_next($chain_ref);
    #Follow the chain
    while (defined($current_element) && defined(get_value($current_element))){
        $result .= $indentation."value = ".get_value($current_element)."\n";
        $indentation .= "\t";
        $current_element = get_next($current_element);
    }

    return($result);
}

# Add an element in a chained list at the right sorted place
# args : chained list ref, reference value for the insertion, ref to store
# return the new crated element
sub add_element($$$){
    my ($chain_ref,$value,$ref) = @_;

    return(undef) if (!defined($value));

    $chain_ref->{counter} ++;
    my $new = {
        "value" => $value,
        "stored_ref" => $ref,
        "next" => undef,
        "previous" => undef
    };
    my $current_element = $chain_ref;
    while (defined(get_next($current_element)) && (!defined($value) || (defined(get_value(get_next($current_element))) && (get_value(get_next($current_element)) < $value)))){
        $current_element = get_next($current_element);
    }
    $new->{next} = $current_element->{next};
    $new->{previous} = $current_element;
    $current_element->{next} = $new;

    return($new);
}

# Remove an element from a chained list
# args : chained list ref, element ref to remove
sub remove_element($$){
    my ($chain_ref,$element_ref) = @_;

    $chain_ref->{counter} --;
    $element_ref->{previous}->{next} = $element_ref->{next};
    $element_ref->{next}->{previous} = $element_ref->{previous};
}

return 1;
