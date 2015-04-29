-- Default admission rules for OAR 2
-- $Id$

-- Specify the default value for queue parameter
INSERT INTO admission_rules (priority, enabled, rule) VALUES (1, 'YES', E'# Set default queue is no queue is set
if (not defined($queue_name)) {$queue_name="default";}
');

-- Prevent root and oar to submit jobs.
INSERT INTO admission_rules (priority, enabled, rule) VALUES (2, 'YES', E'# Prevent users oar and root to submit jobs
# Note: do not change this unless you want to break oar !
die ("# ADMISSION RULE> Error: root and oar users are not allowed to submit jobs.\\n") if ( $user eq "root" or $user eq "oar" );
');

-- Avoid the jobs to go on resources in drain mode
INSERT INTO admission_rules (priority, enabled, rule) VALUES (3, 'YES', E'# Avoid the jobs to go on resources in drain mode
$jobproperties_applied_after_validation = "drain=''NO''";
');

-- Avoid users except admin to go in the admin queue
INSERT INTO admission_rules (priority, enabled, rule) VALUES (4, 'YES', E'# Restrict the admin queue to members of the admin group
my $admin_group = "admin";
if ($queue_name eq "admin") {
    my $members; 
    (undef,undef,undef, $members) = getgrnam($admin_group);
    my %h = map { $_ => 1 } split(/\\s+/,$members);
    if ( $h{$user} ne 1 ) {
        {die("# ADMISSION RULE> Error: only member of the group ".$admin_group." can submit jobs in the admin queue\\n");}
    }
}
');

-- Prevent the use of system properties
INSERT INTO admission_rules (priority, enabled, rule) VALUES (5, 'YES', E'# Prevent users from using internal resource properties for oarsub requests 
my @bad_resources = ("type","state","next_state","finaud_decision","next_finaud_decision","state_num","suspended_jobs","scheduler_priority","cpuset","besteffort","deploy","expiry_date","desktop_computing","last_job_date","available_upto","last_available_upto");
foreach my $mold (@{$ref_resource_list}){
    foreach my $r (@{$mold->[0]}){
        my $i = 0;
        while (($i <= $#{$r->{resources}})){
            if (grep(/^$r->{resources}->[$i]->{resource}$/i, @bad_resources)){
                die("# ADMISSION RULE> Error: \'$r->{resources}->[$i]->{resource}\' resource is not allowed\\n");
            }
            $i++;
        }
    }
}
');

-- Force besteffort jobs to run in the besteffort queue
-- Force job of the besteffort queue to be of the besteffort type
-- Force besteffort jobs to run on nodes with the besteffort property
INSERT INTO admission_rules (priority, enabled, rule) VALUES (6, 'YES', E'# Tie the besteffort queue, job type and resource property together
if (grep(/^besteffort$/, @{$type_list}) and not $queue_name eq "besteffort"){
    $queue_name = "besteffort";
    print("# ADMISSION RULE> Info: automatically redirect in the besteffort queue\\n");
}
if ($queue_name eq "besteffort" and not grep(/^besteffort$/, @{$type_list})) {
    push(@{$type_list},"besteffort");
    print("# ADMISSION RULE> Info: automatically add the besteffort type\\n");
}
if (grep(/^besteffort$/, @{$type_list})){
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND besteffort = ''YES''";
    }else{
        $jobproperties = "besteffort = ''YES''";
    }
    print("# ADMISSION RULE> Info: automatically add the besteffort constraint on the resources\\n");
}
');

-- Verify if besteffort jobs are not reservations
INSERT INTO admission_rules (priority, enabled, rule) VALUES (7, 'YES', E'# Prevent besteffort advance-reservation
if ((grep(/^besteffort$/, @{$type_list})) and ($reservationField ne "None")){
    die("# ADMISSION RULE> Error: a job cannot both be of type besteffort and be a reservation.\\n");
}
');

-- Force deploy jobs to go on resources with the deploy property
INSERT INTO admission_rules (priority, enabled, rule) VALUES (8, 'YES', E'# Tie the deploy job type and resource property together
if (grep(/^deploy$/, @{$type_list})){
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND deploy = ''YES''";
    }else{
        $jobproperties = "deploy = ''YES''";
    }
}
');

-- Prevent deploy type jobs on non-entire nodes
INSERT INTO admission_rules (priority, enabled, rule) VALUES (9, 'YES', E'# Restrict allowed properties for deploy jobs to force requesting entire nodes
my @bad_resources = ("cpu","core", "thread","resource_id",);
if (grep(/^deploy$/, @{$type_list})){
    foreach my $mold (@{$ref_resource_list}){
        foreach my $r (@{$mold->[0]}){
            my $i = 0;
            while (($i <= $#{$r->{resources}})){
                if (grep(/^$r->{resources}->[$i]->{resource}$/i, @bad_resources)){
                    die("# ADMISSION RULE> Error: \'$r->{resources}->[$i]->{resource}\' resource is not allowed with a deploy job\\n");
                }
                $i++;
            }
        }
    }
}
');

-- Force desktop_computing jobs to go on nodes with the desktop_computing property
INSERT INTO admission_rules (priority, enabled, rule) VALUES (10, 'YES', E'# Tie desktop computing job type and resource property together
if (grep(/^desktop_computing$/, @{$type_list})){
    print("# ADMISSION RULE> Info: added automatically desktop_computing resource constraints\\n");
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND desktop_computing = ''YES''";
    }else{
        $jobproperties = "desktop_computing = ''YES''";
    }
}else{
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND desktop_computing = ''NO''";
    }else{
        $jobproperties = "desktop_computing = ''NO''";
    }
}
');

-- Limit the number of reservations that a user can do.
-- (overrided on user basis using the file: ~oar/unlimited_reservation.users)
INSERT INTO admission_rules (priority, enabled, rule) VALUES (11, 'YES', E'# Limit the number of advance reservations per user
if ($reservationField eq "toSchedule") {
    my $unlimited=0;
    if (open(FILE, "< $ENV{HOME}/unlimited_reservation.users")) {
        while (<FILE>){
            if (m/^\\s*$user\\s*$/m){
                $unlimited=1;
            }
        }
        close(FILE);
    }
    if ($unlimited > 0) {
        print("# ADMISSION RULE> Info: $user is granted the privilege to do unlimited reservations\\n");
    } else {
        my $max_nb_resa = 2;
        my $nb_resa = $dbh->do("    SELECT job_id
                                    FROM jobs
                                    WHERE
                                        job_user = ''$user'' AND
                                        (reservation = ''toSchedule'' OR
                                        reservation = ''Scheduled'') AND
                                        (state = ''Waiting'' OR state = ''Hold'')
                               ");
        if ($nb_resa >= $max_nb_resa){
            die("# ADMISSION RULE> Error: you cannot have more than $max_nb_resa waiting advance reservations.\\n");
        }
    }
}
');

-- Example of how to perform actions given usernames stored in a file
INSERT INTO admission_rules (priority, enabled, rule) VALUES (12, 'NO', E'# Example of how to perform actions given usernames stored in a file
open(FILE, "/tmp/users.txt");
while (($queue_name ne "admin") and ($_ = <FILE>)){
    if ($_ =~ m/^\\s*$user\\s*$/m){
        print("# ADMISSION RULE> Info: change assigned queue to admin\\n");
        $queue_name = "admin";
    }
}
close(FILE);
');

-- Limit walltime for interactive jobs
INSERT INTO admission_rules (priority, enabled, rule) VALUES (13, 'YES', E'# Limit the walltime for interactive jobs
my $max_walltime = OAR::IO::sql_to_duration("12:00:00");
if (($jobType eq "INTERACTIVE") and ($reservationField eq "None")){ 
    foreach my $mold (@{$ref_resource_list}){
        if ((defined($mold->[1])) and ($max_walltime < $mold->[1])){
            print("# ADMISSION RULE> warning: walltime ".$mold->[1]." to big for an INTERACTIVE job, set to $max_walltime.\\n");
            $mold->[1] = $max_walltime;
        }
    }
}
');

-- specify the default walltime if it is not specified
INSERT INTO admission_rules (priority, enabled, rule) VALUES (14, 'YES', E'# Set the default walltime is not specified
my $default_wall = OAR::IO::sql_to_duration("2:00:00");
foreach my $mold (@{$ref_resource_list}){
    if (!defined($mold->[1])){
        print("# ADMISSION RULE> Info: no walltime defined, use default: $default_wall.\\n");
        $mold->[1] = $default_wall;
    }
}
');

-- Check if types given by the user are right
INSERT INTO admission_rules (priority, enabled, rule) VALUES (15, 'YES', E'# Check if job types are valid
my @types = (
    qr/^container(?:=\\w+)?$/,                 qr/^deploy$/,
    qr/^desktop_computing$/,                   qr/^besteffort$/,
    qr/^cosystem$/,                            qr/^idempotent$/,
    qr/^placeholder=\\w+$/,                    qr/^allowed=\\w+$/,
    qr/^inner=\\w+$/,                          qr/^timesharing=(?:(?:\\*|user),(?:\\*|name)|(?:\\*|name),(?:\\*|user))$/,
    qr/^token\\:\\w+\\=\\d+$/,                 qr/^extensible$/,
    qr/^constraints=/,                         qr/^noop$/
);
foreach my $t ( @{$type_list} ) {
    my $match = 0;
    foreach my $r (@types) {
        if ($t =~ $r) {
            $match = 1;
        }
    }
    unless ( $match ) {
        die( "# ADMISSION RULE> Error: unknown job type: $t\n");
    }
}
');

-- If resource types are not specified, then we force them to default
INSERT INTO admission_rules (priority, enabled, rule) VALUES (16, 'YES', E'# Set resource type to default if not specified
foreach my $mold (@{$ref_resource_list}){
    foreach my $r (@{$mold->[0]}){
        my $prop = $r->{property};
        if (($prop !~ /[\\s\\(]type[\\s=]/) and ($prop !~ /^type[\\s=]/)){
            if (!defined($prop)){
                $r->{property} = "type = ''default''";
            }else{
                $r->{property} = "($r->{property}) AND type = ''default''";
            }
        }
    }
}
print("# ADMISSION RULE> Info: modify resource description with type constraints\\n");
');

