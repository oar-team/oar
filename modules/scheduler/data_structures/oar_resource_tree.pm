# $Id$
package oar_resource_tree;

use warnings;
use strict;
use Data::Dumper;
use Storable qw(dclone);
use Time::HiRes qw(gettimeofday);

###############################################################################
#                       RESOURCE TREE MANAGEMENT                              #
###############################################################################

# Prototypes
sub new();
sub clone($);
sub add_child($$$);
sub get_children_list($);
sub is_node_a_leaf($);
sub get_a_child($$);
sub get_father($);
sub get_current_resource_name($);
sub get_current_resource_value($);
sub get_current_children_number($);
sub get_current_level($);
sub get_max_available_children($);
sub set_needed_children_number($$);
sub get_needed_children_number($);
sub delete_subtree($);
sub get_previous_brother($);
sub get_next_brother($);
sub get_initial_child($);


###############################################################################

sub get_tree_leafs($);
sub delete_tree_nodes_with_not_enough_resources($);
sub delete_unnecessary_subtrees($);

###############################################################################

# Create a tree
# arg : number of needed children
# return the ref of the created tree
sub new(){
    my $needed_children_number = shift;
    
    my $tree_ref;
    $tree_ref->[0] = undef ;                    # father ref
    $tree_ref->[1] = undef ;                    # ref of a hashtable with children
    $tree_ref->[2] = undef ;                    # name of the resource
    $tree_ref->[3] = undef ;                    # value of this resource
    $tree_ref->[4] = 0 ;                        # level indicator
    $tree_ref->[5] = 0 ;                        # needed children number :
                                                #   -1 means ALL (Alive + Absent + Suspected resources)
                                                #   -2 means BEST (Alive resources at the time)
    $tree_ref->[6] = 0 ;                        # maximum available children
    $tree_ref->[7] = undef ;                    # previous brother ref
    $tree_ref->[8] = undef ;                    # next brother ref
    $tree_ref->[9] = undef ;                    # first child ref
    $tree_ref->[10] = 0 ;                       # current children number


    return($tree_ref);
}

# clone the tree
# arg : tree ref
# return a copy of the tree ref
sub clone($){
  my $tree_ref = shift;
  return(dclone($tree_ref));
}


# return 1 if node is a leaf (no child)
# otherwise retuurn 0
sub is_node_a_leaf($){
    my $tree_ref = shift;

    if (defined($tree_ref->[1])){
        return(0);
    }else{
        return(1);
    }
}

# add a child to the given tree ref (if child resource name is undef it seems
# that this child is a leaf of the tree)
# arg : tree ref, resource name, resource value
# return the ref of the child
sub add_child($$$){
    my $tree_ref = shift;
    my $resource_name = shift;
    my $resource_value = shift;

    my $tmp_ref;
    if (!defined($tree_ref->[1]->{$resource_value})){
        # Create a new tree node
        $tmp_ref = [ $tree_ref, undef, $resource_name, $resource_value, $tree_ref->[4] + 1, 0, 0, undef, undef, undef, 0];
        
        $tree_ref->[1]->{$resource_value} = $tmp_ref;
        $tree_ref->[6] = $tree_ref->[6] + 1;
        $tree_ref->[10] = $tree_ref->[10] + 1;

        # Add new brother
        if (defined($tree_ref->[9])){
            $tmp_ref->[8] = $tree_ref->[9];
            $tree_ref->[9]->[7] = $tmp_ref;
        }
        $tree_ref->[9] = $tmp_ref;
    }else{
        $tmp_ref = $tree_ref->[1]->{$resource_value};
    }
    
    return($tmp_ref);
}

# Store information about the number of needed children
sub set_needed_children_number($$){
    my $tree_ref = shift;
    my $needed_children_number = shift;

    $tree_ref->[5] = $needed_children_number;
}


# Get previous brother on the same level for the same father
sub get_previous_brother($){
    my $tree_ref = shift;

    if (!defined($tree_ref)){
        return(undef);
    }else{
        return($tree_ref->[7]);
    }
}


