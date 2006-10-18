# Creation de la base de donnees
#CREATE DATABASE IF NOT EXISTS oar;

# Creation de l utilisateur oar
#CONNECT mysql;
#INSERT INTO user (Host,User,Password) VALUES('localhost','oar',PASSWORD('oar'));

#INSERT INTO user (Host,User,Password) VALUES('%.imag.fr','oar',PASSWORD('oar'));
#INSERT INTO db  (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) VALUES
#				('localhost','oar','oar','Y','Y','Y','Y','Y','Y');
#INSERT INTO db  (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) VALUES
#				('%.imag.fr','oar','oar','Y','Y','Y','Y','Y','Y');
#FLUSH PRIVILEGES;

#GRANT ALL ON oar.* TO oar@localhost;
#GRANT ALL ON oar.* TO oar@localhost;
#GRANT SELECT ON oar.* TO oarreader@"%.imag.fr";
#GRANT SELECT ON oar.* TO oarreader@"%.imag.fr";
#FLUSH PRIVILEGES;

#CONNECT oar;
# Creation des tables dans la base de donnees oar
#DROP TABLE IF EXISTS jobs;
CREATE TABLE IF NOT EXISTS jobs (
job_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
job_name VARCHAR( 100 ) ,
job_env TEXT ,
cpuset_name VARCHAR(255),
job_type ENUM('INTERACTIVE','PASSIVE') DEFAULT 'PASSIVE' NOT NULL ,
info_type VARCHAR( 255 ) ,
state ENUM('Waiting','Hold','toLaunch','toError','toAckReservation','Launching','Running','Suspended','Resuming','Finishing','Terminated','Error')  NOT NULL ,
reservation ENUM('None','toSchedule','Scheduled') DEFAULT 'None'  NOT NULL ,
message VARCHAR( 255 ) NOT NULL ,
job_user VARCHAR( 255 ) NOT NULL ,
project VARCHAR( 255 ) NOT NULL ,
job_group VARCHAR( 255 ) NOT NULL ,
command TEXT ,
exit_code INT NOT NULL DEFAULT '0' ,
queue_name VARCHAR( 100 ) NOT NULL ,
properties TEXT ,
launching_directory TEXT NOT NULL ,
submission_time INT UNSIGNED NOT NULL ,
start_time INT UNSIGNED NOT NULL ,
stop_time INT UNSIGNED NOT NULL ,
file_id INT UNSIGNED,
accounted ENUM("YES","NO") NOT NULL DEFAULT "NO" ,
notify VARCHAR( 255 ) DEFAULT NULL ,
assigned_moldable_job INT UNSIGNED DEFAULT 0 ,
checkpoint INT UNSIGNED NOT NULL DEFAULT 0 ,
checkpoint_signal INT NOT NULL,
stdout_file TEXT ,
stderr_file TEXT ,
resubmit_job_id INT UNSIGNED DEFAULT 0,
suspended ENUM("YES","NO") NOT NULL DEFAULT "NO" ,
INDEX state (state),
INDEX reservation (reservation),
INDEX queue_name (queue_name),
INDEX accounted (accounted),
INDEX suspended (suspended),
PRIMARY KEY (job_id)
);

#DROP TABLE IF EXISTS job_types;
CREATE TABLE IF NOT EXISTS job_types (
job_id INT UNSIGNED NOT NULL ,
type VARCHAR(255) NOT NULL ,
types_index ENUM('CURRENT','LOG') DEFAULT 'CURRENT' NOT NULL ,
INDEX log (types_index),
INDEX type (type),
INDEX id_types (job_id)
);

#DROP TABLE IF EXISTS challenges;
CREATE TABLE IF NOT EXISTS challenges (
job_id INT UNSIGNED NOT NULL ,
challenge VARCHAR(255) NOT NULL ,
PRIMARY KEY (job_id)
);

#DROP TABLE IF EXISTS moldable_job_descriptions;
CREATE TABLE IF NOT EXISTS moldable_job_descriptions (
moldable_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
moldable_job_id INT UNSIGNED NOT NULL ,
moldable_walltime INT UNSIGNED NOT NULL ,
moldable_index ENUM('CURRENT','LOG') DEFAULT 'CURRENT' NOT NULL ,
INDEX job (moldable_job_id) ,
INDEX log (moldable_index) ,
PRIMARY KEY (moldable_id)
);

