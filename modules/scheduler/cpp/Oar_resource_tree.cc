#include <iostream>
#include "Oar_resource_tree.H"

namespace oar_resource_tree {

// # $Id$
// package oar_resource_tree;

// use warnings;
// use strict;
// use Data::Dumper;
// use Storable qw(dclone);
// use Time::HiRes qw(gettimeofday);

// ###############################################################################
// #                       RESOURCE TREE MANAGEMENT                              #
// ###############################################################################

// # Prototypes
// sub new();
// sub clone($);
// sub add_child($$$);
// sub get_children_list($);
// sub is_node_a_leaf($);
// sub get_a_child($$);
// sub get_father($);
// sub get_current_resource_name($);
// sub get_current_resource_value($);
// sub get_current_children_number($);
// sub get_current_level($);
// sub get_max_available_children($);
// sub set_needed_children_number($$);
// sub get_needed_children_number($);
// sub delete_subtree($);
// sub get_previous_brother($);
// sub get_next_brother($);
// sub get_initial_child($);


// ###############################################################################

// sub get_tree_leafs($);
// sub delete_tree_nodes_with_not_enough_resources($);
// sub delete_unnecessary_subtrees($);

// ###############################################################################

// # Create a tree
// # arg : number of needed children
// # return the ref of the created tree
// sub new(){
//     my $needed_children_number = shift;
    
//     my $tree_ref;
//     $tree_ref->[0] = undef ;                    # father ref
//     $tree_ref->[1] = undef ;                    # ref of a hashtable with children
//     $tree_ref->[2] = undef ;                    # name of the resource
//     $tree_ref->[3] = undef ;                    # value of this resource
//     $tree_ref->[4] = 0 ;                        # level indicator
//     $tree_ref->[5] = 0 ;                        # needed children number :
//                                                 #   -1 means ALL (Alive + Absent + Suspected resources)
//                                                 #   -2 means BEST (Alive resources at the time)
//     $tree_ref->[6] = 0 ;                        # maximum available children
//     $tree_ref->[7] = undef ;                    # previous brother ref
//     $tree_ref->[8] = undef ;                    # next brother ref
//     $tree_ref->[9] = undef ;                    # first child ref
//     $tree_ref->[10] = 0 ;                       # current children number


//     return($tree_ref);
// }


/** c'est non trivial en c++ ?
    J'ai fait trivial : hypothese: c'est bien un arbre et pas un dag ! 
    # clone the tree
    # arg : tree ref
    # return a copy of the tree ref
*/

static TreeNode *dclone(TreeNode *tree_ref)
{
  int i;
  TreeNode *last_inserted_child = NULL;

  assert(tree_ref != 0);

  TreeNode *newnode = new TreeNode(tree_ref->needed_children_number);
  newnode->name = tree_ref->name;
  newnode->value = tree_ref->value;
  newnode->level = tree_ref->level;


  // pour chaque fils, creer un sous-arbre
  // et l'insérer comme fils dans le nouvel arbre
  TreeNode *current_child = tree_ref->first_child;
  assert(  tree_ref->current_child_number == (int) tree_ref->children.size() );

  for(i=0;
      i < tree_ref->current_child_number;
      i++, current_child = current_child->next_brother )
    {
      assert( current_child != NULL );
      TreeNode *newchild;

      newchild = dclone( current_child );
      newchild->father = newnode;

      // on prend le name de chaque fils, et on l'insere la nouvelle ref
      newnode->children.insert( std::pair<std::string, TreeNode *>(current_child->value,
								   newchild) );

      if ( last_inserted_child == NULL )
	{
	  newnode->first_child = newchild;
	}
      else
	{
	  newchild->prev_brother = last_inserted_child;
	  last_inserted_child->next_brother = newchild;
	}
      last_inserted_child = newchild;


      newnode->current_child_number ++;
    }

  assert( newnode->current_child_number == tree_ref->current_child_number );
//   std::cerr << "lvl :" << newnode->level << " newnode ch size :" 
// 	    << newnode->children.size() << " tree_ref ch size :" 
// 	    << tree_ref->children.size() << std::endl;
 
  assert( newnode->children.size() == tree_ref->children.size() );
  return newnode;
}

TreeNode *clone(TreeNode *tree_ref)
{
  if (tree_ref == NULL)
    return NULL;

  return ( dclone(tree_ref) );
}
// # clone the tree
// # arg : tree ref
// # return a copy of the tree ref
// sub clone($){
//     my $tree_ref = shift;

//     return(dclone($tree_ref));
// }


/** return 1 if node is a leaf (no child)
    otherwise retuurn 0 */

bool is_node_a_leaf(TreeNode *tree_ref){
  if ( tree_ref->children.size() > 0 )
    return false;
  else
    return true;
}


// # return 1 if node is a leaf (no child)
// # otherwise retuurn 0
// sub is_node_a_leaf($){
//     my $tree_ref = shift;

//     if (defined($tree_ref->[1])){
//         return(0);
//     }else{
//         return(1);
//     }
// }


/**
   add a child to the given tree ref (if child resource name is undef it seems
   that this child is a leaf of the tree)
   arg : tree ref, resource name, resource value
   return the ref of the child
*/
TreeNode *add_child(TreeNode *tree_ref,
		    std::string resource_name,
		    std::string resource_value)
{
    TreeNode *tmp_ref;
    if ( tree_ref->children.find(resource_value) ==  tree_ref->children.end() ) 
      {
	// Create a new tree node
	tmp_ref = new TreeNode(tree_ref, 0, resource_name, resource_value,
			       tree_ref->level+1, 0, 0, NULL, NULL, NULL, 0 );

	
	tree_ref->children.insert( std::pair<std::string, TreeNode *>(resource_value,
								      tmp_ref) );
        
	tree_ref->max_available_children++;
	tree_ref->current_child_number++;

        // Add new brother
	if (tree_ref->first_child != NULL) {
	  tmp_ref->next_brother = tree_ref->first_child;
	  tree_ref->first_child->prev_brother = tmp_ref;
	}
	tree_ref->first_child = tmp_ref;

      }
    else
      {
	tmp_ref = tree_ref->children.find(resource_value)->second;
      }
    
    return(tmp_ref);
}



// # add a child to the given tree ref (if child resource name is undef it seems
// # that this child is a leaf of the tree)
// # arg : tree ref, resource name, resource value
// # return the ref of the child
// sub add_child($$$){
//     my $tree_ref = shift;
//     my $resource_name = shift;
//     my $resource_value = shift;

//     my $tmp_ref;
//     if (!defined($tree_ref->[1]->{$resource_value})){
//         # Create a new tree node
//         $tmp_ref = [ $tree_ref, undef, $resource_name, $resource_value, $tree_ref->[4] + 1, 0, 0, undef, undef, undef, 0];
        
//         $tree_ref->[1]->{$resource_value} = $tmp_ref;
//         $tree_ref->[6] = $tree_ref->[6] + 1;
//         $tree_ref->[10] = $tree_ref->[10] + 1;

//         # Add new brother
//         if (defined($tree_ref->[9])){
//             $tmp_ref->[8] = $tree_ref->[9];
//             $tree_ref->[9]->[7] = $tmp_ref;
//         }
//         $tree_ref->[9] = $tmp_ref;
//     }else{
//         $tmp_ref = $tree_ref->[1]->{$resource_value};
//     }
    
//     return($tmp_ref);
// }



/** 
    Store information about the number of needed children
 */
int set_needed_children_number(TreeNode *tree_ref, int needed_children_number)
{
    tree_ref->needed_children_number = needed_children_number;

    return needed_children_number;
}

// # Store information about the number of needed children
// sub set_needed_children_number($$){
//     my $tree_ref = shift;
//     my $needed_children_number = shift;

//     $tree_ref->[5] = $needed_children_number;
// }


/**
   Get previous brother on the same level for the same father
*/
TreeNode *get_previous_brother(TreeNode *tree_ref)
{
  if ( tree_ref == NULL )
    return NULL;
  else
    return tree_ref->prev_brother;
}
// # Get previous brother on the same level for the same father
// sub get_previous_brother($){
//     my $tree_ref = shift;

//     if (!defined($tree_ref)){
//         return(undef);
//     }else{
//         return($tree_ref->[7]);
//     }
// }


//# Get next brother on the same level for the same father
TreeNode *get_next_brother(TreeNode *tree_ref)
{
  if (tree_ref == NULL)
    return NULL;
  else
    return tree_ref->next_brother;
}
// # Get next brother on the same level for the same father
// sub get_next_brother($){
//     my $tree_ref = shift;

//     if (!defined($tree_ref)){
//         return(undef);
//     }else{
//         return($tree_ref->[8]);
//     }
// }


/**
   Get initial child ref
*/
TreeNode *get_initial_child(TreeNode *tree_ref)
{
  if (tree_ref == NULL)
    return NULL;
  else
    return tree_ref->first_child;
}
// # Get initial child ref
// sub get_initial_child($){
//     my $tree_ref = shift;

//     if (!defined($tree_ref)){
//         return(undef);
//     }else{
//         return($tree_ref->[9]);
//     }
// }


/**
   Get a specific child
   arg : tree ref, name of a child
   return a ref of a tree
*/
TreeNode *get_a_child(TreeNode *tree_ref, std::string child_name)
{
  std::map<std::string, TreeNode*>::iterator ch;

  if ( tree_ref == NULL 
       || tree_ref->children.size() == 0
       || (ch = tree_ref->children.find(child_name) )
       ==  tree_ref->children.end() )
    return NULL;
  else
    return ch->second;
}

// # Get a specific child
// # arg : tree ref, name of a child
// # return a ref of a tree
// sub get_a_child($$){
//     my $tree_ref = shift;
//     my $child_name = shift;

//     if (!defined($tree_ref) || !defined($tree_ref->[1]) || !defined($tree_ref->[1]->{$child_name})){
//         return(undef);
//     }else{
//         return($tree_ref->[1]->{$child_name});
//     }
// }

/**
   Get the ref of the father tree
   arg : tree ref
   return a tree ref
*/
TreeNode *get_father(TreeNode *tree_ref)
{
  if ( tree_ref == NULL || tree_ref->father == NULL )
    return NULL;
  else
    return tree_ref->father; 
}
// # Get the ref of the father tree
// # arg : tree ref
// # return a tree ref
// sub get_father($){
//     my $tree_ref = shift;

//     if (!defined($tree_ref) || !defined($tree_ref->[0])){
//         return(undef);
//     }else{
//         return($tree_ref->[0]);
//     }
// }


/**
   Get the current resource name
   arg : tree ref
   return the resource name
*/
std::string get_current_resource_name(TreeNode *tree_ref)
{
  if (tree_ref == NULL || tree_ref->name == "" )
    return "";
  else
    return tree_ref->name;
}
// # Get the current resource name
// # arg : tree ref
// # return the resource name
// sub get_current_resource_name($){
//     my $tree_ref = shift;

//     if (!defined($tree_ref) || !defined($tree_ref->[2])){
//         return(undef);
//     }else{
//         return($tree_ref->[2]);
//     }
// }


/**
   Get the current resource value
   arg : tree ref
   return the resource value
*/
std::string get_current_resource_value(TreeNode *tree_ref)
{
  if ( tree_ref == NULL || tree_ref->value == "" )
    return "";
  else
    return tree_ref->value;
}
// # Get the current resource value
// # arg : tree ref
// # return the resource value
// sub get_current_resource_value($){
//     my $tree_ref = shift;

//     if (!defined($tree_ref) || !defined($tree_ref->[3])){
//         return(undef);
//     }else{
//         return($tree_ref->[3]);
//     }
// }


/**
   Get the current children number
   arg : tree ref
   return the resource value
*/
int get_current_children_number(TreeNode *tree_ref)
{
  if (tree_ref == NULL)
    // j'ai enleve le test non sens en C++ :
    // tree_ref->current_child_number est toujours definis
    return -1;
  else
    return  tree_ref->current_child_number;
}
// # Get the current children number
// # arg : tree ref
// # return the resource value
// sub get_current_children_number($){
//     my $tree_ref = shift;

//     if (!defined($tree_ref) || !defined($tree_ref->[10])){
//         return(undef);
//     }else{
//         return($tree_ref->[10]);
//     }
// }


/**
   Get the current level indicator
   arg : tree ref
   return the level indicator
*/
int get_current_level(TreeNode *tree_ref)
{
  if (tree_ref == NULL || tree_ref->level == 0)
    return 0;
  else
    return tree_ref->level;
}
// # Get the current level indicator
// # arg : tree ref
// # return the level indicator
// sub get_current_level($){
//     my $tree_ref = shift;

//     if (!defined($tree_ref) || !defined($tree_ref->[4])){
//         return(0);
//     }else{
//         return($tree_ref->[4]);
//     }
// }


/**
   Get the maximum available number of children
   (just after the creation of the tree)
   arg : tree ref
   return an integer >= 0
*/
int get_max_available_children(TreeNode *tree_ref)
{
  if ( tree_ref == NULL || tree_ref->max_available_children == 0 )
    return 0;
  else
    return tree_ref->max_available_children;
}
// # Get the maximum available number of children
// # (just after the creation of the tree)
// # arg : tree ref
// # return an integer >= 0
// sub get_max_available_children($){
//     my $tree_ref = shift;
    
//     if (!defined($tree_ref) || !defined($tree_ref->[6])){
//         return(0);
//     }else{
//         return($tree_ref->[6]);
//     }
// }


/**
   Get the number of needed children
   arg : tree ref
   return the number of needed children
*/
int get_needed_children_number(TreeNode *tree_ref)
{
  if ( tree_ref == NULL || tree_ref->needed_children_number == 0 )
    return 0;
  else
    return tree_ref->needed_children_number;
}
// # Get the number of needed children
// # arg : tree ref
// # return the number of needed children
// sub get_needed_children_number($){
//     my $tree_ref = shift;

//     if (!defined($tree_ref) || !defined($tree_ref->[5])){
//         return(0);
//     }else{
//         return($tree_ref->[5]);
//     }
// }


/**
   Delete a subtree
   arg : tree ref to delete
   return father tree ref
*/

/**
   recursive delete of nodes, including
   Hypothesys: the graph is really a tree (a single path to a node)
   
 */
static void ddelete_subtree(TreeNode *tree_ref)
{
  int i;
  TreeNode *current_child = get_initial_child( tree_ref );
  TreeNode *next_child = 0;
  if (current_child != 0)
    next_child = get_next_brother( current_child );
  
  for(i = 0;
      i < get_current_children_number( tree_ref );
      i++, current_child = next_child)
    {
      assert(current_child != 0);
      get_next_brother( current_child );
      ddelete_subtree( current_child );
    }

  delete tree_ref;
}


TreeNode *delete_subtree(TreeNode *tree_ref)
{
  if (tree_ref == NULL)
    return NULL;

  TreeNode *father_ref = tree_ref->father;
  TreeNode *prev_brother = tree_ref->prev_brother;
  TreeNode *next_brother = tree_ref->next_brother;
  
  if ( prev_brother == NULL )
    {
      if (father_ref != NULL)
	{
	  assert(father_ref->first_child == tree_ref); // BUG version PERL?
	  father_ref->first_child = next_brother;
	}
    }
  else
    {
      prev_brother->next_brother = next_brother;
    }
  
  if ( next_brother != NULL )
    {
      next_brother->prev_brother = prev_brother;
    }
  
  if (father_ref != NULL) // BUG PERL ? ne verifie pas si la reference est nulle
    if ( father_ref->children.size() > 0 )
      {
	  // s'effacer soit meme de la table
	assert( father_ref->children.find(tree_ref->value)->second == tree_ref);
	assert( father_ref->children.erase(tree_ref->value) );
	
	// effacer les enfants et s'enlever de la mémoire soit meme	
	ddelete_subtree(tree_ref);
	  
	father_ref->current_child_number --;
	return father_ref;
      }
  return static_cast<TreeNode *>(0);
  
}
// # Delete a subtree
// # arg : tree ref to delete
// # return father tree ref
// sub delete_subtree($){
//     my $tree_ref = shift;
    
//     return(undef) if (!defined($tree_ref));

//     my $father_ref = $tree_ref->[0];

//     my $prev_brother = $tree_ref->[7];
//     my $next_brother = $tree_ref->[8];

//     if (!defined($prev_brother)){
//         if (defined($father_ref)){
//             $father_ref->[9] = $next_brother;
//         }
//     }else{
//         $prev_brother->[8] = $next_brother;
//     }

//     if (defined($next_brother)){
//         $next_brother->[7] = $prev_brother;
//     }
    
//     if (defined($father_ref->[1])){
//         delete($father_ref->[1]->{$tree_ref->[3]});
//         $father_ref->[10] = $father_ref->[10] - 1;
//         return($father_ref);
//     }else{
//         return(undef);
//     }
// }

//###############################################################################

/**
   # delete_tree_nodes_with_not_enough_resources
   # Delete subtrees that do not fit wanted resources
   # args: tree ref
   # side effect : modify tree data structure
*/
TreeNode *delete_tree_nodes_with_not_enough_resources(TreeNode *tree_ref)
{
  //#print("START delete_tree_nodes_with_not_enough_resources\n");
  //# Search if there are enough values for each resource
  //# Tremaux algorithm (Deep first)

  TreeNode *current_node = tree_ref;
  do {
    if ( (get_needed_children_number(current_node) > get_current_children_number(current_node) )
	 || ( (get_needed_children_number(current_node) == -1) // ALL
	      && (get_max_available_children(current_node) > get_current_children_number(current_node)))
	 || ( (get_needed_children_number(current_node) == -2) // BEST
	      && (get_current_children_number(current_node) <= 0) ) )
      {
	// we want to delete the root
	if (tree_ref == current_node)
	  return NULL;

	// Delete sub tree that does not fit with wanted resources 
	// print("DELETE ".get_current_resource_value($current_node)."\n");
	current_node = delete_subtree(current_node);
      }
    if ( get_initial_child(current_node) != NULL)
      {
	// Go to child
	current_node = get_initial_child(current_node);
	//print("Go to CHILD =".get_current_resource_value($current_node)."\n");
      }
    else
      {
	// Treate leaf
	while( (current_node != NULL) && 
	       ( (get_father(current_node) == 0) ||
		 (get_next_brother(current_node) == 0)))
	  {
	    // Step up
	    //print("TOTO ".get_current_children_number($current_node)."\n");
	    //print("Go to FATHER : ".get_current_resource_value($current_node)."\n") if (defined(get_current_resource_value($current_node)));
	    if ( (get_needed_children_number(current_node) > get_current_children_number(current_node) )
		 || ( (get_needed_children_number(current_node) == -1) // ALL
		      && ( get_max_available_children(current_node) > get_current_children_number(current_node) ) )
		 || ( (get_needed_children_number(current_node) == -2) // BEST
		      && (get_current_children_number(current_node) <= 0)))
	      {
		// we want to delete the root
		if (tree_ref == current_node)
		  return NULL;
		//print("DELETE 1".get_current_resource_value($current_node)."\n");
		// Delete sub tree that does not fit with wanted resources 
		current_node = delete_subtree(current_node);
	      }
	    else
	      {
		current_node = get_father(current_node);
	      }
	  }
	if ((get_father(current_node) != NULL) && (get_next_brother(current_node) != NULL))
	  {
	    // Treate brother
            TreeNode *brother_node = get_next_brother(current_node);
	    if ((get_needed_children_number(current_node) > get_current_children_number(current_node))
		|| ((get_needed_children_number(current_node) == -1) // ALL
		    && (get_max_available_children(current_node) > get_current_children_number(current_node)))
		|| ((get_needed_children_number(current_node) == -2) // BEST
		    && (get_current_children_number(current_node) <= 0)))
	      {
		//print("DELETE 2".get_current_resource_value($current_node)."\n");
		// Delete sub tree that does not fit with wanted resources 
		delete_subtree(current_node);
	      }
	    current_node = brother_node;
	    //print("Go to BROTHER : ".get_current_resource_value($current_node)."\n");
	  }
      }
  }while( (current_node != NULL) );

  if ( (get_initial_child(tree_ref) == NULL) )
    {
      return NULL;
    }
  else
    {
      return tree_ref;
    }
}


// # delete_tree_nodes_with_not_enough_resources
// # Delete subtrees that do not fit wanted resources
// # args: tree ref
// # side effect : modify tree data structure
// sub delete_tree_nodes_with_not_enough_resources($){
//     my $tree_ref = shift;

//     #print("START delete_tree_nodes_with_not_enough_resources\n");
//     # Search if there are enough values for each resource
//     # Tremaux algorithm (Deep first)
//     my $current_node = $tree_ref;
//     do{
//         if ((get_needed_children_number($current_node) > get_current_children_number($current_node))
//             or ((get_needed_children_number($current_node) == -1)                # ALL
//                 and (get_max_available_children($current_node) > get_current_children_number($current_node)))
//             or ((get_needed_children_number($current_node) == -2)                # BEST
//                 and (get_current_children_number($current_node) <= 0))
//         ){
//             # we want to delete the root
//             return(undef) if ($tree_ref == $current_node);
//             # Delete sub tree that does not fit with wanted resources 
//             #print("DELETE ".get_current_resource_value($current_node)."\n");
//             $current_node = delete_subtree($current_node);
//         }
//         if (defined(get_initial_child($current_node))){
//             # Go to child
//             $current_node = get_initial_child($current_node);
//             #print("Go to CHILD =".get_current_resource_value($current_node)."\n");
//         }else{
//             # Treate leaf
//             while(defined($current_node) and (!defined(get_father($current_node)) or !defined(get_next_brother($current_node)))){
//                 # Step up
//                 #print("TOTO ".get_current_children_number($current_node)."\n");
//                 #print("Go to FATHER : ".get_current_resource_value($current_node)."\n") if (defined(get_current_resource_value($current_node)));
//                 if ((get_needed_children_number($current_node) > get_current_children_number($current_node))
//                     or ((get_needed_children_number($current_node) == -1)                # ALL
//                         and (get_max_available_children($current_node) > get_current_children_number($current_node)))
//                     or ((get_needed_children_number($current_node) == -2)                # BEST
//                         and (get_current_children_number($current_node) <= 0))
//                 ){
//                     # we want to delete the root
//                     return(undef) if ($tree_ref == $current_node);
//                     #print("DELETE 1".get_current_resource_value($current_node)."\n");
//                     # Delete sub tree that does not fit with wanted resources 
//                     $current_node = delete_subtree($current_node);
//                 }else{
//                     $current_node = get_father($current_node);
//                 }
//             }
//             if (defined(get_father($current_node)) and defined(get_next_brother($current_node))){
//                 # Treate brother
//                 my $brother_node = get_next_brother($current_node);
//                 if ((get_needed_children_number($current_node) > get_current_children_number($current_node))
//                     or ((get_needed_children_number($current_node) == -1)                # ALL
//                         and (get_max_available_children($current_node) > get_current_children_number($current_node)))
//                     or ((get_needed_children_number($current_node) == -2)                # BEST
//                         and (get_current_children_number($current_node) <= 0))
//                 ){
//                     #print("DELETE 2".get_current_resource_value($current_node)."\n");
//                     # Delete sub tree that does not fit with wanted resources 
//                     delete_subtree($current_node);
//                 }
//                 $current_node = $brother_node;
//                 #print("Go to BROTHER : ".get_current_resource_value($current_node)."\n");
//             }
//         }
//     }while(defined($current_node));

//     if (!defined(get_initial_child($tree_ref))){
//         return(undef);
//     }else{
//         return($tree_ref);
//     }
// }


/**
   # get_tree_leaf
   # return a list of tree leaf
   # arg: tree ref
*/
std::vector<TreeNode *>get_tree_leafs(TreeNode *tree)
{

  std::vector<TreeNode *> result;

  if (tree == NULL)
    return result;
  
    
  // Search leafs
  // Tremaux algorithm (Deep first)
  TreeNode *current_node = tree;
  do {
    if ( (get_initial_child(current_node) != NULL) )
      {
	// Go to child
	current_node = get_initial_child(current_node);
	//print("Go to CHILD =".get_current_resource_value($current_node)."\n");
      }
    else
      {
	// Treate leaf
	if ( is_node_a_leaf(current_node) == true)
	  {
	    //push(@result, $node_name_pile[0]);
	    result.push_back(current_node);
	    //print("Leaf: ".get_current_resource_value($current_node)."\n");
	  }
	// Look at brothers
	while( (current_node != NULL) 
	       && ( (get_father(current_node) == NULL) || (get_next_brother(current_node) == NULL)))
	  {
	    // Step up
	    current_node = get_father(current_node);
	    //print("Go to FATHER : ".get_current_resource_value($current_node)."\n") if (defined(get_current_resource_value($current_node)));
	  }
	if ( (get_father(current_node) != NULL) && (get_next_brother(current_node) != NULL))
	  {
	    // Treate brother
	    current_node = get_next_brother(current_node);
	    //print("Go to BROTHER : ".get_current_resource_value($current_node)."\n");
	  }
      }
  } while( (current_node != NULL) );

  return result;
}
// # get_tree_leaf
// # return a list of tree leaf
// # arg: tree ref
// sub get_tree_leafs($){
//     my $tree = shift;

//     my @result;
//     return(@result) if (!defined($tree));
    
//     # Search leafs
//     # Tremaux algorithm (Deep first)
//     my $current_node = $tree;
//     do{
//         if (defined(get_initial_child($current_node))){
//             # Go to child
//             $current_node = get_initial_child($current_node);
//             #print("Go to CHILD =".get_current_resource_value($current_node)."\n");
//         }else{
//             # Treate leaf
//             if (is_node_a_leaf($current_node) == 1){
//                 #push(@result, $node_name_pile[0]);
//                 push(@result, $current_node);
//                 #print("Leaf: ".get_current_resource_value($current_node)."\n");
//             }
//             # Look at brothers
//             while(defined($current_node) and (!defined(get_father($current_node)) or !defined(get_next_brother($current_node)))){
//                 # Step up
//                 $current_node = get_father($current_node);
//                 #print("Go to FATHER : ".get_current_resource_value($current_node)."\n") if (defined(get_current_resource_value($current_node)));
//             }
//             if (defined(get_father($current_node)) and defined(get_next_brother($current_node))){
//                 # Treate brother
//                 $current_node = get_next_brother($current_node);
//                 #print("Go to BROTHER : ".get_current_resource_value($current_node)."\n");
//             }
//         }
//     }while(defined($current_node));

//     return(@result);
// }

/**
   # delete_unnecessary_subtrees
   # Delete subtrees that are not necessary (watch needed_children_number)
   # args: tree ref
   # side effect : modify tree data structure
*/

TreeNode *delete_unnecessary_subtrees(TreeNode *tree_ref)
{
  if (tree_ref == NULL)
    return tree_ref;

  // Search if there are enough values for each resource
  // Tremaux algorithm (Deep first)
  TreeNode *current_node = tree_ref;
  do {
        if ( (get_needed_children_number(current_node) >= 0) && (get_needed_children_number(current_node) < (get_current_children_number(current_node))))
	  {
            // Delete extra sub tree
            delete_subtree(get_initial_child(current_node));
	  }
	else
	  {
            if ( (get_initial_child(current_node)) != NULL )
	      {
		// Go to child
		current_node = get_initial_child(current_node);
		//#print("Go to CHILD =".get_current_resource_value($current_node)."\n");
	      }
	    else
	      {
                // Look at brothers
                while( (current_node != NULL) && ( (get_father(current_node) == NULL) || (get_next_brother(current_node) == NULL)))
		  {
                    // Step up
                    current_node = get_father(current_node);
                    //print("Go to FATHER : ".get_current_resource_value($current_node)."\n") if (defined(get_current_resource_value($current_node)));
		  }
                if ( (get_father(current_node) != NULL) 
		     && (get_next_brother(current_node) != NULL) )
		  {
                    // Treate brother
                    current_node = get_next_brother(current_node);
                    //print("Go to BROTHER : ".get_current_resource_value($current_node)."\n");
		  }
	      }
	  }
  } while( (current_node != NULL) );

  return tree_ref;
}
// # delete_unnecessary_subtrees
// # Delete subtrees that are not necessary (watch needed_children_number)
// # args: tree ref
// # side effect : modify tree data structure
// sub delete_unnecessary_subtrees($){
//     my $tree_ref = shift;

//     return($tree_ref) if (!defined($tree_ref));

//     # Search if there are enough values for each resource
//     # Tremaux algorithm (Deep first)
//     my $current_node = $tree_ref;
//     do{
//         if ((get_needed_children_number($current_node) >= 0) and (get_needed_children_number($current_node) < (get_current_children_number($current_node)))){
//             # Delete extra sub tree
//             delete_subtree(get_initial_child($current_node));
//         }else{
//             if (defined(get_initial_child($current_node))){
//                 # Go to child
//                 $current_node = get_initial_child($current_node);
//                 #print("Go to CHILD =".get_current_resource_value($current_node)."\n");
//             }else{
//                 # Look at brothers
//                 while(defined($current_node) and (!defined(get_father($current_node)) or !defined(get_next_brother($current_node)))){
//                     # Step up
//                     $current_node = get_father($current_node);
//                     #print("Go to FATHER : ".get_current_resource_value($current_node)."\n") if (defined(get_current_resource_value($current_node)));
//                 }
//                 if (defined(get_father($current_node)) and defined(get_next_brother($current_node))){
//                     # Treate brother
//                     $current_node = get_next_brother($current_node);
//                     #print("Go to BROTHER : ".get_current_resource_value($current_node)."\n");
//                 }
//             }
//         }
//     }while(defined($current_node));

//     return($tree_ref);
// }
//return 1;

}
