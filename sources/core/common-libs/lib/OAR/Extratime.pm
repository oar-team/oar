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
my $EXTRA_TIME_FORCE_ALLOWED_USERS;

my $dbh;
my $job;
my $moldable;
my $delay_next_jobs;
my $lusr;

sub prepare($$$) {
    my $jobid = shift;
    $lusr = shift;
    $delay_next_jobs = shift;
    $dbh = OAR::IO::connect() or return  (1, 500, "Database error", "Cannot connect to OAR database");
    $job = OAR::IO::get_job($dbh, $jobid);

    if (not defined($job)) {
        return (4, 404, "Not found", "Could not find job $jobid");
    }

    OAR::Conf::init_conf($ENV{OARCONFFILE});
    $REMOTE_HOST = OAR::Conf::get_conf("SERVER_HOSTNAME");
    $REMOTE_PORT = OAR::Conf::get_conf("SERVER_PORT");
    $EXTRA_TIME_DURATION = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_DURATION", $job->{queue_name}, 0);
    $EXTRA_TIME_REQUEST_DELAY = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_REQUEST_DELAY", $job->{queue_name}, 0);
    $EXTRA_TIME_MINIMUM_WALLTIME = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_MINIMUM_WALLTIME", $job->{queue_name}, 0);
    $EXTRA_TIME_FORCE_ALLOWED_USERS = OAR::Conf::get_conf_from_hash_with_default_value("EXTRA_TIME_DELAY_NEXT_JOBS_ALLOWED_USERS", $job->{queue_name}, "");

    # Is extratime possible ?
    if (not defined($lusr)) {
        return (1, 400, "Bad request", "Anonymous request is not allowed");
    } elsif ($EXTRA_TIME_DURATION <= 0 and not grep(/^$lusr$/,('root','oar'))) { 
        return (3, 403, "Forbidden", "User is not allowed to add extra time");
    } elsif ($EXTRA_TIME_DURATION < 0) {
        return (5, 405, "Not available", "Functionality is disabled");
    }
    
    # Job user must be lusr or root or oar
    if ($job->{job_user} ne $lusr and not grep(/^$lusr$/,('root','oar'))) { 
        return (3, 403, "Forbidden", "Job $jobid does not belong to you");
    }
    
    # Job must be running
    if ($job->{state} ne "Running") { 
        return (3, 403, "Forbidden", "Job $jobid is not running");
    }

    # No $delay_next_jobs => undef
    if (defined($delay_next_jobs) and uc($delay_next_jobs) ne "YES") {
        $delay_next_jobs = undef;
    }
    # Can extra time delay next jobs ?
    if (defined($delay_next_jobs) and $EXTRA_TIME_FORCE_ALLOWED_USERS ne "*" and not grep(/^$lusr$/,('root','oar',split(/[,\s]+/,$EXTRA_TIME_FORCE_ALLOWED_USERS)))) {
        return (3, 403, "Forbidden", "Delaying next jobs is not allowed");
    }
    
    # Is job walltime big enough to allow extra time ?
    $moldable = OAR::IO::get_current_moldable_job($dbh, $job->{assigned_moldable_job});
    if ($moldable->{moldable_walltime} < $EXTRA_TIME_MINIMUM_WALLTIME) {
        return (3, 403, "Forbidden", "Extra time request is not allowed for a job with walltime < than $EXTRA_TIME_MINIMUM_WALLTIME s");
    }
    
    # Is job old enough for an extratime request ?
    my $now = OAR::IO::get_date($dbh);
    my $suspended = OAR::IO::get_job_suspended_sum_duration($dbh, $jobid, $now);
    my $allowed_request_date = $job->{start_time} + $moldable->{moldable_walltime} + $suspended - $EXTRA_TIME_REQUEST_DELAY;
    if ($EXTRA_TIME_REQUEST_DELAY > 0 and $allowed_request_date > $now) {
        return (3, 403, "Forbidden", "Request of extra time for job $jobid is only possible in the last ".$EXTRA_TIME_REQUEST_DELAY." s before the end of the job (from ".localtime($allowed_request_date)." onwards)");
    }
    return (0, 200, "OK", "OK");
}

sub status() {
    my $current_extratime = OAR::IO::get_extratime_for_job($dbh, $job->{job_id}); # no lock here
    OAR::IO::disconnect($dbh);
    if (not defined($current_extratime)) {
        $current_extratime = {
            walltime => $moldable->{moldable_walltime},
            granted => 0,
            pending => 0,
            delay_next_jobs => 'NO'
        };
    } else {
        $current_extratime->{walltime} = $moldable->{moldable_walltime};
    }
    return $current_extratime;
}

sub request($) {
    my $requested_extratime = shift;
    my @result;
    OAR::IO::lock_table($dbh,['oarextratime']);
    my $current_extratime = OAR::IO::get_extratime_for_job($dbh, $job->{job_id}); # locked here
    if (defined($current_extratime)) { # Update a request
        if ($current_extratime->{granted} + $requested_extratime > $EXTRA_TIME_DURATION and not grep(/^$lusr$/,('root','oar'))) { 
            @result = (3, 503, "Forbidden", "Request cannot be accepted: you cannot get more than ".$EXTRA_TIME_DURATION." s of extra time");
        } else {
            OAR::IO::update_extratime_request($dbh,$job->{job_id},(defined($delay_next_jobs)?'YES':'NO'),$requested_extratime, undef);
            @result = (0, 202, "Accepted", "Extra time request updated for job ".$job->{job_id}.". It will be handled shortly");
        }
    } else { # New request
        if ($requested_extratime > $EXTRA_TIME_DURATION and not grep(/^$lusr$/,('root','oar'))) {
            @result = (3, 503, "Forbidden", "Request cannot be accepted: you cannot get more than ".$EXTRA_TIME_DURATION." s of extra time");
        } else {
            OAR::IO::add_extratime_request($dbh,$job->{job_id},(defined($delay_next_jobs)?'YES':'NO'),$requested_extratime);
            @result = (0, 202, "Accepted", "Extra time request registered for job ".$job->{job_id}.". It will be handled shortly");
        }
    }
    OAR::IO::unlock_table($dbh);
    OAR::IO::disconnect($dbh);

    if ($result[0] == 0) {
        OAR::Tools::notify_tcp_socket($REMOTE_HOST,$REMOTE_PORT,"Extratime");
    }
    return @result;
}

1;
