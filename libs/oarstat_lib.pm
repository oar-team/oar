package oarstatlib;

use strict;
use warnings;
use Data::Dumper;
use oarversion;
use oar_iolib;
use oar_conflib qw(init_conf dump_conf get_conf is_conf);

my $base;

# Read config
init_conf($ENV{OARCONFFILE});
my $Cpuset_field = get_conf("JOB_RESOURCE_MANAGER_PROPERTY_DB_FIELD");
my $Job_uid_resource_type = get_conf("JOB_RESOURCE_MANAGER_JOB_UID_TYPE");

sub open_db_connection(){
	$base  = iolib::connect_ro_one();
        if (defined($base)) { return 1; }
        else {return 0; }
}

sub close_db_connection(){
	iolib::disconnect($base);
}

sub get_oar_version(){
    return oarversion::get_version();
}

sub local_to_sql($){
	my $date = shift;
    return iolib::local_to_sql($date);
}

sub sql_to_local($){
	my $date = shift;
    return iolib::sql_to_local($date);
}

sub duration_to_sql($) {
	my $duration = shift;
    return iolib::duration_to_sql($duration);
}

sub get_jobs_with_given_properties {
  my $sql_property = shift;
  my @jobs;
  my @jobs_with_given_properties = iolib::get_jobs_with_given_properties($base,$sql_property);
  push( @jobs, @jobs_with_given_properties );
  return \@jobs;
}

sub get_accounting_summary($$$){
    my $start = shift;
    my $stop = shift;
    my $user = shift;
	return iolib::get_accounting_summary($base,$start,$stop,$user);
}

sub get_accounting_summary_byproject($$$){
    my $start = shift;
    my $stop = shift;
    my $user = shift;
	return iolib::get_accounting_summary_byproject($base,$start,$stop,$user);
}

sub get_array_job_ids($){
    my $array_id = shift;
	my @array_job_ids = iolib::get_array_job_ids($base, $array_id);
	return @array_job_ids;
}

sub get_array_subjobs {
  my $array_id = shift;
  my @jobs;
  my @array_subjobs = iolib::get_array_subjobs($base, $array_id);
  push( @jobs, @array_subjobs );
  return \@jobs;
}

sub get_all_jobs_for_user {
  my $user = shift;
  my @jobs;
  my @states =  ("Finishing", "Running", "Resuming", "Suspended", "Launching", "toLaunch", "Waiting", "toAckReservation", "Hold");
  my @get_jobs_in_state_for_user;
  foreach my $current_state (@states){
    @get_jobs_in_state_for_user = iolib::get_jobs_in_state_for_user($base, $current_state, $user);
    push( @jobs, @get_jobs_in_state_for_user );
  }
  return \@jobs;
}

sub get_jobs_for_user_query {
	my $user = shift;
	my $from = shift;
    my $to = shift;
    my $state = shift;
    my $limit = shift;
	my $offset = shift;
	
	if (defined($state)) {
		my @states = split(/,/,$state);
    	my $statement;
    	foreach my $s (@states) {
    		$statement .= $base->quote($s);
    		$statement .= ",";
    	}
    chop($statement);
    $state = $statement;
	}

	my %jobs =  iolib::get_distinct_jobs_gantt_scheduled($base,$from,$to,$state,$limit,$offset,$user);
	return (\%jobs);
}

sub count_jobs_for_user_query {
	my $user = shift;
	my $from = shift;
    my $to = shift;
    my $state = shift;
	
	if (defined($state)) {
		my @states = split(/,/,$state);
    	my $statement;
    	foreach my $s (@states) {
    		$statement .= $base->quote($s);
    		$statement .= ",";
    	}
    chop($statement);
    $state = $statement;
	}

	my $total =  iolib::count_distinct_jobs_gantt_scheduled($base,$from,$to,$state,$user);
	return $total;
}

sub get_pagination_uri($$$) {
	my $from_timestamp = shift;
	my $to_timestamp = shift;
	my $state = shift;

    # link generation
    my $uri_params;

    if (defined($from_timestamp) && !defined($to_timestamp)) {
    	$uri_params = "?from=".$from_timestamp;
    }

    if (defined($to_timestamp) && !defined($from_timestamp)) {
    	$uri_params = "?to=".$to_timestamp;
    }

    if (defined($from_timestamp) && defined($to_timestamp)) {
    	$uri_params = "?from=".$from_timestamp."&to=".$to_timestamp;
    }

	if (defined($state)) {
        if (!defined($uri_params)) {
    	    $uri_params = "?state=".$state;
		}
		else {
    	    $uri_params .= "&state=".$state;
		}
    }

    return $uri_params;
}

