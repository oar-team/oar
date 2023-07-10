#!/usr/bin/perl -I../Iolib -I../ConfLib -w

use strict;
use Data::Dumper;
use OAR::IO;
use OAR::Schedulers::OarResourceTree;
use OAR::Schedulers::GanttHoleStorage;

my $max = 30;

my $gantt = OAR::Schedulers::GanttHoleStorage::new($max);

my $vec = '';
vec($vec, 3, 1) = 1;
OAR::Schedulers::GanttHoleStorage::add_new_resources($gantt, $vec);
$vec = '';
vec($vec, 2, 1) = 1;
vec($vec, 1, 1) = 1;
OAR::Schedulers::GanttHoleStorage::add_new_resources($gantt, $vec);

#$vec = '';
#for (my $i = 0; $i < $max; $i++){
#    vec($vec,$i,1) = 1;
#}
#print("---S\n");
#OAR::Schedulers::GanttHoleStorage::add_new_resource($gantt, $vec);
#print("---E\n");
#$vec = '';
#vec($vec,100000,1) = 1;
#OAR::Schedulers::GanttHoleStorage::add_new_resource($gantt, $vec);
#sleep 10;
#print vec($gantt->[3]->[0]->[1], 30, 1)."\n";
#print vec($gantt->[4], 5, 1)."\n";
#print unpack("b*",$gantt->[4])."\n";
#print unpack("%2b*",$gantt->[4])."\n";
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

my $base = OAR::IO::connect();

#my @r = OAR::IO::list_resources($base);
#print(Dumper(@r));

#foreach my $i (@r){
#    Gantt::add_new_resource($gantt, $i->{resourceId});
#}

$vec = '';

#vec($vec,1,1) = 1;
#vec($vec,2,1) = 1;
#vec($vec,3,1) = 1;
#OAR::Schedulers::GanttHoleStorage::set_occupation($gantt, 2, 30, $vec);

$vec = '';
vec($vec, 3, 1) = 1;
OAR::Schedulers::GanttHoleStorage::set_occupation($gantt, 5, 5, $vec);
vec($vec, 2, 1) = 1;
OAR::Schedulers::GanttHoleStorage::set_occupation($gantt, 8, 5, $vec);

$vec = '';
vec($vec, 1, 1) = 1;
OAR::Schedulers::GanttHoleStorage::set_occupation($gantt, 5, 10, $vec);

#OAR::Schedulers::GanttHoleStorage::set_occupation($gantt, 2, 1, $vec);
#$vec = '';
#vec($vec,1,1) = 1;
#OAR::Schedulers::GanttHoleStorage::set_occupation($gantt, 7, 8, $vec);
#$vec = '';
#vec($vec,3,1) = 1;
#OAR::Schedulers::GanttHoleStorage::set_occupation($gantt, 13, 3, $vec);

#print(Dumper($gantt));
OAR::Schedulers::GanttHoleStorage::pretty_print($gantt);

$vec = '';
vec($vec, 2, 1) = 1;
vec($vec, 1, 1) = 1;
print(OAR::Schedulers::GanttHoleStorage::is_resources_free($gantt, 2, 2, $vec) . "\n");
exit;

#for (my $i=100000; $i > 1000; $i-=101){
#    Gantt::set_occupation($gantt, $i, $i-50, "4");
#}

#print(Gantt::pretty_print($gantt)."\n");
#exit;
print("INIT\n");

#print(Dumper($gantt));
my $resGroup = OAR::IO::get_resources_data_structure_job($base, 2);
print(Dumper($resGroup));
my $h1 =
  OAR::IO::get_possible_wanted_resources($base, [], [], "", $resGroup->[0]->[0]->[0]->{resources});

print(Dumper($h1));

#my $data = ();
#$data->[0] = {
#    "resources" => $resGroup->[0]->[0]->[0]->{resources},
#    "tree" => $h1
#};

#print(Dumper($data));

my @a = Gantt::find_first_hole($gantt, 3, 30, [$h1]);

print(Dumper(@a));
print("TO_OT\n");

#print(Gantt::pretty_print($gantt)."\n");

foreach my $t (@{ $a[1] }) {
    print(Dumper(OAR::Schedulers::ResourceTree::delete_unnecessary_subtrees($t)));
}

#sleep 30;
