/*
  #!/usr/bin/perl
  # $Id$
  #-d:DProf
  
  use strict;
  use DBI();
  use oar_iolib;
  use Data::Dumper;
  use oar_Judas qw(oar_debug oar_warn oar_error set_current_log_category);
  use oar_conflib qw(init_conf dump_conf get_conf is_conf);
  use Gantt_hole_storage;
  use Storable qw(dclone);
  use Time::HiRes qw(gettimeofday);

  # Log category
  set_current_log_category('scheduler');
*/


#include "Oar_conflib.H"
#include "Oar_iolib.H"
#include "Oar_resource_tree.H" 
#include <boost/regex.h>

using namespace std;

/*
###############################################################################
# Fairsharing parameters #
##########################
*/
/// # Avoid problems if there are too many waiting jobs
static const unsigned int Karma_max_number_of_jobs_treated_per_user = 30;
///# number of seconds to consider for the fairsharing
static const unsigned int Karma_window_size = 3600 * 30 * 24;
///# specify the target percentages for project names (0 if not specified)
struct karma_proj_target_t {
  unsigned int first;
  unsigned int default;
};
const struct  karma_proj_target_t Karma_project_targets = { 75, 25 };


///# specify the target percentages for users (0 if not specified)
map<string, unsigned int> Karma_user_targets = map(pair<string, unsigned int>("oar", 100));

///# weight given to each criteria
static const unsigned int Karma_coeff_project_consumption = 0;
static const unsigend int Karma_coeff_user_consumption = 2;
static const unsigned int Karma_coeff_user_asked_consumption = 1;

//###############################################################################

static time_t initial_time;
static unsigned int timeout = 10;
static unsigned int Minimum_timeout_per_job = 2;
//# Constant duration time of a besteffort job
static const unsigned int besteffort_duration = 5*60;
// # $security_time_overhead is the security time (second) used to be sure there
// # are no problem with overlaping jobs
static unsigned int security_time_overhead = 1;
static unsigned int minimum_hole_time = 0;
//# You can add an order preference on resources assigned by the
//# system(SQL ORDER syntax)
static string Order_part;
static vector<string> Sched_available_suspended_resource_type;
static string Resources_to_always_add_type;

static vector<string> Resources_to_always_add;
static unsigned int current_time;
static string queue;


// what are timesharing gantts ?
map<pair<string, string>, Gant_hole_storage::Gantt *> timesharing_gantts;

// # Create the Gantt Diagrams
// #Init the gantt chart with all resources
Gant_hole_storage::Gantt *pgantt = 0;

// variables used in real scheduling
vector<bool> alive_resources_vector;
vector<unsigned int> Dead_resources;
vector<iolib::jobs_iolib_restrict> jobs;

// variables used in karma sorting
map<string, unsigned int> Karma_sum_time;
map<pair<string, string>, unsigned int> Karma_projects;
map<pair<string, string>, unsigned int> Karma_users;

void init_conf(int argc, char **argv)
{
  initial_time = time();

  init_conf(getenv("OARCONFFILE"));

  timeout = CONFDEFAULT_INT("SCHEDULER_TIMEOUT", "10");


  // # $security_time_overhead is the security time (second) used to be sure there
  // # are no problem with overlaping jobs
  security_time_overhead = CONFDEFAULT_INT("SCHEDULER_JOB_SECURITY_TIME", "1");

  minimum_hole_time = CONFDEFAULT_INT("SCHEDULER_GANTT_HOLE_MINIMUM_TIME", "0");
  Order_part = get_conf("SCHEDULER_RESOURCE_ORDER");

  string sched_available_suspended_resource_type_tmp = get_conf("SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE");
  if (sched_available_suspended_resource_type_tmp == "")
    Sched_available_suspended_resource_type.push_back("default");
  else
    {
      int cur_pos = 0;
      int end_pos;
      while(cur_pos < npos )
	{
	  end_pos = sched_available_suspended_resource_type_tmp.find_first_of(" ", cur_pos);
	  if (endpos != npos)
	    {
	      Sched_available_suspended_resource_type.push_back(sched_available_suspended_resource_type_tmp.substr(cur_pos, end_pos-cur_pos));
	      cur_pos = end_pos + 1;
	    }
	  else
	    {
	      Sched_available_suspended_resource_type.push_back(sched_available_suspended_resource_type_tmp.substr(cur_pos, npos));
	      cur_pos = npos;
	    }
	}
    }


  // # Look at resources that we must add for each job
  Resources_to_always_add_type = get_conf("SCHEDULER_RESOURCES_ALWAYS_ASSIGNED_TYPE");
  Resources_to_always_add;


  if (argc  < 3)
    {
      cerr << "[oar_sched_gantt_with_timesharing_and_fairsharing] no queue specified on command line" << endl;
      exit(1);
    }
  else
    {
      queue = argv[1];
      current_time = atoi( argv[2] );
    }
}

