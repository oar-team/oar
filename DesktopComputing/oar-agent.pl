#!/usr/bin/perl
# $Id$
# OAR agent for Desktop Computing
#####
# use packages
#####
# {{{
use warnings;
use strict;
use Sys::Hostname;
use POSIX qw(:signal_h :errno_h :sys_wait_h);
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST $DYNAMIC_FILE_UPLOAD);
use URI::URL;
use Fcntl ':flock';
use IO::Handle;
use Getopt::Long;
use File::Basename;
# }}}

######
# Command line arameters...
######
# {{{
my $hostname;
my $sleep_next_pull;
my $stageindir;
my $cache_timeout;
my $pidfile;
my $verbose;
my $help;

Getopt::Long::Configure ("gnu_getopt");

GetOptions ("nodename|n=s" => \$hostname,
            "pull-interval|i=i"  => \$sleep_next_pull,
            "stagein-directory|d=s" => \$stageindir,
            "stagein-timeout|t=s" => \$cache_timeout,
            "pidfile|p=s" => \$pidfile,
            "verbose|v" => \$verbose,
            "help|h" => \$help,
           );

sub usage() {
    print <<EOS;
Usage: $0 [OPTIONS] <URL>
Run OAR Desktop Computing HTTP agent, using URL as the CGI proxy to OAR server
Options are:
 -n, --nodename=           OAR node hostname (default: system hostname)
 -i, --pull-interval=      OAR server pull interval in seconds (default: 30)
 -d, --stagein-directory=  directory where stageins are stored (default: ./stageins)
 -r, --stagein-timeout=    how long do we keep a stagein in cache (default: 300)
 -p, --pidfile=            write the main process pid in this file
 -v, --verbose             increase verbosity
 -h, --help                show this message
EOS
    exit 1;
}

(defined $help) and usage();
my $url = $ARGV[0];
(defined $url) or usage();
(defined $hostname) or $hostname = hostname();
(defined $sleep_next_pull) or $sleep_next_pull = 30;
(defined $stageindir) or $stageindir = "stageins";
system "mkdir -p $stageindir";
(defined $cache_timeout) or $cache_timeout = 300;
if (defined $pidfile) {
	open F, "> $pidfile" or die "Open pidfile $pidfile failed: $!\n";
	print F "$$\n";
	close F;
}
# }}}

######
# Miscelanious common functions
######
# {{{ 
# prints messages on STDERR if in verbose mode
# parameters: a message
sub message($) {
	my $msg = shift;
	(defined $verbose) and warn $msg;
}

# blocks a list of signals (unused currently)
# parameters: a list of signals
# return: sigset to use to unblock
sub sigBlock(@) {
	my $sigset = POSIX::SigSet->new(@_);
	my $old_sigset = POSIX::SigSet->new;
	unless (defined sigprocmask(SIG_BLOCK, $sigset, $old_sigset)) {
    die "Could not block signals\n";
	}
	return $old_sigset;
}

