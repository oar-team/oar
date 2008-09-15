
/**
   \brief gant manipulation for the scheduler
   \author Gregory Mounié
   \version 0.1
   \date 07 05 2008

   version 0.1:
   Re-writing of the original perl code of OAR 2.1 to get a C++
   version of the same algorithm. The use of the STL is done to be the
   closest possible of the perl version

  
*/

#include <vector>	   
#include "Gantt_hole_storage.H"
#include "Oar_resource_tree.H"
#include <time.h>


// # $Id$
// package Gantt_hole_storage;
// require Exporter;
// use oar_resource_tree;
// use Data::Dumper;
// use warnings;
// use strict;

// # Note : All dates are in seconds
// # Resources are integer so we store them in bit vectors
// # Warning : this gantt cannot manage overlaping time slots

// # 2^32 is infinity in 32 bits stored time
//my $Infinity = 4294967296;


// # Prototypes
// # gantt chart management
// sub new($$);
// sub new_with_1_hole($$$$$);
// sub add_new_resources($$);
// sub set_occupation($$$$);
// sub get_free_resources($$$);
// sub find_first_hole($$$$$);
// sub pretty_print($);
// sub get_infinity_value();


unsigned int get_infinity_value()
{
  // le meme que dans le code perl
  // BUG perl: 1 de trop
  assert(sizeof(unsigned int) == 4);

  return 4294967295UL;
}

// sub get_infinity_value(){
//     return($Infinity);
// }

/**
   affichage des vecteurs de bool inserer dans la structure du gantt
*/
int pretty_print(Gantt *gantt)
{


}

/*
sub pretty_print($){
    my $gantt = shift;
   
    my @bits = split(//, unpack("b*", $gantt->[0]->[2]));
    print("@bits\n");
    foreach my $g (@{$gantt}){
        print("BEGIN : $g->[0]\n");
        foreach my $h (@{$g->[1]}){
            @bits = split(//, unpack("b*", $h->[1]));
            print("    $h->[0] : @bits\n");
        }
        print("\n");
    }
}
*/


/**
   Creates an empty Gantt
   arg : number of the max resource id
*/

/** fonction d'initialisation */

void Gantt::initGantt(int max_resource_number, int minimum_hole_duration)
{
  std::vector<bool> empty_vec(max_resource_number);
  Hole h(0);

  h.holestop.push_back(StopTime(get_infinity_value(), empty_vec));
  h.first_hole = true;
  h.all_inserted_resources = empty_vec;

  // zero_vec est une variable du Gant et pas du trou mantenant 
  zero_vec = empty_vec;

  h.minimum_hole_duration = minimum_hole_duration;
  h.max_time_find_first_hole = std::pair<unsigned int, unsigned int>(get_infinity_value(), get_infinity_value());

  holes.push_back(h);
}


Gantt::Gantt(int max_resource_number, int minimum_hole_duration = 0)
{
  initGantt(max_resource_number, minimum_hole_duration);
}

// # Creates an empty Gantt
// # arg : number of the max resource id
// sub new($$){
//     my $max_resource_number = shift;
//     my $minimum_hole_duration = shift;
//     $minimum_hole_duration = 0 if (!defined($minimum_hole_duration));

//     my $empty_vec = '';
//     vec($empty_vec, $max_resource_number, 1) = 0;
    
//     my $result =[
//                     [
//                         0,                              # start time of this hole
//                         [                               # ref of a structure which contains hole stop times and corresponding resources (ordered by end time)
//                             [$Infinity, $empty_vec]
//                         ],
//                         $empty_vec,                     # Store all inserted resources (Only for the first Gantt hole)
//                         $empty_vec,                     # Store empty vec with enough 0 (Only for the first hole)
//                         $minimum_hole_duration,         # minimum time for a hole
//                         [$Infinity,$Infinity]           # times that find_first_hole must not go after
//                     ]
//                 ];
    
//     return($result);
// }

/**
 * Creates a Gantt with 1 hole
 * args number of the max resource id
 */

Gantt::Gantt(int max_resource_number, int minimum_hole_duration,
	     int date, int duration, std::vector<bool> resources_vec)
  : Gantt::Gantt(max_resource_number, minimum_hole_duration)
{
  resources_vec |= zero_vec;
  
  holes[0].start_time = date;
  holes[0].holestop 
    = std::vector<StopTime>().push_back( StopTime(date + duration, resources_vec));
}

