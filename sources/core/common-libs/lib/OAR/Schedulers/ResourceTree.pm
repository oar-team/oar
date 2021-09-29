# $Id$
package OAR::Schedulers::ResourceTree;

use warnings;
use strict;
#use Data::Dumper;
use OAR::Conf qw(get_conf_with_default_param);
use Storable qw(dclone);
#use Time::HiRes qw(gettimeofday);

$Storable::recursion_limit = get_conf_with_default_param("STORABLE_RECURSION_LIMIT",-1);
$Storable::recursion_limit_hash = get_conf_with_default_param("STORABLE_RECURSION_LIMIT",-1);

###############################################################################
#                       RESOURCE TREE MANAGEMENT                              #
###############################################################################

# Prototypes
sub new();
sub destroy($);
sub clone($);
sub add_child($$$$);
sub get_children_list($);
sub is_node_a_leaf($);
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
sub get_last_child($);


###############################################################################

sub get_tree_leafs($);
sub get_tree_leafs_vec($);
sub delete_tree_nodes_with_not_enough_resources($);
sub delete_unnecessary_subtrees($);
sub delete_tree_nodes_with_not_enough_resources_and_unnecessary_subtrees($$);

###############################################################################

# Create a tree
# arg: number of needed children
# return the ref of the created tree
sub new(){
    my $tree_ref;
    $tree_ref->[0] = undef ;                    # father ref
    $tree_ref->[1] = undef ;                    # ref of a hashtable with all initial children
    $tree_ref->[2] = undef ;                    # name of the resource
    $tree_ref->[3] = undef ;                    # value of this resource
    $tree_ref->[4] = 0 ;                        # level indicator
    $tree_ref->[5] = 0 ;                        # needed children number:
                                                #   -1 means ALL (Alive + Absent + Suspected resources)
                                                #   -2 means BEST (Alive resources at the time)
    $tree_ref->[6] = 0 ;                        # maximum available children
    $tree_ref->[7] = undef ;                    # previous brother ref
    $tree_ref->[8] = undef ;                    # next brother ref
    $tree_ref->[9] = undef ;                    # first child ref
    $tree_ref->[10] = 0 ;                       # current children number
    $tree_ref->[11] = undef ;                   # last child ref
    $tree_ref->[12] = [] ;                      # array with all tree node refs (only on the first tree node)

    return($tree_ref);
}

# Destroy data structure and tell Perl that the corresponding memory can be
# reused
# arg: ROOT tree ref
sub destroy($){
    my $tree_ref = shift;

    if (defined($tree_ref->[12])){
        foreach my $n (@{$tree_ref->[12]}){
            undef(@{$n});
            undef($n);
        }
        undef(@{$tree_ref});
        undef($tree_ref);
    }
}

# clone the tree
# arg: tree ref
# return a copy of the tree ref
sub clone($){
  my $tree_ref = shift;
  return(dclone($tree_ref));
}


# return 1 if node is a leaf (no child)
# otherwise retuurn 0
sub is_node_a_leaf($){
    my $tree_ref = shift;

    if ($tree_ref and $tree_ref->[9]){
        return(0);
    }else{
        return(1);
    }
}

