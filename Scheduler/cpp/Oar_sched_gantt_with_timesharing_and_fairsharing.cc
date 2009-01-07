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

using namespace std;

/*
###############################################################################
# Fairsharing parameters #
##########################
*/
/// # Avoid problems if there are too many waiting jobs
const unsigned int Karma_max_number_of_jobs_treated_per_user = 30;
///# number of seconds to consider for the fairsharing
const unsigned int Karma_window_size = 3600 * 30 * 24;
///# specify the target percentages for project names (0 if not specified)
struct karma_proj_target_t {
  unsigned int first;
  unsigned int default;
};
const struct  karma_proj_target_t Karma_project_targets = { 75, 25 };


///# specify the target percentages for users (0 if not specified)
map<string, unsigned int> Karma_user_targets = map(pair<string, unsigned int>("oar", 100));

///# weight given to each criteria
const unsigned int Karma_coeff_project_consumption = 0;
const unsigend int Karma_coeff_user_consumption = 2;
const unsigned int Karma_coeff_user_asked_consumption = 1;

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
# Init
my $base = iolib::connect();
my $base_ro = iolib::connect_ro();

oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] Begining of Gantt scheduler on queue $queue at time $current_time\n");

# First check states of resources that we must add for each job
if (defined($Resources_to_always_add_type)){
    my $tmp_result_state_resources = iolib::get_specific_resource_states($base,$Resources_to_always_add_type);
    if ($#{@{$tmp_result_state_resources->{"Suspected"}}} >= 0){
        oar_warn("[oar_sched_gantt_with_timesharing] There are resources that are specified in oar.conf (SCHEDULER_RESOURCES_ALWAYS_ASSIGNED_TYPE) which are Suspected. So I cannot schedule any job now.\n");
        exit(1);
    }else{
        if (defined($tmp_result_state_resources->{"Alive"})){
            @Resources_to_always_add = @{$tmp_result_state_resources->{"Alive"}};
            oar_debug("[oar_sched_gantt_with_timesharing] Assign these resources for each jobs: @Resources_to_always_add\n");
        }
    }
}


my $timesharing_gantts;
# Create the Gantt Diagrams
#Init the gantt chart with all resources
my $vec = '';
my $max_resources = 1;
foreach my $r (iolib::list_resources($base)){
    vec($vec,$r->{resource_id},1) = 1;
    $max_resources = $r->{resource_id} if ($r->{resource_id} > $max_resources);
}

my $gantt = Gantt_hole_storage::new($max_resources, $minimum_hole_time);
Gantt_hole_storage::add_new_resources($gantt, $vec);

sub parse_timesharing($$$){
    my $str = shift;
    my $job_user = shift;
    my $job_name = shift;
            
    my $user = "*";
    my $name = "*";
    foreach my $s (split(',', $str)){
        if ($s =~ m/^\s*([\w\*]+)\s*$/m){
            if ($1 eq "user"){
                $user = $job_user;
            }elsif (($1 eq "name") and ($job_name ne "")){
                $name = $job_name;
            }
        }
    }

    return($user,$name);
}

# Take care of currently scheduled jobs (gantt in the database)
my ($order, %already_scheduled_jobs) = iolib::get_gantt_scheduled_jobs($base);
foreach my $i (keys(%already_scheduled_jobs)){
    my $types = iolib::get_current_job_types($base,$i);
    # Do not take care of besteffort jobs
    if ((! defined($types->{besteffort})) or ($queue eq "besteffort")){
        my $user;
        my $name;
        if (defined($types->{timesharing})){
            ($user, $name) = parse_timesharing($types->{timesharing}, $already_scheduled_jobs{$i}->[5], $already_scheduled_jobs{$i}->[6]);
            if (!defined($timesharing_gantts->{$user}->{$name})){
                $timesharing_gantts->{$user}->{$name} = dclone($gantt);
                oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] Create new gantt for ($user, $name)\n");
            }
        }
        my @resource_list = @{$already_scheduled_jobs{$i}->[3]};
        my $job_duration = $already_scheduled_jobs{$i}->[1];
        if ($already_scheduled_jobs{$i}->[4] eq "Suspended"){
            # Remove resources of the type specified in SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE
            @resource_list = iolib::get_job_current_resources($base, $already_scheduled_jobs{$i}->[7],\@Sched_available_suspended_resource_type);
            next if ($#resource_list < 0);
        }
        if ($already_scheduled_jobs{$i}->[8] eq "YES"){
            # This job was suspended so we must recalculate the walltime
            $job_duration += iolib::get_job_suspended_sum_duration($base,$i,$current_time);
        }

        my $vec = '';
        foreach my $r (@resource_list){
            vec($vec,$r,1) = 1;
        }
        #Fill all other gantts
        foreach my $u (keys(%{$timesharing_gantts})){
            foreach my $n (keys(%{$timesharing_gantts->{$u}})){
                if ((!defined($user)) or (!defined($name)) or (($u ne $user) or ($n ne $name))){
                    Gantt_hole_storage::set_occupation($timesharing_gantts->{$u}->{$n},
                                            $already_scheduled_jobs{$i}->[0],
                                            $job_duration + $security_time_overhead,
                                            $vec
                                         );
                }
            }
        }
        Gantt_hole_storage::set_occupation(  $gantt,
                                  $already_scheduled_jobs{$i}->[0],
                                  $job_duration + $security_time_overhead,
                                  $vec
                             );
    }
}

oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] End gantt initialization\n");

