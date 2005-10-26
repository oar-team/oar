# $Id: Gant.pm,v 1.21 2004/08/24 16:10:34 neyron Exp $
package Gant;
require Exporter;
use lib '../Judas/';
use oar_Judas qw(oar_debug oar_warn oar_error);

# Prototypes
# gant chart management
sub create_empty_gant($$);

# Internal management
# Fields access
sub get_node($$);
sub get_weight($$);
sub get_begin($$);
sub get_end($$);
sub get_prev_node($$);
sub get_next_node($$);
sub get_prev_sorted($$);
sub get_next_sorted($$);
sub set_node($$$);
sub set_weight($$$);
sub set_begin($$$);
sub set_end($$$);
sub set_prev_node($$$);
sub set_next_node($$$);
sub set_prev_sorted($$$);
sub set_next_sorted($$$);

# Linked lists management
sub add_tuple_after($$$$$);
sub remove_tuple($$$$);
		    
# Intervals management
sub add_interval_after($$$$);
sub remove_interval($$);
sub fuse_if_necessary($$);

# A gant chart is a flatened array of tuples (elements have to be interpreted
# by group of 8).
# The very first tuple is used as a sentinel for the list sorted tuples and
# the list of free tuples (not linked by te same field).
# In other cases, tuples specify intervals with the following
# fields (self explanatory except for next_node which is the index of
# the next free interval (resp. prev) for the same node and next_sorted
# which is the index of the next (resp. prev) tuple according to the order
# induced by the begin field) :
# (node, weight, begin, end, prev_node, next_node, prev_sorted, next_sorted)
# No interval associated to the same node do overlap.
# The following are used as offset the manipulate the fields
my $node_offset = 0;
my $weight_offset = 1;
my $begin_offset = 2;
my $end_offset = 3;
my $prev_node = 4;
my $next_node = 5;
my $prev_sorted = 6;
my $next_sorted = 7;
# Each sub list of sorted intervals by node should have its own sentinel which
# is referenced by a hash table of nodes of the chart.
# Three fields of the global sentinel have a special meaning :
# the $node field should always be undef
# the $weight field is undef and means this is a sentinel tuple
# the $weight field is used to store the reference to the hash of node sentinels
my $hash_offset = 2;
my $is_sentinel = 1;
my $free_offset = 4;
# An end field set to undef means infinity for the end of the interval.

# ASSUMPTION
# we always maintain the list of tuple forming the gant chart sorted
# in the order of the begin field.

sub get_node($$)
{
  my ($gant,$index)=@_;

  return $gant->[$index+$node_offset];
}

sub get_weight($$)
{
  my ($gant,$index)=@_;

  return $gant->[$index+$weight_offset];
}

sub get_next_free_node($)
{
    my ($gant) = @_;
    return $gant->[$free_offset];
}

sub get_begin($$)
{
  my ($gant,$index)=@_;

  return $gant->[$index+$begin_offset];
}

sub get_end($$)
{
  my ($gant,$index)=@_;

  return $gant->[$index+$end_offset];
}

sub get_prev_node($$)
{
  my ($gant,$index)=@_;

  return $gant->[$index+$prev_node];
}

sub get_next_node($$)
{
  my ($gant,$index)=@_;

  return $gant->[$index+$next_node];
}

sub get_prev_sorted($$)
{
  my ($gant,$index)=@_;

  return $gant->[$index+$prev_sorted];
}

sub get_next_sorted($$)
{
  my ($gant,$index)=@_;

  return $gant->[$index+$next_sorted];
}

sub is_normal_node($$)
{
  my ($gant,$index)=@_;
    
  return (defined($gant->[$index+$is_sentinel]));
}

sub get_nodes_hash($) 
{
    my ($gant) = @_;
    return $gant->[$hash_offset];
}

sub set_node($$$)
{
  my ($gant,$index,$value)=@_;

  $gant->[$index+$node_offset] = $value;
}

