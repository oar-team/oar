#!/usr/bin/perl
# $Id$

use strict;
use Data::Dumper;
use OAR::IO;
use DBI();
use OAR::Conf qw(init_conf dump_conf get_conf is_conf);
use OAR::Modules::Judas qw(oar_debug oar_warn oar_error);
use IO::Socket::INET;
use CGI;
use File::Copy;
use OAR::Tools;

######
# parameters
######
init_conf($ENV{OARCONFFILE});
my $remote_host = get_conf("SERVER_HOSTNAME");
my $remote_port = get_conf("SERVER_PORT");
my $expiry = get_conf("DESKTOP_COMPUTING_EXPIRY");
my $allow_create_node = get_conf("DESKTOP_COMPUTING_ALLOW_CREATE_NODE");
my $stageout_dir = get_conf("STAGEOUT_DIR");
my $stagein_dir = get_conf("STAGEIN_DIR");
my $log_level = get_conf("LOG_LEVEL");

(defined $remote_host) or die "Missing configuration parameter: server hostname.\n";
(defined $remote_port) or die "Missing configuration parameter: server port.\n";
(defined $expiry) or die "Missing configuration parameter: desktop computing expiry delay.\n";
(defined $allow_create_node) or die "Missing configuration parameter: allow create node.\n";
(defined $stageout_dir) or die "Missing configuration parameter: job stageouts storage directory.\n";
(defined $stagein_dir) or die "Missing configuration parameter: job stageins storage directory.\n";
(defined $log_level) or die "Missing configuration parameter: log level.\n";

unless (-d $stageout_dir and -w $stageout_dir) {
    system "mkdir -p $stageout_dir" and die "Cannot create directory $stageout_dir: $!\n";
}
unless (-d $stagein_dir and -w $stagein_dir) {
    system "mkdir -p $stagein_dir" and die "Cannot create directory $stagein_dir: $!\n";
}

######
# Internal data
######

# suitable Data::Dumper configuration for serialization
$Data::Dumper::Purity = 1;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 0;
$Data::Dumper::Deepcopy = 1;

my $cgi = new CGI;

######
# Miscelanious common functions
######

# prints messages on STDERR if in verbose mode
# parameters: a message
sub message($) {
    my $msg = shift;
    ($log_level > 2) and warn $msg;
}

# serialize data
# parameters: perl data
# return: serialized data
sub serialize($) {
    my $data = shift;
    my $serialized = Dumper($data);
    return $serialized;
}

# unserialize data
# parameters: serialized data
# return: perl data
sub unserialize($) {
    my $serialized = shift;

    my $data = eval($serialized);

    return $data;
}

# write http message
# parameters: content, content-type
sub httpwrite($$) {
    my $content = shift;
    my $content_type = shift;
    defined $content_type or $content_type = 'text/plain';
    print $cgi->header($content_type);
    print $content;
}

######
# pull request handling
######