#DROP TABLE IF EXISTS job_resource_groups;
CREATE TABLE IF NOT EXISTS job_resource_groups (
res_group_id INT UNSIGNED NOT NULL AUTO_INCREMENT ,
res_group_moldable_id INT UNSIGNED NOT NULL ,
res_group_property TEXT ,
res_group_index ENUM('CURRENT','LOG') DEFAULT 'CURRENT' NOT NULL ,
INDEX moldable_job (res_group_moldable_id),
INDEX log (res_group_index) ,
PRIMARY KEY (res_group_id)
);

#DROP TABLE IF EXISTS job_resource_descriptions;
CREATE TABLE IF NOT EXISTS job_resource_descriptions (
res_job_group_id INT UNSIGNED NOT NULL,
res_job_resource_type VARCHAR(255) NOT NULL,
res_job_value INT NOT NULL,
res_job_order INT UNSIGNED NOT NULL DEFAULT 0,
res_job_index ENUM('CURRENT','LOG') DEFAULT 'CURRENT' NOT NULL ,
INDEX resgroup (res_job_group_id),
INDEX log (res_job_index) ,
PRIMARY KEY (res_job_group_id,res_job_resource_type,res_job_order)
);

#DROP TABLE IF EXISTS job_state_logs;
CREATE TABLE IF NOT EXISTS job_state_logs (
job_id INT UNSIGNED NOT NULL ,
job_state ENUM('Waiting','Hold','toLaunch','toError','toAckReservation','Launching','Finishing','Running','Terminated','Error')  NOT NULL ,
date_start INT UNSIGNED NOT NULL,
date_stop INT UNSIGNED DEFAULT 0,
INDEX id (job_id),
INDEX state (job_state)
);

#DROP TABLE IF EXISTS frag_jobs;
CREATE TABLE IF NOT EXISTS frag_jobs (
frag_id_job INT UNSIGNED NOT NULL ,
frag_date INT UNSIGNED NOT NULL ,
frag_state ENUM('LEON','TIMER_ARMED','LEON_EXTERMINATE','FRAGGED') DEFAULT 'LEON' NOT NULL ,
INDEX frag_state (frag_state),
PRIMARY KEY (frag_id_job)
);

#DROP TABLE IF EXISTS assigned_resources;
CREATE TABLE IF NOT EXISTS assigned_resources (
moldable_job_id INT UNSIGNED NOT NULL ,
resource_id INT UNSIGNED NOT NULL ,
assigned_resource_index ENUM('CURRENT','LOG') DEFAULT 'CURRENT' NOT NULL ,
INDEX mjob_id (moldable_job_id),
INDEX log (assigned_resource_index),
PRIMARY KEY (moldable_job_id,resource_id)
);

#DROP TABLE IF EXISTS resources;
CREATE TABLE IF NOT EXISTS resources (
resource_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
type VARCHAR( 100 ) NOT NULL DEFAULT "default" ,
network_address VARCHAR( 100 ) NOT NULL ,
state ENUM('Alive','Dead','Suspected','Absent')  NOT NULL ,
next_state ENUM('UnChanged','Alive','Dead','Absent','Suspected') DEFAULT 'UnChanged'  NOT NULL ,
finaud_decision ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
next_finaud_decision ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
state_num INT NOT NULL DEFAULT 0 ,
suspended_jobs ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
switch  VARCHAR( 50 ) NOT NULL DEFAULT "0" ,
cpu INT UNSIGNED NOT NULL DEFAULT 0 ,
cpuset INT UNSIGNED NOT NULL DEFAULT 0 ,
besteffort ENUM('YES','NO') DEFAULT 'YES' NOT NULL ,
deploy ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
expiry_date INT UNSIGNED NOT NULL ,
desktop_computing ENUM('YES','NO') DEFAULT 'NO' NOT NULL,
last_job_date INT UNSIGNED DEFAULT 0,
cm_availability INT UNSIGNED DEFAULT 0 NOT NULL ,
mem INT UNSIGNED DEFAULT 0 NOT NULL,
INDEX state (state),
INDEX next_state (next_state),
INDEX suspended_jobs (suspended_jobs),
PRIMARY KEY (resource_id)
);

