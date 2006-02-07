package oar_tree;

use warnings;
use strict;
use Data::Dumper;

# Constants

# Prototypes
sub new();
sub add_child($$$);
sub get_children($);
sub get_a_child($$);
sub get_father($);
sub get_current_resource($);
sub delete_subtree($);


# Create a tree
# arg : name of the first resource
# return the ref of the created tree
sub new(){
    my $resource_name = shift;
    
    my $tree_ref;
    $tree_ref->[0] = undef ;            # father ref
    $tree_ref->[1] = undef ;            # ref of a hashtable with children
    $tree_ref->[2] = undef ;            # name of the resource
    $tree_ref->[3] = undef ;            # value of this resource

    return($tree_ref);
}


# add a child to the given tree ref (if child resource name is undef it seems
# that this child is a leaf of the tree)
# arg : tree ref, resource value, child resource name or undef
# return the ref of the child
sub add_child($$$){
    my $tree_ref = shift;
    my $resource_name = shift;
    my $resource_value = shift;

    $tree_ref->[2] = $resource_name;
    if (!defined($tree_ref->[1]->{$resource_value})){
        # Initialize value of the father
        $tree_ref->[1]->{$resource_value} = [ $tree_ref, undef, undef, $resource_value ];
    }

    return(\@{$tree_ref->[1]->{$resource_value}});
}


# Get an array with all children of the tree ref
# arg : tree ref
# return array of tree ref
sub get_children_list($){
    my $tree_ref = shift;

    return(keys(%{$tree_ref->[1]}));
}


# Get a specific child
# arg : tree ref, name of a child
# return a ref of a tree
sub get_a_child($$){
    my $tree_ref = shift;
    my $child_name = shift;

    return($tree_ref->[1]->{$child_name});
}

# Get the ref of the tree father
# arg : tree ref
# return a tree ref
sub get_father($){
    my $tree_ref = shift;

    return($tree_ref->[0]);
}


# Get the current resource name and value
# arg : tree ref
# return the resource name and value
sub get_current_resource($){
    my $tree_ref = shift;

    return($tree_ref->[2], $tree_ref->[3]);
}


# Delete a subtree
# arg : tree ref to delete
# return father tree ref
sub delete_subtree($){
    my $tree_ref = shift;
    
    my $father_ref = get_father($tree_ref);
    delete($father_ref->[1]->{$tree_ref->[3]});

    return($father_ref);
}

return 1;