// # Creates a Gantt with 1 hole
// # arg : number of the max resource id
// sub new_with_1_hole($$$$$){
//     my $max_resource_number = shift;
//     my $minimum_hole_duration = shift;
//     my $date = shift;
//     my $duration = shift;
//     my $resources_vec = shift;

//     my $gantt = Gantt_hole_storage::new($max_resource_number, $minimum_hole_duration);

//     # Feed vector with enough 0
//     $resources_vec |= $gantt->[0]->[3];

//     $gantt->[0]->[0] = $date;
//     $gantt->[0]->[1] = [[($date + $duration), $resources_vec]];

//     return($gantt);
// }


/**
 * Adds and initializes new resources in the gantt
 * args : gantt ref, bit vector of resources
 */
int add_new_resources(Gantt *gantt, std::vector<bool> resources_vec) {

  // Feed vector with enough 0
  resources_vec |= gantt->zero_vec;

  // Verify which resources are not already inserted
  std::vector<bool> resource_to_add_vec 
    = resources_vec & ( ! gantt->holes[0].all_inserted_resources);

  if ( resource_to_add_vec != gantt->zero_vec )
    {
      // We need to insert new resources on all hole
      int i = 0;

      for(i=0; i < gantt->holes.size(); i++)
	// Add resources
	if ( gantt->.holes[i].holestop[ gantt->holes[i].holestop.size()-1 ].stop_time
	     == get_infinity_value() )
	  {
	    gant->holes[i].holestop[ gant->holes[i].holestop.size()-1 ].r 
	      |= resources_to_add_vec; 
	  }
	else
	  {
	    gantt->holes[i].holestop.push_back( StopTime(get_infinity_value(), resources_vec) );
	  }

      // Keep already inserted resources in mind
      gantt->holes[0].all_inserted_resources |= resources_vec;
    }
  return 0;
}


// # Adds and initializes new resources in the gantt
// # args : gantt ref, bit vector of resources
// sub add_new_resources($$) {
//     my ($gantt, $resources_vec) = @_;

//     # Feed vector with enough 0
//     $resources_vec |= $gantt->[0]->[3]; 
    
//     # Verify which resources are not already inserted
//     my $resources_to_add_vec = $resources_vec & (~ $gantt->[0]->[2]);
   
//     if (unpack("%32b*",$resources_to_add_vec) > 0){
//         # We need to insert new resources on all hole
//         my $g = 0;
//         while ($g <= $#{@{$gantt}}){
//             # Add resources
//             if ($gantt->[$g]->[1]->[$#{@{$gantt->[$g]->[1]}}]->[0] == $Infinity){
//                 $gantt->[$g]->[1]->[$#{@{$gantt->[$g]->[1]}}]->[1] |= $resources_to_add_vec;
//             }else{
//                 push(@{$gantt->[$g]->[1]}, [$Infinity, $resources_vec]);
//             }
//             $g++;
//         }
//         # Keep already inserted resources in mind
//         $gantt->[0]->[2] |= $resources_vec;
//     }
// }