void init_sched()
{
  //# Init
  // my $base = iolib::connect();
  // my $base_ro = iolib::connect_ro();
  
  // why use two bd access ? performance ?
  // I translate with only one access
  iolib::connect();

  //oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] Begining of Gantt scheduler on queue $queue at time $current_time\n");

  // # First check states of resources that we must add for each job
  if ( Resources_to_always_add_type != "")
    {
      multimap<string, string> tmp_result_state_resources 
	= iolib::get_specific_resource_states( Resources_to_always_add_type);
      
      if ( tmp_result_state_resources.count("Suspected") > 0 )
	{
	  cerr << "[oar_sched_gantt_with_timesharing] There are resources that are specified in oar.conf (SCHEDULER_RESOURCES_ALWAYS_ASSIGNED_TYPE) which are Suspected. So I cannot schedule any job now." << endl;
	  exit(1);
	}
      else
	{
	  if (tmp_result_state_resources.count("Alive") > 0)
	      {
		// copy alive resource_id
		
		multimap<string, string>::iterator it 
		  = tmp_result_state_resources.lower_bound("Alive");
		multimap<string, string>::iterator itend 
		  = tmp_result_state_resources.upper_bound("Alive");
		
		vector<string> res_vec;
		while(it != it.end)
		  {
		    res_vec.insert( it->second );
		    it++;
		  }
		Resources_to_always_add = res_vec;

		// oar_debug("[oar_sched_gantt_with_timesharing] Assign these resources for each jobs: @Resources_to_always_add\n");
	      }
	}
    }
}


void init_gantt()
{

  // # Create the Gantt Diagrams
  // #Init the gantt chart with all resources
  unsigned int max_resources=0
  for(vector<Gant_hole_storage::resources_iolib>::it = res.begin();
      it != res.end();
      it++)
    {
      max_resources = max( max_resources, it->resource_id);
    }
  vector<bool> vec(max_resources, 0);

  vector<Gant_hole_storage::resources_iolib> res
    = iolib::list_resources();

  for(vector<Gant_hole_storage::resources_iolib>::it = res.begin();
      it != res.end();
      it++)
    {
      vec[it->resource_id] = 1;
    }

  pgantt = Gantt_hole_storage::(max_resources, minimum_hole_time);
  Gantt_hole_storage::add_new_resources(pgantt, vec);
}

static boost::regex re_plit_coma(",");
static boost::regex re_user_name("^\\s*([\\w\\*]+)\\s*$");

pair<string, string> parse_timesharing(string str,
				       string job_user,
				       string job_name )
{
  string user = "*";
  string name = "*";

  /* use boost regex instead of QtSQL (better c++ integration (string)) */
  boost::sregex_token_iterator i(s.begin(), s.end(), re_split_coma, -1);
  boost::sregex_token_iterator j;
  
  
  while(i != j)
    {
      string &s =*i;
      cmatch user_or_name;
      if ( boost::regex_match(s, user_or_name, re_user_name) )
	{
	  if  ( user_or_name[1] == "user" )
	    user = job_user;
	  else
	    if (  user_or_name[1] == "name" && job_name != "" )
	      name = job_name;
	}
      i++;
    }
  return pair<string, string>(user, name);
}

