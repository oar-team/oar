#!/usr/bin/perl -w
# This hack allows one to transmute a batch to an advance reservation
# Additional types must be allowed (admission rules): evening, night, week-end
# This hack is thought to be run before each pass of the metascheduler (in a
# wrapper around it) so that there is not conflict with the scheduling.
use strict;
use warnings;

use DBI;
use Data::Dumper;

my $db_host = "oardb";
my $db_port = "5432";
my $db_user = "oarreader";
my $db_password = "read";
my $db_name = "oar2";
my $db_type = "Pg";

my $dbh = DBI->connect("DBI:$db_type:database=$db_name;host=$db_host;port=$db_port", $db_user, $db_password, {'InactiveDestroy' => 1, 'PrintError' => 1}) or die;

my $h = {};
my $req = <<EOS;
SELECT 
  j.job_id, p.start_time, j.message, j.job_user, r.resource_id, m.moldable_walltime
FROM
  jobs j, moldable_job_descriptions m, gantt_jobs_predictions p, gantt_jobs_resources r
WHERE
  j.job_id = m.moldable_job_id AND
  p.moldable_job_id = m.moldable_id AND
  r.moldable_job_id = m.moldable_id AND
  j.reservation = 'Scheduled' AND
  p.start_time > EXTRACT(EPOCH FROM current_timestamp)
EOS
my $sth = $dbh->prepare($req);

$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) {
    $h->{$ref->{job_id}}->{user} = $ref->{job_user};
    $h->{$ref->{job_id}}->{start} = localtime($ref->{start_time});
    $h->{$ref->{job_id}}->{walltime} = $ref->{moldable_walltime};
    $h->{$ref->{job_id}}->{message} = $ref->{message};
    $h->{$ref->{job_id}}->{resources} .= "$ref->{resource_id} ";
}
$dbh->disconnect() or die;
print "## Advance reservation list on ".localtime()."\n";
$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;
foreach my $k (sort keys (%$h)) {
    print "Job $k => " . Dumper($h->{$k});
}




