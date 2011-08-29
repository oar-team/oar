#!/usr/bin/perl
# $Id$
#
#	job stageout delivery

use strict;
use DBI();
use OAR::IO;

my $jobid = shift or die "Job id is missing.\n";
my $stageoutfile = shift or die "Job stageout filename is missing.\n";
( -r $stageoutfile ) or die "Stageout file not found.\n"; 

my $base = OAR::IO::connect();
my $job = OAR::IO::get_job($base,$jobid) or die "Failed to get job information\n";
((defined $job->{'job_user'}) and (defined $job->{'launching_directory'})) or die "Some of the job information are missing\n";
#system "sudo -u ".$job->{'user'}." tar xvfz $stageoutfile -C ".$job->{'launchingDirectory'}." && rm -v $stageoutfile" and die "Stageout delivery failed: $!\n";
#system "sudo -u ".$job->{'job_user'}." tar xfz $stageoutfile -C ".$job->{'launching_directory'}.">& /dev/null && rm $stageoutfile" and die "Stageout delivery failed: $!\n";
$ENV{OARDO_BECOME_USER} = $job->{job_user};
system "oardodo tar xfz $stageoutfile -C $job->{'launching_directory'} >& /dev/null && rm $stageoutfile" and die "Stageout delivery failed: $!\n";
OAR::IO::disconnect($base);