sub set_weight($$$)
{
  my ($gant,$index,$value)=@_;

  $gant->[$index+$weight_offset] = $value;
}

sub set_begin($$$)
{
  my ($gant,$index,$value)=@_;

  $gant->[$index+$begin_offset] = $value;
}

sub set_end($$$)
{
  my ($gant,$index,$value)=@_;

  $gant->[$index+$end_offset] = $value;
}

sub set_prev_node($$$)
{
  my ($gant,$index,$value)=@_;

  $gant->[$index+$prev_node] = $value;
}

sub set_next_node($$$)
{
  my ($gant,$index,$value)=@_;

  $gant->[$index+$next_node] = $value;
}

sub set_prev_sorted($$$)
{
  my ($gant,$index,$value)=@_;

  $gant->[$index+$prev_sorted] = $value;
}

sub set_next_sorted($$$)
{
  my ($gant,$index,$value)=@_;

  $gant->[$index+$next_sorted] = $value;
}

sub set_next_free_node($$)
{
    my ($gant, $node) = @_;
    $gant->[$free_offset] = $node;
}


sub pretty_print_tuple($$) {
    my ($gant, $index) = @_;

    my $node = get_node($gant, $index);
    if (!defined($node)) { $node = "Undef"; }
    my $begin = get_begin($gant, $index);
    if (!defined($begin)) { $begin = "Undef"; }
    my $end = get_end($gant, $index);
    if (!defined($end)) { $end = "Undef"; }
    my $weight = get_weight($gant, $index);
    if (!defined($weight)) { $weight = "Undef"; }
    print "Int. #$index ($begin, $end) on node \"$node\" with weight $weight\n";
}

sub pretty_print_gant($) 
{
    my ($gant) = @_;
    my $index = get_next_sorted($gant, 0);
    
    print "Interval list\n";
    while(is_normal_node($gant, $index)) {
	pretty_print_tuple($gant, $index);
	$index = get_next_sorted($gant, $index);
    }

    my $hash = get_nodes_hash($gant);
    for my $n (keys %{$hash}) {
	$index = get_next_node($gant, $hash->{$n});
	print "\nOn node $n:\n";
	while(is_normal_node($gant, $index)) {
	    if(!(get_node($gant, $index) eq $n)) {
		print "ALERT !! \n"; }
	    pretty_print_tuple($gant, $index);
	    $index = get_next_node($gant, $index);
	}
    }
}

# TODO:
# get_max_weight($node)
sub get_max_weight($) {
    return 1;
}

# insert the already "allocated" tuple indexed by $current_tuple
# after the $prev_tuple indicated using the linkage given by the
# two offsets
# Yoyo: Je trouve ca dommage de ne pas utiliser les accesseurs.
sub add_tuple_after($$$$$) 
{
  my ($array,$prev_tuple,$current_tuple,$prev_offset,$next_offset)=@_;
  my $next_tuple;

  $next_tuple = $array->[$prev_tuple+$next_offset];
  $array->[$prev_tuple+$next_offset] = $current_tuple;
  $array->[$next_tuple+$prev_offset] = $current_tuple;
  $array->[$current_tuple+$next_offset] = $next_tuple;
  $array->[$current_tuple+$prev_offset] = $prev_tuple;
}

# remove the tuple indicated by $current_tuple using the linkage
# given by the two offsets. DOES NOT "free" the tuple.
sub remove_tuple($$$$)
{
  my ($array,$current_tuple,$prev_offset,$next_offset)=@_;
  my ($prev_tuple, $next_tuple);

  $next_tuple = $array->[$current_tuple+$next_offset];
  $prev_tuple = $array->[$current_tuple+$prev_offset];
  $array->[$prev_tuple+$next_offset] = $next_tuple;
  $array->[$next_tuple+$prev_offset] = $prev_tuple;
}

# free the tuple $interval
#    DOES NOT unlink the tuple
sub free_tuple($$) {
    my ($gant, $interval)=@_;

    set_next_node($gant, $interval, get_next_free_node($gant));
    set_next_free_node($gant, $interval);
}