void init_gantt_scheduled_job()
{

  //# Take care of currently scheduled jobs (gantt in the database)
  // TODO: la partie order ne sert a rien ?
  pair< vector<unsigned int>, map<unsigned int, struct iolib::gantt_sched_jobs> >
    order_and_already_scheduled = iolib::get_gantt_scheduled_jobs();

  for( order_and_already_scheduled.second.iterator it
	 = order_and_already_scheduled.second.begin();
       it != order_and_already_scheduled.second.end();
       it++)
    {
      i = it->first;
      map<string, string> types = iolib::get_current_job_types(i);
      // # Do not take care of besteffort jobs
      if ( types.find("besteffort") == types.end() or
	   queue == "besteffort" )
	{
	  string user;
	  string name;

	  if ( types.find("timesharing") != types.end() )
	    {
	      pair<string, string> user_name
		=  parse_timesharing( types["timesharing"],
				      it->second.job_user, it->second.job_name);
	      string user = user_name.first;
	      string name = user_name.second;

	      if ( timesharing_gantts.find( pair<string,string>( user, name) ) == timesharing_gantts.end() )
		{
		  timesharing_gantts[pair<string,string>( user, name)] = dclone(pgantt);
		  // oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] Create new gantt for ($user, $name)\n");
		}
	    }

// foreach my $i (keys(%already_scheduled_jobs)){
//     my $types = iolib::get_current_job_types($base,$i);
//     # Do not take care of besteffort jobs
//     if ((! defined($types->{besteffort})) or ($queue eq "besteffort")){
//         my $user;
//         my $name;
//         if (defined($types->{timesharing})){
//             ($user, $name) = parse_timesharing($types->{timesharing}, $already_scheduled_jobs{$i}->[5], $already_scheduled_jobs{$i}->[6]);
//             if (!defined($timesharing_gantts->{$user}->{$name})){
//                 $timesharing_gantts->{$user}->{$name} = dclone($gantt);
//                 oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] Create new gantt for ($user, $name)\n");
//             }
//         }

	  
	  vector<unsigned int> resource_list = it->second.resource_id_vec;
	  job_duration = it->second.moldable_walltime; // TODO: est-ce bien moldable walltime ?
	  
	  if ( it->second.state == "Suspended" )
            {
	      //# Remove resources of the type specified in SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE
	      resource_list =  iolib::get_job_current_resources(it->second.moldable_id, Sched_available_suspended_resource_type);
	      if (resource_list.size() == 0)
		continue;
	    }
	  if ( it->second.state.suspended )
	    {
	      //# This job was suspended so we must recalculate the walltime
	      job_duration += iolib::get_job_suspended_sum_duration(i, current_time); // TODO: i == jobid ?
	      assert(i == it->second.job_id);
	    }

//         my @resource_list = @{$already_scheduled_jobs{$i}->[3]};
//         my $job_duration = $already_scheduled_jobs{$i}->[1];
//         if ($already_scheduled_jobs{$i}->[4] eq "Suspended"){
//             # Remove resources of the type specified in SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE
//             @resource_list = iolib::get_job_current_resources($base, $already_scheduled_jobs{$i}->[7],\@Sched_available_suspended_resource_type);
//             next if ($#resource_list < 0);
//         }
//         if ($already_scheduled_jobs{$i}->[8] eq "YES"){
//             # This job was suspended so we must recalculate the walltime
//             $job_duration += iolib::get_job_suspended_sum_duration($base,$i,$current_time);
//         }
	  unsigned int max_resources = *max_element(resource_list.begin()
						    resource_list.end());
	  vector<bool> vec(max_resources, 0);
	  for(resource_list.iterator r = resource_list.begin();
	      r != resource_list.end();
	      r++)
	    vec[*r]=1;
	  

//         my $vec = '';
//         foreach my $r (@resource_list){
//             vec($vec,$r,1) = 1;
//         }
	  //#Fill all other gantts
	  for( timesharing_gantts.iterator itts = timesharing_gantts.begin();
	       itts != timesharing_gantts.end();
	       itts++)
	    {
	      u = itts->first.first;
	      n = itts->first.second;

	      if (user == ""
		  || name == ""
		  || u != user
		  || n != name)
		{
		  Gantt_hole_storage::set_occupation(itts->second,
						     it->second.start_time,
						     job_duration + security_time_overhead,
						     vec
						     );
		}
	    }

	  Gantt_hole_storage::set_occupation( pgantt,
					      it->second.start_time,
					      job_duration + security_time_overhead,
					      vec);
	}
    }
}

//         #Fill all other gantts
//         foreach my $u (keys(%{$timesharing_gantts})){
//             foreach my $n (keys(%{$timesharing_gantts->{$u}})){
//                 if ((!defined($user)) or (!defined($name)) or (($u ne $user) or ($n ne $name))){
//                     Gantt_hole_storage::set_occupation($timesharing_gantts->{$u}->{$n},
//                                             $already_scheduled_jobs{$i}->[0],
//                                             $job_duration + $security_time_overhead,
//                                             $vec
//                                          );
//                 }
//             }
//         }
//         Gantt_hole_storage::set_occupation(  $gantt,
//                                   $already_scheduled_jobs{$i}->[0],
//                                   $job_duration + $security_time_overhead,
//                                   $vec
//                              );
//     }
// }

//oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] End gantt initialization\n");

/********** # End of the initialisation ************/


void real_scheduling_begin()
{
  //# Begining of the real scheduling

  //# Get list of Alive resources
  vector<iolib::resources_iolib> resource_list = iolib::get_resources_in_state($base,"Alive");
  unsigned int max_resources=0;
  for(resource_list.iterator r = resource_list.begin();
      r != resource_list.end();
      r++)
    max_resources = max( max_resources, r->resource_id ); 

  alive_resources_vector = vector<bool>(max_resources, 0);
  for(resource_list.iterator r = resource_list.begin();
      r != resource_list.end();
      r++)
    alive_resources_vector[r->resource_id]=1;

   resource_list = iolib::get_resources_in_state($base,"Dead");
   for(resource_list.iterator r = resource_list.begin();
      r != resource_list.end();
      r++)
     Dead_resources.push_back(r->resource_id);

   jobs = iolib::get_fairsharing_jobs_to_schedule(queue, Karma_max_number_of_jobs_treated_per_user);
}

/*
###############################################################################
# Sort jobs depending on their previous usage
# Karma sort algorithm
*/

void karma_sort()
{
  Karma_sum_time = iolib::get_sum_accounting_window(queue, current_time - Karma_window_size, current_time);
  if (Karma_sum_time.find("ASKED") == Karma_sum_time.end() )
    Karma_sum_time["ASKED"] = 1;
  if (Karma_sum_time.find("ASKED") == Karma_sum_time.end() )
    Karma_sum_time["ASKED"] = 1;
  

  Karma_projects = iolib::get_sum_accounting_for_param(queue,"accounting_project", current_time - Karma_window_size, current_time);
  Karma_users = iolib::get_sum_accounting_for_param(queue,"accounting_user", current_time - Karma_window_size, current_time);
}

int karma(iolib::jobs_iolib_restrict j)
{
  int note = 0;
  note = Karma_coeff_project_consumption * (( Karma_projects[pair<string,string>(j.project,"USED")] / Karma_sum_time["USED"]) - ( Karma_project_targets[j.project] / 100));
  note += Karma_coeff_user_consumption * (( Karma_users[pair<string, string>(j.job_user, "USED")] / Karma_sum_time["USED"]) - (Karma_user_targets[j.project] / 100));
  note += Karma_coeff_user_asked_consumption * ((Karma_users[pair<string,string>(j.job_user,"ASKED")] / Karma_sum_time["ASKED"]) - (Karma_user_targets[j.project] / 100));

  return(note);
}

struct less_jobs_iolib_restrict : public binary_function<iolib::jobs_iolib_restrict, iolib::jobs_iolib_restrict, bool> {
  bool operator()(iolib::jobs_iolib_restrict a, iolib::jobs_iolib_restrict b)
  {
    return karma(a) < karma(b);
  }
}

//###############################################################################