sub get_all_admission_rules() {
	my @admission_rules = iolib::list_admission_rules($base);
	return \@admission_rules;
}

sub get_specific_admission_rule {
    my $rule_id = shift;
    my $rule;
    $rule = iolib::get_admission_rule($base,$rule_id);
    return $rule;
}

sub add_admission_rule {
	my $rule = shift;
	my $id = iolib::add_admission_rule($base,$rule);
	return $id;
}

sub delete_specific_admission_rule {
	my $rule_id = shift;
	iolib::delete_admission_rule($base,$rule_id);
}

sub get_duration($){
# Converts a number of seconds in a human readable duration (years,days,hours,mins,secs)
    my $time=shift;
    my $seconds;
    my $minutes;
    my $hours;
    my $days;
    my $years;
    my $duration="";
    $years=int($time/31536000);
    if ($years==1) { $duration .="1 year ";}
    elsif ($years) { $duration .="$years years ";};
    $days=int($time/86400)%365;
    if ($days==1) { $duration .="1 day ";}
    elsif ($days) { $duration .="$days days ";};
    $hours=int($time/3600)%24;
    if ($hours==1) { $duration .="1 hour ";}
    elsif ($hours) { $duration .="$hours hours ";};
    $minutes=int($time/60)%60;
    if ($minutes==1) { $duration .="1 minute ";}
    elsif ($minutes) { $duration .="$minutes minutes ";};
    $seconds=$time%60;
    if ($seconds==1) { $duration .="1 second ";}
    elsif ($seconds) { $duration .="$seconds seconds ";};
    if ($duration eq "") {$duration="0 seconds ";};
    return $duration;
}

sub get_events {
    my $job_ids = shift;
    my @return;
    if ( $#$job_ids >= 0 ) {
      foreach my $j (@$job_ids) {
          my @events = iolib::get_job_events($base,$j);
          push @return, @events;
      }
    }
    return \@return;
}

sub get_gantt {
  my $gantt_query = shift;
  if ($gantt_query =~ m/\s*(\d{4}\-\d{1,2}\-\d{1,2})\s+(\d{1,2}:\d{1,2}:\d{1,2})\s*,\s*(\d{4}\-\d{1,2}\-\d{1,2})\s+(\d{1,2}:\d{1,2}:\d{1,2})\s*/m)
    {
        my $hist = get_history( "$1 $2", "$3 $4" );
        return $hist;
    }else{
      return undef;
    }
}

sub get_history($$){
    my ($date_start,$date_stop) = @_;

    $date_start = sql_to_local($date_start);
    $date_stop = sql_to_local($date_stop);
    
    my %hash_dumper_result;
    my @nodes = iolib::list_resources($base);
    $hash_dumper_result{resources} = \@nodes;
    my %job_gantt = iolib::get_jobs_gantt_scheduled($base,$date_start,$date_stop);
    $hash_dumper_result{jobs} = \%job_gantt;
    #print(Dumper(%hash_dumper_result));
    #print finished or running jobs
    my %jobs_history = iolib::get_jobs_range_dates($base,$date_start,$date_stop);
    foreach my $i (keys(%jobs_history)){
        my $types = iolib::get_current_job_types($base,$i);
        if (!defined($job_gantt{$i}) || (defined($types->{besteffort}))){
            if (($jobs_history{$i}->{state} eq "Running") ||
                ($jobs_history{$i}->{state} eq "toLaunch") ||
                ($jobs_history{$i}->{state} eq "Suspended") ||
                ($jobs_history{$i}->{state} eq "Resuming") ||
                ($jobs_history{$i}->{state} eq "Launching")){
                if (defined($types->{besteffort})){
                    $jobs_history{$i}->{stop_time} = iolib::get_gantt_visu_date($base);
                }else{
                    #This job must be already  printed by gantt
                    next;
                }
            }
            $hash_dumper_result{jobs}{$i} = $jobs_history{$i};
        }
    }

    #print Down or Suspected resources
    my %dead_resource_dates = iolib::get_resource_dead_range_date($base,$date_start,$date_stop);
    $hash_dumper_result{dead_resources} = \%dead_resource_dates;

    return(\%hash_dumper_result);
}

sub get_last_project_karma($$$) {
    my $user = shift;
    my $project = shift;
    my $date = shift;
	my @last_karma=iolib::get_last_project_karma($base,$user,$project,$date);
	return(@last_karma);
}

