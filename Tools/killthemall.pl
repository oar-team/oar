#!/usr/bin/perl
#
use strict;
use warnings;
use Data::Dumper;

my $suspended = 1;
my $exterminated = 1;

sub suspend($) {
	my $pid = shift;
	print $suspended++.") suspend $pid\n";
	kill STOP => $pid;
}

sub getChilds($) {
	my $pid = shift;
	my @pids;
	open PS,"ps --ppid $pid -o pid |";
	<PS>;
	foreach my $p (<PS>) {
		chomp $p;
		push @pids,$p;
	}
	return @pids;
}

sub psloop($);

sub psloop($) {
	my $pid = shift;
	my $processes = {};
	suspend($pid);
	foreach my $p (getChilds($pid)) {
		$processes->{$p} = psloop($p);
	}
	return $processes;
}	

sub exterminate($) {
	my $pid = shift;
	print $exterminated++.") exterminate $pid\n";
	kill KILL => $pid;
}

sub killloop($);

sub killloop($) {
	my $processes = shift;
	foreach my $p (keys %$processes) {
			killloop($processes->{$p});
			exterminate($p);
	}	
}

### main
my $pid = shift;
my $processes;
$processes->{$pid} = psloop($pid);
print Dumper $processes;
killloop($processes);
