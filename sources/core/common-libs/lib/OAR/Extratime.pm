package OAR::Extratime;

use strict;
use warnings;
use DBI();
use OAR::IO;
use OAR::Conf;

my $REMOTE_HOST;
my $REMOTE_PORT;
my $EXTRA_TIME_DURATION;
my $EXTRA_TIME_REQUEST_DELAY;
my $EXTRA_TIME_MINIMUM_WALLTIME;
my $EXTRA_TIME_DELAY_NEXT_JOBS_ALLOWED_USERS;

sub walltime_percent($$) {
    my $value = shift;
    my $walltime = shift;
    if ($value =~ /^(\d+)(%?)$/);
        if (defined($2)) {
             return $walltime * $1 / 100;
        }
    }
    # value is not a percentage, return itself 
    return $value;
}

sub get($$) {
    my $dbh = shift;
    my $jobid = shift;

    my $job = OAR::IO::get_job($dbh,$jobid);
    if (not defined($job)) {
        return (undef, "Unknown", undef);
    }
    my $extratime = OAR::IO::get_extratime_for_job($dbh, $jobid); # no lock here

    OAR::Conf::init_conf($ENV{OARCONFFILE});
    $REMOTE_HOST = OAR::Conf::get_conf("SERVER_HOSTNAME");
    $REMOTE_PORT = OAR::Conf::get_conf("SERVER_PORT");
    $EXTRA_TIME_DURATION = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_DURATION", $job->{queue_name}, 0);
    $EXTRA_TIME_INCREMENT = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_INCREMENT", $job->{queue_name}, 0);
    $EXTRA_TIME_REQUEST_DELAY = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_REQUEST_DELAY", $job->{queue_name}, 0);
    $EXTRA_TIME_MINIMUM_WALLTIME = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_MINIMUM_WALLTIME", $job->{queue_name}, 0);
    $EXTRA_TIME_DELAY_NEXT_JOBS_ALLOWED_USERS = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_DELAY_NEXT_JOBS_ALLOWED_USERS", $job->{queue_name}, "");

    my $moldable = OAR::IO::get_current_moldable_job($dbh, $job->{assigned_moldable_job});
    my $now = OAR::IO::get_date($dbh);
    my $suspended = OAR::IO::get_job_suspended_sum_duration($dbh, $jobid, $now);

    $EXTRA_TIME_DURATION = walltime_percent($EXTRA_TIME_DURATION, $moldable->{moldable_walltime});
    $EXTRA_TIME_REQUEST_DELAY = walltime_percent($EXTRA_TIME_REQUEST_DELAY, $moldable->{moldable_walltime});

    my $allowed_request_date = undef; 
    if ($job->{state} eq "Running") {
      $allowed_request_date = $job->{start_time} + $moldable->{moldable_walltime} + $suspended - $EXTRA_TIME_REQUEST_DELAY;
    }
    if ($EXTRA_TIME_DURATION <= 0 or $job->{state} ne "Running" or $moldable->{moldable_walltime} < $EXTRA_TIME_MINIMUM_WALLTIME or ($EXTRA_TIME_REQUEST_DELAY > 0 and $allowed_request_date > $now)) {
        $extratime->{possible} = 0;
    } else {
        $extratime->{possible} = $EXTRA_TIME_DURATION;
    }
    if (not defined($extratime->{pending})) {
        $extratime->{pending} = 0;
    }
    if (not defined($extratime->{granted})) {
        $extratime->{granted} = 0;
    }
    if ($EXTRA_TIME_DELAY_NEXT_JOBS_ALLOWED_USERS ne "*" and not grep(/^$job->{job_user}$/,split(/[,\s]+/,$EXTRA_TIME_DELAY_NEXT_JOBS_ALLOWED_USERS))) {
        $extratime->{delay_next_jobs} = "FORBIDDEN";
    } elsif (exists($extratime->{delay_next_jobs}) and $extratime->{pending} == 0) {
        delete $extratime->{delay_next_jobs};
    }
    if (exists($extratime->{granted_with_delaying_next_jobs}) and defined($extratime->{granted_with_delaying_next_jobs}) and $extratime->{granted_with_delaying_next_jobs} == 0) {
        delete $extratime->{granted_with_delaying_next_jobs};
    }
    return ($extratime, $job->{state}, $moldable->{moldable_walltime});
}

