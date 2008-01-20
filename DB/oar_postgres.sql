CREATE TABLE accounting (
  window_start integer NOT NULL ,
  window_stop integer NOT NULL DEFAULT '0',
  accounting_user varchar(255) NOT NULL default '',
  accounting_project varchar(255) NOT NULL default '',
  queue_name varchar(100) NOT NULL default '',
  consumption_type varchar(5) check (consumption_type in ('ASKED','USED')) NOT NULL default 'ASKED',
  consumption integer NOT NULL default '0',
  PRIMARY KEY  (window_start,window_stop,accounting_user,accounting_project,queue_name,consumption_type)
);
CREATE INDEX accounting_user ON accounting (accounting_user);
CREATE INDEX accounting_project ON accounting (accounting_project);
CREATE INDEX accounting_queue ON accounting (queue_name);
CREATE INDEX accounting_type ON accounting (consumption_type);


CREATE TABLE admission_rules (
  id bigserial,
  rule text NOT NULL,
  PRIMARY KEY  (id)
);


CREATE TABLE assigned_resources (
  moldable_job_id integer  NOT NULL default '0',
  resource_id integer NOT NULL default '0',
  assigned_resource_index varchar(7) check (assigned_resource_index in ('CURRENT','LOG')) NOT NULL default 'CURRENT',
  PRIMARY KEY  (moldable_job_id,resource_id)
);
CREATE INDEX mjob_id ON assigned_resources (moldable_job_id);
CREATE INDEX log ON assigned_resources (assigned_resource_index);


CREATE TABLE challenges (
  job_id integer NOT NULL default '0',
  challenge varchar(255) NOT NULL default '',
  ssh_private_key text NOT NULL default '' ,
  ssh_public_key text NOT NULL default '' ,
  PRIMARY KEY  (job_id)
);


CREATE TABLE event_log_hostnames (
  event_id integer NOT NULL default '0',
  hostname varchar(255) NOT NULL default '',
  PRIMARY KEY  (event_id,hostname)
);
CREATE INDEX event_hostname ON event_log_hostnames (hostname);


CREATE TABLE event_logs (
  event_id bigserial,
  type varchar(50) NOT NULL default '',
  job_id integer NOT NULL default '0',
  date integer NOT NULL default '0',
  description varchar(255) NOT NULL default '',
  to_check varchar(3) check (to_check in ('YES','NO')) NOT NULL default 'YES',
  PRIMARY KEY  (event_id)
);
CREATE INDEX event_type ON event_logs (type);
CREATE INDEX event_check ON event_logs (to_check);


CREATE TABLE files (
  file_id bigserial,
  md5sum varchar(255) default NULL,
  location varchar(255) default NULL,
  method varchar(255) default NULL,
  compression varchar(255) default NULL,
  size integer NOT NULL default '0',
  PRIMARY KEY  (file_id)
);
CREATE INDEX md5sum ON files (md5sum);


CREATE TABLE frag_jobs (
  frag_id_job integer  NOT NULL default '0',
  frag_date integer NOT NULL default '0',
  frag_state varchar(16) check (frag_state in ('LEON','TIMER_ARMED','LEON_EXTERMINATE','FRAGGED')) NOT NULL default 'LEON',
  PRIMARY KEY  (frag_id_job)
);
CREATE INDEX frag_state ON frag_jobs (frag_state);


CREATE TABLE gantt_jobs_predictions (
  moldable_job_id integer NOT NULL default '0',
  start_time integer NOT NULL default '0',
  PRIMARY KEY  (moldable_job_id)
);


CREATE TABLE gantt_jobs_predictions_visu (
  moldable_job_id integer NOT NULL default '0',
  start_time integer NOT NULL default '0',
  PRIMARY KEY  (moldable_job_id)
);


CREATE TABLE gantt_jobs_resources (
  moldable_job_id integer NOT NULL default '0',
  resource_id integer NOT NULL default '0',
  PRIMARY KEY  (moldable_job_id,resource_id)
);


CREATE TABLE gantt_jobs_resources_visu (
  moldable_job_id integer NOT NULL default '0',
  resource_id integer NOT NULL default '0',
  PRIMARY KEY  (moldable_job_id,resource_id)
);