/** Inserts in the gantt new resource occupations
    args : gantt ref, start slot date, slot duration, resources bit vector
*/
void set_occupation(Gantt *gantt, int start_date, int duration, 
		    std::vector<bool> resources_vec)
{
  // Feed vector with enough 0
    resources_vec |= gantt->zero_vec;

    // If a resource was not initialized
    add_new_resources(gantt, resources_vec); // If it is not yet done

    Hole new_hole = new Hole(date+duration+1);
    // + vecteur vide de holestop
      
    int g;
    for(g= 0;
	g <= gantt->holes.size() 
	  && gantt->holes[g].start_time <= new_hole.start_time;
	g++)

      {
        int slot_deleted = 0;
	// Look at all holes that are before the end of the occupation
        if (gantt->holes[g].holestop.size() >= 1 
	    && gantt->holes[g].holestop[ gantt.holes[g].holestop.size() -1 ].stop_time >= date)
	  {
            // Look at holes with a biggest slot >= $date
	    int h = 0;
	    int slot_date_here = 0;

	    for(h = 0; h < gantt->holes[g].holestop.size(); h++)
	      {
                // Look at all slots
		if (gantt->holes[g].holestop[h].stop_time == date)
		  slot_date_here = 1;

		if (gantt->holes[g].holestop[h].stop_time > date)
		  {
                    // This slot ends after $date
		    //print($date - $gantt->[$g]->[0]." -- $gantt->[0]->[4]\n");
		    if ( (gantt->holes[g].start_time < date)
			 && (slot_date_here == 0)
			 && ( date - gantt.holes[g].start_time > gantt.minimum_hole_duration) )
		      {
                        // We must create a smaller slot (hole start time < $date)
			gantt->holes[g].holestop.insert(h, StopTime(date, gantt->holes[g].holestop[h].r));
                        h++;   // Go to the slot that we were on it before the splice
                        slot_date_here = 1;
                    }
		    // Add new slots in the new hole
		    if ( (new_hole.start_time < gantt->holes[g].holestop[h].stop_time)
			 && ( gantt->holes[g].holestop[h].stop_time - new_hole.start_time > gantt->holes[0].minimum_hole_duration ) )
		      {
			// copy slot in the new hole if needed
                        int slot = 0;

			while( (slot <= new_hole.holestop.size() - 1 )
			       && ( new_hole.holestop[slot].stop_time < gantt->holes[g].holestop[h].stop_time ) )
			  {
			    // Find right index in the sorted slot array
                            slot++;
			  }

			if (slot <= new_hole.holestop.size() - 1)
			  {
			    if ( new_hole.holestop[slot].stop_time  == gantt->holes[g].holestop[h].stop_time )
			      {
                                // If the slot already exists, binary OR vector resources
				new_hole.holestop[slot].r |= gantt->holes[g].holestop[h].r;
			      }
			    else
			      {
                                // Insert the new slot from the gantt
				// TODO: optimiser insertion
				new_hole.holestop.insert($slot, StopTime( gantt->holes[h].holestop[h].stop_time, gant.holes[g].holestop[h].r) );
			      }
			  }
			else
			  if (new_hole.start_time < gantt->holes[g].holestop[h].stop_time)
			    {
			      // There is no slot so we create one
			      new_hole.holestop.push_back( StopTime(gantt->holes[g].holestop[h].stop_time, gantt->holes[g].holestop[h].r ) );
			    }
		      }
                    // Remove new occupied resources from the current slot
		    gant.holes[g].holestop[h].r &= ( ! resources_vec );

		    if ( gantt->holes[g].holestop[h].r == std::vector<bool>(gantt->holes[g].holestop[h].r.size(), 0) )
		      {
			// There is no free resource on this slot so we delete it
			gantt->holes[g].holestop.erase(h);
			h --;
                        slot_deleted = 1;
		      }
		  }
	      }
	  }
	
	if ( (slot_deleted == 1)
	     && ( gantt->holes.holestop.size() == 0 ))
	  {
            // There is no free slot on the current hole so we delete it
	    gantt->holes.erase[g];
            g--;
	  }


      }

}





// sub set_occupation($$$$){
//     my ($gantt, $date, $duration, $resources_vec) = @_;

//     # Feed vector with enough 0
//     $resources_vec |= $gantt->[0]->[3];

//     # If a resource was not initialized
//     add_new_resources($gantt,$resources_vec); # If it is not yet done

//     my $new_hole = [
//                         $date + $duration + 1,
//                         []
//                     ];
    