#sub get_properties {
	#my $job_ids = shift;
	#my $return_hash;
	#my @resources;
	#foreach my $j (@$job_ids){
		#my @job_resources_properties = iolib::get_job_resources_properties($base, $j);
		#push  ( @resources, @job_resources_properties);
	#}
	#foreach my $r (@resources){
		#my $hash_resource_properties;
		#foreach my $p (keys(%{$r})){
			#if(oar_Tools::check_resource_system_property($p) != 1){
				#$hash_resource_properties->{$p}= $r->{$p};
			#}
		#}
		#$return_hash->{$r->{resource_id}} = $hash_resource_properties;
	#}
	#return $return_hash;
#}

sub get_specific_jobs {
    my $job_ids = shift;
    my @jobs;
    foreach my $j (@$job_ids) {
      my $tmp = iolib::get_job($base, $j);
      if (defined($tmp)){
	push(@jobs, $tmp);
      }
    }
    return \@jobs;
}

sub get_job_resources($) {
    my $job_info=shift;
    my $reserved_resources=[];
    my @assigned_resources;
    my @assigned_hostnames;
    if (defined($job_info->{assigned_moldable_job}) && $job_info->{assigned_moldable_job} ne ""){
        @assigned_resources = iolib::get_job_resources($base,$job_info->{assigned_moldable_job});
        @assigned_hostnames = iolib::get_job_network_address($base,$job_info->{assigned_moldable_job});
    }
    if ($job_info->{reservation} eq "Scheduled" and $job_info->{state} eq "Waiting") {
        $reserved_resources = iolib::get_gantt_visu_resources_for_resa($base,$job_info->{job_id});
    }
    return { assigned_resources => \@assigned_resources,
             assigned_hostnames => \@assigned_hostnames,
             reserved_resources => $reserved_resources };
}

