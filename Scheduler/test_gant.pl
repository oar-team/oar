#!/usr/bin/perl -I../Iolib -I../ConfLib -w
# $Id: test_gant.pl,v 1.11 2004/08/24 15:56:56 neyron Exp $


use strict;

use Gantt;

my $nodes={ "node1" => 1, 
	    "node2" => 1,
	    "node4" => 1,
	    "node5" => 1 };
my $chart=Gantt::create_empty_gant(0, $nodes);
# print $#{$nodes},"\n";

# Gantt::find_first_hole(2,1,3,$nodes,$chart);
print "Part 1\n";
Gantt::pretty_print_gant($chart);
Gantt::set_occupation($chart, 2, 5, ["node1", "node2", "node4"]);
print "Part 2\n";
Gantt::pretty_print_gant($chart);
Gantt::set_occupation($chart, 0, 3, ["node1"]);
print "Part 3\n";
Gantt::pretty_print_gant($chart);
Gantt::set_occupation($chart, 5, 3, ["node2"]);
print "Part 4\n";
Gantt::pretty_print_gant($chart);
Gantt::set_occupation($chart, 7, 3, ["node4"]);
print "Part 5\n";
Gantt::pretty_print_gant($chart);
Gantt::set_occupation($chart, 0, 3, ["node4", "node5"]);
print "Part 6\n";
Gantt::pretty_print_gant($chart);
Gantt::set_occupation($chart, -1, 1, ["node1"]);
print "Part 7\n";
Gantt::pretty_print_gant($chart);

my @r = Gantt::find_first_hole($chart, 2, 4, ["node1", "node2", "node4", "node5"]);

print "Result: @r \n";

my @k = Gantt::available_nodes($chart, 7, 3, ["node1", "node2", "node4", "node5"]);

print "K: @k \n";