//     my $g = 0;
//     while (($g <= $#{@{$gantt}}) and ($gantt->[$g]->[0] <= $new_hole->[0])){
//         my $slot_deleted = 0;
//         # Look at all holes that are before the end of the occupation
//         if (($#{@{$gantt->[$g]->[1]}} >= 0) and ($gantt->[$g]->[1]->[$#{@{$gantt->[$g]->[1]}}]->[0] >= $date)){
//             # Look at holes with a biggest slot >= $date
//             my $h = 0;
//             my $slot_date_here = 0;
//             while ($h <= $#{@{$gantt->[$g]->[1]}}){
//                 # Look at all slots
//                 $slot_date_here = 1 if ($gantt->[$g]->[1]->[$h]->[0] == $date);
//                 if ($gantt->[$g]->[1]->[$h]->[0] > $date){
//                     # This slot ends after $date
//                     #print($date - $gantt->[$g]->[0]." -- $gantt->[0]->[4]\n");
//                     if (($gantt->[$g]->[0] < $date) and ($slot_date_here == 0) and ($date - $gantt->[$g]->[0] > $gantt->[0]->[4])){
//                         # We must create a smaller slot (hole start time < $date)
//                         splice(@{$gantt->[$g]->[1]}, $h, 0, [ $date , $gantt->[$g]->[1]->[$h]->[1] ]);
//                         $h++;   # Go to the slot that we were on it before the splice
//                         $slot_date_here = 1;
//                     }
//                     # Add new slots in the new hole
//                     if (($new_hole->[0] < $gantt->[$g]->[1]->[$h]->[0]) and ($gantt->[$g]->[1]->[$h]->[0] - $new_hole->[0] > $gantt->[0]->[4])){
//                         # copy slot in the new hole if needed
//                         my $slot = 0;
//                         while (($slot <= $#{@{$new_hole->[1]}}) and ($new_hole->[1]->[$slot]->[0] < $gantt->[$g]->[1]->[$h]->[0])){
//                             # Find right index in the sorted slot array
//                             $slot++;
//                         }
//                         if ($slot <= $#{@{$new_hole->[1]}}){
//                             if ($new_hole->[1]->[$slot]->[0] == $gantt->[$g]->[1]->[$h]->[0]){
//                                 # If the slot already exists
//                                 $new_hole->[1]->[$slot]->[1] |= $gantt->[$g]->[1]->[$h]->[1];
//                             }else{
//                                 # Insert the new slot
//                                 splice(@{$new_hole->[1]}, $slot, 0, [$gantt->[$g]->[1]->[$h]->[0], $gantt->[$g]->[1]->[$h]->[1]]);
//                             }
//                         }elsif ($new_hole->[0] < $gantt->[$g]->[1]->[$h]->[0]){
//                             # There is no slot so we create one
//                             push(@{$new_hole->[1]}, [ $gantt->[$g]->[1]->[$h]->[0], $gantt->[$g]->[1]->[$h]->[1] ]);
//                         }
//                     }
//                     # Remove new occupied resources from the current slot
//                     $gantt->[$g]->[1]->[$h]->[1] &= (~ $resources_vec) ;
//                     if (unpack("%32b*",$gantt->[$g]->[1]->[$h]->[1]) == 0){
//                         # There is no free resource on this slot so we delete it
//                         splice(@{$gantt->[$g]->[1]}, $h, 1);
//                         $h--;
//                         $slot_deleted = 1;
//                     }
//                 }
//                 # Go to the next slot
//                 $h++;
//             }
//         }
//         if (($slot_deleted == 1) and ($#{@{$gantt->[$g]->[1]}} < 0)){
//             # There is no free slot on the current hole so we delete it
//             splice(@{$gantt}, $g, 1);
//             $g--;
//         }
//         # Go to the next hole
//         $g++;
//     }
//     if ($#{@{$new_hole->[1]}} >= 0){
//         # Add the new hole
//         if (($g > 0) and ($g - 1 <= $#{@{$gantt}}) and ($gantt->[$g - 1]->[0] == $new_hole->[0])){
//             # Verify if the hole does not already exist
//             splice(@{$gantt}, $g - 1, 1, $new_hole);
//         }else{
//             splice(@{$gantt}, $g, 0, $new_hole);
//         }
//     }
// }



/** Find the first hole in the data structure that can fit the given
    slot
 */

int find_hole(Gantt *gantt, int begin_date, int duration)
{
    int end_date = begin_date + duration;
    unsigned int g = 0;
    for(g=0; g < gantt->holes.size()
	  && gantt->holes[g].start_time < begin_date
	  && gantt->holes[g].holestop.rbegin()->stop_time < end_date;
	g++);

    return g;
}

// sub find_hole($$$){
//     my ($gantt, $begin_date, $duration) = @_;

//     my $end_date = $begin_date + $duration;
//     my $g = 0;
//     while (($g <= $#{@{$gantt}}) and ($gantt->[$g]->[0] < $begin_date) and ($gantt->[$g]->[1]->[$#{@{$gantt->[$g]->[1]}}]->[0] < $end_date)){
//         $g++
//     }

//     return($g);
// }

/** Returns the vector of the maximum free resources at the given date
    for the given duration
 */