# pull function
# First update node status in OAR database -> Alive + expiry-data++ unless we actually quit
# if node does not exist yet, we try to declare it, if the configuration allows that.
# Then process jobs, to kill or to launch, with error handling
sub pull() {
    my $quit=$cgi->param('QUIT');
    my $hostname=$cgi->param('HOSTNAME') or die "Node hostname missing.";
    my $base = OAR::IO::connect() or die "cannot connect to the data base\n";
    my $is_desktop_computing = OAR::IO::is_node_desktop_computing($base,$hostname);
    my $do_notify;
    $do_notify=undef;
    if ($quit) {
        if (defined $is_desktop_computing and $is_desktop_computing eq 'YES') {
            OAR::IO::lock_table($base,["resources"]);
            OAR::IO::set_node_nextState($base,$hostname,"Absent");
            OAR::IO::set_node_expiryDate($base,$hostname,OAR::IO::get_date($base));
            OAR::IO::unlock_table($base);
            $do_notify=1;
	} else {
            OAR::IO::disconnect($base);
            my $msg = "$hostname is not declared as a Desktop Computing node in OAR database.\n";
            my $data = { 'error' => $msg };
            httpwrite(serialize($data),'application/data');
            exit 0;
        }
    } else {
        if (defined $is_desktop_computing) {
            if ($is_desktop_computing eq 'YES') {
                OAR::IO::lock_table($base,["resources"]);
                if (OAR::IO::set_node_nextState_if_necessary($base,$hostname,"Alive") > 0){
                    $do_notify=1;
                }
                OAR::IO::set_node_expiryDate($base,$hostname, OAR::IO::get_date($base) + $expiry);
                OAR::IO::unlock_table($base);
	    } else {
                OAR::IO::disconnect($base);
                my $msg = "$hostname is not declared as a Desktop Computing node in OAR database.\n";
                my $data = { 'error' => $msg };
                httpwrite(serialize($data),'application/data');
                exit 0;
            }
        } else {
            if ($allow_create_node) {
                message "Trying to add $hostname to OAR database...\n";
                my $resource = OAR::IO::add_resource($base, $hostname, "Alive");
                OAR::IO::set_resource_property($base,$resource,"desktop_computing","YES");
                OAR::IO::set_resource_nextState($base,$resource,"Alive");
                OAR::IO::set_node_expiryDate($base,$hostname, OAR::IO::get_date($base) + $expiry);
                $do_notify=1;
            } else {
                OAR::IO::disconnect($base);
                my $msg = "$hostname is not a known Desktop Computing node, declare it in OAR database first.\n";
                my $data = { 'error' => $msg };
                httpwrite(serialize($data),'application/data');
                exit 0;
            }
        }
    }
    if ($do_notify) {
        OAR::Tools::notify_tcp_socket($remote_host,$remote_port,"ChState");
    }

    my $agentJobs=unserialize($cgi->param('JOBS'));
    my $dbJobs = OAR::IO::get_desktop_computing_host_jobs($base,$hostname);
    my $toLaunchJobs = undef;
    my $toKillJobs = undef;
    foreach my $jobid (keys %$dbJobs) {
        if (OAR::IO::is_tokill_job($base, $jobid)) {
            message "$jobid must be killed\n";
            $toKillJobs->{$jobid}=$dbJobs->{$jobid};
            OAR::IO::job_arm_leon_timer($base, $jobid)
        } else {
            message "$jobid must be kept running\n";
        }
        if (not $quit and $dbJobs->{$jobid}->{'state'} eq "toLaunch") {
            $toLaunchJobs->{$jobid}=$dbJobs->{$jobid};
#			$toLaunchJobs->{$jobid}->{'pulltime'} = OAR::IO::get_unix_timestamp($base);
            my $stagein = OAR::IO::get_job_stagein($base,$jobid);
            if (defined $stagein->{'md5sum'}) {
                $toLaunchJobs->{$jobid}->{'stagein'}->{'md5sum'}=$stagein->{'md5sum'};
                $toLaunchJobs->{$jobid}->{'stagein'}->{'compression'}=$stagein->{'compression'};
                $toLaunchJobs->{$jobid}->{'stagein'}->{'size'}=$stagein->{'size'};
            }
#			OAR::IO::set_job_state($base,$jobid,"Launching");
            OAR::IO::set_running_date($base,$jobid);
            OAR::IO::set_job_state($base,$jobid,"Running");
        } elsif ($dbJobs->{$jobid}->{'state'} eq "Launching" or $dbJobs->{$jobid}->{'state'} eq "Running" ) {
            unless (grep $jobid, keys %$agentJobs) {
                message("[oar-cgi $jobid] Job $jobid terminated\n");
                OAR::IO::lock_table($base,["jobs","job_state_logs","resources","assigned_resources","event_logs","challenges","moldable_job_descriptions","job_types","job_dependencies","job_resource_groups","job_resource_descriptions"]);
                OAR::IO::set_finish_date($base,$jobid);
                my $strWARN = "[oar-cgi $jobid] Job was killed";
                message("$strWARN\n");
                OAR::IO::set_job_state($base,$jobid,"Error");
                OAR::IO::set_job_message($base,$jobid,"$strWARN");
                OAR::IO::unlock_table($base);
            }
        } 
    }
    $do_notify=undef;
    foreach my $jobid (keys %$agentJobs) {
        if (defined $agentJobs->{$jobid}->{'terminated'}) {
            $do_notify = 1;
            # TODO: As soon as BibBip becomes a library, replace this copy of BipBip code by a function call.
            #	my $base = OAR::IO::connect() or die "cgi-job-end: cannot connect to the data base\n";
            message("Job $jobid terminated\n");
            OAR::IO::lock_table($base,["jobs","job_state_logs","resources","assigned_resources","event_logs","challenges","moldable_job_descriptions","job_types","job_dependencies","job_resource_groups","job_resource_descriptions"]);
            my $refJob = OAR::IO::get_job($base,$jobid);
            if ($refJob->{'state'} eq "Running"){
                OAR::IO::set_finish_date($base,$jobid);
                message("Release nodes for $jobid\n");
                if ($agentJobs->{$jobid}->{'terminated'} eq 'exit' and $agentJobs->{$jobid}->{'exitstatus'} == 0) {
                    message("Launch completed OK for $jobid\n");
                    OAR::IO::set_job_state($base,$jobid,"Terminated");
                    OAR::IO::set_job_message($base,$jobid,"ALL is GOOD");
                } else {
                    my $strWARN = "Job $jobid failed (maybe killed)";
                    message("$strWARN\n");
                    OAR::IO::set_job_state($base,$jobid,"Error");
                    OAR::IO::set_job_message($base,$jobid,"$strWARN");
                }
            } else {
                message("Job $jobid was previously killed or Terminated but I did not know that!!\n");
            }
            OAR::IO::unlock_table($base);
        }	
    }
    OAR::IO::disconnect($base);
    if ($do_notify) {
        OAR::Tools::notify_tcp_socket($remote_host,$remote_port,"Term");
    }
    # End of BipBip code.

    my $data = {
                'launch' => $toLaunchJobs,
                'kill' => $toKillJobs,
                };
    message "toLaunchJobs=".serialize($toLaunchJobs)."\n";
    message "toKillJobs=".serialize($toKillJobs)."\n";
#	message "pull=".serialize($data)."\n";
    httpwrite(serialize($data),'application/data');
}