#DROP TABLE IF EXISTS resource_logs;
CREATE TABLE IF NOT EXISTS resource_logs (
resource_log_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
resource_id INT UNSIGNED NOT NULL ,
attribute VARCHAR( 255 ) NOT NULL ,
value VARCHAR( 255 ) NOT NULL ,
date_start INT UNSIGNED NOT NULL,
date_stop INT UNSIGNED DEFAULT 0 ,
finaud_decision ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
INDEX resource (resource_id),
INDEX attribute (attribute),
INDEX finaud (finaud_decision),
INDEX val (value),
PRIMARY KEY (resource_log_id)
);


#DROP TABLE IF EXISTS queues;
CREATE TABLE IF NOT EXISTS queues (
queue_name VARCHAR( 100 ) NOT NULL ,
priority INT UNSIGNED NOT NULL ,
scheduler_policy VARCHAR( 100 ) NOT NULL ,
state ENUM('Active','notActive')  NOT NULL DEFAULT 'Active',
PRIMARY KEY (queue_name)
);

#DROP TABLE IF EXISTS admission_rules;
CREATE TABLE IF NOT EXISTS admission_rules (
id INT UNSIGNED NOT NULL AUTO_INCREMENT,
rule TEXT NOT NULL,
PRIMARY KEY (id)
);

#DROP TABLE IF EXISTS gantt_jobs_predictions;
CREATE TABLE IF NOT EXISTS gantt_jobs_predictions (
moldable_job_id INT UNSIGNED NOT NULL ,
start_time INT UNSIGNED NOT NULL ,
PRIMARY KEY (moldable_job_id)
);

#DROP TABLE IF EXISTS gantt_jobs_predictions_visu;
CREATE TABLE IF NOT EXISTS gantt_jobs_predictions_visu (
moldable_job_id INT UNSIGNED NOT NULL ,
start_time INT UNSIGNED NOT NULL ,
PRIMARY KEY (moldable_job_id)
);

#DROP TABLE IF EXISTS gantt_jobs_resources;
CREATE TABLE IF NOT EXISTS gantt_jobs_resources (
moldable_job_id INT UNSIGNED NOT NULL ,
resource_id INT UNSIGNED NOT NULL ,
PRIMARY KEY (moldable_job_id,resource_id)
);

#DROP TABLE IF EXISTS gantt_jobs_resources_visu;
CREATE TABLE IF NOT EXISTS gantt_jobs_resources_visu (
moldable_job_id INT UNSIGNED NOT NULL ,
resource_id INT UNSIGNED NOT NULL ,
PRIMARY KEY (moldable_job_id,resource_id)
);

#DROP TABLE IF EXISTS files;
CREATE TABLE IF NOT EXISTS files (
file_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
md5sum VARCHAR( 255 ) ,
location VARCHAR( 255 ) ,
method VARCHAR( 255 ) ,
compression VARCHAR( 255 ) ,
size INT UNSIGNED NOT NULL ,
INDEX md5sum (md5sum),
PRIMARY KEY (file_id)
);

#DROP TABLE IF EXISTS event_logs;
CREATE TABLE IF NOT EXISTS event_logs (
event_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
type VARCHAR(50) NOT NULL,
job_id INT UNSIGNED NOT NULL ,
date INT UNSIGNED NOT NULL ,
description VARCHAR(255) NOT NULL,
to_check ENUM('YES','NO') NOT NULL DEFAULT 'YES',
INDEX event_type (type),
INDEX event_check (to_check),
PRIMARY KEY (event_id)
);

#DROP TABLE IF EXISTS event_log_hostnames;
CREATE TABLE IF NOT EXISTS event_log_hostnames (
event_id INT UNSIGNED NOT NULL,
hostname VARCHAR( 255 ) NOT NULL ,
INDEX event_hostname (hostname),
PRIMARY KEY (event_id, hostname)
);

