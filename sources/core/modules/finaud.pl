#!/usr/bin/perl
# $Id$
# This program aims to change node state automatically when they are inaccesible or they become alive

use OAR::IO;
use OAR::Modules::Judas qw(oar_debug oar_warn oar_error set_current_log_category);
use OAR::PingChecker qw(test_hosts);
use OAR::Conf qw(init_conf dump_conf get_conf is_conf);
use Data::Dumper;
use strict;
use IO::Socket::INET;

# Log category
set_current_log_category('main');

oar_debug("[finaud] Finaud started\n");

oar_debug("[finaud] Check Alive and Suspected nodes\n");
my $base = OAR::IO::connect();

my @node_list_tmp = OAR::IO::get_finaud_nodes($base);
my $Occupied_nodes;
my $check_occupied_nodes = 'no';
my $disable_suspected_nodes_repair = 'no';

# get in conf the options that tells if we have to check nodes
# that are running jobs.
init_conf($ENV{OARCONFFILE});
if (is_conf("CHECK_NODES_WITH_RUNNING_JOB")){
    $check_occupied_nodes = get_conf("CHECK_NODES_WITH_RUNNING_JOB");
}
if (is_conf("DISABLE_SUSPECTED_NODES_REPAIR")){
    $disable_suspected_nodes_repair = get_conf("DISABLE_SUSPECTED_NODES_REPAIR");
}

if ($check_occupied_nodes eq 'no'){
    $Occupied_nodes = OAR::IO::get_current_assigned_nodes($base);
}

my %Nodes_hash;
foreach my $i (@node_list_tmp){
    if ($check_occupied_nodes eq 'no'){
        if (!defined($Occupied_nodes->{$i->{network_address}})){
            $Nodes_hash{$i->{network_address}} = $i;
        }
    }else{
        $Nodes_hash{$i->{network_address}} = $i;
    }
}

my @Nodes_to_check = keys(%Nodes_hash);
oar_debug("[finaud] Testing resource(s) on : @Nodes_to_check\n");

# Call the right program to test each nodes
my %bad_node_hash;
foreach my $i (test_hosts(@Nodes_to_check)){
    $bad_node_hash{$i} = 1;
}

#Make the decisions
my $return_value = 0;
foreach my $i (values(%Nodes_hash)){
    if (defined($bad_node_hash{$i->{network_address}}) and ($i->{state} eq "Alive")){
        OAR::IO::set_node_nextState($base,$i->{network_address},"Suspected");
        OAR::IO::update_node_nextFinaudDecision($base,$i->{network_address},"YES");
        OAR::IO::add_new_event_with_host($base, "FINAUD_ERROR", 0, "Finaud has detected an error on the node", [$i->{network_address}]);
        $return_value = 1;
        oar_debug("[finaud] Set the next state of $i->{network_address} to Suspected\n");
    }elsif (!defined($bad_node_hash{$i->{network_address}}) and $i->{state} eq "Suspected" and $disable_suspected_nodes_repair eq 'no'){
        OAR::IO::set_node_nextState($base,$i->{network_address},"Alive");
        OAR::IO::update_node_nextFinaudDecision($base,$i->{network_address},"YES");
        OAR::IO::add_new_event_with_host($base, "FINAUD_RECOVER", 0, "Finaud has detected that the node comes back", [$i->{network_address}]);
        $return_value = 1;
        oar_debug("[finaud] Set the next state of $i->{network_address} to Alive\n");
    }
}

OAR::IO::disconnect($base);

oar_debug("[finaud] Finaud ended : $return_value\n");

exit($return_value);