# add a child to the given tree ref (if child resource name is undef it seems
# that this child is a leaf of the tree)
# arg: tree ref, resource name, resource value, tree root ref
# return the ref of the child
sub add_child($$$$){
    my $tree_ref = shift;
    my $resource_name = shift;
    my $resource_value = shift;
    my $tree_root_ref = shift;   # First node of the tree

    $resource_value = "" if (!defined($resource_value));
    my $tmp_ref;
    if (!defined($tree_ref->[1]->{$resource_value})){
        # Create a new tree node
        $tmp_ref = [ $tree_ref, undef, $resource_name, $resource_value, $tree_ref->[4] + 1, 0, 0, undef, undef, undef, 0, undef ];
        push(@{$tree_root_ref->[12]}, $tmp_ref);
        
        $tree_ref->[1]->{$resource_value} = $tmp_ref;
        $tree_ref->[6] += 1;
        $tree_ref->[10] += 1;

        # Add new brother
        if ($tree_ref->[9]){
            $tmp_ref->[8] = $tree_ref->[9];
            $tree_ref->[9]->[7] = $tmp_ref;
        }
        $tree_ref->[9] = $tmp_ref;
        # Init last child
        if (!$tree_ref->[11]){
            $tree_ref->[11] = $tmp_ref;
        }
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

    if (!$tree_ref){
        return(undef);
    }else{
        return($tree_ref->[7]);
    }
}


# Get next brother on the same level for the same father
sub get_next_brother($){
    my $tree_ref = shift;

    if (! $tree_ref){
        return(undef);
    }else{
        return($tree_ref->[8]);
    }
}


# Get initial child ref
sub get_initial_child($){
    my $tree_ref = shift;

    if (! $tree_ref){
        return(undef);
    }else{
        return($tree_ref->[9]);
    }
}


# Get last child ref
sub get_last_child($){
    my $tree_ref = shift;

    if (! $tree_ref){
        return(undef);
    }else{
        return($tree_ref->[11]);
    }
}


# Get the ref of the father tree
# arg: tree ref
# return a tree ref
sub get_father($){
    my $tree_ref = shift;

    if (!$tree_ref || !$tree_ref->[0]){
        return(undef);
    }else{
        return($tree_ref->[0]);
    }
}


# Get the current resource name
# arg: tree ref
# return the resource name
sub get_current_resource_name($){
    my $tree_ref = shift;

    if (! $tree_ref){
        return(undef);
    }else{
        return($tree_ref->[2]);
    }
}


# Get the current resource value
# arg: tree ref
# return the resource value
sub get_current_resource_value($){
    my $tree_ref = shift;

    if (! $tree_ref){
        return(undef);
    }else{
        return($tree_ref->[3]);
    }
}


# Get the current children number
# arg: tree ref
# return the resource value
sub get_current_children_number($){
    my $tree_ref = shift;

    if ($tree_ref){
        return($tree_ref->[10]);
    }else{
        return(undef);
    }
}


# Get the current level indicator
# arg: tree ref
# return the level indicator
sub get_current_level($){
    my $tree_ref = shift;

    if ($tree_ref){
        return($tree_ref->[4]);
    }else{
        return(0);
    }
}


# Get the maximum available number of children
# (just after the creation of the tree)
# arg: tree ref
# return an integer >= 0
sub get_max_available_children($){
    my $tree_ref = shift;
    
    if ($tree_ref){
        return($tree_ref->[6]);
    }else{
        return(0);
    }
}


# Get the number of needed children
# arg: tree ref
# return the number of needed children
sub get_needed_children_number($){
    my $tree_ref = shift;

    if ($tree_ref){
        return($tree_ref->[5]);
    }else{
        return(0);
    }
}


# Delete a subtree
# arg: tree ref to delete
# return father tree ref
sub delete_subtree($){
    my $tree_ref = shift;
    
    return(undef) if (! $tree_ref);

    my $father_ref = $tree_ref->[0];

    my $prev_brother = $tree_ref->[7];
    my $next_brother = $tree_ref->[8];

    if (! $prev_brother){
        if ($father_ref){
            $father_ref->[9] = $next_brother;   # update father first child
        }
    }else{
        $prev_brother->[8] = $next_brother;     # update next brother
    }

    if (! $next_brother){
        if ($father_ref){
            $father_ref->[11] = $prev_brother;  # update father last child
        }
    }else{
        $next_brother->[7] = $prev_brother;     # update previous brother
    }
    
    if ($father_ref and $father_ref->[1]){
        $father_ref->[10] -= 1;
        return($father_ref);
    }else{
        return(undef);
    }
}

###############################################################################

# delete_tree_nodes_with_not_enough_resources
# Delete subtrees that do not fit wanted resources
# args: tree ref
# side effect: modify tree data structure
sub delete_tree_nodes_with_not_enough_resources($){
    my $tree_ref = shift;

    #print("START delete_tree_nodes_with_not_enough_resources\n");
    # Search if there are enough values for each resource
    # Tremaux algorithm (Deep first)
    my $current_node = $tree_ref;
    do{
        if (defined(get_initial_child($current_node))){
            # Go to child
            $current_node = get_initial_child($current_node);
            #print("Go to CHILD =".get_current_resource_value($current_node)."\n");
        }else{
            # Treate leaf
            while(defined($current_node) and (!defined(get_next_brother($current_node)))){
                # Step up
                #print("Go to FATHER: ".get_current_resource_value($current_node)."\n") if (defined(get_current_resource_value($current_node)));
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
            if (defined(get_next_brother($current_node))){
                # Treate brother
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
                $current_node = get_next_brother($current_node);
                #print("Go to BROTHER: ".get_current_resource_value($current_node)."\n");
            }
        }
    }while(defined($current_node));

    if (!defined(get_initial_child($tree_ref))){
        return(undef);
    }else{
        return($tree_ref);
    }
}


# get_tree_leafs
# return a list of tree leafs
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
                #print("Leaf: ".get_current_resource_name($current_node)." = ".get_current_resource_value($current_node)."\n");
            }
            # Look at brothers
            while(defined($current_node) and (!defined(get_next_brother($current_node)))){
                # Step up
                $current_node = get_father($current_node);
                #print("Go to FATHER: ".get_current_resource_value($current_node)."\n") if (defined(get_current_resource_value($current_node)));
            }
            if (defined(get_next_brother($current_node))){
                # Treate brother
                $current_node = get_next_brother($current_node);
                #print("Go to BROTHER: ".get_current_resource_value($current_node)."\n");
            }
        }
    }while(defined($current_node));

    return(@result);
}