CREATE TABLE job_dependencies (
  job_id integer NOT NULL default '0',
  job_id_required integer NOT NULL default '0',
  job_dependency_index varchar(7) check (job_dependency_index in ('CURRENT','LOG')) NOT NULL default 'CURRENT',
  PRIMARY KEY  (job_id,job_id_required)
);
CREATE INDEX id_dep ON job_dependencies (job_id);
CREATE INDEX log_dep ON job_dependencies (job_dependency_index);


CREATE TABLE job_resource_groups (
  res_group_id bigserial,
  res_group_moldable_id integer NOT NULL default '0',
  res_group_property text,
  res_group_index varchar(7) check (res_group_index in ('CURRENT','LOG')) NOT NULL default 'CURRENT',
  PRIMARY KEY  (res_group_id)
);
CREATE INDEX moldable_job ON job_resource_groups (res_group_moldable_id);
CREATE INDEX log_res ON job_resource_groups (res_group_index);


CREATE TABLE job_resource_descriptions (
  res_job_group_id integer NOT NULL default '0',
  res_job_resource_type varchar(255) NOT NULL default '',
  res_job_value integer NOT NULL default '0',
  res_job_order integer NOT NULL default '0',
  res_job_index varchar(7) check (res_job_index in ('CURRENT','LOG')) NOT NULL default 'CURRENT',
  PRIMARY KEY  (res_job_group_id,res_job_resource_type,res_job_order)
);
CREATE INDEX resgroup ON job_resource_descriptions (res_job_group_id);
CREATE INDEX log_res_desc ON job_resource_descriptions (res_job_index);


CREATE TABLE job_state_logs (
  job_state_log_id bigserial,
  job_id integer NOT NULL default '0',
  job_state varchar(16) check (job_state in ('Waiting','Hold','toLaunch','toError','toAckReservation','Launching','Running','Suspended','Resuming','Finishing','Terminated','Error')) NOT NULL default 'Waiting',
  date_start integer NOT NULL default '0',
  date_stop integer NOT NULL default '0',
  PRIMARY KEY (job_state_log_id)
);
CREATE INDEX id_job_log ON job_state_logs (job_id);
CREATE INDEX state_job_log ON job_state_logs (job_state);


CREATE TABLE job_types (
  job_type_id bigserial,
  job_id integer NOT NULL default '0',
  type varchar(255) NOT NULL default '',
  types_index varchar(7) check (types_index in ('CURRENT','LOG')) NOT NULL default 'CURRENT',
  PRIMARY KEY (job_type_id)
);
CREATE INDEX log_types ON job_types (types_index);
CREATE INDEX type ON job_types (type);
CREATE INDEX id_types ON job_types (job_id);


CREATE TABLE jobs (
  job_id bigserial,
  initial_request text,
  job_name varchar(100) ,
  job_env text ,
  cpuset_name varchar(255),
  job_type varchar(11) check (job_type in ('INTERACTIVE','PASSIVE')) NOT NULL default 'PASSIVE',
  info_type varchar(255) default NULL,
  state varchar(16) check (state in ('Waiting','Hold','toLaunch','toError','toAckReservation','Launching','Running','Suspended','Resuming','Finishing','Terminated','Error')) NOT NULL default 'Waiting',
  reservation varchar(10) check (reservation in ('None','toSchedule','Scheduled')) NOT NULL default 'None',
  message varchar(255) NOT NULL default '',
  job_user varchar(255) NOT NULL default '',
  project varchar(255) NOT NULL default '',
  job_group varchar(255) NOT NULL default '',
  command text,
  exit_code integer default NULL,
  queue_name varchar(100) NOT NULL default '',
  properties text,
  launching_directory text NOT NULL ,
  submission_time integer NOT NULL default '0',
  start_time integer NOT NULL default '0',
  stop_time integer NOT NULL default '0',
  file_id integer default NULL,
  accounted varchar(3) check (accounted in ('YES','NO')) NOT NULL default 'NO',
  notify varchar(255) default NULL,
  assigned_moldable_job integer default '0',
  checkpoint integer NOT NULL default '0',
  checkpoint_signal integer NOT NULL,
  stdout_file text ,
  stderr_file text ,
  resubmit_job_id integer NOT NULL default '0',
  suspended varchar(3) check (accounted in ('YES','NO')) NOT NULL default 'NO',
  PRIMARY KEY  (job_id)
);
CREATE INDEX state ON jobs (state);
CREATE INDEX state_id ON jobs (state,job_id);
CREATE INDEX reservation ON jobs (reservation);
CREATE INDEX queue_name ON jobs (queue_name);
CREATE INDEX accounted ON jobs (accounted);
CREATE INDEX suspended ON jobs (suspended);


