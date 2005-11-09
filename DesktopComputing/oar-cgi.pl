#!/usr/bin/perl
# $Id: oar-cgi.pl,v 1.3 2005/04/04 13:11:55 capitn Exp $

use strict;
use Data::Dumper;
use oar_iolib;
use DBI();
use oar_conflib qw(init_conf dump_conf get_conf is_conf);
use oar_Judas qw(oar_debug oar_warn oar_error);
use IO::Socket::INET;
use CGI;
use File::Copy;

######
# parameters
######
init_conf("oar.conf");
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
	my $maxweight=$cgi->param('MAXWEIGHT') or die "Node max weight missing.";
	my $base = iolib::connect() or die "cannot connect to the data base\n";
	my $is_desktop_computing = iolib::is_node_desktop_computing($base,$hostname);
	my $do_notify;
	$do_notify=undef;
	if ($quit) {
		if (defined $is_desktop_computing and $is_desktop_computing eq 'YES') {
			$base->do("LOCK TABLE nodes WRITE, nodeProperties WRITE");
			iolib::set_node_nextState($base,$hostname,"Absent");
			iolib::set_node_expiryDate($base,$hostname,"NOW()");
			$base->do("UNLOCK TABLES");
			$do_notify=1;
		} else {
			iolib::disconnect($base);
			my $msg = "$hostname is not declared as a Desktop Computing node in OAR database.\n";
			my $data = { 'error' => $msg };
			httpwrite(serialize($data),'application/data');
			exit 0;
		}
	} else {
		if (defined $is_desktop_computing) {
			if ($is_desktop_computing eq 'YES') {
				$base->do("LOCK TABLE nodes WRITE, nodeProperties WRITE");
				iolib::set_node_nextState($base,$hostname,"Alive");
				iolib::set_node_expiryDate($base,$hostname,"NOW() + INTERVAL $expiry MINUTE");
				$base->do("UNLOCK TABLES");
				$do_notify=1;
			} else {
				iolib::disconnect($base);
				my $msg = "$hostname is not declared as a Desktop Computing node in OAR database.\n";
				my $data = { 'error' => $msg };
				httpwrite(serialize($data),'application/data');
				exit 0;
			}
		} else {
			if ($allow_create_node) {
				message "Trying to add $hostname to OAR database...\n";
				$base->do("LOCK TABLE nodes WRITE, nodeProperties WRITE, nodeState_log WRITE");
				iolib::add_node($base, $hostname, "Alive", $maxweight, "YES");
				iolib::set_node_nextState($base,$hostname,"Alive");
				iolib::set_node_expiryDate($base,$hostname,"NOW() + INTERVAL $expiry MINUTE");
				$base->do("UNLOCK TABLES");
				$do_notify=1;
			} else {
				iolib::disconnect($base);
				my $msg = "$hostname is not a known Desktop Computing node, declare it in OAR database first.\n";
				my $data = { 'error' => $msg };
				httpwrite(serialize($data),'application/data');
				exit 0;
			}
		}
	}
	if ($do_notify) {
		my $socket = IO::Socket::INET->new(PeerAddr => $remote_host,
    	                               PeerPort => $remote_port,
      	                             Proto => "tcp",
        	                           Type  => SOCK_STREAM)
		or die("cgi-pull: Couldn't connect executor $remote_host:$remote_port\n");
		print $socket "ChState\n";
		close $socket;
	}

	my $agentJobs=unserialize($cgi->param('JOBS'));
	my $dbJobs = iolib::get_desktop_computing_host_jobs($base,$hostname);
	my $toLaunchJobs = undef;
	my $toKillJobs = undef;
	foreach my $jobid (keys %$dbJobs) {
		if (iolib::is_tokill_job($base, $jobid)) {
			message "$jobid must be killed\n";
			$toKillJobs->{$jobid}=$dbJobs->{$jobid};
			iolib::job_arm_leon_timer($base, $jobid)
		} else {
			message "$jobid must be kept running\n";
		}
		if (not $quit and $dbJobs->{$jobid}->{'state'} eq "toLaunch") {
			$toLaunchJobs->{$jobid}=$dbJobs->{$jobid};
#			$toLaunchJobs->{$jobid}->{'pulltime'} = iolib::get_unix_timestamp($base);
			my $stagein = iolib::get_job_stagein($base,$jobid);
			if (defined $stagein->{'md5sum'}) {
				$toLaunchJobs->{$jobid}->{'stagein'}->{'md5sum'}=$stagein->{'md5sum'};
				$toLaunchJobs->{$jobid}->{'stagein'}->{'compression'}=$stagein->{'compression'};
				$toLaunchJobs->{$jobid}->{'stagein'}->{'size'}=$stagein->{'size'};
			}
#			iolib::set_job_state($base,$jobid,"Launching");
			iolib::set_running_date($base,$jobid);
			iolib::set_job_state($base,$jobid,"Running");
		} elsif ($dbJobs->{$jobid}->{'state'} eq "Launching" or $dbJobs->{$jobid}->{'state'} eq "Running" ) {
			unless (grep $jobid, keys %$agentJobs) {
				message("[oar-cgi $jobid] Job $jobid terminated\n");
				$base->do("LOCK TABLE jobs WRITE, nodes WRITE, processJobs WRITE, processJobs_log WRITE,nodeState_log WRITE");
				iolib::set_finish_date($base,$jobid);
				iolib::decrease_weight($base,$jobid);
				iolib::delete_job_process($base,$jobid);
	      my $strWARN = "[oar-cgi $jobid] Job was killed";
        message("$strWARN\n");
        iolib::set_job_state($base,$jobid,"Error");
        iolib::set_job_message($base,$jobid,"$strWARN");
				$base->do("UNLOCK TABLES");
			}
		} 
	}
	$do_notify=undef;
	foreach my $jobid (keys %$agentJobs) {
		if (defined $agentJobs->{$jobid}->{'terminated'}) {
			# TODO: As soon as BibBip becomes a library, replace this copy of BipBip code by a function call.
			#	my $base = iolib::connect() or die "cgi-job-end: cannot connect to the data base\n";
			message("Job $jobid terminated\n");
			$base->do("LOCK TABLE jobs WRITE, nodes WRITE, processJobs WRITE, processJobs_log WRITE,nodeState_log WRITE");
			my $refJob = iolib::get_job($base,$jobid);
		  if ($refJob->{'state'} eq "Running"){
				iolib::set_finish_date($base,$jobid);
				message("Release nodes for $jobid\n");
				iolib::decrease_weight($base,$jobid);
				iolib::delete_job_process($base,$jobid);
				if ($agentJobs->{$jobid}->{'terminated'} eq 'exit' and $agentJobs->{$jobid}->{'exitstatus'} == 0) {
					message("Launch completed OK for $jobid\n");
					iolib::set_job_state($base,$jobid,"Terminated");
					iolib::set_job_message($base,$jobid,"ALL is GOOD");
				} else {
	        my $strWARN = "Job $jobid failed (maybe killed)";
          message("$strWARN\n");
          iolib::set_job_state($base,$jobid,"Error");
          iolib::set_job_message($base,$jobid,"$strWARN");
				}
			} else {
				message("Job $jobid was previously killed or Terminated but I did not know that!!\n");
			}
			$base->do("UNLOCK TABLES");
		}	
	}
	iolib::disconnect($base);
	if ($do_notify) {
		my $socket = IO::Socket::INET->new(PeerAddr => $remote_host,
    	                               PeerPort => $remote_port,
      	                             Proto => "tcp",
        	                           Type  => SOCK_STREAM)
		or die("oar-cgi: Couldn't connect executor $remote_host:$remote_port\n");
		print $socket "BipBip\n";
		close $socket;
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
	my $base = iolib::connect() or die "cannot connect to the data base\n";
	my $stagein = iolib::get_job_stagein($base,$jobid);
	iolib::disconnect($base);
	if ($stagein->{'method'} eq "FILE") {
		httpwrite("","data/binary");
		open F,"< ".$stagein->{'location'} or die "Can't open stagein ".$stagein->{'location'}.": $!";
		print <F>;
		close F;
	} else {
		die "Stagein method ".$stagein->{'method'}." not yet implemented.\n";
	} 
#	iolib::set_running_date($base,$jobid);
#	iolib::set_job_state($base,$jobid,"Running");
#	iolib::disconnect($base);
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
	system "oarres $jobid $filename < /dev/null >& /dev/null &";
}

#####
# main fucntion
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
