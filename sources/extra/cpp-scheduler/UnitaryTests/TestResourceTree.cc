#include <string>

#include "TestResourceTree.H"

#include "../Oar_resource_tree.H"

using namespace OAR::Schedulers::ResourceTree;

CPPUNIT_TEST_SUITE_REGISTRATION( TestResourceTree );

void TestResourceTree::setUp()
{
}

void TestResourceTree::tearDown()
{
}

void TestResourceTree::testConstructor()
{
  TreeNode *n, *n2;

  // essai du constructeur avec juste le needed_children_number
  n = new TreeNode(123);
  CPPUNIT_ASSERT_EQUAL( 123, n->needed_children_number);
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(0), n->father );
  CPPUNIT_ASSERT_EQUAL( static_cast<size_t>(0), n->children.size() );
  CPPUNIT_ASSERT_EQUAL( std::string(), n->name );
  CPPUNIT_ASSERT_EQUAL( std::string(), n->value );
  CPPUNIT_ASSERT_EQUAL( 0, n->level );
  CPPUNIT_ASSERT_EQUAL( 0, n->max_available_children );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(0), n->prev_brother );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(0), n->next_brother );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(0), n->first_child );
  CPPUNIT_ASSERT_EQUAL( 0, n->current_child_number );


  // essai du constructeur avec l'ensemble des parametres
  n2 = n;
  n = new TreeNode(n2, static_cast<TreeNode *>(0),
		   "toto", "tutu", 10, 11, 12, n2+1, n2+2, n2+3,  14 );

  CPPUNIT_ASSERT_EQUAL( 11, n->needed_children_number);
  CPPUNIT_ASSERT_EQUAL( n2, n->father );
  CPPUNIT_ASSERT_EQUAL( static_cast<size_t>(0), n->children.size() );
  CPPUNIT_ASSERT_EQUAL( std::string("toto"), n->name );
  CPPUNIT_ASSERT_EQUAL( std::string("tutu"), n->value );
  CPPUNIT_ASSERT_EQUAL( 10, n->level );
  CPPUNIT_ASSERT_EQUAL( 12, n->max_available_children );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(n2+1), n->prev_brother );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(n2+2), n->next_brother );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(n2+3), n->first_child );
  CPPUNIT_ASSERT_EQUAL( 14, n->current_child_number );

  delete n;
  delete n2;

}

void TestResourceTree::testAccessor()
{
  TreeNode *n;
  TreeNode *n2= (TreeNode *)123456;

  // essai du constructeur avec l'ensemble des parametres
  n = new TreeNode(static_cast<TreeNode *>((void*)5), static_cast<TreeNode *>(0),
		   "toto", "tutu", 10, 11, 12, n2+1, n2+2, n2+3,  14 );

  CPPUNIT_ASSERT_EQUAL( true, is_node_a_leaf(n) );
  CPPUNIT_ASSERT_EQUAL( 21, set_needed_children_number(n, 21) );
  CPPUNIT_ASSERT_EQUAL( 21, n->needed_children_number );
  CPPUNIT_ASSERT_EQUAL( 21, get_needed_children_number(n) );  
  
  CPPUNIT_ASSERT_EQUAL( static_cast<size_t>(0), n->children.size() );
  CPPUNIT_ASSERT_EQUAL( std::string("toto"), get_current_resource_name(n) );
  CPPUNIT_ASSERT_EQUAL( std::string("tutu"), get_current_resource_value(n) );
  CPPUNIT_ASSERT_EQUAL( 10, n->level );
  CPPUNIT_ASSERT_EQUAL( 12, n->max_available_children );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(n2+1), get_previous_brother(n) );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(n2+2), get_next_brother(n) );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(n2+3), get_initial_child(n) );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>((void*)5), get_father(n) );
  CPPUNIT_ASSERT_EQUAL( 14, get_current_children_number(n) );
  CPPUNIT_ASSERT_EQUAL( 10, get_current_level(n) );
  CPPUNIT_ASSERT_EQUAL( 12, get_max_available_children(n) );

  delete n;
}

/**
   This fonction builds a tree with 5 nodes : a root (cluster, alpha)
   , with two childs (network, giga) (network, myri). One of the child
   (network, giga) with two other childs (node, p1) et (node, p2).

   This tree is cloned, then the subtree without child is suppressed.
*/
static void test1fils(TreeNode *a)
{
  CPPUNIT_ASSERT_EQUAL( static_cast<size_t>(1), a->children.size() );
  CPPUNIT_ASSERT_EQUAL( a->children.find("giga")->second,
			get_initial_child( a ) );
  CPPUNIT_ASSERT_EQUAL( a, get_father( get_initial_child( a ) ) );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(0),
			get_next_brother( get_initial_child ( a ) ) );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(0),
			get_next_brother( a ) );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(0),
			get_previous_brother( get_initial_child ( a ) ) );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(0),
			get_previous_brother( a ) );
}

static void test2fils( TreeNode *a )
{
  CPPUNIT_ASSERT_EQUAL( static_cast<size_t>(2), a->children.size() );
  // le nouveau fils a ete ajoute en premier (insertion en tete)

  //std::cerr << " myri :" << a->children.find("myri")->second
  //	    << " giga :" << a->children.find("giga")->second << std::endl;
  CPPUNIT_ASSERT_EQUAL( a->children.find("myri")->second,
			get_initial_child( a ) );
  CPPUNIT_ASSERT_EQUAL( a, get_father( get_initial_child( a ) ) );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>( a->children.find("giga")->second ),
			get_next_brother( get_initial_child ( a ) ) );

  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(0),
			get_next_brother( get_next_brother( a ) ) );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(0),
			get_previous_brother( get_initial_child ( a ) ) );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(get_initial_child( a ) ),
			get_previous_brother( get_next_brother( get_initial_child( a ) ) ) );
  CPPUNIT_ASSERT_EQUAL( static_cast<TreeNode *>(0),
			get_previous_brother( a ) );
}

void TestResourceTree::testTreeManipulation()
{
  TreeNode *nroot;
  TreeNode *cnroot;


  // essai du constructeur avec l'ensemble des parametres
  nroot = new TreeNode(static_cast<TreeNode *>(0),
		       static_cast<TreeNode *>(0),
		       "cluster", "alpha", 1, 0, 0, 0, 0, 0, 0);

  add_child(nroot, "network", "giga");
  test1fils(nroot);

  add_child(nroot, "network", "giga"); // this should not be inserted
  CPPUNIT_ASSERT_EQUAL( static_cast<size_t>(1), nroot->children.size() );

  // ajout du deuxième fils
  add_child(nroot, "network", "myri");
  test2fils( nroot );


  // ajout de deux fils au fils giga
  add_child(nroot->children.find( "giga" )->second , "node", "p1");
  add_child(nroot->children.find( "giga" )->second , "node", "p2");
  
  CPPUNIT_ASSERT_EQUAL( static_cast<size_t>(2),
			nroot->children.find("giga")->second->children.size() );
  CPPUNIT_ASSERT_EQUAL( nroot, get_father( get_father( nroot->first_child->next_brother->first_child->next_brother ) ) );

  // On clone
  cnroot = clone(nroot);
  // il faudrait refaire les mêmes tests
  CPPUNIT_ASSERT( cnroot != nroot );
  test2fils(cnroot);

  // on efface le clone
  delete_subtree(cnroot);

  test2fils(nroot);
  // on efface l'original
  delete_subtree( nroot );
}

// tester: clone, is_node_a_leaf, add_child,
// delete_subtree,delete_tree_nodes_with_not_enough_resources,
// get_tree_leafs, delete_unnecessary_subtree
