#ifndef GANTT_HOLE_STORAGE_H
#define GANTT_HOLE_STORAGE_H

#include <cmath>

//const unsigned int INFINITY = MAX_INT;

#include "Oar_resource_tree.H"

namespace Gant_hole_storage {

class StopTime
{
public:
  unsigned int stop_time;
  std::vector<bool> r;
  StopTime(unsigned int time, std::vector<bool> res) : stop_time(time), r(res) {};
};

class Hole
{
public:
  int start_time; //  $gantt->[0]->[0]
  std::vector<StopTime> holestop;
  
  /* just for the first hole */
  bool first_hole;
  std::vector<bool> all_inserted_resources;
  
  int minimum_hole_duration; //  $gantt->[0]->[4]
  std::pair<int, int> max_time_find_first_hole;
  
  Hole(int start) : start_time(start) {}; 
};

class Gantt
{
  void initGantt(int, int);
public:
  std::vector<bool> zero_vec; // ex-perl $gantt->[0]->[3];
  std::vector<Hole> holes;
  Gantt(int, int);
  Gantt(int max_resource_number, int minimum_hole_duration,
	int date, int duration, std::vector<bool> resources_vec);
};

//int new_1_with_holes(a,b,c,d,e);
int add_new_resources(Gantt *a, std::vector<bool> b);
int set_occupation(Gantt *a, int b, int c, std::vector<bool> d);
int get_free_resources(Gantt *gantt, int begin_date, int duration);
int find_hole(Gantt *gantt, int begin_date, int duration);
std::pair<int, std::vector<oar_resource_tree::TreeNode *> >
find_first_hole(Gantt *gantt, int initial_time, int duration,
		std::vector<oar_resource_tree::TreeNode *> tree_description_list, int timeout);
int pretty_print(Gantt *a);
unsigned int get_infinity_value();

}

#endif