# get_tree_leafs_vec
# return a binary vector with the leaf resource_id AND a hashref with resource_id => tree_ref
# arg: root tree ref
sub get_tree_leafs_vec($){
    my $tree = shift;

    my $result_leafs_vec = '';
    my %result_leafs_hash = ();
    return($result_leafs_vec, \%result_leafs_hash) if (!$tree);
    
    # Search leafs
    # Tremaux algorithm (Deep first)
    my $current_node = $tree;
    do{
        if (get_initial_child($current_node)){
            # Go to child
            $current_node = get_initial_child($current_node);
            #print("Go to CHILD =".get_current_resource_value($current_node)."\n");
        }else{
            # Treate leaf
            if (is_node_a_leaf($current_node) == 1){
                vec($result_leafs_vec, get_current_resource_value($current_node), 1) = 1;
                $result_leafs_hash{get_current_resource_value($current_node)} = $current_node;
                #print("Leaf: ".get_current_resource_name($current_node)." = ".get_current_resource_value($current_node)."\n");
            }
            # Look at brothers
            while($current_node and (!get_next_brother($current_node))){
                # Step up
                $current_node = get_father($current_node);
                #print("Go to FATHER: ".get_current_resource_value($current_node)."\n") if (defined(get_current_resource_value($current_node)));
            }
            if (get_next_brother($current_node)){
                # Treate brother
                $current_node = get_next_brother($current_node);
                #print("Go to BROTHER: ".get_current_resource_value($current_node)."\n");
            }
        }
    }while($current_node);

    return($result_leafs_vec, \%result_leafs_hash);
}

# delete_unnecessary_subtrees
# Delete subtrees that are not necessary (watch needed_children_number)
# args: tree ref
# side effect: modify tree data structure
sub delete_unnecessary_subtrees($){
    my $tree_ref = shift;

    return($tree_ref) if (!defined($tree_ref));

    # Search if there are enough values for each resource
    # Tremaux algorithm (Deep first)
    my $current_node = $tree_ref;
    do{
        if ((get_needed_children_number($current_node) >= 0) and (get_needed_children_number($current_node) < get_current_children_number($current_node))){
            # Delete extra sub tree
            delete_subtree(get_initial_child($current_node));
        }else{
            if (defined(get_initial_child($current_node))){
                # Go to child
                $current_node = get_initial_child($current_node);
                #print("Go to CHILD =".get_current_resource_value($current_node)."\n");
            }else{
                # Look at brothers
                while(defined($current_node) and (!defined(get_next_brother($current_node)))){
                    # Step up
                    $current_node = get_father($current_node);
                    #print("Go to FATHER: ".get_current_resource_value($current_node)."\n") if (defined(get_current_resource_value($current_node)));
                }
                if (defined(get_next_brother($current_node))){
                    # Treate brother
                    $current_node = get_next_brother($current_node);
                    #print("Go to BROTHER: ".get_current_resource_value($current_node)."\n");
                }
            }
        }
    }while(defined($current_node));

    return($tree_ref);
}

