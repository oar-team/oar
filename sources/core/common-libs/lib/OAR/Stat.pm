package OAR::Stat;

use strict;
use warnings;
use Data::Dumper;
use OAR::Version;
use OAR::IO;
use OAR::Conf qw(init_conf dump_conf get_conf get_conf_with_default_param is_conf);
use OAR::Walltime qw(get);

my $base;
my $current_date               = -1;
my %Conversion_fields_format_3 = (
    Job_Id             => "id",
    job_id             => "id",
    launchingDirectory => "launching_directory",
    jobType            => "type",
    job_type           => "type",
    submissionTime     => "submission_time",
    startTime          => "start_time",
    stopTime           => "stop_time",
    scheduledStart     => "scheduled_start",
    job_name           => "name");

# Read config
init_conf($ENV{OARCONFFILE});
my $Cpuset_field = get_conf("JOB_RESOURCE_MANAGER_PROPERTY_DB_FIELD");
my $Other_users_request =
  get_conf_with_default_param("OARSTAT_SHOW_OTHER_USERS_INITIAL_REQUEST", "no");

sub open_db_connection() {
    $base = OAR::IO::connect_ro_one();
    if   (defined($base)) { return 1; }
    else                  { return 0; }
}

sub close_db_connection() {
    OAR::IO::disconnect($base) if (defined($base));
    $base = undef;
}

sub get_oar_version() {
    return OAR::Version::get_version();
}

sub local_to_sql($) {
    my $date = shift;
    return OAR::IO::local_to_sql($date);
}

sub sql_to_local($) {
    my $date = shift;
    return OAR::IO::sql_to_local($date);
}

sub duration_to_sql($) {
    my $duration = shift;
    return OAR::IO::duration_to_sql($duration);
}

sub set_quote($) {
    my $string = shift;
    my $result;
    if (defined($base)) {
        $result = $base->quote($string);
    } else {
        open_db_connection();
        $result = $base->quote($string);
        close_db_connection();
    }

    return $result;
}

sub get_jobs_with_given_properties {
    my $sql_property = shift;
    my @jobs;
    my @jobs_with_given_properties = OAR::IO::get_jobs_with_given_properties($base, $sql_property);
    push(@jobs, @jobs_with_given_properties);
    return \@jobs;
}

sub get_accounting_summary($$$$) {
    my $start        = shift;
    my $stop         = shift;
    my $user         = shift;
    my $sql_property = shift;
    return OAR::IO::get_accounting_summary($base, $start, $stop, $user, $sql_property);
}

sub get_accounting_summary_byproject($$$) {
    my $start = shift;
    my $stop  = shift;
    my $user  = shift;
    return OAR::IO::get_accounting_summary_byproject($base, $start, $stop, $user, undef, undef);
}

sub get_array_job_ids($) {
    my $array_id      = shift;
    my @array_job_ids = OAR::IO::get_array_job_ids($base, $array_id);
    return @array_job_ids;
}

sub get_array_subjobs {
    my $array_id = shift;
    my @jobs;
    my @array_subjobs = OAR::IO::get_array_subjobs($base, $array_id);
    push(@jobs, @array_subjobs);
    return \@jobs;
}

sub get_all_jobs_for_user {
    my $user = shift;

    my @states = (
        "Finishing", "Running",  "Resuming", "Suspended",
        "Launching", "toLaunch", "Waiting",  "toAckReservation",
        "Hold");
    return (OAR::IO::get_jobs_in_states_for_user($base, \@states, $user));
}

sub get_jobs_for_user_query {
    my $user   = shift;
    my $from   = shift;
    my $to     = shift;
    my $state  = shift;
    my $limit  = shift;
    my $offset = shift;
    my $array  = shift;
    my $ids    = shift;

    if (defined($state)) {
        my @states = split(/,/, $state);
        my $statement;
        foreach my $s (@states) {
            $statement .= $base->quote($s);
            $statement .= ",";
        }
        chop($statement);
        $state = $statement;
    }

    my %jobs =
      OAR::IO::get_jobs_for_user_query($base, $from, $to, $state, $limit, $offset, $user, $array,
        $ids);
    return (\%jobs);
}

sub count_jobs_for_user_query {
    my $user  = shift;
    my $from  = shift;
    my $to    = shift;
    my $state = shift;
    my $array = shift;
    my $ids   = shift;

    if (defined($state)) {
        my @states = split(/,/, $state);
        my $statement;
        foreach my $s (@states) {
            $statement .= $base->quote($s);
            $statement .= ",";
        }
        chop($statement);
        $state = $statement;
    }

    my $total =
      OAR::IO::count_jobs_for_user_query($base, $from, $to, $state, undef, undef, $user, $array,
        $ids);
    return $total;
}

