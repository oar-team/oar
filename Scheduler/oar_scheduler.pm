package oar_scheduler;

use Data::Dumper;
use strict;
use warnings;
use oar_iolib;
use Gant;
use oar_Judas qw(oar_debug oar_warn oar_error);

#minimum of seconds between each jobs
my $security_time_overhead = 1;

# waiting time when a reservation has not all of its nodes
my $reservationWaitingTimeout = 300;

# global variables : initialized in init_scheduler function
my %reservationJobsNodes;
my %besteffortNodesOccupation;
my %node_max_weight;

my $current_time_sql = 0;
my $current_time_sec = "0000-00-00 00:00:00";

# Give initial time in second and sql formats in a hashtable.
sub get_initial_time(){
    my %time = (
                "sec" => $current_time_sec,
                "sql" => $current_time_sql
              );
    return(%time);
}

#Initialize Gantt tables with scheduled reservation jobs, Running jobs, toLaunch jobs and Launching jobs;
# arg1 --> database ref
sub init_scheduler($){
    my $dbh = shift;

    # Create the list of nodes and the hash table of their weight
    my @alive_nodes = iolib::get_alive_node($dbh);
    foreach my $node (@alive_nodes) {
        $node_max_weight{$node} = iolib::get_maxweight_one_node($dbh, $node);
    }

    #my $gant = Gant::create_empty_gant($current_time_sec, \%node_max_weight);
    

    # Take care of the currently (or nearly) running jobs
    # Lock to prevent bipbip update in same time
    $dbh->do("LOCK TABLE jobs WRITE, processJobs WRITE, ganttJobsPrediction WRITE, ganttJobsNodes WRITE");
   
    #calculate now date with no overlap with other jobs
    my $previousRefTimeSec = iolib::sql_to_local(iolib::get_gantt_date($dbh));
    $current_time_sec = iolib::sql_to_local(iolib::get_date($dbh));
    if ($current_time_sec < $previousRefTimeSec){
        # The system is very fast!!!
        $current_time_sec = $previousRefTimeSec;
    }
    $current_time_sec++;
    $current_time_sql = iolib::local_to_sql($current_time_sec);

   
    iolib::gantt_flush_tables($dbh);
    iolib::set_gantt_date($dbh,$current_time_sql);
    
    my @initial_jobs;
    push(@initial_jobs, iolib::get_jobs_in_state($dbh, "Running"));
    push(@initial_jobs, iolib::get_jobs_in_state($dbh, "toLaunch"));
    push(@initial_jobs, iolib::get_jobs_in_state($dbh, "Launching"));

    my $gant = Gant::create_empty_gant($current_time_sec, \%node_max_weight);
    
    foreach my $i (@initial_jobs){
        # The list of nodes on which the job is running
        my @node_list = iolib::get_job_host_distinct($dbh, $i->{idJob});

        my $date ;
        if ($i->{startTime} eq "0000-00-00 00:00:00") {
            $date = $current_time_sql;
        }elsif (iolib::sql_to_local($i->{startTime}) + iolib::sql_to_duration($i->{maxTime}) < $current_time_sec){
            $date = iolib::local_to_sql($current_time_sec - iolib::sql_to_duration($i->{maxTime}));
        }else{
            $date = $i->{startTime};
        }
        oar_debug("[oar_scheduler] init_scheduler : add in gantt job $i->{idJob}\n");
        iolib::add_gantt_scheduled_jobs($dbh,$i->{idJob},$date,\@node_list);

        # Treate besteffort jobs like nothing!
        if ($i->{queueName} ne "besteffort"){
            Gant::set_occupation($gant,
                                 iolib::sql_to_local($date),
                                 $i->{weight},
                                 iolib::sql_to_duration($i->{maxTime}) + $security_time_overhead,
                                 \@node_list
                                );
        }else{
            #Stock information about besteffort jobs
            foreach my $j (@node_list){
                push(@{$besteffortNodesOccupation{$j}}, $i->{idJob});
            }
        }
    }
    $dbh->do("UNLOCK TABLES");

    #Add in Gantt reserved jobs already scheduled
    my @Rjobs = iolib::get_waiting_reservation_jobs($dbh);
    foreach my $job (@Rjobs){
        #my @available_nodes = iolib::get_really_alive_node_job($dbh, $job->{idJob}, $job->{weight});
        my @available_nodes = iolib::get_alive_node_job($dbh, $job->{idJob}, $job->{weight});
        my @gantt_nodes = Gant::available_nodes($gant,
                                                $job->{weight},
                                                iolib::sql_to_local($job->{startTime}),
                                                iolib::sql_to_duration($job->{maxTime}) + $security_time_overhead,
                                                \@available_nodes
                                               );
        my @assignedNodes;
        #order hostname with Alive nodes first
        @gantt_nodes = iolib::order_property_node($dbh, \@gantt_nodes, "n.state ASC");
        #Attach nodes to a reservation
        while (($#gantt_nodes >= 0) && (($#assignedNodes+1) < $job->{nbNodes})){
            push(@assignedNodes, shift(@gantt_nodes));
        }
        if ($#assignedNodes >= 0){
            my $startTime = $job->{startTime};
            if (iolib::sql_to_local($startTime) < $current_time_sec){
                $startTime = $current_time_sql;
            }
            Gant::set_occupation($gant,
                                 iolib::sql_to_local($startTime),
                                 $job->{weight},
                                 iolib::sql_to_duration($job->{maxTime}) + $security_time_overhead,
                                 \@assignedNodes
                                );
            oar_debug("[oar_scheduler] init_scheduler : add in gantt reservation job $job->{idJob}\n");
            iolib::add_gantt_scheduled_jobs($dbh,$job->{idJob},$startTime,\@assignedNodes);
            $reservationJobsNodes{$job->{idJob}} = \@assignedNodes;
        }
    }
    #Gant::pretty_print_gant($gant);
}


# launch right reservation jobs
# arg1 : database ref
# arg2 : queue name
# return 1 if there is at least a job to treate, 2 if besteffort jobs must die
sub treate_waiting_reservation_jobs($$){
    my $dbh = shift;
    my $queueName = shift;

    oar_debug("[oar_scheduler] treate_waiting_reservation_jobs : Search for waiting reservations in $queueName queue\n");

    my $return = 0;

    my @arrayJobs = iolib::get_waiting_reservation_jobs_specific_queue($dbh,$queueName);
    # See if there are reserved jobs to launch
    foreach my $job (@arrayJobs){
        my $start = iolib::sql_to_local($job->{startTime});
        my $max = iolib::sql_to_duration($job->{maxTime});
        # Test if the job is in the paste
        if ($current_time_sec > $start+$max ){
            oar_debug("[oar_scheduler] treate_waiting_reservation_jobs :  Reservation $job->{idJob} in ERROR\n");
            iolib::set_job_state($dbh, $job->{idJob}, "Error");
            iolib::set_job_message($dbh,$job->{idJob},"[oar_scheduler] Reservation has expired and it cannot be started.");
            $return = 1;
        }
        my $nbNodes = scalar(iolib::get_gantt_Alive_nodes_for_job($dbh,$job->{idJob}));
        # test if the job is going to be launched and there is no Alive node
        if (($nbNodes == 0) && (iolib::sql_to_local($job->{startTime}) <= $current_time_sec)){
            oar_debug("[oar_scheduler] Reservation $job->{idJob} is in waiting mode because no node is present\n");
            iolib::set_gantt_job_startTime($dbh,$job->{idJob},iolib::local_to_sql($current_time_sec + 1));
        }elsif (($nbNodes < $job->{nbNodes}) && (iolib::sql_to_local($job->{startTime}) <= $current_time_sec) && (iolib::sql_to_local($job->{startTime}) + $reservationWaitingTimeout > $current_time_sec)){
            # we have not the same number of nodes than in the query --> wait the specified timeout
            oar_debug("[oar_scheduler] Reservation $job->{idJob} is in waiting mode because all nodes are not yet available : $nbNodes/$job->{nbNodes}\n");
            iolib::set_gantt_job_startTime($dbh,$job->{idJob},iolib::local_to_sql($current_time_sec + 1));
        }elsif(iolib::sql_to_local($job->{startTime}) <= $current_time_sec){
            #Check if nodes are in Alive state otherwise remove them, the job is going to be launched
            my @nodeList = iolib::get_gantt_nodes_for_job($dbh, $job->{idJob}); 
            my $nbNodes = 0;
            foreach my $n (@nodeList){
                my $nodeInfo = iolib::get_node_info($dbh,$n);
                if ($nodeInfo->{state} ne "Alive"){
                    oar_debug("[oar_scheduler] Reservation $job->{idJob} : remove node $n because it state is $nodeInfo->{state}\n");
                    iolib::remove_gantt_node_job($dbh, $job->{idJob}, $n);
                }else{
                    $nbNodes++;
                }
            }
            if ($nbNodes < $job->{nbNodes}){
                iolib::set_job_number_of_nodes($dbh, $job->{idJob}, $nbNodes);
                iolib::add_new_event($dbh,"SCHEDULER_REDUCE_NB_NODES_FOR_RESERVATION",$job->{idJob},"[oar_scheduler] Reduce the number of nodes for the job $job->{idJob} from $job->{nbNodes} to $nbNodes");
            }
        }
    }

    return($return);
}


# check for jobs with reservation
# arg1 : database ref
# arg2 : queue name
# return 1 if there is at least a job to treate else 0
sub check_reservation_jobs($$){
    my $dbh = shift;
    my $queueName = shift;

    oar_debug("[oar_scheduler] check_reservation_jobs : Check for new reservation in the $queueName queue\n");

    my $return = 0;

    my $gant = Gant::create_empty_gant($current_time_sec, \%node_max_weight);

    # Find jobs to check
    my @jobsToSched = iolib::get_waiting_toSchedule_reservation_jobs_specific_queue($dbh,$queueName);
    if ($#jobsToSched >= 0){
        # Build gantt diagram of other jobs
        # Take care of currently scheduled jobs except besteffort jobs if queueName is not besteffort
        my %alreadyScheduledJobs = iolib::get_gantt_scheduled_jobs($dbh);
        foreach my $i (keys(%alreadyScheduledJobs)){
            if (($alreadyScheduledJobs{$i}->[3] ne "besteffort") || ($queueName eq "besteffort")){
                Gant::set_occupation($gant,
                                     iolib::sql_to_local($alreadyScheduledJobs{$i}->[0]),
                                     $alreadyScheduledJobs{$i}->[1],
                                     iolib::sql_to_duration($alreadyScheduledJobs{$i}->[2]) + $security_time_overhead,
                                     $alreadyScheduledJobs{$i}->[4]
                                    );
            }
        }
        #Gant::pretty_print_gant($gant);
    }
    foreach my $job (@jobsToSched){
        #look if reservation is too old
        if ($current_time_sec >= (iolib::sql_to_local($job->{startTime}) + iolib::sql_to_duration($job->{maxTime}))){
            oar_debug("[oar_scheduler] check_reservation_jobs : Cancel reservation $job->{idJob}, job is too old\n");
            iolib::set_job_state($dbh, $job->{idJob}, "toError");
        }else{
            if (iolib::sql_to_local($job->{startTime}) < $current_time_sec){
                $job->{startTime} = $current_time_sql;
                iolib::set_running_date_arbitrary($dbh,$job->{idJob},$current_time_sql);
            }
            my @available_nodes = iolib::get_alive_node_job($dbh, $job->{idJob}, $job->{weight});
            my @gantt_nodes = Gant::available_nodes($gant,
                                                    $job->{weight},
                                                    iolib::sql_to_local($job->{startTime}),
                                                    iolib::sql_to_duration($job->{maxTime}) + $security_time_overhead,
                                                    \@available_nodes
                                                   );
            my @assignedNodes;
            while (($#gantt_nodes >= 0) && (($#assignedNodes+1) < $job->{nbNodes})){
                push(@assignedNodes, shift(@gantt_nodes));
            }
            if ($#assignedNodes == ($job->{nbNodes} - 1)){
                Gant::set_occupation($gant,
                                     iolib::sql_to_local($job->{startTime}),
                                     $job->{weight},
                                     iolib::sql_to_duration($job->{maxTime}) + $security_time_overhead,
                                     \@assignedNodes
                                    );
                oar_debug("[oar_scheduler] check_reservation_jobs : Confirm reservation $job->{idJob} and add in gantt\n");
                iolib::add_gantt_scheduled_jobs($dbh,$job->{idJob},$job->{startTime},\@assignedNodes);
                $reservationJobsNodes{$job->{idJob}} = \@assignedNodes;
                iolib::set_job_state($dbh, $job->{idJob}, "toAckReservation");
            }else{
                oar_debug("[oar_scheduler] check_reservation_jobs : Cancel reservation $job->{idJob}, not enough nodes\n");
                iolib::set_job_state($dbh, $job->{idJob}, "toError");
            }
        }
        iolib::set_job_resa_state($dbh, $job->{idJob}, "Scheduled");
        $return = 1;
    }
    return($return);
}


# Detect if there are besteffort jobs to kill
# arg1 --> database ref
# return 1 if there is at least 1 job to frag otherwise 0
sub check_jobs_to_kill($){
    my $dbh = shift;

    oar_debug("[oar_scheduler] check_jobs_to_kill : check besteffort jobs\n");
    my $return = 0;
    my %nodesForJobsToLaunch = iolib::get_gantt_nodes_for_jobs_to_launch($dbh,$current_time_sql); 
    foreach my $node (keys(%nodesForJobsToLaunch)){
        if (defined($besteffortNodesOccupation{$node})){
            foreach my $j (@{$besteffortNodesOccupation{$node}}){
                oar_debug("[oar_scheduler] check_jobs_to_kill : besteffort job $j must be killed\n");
                iolib::add_new_event($dbh,"BESTEFFORT_KILL",$j,"[oar_scheduler] kill the besteffort job $j");
                iolib::frag_job($dbh, $j);
            }
            $return = 1;
        }
     }
     return($return);
}



# Detect if there are jobs to launch
# arg1 --> database ref
# return 1 if there is at least 1 job to launch otherwise 0
sub check_jobs_to_launch($){
    my $dbh = shift;

    oar_debug("[oar_scheduler] check_jobs_to_launch : check jobs with a start time <= $current_time_sql\n");
    my $returnCode = 0;
    my %jobs_to_launch = iolib::get_gantt_jobs_to_launch($dbh,$current_time_sql);
    foreach my $i (keys(%jobs_to_launch)){
        oar_debug("[oar_scheduler] check_jobs_to_launch : set job $i in state toLaunch ($current_time_sql)\n");
        iolib::set_job_state($dbh, $i, "toLaunch");
        iolib::set_running_date_arbitrary($dbh,$i,$current_time_sql);
        foreach my $n (@{$jobs_to_launch{$i}->[1]}){
            iolib::add_node_job_pair($dbh,$i,$n);
            $dbh->do("LOCK TABLE nodes WRITE");
            iolib::set_weight_node($dbh,$n,iolib::get_weight_node($dbh,$n) + $jobs_to_launch{$i}->[0]);
            $dbh->do("UNLOCK TABLES");
        }
        $returnCode = 1;
    }

    return($returnCode);
}

#Update gantt visualization tables with new scheduling
#arg : database ref
sub update_gantt_visu_tables($){
    my $dbh = shift;

    iolib::update_gantt_visualization($dbh); 
}

return 1;