# allocate_tuple 
#    allocates a new tuple
#    returns the index of the tuple
sub allocate_tuple($$$$$) {
    my ($gant, $node, $weight, $begin, $end) = @_;
    my $index;

    # take a new tuple, create it if there are no more free_node
    if (!is_normal_node($gant, get_next_free_node($gant))) {
	# need some new nodes
	$index = $#{$gant} + 1;
# 	print "Needed new nodes, returned $index\n";
    } else {
	$index = get_next_free_node($gant);
	set_next_free_node($gant, get_next_node($gant, $index));
    }
    set_node($gant, $index, $node);
    set_weight($gant, $index, $weight);
    set_begin($gant, $index, $begin);
    set_end($gant, $index, $end);

    set_next_node($gant, $index, undef);
    set_prev_node($gant, $index, undef);
    set_next_sorted($gant, $index, undef);
    set_prev_sorted($gant, $index, undef);
    return $index;
}

# Creates an empty Gant
# Parameters : the time of creation of the world
#              a ref to a hashtable node names <-> max weight

sub create_empty_gant($$)
{
    my ($now, $nodes) = @_;
  # first sentinel :
  # this is the global sentinel : first field is undef
  # this is a sentinel : second field is undef
  # link to an empty hash table
  # this is the sentinel of the list of free tuples :
  #      linkage to self in fields 4 and 5.
  # this is the sentinel of the list of sorted free intervals :
  #      linkage to self in fields 6 and 7.
    my $result = [undef, undef, {}, undef, 0, 0, 0, 0];
  
    for my $n (keys %{$nodes}) {
	$maxweight = $nodes->{$n};
	insert_new_node($result, $n, $maxweight, $now);
    }
    
    return $result;
}


# create_node_sentinel
# Parameters : Gantt chart and node name
# Creates a new sentinel for the interval list by node
# Inserts the sentinel into the hashtable
sub create_node_sentinel($$) {
    my ($gant, $node) = @_;

#     print "Creating node sentinel for node $node\n";

    my $result = allocate_tuple($gant, $node, undef, undef, undef);
    set_next_node($gant, $result, $result);
    set_prev_node($gant, $result, $result);

    my $hash = get_nodes_hash($gant);
    $hash->{$node} = $result;
    return $result;

}

# Add a new node (machine) in the Gant
# Creates a [0, Undef] interval with weight maxweight
# to indicate that this machine is free from now on.
sub insert_new_node($$$$) {
    my ($gant, $node, $maxweight, $start_time) = @_;

    my $node_hash = get_nodes_hash($gant);
    die "Already existing node $node" if defined($node_hash->{$node});
      
    $sentinel = create_node_sentinel($gant, $node); 
    my $t = allocate_tuple($gant, $node, $maxweight, $start_time, undef);
    add_interval_after($gant, $t, 0, $sentinel);
}

sub add_interval_after($$$$) {
    my ($gant, $index, $prev_sorted_tuple, $prev_node_tuple) = @_;
    
    add_tuple_after($gant, $prev_sorted_tuple, $index, $prev_sorted, $next_sorted);
    add_tuple_after($gant, $prev_node_tuple, $index, $prev_node, $next_node);

}