CREATE TABLE moldable_job_descriptions (
  moldable_id bigserial,
  moldable_job_id integer NOT NULL default '0',
  moldable_walltime integer NOT NULL default '0',
  moldable_index varchar(7) check (moldable_index in ('CURRENT','LOG')) NOT NULL default 'CURRENT',
  PRIMARY KEY  (moldable_id)
);
CREATE INDEX job_mold ON moldable_job_descriptions (moldable_job_id);
CREATE INDEX log_mold_desc ON moldable_job_descriptions (moldable_index);


CREATE TABLE queues (
  queue_name varchar(100) NOT NULL default '',
  priority integer NOT NULL default '0',
  scheduler_policy varchar(100) NOT NULL default '',
  state varchar(9) check (state in ('Active','notActive')) NOT NULL default 'Active',
  PRIMARY KEY  (queue_name)
);


CREATE TABLE resource_logs (
  resource_log_id bigserial,
  resource_id integer NOT NULL default '0',
  attribute varchar(255) NOT NULL default '',
  value varchar(255) NOT NULL default '',
  date_start integer NOT NULL default '0',
  date_stop integer NOT NULL default '0',
  finaud_decision varchar(3) check (finaud_decision in ('YES','NO')) NOT NULL default 'NO',
  PRIMARY KEY (resource_log_id)
);
CREATE INDEX resource ON resource_logs (resource_id);
CREATE INDEX attribute ON resource_logs (attribute);
CREATE INDEX resource_id ON resource_logs (resource_id);
CREATE INDEX finaud ON resource_logs (finaud_decision);
CREATE INDEX val ON resource_logs (value);


CREATE TABLE resources (
  resource_id bigserial,
  type varchar(100) NOT NULL default 'default',
  network_address varchar(100) NOT NULL default '',
  state varchar(9) check (state in ('Alive','Dead','Suspected','Absent')) NOT NULL default 'Alive',
  next_state varchar(9) check (next_state in ('UnChanged','Alive','Dead','Absent','Suspected')) NOT NULL default 'UnChanged',
  finaud_decision varchar(3) check (finaud_decision in ('YES','NO')) NOT NULL default 'NO',
  next_finaud_decision varchar(3) check (next_finaud_decision in ('YES','NO')) NOT NULL default 'NO',
  state_num integer NOT NULL default '0',
  suspended_jobs varchar(3) check (suspended_jobs in ('YES','NO')) NOT NULL default 'NO',
  scheduler_priority integer NOT NULL default '0',
  switch varchar(50) NOT NULL default '0',
  cpu integer NOT NULL default '0',
  cpuset integer NOT NULL default '0',
  besteffort varchar(3) check (besteffort in ('YES','NO')) NOT NULL default 'YES',
  deploy varchar(3) check (deploy in ('YES','NO')) NOT NULL default 'NO',
  expiry_date integer NOT NULL default '0',
  desktop_computing varchar(3) check (desktop_computing in ('YES','NO')) NOT NULL default 'NO',
  last_job_date integer NOT NULL default '0',
  cm_availability integer NOT NULL default '0',
  mem integer NOT NULL default '0',
  PRIMARY KEY (resource_id)
);
CREATE INDEX resource_state ON resources (state);
CREATE INDEX resource_next_state ON resources (next_state);
CREATE INDEX resource_suspended_jobs ON resources (suspended_jobs);
CREATE INDEX resource_type ON resources (type);
CREATE INDEX resource_network_address ON resources (network_address);



-- Default insertions
-- Specify the default value for queue parameter
INSERT INTO admission_rules (rule) VALUES ('if (not defined($queue_name)) {$queue_name="default";}');
-- Avoid users except oar to go in the admin queue
INSERT INTO admission_rules (rule) VALUES ('if (($queue_name eq "admin") && ($user ne "oar")) {die("[ADMISSION RULE] Only the user oar can submit jobs in the admin queue\\n");}');