# Get next brother on the same level for the same father
sub get_next_brother($){
    my $tree_ref = shift;

    if (!defined($tree_ref)){
        return(undef);
    }else{
        return($tree_ref->[8]);
    }
}


# Get initial child ref
sub get_initial_child($){
    my $tree_ref = shift;

    if (!defined($tree_ref)){
        return(undef);
    }else{
        return($tree_ref->[9]);
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

# Get the ref of the father tree
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


# Get the current children number
# arg : tree ref
# return the resource value
sub get_current_children_number($){
    my $tree_ref = shift;

    if (!defined($tree_ref) || !defined($tree_ref->[10])){
        return(undef);
    }else{
        return($tree_ref->[10]);
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


# Get the maximum available number of children
# (just after the creation of the tree)
# arg : tree ref
# return an integer >= 0
sub get_max_available_children($){
    my $tree_ref = shift;
    
    if (!defined($tree_ref) || !defined($tree_ref->[6])){
        return(0);
    }else{
        return($tree_ref->[6]);
    }
}


# Get the number of needed children
# arg : tree ref
# return the number of needed children
sub get_needed_children_number($){
    my $tree_ref = shift;

    if (!defined($tree_ref) || !defined($tree_ref->[5])){
        return(0);
    }else{
        return($tree_ref->[5]);
    }
}


# Delete a subtree
# arg : tree ref to delete
# return father tree ref
sub delete_subtree($){
    my $tree_ref = shift;
    
    return(undef) if (!defined($tree_ref));

    my $father_ref = $tree_ref->[0];

    my $prev_brother = $tree_ref->[7];
    my $next_brother = $tree_ref->[8];

    if (!defined($prev_brother)){
        if (defined($father_ref)){
            $father_ref->[9] = $next_brother;
        }
    }else{
        $prev_brother->[8] = $next_brother;
    }

    if (defined($next_brother)){
        $next_brother->[7] = $prev_brother;
    }
    
    if (defined($father_ref->[1])){
        delete($father_ref->[1]->{$tree_ref->[3]});
        $father_ref->[10] = $father_ref->[10] - 1;
        return($father_ref);
    }else{
        return(undef);
    }
}

###############################################################################

# delete_tree_nodes_with_not_enough_resources
# Delete subtrees that do not fit wanted resources
# args: tree ref
# side effect : modify tree data structure
sub delete_tree_nodes_with_not_enough_resources($){
    my $tree_ref = shift;

    #print("START delete_tree_nodes_with_not_enough_resources\n");
    # Search if there are enough values for each resource
    # Tremaux algorithm (Deep first)
    my $current_node = $tree_ref;
    do{
        if ((get_needed_children_number($current_node) > get_current_children_number($current_node))
            or ((get_needed_children_number($current_node) == -1)                # ALL
                and (get_max_available_children($current_node) > get_current_children_number($current_node)))
            or ((get_needed_children_number($current_node) == -2)                # BEST
                and (get_current_children_number($current_node) <= 0))
        ){
            # we want to delete the root
            return(undef) if ($tree_ref == $current_node);
            # Delete sub tree that does not fit with wanted resources 
            #print("DELETE ".get_current_resource_value($current_node)."\n");
            $current_node = delete_subtree($current_node);
        }
        if (defined(get_initial_child($current_node))){
            # Go to child
            $current_node = get_initial_child($current_node);
            #print("Go to CHILD =".get_current_resource_value($current_node)."\n");
        }else{
            # Treate leaf
            while(defined($current_node) and (!defined(get_father($current_node)) or !defined(get_next_brother($current_node)))){
                # Step up
                #print("TOTO ".get_current_children_number($current_node)."\n");
                #print("Go to FATHER : ".get_current_resource_value($current_node)."\n") if (defined(get_current_resource_value($current_node)));
                if ((get_needed_children_number($current_node) > get_current_children_number($current_node))
                    or ((get_needed_children_number($current_node) == -1)                # ALL
                        and (get_max_available_children($current_node) > get_current_children_number($current_node)))
                    or ((get_needed_children_number($current_node) == -2)                # BEST
                        and (get_current_children_number($current_node) <= 0))
                ){
                    # we want to delete the root
                    return(undef) if ($tree_ref == $current_node);
                    #print("DELETE 1".get_current_resource_value($current_node)."\n");
                    # Delete sub tree that does not fit with wanted resources 
                    $current_node = delete_subtree($current_node);
                }else{
                    $current_node = get_father($current_node);
                }
            }
            if (defined(get_father($current_node)) and defined(get_next_brother($current_node))){
                # Treate brother
                my $brother_node = get_next_brother($current_node);
                if ((get_needed_children_number($current_node) > get_current_children_number($current_node))
                    or ((get_needed_children_number($current_node) == -1)                # ALL
                        and (get_max_available_children($current_node) > get_current_children_number($current_node)))
                    or ((get_needed_children_number($current_node) == -2)                # BEST
                        and (get_current_children_number($current_node) <= 0))
                ){
                    #print("DELETE 2".get_current_resource_value($current_node)."\n");
                    # Delete sub tree that does not fit with wanted resources 
                    delete_subtree($current_node);
                }
                $current_node = $brother_node;
                #print("Go to BROTHER : ".get_current_resource_value($current_node)."\n");
            }
        }
    }while(defined($current_node));

    if (!defined(get_initial_child($tree_ref))){
        return(undef);
    }else{
        return($tree_ref);
    }
}


# get_tree_leaf
# return a list of tree leaf
# arg: tree ref
sub get_tree_leafs($){
    my $tree = shift;

    my @result;
    return(@result) if (!defined($tree));
    
    # Search leafs
    # Tremaux algorithm (Deep first)
    my $current_node = $tree;
    do{
        if (defined(get_initial_child($current_node))){
            # Go to child
            $current_node = get_initial_child($current_node);
            #print("Go to CHILD =".get_current_resource_value($current_node)."\n");
        }else{
            # Treate leaf
            if (is_node_a_leaf($current_node) == 1){
                #push(@result, $node_name_pile[0]);
                push(@result, $current_node);
                #print("Leaf: ".get_current_resource_value($current_node)."\n");
            }
            # Look at brothers
            while(defined($current_node) and (!defined(get_father($current_node)) or !defined(get_next_brother($current_node)))){
                # Step up
                $current_node = get_father($current_node);
                #print("Go to FATHER : ".get_current_resource_value($current_node)."\n") if (defined(get_current_resource_value($current_node)));
            }
            if (defined(get_father($current_node)) and defined(get_next_brother($current_node))){
                # Treate brother
                $current_node = get_next_brother($current_node);
                #print("Go to BROTHER : ".get_current_resource_value($current_node)."\n");
            }
        }
    }while(defined($current_node));

    return(@result);
}


# delete_unnecessary_subtrees
# Delete subtrees that are not necessary (watch needed_children_number)
# args: tree ref
# side effect : modify tree data structure
sub delete_unnecessary_subtrees($){
    my $tree_ref = shift;

    return($tree_ref) if (!defined($tree_ref));

    # Search if there are enough values for each resource
    # Tremaux algorithm (Deep first)
    my $current_node = $tree_ref;
    do{
        if ((get_needed_children_number($current_node) >= 0) and (get_needed_children_number($current_node) < (get_current_children_number($current_node)))){
            # Delete extra sub tree
            delete_subtree(get_initial_child($current_node));
        }else{
            if (defined(get_initial_child($current_node))){
                # Go to child
                $current_node = get_initial_child($current_node);
                #print("Go to CHILD =".get_current_resource_value($current_node)."\n");
            }else{
                # Look at brothers
                while(defined($current_node) and (!defined(get_father($current_node)) or !defined(get_next_brother($current_node)))){
                    # Step up
                    $current_node = get_father($current_node);
                    #print("Go to FATHER : ".get_current_resource_value($current_node)."\n") if (defined(get_current_resource_value($current_node)));
                }
                if (defined(get_father($current_node)) and defined(get_next_brother($current_node))){
                    # Treate brother
                    $current_node = get_next_brother($current_node);
                    #print("Go to BROTHER : ".get_current_resource_value($current_node)."\n");
                }
            }
        }
    }while(defined($current_node));

    return($tree_ref);
}
return 1;
