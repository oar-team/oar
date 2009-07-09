use strict;
use warnings;
use Data::Dumper;
use oarversion;
use oar_iolib;

package oarnodeslib;

my $base;

sub open_db_connection(){
	$base  = iolib::connect_ro();
}
sub close_db_connection(){
	iolib::disconnect($base);
}

sub encode_result($$){
	my $result = shift or die("[oarnodes_lib] encode_result: no result to encode");
	my $encoding = shift or die("[oarnodes_lib] encode_result: no format to encode to");
    if($encoding eq "XML"){
		eval "use XML::Dumper qw(pl2xml);1" or die ("XML module not available");
		my $dump = new XML::Dumper;
		$dump->dtd;
		my $return = $dump->pl2xml($result) or die("XML conversion failed");
		return $return;
	}elsif($encoding eq "YAML"){
		eval "use YAML;1" or die ("YAML module not available");
		my $return = YAML::Dump($result) or die("YAML conversion failed");
		return $return;
	}elsif($encoding eq "JSON"){
		eval "use JSON;1"  or die ("JSON module not available");
		my $return = JSON->new->pretty(1)->encode($result) or die("JSON conversion failed");
		return $return;
    }
}

sub get_oar_version(){
    return oarversion::get_version();
}

sub format_date($){
	my $date = shift;
    return iolib::local_to_sql($date);
}

sub get_events($$){
	my $hostname = shift;
	my $date_from = shift;
	my @events = iolib::get_events_for_hostname($base, $hostname, $date_from);
	return \@events;
}

sub get_resources_with_given_sql($){
	my $sql_clause = shift;
	my @sql_resources = iolib::get_resources_with_given_sql($base,$sql_clause);
	return \@sql_resources;
}

sub get_resource_state($){
	my $resource_id = shift;
	return iolib::get_resource_state($base, $resource_id);
}

1;
