package oar_resource_tree;

use warnings;
use strict;
use Data::Dumper;
use Storable qw(dclone);

###############################################################################
#                       RESOURCE TREE MANAGEMENT                              #
###############################################################################

# Prototypes
sub new();
sub clone($);
sub add_child($$$);
sub get_children_list($);
sub get_a_child($$);
sub get_father($);
sub get_current_resource_name($);
sub get_current_resource_value($);
sub get_current_level($);
sub delete_subtree($);

sub get_tree_leaf($);
sub delete_tree_nodes_with_not_enough_resources($$);


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
    $tree_ref->[4] = 0 ;                # level indicator

    return($tree_ref);
}

# clone the tree
# arg : tree ref
# return a copy of the tree ref
sub clone($){
    my $tree_ref = shift;

    return(dclone($tree_ref));
}


# add a child to the given tree ref (if child resource name is undef it seems
# that this child is a leaf of the tree)
# arg : tree ref, resource value, child resource name or undef
# return the ref of the child
sub add_child($$$){
    my $tree_ref = shift;
    my $resource_name = shift;
    my $resource_value = shift;

    #$tree_ref->[2] = $resource_name;
    if (!defined($tree_ref->[1]->{$resource_value})){
        # Initialize value of the father
        $tree_ref->[1]->{$resource_value} = [ $tree_ref, undef, $resource_name, $resource_value, 0 ];
    }

    $tree_ref->[1]->{$resource_value}->[4] = get_current_level($tree_ref) + 1;

    return(\@{$tree_ref->[1]->{$resource_value}});
}


# Get an array with all children of the tree ref
# arg : tree ref
# return array of tree ref
sub get_children_list($){
    my $tree_ref = shift;

    if (!defined($tree_ref) || !defined($tree_ref->[1])){
        return(());
    }else{
        return(keys(%{$tree_ref->[1]}));
    }
}


# Get a specific child
# arg : tree ref, name of a child
# return a ref of a tree
sub get_a_child($$){
    my $tree_ref = shift;
    my $child_name = shift;

    if (!defined($tree_ref) || !defined($tree_ref->[1]) || !defined($tree_ref->[1]->{$child_name})){
        return(undef);
    }else{
        return($tree_ref->[1]->{$child_name});
    }
}

# Get the ref of the tree father
# arg : tree ref
# return a tree ref
sub get_father($){
    my $tree_ref = shift;

    if (!defined($tree_ref) || !defined($tree_ref->[0])){
        return(undef);
    }else{
        return($tree_ref->[0]);
    }
}


# Get the current resource name
# arg : tree ref
# return the resource name
sub get_current_resource_name($){
    my $tree_ref = shift;

    if (!defined($tree_ref) || !defined($tree_ref->[2])){
        return(undef);
    }else{
        return($tree_ref->[2]);
    }
}


# Get the current resource value
# arg : tree ref
# return the resource value
sub get_current_resource_value($){
    my $tree_ref = shift;

    if (!defined($tree_ref) || !defined($tree_ref->[3])){
        return(undef);
    }else{
        return($tree_ref->[3]);
    }
}


