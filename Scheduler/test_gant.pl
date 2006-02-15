#!/usr/bin/perl -I../Iolib -I../ConfLib -w
# $Id: test_gant.pl,v 1.11 2004/08/24 15:56:56 neyron Exp $


use strict;
use Data::Dumper;
use oar_iolib;
use oar_resource_tree;
use Gantt;

my $gantt = Gantt::new(11);

#Gantt::add_new_resource($gantt, "node1");
#Gantt::add_new_resource($gantt, "node3");
#Gantt::set_occupation($gantt, 20, 5, "node1");
#Gantt::set_occupation($gantt, 26, 10, "node1");
#Gantt::set_occupation($gantt, 40, 5, "node1");
#Gantt::set_occupation($gantt, 20, 5, "node2");
#print(Gantt::pretty_print($gantt)."\n");

#print(Dumper($gantt));
#print(Gantt::is_resource_free($gantt, 337, 1, "node1"));
#print(Gantt::pretty_print($gantt)."\n");
#
my $base = iolib::connect();

my @r = iolib::list_resources($base);
print(Dumper(@r));

foreach my $i (@r){
    Gantt::add_new_resource($gantt, $i->{resourceId});
}

Gantt::set_occupation($gantt, 40, 5, "1");
#print(Dumper($gantt));
my $resGroup = iolib::get_resources_data_structure_job($base, 2);
print(Dumper($resGroup));
my $h1 = iolib::get_possible_wanted_resources($base,[],[],"", $resGroup->[0]->[0]->[0]->{resources});

print(Dumper($h1));
my $data = ();
$data->[0] = {
    "resources" => $resGroup->[0]->[0]->[0]->{resources},
    "tree" => $h1
};

print(Dumper($data));

Gantt::find_first_hole($gantt, 10, $data);

print(Gantt::pretty_print($gantt)."\n");