sub get_all_admission_rules() {
    my @admission_rules = OAR::IO::list_admission_rules($base, undef);
    return \@admission_rules;
}

sub get_requested_admission_rules {
    my $limit  = shift;
    my $offset = shift;
    my @rules  = OAR::IO::get_requested_admission_rules($base, $limit, $offset);
    return \@rules;
}

sub count_all_admission_rules {
    my $total = OAR::IO::count_all_admission_rules($base);
    return $total;
}

sub get_specific_admission_rule {
    my $rule_id = shift;
    my $rule;
    $rule = OAR::IO::get_admission_rule($base, $rule_id);
    return $rule;
}

sub get_duration($) {

    # Converts a number of seconds in a human readable duration (years,days,hours,mins,secs)
    my $time = shift;
    my $seconds;
    my $minutes;
    my $hours;
    my $days;
    my $years;
    my $duration = "";
    $years = int($time / 31536000);
    if    ($years == 1) { $duration .= "1 year "; }
    elsif ($years)      { $duration .= "$years years "; }
    $days = int($time / 86400) % 365;
    if    ($days == 1) { $duration .= "1 day "; }
    elsif ($days)      { $duration .= "$days days "; }
    $hours = int($time / 3600) % 24;
    if    ($hours == 1) { $duration .= "1 hour "; }
    elsif ($hours)      { $duration .= "$hours hours "; }
    $minutes = int($time / 60) % 60;
    if    ($minutes == 1) { $duration .= "1 minute "; }
    elsif ($minutes)      { $duration .= "$minutes minutes "; }
    $seconds = $time % 60;
    if    ($seconds <= 1)   { $duration .= "$seconds second "; }
    elsif ($seconds)        { $duration .= "$seconds seconds "; }
    if    ($duration eq "") { $duration = "0 seconds "; }
    return $duration;
}

sub convert_job_format_3($) {
    my $job = shift;
    my %job_format_3;

    foreach my $key (keys %$job) {
        if (exists($Conversion_fields_format_3{$key})) {
            $job_format_3{ $Conversion_fields_format_3{$key} } = $job->{$key};
        } else {
            $job_format_3{$key} = $job->{$key};
        }
    }

    if (!defined($job_format_3{owner}) && defined($job_format_3{job_user})) {
        $job_format_3{owner} = $job_format_3{job_user};
    }
    if (!defined($job_format_3{owner}) && defined($job_format_3{user})) {
        $job_format_3{owner} = $job_format_3{user};
    }

    delete $job_format_3{job_user};
    delete $job_format_3{user};

    return (%job_format_3);
}

sub get_events {
    my $job_ids = shift;
    my $events;

    if ($#$job_ids >= 0) {
        $events = OAR::IO::get_jobs_events($base, $job_ids);
    }

    return ($events);
}

sub get_gantt {
    my $gantt_query = shift;
    my $format      = shift;
    if ($gantt_query =~
        m/\s*(\d{4}\-\d{1,2}\-\d{1,2})\s+(\d{1,2}:\d{1,2}:\d{1,2})\s*,\s*(\d{4}\-\d{1,2}\-\d{1,2})\s+(\d{1,2}:\d{1,2}:\d{1,2})\s*/m
    ) {
        my $hist    = get_history("$1 $2", "$3 $4", $format);
        my @job_ids = keys %{ $hist->{jobs} };
        my $events  = OAR::Stat::get_events(\@job_ids);

        foreach my $event (@{$events}) {
            if (!exists($hist->{jobs}->{ $event->{job_id} }->{events})) {
                $hist->{jobs}->{ $event->{job_id} }->{events} = [];
            }
            push @{ $hist->{jobs}->{ $event->{job_id} }->{events} }, $event;
        }

        return $hist;
    } else {
        return undef;
    }
}