# unblocks signals previously blocked (unused currently)
# parameters: the return of the previous sigBlock function call
sub sigUnblock($) {
	my $old_sigset = shift;
	unless (defined sigprocmask(SIG_UNBLOCK, $old_sigset)) {
    die "Could not unblock signals\n";
	}
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
# }}}

######
# Internal data
######
# {{{
# suitable Data::Dumper configuration for serialization
$Data::Dumper::Purity = 1;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 0;
$Data::Dumper::Deepcopy = 1;

# HTTP user agent
my $cgiUrl = new URI::URL($url);
my $userAgent = LWP::UserAgent->new();
$userAgent->agent("OAR-Agent/0.1 ");
my $maxretry=4;

my $kill_timeout = 5;
my %childs;
my %job2pid;
my %borndead;
my $launch_job_pid = undef;
my $killchild = undef;
my $stageintime;
my $quit=0;
my $stageinprefix = "oar-";
my $reader = undef;
my $writer = undef;
# }}}

######
# Signal handlers
######

sub sigQuitHandler();
# {{{
$SIG{QUIT} = \&sigQuitHandler;
sub sigQuitHandler() {
	$SIG{QUIT} = \&sigQuitHandler;
	$quit++;
# we should not do system calls in a handler !:(
	syswrite $writer,'QUIT',4;
}
# }}}

sub sigIntHandler();
# {{{
$SIG{INT} = \&sigIntHandler;
sub sigIntHandler() {
	$SIG{INT} = \&sigIntHandler;
	$quit++;
# we should not do system calls in a handler !:(
	syswrite $writer,'INT_',4;
}
# }}}

sub sigUSR1Handler();
# {{{
$SIG{USR1} = \&sigUSR1Handler;
sub sigUSR1Handler() {
	$SIG{USR1} = \&sigUSR1Handler;
	message "\t\tUSR1:".serialize(\%childs)."\n";
# we should not do system calls in a handler !:(
	syswrite $writer,'USR1',4;
}
# }}}

sub sigChildHandler;
# {{{
$SIG{CHLD} = \&sigChildHandler;
sub sigChildHandler {
  $SIG{CHLD} = \&sigChildHandler;
# we should not do system calls in a handler !:(
	syswrite $writer,'CHLD',4;
#	warn "#CHLD";
}
# }}}

sub sigTermHandler;
# {{{
$SIG{TERM} = 'DEFAULT';
sub sigTermHandler {
  $SIG{TERM} = \&sigTermHandler;
# we should not do system calls in a handler !:(
	$killchild = 1;
	syswrite $writer,'TERM',4;
#	warn "#TERM";
}
# }}}

######
# Main process (agent) functions
######

# checks terminated childs status and write it into the childs hash
sub checkChildsStatus();
# {{{
sub checkChildsStatus() {
	my $pid;
  while (($pid = waitpid(-1,WNOHANG)) > 0){
    if (WIFEXITED($?)) {
			$childs{$pid}->{'terminated'}="exit";
			$childs{$pid}->{'exitstatus'}=WEXITSTATUS($?);
    } elsif (WIFSIGNALED($?)) {
			$childs{$pid}->{'terminated'}="kill";
			$childs{$pid}->{'killsignal'}=WTERMSIG($?);
		}
  }
}
# }}}

# gets information from OAR server via CGI proxy: oar-cgi
sub request($$$);
# {{{
sub request($$$) {
	my $content_type = shift;
	my $content = shift;
	my $tofile = shift;
	my $retry = $maxretry;
	my $request = POST($cgiUrl, 'Content_type' => $content_type, 'Content' => $content);
	my $result;
	do {
                $result = $userAgent->request($request, $tofile);
		unless ($result->is_success()) {
			$retry and print "HTTP request failed, retrying ($retry)\n" or die "HTTP request failed\n";
			$retry--;
		}
	} until	$result->is_success();# or die "HTTP request failed (job-end)\n";
	return ($result->content(), $result->content_type());

}
# }}}

# pulls job information
# send currently handled jobs
# receive to launch and to kill jobs
sub pull();
# {{{
sub pull() {
	my $jobs={};
	foreach my $pid (keys %childs) {
		my $jobid = $childs{$pid}->{'jobid'};
		$jobs->{$jobid}=$childs{$pid};
		if (defined $childs{$pid}->{'terminated'}) {
			delete $childs{$pid};
		}
	}	
	message "\t\tpull send:".serialize($jobs)."\n";
	my ($out,$content_type) = request('form-data',[ 'REQTYPE' => 'PULL', 'HOSTNAME' => $hostname, 'QUIT' => $quit, 'JOBS' => serialize($jobs) ],undef);
	$content_type eq "application/data" or die "HTTP bad content type for pull response.\n";
	my $data=unserialize($out);
	message "\t\tpull recv:".serialize($data)."\n";
	return $data;
}
# }}}

# processes pulled job information
# setups job child processes
# handles to kill then to launch jobs.
sub process_jobs($);
# {{{
sub process_jobs($) {
	my $data = shift;
	(defined %$data) or return;
	(defined $data->{'error'}) and die "ERROR: ".$data->{'error'};
	my $toLaunchJobs = $data->{'launch'};
	my $toKillJobs = $data->{'kill'};
	if (defined $toLaunchJobs) {
		message "\t\tLaunching jobs: ".join (", ",keys %$toLaunchJobs)."\n";
	} 
	if (defined $toKillJobs) {
		message "\t\tKilling jobs: ".join (", ",keys %$toKillJobs)."\n";
	}
	foreach my $jobid (keys %$toKillJobs) {
		message "\t\tKilling job $jobid\n";
		my $pid = $job2pid{$jobid};
		if (defined ($pid)) {
			kill TERM => $pid;
		} else {
			$borndead{$jobid}=1;
		}
	}
	foreach my $jobid (keys %$toLaunchJobs) {
		message "\t\tForking job $jobid\n";
		my $pid = fork();
		if ($pid > 0) {
	    $childs{$pid}->{'jobid'} = $jobid;
			$job2pid{$jobid} = $pid;
			message "\t\tForked child process for job $jobid has pid: $pid\n";
  	} elsif ($pid == 0) {
			close $reader;
			close $writer;
			$reader = undef;
			$writer = undef;
			pipe ($reader,$writer);
			$writer->autoflush(1);
			$SIG{CHLD}=\&sigChildHandler;
			$SIG{TERM}=\&sigTermHandler;
			$SIG{INT}='IGNORE';
			$SIG{QUIT}='IGNORE';
			$SIG{USR1}='DEFAULT';
			launch_job($jobid,$toLaunchJobs->{$jobid});
			exit 0;
		} else {
			die "fork";
		}
	}
}
# }}}

# cleans up stageins cache directory 
# to old stagein files are removed
sub stagein_cleanup ();
# {{{
sub stagein_cleanup () {
	opendir DIR, "$stageindir/" or die "Can't open $stageindir: $!";
	while( defined (my $file = readdir DIR) ) {
		if ($file =~ /^$stageinprefix/ and not ($file =~ /\.lock$/ or $file eq ".." or $file eq ".")) {
			# lock to be sure no new job will try to use this file while we are removing it.
			my $lockfile = "$file.lock";
			open LOCKFILE,"> $lockfile" or warn "Open lockfile failed: $!\n";
			flock LOCKFILE,LOCK_EX or warn "Lock lockfile failed: $!\n";
			if (time - (stat "$stageindir/$file")[8] > $cache_timeout) {
				message "\t\tCache cleanup: deleting stagein file: $file\n";
				unlink "$stageindir/$file";
			}
			flock LOCKFILE,LOCK_UN or warn "Unlock lockfile failed: $!\n";
			close LOCKFILE or warn "Close lockfile failed: $!\n";
			(-e $lockfile ) and ( unlink $lockfile or warn "Unlink lockfile failed: $!\n" );
		}
	}
	closedir(DIR);
}
# }}}

# sleeps between pulls
# sleep for $sleep_next_pull unless a handler wrote in the pipe
sub sleep_or_signals();
# {{{
sub sleep_or_signals() {
	my $rin = '';
  my $rout;
  vec ($rin,fileno($reader),1) = 1;
	my ($n,$t) = select($rout=$rin, undef, undef, $sleep_next_pull);
	if ($n) {
		while (select($rout=$rin, undef, undef, 0)) {
			my $buf;
			sysread ($reader,$buf,4);
		}
	}
}
# }}}

# send a signal to all jobs child processes
sub kill_them_all($);
# {{{
sub kill_them_all($) {
	my $killsignal = shift;
	foreach my $pid (keys %childs) {
		message "\t\tKilling $pid with $killsignal...\n"; 
		kill $killsignal => $pid;
	}
}
# }}}

######
# Child processes (jobs) functions
######

# recursive function use to build a child process hierarchy, given the father.
# may be used to clean up job exec in case of INT or oardel
# not use yet
sub psLoop($);
# {{{
sub psLoop($) {
	my $pid = shift;
	my $ptree = {};
	my @plist;
	message "\t($$) Suspending process $pid\n";
	kill STOP => $pid or die "kill -STOP $pid failed: $!\n";
	open PS, "ps --ppid $pid -opid |" or die "open ps command pipe failed: $!\n";
	<PS>;
	foreach my $p (<PS>) {
		chomp $p;
		push @plist,$p;
	}
	close PS;
	foreach my $p (@plist) {
		$ptree->{$p} = psLoop($p);
	}
	return $ptree;
}
# }}}

# recursive function use to kill a child process hierarchy, given the hierarchy built with psLoop.
# may be used to clean up job exec in case of INT or oardel
# not use yet
sub killLoop($);
# {{{
sub killLoop($) {
	my $ptree = shift;
	foreach my $p (keys %$ptree) {
		killLoop($ptree->{$p});
		message "\t($$) Killing process $p\n";
		kill KILL => $p or die "kill -KILL $p failed: $!\n";
	}
}
# }}}

# stagein prcessed
sub stagein($$);
# {{{
sub stagein($$) {
	my $jobid = shift;
	my $job = shift;
	if (defined $job->{'stagein'}) {
		(-d $stageindir) or mkdir $stageindir;
		my $file = "$stageindir/$stageinprefix".$job->{'stagein'}->{'md5sum'};
		# locks file to insure no other job or stagein_cleanup is not messing everything up.
		my $lockfile = "$file.lock";
		open LOCKFILE,"> $lockfile" or warn "($$)Open lockfile failed: $!\n";
		flock LOCKFILE,LOCK_EX or warn "($$)Lock lockfile failed: $!\n";
		$launch_job_pid = fork();
		if ($launch_job_pid == 0) {
			close $reader;
			close $writer;
			$SIG{CHLD}='DEFAULT';
			$SIG{TERM}='DEFAULT';
			if ( -r $file and (stat $file)[7] == $job->{'stagein'}->{'size'} ) {
				message "($$)Job $jobid stagein already fetched\n";
			} else {
				message "($$)Fetching job $jobid stagein (".$job->{'stagein'}->{'size'}." bytes)\n";
				request("form-data",[ 'REQTYPE' => 'STAGEIN', 'JOBID' => $jobid ],$file);
			}
			message "($$)Deploying job $jobid stagein\n";
			if ($job->{'stagein'}->{'compression'} eq "tar.gz") {
				exec "tar xfz $file -m -C $jobid/ && touch $jobid";
				die "($$)Exec Failed: $!\n";
			} else {
				die "($$)Stagein compression method ".$job->{'stagein'}->{'compression'}." not yet implemented\n";
			}
		}
		message "\t($$)Forked stagein process with pid: $launch_job_pid\n";
		my $status = undef;
		my $rin = '';
  	vec ($rin,fileno($reader),1) = 1;
		do {
			select(my $rout=$rin, undef, undef, undef); 
			#while	(select(my $rout=$rin, undef, undef, 0)) {
				my $buf;
				sysread ($reader,$buf,4);
			#}
			my $pid = waitpid(-1,WNOHANG);
			if ($pid == $launch_job_pid) {
				# stagein child teminated
				$status = $?;
			} elsif (defined $killchild ) {
				# got a kill signal
				kill KILL => $launch_job_pid;
			}
		} until (defined $status);
		$launch_job_pid = undef;
		#until (wait == $launch_job_pid) {};
		#my $status = $?;
		#$launch_job_pid = undef;
		if ($status == 0) {
			$stageintime=(stat $jobid)[9]+1;
			sleep 1;
		} else {
			message "\t($$)Stagein failed or aborted, cleaning up...\n";
			if ( -r $file ) {
				unless ((stat $file)[7] == $job->{'stagein'}->{'size'} ) {
					unlink $file; 	
				}
			}
		}
		flock LOCKFILE,LOCK_UN or warn "($$)Unlock lockfile failed: $!\n";
		close LOCKFILE or warn "($$)Close lockfile failed: $!\n";
		( -e $lockfile ) and ( unlink $lockfile or warn "($$)Unlink lockfile failed: $!\n" );
		return $status;
	} else {
		return 0;
	}
}
# }}}

# home brewed version of the system command
sub runcmd($$);
# {{{
sub runcmd($$) {
	my $jobid = shift;
	my $job = shift;
	my $cmd =  $job->{'command'};
	my $directory = $job->{'directory'};
  $cmd =~ s#^$directory/?##;
	$launch_job_pid = fork();
	if ($launch_job_pid == 0) {
		close $reader;
		close $writer;
		$SIG{CHLD}='DEFAULT';
		$SIG{TERM}='DEFAULT';
		$ENV{'OAR_JOBID'} = $jobid;
		my $execcmd = "$cmd > $job->{'stdout_file'} 2> $job->{'stderr_file'}";
		message "($$)Executing '$execcmd'\n";
		exec $execcmd;
		die "($$)Exec Failed: $!\n";
	}
	message "\t($$)Forked process pid: $launch_job_pid\n";
#	until (wait == $launch_job_pid) {};
#	my $status = $?;
	my $already_killed = undef;
	my $status = undef;
	my $rin = '';
  vec ($rin,fileno($reader),1) = 1;
	do {
		select(my $rout=$rin, undef, undef, undef); 
		#while	(select(my $rout=$rin, undef, undef, 0)) {
			my $buf;
			sysread ($reader,$buf,4);
		#}
		my $pid = waitpid(-1,WNOHANG);
		#message "waitpid: $pid\n";
		if ($pid == $launch_job_pid) {
			# runcmd child teminated
			$status = $?;
		} elsif (defined $killchild and not defined $already_killed ) {
			# got a kill signal
			my $ptree = {};
			$ptree->{$launch_job_pid} = psLoop($launch_job_pid);
			killLoop($ptree);
			$already_killed = 1;
		}
	} until (defined $status);
	$launch_job_pid = undef;
	message "\t($$)Cmd exit: $status\n";
	return $status;
}
# }}}

# stageout prcessed
sub stageout($$);
# {{{
sub stageout($$) {
	my $jobid = shift;
	my $job = shift;
	# we pack only files created after the stagein unarchiving
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($stageintime);	
	my $date = sprintf("%04d-%02d-%02d %02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
	my $stageout = $jobid.".tgz";
	$launch_job_pid = fork();
	if ($launch_job_pid == 0) {
		close $reader;
		close $writer;
		$SIG{CHLD}='DEFAULT';
		$SIG{TERM}='DEFAULT';
		message "($$)Packing job $jobid stageout\n";
		exec "tar cfz $stageout -C $jobid --newer-mtime \"$date\" .";
		die "($$)Exec Failed: $!\n";
	}
	message "\t($$)Forked stageout process with pid: $launch_job_pid\n";
	#until (wait == $launch_job_pid) {};
	#$status = $?;
	#$launch_job_pid = undef;
	my $status = undef;
	my $rin = '';
  vec ($rin,fileno($reader),1) = 1;
	do {
		select(my $rout=$rin, undef, undef, undef); 
		#while	(select(my $rout=$rin, undef, undef, 0)) {
			my $buf;
			sysread ($reader,$buf,4);
		#}
		my $pid = waitpid(-1,WNOHANG);
		if ($pid == $launch_job_pid) {
			# runcmd child teminated
			$status = $?;
		} elsif (defined $killchild ) {
			# got a kill signal
			kill KILL => $launch_job_pid;
		}
	} until (defined $status);
	$launch_job_pid = undef;
	if ($status != 0) {
		return $status;
	}
	$launch_job_pid = fork();
	if ($launch_job_pid == 0) {
		close $reader;
		close $writer;
		$SIG{CHLD}='DEFAULT';
		$SIG{TERM}='DEFAULT';
		message "($$)Sending job $jobid stageout (".(stat $stageout)[7]." bytes)\n";
		request("form-data", [ 'REQTYPE' => 'STAGEOUT', 'JOBID' => $jobid, 'STAGEOUT' => [ $stageout ]],undef);
		exit 0;
	}
	message "\t($$)Forked stageout process with pid: $launch_job_pid\n";
	#until (wait == $launch_job_pid) {};
	#$status = $?;
	#$launch_job_pid = undef;
	$status = undef;
	$rin = '';
  vec ($rin,fileno($reader),1) = 1;
	do {
		select(my $rout=$rin, undef, undef, undef); 
		#while	(select(my $rout=$rin, undef, undef, 0)) {
			my $buf;
			sysread ($reader,$buf,4);
		#}
		my $pid = waitpid(-1,WNOHANG);
		if ($pid == $launch_job_pid) {
			# runcmd child teminated
			$status = $?;
		} elsif (defined $killchild ) {
			# got a kill signal
			kill KILL => $launch_job_pid;
		}
	} until (defined $status);
	$launch_job_pid = undef;
	return $status;
}
# }}}

# launches a job: manages stagein, runcmd, and stageout
sub launch_job($$);
# {{{
sub launch_job($$) {
	my $jobid = shift;
	my $job = shift;
	my $in = serialize($jobid);
	# if we already receive the order to kill the job
	if ($borndead{$jobid}) {
		message "\t($$)Job $jobid is borndead\n";
		exit 1;
	}
	mkdir $jobid or warn "($$)Cannot create job $jobid directory: $!\n";
	# fetch and setup stagein is there is one
	$stageintime=(stat $jobid)[9];
	my $stagein_status = stagein($jobid, $job);
	if ($stagein_status != 0 or $killchild ) {
		message "\t($$)Job $jobid killed during its stagein\n";
		system "rm -rf $jobid $jobid.tgz";
		exit 2;
	}
	# execute the job
	chdir $jobid or warn "($$)Cannot change directory to $jobid: $!\n";
  message "\t($$)Running '".$job->{'command'}."'\n";
	my $runcmd_status = runcmd($jobid, $job);
	message "\t($$)Job exited with status $runcmd_status\n";
	chdir ".." or warn "($$)Cannot change directory: $!\n";
	if (WIFSIGNALED($runcmd_status) or $killchild) {
		message "\t($$)Job $jobid killed during its execution\n";
		system "rm -rf $jobid $jobid.tgz";
		exit 3;
	}
	# handle stageout
	my $stageout_status = stageout($jobid, $job);
	if ($stageout_status != 0 or $killchild) {
		message "\t($$)Job $jobid killed during its stageout\n";
		system "rm -rf $jobid $jobid.tgz";
		exit 4;
	}
	# clean up and exit
	system "rm -rf $jobid $jobid.tgz";
	exit 0;
}
# }}}

######
# main function
######
sub main();
# {{{
sub main() {
	pipe ($reader,$writer);
	$writer->autoflush(1);
	message "CMD\tCHLD\tAGENT($$)\n";
	print $writer "FirstLoop";
	do {
		sleep_or_signals();
		checkChildsStatus();
		my $jobs=pull();
		process_jobs($jobs);
		stagein_cleanup();
		if ($quit > 1) {
			message "\t\tKill all jobs...\n";
			kill_them_all('TERM');
		} elsif ($quit == 1) {
			message "\t\tWaiting for running jobs to terminate...\n";
		} else {
			message "\t\tWaiting for next event...\n";
		}
	} until ($quit > 0 and not keys (%childs));
	message "\t\tWell done, bye !\n";
	exit 0;
}
# }}}

######
# Here we go !
######
main();