######
# stagein request handling
######

# job stagein function
# gives the stagein for a job
sub jobStageIn() {
    my $jobid =$cgi->param('JOBID') or die "JOBID not found.\n";
    my $base = OAR::IO::connect() or die "cannot connect to the data base\n";
    my $stagein = OAR::IO::get_job_stagein($base,$jobid);
    OAR::IO::disconnect($base);
    if ($stagein->{'method'} eq "FILE") {
        httpwrite("","data/binary");
        open F,"< ".$stagein->{'location'} or die "Can't open stagein ".$stagein->{'location'}.": $!";
        print <F>;
        close F;
    } else {
        die "Stagein method ".$stagein->{'method'}." not yet implemented.\n";
    } 
#	OAR::IO::set_running_date($base,$jobid);
#	OAR::IO::set_job_state($base,$jobid,"Running");
#	OAR::IO::disconnect($base);
}

######
# stageout request handling
######

# job stageout function
# retrieve a job stageout
sub jobStageOut() {
    my $jobid =$cgi->param('JOBID');
    defined $jobid or die "JOBID not found.\n";
    my $out = $cgi->upload('STAGEOUT');
    my $filename = $stageout_dir.$jobid.".tgz";
    copy($out,$filename) or message "Job $jobid stageout retrieval failed $!\n";
    httpwrite("Job $jobid stageout.","text/plain");
    system "$ENV{OARDIR}/oarres $jobid $filename < /dev/null >& /dev/null &";
}

#####
# main function
#####
sub main() {
    my $reqtype = $cgi->param('REQTYPE') or "REQTYPE not found.\n";
    if ($reqtype eq 'PULL') {
        pull();
    } elsif ( $reqtype eq 'STAGEIN') {
        jobStageIn();
    } elsif ( $reqtype eq 'STAGEOUT') {
        jobStageOut();
    } else {
        die "Invalid REQTYPE: ".$reqtype."\n";
    }
}

#####
# Here we go !
#####
main();