# Parameters :
# - reference to a Gant chart
# - index in the gant chart of an interval entry to remove
sub remove_interval($$)
{
  my ($gant, $interval) = @_;
  my $prev;
  my $next;
  my $sentinel;

  # first, manage the links regarding the global sorted list

# Ca c'est sale.
#   $prev = $gant->[$interval+$prev_sorted];
#  $next = $gant->[$interval+$next_sorted];
#  $gant->[$prev+$next_sorted] = $next;
#  $gant->[$next+$prev_sorted] = $prev;

  remove_tuple($gant, $interval, $prev_sorted, $next_sorted);

# Ou la deuxième version :-)
#  $prev = get_prev_sorted($gant, $interval);
#  $next = get_next_sorted($gant, $interval);
#  set_next_sorted($gant, $prev, $next);
#  set_prev_sorted($gant, $next, $prev);


  remove_tuple($gant, $interval, $prev_node, $next_node);
  
# Ou la deuxième version :-)
#  $next = get_next_node($gant, $interval);
#  $prev = get_prev_node($gant, $interval);
#  set_next_node($gant, $prev, $next);
#  set_prev_node($gant, $next, $prev);


  # if next = prev then the tuple about to be suppressed is the
  # last one of its node and we might suppress as well its sentinel
  # node. 


#  if ($next == $prev)
#    {
#     $sentinel = $prev;

      # ${$gant->[$hash_offset]}{$gant->[$sentinel+$node_index]} = undef;
      # Yoyo: Ca, ca ne marche pas. Cf test_gant.pl
      # Du coup, je vire tout ca et je laisse la sentinelle tout seule.
#      $prev = $gant->[$sentinel+$prev_sorted];
#      $next = $gant->[$sentinel+$next_sorted];
#      $gant->[$prev+$next_sorted] = $next;
#      $gant->[$next+$prev_sorted] = $prev;

      # The sentinel tuple is put in the free node list
#      free_tuple($gant, $sentinel);
#   }

  # finally, add the unused tuple to the list of free tuples

  free_tuple($gant, $interval);
}


# add the interval $interval after the nodes
# $node_prev_sorted for the global list and
# $node_prev_node for the node list
sub add_after_interval($$$$)
{
  my ($gant, $interval, $node_prev_sorted, $node_prev_node) = @_;

  add_tuple_after($gant, $node_prev_sorted, $interval, $prev_sorted, $next_sorted);
  add_tuple_after($gant, $node_prev_node, $interval, $prev_node, $next_node);
}


# Parameters :
# - reference to a Gant chart
# - index in the gant chart of the second interval (possibly to fuse with
#   the previous one in the list
# Returns the index of the last resulting interval.
sub fuse_if_necessary($$)
{
  my ($gant, $second) = @_;
  my $first = get_prev_node($gant, $second);

#   print "Trying to fusion.\n";
#   pretty_print_tuple($gant, $first);
#   pretty_print_tuple($gant, $second);

  die "Abnormal interval chaining" unless ((!is_normal_node($gant, $first))
					   || (defined(get_end($gant, $first))
					       && get_end($gant, $first) == get_begin($gant, $second)));

  if (is_normal_node($gant, $first) 
      && (get_weight($gant, $first) == get_weight($gant, $second)) ) {
     
      set_end($gant, $first, get_end($gant, $second));
      remove_interval($gant, $second);
      return $first;
  } else {
      return $second;
  }
}