std::vector<bool> get_free_resources(Gantt *gantt, int begin_date, int duration)
{
    int end_date = begin_date + duration;
    int hole_index = 0;
    // search the nearest hole
    for(hole_index=0; hole_index < gantt->holes.size()
	  && gantt->holes[hole_index].start_time < begin_date
	  // regarder le derner stop du trou
	  && ( ( gantt->holes[hole_index].holestop.rbegin()->stop_time < end_date )
	       || (hole_index+1 < gantt->holes.size() && gantt->holes[hole_index+1].start_time < begin_date) );
	hole_index++);

    if ( hole_index >= gantt->holes.size() )
      return gantt->holes[0].minimum_hole_duration;

    int h = 0;
    for (h=0; h < gantt->holes[hole_index].holestop.size()
	   && gantt->holes[hole_index].holestop[h].stop_time < end_date;
	 h++);

    return gantt->holes[hole_index].holestop[h].r;
}

// sub get_free_resources($$$){
//     my ($gantt, $begin_date, $duration) = @_;
    
//     my $end_date = $begin_date + $duration;
//     my $hole_index = 0;
//     # search the nearest hole
//     while (($hole_index <= $#{@{$gantt}}) and ($gantt->[$hole_index]->[0] < $begin_date) and
//             (($gantt->[$hole_index]->[1]->[$#{@{$gantt->[$hole_index]->[1]}}]->[0] < $end_date) or 
//                 (($hole_index + 1 <= $#{@{$gantt}}) and $gantt->[$hole_index + 1]->[0] < $begin_date))){
//         $hole_index++;
//     }
//     return($gantt->[0]->[4]) if ($hole_index > $#{@{$gantt}});
    
//     my $h = 0;
//     while (($h <= $#{@{$gantt->[$hole_index]->[1]}}) and ($gantt->[$hole_index]->[1]->[$h]->[0] < $end_date)){
//         $h++;
//     }
//     return($gantt->[$hole_index]->[1]->[$h]->[1]);
// }


/** Take a list of resource trees and find a hole that fit 
 args : gantt ref, initial time from which the search will begin, job
 duration, list of resource trees
 */

