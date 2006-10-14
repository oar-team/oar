package oar_scheduler;

use Data::Dumper;
use strict;
use warnings;
use oar_iolib;
use Gantt_2;
use oar_Judas qw(oar_debug oar_warn oar_error);
use oar_conflib qw(init_conf get_conf is_conf);


init_conf($ENV{OARCONFFILE});

#minimum of seconds between each jobs
my $Security_time_overhead = 1;

#minimum of seconds to be considered like a hole in the gantt
my $Minimum_hole_time = 0;

# waiting time when a reservation has not all of its nodes
my $Reservation_waiting_timeout = 300;

# global variables : initialized in init_scheduler function
my %besteffort_resource_occupation;

my $current_time_sec = 0;
my $current_time_sql = "0000-00-00 00:00:00";

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
sub init_scheduler($$$$$$){
    my $dbh = shift;
    my $dbh_ro = shift;
    my $secure_time = shift;
    my $hole_time = shift;
    my $order_part = shift;
    my $resa_admin_waiting_timeout = shift;

    $Reservation_waiting_timeout = $resa_admin_waiting_timeout if (defined($resa_admin_waiting_timeout));
    
    if ($secure_time > 1){
        $Security_time_overhead = $secure_time;
    }

    if ($hole_time >= 0){
        $Minimum_hole_time = $hole_time;
    }

    # Take care of the currently (or nearly) running jobs
    # Lock to prevent bipbip update in same time
    iolib::lock_table($dbh,["jobs","assigned_resources","gantt_jobs_predictions","gantt_jobs_resources","job_types","moldable_job_descriptions","resources"]);
   
    #calculate now date with no overlap with other jobs
    my $previous_ref_time_sec = iolib::get_gantt_date($dbh);
    $current_time_sec = iolib::get_date($dbh);
    if ($current_time_sec < $previous_ref_time_sec){
        # The system is very fast!!!
        $current_time_sec = $previous_ref_time_sec;
    }
    $current_time_sec++;
    $current_time_sql = iolib::local_to_sql($current_time_sec);

   
    iolib::gantt_flush_tables($dbh);
    iolib::set_gantt_date($dbh,$current_time_sec);
    
    my @initial_jobs;
    push(@initial_jobs, iolib::get_jobs_in_state($dbh, "Running"));
    push(@initial_jobs, iolib::get_jobs_in_state($dbh, "toLaunch"));
    push(@initial_jobs, iolib::get_jobs_in_state($dbh, "Launching"));
    push(@initial_jobs, iolib::get_jobs_in_state($dbh, "Finishing"));
    push(@initial_jobs, iolib::get_jobs_in_state($dbh, "Suspended"));
    push(@initial_jobs, iolib::get_jobs_in_state($dbh, "Resuming"));

    my $max_resources = 50;
    #Init the gantt chart with all resources
    my $vec = '';
    foreach my $r (iolib::list_resources($dbh)){
        vec($vec,$r->{resource_id},1) = 1;
        $max_resources = $r->{resource_id} if ($r->{resource_id} > $max_resources);
    }
    my $gantt = Gantt_2::new($max_resources, $Minimum_hole_time);
    Gantt_2::add_new_resources($gantt, $vec);
    
    foreach my $i (@initial_jobs){
        my $mold = iolib::get_current_moldable_job($dbh,$i->{assigned_moldable_job});
        # The list of resources on which the job is running
        my @resource_list = iolib::get_job_current_resources($dbh, $i->{assigned_moldable_job},undef);

        my $date ;
        if ($i->{start_time} == 0) {
            $date = $current_time_sec;
        }elsif ($i->{start_time} + $mold->{moldable_walltime} < $current_time_sec){
            $date = $current_time_sec - $mold->{moldable_walltime};
        }else{
            $date = $i->{start_time};
        }
        oar_debug("[oar_scheduler] init_scheduler : add in gantt job $i->{job_id}\n");
        iolib::add_gantt_scheduled_jobs($dbh,$i->{assigned_moldable_job},$date,\@resource_list);

        # Treate besteffort jobs like nothing!
        if ($i->{queue_name} ne "besteffort"){
            my $job_duration = $mold->{moldable_walltime};
            if ($i->{state} eq "Suspended"){
                # Remove resources of the type specified in SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE
                my @suspended_types = split(" ",get_conf("SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE"));
                @resource_list = iolib::get_job_current_resources($dbh, $i->{assigned_moldable_job},\@suspended_types);
            }
            if ($i->{suspended} eq "YES"){
                # This job was suspended so we must recalculate the walltime
                $job_duration += iolib::get_job_suspended_sum_duration($dbh,$i->{job_id},$current_time_sec);
            }

            my $vec = '';
            foreach my $r (@resource_list){
                vec($vec, $r, 1) = 1;
            }
            Gantt_2::set_occupation(  $gantt,
                                      $date,
                                      $job_duration + $Security_time_overhead,
                                      $vec
                                   );
        }else{
            #Stock information about besteffort jobs
            foreach my $j (@resource_list){
                $besteffort_resource_occupation{$j} = $i->{job_id};
            }
        }
    }
    iolib::unlock_table($dbh);

    #Add in Gantt reserved jobs already scheduled
    my @Rjobs = iolib::get_waiting_reservation_jobs($dbh);
    foreach my $job (@Rjobs){
        my $job_descriptions = iolib::get_resources_data_structure_current_job($dbh,$job->{job_id});
        # For reservation we take the first moldable job
        my $moldable = $job_descriptions->[0];
        my $available_resources_vector = '';
        #my $alive_resources_vector = '';
        my @tmp_resource_list;
        # Get the list of resources where the reservation will be able to be launched
        push(@tmp_resource_list, iolib::get_resources_in_state($dbh,"Alive"));
        push(@tmp_resource_list, iolib::get_resources_in_state($dbh,"Absent"));
        push(@tmp_resource_list, iolib::get_resources_in_state($dbh,"Suspected"));	
	    my $free_resources_vec = Gantt_2::get_free_resources(	$gantt,
                                     				            $job->{start_time},
                                        			            $moldable->[1] + $Security_time_overhead,
                                       			            );
        foreach my $r (@tmp_resource_list){
            if (vec($free_resources_vec, $r->{resource_id}, 1) == 1){
                #if ($r->{state} eq "Alive"){
                #    vec($alive_resources_vector, $r->{resource_id}, 1) = 1;
                #}
                vec($available_resources_vector, $r->{resource_id}, 1) = 1;
            }
        }

        my @dead_resources;
        foreach my $r (iolib::get_resources_in_state($dbh,"Dead")){
            push(@dead_resources, $r->{resource_id});
        }
        
        my $job_properties = "TRUE";
        if ((defined($job->{properties})) and ($job->{properties} ne "")){
            $job_properties = $job->{properties};
        }

        my $resource_id_used_list_vector = '';
        my @tree_list;
        foreach my $m (@{$moldable->[0]}){
            my $tmp_properties = "TRUE";
            if ((defined($m->{property})) and ($m->{property} ne "")){
                $tmp_properties = $m->{property};
            }
            my $tmp_tree;
            ## Try first with only alive nodes
            #$tmp_tree = iolib::get_possible_wanted_resources($dbh_ro,$alive_resources_vector,$resource_id_used_list_vector,\@dead_resources,"$job_properties AND $tmp_properties", $m->{resources}, $order_part);
            #if (!defined($tmp_tree)){
            if (!defined($order_part) or ($order_part eq "")){
                $order_part = "state ASC";
            }else{
                $order_part = "state ASC,".$order_part;
            }
                $tmp_tree = iolib::get_possible_wanted_resources($dbh_ro,$available_resources_vector,$resource_id_used_list_vector,\@dead_resources,"$job_properties AND $tmp_properties", $m->{resources}, "".$order_part);
            #}
            push(@tree_list, $tmp_tree);
            my @leafs = oar_resource_tree::get_tree_leafs($tmp_tree);
            foreach my $l (@leafs){
                vec($resource_id_used_list_vector, oar_resource_tree::get_current_resource_value($l), 1) = 1;
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
            my $vec = '';
            foreach my $r (@resources){
                vec($vec, $r, 1) = 1;
            }
            Gantt_2::set_occupation(  $gantt,
                                      $job->{start_time},
                                      $moldable->[1] + $Security_time_overhead,
                                      $vec
                                 );
            # Update database
            iolib::add_gantt_scheduled_jobs($dbh,$moldable->[2],$job->{start_time},\@resources);
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
        my $job_descriptions = iolib::get_resources_data_structure_current_job($dbh,$job->{job_id});
        my $moldable = $job_descriptions->[0];
    
        my $start = $job->{start_time};
        my $max = $moldable->[1];
        # Test if the job is in the paste
        if ($current_time_sec > $start+$max ){
            oar_debug("[oar_scheduler] treate_waiting_reservation_jobs :  Reservation $job->{job_id} in ERROR\n");
            iolib::set_job_state($dbh, $job->{job_id}, "Error");
            iolib::set_job_message($dbh,$job->{job_id},"[oar_scheduler] Reservation has expired and it cannot be started.");
            $return = 1;
        }
        my @resa_alive_resources = iolib::get_gantt_Alive_resources_for_job($dbh,$moldable->[2]);
        # test if the job is going to be launched and there is no Alive node
        if (($#resa_alive_resources < 0) && ($job->{start_time} <= $current_time_sec)){
            oar_debug("[oar_scheduler] Reservation $job->{job_id} is in waiting mode because no resource is present\n");
            iolib::set_gantt_job_startTime($dbh,$job->{job_id},iolib::local_to_sql($current_time_sec + 1));
        }elsif($job->{start_time} <= $current_time_sec){
            my @resa_resources = iolib::get_gantt_resources_for_job($dbh,$moldable->[2]);
            if ($job->{start_time} + $Reservation_waiting_timeout > $current_time_sec){
                if ($#resa_resources > $#resa_alive_resources){
                    # we have not the same number of nodes than in the query --> wait the specified timeout
                    oar_debug("[oar_scheduler] Reservation $job->{job_id} is in waiting mode because all nodes are not yet available.\n");
                    iolib::set_gantt_job_startTime($dbh,$job->{job_id},($current_time_sec + 1));
                }
            }else{
                #Check if resources are in Alive state otherwise remove them, the job is going to be launched
                foreach my $r (@resa_resources){
                    my $resource_info = iolib::get_resource_info($dbh,$r);
                    if ($resource_info->{state} ne "Alive"){
                        oar_debug("[oar_scheduler] Reservation $job->{job_id} : remove resource $r because it state is $resource_info->{state}\n");
                        iolib::remove_gantt_resource_job($dbh, $moldable->[2], $r);
                    }
                }
                if ($#resa_resources > $#resa_alive_resources){
                    iolib::add_new_event($dbh,"SCHEDULER_REDUCE_NB_NODES_FOR_RESERVATION",$job->{job_id},"[oar_scheduler] Reduce the number of resources for the job $job->{job_id}.");
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
sub check_reservation_jobs($$$$){
    my $dbh = shift;
    my $dbh_ro = shift;
    my $queue_name = shift;
    my $order_part = shift;

    oar_debug("[oar_scheduler] check_reservation_jobs : Check for new reservation in the $queue_name queue\n");

    my $return = 0;

    #Init the gantt chart with all resources
    my $max_resources = 50;
    my $vec = '';
    foreach my $r (iolib::list_resources($dbh)){
        vec($vec,$r->{resource_id},1) = 1;
        $max_resources = $r->{resource_id} if ($r->{resource_id} > $max_resources);
    }
    my $gantt = Gantt_2::new($max_resources, $Minimum_hole_time);
    Gantt_2::add_new_resources($gantt, $vec);

    # Find jobs to check
    my @jobs_to_sched = iolib::get_waiting_toSchedule_reservation_jobs_specific_queue($dbh,$queue_name);
    if ($#jobs_to_sched >= 0){
        # Build gantt diagram of other jobs
        # Take care of currently scheduled jobs except besteffort jobs if queue_name is not besteffort
        my %already_scheduled_jobs = iolib::get_gantt_scheduled_jobs($dbh);
        foreach my $i (keys(%already_scheduled_jobs)){
            if (($already_scheduled_jobs{$i}->[2] ne "besteffort") or ($queue_name eq "besteffort")){
                my @resource_list = @{$already_scheduled_jobs{$i}->[3]};
                my $job_duration = $already_scheduled_jobs{$i}->[1];
                if ($already_scheduled_jobs{$i}->[4] eq "Suspended"){
                    # Remove resources of the type specified in SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE
                    my @suspended_types = split(" ",get_conf("SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE"));
                    @resource_list = iolib::get_job_current_resources($dbh, $already_scheduled_jobs{$i}->[7],\@suspended_types);
                    next if ($#resource_list < 0);
                }
                if ($already_scheduled_jobs{$i}->[8] eq "YES"){
                    # This job was suspended so we must recalculate the walltime
                    $job_duration += iolib::get_job_suspended_sum_duration($dbh,$i,$current_time_sec);
                }

                my $vec = '';
                foreach my $r (@resource_list){
                    vec($vec, $r, 1) = 1;
                }
                Gantt_2::set_occupation(  $gantt,
                                          $already_scheduled_jobs{$i}->[0],
                                          $job_duration + $Security_time_overhead,
                                          $vec
                                       );
            }
        }
    }
    foreach my $job (@jobs_to_sched){
        my $job_descriptions = iolib::get_resources_data_structure_current_job($dbh,$job->{job_id});
        # It is a reservation, we take care only of the first moldable job
        my $moldable = $job_descriptions->[0];
        my $duration = $moldable->[1];

        #look if reservation is too old
        if ($current_time_sec >= ($job->{start_time} + $duration)){
            oar_debug("[oar_scheduler] check_reservation_jobs : Cancel reservation $job->{job_id}, job is too old\n");
            iolib::set_job_message($dbh, $job->{job_id}, "reservation too old");
            iolib::set_job_state($dbh, $job->{job_id}, "toError");
        }else{
            if ($job->{start_time} < $current_time_sec){
                $job->{start_time} = $current_time_sec;
                #iolib::set_running_date_arbitrary($dbh,$job->{job_id},$current_time_sql);
            }
            
            my $available_resources_vector = '';
            my @tmp_resource_list;
            # Get the list of resources where the reservation will be able to be launched
            push(@tmp_resource_list, iolib::get_resources_in_state($dbh,"Alive"));
            push(@tmp_resource_list, iolib::get_resources_in_state($dbh,"Absent"));
            push(@tmp_resource_list, iolib::get_resources_in_state($dbh,"Suspected"));
            foreach my $r (@tmp_resource_list){
                vec($available_resources_vector, $r->{resource_id}, 1) = 1;
            }
            my @dead_resources;
            foreach my $r (iolib::get_resources_in_state($dbh,"Dead")){
                push(@dead_resources, $r->{resource_id});
            }
            my $job_properties = "TRUE";
            #print(Dumper($job));
            if ((defined($job->{properties})) and ($job->{properties} ne "")){
                $job_properties = $job->{properties};
            }

            my $resource_id_used_list_vector = '';
            my @tree_list;
            foreach my $m (@{$moldable->[0]}){
                my $tmp_properties = "TRUE";
                #print(Dumper($m));
                if ((defined($m->{property})) and ($m->{property} ne "")){
                    $tmp_properties = $m->{property};
                }
                my $tmp_tree = iolib::get_possible_wanted_resources($dbh_ro,$available_resources_vector,$resource_id_used_list_vector,\@dead_resources,"$job_properties AND $tmp_properties", $m->{resources}, $order_part);
                push(@tree_list, $tmp_tree);
                my @leafs = oar_resource_tree::get_tree_leafs($tmp_tree);
                foreach my $l (@leafs){
                    vec($resource_id_used_list_vector, oar_resource_tree::get_current_resource_value($l), 1) = 1;
                }
            }
            my @hole = Gantt_2::find_first_hole($gantt,$job->{start_time}, $duration, \@tree_list);
            #print(Dumper(@hole));
            if ($hole[0] == $job->{start_time}){
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
                oar_debug("[oar_scheduler] check_reservation_jobs : Confirm reservation $job->{job_id} and add in gantt\n");
                my $vec = '';
                foreach my $r (@resources){
                    vec($vec, $r, 1) = 1;
                }
                Gantt_2::set_occupation(  $gantt,
                                          $job->{start_time},
                                          $moldable->[1] + $Security_time_overhead,
                                          $vec
                                       );
                # Update database
                iolib::add_gantt_scheduled_jobs($dbh,$moldable->[2],$job->{start_time},\@resources);
                iolib::set_job_state($dbh, $job->{job_id}, "toAckReservation");
            }else{           
                oar_debug("[oar_scheduler] check_reservation_jobs : Cancel reservation $job->{job_id}, not enough nodes\n");
                iolib::set_job_state($dbh, $job->{job_id}, "toError");
                iolib::set_job_message($dbh, $job->{job_id}, "This reservation may be run at ".iolib::local_to_sql($hole[0]));
            }
        }
        iolib::set_job_resa_state($dbh, $job->{job_id}, "Scheduled");
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
    my %nodes_for_jobs_to_launch = iolib::get_gantt_resources_for_jobs_to_launch($dbh,$current_time_sec);
    foreach my $r (keys(%nodes_for_jobs_to_launch)){
        if (defined($besteffort_resource_occupation{$r})){
            oar_debug("[oar_scheduler] check_jobs_to_kill : besteffort job $besteffort_resource_occupation{$r} must be killed\n");
            iolib::add_new_event($dbh,"BESTEFFORT_KILL",$besteffort_resource_occupation{$r},"[oar_scheduler] kill the besteffort job $besteffort_resource_occupation{$r}");
            iolib::lock_table($dbh,["frag_jobs","event_logs","jobs"]);
            iolib::frag_job($dbh, $besteffort_resource_occupation{$r});
            iolib::unlock_table($dbh);
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
    my $return_code = 0;
    my %jobs_to_launch = iolib::get_gantt_jobs_to_launch($dbh,$current_time_sec);
    
    foreach my $i (keys(%jobs_to_launch)){
        oar_debug("[oar_scheduler] check_jobs_to_launch : set job $i in state toLaunch ($current_time_sql)\n");
        iolib::set_job_state($dbh, $i, "toLaunch");
        iolib::set_running_date_arbitrary($dbh,$i,$current_time_sec);
        # We must look at reservations to not go after the initial stop time
        my $mold = iolib::get_current_moldable_job($dbh,$jobs_to_launch{$i}->[0]);
        my $job = iolib::get_job($dbh,$i);
        if (($job->{reservation} eq "Scheduled") and ($job->{start_time} < $current_time_sec)){
            my $max_time = $mold->{moldable_walltime} - ($current_time_sec - $job->{start_time});
            iolib::set_moldable_job_max_time($dbh,$jobs_to_launch{$i}->[0], $max_time);
            oar_debug("[oar_scheduler] Reduce job ($i) walltime to $max_time instead of $mold->{moldable_walltime}\n");
            iolib::add_new_event($dbh,"REDUCE_RESERVATION_WALLTIME",$i,"Change walltime from $mold->{moldable_walltime} to $max_time");
        }
        iolib::set_assigned_moldable_job($dbh,$i,$jobs_to_launch{$i}->[0]);
        foreach my $r (@{$jobs_to_launch{$i}->[1]}){
            iolib::add_resource_job_pair($dbh,$jobs_to_launch{$i}->[0],$r);
        }
        $return_code = 1;
    }

    return($return_code);
}


#Update gantt visualization tables with new scheduling
#arg : database ref
sub update_gantt_visu_tables($){
    my $dbh = shift;

    iolib::update_gantt_visualization($dbh); 
}

# Look at nodes that are unused for a duration
sub get_idle_nodes($$$){
    my $dbh = shift;
    my $idle_duration = shift;
    my $sleep_duration = shift;

    my %nodes = iolib::search_idle_nodes($dbh, $current_time_sec);
    my $tmp_time = $current_time_sec - $idle_duration;
    my @res;
    foreach my $n (keys(%nodes)){
        if ($nodes{$n} < $tmp_time){
            # Search if the node has enough time to sleep
            my $tmp = iolib::get_next_job_date_on_node($dbh,$n);
            if (!defined($tmp) or ($tmp - $sleep_duration > $current_time_sec)){
                push(@res, $n);
            }
        }
    }
    return(@res);
}

# Get nodes where the scheduler wants to schedule jobs but which is in the
# Absent state
sub get_nodes_to_wake_up($){
    my $dbh = shift;
    
    return(iolib::get_gantt_hostname_to_wake_up($dbh, $current_time_sec));
}

return(1);