sub request($$$$$) {
    my $dbh = shift;
    my $jobid = shift;
    my $lusr = shift;
    my $requested_extratime = shift;
    my $delay_next_jobs = shift;
    my $job;
    my $moldable;
    my @result;

    $job = OAR::IO::get_job($dbh, $jobid);

    if (not defined($job)) {
        return (4, 404, "not found", "could not find job $jobid");
    }

    OAR::Conf::init_conf($ENV{OARCONFFILE});
    $REMOTE_HOST = OAR::Conf::get_conf("SERVER_HOSTNAME");
    $REMOTE_PORT = OAR::Conf::get_conf("SERVER_PORT");
    $EXTRA_TIME_DURATION = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_DURATION", $job->{queue_name}, 0);
    $EXTRA_TIME_INCREMENT = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_INCREMENT", $job->{queue_name}, 0);
    $EXTRA_TIME_REQUEST_DELAY = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_REQUEST_DELAY", $job->{queue_name}, 0);
    $EXTRA_TIME_MINIMUM_WALLTIME = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_MINIMUM_WALLTIME", $job->{queue_name}, 0);
    $EXTRA_TIME_DELAY_NEXT_JOBS_ALLOWED_USERS = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_DELAY_NEXT_JOBS_ALLOWED_USERS", $job->{queue_name}, "");

    $moldable = OAR::IO::get_current_moldable_job($dbh, $job->{assigned_moldable_job});
    $EXTRA_TIME_DURATION = walltime_percent($EXTRA_TIME_DURATION, $moldable->{moldable_walltime});
    $EXTRA_TIME_REQUEST_DELAY = walltime_percent($EXTRA_TIME_REQUEST_DELAY, $moldable->{moldable_walltime});

    # Is extratime possible ?
    if (not defined($lusr)) {
        return (1, 400, "bad request", "anonymous request is not allowed");
    } elsif ($EXTRA_TIME_DURATION <= 0 and not grep(/^$lusr$/,('root','oar'))) { 
        return (3, 403, "forbidden", "user is not allowed to add extra time");
    } elsif ($EXTRA_TIME_DURATION < 0) {
        return (5, 405, "not available", "functionality is disabled");
    }
    
    # Job user must be lusr or root or oar
    if ($job->{job_user} ne $lusr and not grep(/^$lusr$/,('root','oar'))) { 
        return (3, 403, "forbidden", "job $jobid does not belong to you");
    }
    
    # Job must be running
    if ($job->{state} ne "Running") { 
        return (3, 403, "forbidden", "job $jobid is not running");
    }

    # If $delay_next_jobs != YES then undef
    if (defined($delay_next_jobs) and uc($delay_next_jobs) ne "YES") {
        $delay_next_jobs = undef;
    }
    # Can extra time delay next jobs ?
    if (defined($delay_next_jobs) and $EXTRA_TIME_DELAY_NEXT_JOBS_ALLOWED_USERS ne "*" and not grep(/^$lusr$/,('root','oar',split(/[,\s]+/,$EXTRA_TIME_DELAY_NEXT_JOBS_ALLOWED_USERS)))) {
        return (3, 403, "forbidden", "walltime change for this job cannot delay other jobs");
    }
    
    # Is job walltime big enough to allow extra time ?
    if ($moldable->{moldable_walltime} < $EXTRA_TIME_MINIMUM_WALLTIME) {
        return (3, 403, "forbidden", "walltime change is not allowed for a job with walltime < ${EXTRA_TIME_MINIMUM_WALLTIME}s");
    }
    
    # Handle the case where extratime duration is given as a new absolute walltime or is negative
    if ($requested_extratime =~ /^(\d+)$/) {
        $requested_extratime = $1 - $moldable->{moldable_walltime};
    } elsif ($requested_extratime =~ /^([-+]\d+)$/) {
        $requested_extratime = $1;
    }

    # For negative extratime, do not allow end time before now
    my $job_remaining_time = $job->{start_time} + $moldable->{moldable_walltime} + $suspended - $now;
    if ($job_remaining_time < - $requested_extratime) { 
        $requested_extratime = - $job_remaining_time;
    }

    # Is job old enough for an extratime request ?
    my $now = OAR::IO::get_date($dbh);
    my $suspended = OAR::IO::get_job_suspended_sum_duration($dbh, $jobid, $now);
    my $allowed_request_date = $job->{start_time} + $moldable->{moldable_walltime} + $suspended - $EXTRA_TIME_REQUEST_DELAY;
    if ($requested_extratime > 0 and $EXTRA_TIME_REQUEST_DELAY > 0 and $allowed_request_date > $now) {
        return (3, 403, "forbidden", "walltime increase is not possible yet (only possible in the last ".$EXTRA_TIME_REQUEST_DELAY."s before the predicted end of the job)");
    }

    OAR::IO::lock_table($dbh,['oarextratime']);
    my $current_extratime = OAR::IO::get_extratime_for_job($dbh, $job->{job_id}); # locked here
    if (defined($current_extratime)) { # Update a request
        if ($current_extratime->{granted} + $requested_extratime > $EXTRA_TIME_DURATION and not grep(/^$lusr$/,('root','oar'))) { 
            @result = (3, 503, "forbidden", "request cannot be updated because the walltime cannot increase for more than ".$EXTRA_TIME_DURATION."s");
        } else {
            OAR::IO::update_extratime($dbh,$job->{job_id},$requested_extratime, ((defined($delay_next_jobs) and $requested_extratime > 0)?'YES':'NO'), $EXTRA_TIME_INCREMENT, undef, undef);
            @result = (0, 202, "accepted", "walltime change request updated for job ".$job->{job_id}.", it will be handled shortly");
        }
    } else { # New request
        if ($requested_extratime > $EXTRA_TIME_DURATION and not grep(/^$lusr$/,('root','oar'))) {
            @result = (3, 503, "forbidden", "request cannot be accepted because the walltime cannot increase for more than ".$EXTRA_TIME_DURATION."s");
        } else {
            OAR::IO::add_extratime($dbh,$job->{job_id},$requested_extratime,((defined($delay_next_jobs) and $requested_extratime > 0)?'YES':'NO', $EXTRA_TIME_INCREMENT));
            @result = (0, 202, "accepted", "walltime change request accepted for job ".$job->{job_id}.", it will be handled shortly");
        }
    }
    OAR::IO::unlock_table($dbh);

    if ($result[0] == 0) {
        OAR::Tools::notify_tcp_socket($REMOTE_HOST,$REMOTE_PORT,"Extratime");
    }
    return @result;
}

1;
