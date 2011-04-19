use strict;
use warnings;
use oarversion;
use oar_iolib;

package oarnodeslib;

my $base;

sub open_db_connection(){
	$base  = iolib::connect_ro_one();
        if (defined($base)) { return 1; }
        else {return 0; }
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

sub get_all_hosts(){
    my @nodes = iolib::list_nodes($base);
	return \@nodes;
}

sub get_all_resources(){
    my @resources = iolib::list_resources($base);
        return \@resources;
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

sub get_nodes_with_given_sql($){
	my $sql_clause = shift;
	my @sql_resources = iolib::get_nodes_with_given_sql($base,$sql_clause);
	return \@sql_resources;
}

sub get_resources_states($){
	my $resources = shift;
	my %resources_states;
	foreach my $current_resource (@$resources){
		my $properties = iolib::get_resource_info($base, $current_resource);
                if ($properties->{state} eq "Absent" && $properties->{available_upto} >= time()) {
                   $properties->{state} .= " (standby)";
                }
		$resources_states{$current_resource} = $properties->{state};
	}
	return \%resources_states;
}

sub get_resources_states_for_host($){
	my $hostname = shift;
	my @node_info = iolib::get_node_info($base, $hostname);
	my @resources;
	foreach my $info (@node_info){
		push @resources, $info->{resource_id};
	}
	return get_resources_states(\@resources);
}

sub get_resource_infos($){
  my $id=shift;
  my $resource = iolib::get_resource_info($base,$id);
}

sub get_resources_infos($){
	my $resources = shift;
	my %resources_infos;
	foreach my $current_resource (@$resources){
		my $properties = iolib::get_resource_info($base, $current_resource);
		add_running_jobs_to_resource_properties($properties);
		$resources_infos{$current_resource} = $properties
	}
	return \%resources_infos;
}

sub get_resources_for_host($){
	my $hostname = shift;
	my @resources = iolib::get_node_info($base, $hostname);
        return \@resources;
}

sub get_resources_infos_for_host($){
	my $hostname = shift;
	my @node_info = iolib::get_node_info($base, $hostname);
	my @resources;
	foreach my $info (@node_info){
		push @resources, $info->{resource_id};
	}
	return get_resources_infos(\@resources);
}

sub get_jobs_running_on_resource($){
	my $resource_id = shift;
	my @jobs = iolib::get_resource_job($base, $resource_id);
	return \@jobs;
}

sub add_running_jobs_to_resource_properties($){
	my $info = shift;
	if ($info->{state} eq "Alive"){
		my $jobs = get_jobs_running_on_resource($info->{resource_id});
		if (@$jobs > 0){
# 			my $jobs_string = Dumper($jobs); # not proud of it...
# 			$jobs = join(', ', split(/,/, $jobs_string));
# 			$jobs =~ s/[\[\]\']//g;
			my $jobs_string = '';
			foreach my $current_job (@$jobs){
				$jobs_string .= $current_job.", ";
			}
			chop($jobs_string); # remove last space
			chop($jobs_string); # remove last ,
			$info->{jobs} = $jobs_string;
		}
	}
}

1;