# End of the initialisation
}

# Begining of the real scheduling

# Get list of Alive resources
my $alive_resources_vector = '';
foreach my $r (iolib::get_resources_in_state($base,"Alive")){
    vec($alive_resources_vector, $r->{resource_id}, 1) = 1;
}

my @Dead_resources;
foreach my $r (iolib::get_resources_in_state($base,"Dead")){
    push(@Dead_resources, $r->{resource_id});
}

my @jobs = iolib::get_fairsharing_jobs_to_schedule($base,$queue,$Karma_max_number_of_jobs_treated_per_user);
###############################################################################
# Sort jobs depending on their previous usage
# Karma sort algorithm
my $Karma_sum_time = iolib::get_sum_accounting_window($base,$queue,$current_time - $Karma_window_size,$current_time);
$Karma_sum_time->{ASKED} = 1 if (!defined($Karma_sum_time->{ASKED}));
$Karma_sum_time->{USED} = 1 if (!defined($Karma_sum_time->{USED}));

my $Karma_projects = iolib::get_sum_accounting_for_param($base,$queue,"accounting_project",$current_time - $Karma_window_size,$current_time);
my $Karma_users = iolib::get_sum_accounting_for_param($base,$queue,"accounting_user",$current_time - $Karma_window_size,$current_time);

sub karma($){
    my $j = shift;

    my $note = 0;
    $note = $Karma_coeff_project_consumption * (($Karma_projects->{$j->{project}}->{USED} / $Karma_sum_time->{USED}) - ($Karma_project_targets->{$j->{project}} / 100));
    $note += $Karma_coeff_user_consumption * (($Karma_users->{$j->{job_user}}->{USED} / $Karma_sum_time->{USED}) - ($Karma_user_targets->{$j->{project}} / 100));
    $note += $Karma_coeff_user_asked_consumption * (($Karma_users->{$j->{job_user}}->{ASKED} / $Karma_sum_time->{ASKED}) - ($Karma_user_targets->{$j->{project}} / 100));

    return($note);
}

###############################################################################

@jobs = sort({karma($a) <=> karma($b)} @jobs);
my $job_index = 0;
while (($job_index <= $#jobs) and ((time() - $initial_time) < $timeout)){
    my $j = $jobs[$job_index];
    $job_index ++;
    
    oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] [$j->{job_id}] Start scheduling (Karma note = ".karma($j).")\n");
    
    my $scheduler_init_date = $current_time;
    # Search for dependencies
    my $skip_job = 0;
    foreach my $d (iolib::get_current_job_dependencies($base,$j->{job_id})){
        next if ($skip_job == 1);
        my $dep_job = iolib::get_job($base,$d);
        if (($dep_job->{state} ne "Terminated")){
            my @date_tmp = iolib::get_gantt_job_start_time($base,$d);
            if (defined($date_tmp[0])){
                my $mold_dep = iolib::get_current_moldable_job($base,$date_tmp[1]);
                my $sched_tmp = $date_tmp[0] + $mold_dep->{moldable_walltime};
                if ($scheduler_init_date < $sched_tmp){
                    $scheduler_init_date = $sched_tmp;
                }
            }else{
                my $message = "Cannot determine scheduling time due to dependency with the job $d";
                iolib::set_job_message($base,$j->{job_id},$message);
                oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] [$j->{job_id}] $message\n");
                $skip_job = 1;
                next;
            }
        }elsif (($dep_job->{job_type} eq "PASSIVE") and ($dep_job->{exit_code} != 0)){
            my $message = "Cannot determine scheduling time due to dependency with the job $d (exit code != 0)";
            iolib::set_job_message($base,$j->{job_id},$message);
            oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] [$j->{job_id}] $message\n");
            $skip_job = 1;
            next;
        }
    }
    next if ($skip_job == 1);
     
    my $gantt_to_use = $gantt;
    my $types = iolib::get_current_job_types($base,$j->{job_id});
    if (defined($types->{timesharing})){
        my ($user, $name) = parse_timesharing($types->{timesharing}, $j->{job_user}, $j->{job_name});
        if (!defined($timesharing_gantts->{$user}->{$name})){
            $timesharing_gantts->{$user}->{$name} = dclone($gantt);
            oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] Create new gantt in phase II for ($user, $name)\n");
        }
        $gantt_to_use = $timesharing_gantts->{$user}->{$name};
        oar_debug("[oar_sched_gantt_with_timesharing_and_fairsharing] Use gantt for ($user,$name)\n");
    }
    #oar_debug("[oar_sched_gantt_with_timesharing] Use gantt for $j->{job_id}:\n".Gantt_hole_storage::pretty_print($gantt_to_use)."\n");

    my $job_properties = "\'1\'";
    if ((defined($j->{properties})) and ($j->{properties} ne "")){
        $job_properties = $j->{properties};
    }
    
    # Choose the moldable job to schedule
    my @moldable_results;
    my $job_descriptions = iolib::get_resources_data_structure_current_job($base,$j->{job_id});
    foreach my $moldable (@{$job_descriptions}){
    #my $moldable = $job_descriptions->[0];
        my $duration;
        if (defined($types->{besteffort})){
            $duration = $besteffort_duration;
        }else{
            $duration = $moldable->[1] + $security_time_overhead;
        }

        # CM part
        my $alive_resources_vector_store = $alive_resources_vector;
        if (is_conf("SCHEDULER_NODE_MANAGER_WAKE_UP_CMD")){
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