pair<int, vector<TreeNode *> >
find_first_hole(Gantt *gantt, int initial_time, int duration,
		    vector<TreeNode *> tree_description_list, int timeout)
{
  /* $tree_description_list->[0]  --> First resource group corresponding tree
     $tree_description_list->[1]  --> Second resource group corresponding tree
     ...
  */
  
  if (tree_description_list.size() == 0 )
    return pair<int, vector<TreeNode *> >(get_infinity_value(), vector<TreeNode *>() );

  vector<TreeNode *> result_tree_list;
  int end_loop = 0;
  int current_time = initial_time;
  int timeout_initial_time = time(NULL);
  // begin research at the first potential hole
  int current_hole_index = find_hole(gantt, initial_time, duration);
  int h = 0;

  while(end_loop == 0)
    {
      // Go to a right hole
      while( (current_hole_index < gantt.holes.size())
	     && (
		 // BUG ? test bizarre, comment est-on sur de h>0 ?
		 (gantt.holes[current_hole_index].start_time + duration > gantt.holes[current_hole_index].holestop[h].stop_time) 
		 || ( (initial_time > gantt.holes[current_hole_index].start_time)
		      && (initial_time + duration > gantt.holes[current_hole_index].holestop[h].stop_time ) ) ) )
	{
	  // BUG ? surtout que l'on ne teste h que la et il commence pas a 0 
	  for( ; h < gant.hole[current_hole_index].holestop.size()
		 && ( ( gantt.holes[current_hole_index].start_time + duration
			> gantt.holes[current_hole_index].holestop[h].stop_time )
		      || ( (inital_time > gantt.holes[current_hole_index].start_time)
			   || (inital_time + duration 
			       > gantt.holes[current_hole_index].holestop[h].stop_time) 
			   ) 
		      );
	       h++);
	  
	  if (h >= gantt.holes[current_hole_index].holestop.size() )
	    {
	      // in this hole no slot fits so we must search in the next hole
	      h = 0;
	      current_hole_index++;
            }
        }
      
      if (current_hole_index >= gantt.hole.size() )
	{
	  // no hole fits
	  current_time = get_infinity_value();
	  result_tree_list = vector<TreeNode *>(0);
	  end_loop = 1;
        }
      else
	{
	  // printf("Treate hole %d, %d : %d --> %d\n", current_hole_index, h, gantt.holes[current_hole_index].start_time, gantt.holes[current_hole_index].holestop[h].stop_time);
	  if ( inital_time < gantt.holes[current_hole_index].start_time )
	    current_time = gantt.holes[current_hole_index].start_time;

	  //Check all trees
          TreeNode *tree_clone;

          int i = 0;
	  do{
	    //# clone the tree, so we can work on it without damage
	    tree_clone = oar_resource_tree::clone(tree_description_list[i]);
	    //#Remove tree leafs that are not free
	    vector<TreeNode *> vn = oar_resource_tree::get_tree_leafs(tree_clone);
	    vector<TreeNode *>::iterator l = vn.begin();
	    while( l != vn.end() )
	      {
		if ( ! gantt.holes[current_hole_index].holestop[h].r[oar_resource_tree::get_current_resource_value(l)] )
		  {
		    oar_resource_tree::delete_subtree(l);
		  }
		l++;
	      }
	    // #print(Dumper($tree_clone));
	    tree_clone = oar_resource_tree::delete_tree_nodes_with_not_enough_resources(tree_clone);
                
// #$Data::Dumper::Purity = 0;
// #$Data::Dumper::Terse = 0;
// #$Data::Dumper::Indent = 1;
// #$Data::Dumper::Deepcopy = 0;
// #                print(Dumper($tree_clone));

	      result_tree_list[i] = tree_clone;
	      i ++;
	  } while(tree_clone != NULL && (i < tree_description_list.size()));

	  if (tree_clone != NULL)
	    {
	      //# We find the first hole
	      end_loop = 1;
            }
	  else
	    {
	      //# Go to the next slot of this hole
	      if (h >= gantt.holes[current_hole_index].holestop.size() )
		{
		  h = 0;
		  current_hole_index++;
		}
	      else
		{
		  h++;
		}
            }
        }
      //# Check timeout
      // BUG: Gregory: I did not port the timeout for the moment

        // if (($current_hole_index <= $#{@{$gantt}}) and
//             (((time() - $timeout_initial_time) >= $timeout) or
//             (($gantt->[$current_hole_index]->[0] == $gantt->[0]->[5]->[0]) and ($gantt->[$current_hole_index]->[1]->[$h]->[0] >= $gantt->[0]->[5]->[1])) or
//             ($gantt->[$current_hole_index]->[0] > $gantt->[0]->[5]->[0]))){
//             if (($gantt->[0]->[5]->[0] == $gantt->[$current_hole_index]->[0]) and
//                 ($gantt->[0]->[5]->[1] > $gantt->[$current_hole_index]->[1]->[$h]->[0])){
//                 $gantt->[0]->[5]->[1] = $gantt->[$current_hole_index]->[1]->[$h]->[0];
//             }elsif ($gantt->[0]->[5]->[0] > $gantt->[$current_hole_index]->[0]){
//                 $gantt->[0]->[5]->[0] = $gantt->[$current_hole_index]->[0];
//                 $gantt->[0]->[5]->[1] = $gantt->[$current_hole_index]->[1]->[$h]->[0];
//             }
//             #print("TTTTTTT $gantt->[0]->[5]->[0] $gantt->[0]->[5]->[1] -- $gantt->[$current_hole_index]->[0] $gantt->[$current_hole_index]->[1]->[$h]->[0]\n");
//             $current_time = $Infinity;
//             @result_tree_list = ();
//             $end_loop = 1;
//         }
    }

  return pair<int, vector<TreeNode *> >(current_time, result_tree_list);
}

// sub find_first_hole($$$$$){
//     my ($gantt, $initial_time, $duration, $tree_description_list, $timeout) = @_;

//     # $tree_description_list->[0]  --> First resource group corresponding tree
//     # $tree_description_list->[1]  --> Second resource group corresponding tree
//     # ...

//     return ($Infinity, ()) if (!defined($tree_description_list->[0]));