void real_scheduler_main()
{
  // sort jobs by karma
  sort(jobs.begin(), jobs.end(), less_jobs_iolib_restrict());

  int job_index = 0;
  
  while ((job_index <= jobs.size() ) and ((time() - initial_time) < timeout))
    {
      iolib::jobs_iolib_restrict j = jobs[job_index];
      job_index ++;
    
      oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] [" + j.job_id + "] Start scheduling (Karma note = " + karma($j) + ")\n");

      unsigned int scheduler_init_date = current_time;
      //# Search for dependencies
      int skip_job = 0;

      // skip jobs if it is not ready
      vector<unsigned int> vjobdep = iolib::get_current_job_dependencies(j.job_id);
      for(unisgend int d = vjobdep.begin();
	  d != vjobdep.end(); vjobdep++)
	{
	  if (skip_job)
	    break;

	  jobs_get_job_iolib_restrict dep_job =  iolib::get_job_restrict(d);
	  if (dep_job.state != "Terminated")
	    {
	      gantt_job_start_time date_tmp = iolib::get_gantt_job_start_time(d);
	      if (date_tmp.start_time != 0 || date_tmp.moldable_job_id != 0)
		{
		  unsigned int mold_dep_moldable_walltime = iolib::get_current_moldable_job(date_tmp.moldable_job_id);
		  unsigned int sched_tmp = date_tmp.start_time +  mold_dep_moldable_walltime;
		  if ( scheduler_init_date < sched_tmp)
		    {
		      scheduler_init_date = sched_tmp;
		    }
		}
	      else
		{
		  string message = "Cannot determine scheduling time due to dependency with the job "<< d;
		  iolib::set_job_message(j.job_id, message);
		  oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] ["+j.job_id+"] "+message+"\n");
		  skip_job = 1;
		  break;
		}
	    } 
	  else
	    if ((dep_job.job_type == "PASSIVE") && (dep_job.exit_code != 0))
	      {
		string message = "Cannot determine scheduling time due to dependency with the job "+ d +<< "(exit code != 0)";
		iolib::set_job_message(j.job_id, message);
		oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] ["+j.job_id+"] "+message+"\n");
		skip_job = 1;
		break;
	      }
	}

    if (skip_job == 1)
      continue;
     
    Gant_hole_storage::Gantt *gantt_to_use = pgantt;
    map<string, string> types = iolib::get_current_job_types(j.job_id);
    if ( types.find("timesharing") != types.end() )
      {
        pair<string, string> user_name = parse_timesharing(types["timesharing"], j.job_user, j.job_name);
	
	if ( timesharing_gantts.find(user_name) == timesharing_gantts.end() )
	  {
	    timesharing_gantts[user_name] = oar_resource_tree::dclone(gantt);
            oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] Create new gantt in phase II for ("+user_name.first+" "+user_name.second+")\n");
	  }
        gantt_to_use = timesharing_gantts[user_name];
        oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] Use gantt for ("+user_name.first+" "+user_name.second+"\n");
      }
    //#oar_debug("[oar_sched_gantt_with_timesharing] Use gantt for $j->{job_id}:\n".Gantt_hole_storage::pretty_print($gantt_to_use)."\n");

    string job_properties = "'1'";
    if (j.properties != "")
      {
	job_properties = j.properties;
      }
    
    //# Choose the moldable job to schedule
    // TODO: type ???
    my @moldable_results;

    vector<resources_data_moldable> job_descriptions = iolib::get_resources_data_structure_current_job(j.job_id);
    for(vector<property_resources_per_job>::iterator moldable = job_descriptions[0].prop_res.begin();
	moldable != job_descriptions[0].prop_res.end();
	moldable++)
      {
	//#my $moldable = $job_descriptions->[0];
        unsigned int duration;

        if (types.find("besteffort") != types.end() )
	  {
            duration = besteffort_duration;
	  }
	else
	  {
            duration = moldable->walltime + security_time_overhead;
	  }

        //# CM part
	  vector<bool> alive_resources_vector_store = alive_resources_vector;
	  if ( conflib::is_conf("SCHEDULER_NODE_MANAGER_WAKE_UP_CMD") )
	    {
	      /**** TODO TO DO ****/

            foreach my $r (iolib::get_resources_that_can_be_waked_up($base, iolib::get_date($base) + $duration)){
                vec($alive_resources_vector, $r->{resource_id}, 1) = 1;
            }
            foreach my $r (iolib::get_resources_that_will_be_out($base, iolib::get_date($base) + $duration)){
                vec($alive_resources_vector, $r->{resource_id}, 1) = 0;
            }
            my $str_tmp = "state_num ASC, cm_availability DESC";
            if (defined($Order_part)){
                $Order_part = $str_tmp.",".$Order_part;
            }else{
                $Order_part = $str_tmp;
            }
        }
        # CM part
        
        my $resource_id_used_list_vector = '';
        my @tree_list;
        foreach my $m (@{$moldable->[0]}){
            my $tmp_properties = "\'1\'";
            if ((defined($m->{property})) and ($m->{property} ne "")){
                $tmp_properties = $m->{property};
            }
            my $tmp_tree = iolib::get_possible_wanted_resources($base_ro,$alive_resources_vector,$resource_id_used_list_vector,\@Dead_resources,"$job_properties AND $tmp_properties", $m->{resources}, $Order_part);
            push(@tree_list, $tmp_tree);
            my @leafs = oar_resource_tree::get_tree_leafs($tmp_tree);
            foreach my $l (@leafs){
                vec($resource_id_used_list_vector, oar_resource_tree::get_current_resource_value($l), 1) = 1;
            }
        }
        my $gantt_timeout =  ($timeout - (time() - $initial_time)) / 4;
        $gantt_timeout = $Minimum_timeout_per_job if ($gantt_timeout < ($timeout / 3));
        oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] [$j->{job_id}] find_first_hole with a timeout of $gantt_timeout\n");
        my @hole = Gantt_hole_storage::find_first_hole($gantt_to_use, $scheduler_init_date, $duration, \@tree_list,$gantt_timeout);
        