#DROP TABLE IF EXISTS accounting;
CREATE TABLE IF NOT EXISTS accounting (
window_start INT UNSIGNED NOT NULL ,
window_stop INT UNSIGNED NOT NULL ,
accounting_user VARCHAR( 255 ) NOT NULL ,
accounting_project VARCHAR( 255 ) NOT NULL ,
queue_name VARCHAR( 100 ) NOT NULL ,
consumption_type ENUM("ASKED","USED") NOT NULL ,
consumption INT UNSIGNED NOT NULL ,
INDEX accounting_user (accounting_user),
INDEX accounting_project (accounting_project),
INDEX accounting_queue (queue_name),
INDEX accounting_type (consumption_type),
PRIMARY KEY (window_start,window_stop,accounting_user,accounting_project,queue_name,consumption_type)
);

#DROP TABLE IF EXISTS job_dependencies;
CREATE TABLE IF NOT EXISTS job_dependencies (
job_id INT UNSIGNED NOT NULL ,
job_id_required INT UNSIGNED NOT NULL,
job_dependency_index ENUM('CURRENT','LOG') DEFAULT 'CURRENT' NOT NULL ,
INDEX id (job_id),
INDEX log (job_dependency_index),
PRIMARY KEY (job_id,job_id_required)
);

# Default insertions
# Specify the default value for queue parameter
INSERT IGNORE INTO admission_rules (rule) VALUES ('if (not defined($queue_name)) {$queue_name="default";}');
# Avoid users except oar to go in the admin queue
INSERT IGNORE INTO admission_rules (rule) VALUES ('if (($queue_name eq "admin") && ($user ne "oar")) {die("[ADMISSION RULE] Only oar user can submit jobs in the admin queue\\n");}');
# Force besteffort jobs to go on nodes with the besteffort property
INSERT IGNORE INTO admission_rules (rule) VALUES ('
if (grep(/^besteffort$/, @{$type_list})){
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND besteffort = \\\'YES\\\'";
    }else{
        $jobproperties = "besteffort = \\\'YES\\\'";
    }
    print("[ADMISSION RULE] Added automatically besteffort resource constraint\\n");
}
');
# Force besteffort jobs to go in the besteffort queue
INSERT IGNORE INTO admission_rules (rule) VALUES ('
if (grep(/^besteffort$/, @{$type_list})){
    $queue_name = "besteffort";
    print("[ADMISSION RULE] Redirect automatically in the besteffort queue\\n");
}
');
# Verify if besteffort jobs are not reservations
INSERT IGNORE INTO admission_rules (rule) VALUES ('
if ((grep(/^besteffort$/, @{$type_list})) and ($reservationField ne "None")){
    die("[ADMISSION RULE] Error : a besteffort typed job cannot be a reservation.\\n");
}
');
# Force deploy jobs to go on nodes with the deploy property
INSERT IGNORE INTO admission_rules (rule) VALUES ('
if (grep(/^deploy$/, @{$type_list})){
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND deploy = \\\'YES\\\'";
    }else{
        $jobproperties = "deploy = \\\'YES\\\'";
    }
    foreach my $mold (@{$ref_resource_list}){
        foreach my $r (@{$mold->[0]}){
            my $i = 0;
            while (($i <= $#{@{$r->{resources}}}) and ($r->{resources}->[$i]->{resource} ne "resource_id")){
                $i++;
            }
            splice(@{$r->{resources}}, $i, $#{@{$r->{resources}}} - $i + 1, {
                                                                                resource => "network_address",
                                                                                value    => 1,
                                                                            });
            
        }
    }

    print("[ADMISSION RULE] Modify resource description with deploy constraints\\n");
}
');

# Force desktop_computing jobs to go on nodes with the desktop_computing property
INSERT IGNORE INTO admission_rules (rule) VALUES ('
if (grep(/^desktop_computing$/, @{$type_list})){
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND desktop_computing = \\\'YES\\\'";
    }else{
        $jobproperties = "desktop_computing = \\\'YES\\\'";
    }
}else{
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND desktop_computing = \\\'NO\\\'";
    }else{
        $jobproperties = "desktop_computing = \\\'NO\\\'";
    }
}
print("[ADMISSION RULE] Added automatically desktop_computing resource constraints\\n");
');

# How to limit reservation number by user
INSERT IGNORE INTO admission_rules (rule) VALUES ('
if ($reservationField eq "toSchedule") {
    my $max_nb_resa = 2;
    my $nb_resa = $dbh->do("    SELECT job_id
                                FROM jobs
                                WHERE
                                    job_user = \\\'$user\\\' AND
                                    (reservation = \\\'toSchedule\\\' OR
                                    reservation = \\\'Scheduled\\\') AND
                                    (state = \\\'Waiting\\\' OR
                                     state = \\\'Hold\\\')
             ");
    if ($nb_resa >= $max_nb_resa){
        die("[ADMISSION RULE] Error : you cannot have more than $max_nb_resa waiting reservations.\\n");
    }
}
');

## How to perform actions if the user name is in a file
#INSERT IGNORE INTO admission_rules (rule) VALUES ('
#open(FILE, "/tmp/users.txt");
#while (($queue_name ne "admin") and ($_ = <FILE>)){
#    if ($_ =~ m/^\\s*$user\\s*$/m){
#        print("[ADMISSION RULE] Change assigned queue into admin\\n");
#        $queue_name = "admin";
#    }
#}
#close(FILE);
#');

# Limit walltime for interactive jobs
INSERT IGNORE INTO admission_rules (rule) VALUES ('
my $max_walltime = iolib::sql_to_duration("12:00:00");
if ($jobType eq "INTERACTIVE"){ 
    foreach my $mold (@{$ref_resource_list}){
        if ((defined($mold->[1])) and ($max_walltime < $mold->[1])){
            print("[ADMISSION RULE] Walltime to big for an INTERACTIVE job so it is set to $max_walltime.\\n");
            $mold->[1] = $max_walltime;
        }
    }
}
');

# specify the default walltime if it is not specified
INSERT IGNORE INTO admission_rules (rule) VALUES ('
my $default_wall = iolib::sql_to_duration("2:00:00");
foreach my $mold (@{$ref_resource_list}){
    if (!defined($mold->[1])){
        print("[ADMISSION RULE] Set default walltime to $default_wall.\\n");
        $mold->[1] = $default_wall;
    }
}
');

# Check if types given by the user are right
INSERT IGNORE INTO admission_rules (rule) VALUES ('
my @types = ("deploy","desktop_computing","besteffort","cosystem","idempotent","timesharing");
foreach my $t (@{$type_list}){
    my $i = 0;
    while (($types[$i] ne $t) and ($i <= $#types)){
        $i++;
    }
    if (($i > $#types) and ($t !~ /^timesharing/)){
        die("[ADMISSION RULE] The job type $t is not handled by OAR; Right values are : @types\\n");
    }
}
');
# If resource types are not specified, then we force them to default
INSERT IGNORE INTO admission_rules (rule) VALUES ('
foreach my $mold (@{$ref_resource_list}){
    foreach my $r (@{$mold->[0]}){
        my $prop = $r->{property};
        if (($prop !~ /[\\s\\(]type[\\s=]/) and ($prop !~ /^type[\\s=]/)){
            if (!defined($prop)){
                $r->{property} = "type = \\\'default\\\'";
            }else{
                $r->{property} = "($r->{property}) AND type = \\\'default\\\'";
            }
        }
    }
}
print("[ADMISSION RULE] Modify resource description with type constraints\\n");
}
');




INSERT IGNORE INTO queues (queue_name, priority, scheduler_policy) VALUES ('admin','10','oar_sched_gantt_with_timesharing');
INSERT IGNORE INTO queues (queue_name, priority, scheduler_policy) VALUES ('default','2','oar_sched_gantt_with_timesharing');
INSERT IGNORE INTO queues (queue_name, priority, scheduler_policy) VALUES ('besteffort','0','oar_sched_gantt_with_timesharing');

INSERT IGNORE INTO gantt_jobs_predictions (moldable_job_id , start_time) VALUES ('0','0');

