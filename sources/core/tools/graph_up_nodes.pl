#!/usr/bin/perl
# Simple script to graph the number of nodes that are not Absent
# (supposing "not in energy saving standby") depending on the time 
# Result can be plotted using gnuplot:
#gnuplot> set style fill solid 1.00 border
#gnuplot> set xdata time
#gnuplot> set timefmt "%s"
#gnuplot> set yrange [0:]
#gnuplot> plot '/tmp/up_nodes.txt' using 1:2 with boxes

use strict;

my $total_nodes=48;
my $oar_db="oar";
my $oar_user="oar";
my $oar_passwd="oar";

if (not defined($ARGV[2])) {
  print "usage: graph_up_nodes.pl <start_timestamp> <stop_timestamp> <step_in_seconds>\n";
  exit 1;
}

my $file=`mktemp`;
`mysql -N -p$oar_passwd $oar_db -u$oar_user -e "select distinct network_address,date_start,date_stop from resource_logs,resources where value=\\"Absent\\" and resource_logs.resource_id=resources.resource_id and date_start <= $ARGV[1] and (date_stop > $ARGV[0] or date_stop=0) order by date_start" > $file`;

# to be accurate, we should filter here the nodes that are Absent, but not
# in standby (available_upto < now)

open(FILE,"$file");
my %absent;
foreach (<FILE>) {
  my @array;
  (my $node,@array[0],@array[1]) = split;
  if (@array[1]==0) {@array[1]=time()};
  if(not defined($absent{$node})) {$absent{$node}=[]};
  push(@{$absent{$node}},\@array);
}

for (my $timestamp = $ARGV[0]; $timestamp <= $ARGV[1]; $timestamp+=$ARGV[2]) {
  my $absent_nodes=0;
  foreach my $node (keys(%absent)) {
    foreach my $arr (@{$absent{$node}}) {
      if ($timestamp > @{$arr}[0] && $timestamp < @{$arr}[1]) {
        $absent_nodes++ ."\n";
      }
    }
  }
  
  print "$timestamp ". ($total_nodes - $absent_nodes) ."\n";
}  
unlink $file;
