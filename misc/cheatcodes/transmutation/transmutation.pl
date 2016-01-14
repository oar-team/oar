#!/usr/bin/perl -w
# This hack allows one to transmute a batch to an advance reservation
# Additional types must be allowed (admission rules): evening, night, week-end
# This hack is thought to be run before each pass of the metascheduler (in a
# wrapper around it) so that there is not conflict with the scheduling.
use strict;
use warnings;

use DBI;
use Data::Dumper;

my $date = shift or die "I need a date";
my $db_host = "localhost";
my $db_port = "5432";
my $db_user = "oar";
my $db_password = "oar";
my $db_name = "oar";
my $db_type = "Pg";

my $dbh = DBI->connect("DBI:$db_type:database=$db_name;host=$db_host;port=$db_port", $db_user, $db_password, {'InactiveDestroy' => 1, 'PrintError' => 1}) or die;

my $req = <<EOS;
SELECT 
  j.job_id, p.start_time, j.message
FROM
  jobs j, moldable_job_descriptions m, gantt_jobs_predictions p, job_types t
WHERE
  p.moldable_job_id = m.moldable_id AND
  j.job_id = m.moldable_job_id AND
  t.job_id = j.job_id AND
  t.type IN ('evening=$date', 'night=$date', 'week-end=$date') AND
  NOT j.reservation = 'Scheduled'
EOS
my $sth = $dbh->prepare($req);

$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) {
  print Dumper($ref);
  $ref->{message} =~ s/J=B/J=R/;
  $current_time = $dbh
  $dbh->do("UPDATE jobs SET reservation='Scheduled', start_time=$ref->{start_time}, message='$ref->{message}' WHERE job_id = $ref->{job_id}");
  $dbh->do("INSERT INTO event_logs (type,job_id,date,description,to_check) VALUES ('EXTERNAL',$job_id,EXTRACT(EPOCH FROM current_timestamp),'batch job transmuted to advance reservation','NO')");
}
$dbh->disconnect() or die;