sub set_occupation($$$$$)
{
    # Est-ce que $duration peut etre infinie ??
  my ( $gant, $date, $required_weight, $duration, $nodes_list)=@_;
  my %required_nodes; # a hashtable for quick decision whether a node is required or not
  my ($node, $weight, $begin, $end);
  my ($next_node, $next_weight, $next_begin, $next_end);

  my $occup_end = $date + $duration;
  my $where = 0; # 0 au début, 1 au milieu, 2 à la fin.

  my $waiting_intervals = 0;

#  oar_debug "Setting Occupation from $date for $duration, w = $required_weight, on @{$nodes_list}\n";

   for my $node (@{$nodes_list}) 
   {
#	insert_new_node_if_necessary($gant, $node);
	$required_nodes{$node} = -1;
    }
  # iterates through the sorted list of free intervals

  # TODO : Il faudrait commencer par vérifier que c'est possible.
  # Guillaume dit que non.

  my $index = $gant->[$next_sorted];
  do {
      while (is_normal_node($gant, $index)) {
	  $node = get_node($gant, $index);
	  $begin = get_begin($gant, $index);
	  
	  # Ici je fais l'insertion des intervalles en attente.
	  if ( (($where == 0) && ($begin >= $date))
	       || (($where == 1) && ($begin >= $occup_end)) ){
	      for my $n (keys %required_nodes) {
		  my $new = $required_nodes{$n};
		  if ($new != -1) {
		      die "Is this normal ??" unless (get_begin($gant, $new) <= $begin);
		      if (defined(get_next_node($gant, $new))) {
			  $required_nodes{$n} = get_next_node($gant, $new);
		      } else {
			  $required_nodes{$n} = -1;
		      }
		      add_interval_after($gant, $new, get_prev_sorted($gant, $index),
					 get_prev_node($gant, $new));
		      $waiting_intervals--;
		      $index = $new;
		  }
	      }
	      $where++;
	  }
	  
	  $next = get_next_sorted($gant, $index); # Pour éviter les mauvaises surprises dues aux fusions
#   	  print ("Parcours en cours... \n\t");
#  	  pretty_print_tuple($gant, $index);
#  	  pretty_print_gant($gant);
	  $node = get_node($gant, $index); # $index peut avoir changé après l'insertion
	  $begin = get_begin($gant, $index);
	  
	  if (defined($required_nodes{$node})) {
#	      print "Interesting node\n";
	      $end =  get_end($gant, $index);
	      if ( ($occup_end > $begin) && (!defined($end) || ($date < $end)) ) {
#		  print "Interesting time\n";
		  $weight = get_weight($gant, $index);
		  if ($date > $begin) {
#		      print "Date > Begin\n";
		      set_end($gant, $index, $date);
		      my $new = allocate_tuple($gant, $node, $weight, $date, $end);
		      $required_nodes{$node} = $new;
		      $waiting_intervals++;
		      set_prev_node($gant, $new, $index);
		  } else { # Here $date <= $begin
#		      print "Date < Begin\n";
		      set_weight($gant, $index, $weight - $required_weight);
		      
		      $index = fuse_if_necessary($gant, $index);
		      
		      if ( (!defined($end)) || ($end > $occup_end) ) {
			  set_end($gant, $index, $occup_end); # On tronque l'intervalle courant
			  # Et on cree un intervalle apres.
			  my $new = allocate_tuple($gant, $node, $weight, $occup_end, $end);
			  die "Ach, Das ist niche gut" unless ($required_nodes{$node} == -1);
			  $required_nodes{$node} = $new;
			  $waiting_intervals++;
			  set_prev_node($gant, $new, $index); # The full chaining will be done later.
		      } elsif (defined($end) && ($end == $occup_end)) {
			  fuse_if_necessary($gant, get_next_node($gant, $index));
		      }
		  }
	      }
	  }
	  $index = $next;
	  
      }

      if ($where < 2) {
	  for  $n (keys %required_nodes) {
	      $new = $required_nodes{$n};
	      if ($new != -1) {
		  if (defined(get_next_node($gant, $new))) {
		      $required_nodes{$n} = get_next_node($gant, $new);
		  } else {
		      $required_nodes{$n} = -1;
		  }
		  add_interval_after($gant, $new, get_prev_sorted($gant, $index),
				     get_prev_node($gant, $new));
		  $waiting_intervals--;
		  $index = $new;
	      }
	  }
	  $where++;
      }

  } until ($where >= 2);

}

# Find_stop_time
# Returns the last time after the beginning of interval $interval
#  so that at least $required_weight weight is available on the node.
# Returns -1 if $interval does not have the required weight.
sub find_stop_time($$$) 
{
    my($gant, $interval, $required_weight) = @_;
    
    my $result = -1;
    my $index = $interval;
    while(is_normal_node($gant, $index)) {
	my $weight = get_weight($gant, $index);
	if($weight < $required_weight) {
	    return $result;
	} else {
	    $result = get_end($gant, $index);
	    $index = get_next_node($gant, $index);
	}
    }
    return $result;
}



# Find First Hole
# Looks for some place in the Gantt to schedule something
# Returns a list, the first element is the starting time of the block
# The others are the nodes that are available. There are at least
# $nb_nodes_required, but may be more.

