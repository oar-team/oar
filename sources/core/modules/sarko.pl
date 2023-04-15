#!/usr/bin/perl
#Almighty module: check walltimes and jobs to frag
use strict;
use DBI();
use Data::Dumper;
use OAR::IO;
use OAR::Modules::Judas qw(oar_debug oar_warn oar_info oar_error set_current_log_category);
use OAR::Conf qw(init_conf dump_conf get_conf is_conf);
use OAR::Tools;

# Log category
set_current_log_category('main');

my $Module_name = "Sarko";
my $Session_id  = $$;

# Get job delete and checkpoint walltime values
my $Leon_soft_walltime = OAR::Tools::get_default_leon_soft_walltime();
my $Leon_walltime      = OAR::Tools::get_default_leon_walltime();
init_conf($ENV{OARCONFFILE});
if (is_conf("JOBDEL_SOFTWALLTIME")) {
    $Leon_soft_walltime = get_conf("JOBDEL_SOFTWALLTIME");
}
if (is_conf("JOBDEL_WALLTIME")) {
    $Leon_walltime = get_conf("JOBDEL_WALLTIME");
}

if ($Leon_walltime <= $Leon_soft_walltime) {
    $Leon_walltime = $Leon_soft_walltime + 1;
}

my $Server_hostname = get_conf("SERVER_HOSTNAME");

my $Deploy_hostname = get_conf("DEPLOY_HOSTNAME");
if (!defined($Deploy_hostname)) {
    $Deploy_hostname = $Server_hostname;
}

my $Cosystem_hostname = get_conf("COSYSTEM_HOSTNAME");
if (!defined($Cosystem_hostname)) {
    $Cosystem_hostname = $Server_hostname;
}

my $Openssh_cmd = get_conf("OPENSSH_CMD");
$Openssh_cmd = OAR::Tools::get_default_openssh_cmd() if (!defined($Openssh_cmd));

if (is_conf("OAR_SSH_CONNECTION_TIMEOUT")) {
    OAR::Tools::set_ssh_timeout(get_conf("OAR_SSH_CONNECTION_TIMEOUT"));
}

if (is_conf("OAR_RUNTIME_DIRECTORY")) {
    OAR::Tools::set_default_oarexec_directory(get_conf("OAR_RUNTIME_DIRECTORY"));
}

# get script args
my $base = OAR::IO::connect();
if (!defined($base)) {
    oar_error($Module_name, "Can not connect to the database\n", $Session_id);
    exit(1);
}

oar_info($Module_name,
    "Starting with FRAG timeout=$Leon_soft_walltime EXTERMINATE timeout=$Leon_walltime\n",
    $Session_id);

my $guilty_found = 0;
my $current      = OAR::IO::get_date($base);

# Look at leon timers
# Decide if OAR must retry to delete the job or just change values in the database
foreach my $j (OAR::IO::get_timered_job($base)) {
    my $job_ref = OAR::IO::get_job($base, $j->{job_id});
    if (($job_ref->{state} eq "Terminated") ||
        ($job_ref->{state} eq "Error") ||
        ($job_ref->{state} eq "Finishing")) {
        oar_info($Module_name, "Set job to FRAGGED\n", $Session_id, $j->{job_id});
        OAR::IO::job_fragged($base, $j->{job_id});

# Frag again inner jobs: handle a possible race condition if new inner jobs after frag_job was called
        OAR::IO::frag_inner_jobs($base, $j->{job_id},
            "Frag any remaining inner jobs of container job $j->{job_id}\n",
            $Module_name, $Session_id);
    } else {
        my $frag_date = OAR::IO::get_frag_date($base, $j->{job_id});
        oar_info($Module_name, "Job fragged at $frag_date\n", $Session_id, $j->{job_id});
        if (($current > $frag_date + $Leon_soft_walltime) &&
            ($current <= $frag_date + $Leon_walltime)) {
            oar_info($Module_name, "Leon will RE-FRAG bipbip of job $j->{job_id}\n",
                $Session_id, $j->{job_id});
            OAR::IO::job_refrag($base, $j->{job_id});
            $guilty_found = 1;
        } elsif ($current > $frag_date + $Leon_walltime) {
            oar_info($Module_name, "Leon will EXTERMINATE bipbip of job $j->{job_id}\n",
                $Session_id, $j->{job_id});
            OAR::IO::job_leon_exterminate($base, $j->{job_id});
            $guilty_found = 1;
        } else {
            oar_info($Module_name, "Leon timer is not expired yet for the job, do nothing\n",
                $Session_id, $j->{job_id});
        }
    }
}