//     my @result_tree_list = ();
//     my $end_loop = 0;
//     my $current_time = $initial_time;
//     my $timeout_initial_time = time();
//     # begin research at the first potential hole
//     my $current_hole_index = find_hole($gantt, $initial_time, $duration);
//     my $h = 0;
//     while ($end_loop == 0){
//         # Go to a right hole
//         while (($current_hole_index <= $#{@{$gantt}}) and
//                 (($gantt->[$current_hole_index]->[0] + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0]) or
//                    (($initial_time > $gantt->[$current_hole_index]->[0]) and
//                         ($initial_time + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0])))){
//             while (($h <= $#{@{$gantt->[$current_hole_index]->[1]}}) and
//                     (($gantt->[$current_hole_index]->[0] + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0]) or
//                         (($initial_time > $gantt->[$current_hole_index]->[0]) and
//                         ($initial_time + $duration > $gantt->[$current_hole_index]->[1]->[$h]->[0])))){
//                 $h++;
//             }
//             if ($h > $#{@{$gantt->[$current_hole_index]->[1]}}){
//                 # in this hole no slot fits so we must search in the next hole
//                 $h = 0;
//                 $current_hole_index++;
//             }
//         }
//         if ($current_hole_index > $#{@{$gantt}}){
//             # no hole fits
//             $current_time = $Infinity;
//             @result_tree_list = ();
//             $end_loop = 1;
//         }else{
//             #print("Treate hole $current_hole_index, $h : $gantt->[$current_hole_index]->[0] --> $gantt->[$current_hole_index]->[1]->[$h]->[0]\n");
//             $current_time = $gantt->[$current_hole_index]->[0] if ($initial_time < $gantt->[$current_hole_index]->[0]);
//             #Check all trees
//             my $tree_clone;
//             my $i = 0;
//             do{
//                 # clone the tree, so we can work on it without damage
//                 $tree_clone = oar_resource_tree::clone($tree_description_list->[$i]);
//                 #Remove tree leafs that are not free
//                 foreach my $l (oar_resource_tree::get_tree_leafs($tree_clone)){
//                     if (!vec($gantt->[$current_hole_index]->[1]->[$h]->[1],oar_resource_tree::get_current_resource_value($l),1)){
//                         oar_resource_tree::delete_subtree($l);
//                     }
//                 }
//                 #print(Dumper($tree_clone));
//                 $tree_clone = oar_resource_tree::delete_tree_nodes_with_not_enough_resources($tree_clone);
                
// #$Data::Dumper::Purity = 0;
// #$Data::Dumper::Terse = 0;
// #$Data::Dumper::Indent = 1;
// #$Data::Dumper::Deepcopy = 0;
// #                print(Dumper($tree_clone));

//                 $result_tree_list[$i] = $tree_clone;
//                 $i ++;
//             }while(defined($tree_clone) && ($i <= $#$tree_description_list));
//             if (defined($tree_clone)){
//                 # We find the first hole
//                 $end_loop = 1;
//             }else{
//                 # Go to the next slot of this hole
//                 if ($h >= $#{@{$gantt->[$current_hole_index]->[1]}}){
//                     $h = 0;
//                     $current_hole_index++;
//                 }else{
//                     $h++;
//                 }
//             }
//         }
//         # Check timeout
//         if (($current_hole_index <= $#{@{$gantt}}) and
//             (((time() - $timeout_initial_time) >= $timeout) or
//             (($gantt->[$current_hole_index]->[0] == $gantt->[0]->[5]->[0]) and ($gantt->[$current_hole_index]->[1]->[$h]->[0] >= $gantt->[0]->[5]->[1])) or
//             ($gantt->[$current_hole_index]->[0] > $gantt->[0]->[5]->[0]))){
//             if (($gantt->[0]->[5]->[0] == $gantt->[$current_hole_index]->[0]) and
//                 ($gantt->[0]->[5]->[1] > $gantt->[$current_hole_index]->[1]->[$h]->[0])){
//                 $gantt->[0]->[5]->[1] = $gantt->[$current_hole_index]->[1]->[$h]->[0];
//             }elsif ($gantt->[0]->[5]->[0] > $gantt->[$current_hole_index]->[0]){
//                 $gantt->[0]->[5]->[0] = $gantt->[$current_hole_index]->[0];
//                 $gantt->[0]->[5]->[1] = $gantt->[$current_hole_index]->[1]->[$h]->[0];
//             }
//             #print("TTTTTTT $gantt->[0]->[5]->[0] $gantt->[0]->[5]->[1] -- $gantt->[$current_hole_index]->[0] $gantt->[$current_hole_index]->[1]->[$h]->[0]\n");
//             $current_time = $Infinity;
//             @result_tree_list = ();
//             $end_loop = 1;
//         }
//     }

//     return($current_time, \@result_tree_list);
// }

// return 1;