-- Force besteffort jobs to go on nodes with the besteffort property
INSERT INTO admission_rules (rule) VALUES ('
if (grep(/^besteffort$/, @{$type_list})){
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND besteffort = \\\'YES\\\'";
    }else{
        $jobproperties = "besteffort = \\\'YES\\\'";
    }
    print("[ADMISSION RULE] Added automatically besteffort resource constraint\\n");
}
');

-- Force besteffort jobs to go in the besteffort queue
INSERT INTO admission_rules (rule) VALUES ('
if (grep(/^besteffort$/, @{$type_list})){
    $queue_name = "besteffort";
    print("[ADMISSION RULE] Redirect automatically in the besteffort queue\\n");
}
');

-- Verify if besteffort jobs are not reservations
INSERT INTO admission_rules (rule) VALUES ('
if ((grep(/^besteffort$/, @{$type_list})) and ($reservationField ne "None")){
    die("[ADMISSION RULE] Error : a besteffort typed job cannot be a reservation.\\n");
}
');

-- Force deploy jobs to go on nodes with the deploy property
INSERT INTO admission_rules (rule) VALUES ('
if (grep(/^deploy$/, @{$type_list})){
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND deploy = \\\'YES\\\'";
    }else{
        $jobproperties = "deploy = \\\'YES\\\'";
    }
}
');

-- Force deploy and allow_classic_ssh type jobs to go only on nodes
INSERT INTO admission_rules (rule) VALUES ('
my @allowed_resources = ("network_address","switch");
if (grep(/^(deploy|allow_classic_ssh)$/, @{$type_list})){
    foreach my $mold (@{$ref_resource_list}){
        foreach my $r (@{$mold->[0]}){
            my $i = 0;
            while (($i <= $#{@{$r->{resources}}})){
                if (! grep(/^$r->{resources}->[$i]->{resource}$/, @allowed_resources)){
                    die("[ADMISSION RULE] \'$r->{resources}->[$i]->{resource}\' resource is not allowed with a deploy or allow_classic_ssh type job\\n");
                }
                $i++;
            }
        }
    }
}
');

-- Force desktop_computing jobs to go on nodes with the desktop_computing property
INSERT INTO admission_rules (rule) VALUES ('
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


-- How to limit reservation number by user
INSERT INTO admission_rules (rule) VALUES ('
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

--# How to perform actions if the user name is in a file
--INSERT INTO admission_rules (rule) VALUES ('
--open(FILE, "/tmp/users.txt");
--while (($queue_name ne "admin") and ($_ = <FILE>)){
--    if ($_ =~ m/^\\s*$user\\s*$/m){
--        print("[ADMISSION RULE] Change assigned queue into admin\\n");
--        $queue_name = "admin";
--    }
--}
--close(FILE);
--');

-- Limit walltime for interactive jobs
INSERT INTO admission_rules (rule) VALUES ('
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

-- specify the default walltime if it is not specified
INSERT INTO admission_rules (rule) VALUES ('
my $default_wall = iolib::sql_to_duration("2:00:00");
foreach my $mold (@{$ref_resource_list}){
    if (!defined($mold->[1])){
        print("[ADMISSION RULE] Set default walltime to $default_wall.\\n");
        $mold->[1] = $default_wall;
    }
}
');

-- Check if types given by the user are right
INSERT INTO admission_rules (rule) VALUES ('
my @types = ("deploy","desktop_computing","besteffort","cosystem","idempotent","timesharing","allow_classic_ssh");
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

-- If resource types are not specified, then we force them to default
INSERT INTO admission_rules (rule) VALUES ('
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
');


INSERT INTO queues (queue_name, priority, scheduler_policy) VALUES ('admin','10','oar_sched_gantt_with_timesharing');
INSERT INTO queues (queue_name, priority, scheduler_policy) VALUES ('default','2','oar_sched_gantt_with_timesharing');
INSERT INTO queues (queue_name, priority, scheduler_policy) VALUES ('besteffort','0','oar_sched_gantt_with_timesharing');

INSERT INTO gantt_jobs_predictions (moldable_job_id , start_time) VALUES ('0','0');

