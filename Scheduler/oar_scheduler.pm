package oar_scheduler;

use Data::Dumper;
use strict;
use warnings;
use oar_iolib;
use Gantt;
use oar_Judas qw(oar_debug oar_warn oar_error);

#minimum of seconds between each jobs
my $security_time_overhead = 1;

# waiting time when a reservation has not all of its nodes
my $reservationWaitingTimeout = 300;

# global variables : initialized in init_scheduler function
my %besteffort_resource_occupation;

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

    # Take care of the currently (or nearly) running jobs
    # Lock to prevent bipbip update in same time
    $dbh->do("LOCK TABLE jobs WRITE, assignedResources WRITE, ganttJobsPredictions WRITE, ganttJobsResources WRITE, job_types WRITE");
   
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

    my $gantt = Gantt::new();
    
    foreach my $i (@initial_jobs){
        # The list of resources on which the job is running
        my @resource_list = iolib::get_job_current_resources($dbh, $i->{assignedMoldableJob});

        my $date ;
        if ($i->{startTime} eq "0000-00-00 00:00:00") {
            $date = $current_time_sql;
        }elsif (iolib::sql_to_local($i->{startTime}) + iolib::sql_to_duration($i->{maxTime}) < $current_time_sec){
            $date = iolib::local_to_sql($current_time_sec - iolib::sql_to_duration($i->{maxTime}));
        }else{
            $date = $i->{startTime};
        }
        oar_debug("[oar_scheduler] init_scheduler : add in gantt job $i->{idJob}\n");
        iolib::add_gantt_scheduled_jobs($dbh,$i->{assignedMoldableJob},$date,\@resource_list);

        # Treate besteffort jobs like nothing!
        my $types_hash = iolib::get_current_job_types($dbh, $i->{idJob});
        if (!defined($types_hash->{besteffort})){
            foreach my $r (@resource_list){
                Gantt::set_occupation(  $gantt,
                                        iolib::sql_to_local($date),
                                        iolib::sql_to_duration($i->{maxTime}) + $security_time_overhead,
                                        $r
                                     );
            }
        }else{
            #Stock information about besteffort jobs
            foreach my $j (@resource_list){
                $besteffort_resource_occupation{$j} = $i->{assignedMoldableJob};
            }
        }
    }
    $dbh->do("UNLOCK TABLES");

    #Add in Gantt reserved jobs already scheduled
    my @Rjobs = iolib::get_waiting_reservation_jobs($dbh);
    foreach my $job (@Rjobs){
        my $job_descriptions = iolib::get_resources_data_structure_current_job($dbh,$job->{idJob});
        # For reservation we take the first moldable job
        my $moldable = $job_descriptions->[0];
        my @available_resources;
        my @tmp_resource_list;
        # Get the list of resources where the reservation will be able to be launched
        push(@tmp_resource_list, iolib::get_resources_in_state($dbh,"Alive"));
        push(@tmp_resource_list, iolib::get_resources_in_state($dbh,"Absent"));
        push(@tmp_resource_list, iolib::get_resources_in_state($dbh,"Suspected"));
        foreach my $r (@tmp_resource_list){
            if (Gantt::is_resource_free($gantt,
                                        iolib::sql_to_local($job->{startTime}),
                                        iolib::sql_to_duration($moldable->[1]) + $security_time_overhead,
                                        $r->{resourceId}
                                       ) == 1
               ){                       
                push(@available_resources, $r->{resourceId});
            }
        }
        
        my $job_properties = "TRUE";
        if ($job->{properties} ne ""){
            $job_properties = $job->{properties};
        }

        my @resource_id_used_list;
        my @tree_list;
        foreach my $m (@{$moldable->[0]}){
            my $tmp_properties = "TRUE";
            if ($m->{property} ne ""){
                $tmp_properties = $m->{property};
            }
            my $tmp_tree = iolib::get_possible_wanted_resources($dbh,\@available_resources,\@resource_id_used_list,"$job_properties AND $tmp_properties", $m->{resources});
            push(@tree_list, $tmp_tree);
            my @leafs = oar_resource_tree::get_tree_leafs($tmp_tree);
            foreach my $l (@leafs){
                push(@resource_id_used_list, oar_resource_tree::get_current_resource_value($l));
            }
        }
        
        my @res_trees;
        my @resources;
        foreach my $t (@tree_list){
            my $minimal_tree = oar_resource_tree::delete_unnecessary_subtrees($t);
            push(@res_trees, $minimal_tree);
            foreach my $r (oar_resource_tree::get_tree_leafs($minimal_tree)){
                push(@resources, oar_resource_tree::get_current_resource_value($r));
            }
        }
        
        if ($#resources >= 0){
            # We can schedule the job
            foreach my $r (@resources){
                Gantt::set_occupation(  $gantt,
                                        iolib::sql_to_local($job->{startTime}),
                                        iolib::sql_to_duration($moldable->[1]) + $security_time_overhead,
                                        $r
                                     );
            }
            # Update database
            iolib::add_gantt_scheduled_jobs($dbh,$moldable->[2],$job->{startTime},\@resources);
        }
    }
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
        my $job_descriptions = iolib::get_resources_data_structure_current_job($dbh,$job->{idJob});
        my $moldable = $job_descriptions->[0];
    
        my $start = iolib::sql_to_local($job->{startTime});
        my $max = iolib::sql_to_duration($moldable->[1]);
        # Test if the job is in the paste
        if ($current_time_sec > $start+$max ){
            oar_debug("[oar_scheduler] treate_waiting_reservation_jobs :  Reservation $job->{idJob} in ERROR\n");
            iolib::set_job_state($dbh, $job->{idJob}, "Error");
            iolib::set_job_message($dbh,$job->{idJob},"[oar_scheduler] Reservation has expired and it cannot be started.");
            $return = 1;
        }
        my @resa_alive_resources = iolib::get_gantt_Alive_resources_for_job($dbh,$moldable->[2]);
        # test if the job is going to be launched and there is no Alive node
        if (($#resa_alive_resources < 0) && (iolib::sql_to_local($job->{startTime}) <= $current_time_sec)){
            oar_debug("[oar_scheduler] Reservation $job->{idJob} is in waiting mode because no resource is present\n");
            iolib::set_gantt_job_startTime($dbh,$job->{idJob},iolib::local_to_sql($current_time_sec + 1));
        }elsif(iolib::sql_to_local($job->{startTime}) <= $current_time_sec){
            my @resa_resources = iolib::get_gantt_resources_for_job($dbh,$moldable->[2]);
            if ((iolib::sql_to_local($job->{startTime}) + $reservationWaitingTimeout > $current_time_sec)){
                if ($#resa_resources > $#resa_alive_resources){
                    # we have not the same number of nodes than in the query --> wait the specified timeout
                    oar_debug("[oar_scheduler] Reservation $job->{idJob} is in waiting mode because all nodes are not yet available.\n");
                    iolib::set_gantt_job_startTime($dbh,$job->{idJob},iolib::local_to_sql($current_time_sec + 1));
                }
            }else{
                #Check if resources are in Alive state otherwise remove them, the job is going to be launched
                foreach my $r (@resa_resources){
                    my $resource_info = iolib::get_resource_info($dbh,$r);
                    if ($resource_info->{state} ne "Alive"){
                        oar_debug("[oar_scheduler] Reservation $job->{idJob} : remove resource $r because it state is $resource_info->{state}\n");
                        iolib::remove_gantt_resource_job($dbh, $moldable->[2], $r);
                    }
                }
                if ($#resa_resources > $#resa_alive_resources){
                    iolib::add_new_event($dbh,"SCHEDULER_REDUCE_NB_NODES_FOR_RESERVATION",$job->{idJob},"[oar_scheduler] Reduce the number of resources for the job $job->{idJob}.");
                }
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

    my $gantt = Gantt::new();

    # Find jobs to check
    my @jobsToSched = iolib::get_waiting_toSchedule_reservation_jobs_specific_queue($dbh,$queueName);
    if ($#jobsToSched >= 0){
        # Build gantt diagram of other jobs
        # Take care of currently scheduled jobs except besteffort jobs if queueName is not besteffort
        my %alreadyScheduledJobs = iolib::get_gantt_scheduled_jobs($dbh);
        foreach my $i (keys(%alreadyScheduledJobs)){
            my $types = iolib::get_current_job_types($dbh,$i);
            if (!defined($types->{"besteffort"})){
                foreach my $r (@{$alreadyScheduledJobs{$i}->[3]}){
                    Gantt::set_occupation(  $gantt,
                                         iolib::sql_to_local($alreadyScheduledJobs{$i}->[0]),
                                            iolib::sql_to_duration($alreadyScheduledJobs{$i}->[1]) + $security_time_overhead,
                                            $r
                                         );
                }
            }
        }
    }
    foreach my $job (@jobsToSched){
        my $job_descriptions = iolib::get_resources_data_structure_current_job($dbh,$job->{idJob});
        # It is a reservation, we take care only of the first moldable job
        my $moldable = $job_descriptions->[0];
        my $duration = iolib::sql_to_duration($moldable->[1]);

        my $types = iolib::get_current_job_types($dbh,$job->{idJob});
        #look if reservation is too old
        if ($current_time_sec >= (iolib::sql_to_local($job->{startTime}) + $duration)){
            oar_debug("[oar_scheduler] check_reservation_jobs : Cancel reservation $job->{idJob}, job is too old\n");
            iolib::set_job_state($dbh, $job->{idJob}, "toError");
        }else{
            if (iolib::sql_to_local($job->{startTime}) < $current_time_sec){
                $job->{startTime} = $current_time_sql;
                iolib::set_running_date_arbitrary($dbh,$job->{idJob},$current_time_sql);
            }
            
            my @available_resources;
            my @tmp_resource_list;
            # Get the list of resources where the reservation will be able to be launched
            push(@tmp_resource_list, iolib::get_resources_in_state($dbh,"Alive"));
            push(@tmp_resource_list, iolib::get_resources_in_state($dbh,"Absent"));
            push(@tmp_resource_list, iolib::get_resources_in_state($dbh,"Suspected"));
            foreach my $r (@tmp_resource_list){
                if (Gantt::is_resource_free($gantt,
                                            iolib::sql_to_local($job->{startTime}),
                                            $duration + $security_time_overhead,
                                            $r->{resourceId}
                                           ) == 1
                   ){                       
                    push(@available_resources, $r->{resourceId});
                }
            }
            my $job_properties = "TRUE";
            if ($job->{properties} ne ""){
                $job_properties = $job->{properties};
            }

            my @resource_id_used_list;
            my @tree_list;
            foreach my $m (@{$moldable->[0]}){
                my $tmp_properties = "TRUE";
                if ($m->{property} ne ""){
                    $tmp_properties = $m->{property};
                }
                my $tmp_tree = iolib::get_possible_wanted_resources($dbh,\@available_resources,\@resource_id_used_list,"$job_properties AND $tmp_properties", $m->{resources});
                push(@tree_list, $tmp_tree);
                my @leafs = oar_resource_tree::get_tree_leafs($tmp_tree);
                foreach my $l (@leafs){
                    push(@resource_id_used_list, oar_resource_tree::get_current_resource_value($l));
                }
            }
            my @hole = Gantt::find_first_hole($gantt,iolib::sql_to_local($job->{startTime}), $duration, \@tree_list);
            if ($hole[0] == iolib::sql_to_local($job->{startTime})){
                # The reservation can be scheduled
                my @res_trees;
                my @resources;
                foreach my $t (@tree_list){
                    my $minimal_tree = oar_resource_tree::delete_unnecessary_subtrees($t);
                    push(@res_trees, $minimal_tree);
                    foreach my $r (oar_resource_tree::get_tree_leafs($minimal_tree)){
                        push(@resources, oar_resource_tree::get_current_resource_value($r));
                    }
                }
        
                # We can schedule the job
                oar_debug("[oar_scheduler] check_reservation_jobs : Confirm reservation $job->{idJob} and add in gantt\n");
                foreach my $r (@resources){
                    Gantt::set_occupation(  $gantt,
                                            iolib::sql_to_local($job->{startTime}),
                                            iolib::sql_to_duration($moldable->[1]) + $security_time_overhead,
                                            $r
                                         );
                }
                # Update database
                iolib::add_gantt_scheduled_jobs($dbh,$moldable->[2],$job->{startTime},\@resources);
                iolib::set_job_state($dbh, $job->{idJob}, "toAckReservation");
            }else{           
                oar_debug("[oar_scheduler] check_reservation_jobs : Cancel reservation $job->{idJob}, not enough nodes\n");
                iolib::set_job_state($dbh, $job->{idJob}, "toError");
                iolib::set_job_message($dbh, $job->{idJob}, "This reservation may be run at ".iolib::local_to_sql($hole[0]));
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
    my %nodesForJobsToLaunch = iolib::get_gantt_resources_for_jobs_to_launch($dbh,$current_time_sql); 
    foreach my $r (keys(%nodesForJobsToLaunch)){
        if (defined($besteffort_resource_occupation{$r})){
            oar_debug("[oar_scheduler] check_jobs_to_kill : besteffort job $besteffort_resource_occupation{$r} must be killed\n");
            iolib::add_new_event($dbh,"BESTEFFORT_KILL",$besteffort_resource_occupation{$r},"[oar_scheduler] kill the besteffort job $besteffort_resource_occupation{$r}");
            iolib::frag_job($dbh, $besteffort_resource_occupation{$r});
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
        iolib::set_assigned_moldable_job($dbh,$i,$jobs_to_launch{$i}->[0]);
        foreach my $r (@{$jobs_to_launch{$i}->[1]}){
            iolib::add_resource_job_pair($dbh,$jobs_to_launch{$i}->[0],$r);
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