# delete_tree_nodes_with_not_enough_resources_and_unnecessary_subtrees
# Delete subtrees that do not fit wanted resources and unnecessary one
# args: tree ref, bit vector with authorized leafs (resource_id)
# side effect: modify tree data structure
sub delete_tree_nodes_with_not_enough_resources_and_unnecessary_subtrees($$){
    my $tree_ref = shift;
    my $authorized_leafs_vec = shift;   # if undef then all resources are authorized

#    print("START delete_tree_nodes_with_not_enough_resources\n");

    # Record the current number of children that can be taken
    my %nb_children_validated;
    # Search if there are enough values for each resource
    # Tremaux algorithm (Deep first)
    my $current_node = $tree_ref;
    do{
        if (get_last_child($current_node)){
            # Go to child
            $nb_children_validated{$current_node} = 0;
            $current_node = get_last_child($current_node);
#            print("Go to CHILD: ".get_current_resource_name($current_node)."=".get_current_resource_value($current_node)."\n");
        }else{
            # Treate leaf
            if (defined($authorized_leafs_vec)
                and (is_node_a_leaf($current_node) == 1)
                and ($tree_ref != $current_node)
                and (get_current_resource_name($current_node) eq "resource_id")
                and (!vec($authorized_leafs_vec, get_current_resource_value($current_node), 1))
               ){
#                    print("DELETE LEAF: ".get_current_resource_name($current_node)."=".get_current_resource_value($current_node)."\n");
                    # This leaf is not available
                    my $tmp_prev = get_previous_brother($current_node);
                    $current_node = delete_subtree($current_node);
                    if ($tmp_prev){
                        $current_node = $tmp_prev;
                    }
            }else{
                while($current_node and (! get_previous_brother($current_node))){
                    if ((get_needed_children_number($current_node) > get_current_children_number($current_node))
                        or ((get_needed_children_number($current_node) == -1)                # ALL
                            and (get_max_available_children($current_node) > get_current_children_number($current_node)))
                        or ((get_needed_children_number($current_node) == -2)                # BEST
                            and (get_current_children_number($current_node) <= 0))
                        or (($tree_ref != $current_node)
                            and (get_needed_children_number(get_father($current_node)) > 0)
                            and ($nb_children_validated{get_father($current_node)} >= get_needed_children_number(get_father($current_node))))
                        or (get_needed_children_number($current_node) == 0)                 # For stupid requests with 0 item wanted
                       ){
                        # we want to delete the root
                        return(undef) if ($tree_ref == $current_node);
#                       print("DELETE 2: ".get_current_resource_name($current_node)."=".get_current_resource_value($current_node)."\n");
                        # Delete sub tree that does not fit with wanted resources 
                        $current_node = delete_subtree($current_node);
                    }else{
                        # Step up
                        $current_node = get_father($current_node);
                        $nb_children_validated{$current_node}++ if ($current_node);
#                       print("Go to FATHER: ".get_current_resource_name($current_node)."=".get_current_resource_value($current_node)." ($nb_children_validated{$current_node}/".get_needed_children_number($current_node).")\n") if (defined(get_current_resource_value($current_node)));
                    }
                }
    
                if ($current_node 
                    and ($tree_ref != $current_node)
                   ){
                    my $tmp_father = get_father($current_node);
                    if ((get_needed_children_number($tmp_father) > 0)
                        and ($nb_children_validated{$tmp_father} >= get_needed_children_number($tmp_father))
                       ){
                        # We have enough nodes at this stage
                        $current_node->[7] = undef;  # purge the rest of brothers
                        #$tmp_father->[10] = $nb_children_validated{$tmp_father} + 1;
#                       print("PURGE BROTHERS: ".get_current_resource_name($current_node)."=".get_current_resource_value($current_node)."($tmp_father->[10])\n");
                    }
                }
    
                if (get_previous_brother($current_node)){
                    # Treate brother
                    if ((get_needed_children_number($current_node) > get_current_children_number($current_node))
                        or ((get_needed_children_number($current_node) == -1)                # ALL
                            and (get_max_available_children($current_node) > get_current_children_number($current_node)))
                        or ((get_needed_children_number($current_node) == -2)                # BEST
                            and (get_current_children_number($current_node) <= 0))
                        or (get_needed_children_number($current_node) == 0)                  # For stupid requests with 0 item wanted
                       ){
#                       print("DELETE 3: ".get_current_resource_name($current_node)."=".get_current_resource_value($current_node)."\n");
                        # Delete sub tree that does not fit with wanted resources 
                        delete_subtree($current_node);
                    }elsif ($tree_ref != $current_node){
                        $nb_children_validated{get_father($current_node)}++;
                    }
                    $current_node = get_previous_brother($current_node) ;
                    $nb_children_validated{$current_node} = 0;
#                   print("Go to BROTHER: ".get_current_resource_name($current_node)."=".get_current_resource_value($current_node)."\n");
                }
            }
        }
    }while($current_node);
#    print("STOP delete_tree_nodes_with_not_enough_resources\n");

    if (! get_initial_child($tree_ref)){
        return(undef);
    }else{
        return($tree_ref);
    }
}

return 1;
