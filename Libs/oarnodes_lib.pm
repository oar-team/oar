use strict;
use warnings;
use Data::Dumper;
use oarversion;
use oar_iolib;

package oarnodeslib;

my $base = iolib::connect_ro();

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
	return iolib::get_events_for_hostname($base, $hostname, $date_from);
}

1;
