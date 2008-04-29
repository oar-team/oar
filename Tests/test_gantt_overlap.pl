#!/usr/bin/perl
# $Id$
# Description:
#  Simple script to check that a gantt is correct, with regard to overlaping jobs
# Usage:
#  oarstat -g "2008-04-29 18:00:00, 2008-04-30 08:00:00" | ./test_gantt_overlap.pl
# Todo:
#  - handle timesharing jobs
#  - handle container jobs
#  - ...

use strict;
use Data::Dumper;
my $gantt_input;
while (<STDIN>) {
	$gantt_input .= $_;
}

my $gantt = eval($gantt_input);
my $jobs = $gantt->{jobs};
my @jobids = keys(%$jobs);

sub match($$) {
	my $a1 = shift;
	my $a2 = shift;
	my %h;
	my @res;
	foreach my $k (@$a1,@$a2) {
		if (exists($h{$k})) {
			push @res,$k;
		}
		$h{$k}=undef;
	}
	return @res;
}

while (my $jobid0 = shift(@jobids)) {
	foreach my $jobidN (@jobids) {
		if ((
			# job0 across jobN start_time
			$jobs->{$jobid0}->{start_time} <= $jobs->{$jobidN}->{start_time} and
			$jobs->{$jobid0}->{stop_time} >= $jobs->{$jobidN}->{start_time}
		 	) or (
			# job0 across jobN stop_time
			$jobs->{$jobid0}->{start_time} <= $jobs->{$jobidN}->{stop_time} and
			$jobs->{$jobid0}->{stop_time} >= $jobs->{$jobidN}->{stop_time}
		 	) or (
			# job0 within jobN 
			$jobs->{$jobid0}->{start_time} >= $jobs->{$jobidN}->{start_time} and
			$jobs->{$jobid0}->{stop_time} <= $jobs->{$jobidN}->{stop_time}
			)) {
			my @m = match($jobs->{$jobid0}->{resources},$jobs->{$jobidN}->{resources});
			if (@m) {
				print "CONFLICT: $jobid0 and $jobidN\n";
				foreach my $j ($jobid0,$jobidN) {
					print "|-[$j]-start_time: ".localtime($jobs->{$j}->{start_time})."\n";
					print "|-[$j]-stop_time: ".localtime($jobs->{$j}->{stop_time})."\n";
					print "|-[$j]-user: ".$jobs->{$j}->{user}."\n";
					print "|-[$j]-walltime: ".$jobs->{$j}->{walltime}."\n";
				}
				print "`-confict resources: ".join(", ",@m)."\n";

			}
		}		
	}	
}
