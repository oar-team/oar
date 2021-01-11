print "===============================================================================\n";

# Loop over the moldable jobs
# Usage:
#   foreach_moldable_job {
#     my ($resource_requests, $walltime, $moldable_job) = @_;
#     <your code>
#   };
sub foreach_moldable_job(&) {
  my $yield = shift;
  foreach my $moldable_job (@{$ref_resource_list}) {
    my $resource_requests = $moldable_job->[0];
    my $walltime = $moldable_job->[1];
    $yield->($resource_requests, $walltime, $moldable_job);
  }
}

# Loop over the resource requests of a moldable job
# Usage:
#   foreach_resource_request_of_a_moldable_job {
#     my ($hierarchy, $property) = @_;
#     <your code>
#   } $a_moldable_job;
sub foreach_resource_request_of_a_moldable_job(&$) {
  my $yield = shift;
  my $resource_requests = shift;
  foreach my $request (@$resource_requests) {
    my $property = $request->{property};
    my $hierarchy = $request->{resources};
    $yield->($hierarchy, $property);
  }
}

# Loop over all resource requests of all moldable jobs
# Usage:
#   foreach_resource_requests_of_all_moldable_jobs {
#     my ($hierarchy, $property, $resource_requests, $walltime, $moldable_job) = @_;
#     <your code>
#   };
sub foreach_resource_request_of_all_moldable_jobs(&) {
  my $yield = shift;
  foreach_moldable_job {
    my ($resource_requests, $walltime, $moldable_job) = @_;
    foreach_resource_request_of_a_moldable_job {
      my ($hierarchy, $property) = @_;
      $yield->($hierarchy, $property, $resource_requests, $walltime, $moldable_job);
    } $resource_requests;
  };
}

# Loop over all hiearchy levels of a resource request of a moldable job
# Usage
#   foreach_resource_hierarchy_level_of_a_resource_request_of_a_moldable_job {
#     my ($resource, $value, $index) = @_;
#     <your code>
#   } $resource_hierarchy;
sub foreach_resource_hierarchy_level_of_a_resource_request_of_a_moldable_job(&*) {
  my $yield = shift;
  my $hierarchy = shift;
  my $index = 0;
  foreach my $level (@$hierarchy){
    $yield->($level->{resource}, $level->{value}, $index++)
  }
}

# Loop over all hiearchy levels of all resource requests of all moldable jobs
#   foreach_resource_hierarchy_level_of_all_resource_requests_of_all_moldable_jobs(&) {
#     my ($resource, $value, $index, $hierarchy, $property, $resource_requests, $walltime, $moldable_job) = @_;
#     <your code>
#   };
sub foreach_resource_hierarchy_level_of_all_resource_requests_of_all_moldable_jobs(&) {
  my $yield = shift;
  foreach_resource_request_of_all_moldable_jobs {
    my ($hierarchy, $property, $resource_requests, $walltime, $moldable_job) = @_;
    foreach_resource_hierarchy_level_of_a_resource_request_of_a_moldable_job {
      my ($resource, $value, $index) = @_;
      $yield->($resource, $value, $index, $hierarchy, $property, $resource_requests, $walltime, $moldable_job);
    } $hierarchy;
  };
}

my $i;
$i= 0;
use Data::Dumper;
foreach_moldable_job {
  my ($resource_requests, $walltime, $moldable_job) = @_;
  print "Moldable: ".$i++."\n";
  print "Resource_requests: ".Dumper($resource_requests)."\n";
  print "Walltime: $walltime\n\n";
};

print "===============================================================================\n";
$i = 0;
foreach_resource_request_of_all_moldable_jobs {
  my ($hierarchy, $property, $resource_requests, $walltime, $moldable_job) = @_;
  print "Request: ".$i++."\n";
  print "Property: $property\n";
  print "Resources: ".join('/',map { $_->{resource}."=".$_->{value} } @$hierarchy)."\n";
  print "Walltime: $walltime\n\n";
};

print "===============================================================================\n";
foreach_resource_hierarchy_level_of_all_resource_requests_of_all_moldable_jobs {
  my ($resource, $value, $index, $hierarchy, $property, $resource_requests, $walltime, $moldable_job) = @_;
  print "$index: $resource = $value\n";
};