sub get_history($$$) {
    my ($date_start, $date_stop, $format) = @_;

    $date_start = sql_to_local($date_start);
    $date_stop  = sql_to_local($date_stop);

    my %hash_dumper_result;
    my @nodes = OAR::IO::list_resources($base);
    $hash_dumper_result{resources} = \@nodes;
    $hash_dumper_result{jobs} = OAR::IO::get_jobs_future_from_range($base, $date_start, $date_stop);
    my $now_date = OAR::IO::get_gantt_visu_date($base);
    my $jobs_past_and_current =
      OAR::IO::get_jobs_past_and_current_from_range($base, $date_start, $date_stop);
    while (my ($k, $v) = each(%$jobs_past_and_current)) {
        if (exists($hash_dumper_result{jobs}->{$k})) {

            #This job is already in the result (got it from the future...)
            next;
        }
        if (grep(/^besteffort$/, @{ $v->{types} }) and
            $v->{state} =~ /^Running|toLaunch|Suspended|Resuming|Launching$/) {
            $v->{stop_time} = $now_date;
        }
        $hash_dumper_result{jobs}->{$k} = $v;
    }

    if ($format eq "3") {
        foreach my $job (keys %{ $hash_dumper_result{jobs} }) {
            %{ $hash_dumper_result{jobs}->{$job} } =
              convert_job_format_3($hash_dumper_result{jobs}->{$job});
        }
    }

    #Retrieve Dead and Suspected resources
    my %dead_resource_dates =
      OAR::IO::get_resources_absent_suspected_dead_from_range($base, $date_start, $date_stop);
    $hash_dumper_result{dead_resources} = \%dead_resource_dates;

    return (\%hash_dumper_result);
}

sub get_last_project_karma($$$) {
    my $user       = shift;
    my $project    = shift;
    my $date       = shift;
    my @last_karma = OAR::IO::get_last_project_karma($base, $user, $project, $date);
    return (@last_karma);
}

#sub get_properties {
#my $job_ids = shift;
#my $return_hash;
#my @resources;
#foreach my $j (@$job_ids){
#my @job_resources_properties = OAR::IO::get_job_resources_properties($base, $j);
#push  ( @resources, @job_resources_properties);
#}
#foreach my $r (@resources){
#my $hash_resource_properties;
#foreach my $p (keys(%{$r})){
#if(OAR::Tools::check_resource_system_property($p) != 1){
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
        my $tmp = OAR::IO::get_job($base, $j);
        if (defined($tmp)) {
            push(@jobs, $tmp);
        }
    }
    return \@jobs;
}

sub get_job_resources($) {
    my $job_info            = shift;
    my $reserved_resources  = [];
    my $scheduled_resources = [];
    my @assigned_resources;
    my @assigned_hostnames;
    if (defined($job_info->{assigned_moldable_job}) && $job_info->{assigned_moldable_job} ne "") {
        @assigned_resources = OAR::IO::get_job_resources($base, $job_info->{assigned_moldable_job});
        @assigned_hostnames =
          OAR::IO::get_job_network_address($base, $job_info->{assigned_moldable_job});
    }
    if ($job_info->{reservation} eq "Scheduled" and $job_info->{state} eq "Waiting") {
        $reserved_resources =
          OAR::IO::get_gantt_visu_scheduled_job_resources($base, $job_info->{job_id});
    }
    if ($job_info->{reservation} eq "None" and $job_info->{state} eq "Waiting") {
        $scheduled_resources =
          OAR::IO::get_gantt_visu_scheduled_job_resources($base, $job_info->{job_id});
    }
    return {
        assigned_resources  => \@assigned_resources,
        assigned_hostnames  => \@assigned_hostnames,
        reserved_resources  => $reserved_resources,
        scheduled_resources => $scheduled_resources };
}