# Please make sure that there are enough nodes with maxweight >=
# required_weight.
# Else you're going to kill me...

sub find_first_hole($$$$$)
{
  my ($gant, $nb_nodes_required, $required_weight, $required_duration, $nodes_list) = @_;
  my %stop_time;
 
#  oar_debug "Searching Hole of $nb_nodes_required nodes for $required_duration, w = $required_weight, on @{$nodes_list}\n"; 
  
  for my $node (@{$nodes_list}) {
      $stop_time{$node} = -1;
#      insert_new_node_if_necessary($gant, $node);
  }
  
  my $current_time = 0;
  my $index = get_next_sorted($gant, 0);
  while(is_normal_node($gant, $index)) {
      my $begin = get_begin($gant, $index);
      my $end = get_end($gant, $index);
      my $weight = get_weight($gant, $index);
      local $node = get_node($gant, $index);
      
      if ($begin > $current_time) {
	  local $nb_ok_nodes = 0; # De toute facon je vais tout parcourir...
	                       # Si je pouvais je ferai pas comme ca, mais ca a pas l'air facile.
	  local @ok_nodes = ();
	  push @ok_nodes, $current_time;
          for my $n (keys %stop_time) {
	      my $stop = $stop_time{$n};
	      if( (!defined($stop)) || (($stop - $current_time) >= $required_duration) ) {
		  $nb_ok_nodes++;
		  push @ok_nodes, $n;
	      } else {
		  $stop_time{$n} = -1;
	      }
	  }
	  if ($nb_ok_nodes >= $nb_nodes_required) {
	      return @ok_nodes;
	  }
	  
	  $current_time = $begin;
      }
      
      if (defined($stop_time{$node}) && ($stop_time{$node} == -1)) {
	  my $stop = find_stop_time($gant, $index, $required_weight);
	  $stop_time{$node} = $stop;

	  # Ca la c'est meme pas necessaire...
	  if( (!defined($stop)) || (($stop - $current_time) >= $required_duration) ) {
	      $nb_ok_nodes++;
	  }
      }

      $index = get_next_sorted($gant, $index);
  }


  local @ok_nodes = ();
  push @ok_nodes, $current_time;
  for my $n (keys %stop_time) {
      my $stop = $stop_time{$n};
      if( (!defined($stop)) || (($stop - $current_time) >= $required_duration) ) {
	  $nb_ok_nodes++;
	  push @ok_nodes, $n;
      } else {
	  $stop_time{$n} = -1;
      }
  }
  if ($nb_ok_nodes >= $nb_nodes_required) {
      return @ok_nodes;
  }

  print "Je devrais pas etre la !!\n";
  print "Time = $current_time \n";
  for my $n (keys %stop_time) {
      print "($n, $stop_time{$n})\n";
  }

  die "Argh. What's going on ?";
}

# Available Nodes
# Gives the list of nodes with enough free weight (at least $required_weight)
# between $begin_date and $begin_date+$required_duration. Consider only the nodes in $nodes_list

sub available_nodes($$$$$)
{
    my ($gant, $required_weight, $begin_date, $required_duration, $nodes_list) = @_;
    
    my $end_date = $begin_date + $required_duration; 
    my $hash = get_nodes_hash($gant);

    my @available_nodes = ();

    for my $node (@{$nodes_list}) {
	
	if (defined($hash->{$node})) {
	    my $index = get_next_node($gant, $hash->{$node});
	    my $is_available = 1;
	    while (is_normal_node($gant, $index)) {
		my $b = get_begin($gant, $index);
		my $e = get_end($gant, $index);
		my $w = get_weight($gant, $index);

		last if($b >= $end_date);

		if( (!defined($e)) || $begin_date < $e) {
		    $is_available = 0, last if ($w < $required_weight);
		}
		$index = get_next_node($gant, $index);
	    }
	    push @available_nodes, $node if ($is_available == 1);
	}
	else { push @available_nodes, $node; }
    }

    return @available_nodes;

}