# Check jobs walltime
my @running_jobs = OAR::IO::get_jobs_in_state($base, "Running");
if (@running_jobs) {
    oar_debug(
        $Module_name,
        "Check running jobs against their walltime: " .
          join(" ", (map { $_->{job_id} } @running_jobs)) . "\n",
        $Session_id);
} else {
    oar_debug($Module_name, "No Running job\n", $Session_id);
}
foreach my $job (@running_jobs) {
    my ($start, $walltime);

    # Get starting time
    $start = $job->{start_time};

    # Get walltime
    my $mold_job = OAR::IO::get_current_moldable_job($base, $job->{assigned_moldable_job});
    $walltime = $mold_job->{moldable_walltime};
    if ($job->{suspended} eq "YES") {

        # This job was suspended so we must recalculate the walltime
        $walltime += OAR::IO::get_job_suspended_sum_duration($base, $job->{job_id}, $current);
    }

    if ($current > $start + $walltime) {
        oar_info($Module_name, "Job $job->{job_id} reached its walltime ($walltime)\n",
            $Session_id, $job->{job_id});
        $guilty_found = 1;
        OAR::IO::lock_table($base, [ "frag_jobs", "event_logs", "jobs" ]);
        OAR::IO::frag_job($base, $job->{job_id});
        OAR::IO::unlock_table($base);
        OAR::IO::add_new_event($base, "WALLTIME", $job->{job_id},
            "Job [$job->{job_id}] reached its walltime (start: $start + walltime:$walltime > current time: $current)"
        );
    } elsif (($job->{checkpoint} > 0) && ($current >= ($start + $walltime - $job->{checkpoint}))) {

        # OAR must notify the job to checkpoint itself
        oar_info($Module_name, "Send checkpoint signal to job $job->{job_id}\n",
            $Session_id, $job->{job_id});

        # Retrieve node names used by the job
        my @hosts           = OAR::IO::get_job_current_hostnames($base, $job->{job_id});
        my $types           = OAR::IO::get_job_types_hash($base, $job->{job_id});
        my $host_to_connect = $hosts[0];
        if ((defined($types->{cosystem})) or ($#hosts < 0)) {
            $host_to_connect = $Cosystem_hostname;
        } elsif (defined($types->{deploy})) {
            $host_to_connect = $Deploy_hostname;
        }
        OAR::IO::add_new_event($base, "CHECKPOINT", $job->{job_id},
            "Checkpoint requested on $host_to_connect");
        my $str_log;
        my @exit_codes;

        # Timeout the ssh command
        eval {
            $SIG{ALRM} = sub { die "alarm\n" };
            alarm(OAR::Tools::get_ssh_timeout());
            @exit_codes =
              OAR::Tools::signal_oarexec($host_to_connect, $job->{job_id}, "SIGUSR2", 1, $base,
                $Openssh_cmd, '');
            alarm(0);
        };
        if ($@) {
            if ($@ eq "alarm\n") {
                $str_log =
                  "Cannot contact $host_to_connect, operation timed out (" .
                  OAR::Tools::get_ssh_timeout() .
                  " s). Checkpoint signal cannot be sent to job $job->{job_id} on $host_to_connect";
                oar_warn($Module_name, "$str_log\n", $Session_id, $job->{job_id});
                OAR::IO::add_new_event($base, "CHECKPOINT_ERROR", $job->{job_id}, $str_log);
            } else {
                $str_log =
                  "An unknown error occured when triggering the checkpoint signal for job $job->{job_id} on $host_to_connect";
                oar_warn($Module_name, "$str_log\n", $Session_id, $job->{job_id});
                OAR::IO::add_new_event($base, "CHECKPOINT_ERROR", $job->{job_id}, $str_log);
            }
        } else {
            if ($exit_codes[0] == 0) {
                $str_log =
                  "The job $job->{job_id} was notified to checkpoint itself on $host_to_connect";
                oar_info($Module_name, "$str_log\n", $Session_id, $job->{job_id});
                OAR::IO::add_new_event($base, "CHECKPOINT_SUCCESSFULL", $job->{job_id}, $str_log);
            } else {
                $str_log =
                  "kill command returned a bad exit code (@exit_codes) on $host_to_connect";
                oar_warn($Module_name, "$str_log\n", $Session_id, $job->{job_id});
                OAR::IO::add_new_event($base, "CHECKPOINT_ERROR", $job->{job_id}, $str_log);
            }
        }
    }
}

# Retrieve nodes with expiry_dates in the past
# special for Desktop computing
my @resources = OAR::IO::get_expired_resources($base);
if ($#resources >= 0) {

    # First mark the nodes as dead
    foreach my $r (@resources) {
        OAR::IO::set_resource_nextState($base, $r, 'Suspected');
        my $rinfo = OAR::IO::get_resource_info($base, $r);
        OAR::IO::add_new_event_with_host(
            $base, "LOG_SUSPECTED", 0,
            "The DESKTOP COMPUTING resource $r has expired on node $rinfo->{network_address}",
            [ $rinfo->{network_address} ]);
    }

    # Then notify Almighty
    my $remote_host = get_conf("SERVER_HOSTNAME");
    my $remote_port = get_conf("SERVER_PORT");

    OAR::Tools::notify_tcp_socket($remote_host, $remote_port, "ChState");
}

my $dead_switch_time = OAR::Tools::get_default_dead_switch_time();
if (is_conf("DEAD_SWITCH_TIME")) {
    $dead_switch_time = get_conf("DEAD_SWITCH_TIME");
}

# Get Absent and Suspected nodes for more than 5 mn (default)
if ($dead_switch_time > 0) {
    my $notify = 0;
    foreach my $r (OAR::IO::get_absent_suspected_resources_for_a_timeout($base, $dead_switch_time))
    {
        OAR::IO::set_resource_nextState($base, $r, "Dead");
        OAR::IO::update_resource_nextFinaudDecision($base, $r, "YES");
        oar_info($Module_name, "Set the next state of $r to Dead\n", $Session_id);
        $notify = 1;
    }
    if ($notify > 0) {
        my $remote_host = get_conf("SERVER_HOSTNAME");
        my $remote_port = get_conf("SERVER_PORT");
        OAR::Tools::notify_tcp_socket($remote_host, $remote_port, "ChState");
    }
}

OAR::IO::disconnect($base);

exit($guilty_found);