sub get_job_data($$;$) {
    my $job_info  = shift;
    my $full_view = shift;
    my $format    = shift;

    my $dbh = $base;
    my @nodes;
    my @node_hostnames;
    my $mold;
    my @date_tmp;
    my @job_events;
    my %data_to_display;
    my $job_user;
    my @job_dependencies;
    my @job_types = OAR::IO::get_job_types($dbh, $job_info->{job_id});
    my $cpuset_name;

    $cpuset_name = OAR::IO::get_job_cpuset_name($dbh, $job_info->{job_id})
      if (defined($Cpuset_field));

    my $resources_string = "";
    my $reserved_resources;
    if ($job_info->{assigned_moldable_job} ne "" && $job_info->{assigned_moldable_job} ne "0") {
        @nodes = OAR::IO::get_job_resources($dbh, $job_info->{assigned_moldable_job});
        @node_hostnames =
          OAR::IO::get_job_network_address($dbh, $job_info->{assigned_moldable_job});
        $mold = OAR::IO::get_moldable_job($dbh, $job_info->{assigned_moldable_job});
    } else {

        # Try to get the moldable description of a waiting job
        $mold = OAR::IO::get_scheduled_job_description($dbh, $job_info->{job_id});
    }
    if ($job_info->{reservation} eq "Scheduled" and $job_info->{state} eq "Waiting") {
        $reserved_resources =
          OAR::IO::get_gantt_visu_scheduled_job_resources($dbh, $job_info->{job_id});
    }

    if (defined($full_view)) {
        @date_tmp         = OAR::IO::get_gantt_job_start_time_visu($dbh, $job_info->{job_id});
        @job_events       = OAR::IO::get_job_events($dbh, $job_info->{job_id});
        @job_dependencies = OAR::IO::get_current_job_dependencies($dbh, $job_info->{job_id});
        $job_user         = $job_info->{job_user};

        #Get the job resource description to print -l option
        my $job_descriptions =
          OAR::IO::get_resources_data_structure_current_job($dbh, $job_info->{job_id});
        foreach my $moldable (@{$job_descriptions}) {
            my $tmp_str = "";
            foreach my $group (@{ $moldable->[0] }) {
                if ($tmp_str ne "") {

                    # add a new group
                    $tmp_str .= "+";
                } else {

                    # first group
                    $tmp_str .= "-l \"";
                }
                if ((defined($group->{property})) and ($group->{property} ne "")) {
                    $tmp_str .= "{$group->{property}}";
                }
                foreach my $resource (@{ $group->{resources} }) {
                    my $tmp_val = $resource->{value};
                    if ($tmp_val == -1) {
                        $tmp_val = "ALL";
                    } elsif ($tmp_val == -2) {
                        $tmp_val = "BEST";
                    }
                    $tmp_str .= "/$resource->{resource}=$tmp_val";
                }
            }
            $tmp_str          .= ",walltime=" . OAR::IO::duration_to_sql($moldable->[1]) . "\" ";
            $resources_string .= $tmp_str;
        }

        %data_to_display = (
            Job_Id                   => $job_info->{job_id},
            array_id                 => $job_info->{array_id},
            array_index              => $job_info->{array_index},
            name                     => $job_info->{job_name},
            owner                    => $job_info->{job_user},
            job_user                 => $job_user,
            state                    => $job_info->{state},
            assigned_resources       => \@nodes,
            assigned_network_address => \@node_hostnames,
            queue                    => $job_info->{queue_name},
            command                  => $job_info->{command},
            launchingDirectory       => $job_info->{launching_directory},
            jobType                  => $job_info->{job_type},
            properties               => $job_info->{properties},
            reservation              => $job_info->{reservation},
            walltime                 => $mold->{moldable_walltime},
            submissionTime           => $job_info->{submission_time},
            startTime                => $job_info->{start_time},
            stopTime                 => $job_info->{stop_time},
            message                  => $job_info->{message},
            scheduledStart           => $date_tmp[0],
            resubmit_job_id          => $job_info->{resubmit_job_id},
            events                   => \@job_events,
            wanted_resources         => $resources_string,
            project                  => $job_info->{project},
            cpuset_name              => $cpuset_name,
            types                    => \@job_types,
            dependencies             => \@job_dependencies,
            exit_code                => $job_info->{exit_code},
            stdout_file              => OAR::Tools::replace_jobid_tag_in_string(
                $job_info->{stdout_file}, $job_info->{job_id}
            ),
            stderr_file => OAR::Tools::replace_jobid_tag_in_string(
                $job_info->{stderr_file}, $job_info->{job_id}
            ),
            initial_request => "");
        if (lc($Other_users_request) eq "yes" or
            ($ENV{OARDO_USER} eq $job_info->{job_user}) or
            ($ENV{OARDO_USER} eq "oar") or
            ($ENV{OARDO_USER} eq "root")) {
            $data_to_display{initial_request} = $job_info->{initial_request};

        }
    } else {
        %data_to_display = (
            Job_Id                   => $job_info->{job_id},
            array_id                 => $job_info->{array_id},
            array_index              => $job_info->{array_index},
            name                     => $job_info->{job_name},
            owner                    => $job_info->{job_user},
            state                    => $job_info->{state},
            assigned_resources       => \@nodes,
            assigned_network_address => \@node_hostnames,
            queue                    => $job_info->{queue_name},
            command                  => $job_info->{command},
            launchingDirectory       => $job_info->{launching_directory},
            stdout_file              => OAR::Tools::replace_jobid_tag_in_string(
                $job_info->{stdout_file}, $job_info->{job_id}
            ),
            stderr_file => OAR::Tools::replace_jobid_tag_in_string(
                $job_info->{stderr_file}, $job_info->{job_id}
            ),
            jobType         => $job_info->{job_type},
            properties      => $job_info->{properties},
            reservation     => $job_info->{reservation},
            submissionTime  => $job_info->{submission_time},
            startTime       => $job_info->{start_time},
            message         => $job_info->{message},
            resubmit_job_id => $job_info->{resubmit_job_id},
            project         => $job_info->{project},
            cpuset_name     => $cpuset_name,
            types           => \@job_types,
            dependencies    => \@job_dependencies);
    }
    if (defined($reserved_resources)) {
        $data_to_display{'reserved_resources'} = $reserved_resources;
    }

    if ($format eq "3") {
        my %data_to_display_format_3 = convert_job_format_3(\%data_to_display);

        return (\%data_to_display_format_3);
    } else {
        return (\%data_to_display);
    }
}