sub get_job_data($$){
    my $job_info = shift;
    my $full_view = shift;
    
    my $dbh = $base;
    my @nodes;
    my @node_hostnames;
    my $mold;
    my @date_tmp;
    my @job_events;
    my %data_to_display;
    my $job_user;
    my $job_cpuset_uid;
    my @job_dependencies;
    my @job_types = iolib::get_job_types($dbh,$job_info->{job_id});
    my $cpuset_name;
    my $array_index;
    
    $cpuset_name = iolib::get_job_cpuset_name($dbh, $job_info->{job_id}) if (defined($Cpuset_field));
    $array_index = iolib::get_job_array_index($dbh,$job_info->{job_id});

    my $resources_string = "";
    my $reserved_resources;
    if ($job_info->{assigned_moldable_job} ne ""){
        @nodes = iolib::get_job_resources($dbh,$job_info->{assigned_moldable_job});
        @node_hostnames = iolib::get_job_network_address($dbh,$job_info->{assigned_moldable_job});
        $mold = iolib::get_moldable_job($dbh,$job_info->{assigned_moldable_job});
    }
    if ($job_info->{reservation} eq "Scheduled" and $job_info->{state} eq "Waiting") {
        $reserved_resources = iolib::get_gantt_visu_resources_for_resa($dbh,$job_info->{job_id});
    } 
	
	if (defined($full_view)){
        @date_tmp = iolib::get_gantt_job_start_time_visu($dbh,$job_info->{job_id});
        @job_events = iolib::get_job_events($dbh,$job_info->{job_id});
        @job_dependencies = iolib::get_current_job_dependencies($dbh,$job_info->{job_id});

        $job_cpuset_uid = iolib::get_job_cpuset_uid($dbh, $job_info->{assigned_moldable_job}, $Job_uid_resource_type, $Cpuset_field) if ((defined($Job_uid_resource_type)) and (defined($Cpuset_field)));
        $job_user = oar_Tools::format_job_user($job_info->{job_user},$job_info->{job_id},$job_cpuset_uid);
   
        #Get the job resource description to print -l option
        my $job_descriptions = iolib::get_resources_data_structure_current_job($dbh,$job_info->{job_id});
        foreach my $moldable (@{$job_descriptions}){
            my $tmp_str = "";
            foreach my $group (@{$moldable->[0]}){
                if ($tmp_str ne ""){
                    # add a new group
                    $tmp_str .= "+";
                }else{
                    # first group
                    $tmp_str .= "-l \"";
                }
                if ((defined($group->{property})) and ($group->{property} ne "")){
                    $tmp_str .= "{$group->{property}}";
                }
                foreach my $resource (@{$group->{resources}}){
                    my $tmp_val = $resource->{value};
                    if ($tmp_val == -1){
                        $tmp_val = "ALL";
                    }elsif ($tmp_val == -2){
                        $tmp_val = "BEST";
                    }
                    $tmp_str .= "/$resource->{resource}=$tmp_val";
                }
            }
            $tmp_str .= ",walltime=".iolib::duration_to_sql($moldable->[1])."\" ";
            $resources_string .= $tmp_str;
        }
        
        
        %data_to_display = (
            Job_Id => $job_info->{job_id},
            array_id => $job_info->{array_id},
            array_index => $array_index,
            name => $job_info->{job_name},
            owner => $job_info->{job_user},
            job_user => $job_user,
            job_uid => $job_cpuset_uid,
            state => $job_info->{state},
            assigned_resources => \@nodes,
            assigned_network_address => \@node_hostnames,
            queue => $job_info->{queue_name},
            command => $job_info->{command},
            launchingDirectory => $job_info->{launching_directory},
            jobType => $job_info->{job_type},
            properties => $job_info->{properties},
            reservation => $job_info->{reservation},
            walltime => $mold->{moldable_walltime},
            submissionTime => $job_info->{submission_time},
            startTime => $job_info->{start_time},
            message => $job_info->{message},
            scheduledStart => $date_tmp[0],
            resubmit_job_id => $job_info->{resubmit_job_id},
            events => \@job_events,
            wanted_resources => $resources_string,
            project => $job_info->{project},
            cpuset_name => $cpuset_name,
            types => \@job_types,
            dependencies => \@job_dependencies,
            exit_code => $job_info->{exit_code},
            initial_request => ""

        );
        if (($ENV{OARDO_USER} eq $job_info->{job_user})
            or ($ENV{OARDO_USER} eq "oar")
            or ($ENV{OARDO_USER} eq "root")){
            $data_to_display{initial_request} = $job_info->{initial_request};

        }
    }else{
        %data_to_display = (
            Job_Id => $job_info->{job_id},
            array_id => $job_info->{array_id},
            array_index => $array_index,
            name => $job_info->{job_name},
            owner => $job_info->{job_user},
            state => $job_info->{state},
            assigned_resources => \@nodes,
            assigned_network_address => \@node_hostnames,
            queue => $job_info->{queue_name},
            command => $job_info->{command},
            launchingDirectory => $job_info->{launching_directory},
            jobType => $job_info->{job_type},
            properties => $job_info->{properties},
            reservation => $job_info->{reservation},
            submissionTime => $job_info->{submission_time},
            startTime => $job_info->{start_time},
            message => $job_info->{message},
            resubmit_job_id => $job_info->{resubmit_job_id},
            project => $job_info->{project},
            cpuset_name => $cpuset_name,
            types => \@job_types,
            dependencies => \@job_dependencies
        );
    }
    if (defined($reserved_resources)) {
        $data_to_display{'reserved_resources'}=$reserved_resources;
    }

    return(\%data_to_display);
}

sub get_job_resources_properties($) {
	my $jobid= shift;
	my @job_resources_properties = iolib::get_job_resources_properties($base, $jobid);
	return @job_resources_properties;
}

sub get_job_state($) {
	my $idJob = shift;
	my $state_string = iolib::get_job_state($base,$idJob);
	return $state_string;
}


#sub get_default_job_infos($$){
	#my $job_array = shift;
	#my $hashestat = shift;
	
	#print "\nDumper job_array: ".Dumper(@$job_array); 
	#print "\nDumper hashestat: ".Dumper(%$hashestat); 
	
	#my %default_job_infos;
	
	#foreach my $job_info (@$job_array){
		#print "\nDumper job_info: ".Dumper($job_info); 
		
		##$job_info->{'command'} = '' if (!defined($job_info->{'command'}));
		#$job_info->{job_name} = '' if (!defined($job_info->{job_name}));
		
		#print ("\nDEBUG : ".$job_info->{'job_id'}.
			#"\n".$job_info->{'job_name'}.
			#"\n".$job_info->{'job_user'}.
			#"\n".$job_info->{'submission_time'}.
			#"\n".$job_info->{'state'}.
			#"\n".$job_info->{'queue_name'});
		
		#$default_job_infos = [ $job_info->{'job_id'},
			#$job_info->{'job_name'},
			#$job_info->{'job_user'},
			#iolib::local_to_sql($job_info->{'submission_time'}),
			#%$hashestat{$job_info->{'state'}},
			#$job_info->{'queue_name'} ];
	#}
	#print "\nDumper default_job_infos: ".Dumper(%default_job_infos); 
	#exit 0;
	#return(\%default_job_infos);
#}

1;