#        print("[GANTT] 10 ".gettimeofday."\n");
        my @res_trees;
        my @resources;
        foreach my $t (@{$hole[1]}){
#        print("[GANTT] 11 ".gettimeofday."\n");
            my $minimal_tree = oar_resource_tree::delete_unnecessary_subtrees($t);
#        print("[GANTT] 12 ".gettimeofday."\n");
            push(@res_trees, $minimal_tree);
            foreach my $r (oar_resource_tree::get_tree_leafs($minimal_tree)){
                push(@resources, oar_resource_tree::get_current_resource_value($r));
            }
#        print("[GANTT] 13 ".gettimeofday."\n");
        }
        push(@moldable_results, {
                                    resources => \@resources,
                                    start_date => $hole[0],
                                    duration => $duration,
                                    moldable_id => $moldable->[2]
                                });
        # CM part
        $alive_resources_vector = $alive_resources_vector_store ;
        # CM part
    }

    # Choose moldable job which will finish the first
    my $index_to_choose = -1;
    my $best_stop_time;
#        print("[GANTT] 14 ".gettimeofday."\n");
    for (my $i=0; $i <= $#moldable_results; $i++){
        #my @tmp_array = @{$moldable_results[$i]->{resources}};
        if ($#{@{$moldable_results[$i]->{resources}}} >= 0){
            my $tmp_stop_date = $moldable_results[$i]->{start_date} + $moldable_results[$i]->{duration};
            if ((!defined($best_stop_time)) or ($best_stop_time > $tmp_stop_date)){
                $best_stop_time = $tmp_stop_date;
                $index_to_choose = $i;
            }
        }
    }
    if ($index_to_choose >= 0){
        # We can schedule the job
#        print("[GANTT] 15 ".gettimeofday."\n");
        my $vec = '';
        foreach my $r (@{$moldable_results[$index_to_choose]->{resources}}){
            vec($vec, $r, 1) = 1;
        }
        Gantt_hole_storage::set_occupation(    $gantt,
                                    $moldable_results[$index_to_choose]->{start_date},
                                    $moldable_results[$index_to_choose]->{duration},
                                    $vec
                                );
        #Fill all other gantts
        foreach my $u (keys(%{$timesharing_gantts})){
#        print("[GANTT] 17 ".gettimeofday."\n");
            foreach my $n (keys(%{$timesharing_gantts->{$u}})){
                if (($gantt_to_use != $timesharing_gantts->{$u}->{$n})){
                    Gantt_hole_storage::set_occupation(  $timesharing_gantts->{$u}->{$n},
                                              $moldable_results[$index_to_choose]->{start_date},
                                              $moldable_results[$index_to_choose]->{duration},
                                              $vec
                                         );
                }
            }
        }
        
        #update database
        push(@{$moldable_results[$index_to_choose]->{resources}},@Resources_to_always_add);
        iolib::add_gantt_scheduled_jobs($base,$moldable_results[$index_to_choose]->{moldable_id}, $moldable_results[$index_to_choose]->{start_date},$moldable_results[$index_to_choose]->{resources});
        iolib::set_job_message($base,$j->{job_id},"Karma = ".sprintf("%.3f",karma($j)));
    }else{
        my $message = "Cannot find enough resources which fit for the job $j->{job_id}";
        iolib::set_job_message($base,$j->{job_id},$message);
        oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] [$j->{job_id}] $message\n");
    }
#        print("[GANTT] 18 ".gettimeofday."\n");
    oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] [$j->{job_id}] End scheduling\n");
}


iolib::disconnect($base);
iolib::disconnect($base_ro);

if ($job_index <= $#jobs){
    oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing_and_fairsharing] I am not able to schedule all waiting jobs in the specified time : $timeout s\n");
}

oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] End of scheduler for queue $queue\n");