sub get_job_resources_properties($) {
    my $jobid                    = shift;
    my @job_resources_properties = OAR::IO::get_job_resources_properties($base, $jobid);
    return @job_resources_properties;
}

sub get_job_state($) {
    my $idJob        = shift;
    my $state_string = OAR::IO::get_job_state($base, $idJob);
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

#print ("\nDEBUG: ".$job_info->{'job_id'}.
#"\n".$job_info->{'job_name'}.
#"\n".$job_info->{'job_user'}.
#"\n".$job_info->{'submission_time'}.
#"\n".$job_info->{'state'}.
#"\n".$job_info->{'queue_name'});

#$default_job_infos = [ $job_info->{'job_id'},
#$job_info->{'job_name'},
#$job_info->{'job_user'},
#OAR::IO::local_to_sql($job_info->{'submission_time'}),
#%$hashestat{$job_info->{'state'}},
#$job_info->{'queue_name'} ];
#}
#print "\nDumper default_job_infos: ".Dumper(%default_job_infos);
#exit 0;
#return(\%default_job_infos);
#}

# Compact the array jobs
# Replaces all jobs from an array by a single virtual job
# having "N@array_id" as job_id, with N the number of jobs
# into the array
sub compact_arrays($) {
    my $jobs      = shift;
    my $array_job = {};
    my $newjobs   = [];

    # Parse all the jobs to search for arrays of more than 1 job
    foreach my $job (@{$jobs}) {
        if (defined($array_job->{ $job->{array_id} })) {

            # New element of an array found, increasing the counter
            $array_job->{ $job->{array_id} }->{n}     = $array_job->{ $job->{array_id} }->{n} + 1;
            $array_job->{ $job->{array_id} }->{state} = "NA";
        } else {
            $array_job->{ $job->{array_id} } = $job;
            $array_job->{ $job->{array_id} }->{n} = 1;
        }
    }

    # Generate the new list of jobs
    foreach my $job (@{$jobs}) {
        if ($array_job->{ $job->{array_id} }->{n} > 1) {

            # Do not output the jobs inside an array, but output the virtual job only once
            if (!defined($array_job->{ $job->{array_id} }->{already_printed})) {
                $array_job->{ $job->{array_id} }->{job_id} =
                  $array_job->{ $job->{array_id} }->{n} . "@" . $job->{array_id};
                push(@{$newjobs}, $array_job->{ $job->{array_id} });
                $array_job->{ $job->{array_id} }->{already_printed} = 1;
            }
        } else {

            # jobs not comming from an array are outputed normally
            push(@{$newjobs}, $job);
        }
    }
    return $newjobs;
}

# Use the current date in seconds from the EPOCH to determine the duration of a
# running job (start_time>0)
sub get_job_duration($$) {
    my $start_date = shift;
    my $stop_date  = shift;

    if ($stop_date < $start_date) {
        if ($current_date < 0) {
            $current_date = OAR::IO::get_date($base);
        }
        $stop_date = $current_date;
    }
    my ($h, $m, $s) = (0, 0, 0);
    if (($start_date > 0) and ($start_date < $stop_date)) {
        ($h, $m, $s) = OAR::IO::duration_to_hms($stop_date - $start_date);
    }
    return (sprintf("%i:%02i:%02i", $h, $m, $s));
}

sub get_job_walltime_change($) {
    my $jobid = shift;
    return OAR::Walltime::get($base, $jobid);
}

1;
