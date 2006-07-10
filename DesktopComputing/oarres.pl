#!/usr/bin/perl
# $Id: oarres.pl,v 1.2 2004/12/15 10:24:26 neyron Exp $
#
#	job stageout delivery

use strict;
use DBI();
use oar_iolib;

my $jobid = shift or die "Job id is missing.\n";
my $stageoutfile = shift or die "Job stageout filename is missing.\n";
( -r $stageoutfile ) or die "Stageout file not found.\n"; 

my $base = iolib::connect();
my $job = iolib::get_job($base,$jobid) or die "Failed to get job information\n";
((defined $job->{'job_user'}) and (defined $job->{'launching_directory'})) or die "Some of the job information are missing\n";
#system "sudo -u ".$job->{'user'}." tar xvfz $stageoutfile -C ".$job->{'launchingDirectory'}." && rm -v $stageoutfile" and die "Stageout delivery failed: $!\n";
system "sudo -u ".$job->{'job_user'}." tar xfz $stageoutfile -C ".$job->{'launching_directory'}.">& /dev/null && rm $stageoutfile" and die "Stageout delivery failed: $!\n";
iolib::disconnect($base);
