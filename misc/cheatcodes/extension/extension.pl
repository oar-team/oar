#!/usr/bin/perl -w
# This hack looks at the database to see if there is room in the gantt to extend
# a job. If so, it then extend the walltime of the job.
# Warning: the WALLTIME_JOB_WALLTIME environement variables will not be updated 
# within the job.
# Also, arbitration between users might be needed, to allow extension or not 
# (fairness)
# This hack is thought to be run before each pass of the metascheduler (in a
# wrapper around it) so that there is not conflict with the scheduling.
use strict;
use warnings;

use DBI;
use Data::Dumper;

my $db_host = "localhost";
my $db_port = "5432";
my $db_user = "oar";
my $db_password = "oar";
my $db_name = "oar";
my $db_type = "Pg";

my $job_id = shift;
my $extension_duration = shift;
if (not defined($job_id) or not defined($extension_duration)) {
  die "I need 2 parameters: a job id and a extenstion duration\n";
}

my $dbh = DBI->connect("DBI:$db_type:database=$db_name;host=$db_host;port=$db_port", $db_user, $db_password, {'InactiveDestroy' => 1, 'PrintError' => 1}) or die;

my $req = <<EOS;
SELECT
  j.start_time, m.moldable_walltime, a.resource_id
FROM
  jobs j, moldable_job_descriptions m, assigned_resources a
WHERE
  job_id=$job_id AND
  j.job_id = m.moldable_job_id AND
  j.assigned_moldable_job=a.moldable_job_id AND
  j.state = 'Running'
EOS

my $sth = $dbh->prepare($req);

my $security_duration = 120;
my $extension_from;
my $extension_to;
my @extension_resources = ();
my $job_start_time;
my $job_walltime;
$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) {
  $job_start_time = $ref->{start_time};
  $job_walltime = $ref->{moldable_walltime};
  push @extension_resources,$ref->{resource_id};
}
$extension_from = $job_start_time + $job_walltime;
$extension_to = $extension_from + $extension_duration;
print "Job $job_id started on ".localtime($job_start_time)." for ".($job_walltime/3600)." hours, try to postpone its end from ".localtime($extension_from)." to ".localtime($extension_to)."\n";

$req = <<EOS;
SELECT
  j.job_id, gp.start_time, j.initial_request
FROM 
  jobs j, moldable_job_descriptions m, gantt_jobs_predictions gp 
WHERE
  j.job_id = m.moldable_job_id AND
  gp.moldable_job_id = m.moldable_id AND
  gp.start_time > $extension_from AND
  gp.start_time - $security_duration <= $extension_to
EOS

my $conflict;
$sth = $dbh->prepare($req);
$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) {
    print "Found conficting job: ".$ref->{job_id}.", starting on ".localtime($ref->{start_time}).": $ref->{initial_request}\n";
    $extension_to = $ref->{start_time} - $security_duration;
}

if ($conflict) {
    print "Reduice possible extension to ".($extension_to - $extension_from)."s\n";
} else {
    print "Requested extension is possible\n";
}

if ($extension_to > 0) {
  my $new_walltime = $job_walltime + $extension_to - $extension_from;
  $dbh->do("UPDATE moldable_job_descriptions SET moldable_walltime=$new_walltime FROM jobs WHERE jobs.job_id = moldable_job_id AND jobs.job_id = $job_id");
  $dbh->do("INSERT INTO event_logs (type,job_id,date,description,to_check) VALUES ('EXTERNAL',$job_id,EXTRACT(EPOCH FROM current_timestamp),'job extension succeeded with new walltime=${new_walltime}s','NO')");
  print "Job extension succeeded with new walltime=${new_walltime}s\n";
} else {
  print "No extension is currently possible for job $job_id\n"; 
}
$dbh->disconnect() or die;