# Get the current level indicator
# arg : tree ref
# return the level indicator
sub get_current_level($){
    my $tree_ref = shift;

    if (!defined($tree_ref) || !defined($tree_ref->[4])){
        return(0);
    }else{
        return($tree_ref->[4]);
    }
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


# delete_tree_nodes_with_not_enough_resources
# Delete subtrees that do not fit wanted resources
# args: tree ref, corresponding wanted resources
# side effect : modify tree data structure
sub delete_tree_nodes_with_not_enough_resources($$){
    my $tree_ref = shift;
    my $wanted_resources_ref = shift;

    my @wanted_resources = @{$wanted_resources_ref};
    # Search if there are enough values for each resource
    # Tremaux algorithm
    my $current_node = $tree_ref;
    my %level_index;
    do{
        if (!defined($level_index{$current_node})){
            # Initialize index where we are for the node
            $level_index{$current_node} = 0;
        }
        my @child = sort(get_children_list($current_node));
        if ((defined($wanted_resources[get_current_level($current_node)])) && ($wanted_resources[get_current_level($current_node)]->{value} > ($#child + 1))){
            # Delete sub tree that does not fit with wanted resources 
            #print("Delete @child\n");
            my $tmp_current_node = get_father($current_node);
            my @tmp = sort(get_children_list($tmp_current_node));
            my $father_key_name = $tmp[$level_index{$tmp_current_node} - 1];
            if (!defined($father_key_name)){
                # No matching records (we want to delete the root)
                return(undef);
            }
            #print("Key father : $father_key_name\n");
            $current_node = $tmp_current_node;
            delete_subtree(get_a_child($current_node, $father_key_name));
            $level_index{$current_node} --;
        }else{
            if (defined($child[$level_index{$current_node}]) and defined(get_a_child($current_node, $child[$level_index{$current_node}]))){
                # Go to child
                #print("GO to  Child = $child[$level_index{$current_node}]\n");
                my $tmp_current_node = $current_node;
                $current_node = get_a_child($current_node, $child[$level_index{$current_node}]);
                $level_index{$tmp_current_node} ++;
            }else{
                # Treate leaf
                my @brothers = sort(get_children_list(get_father($current_node)));
                while(defined($current_node) and !defined($brothers[$level_index{get_father($current_node)}])){
                    $level_index{get_father($current_node)} ++ if defined(get_father($current_node));
                    $current_node = get_father($current_node);
                    @brothers = sort(get_children_list(get_father($current_node))) ;
                }
                if (defined(get_father($current_node)) &&  defined($brothers[$level_index{get_father($current_node)}])){
                    # Treate brother
                    #print("Treate brother $brothers[$level_index{$current_node->[0]}] \n");
                    $current_node = get_a_child(get_father($current_node), $brothers[$level_index{get_father($current_node)}]);
                    $level_index{get_father($current_node)} ++;
                }
            }
        }
    }while(defined($current_node));

#    return($tree_ref);
}


# get_tree_leaf
# return a list of tree leaf
# arg: tree ref
sub get_tree_leaf($){
    my $tree = shift;

    my @result;
    return(@result) if (!defined($tree));
    
    # Search leafs
    # Tremaux algorithm
    my $current_node = $tree;
    my %level_index;
    my @node_name_pile;
    do{
        if (!defined($level_index{$current_node})){
            # Initialize index where we are for the node
            $level_index{$current_node} = 0;
        }
        my @child = sort(get_children_list($current_node));
        if (defined($child[$level_index{$current_node}]) and defined(get_a_child($current_node, $child[$level_index{$current_node}]))){
            # Go to child
            #print("GO to  Child = $child[$level_index{$current_node}]\n");
            #unshift(@node_name_pile, $child[$level_index{$current_node}]);
            unshift(@node_name_pile, get_a_child($current_node, $child[$level_index{$current_node}]));
            my $tmp_current_node = $current_node;
            $current_node = get_a_child($current_node, $child[$level_index{$current_node}]);
            $level_index{$tmp_current_node} ++;
        }else{
            # Treate leaf
            if (!defined(get_a_child($current_node, $child[$level_index{$current_node}]))){
                push(@result, $node_name_pile[0]);
                #push(@result, $current_node);
                #print("Leaf: ".$node_name_pile[0]."\n");
            }
            # Look at brothers
            my @brothers = sort(get_children_list(get_father($current_node)));
            while(defined($current_node) and !defined($brothers[$level_index{get_father($current_node)}])){
                shift(@node_name_pile);
                $current_node = get_father($current_node);
                $level_index{$current_node} ++;
                @brothers = sort(get_children_list(get_father($current_node)));
            }
            if (defined($brothers[$level_index{get_father($current_node)}])){
                # Treate brother
                #unshift(@node_name_pile, $brothers[$level_index{get_father($current_node)}]);
                unshift(@node_name_pile, get_a_child(get_father($current_node), $brothers[$level_index{get_father($current_node)}]));
                #print("Treate brother $brothers[$level_index{$current_node->[0]}] \n");
                $current_node = get_a_child(get_father($current_node), $brothers[$level_index{get_father($current_node)}]);
                $level_index{get_father($current_node)} ++;
            }
        }
    }while(defined($current_node));

    return(@result);
}

return 1;
