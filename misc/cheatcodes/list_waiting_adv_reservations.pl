#!/usr/bin/perl -w
# List current and future advance reservations with resources displayed by state
# The same information can be retrieved by running:
# $ oarstat -f --sql "reservation = 'Scheduled' and (state='Waiting' or state='Running')" -D
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
  j.job_id, gp.start_time, j.message, j.job_user, r.resource_id, r.state, m.moldable_walltime, j.submission_time, EXTRACT(EPOCH FROM current_timestamp) as now
FROM
  jobs j, moldable_job_descriptions m, gantt_jobs_predictions gp, gantt_jobs_resources gr, resources r
WHERE
  j.job_id = m.moldable_job_id AND
  gp.moldable_job_id = m.moldable_id AND
  gr.moldable_job_id = m.moldable_id AND
  j.reservation = 'Scheduled' AND
  r.resource_id = gr.resource_id AND
  gp.start_time > EXTRACT(EPOCH FROM current_timestamp)
EOS
my $sth = $dbh->prepare($req);

$sth->execute();
my $now;
while (my $ref = $sth->fetchrow_hashref()) {
    $now = $ref->{now};
    $h->{$ref->{job_id}}->{user} = $ref->{job_user};
    $h->{$ref->{job_id}}->{submission_time} = localtime($ref->{submission_time});
    $h->{$ref->{job_id}}->{start_time} = localtime($ref->{start_time});
    $h->{$ref->{job_id}}->{walltime} = $ref->{moldable_walltime};
    $h->{$ref->{job_id}}->{message} = $ref->{message};
    $h->{$ref->{job_id}}->{resources}->{$ref->{state}} .= "$ref->{resource_id} ";
}
$dbh->disconnect() or die;
print "## Advance reservation list on ".localtime($now)."\n";
$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;
foreach my $k (sort keys (%$h)) {
    print "Job $k => " . Dumper($h->{$k});
}




