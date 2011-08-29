#ifndef OAR_RESOURCE_TREE_H
#define OAR_RESOURCE_TREE_H

#include <list>
#include <string>
#include <map>
#include <vector>
#include <cassert>



namespace OAR::Schedulers::ResourceTree {

class TreeNode;

class TreeNode {
public:
  TreeNode *father; // father ref $tree_ref->[0]
  std::map<std::string, TreeNode *> children; // ref of a hashtable with children $tree_ref->[1
  std::string name; //  name of the resource $tree_ref->[2]
  std::string value; // value of this resource  $tree_ref->[3]
  int level; // level indicator $tree_ref->[4]
  int needed_children_number; /* needed children number :  $tree_ref->[5]
				 -1 means ALL (Alive + Absent + Suspected resources)
				 -2 means BEST (Alive resources at the time)*/
  
  int max_available_children; // maximum available children:  $tree_ref->[6];
  TreeNode *prev_brother; // previous brother ref $tree_ref->[7]
  TreeNode *next_brother; // next brother ref  $tree_ref->[8]
  TreeNode *first_child; //  first child ref $tree_ref->[9]
  int current_child_number; //  current children number $tree_ref->[10] = 0 ;   

  /**
     # Create a tree
     # arg : number of needed children
     # return the ref of the created tree
  */
  TreeNode(int need_child_num) : father(NULL), level(0), needed_children_number(need_child_num),max_available_children(0), prev_brother(NULL), next_brother(NULL), first_child(NULL),current_child_number(0) {};
  TreeNode(TreeNode *fat, TreeNode *child,
	   std::string res_name, std::string res_value,
	   int lev, int need_ch_numb, int max_avai_ch,
	   TreeNode *prev_bro, TreeNode *next_bro, 
	   TreeNode *first_ch, 
	   int cur_ch_numb ) : father(fat),
			       name(res_name),
			       value(res_value),level(lev),
			       needed_children_number(need_ch_numb),
			       max_available_children(max_avai_ch),
			       prev_brother(prev_bro),
			       next_brother(next_bro),
			       first_child(first_ch),
			       current_child_number(cur_ch_numb) {
    assert( child == 0 ); // not implemented
  };
};


TreeNode *clone(TreeNode *tree_ref);
bool is_node_a_leaf(TreeNode *tree_ref);
TreeNode *add_child(TreeNode *tree_ref,
		    std::string resource_name,
		    std::string resource_value);
int set_needed_children_number(TreeNode *tree_ref,
			       int needed_children_number);
TreeNode *get_previous_brother(TreeNode *tree_ref);
TreeNode *get_next_brother(TreeNode *tree_ref);
TreeNode *get_initial_child(TreeNode *tree_ref);
TreeNode *get_a_child(TreeNode *tree_ref, std::string child_name);
TreeNode *get_father(TreeNode *tree_ref);
std::string get_current_resource_name(TreeNode *tree_ref);
std::string get_current_resource_value(TreeNode *tree_ref);
int get_current_children_number(TreeNode *tree_ref);
int get_current_level(TreeNode *tree_ref);
int get_max_available_children(TreeNode *tree_ref);
int get_needed_children_number(TreeNode *tree_ref);
TreeNode *delete_subtree(TreeNode *tree_ref);
TreeNode *delete_tree_nodes_with_not_enough_resources(TreeNode *tree_ref);
std::vector<TreeNode *> get_tree_leafs(TreeNode *tree);
TreeNode *delete_unnecessary_subtrees(TreeNode *tree_ref);


}
#endif
