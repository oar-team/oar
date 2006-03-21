#!/usr/bin/perl -I../Iolib -I../ConfLib -w
# $Id: test_gant.pl,v 1.11 2004/08/24 15:56:56 neyron Exp $


use strict;
use Data::Dumper;
use oar_iolib;
use oar_resource_tree;
use Gantt;

my $gantt = Gantt::new();

#Gantt::add_new_resource($gantt, "2");
#Gantt::add_new_resource($gantt, "4");
#Gantt::set_occupation($gantt, 20, 5, "2");
#Gantt::set_occupation($gantt, 26, 10, "2");
#Gantt::set_occupation($gantt, 40, 5, "2");
#Gantt::set_occupation($gantt, 20, 5, "2");
#Gantt::set_occupation($gantt, 20, 24, "2");
#print(Gantt::pretty_print($gantt)."\n");

#print(Dumper($gantt));
#print(Gantt::is_resource_free($gantt, 337, 1, "node1"));
#print(Gantt::pretty_print($gantt)."\n");
#

#exit;
my $base = iolib::connect();

my @r = iolib::list_resources($base);
#print(Dumper(@r));

foreach my $i (@r){
    Gantt::add_new_resource($gantt, $i->{resourceId});
}

Gantt::set_occupation($gantt, 4, 50, "4");
Gantt::set_occupation($gantt, 4, 50, "5");
#Gantt::set_occupation($gantt, 59, 15, "5");
#Gantt::set_occupation($gantt, 110, 200, "5");
#Gantt::set_occupation($gantt, 100, 5, "2");
#Gantt::set_occupation($gantt, 40, 50, "6");

#for (my $i=100000; $i > 1000; $i-=101){
#    Gantt::set_occupation($gantt, $i, $i-50, "4");
#}

#print(Gantt::pretty_print($gantt)."\n");
#exit;
print("INIT\n");
#print(Dumper($gantt));
my $resGroup = iolib::get_resources_data_structure_job($base, 2);
print(Dumper($resGroup));
my $h1 = iolib::get_possible_wanted_resources($base,[],[],"", $resGroup->[0]->[0]->[0]->{resources});

print(Dumper($h1));
#my $data = ();
#$data->[0] = {
#    "resources" => $resGroup->[0]->[0]->[0]->{resources},
#    "tree" => $h1
#};

#print(Dumper($data));

my @a = Gantt::find_first_hole($gantt,3, 30, [$h1]);

print(Dumper(@a));
print("TO_OT\n");
#print(Gantt::pretty_print($gantt)."\n");

foreach my $t (@{$a[1]}){
    print(Dumper(oar_resource_tree::delete_unnecessary_subtrees($t)));
}

#sleep 30;
