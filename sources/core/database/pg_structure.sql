-- info version, change here if you have updated the db schema
CREATE TABLE schema (
  version VARCHAR( 255 ) NOT NULL,
  name VARCHAR( 255 ) NOT NULL
);
INSERT INTO schema VALUES ('2.5.10','');

CREATE TABLE accounting (
  window_start integer NOT NULL ,
  window_stop integer NOT NULL DEFAULT '0',
  accounting_user varchar(255) NOT NULL default '',
  accounting_project varchar(255) NOT NULL default '',
  queue_name varchar(100) NOT NULL default '',
  consumption_type varchar(5) check (consumption_type in ('ASKED','USED')) NOT NULL default 'ASKED',
  consumption bigint NOT NULL default '0',
  PRIMARY KEY  (window_start,window_stop,accounting_user,accounting_project,queue_name,consumption_type)
);
CREATE INDEX accounting_user ON accounting (accounting_user);
CREATE INDEX accounting_project ON accounting (accounting_project);
CREATE INDEX accounting_queue ON accounting (queue_name);
CREATE INDEX accounting_type ON accounting (consumption_type);


CREATE TABLE admission_rules (
  id bigserial,
  priority integer NOT NULL DEFAULT '0',
  enabled varchar(3) check (enabled in ('YES','NO')) NOT NULL default 'YES',
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
CREATE INDEX challenge_job_id ON challenges (job_id);

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
CREATE INDEX event_job_id ON event_logs (job_id);

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


CREATE TABLE gantt_jobs_predictions_log (
  sched_date integer NOT NULL default '0',
  moldable_job_id integer NOT NULL default '0',
  start_time integer NOT NULL default '0',
  PRIMARY KEY  (sched_date, moldable_job_id)
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


CREATE TABLE gantt_jobs_resources_log (
  sched_date integer NOT NULL default '0',
  moldable_job_id integer NOT NULL default '0',
  resource_id integer NOT NULL default '0',
  PRIMARY KEY  (sched_date, moldable_job_id,resource_id)
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
  array_id integer NOT NULL default '0',
  array_index integer NOT NULL default '1',
  initial_request text,
  job_name varchar(100) ,
  job_env text ,
  job_type varchar(11) check (job_type in ('INTERACTIVE','PASSIVE')) NOT NULL default 'PASSIVE',
  info_type varchar(255) default NULL,
  state varchar(16) check (state in ('Waiting','Hold','toLaunch','toError','toAckReservation','Launching','Running','Suspended','Resuming','Finishing','Terminated','Error')) NOT NULL default 'Waiting',
  reservation varchar(10) check (reservation in ('None','toSchedule','Scheduled')) NOT NULL default 'None',
  message varchar(255) NOT NULL default '',
  scheduler_info varchar(255) NOT NULL default '',
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
  accounted varchar(3) check (accounted in ('YES','NO','NA')) NOT NULL default 'NO',
  notify varchar(255) default NULL,
  assigned_moldable_job integer default '0',
  checkpoint integer NOT NULL default '0',
  checkpoint_signal integer NOT NULL,
  stdout_file text ,
  stderr_file text ,
  resubmit_job_id integer NOT NULL default '0',
  suspended varchar(3) check (suspended in ('YES','NO')) NOT NULL default 'NO',
  PRIMARY KEY  (job_id)
);
CREATE INDEX state ON jobs (state);
CREATE INDEX state_id ON jobs (state,job_id);
CREATE INDEX reservation ON jobs (reservation);
CREATE INDEX queue_name ON jobs (queue_name);
CREATE INDEX accounted ON jobs (accounted);
CREATE INDEX suspended ON jobs (suspended);
CREATE INDEX job_array_id ON jobs (array_id);


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

CREATE TABLE scheduler (
  name VARCHAR(100) NOT NULL,
  script VARCHAR(100) NOT NULL,
  description VARCHAR(255) NOT NULL,
  PRIMARY KEY (name)
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
CREATE INDEX date_start ON resource_logs (date_start);
CREATE INDEX date_stop ON resource_logs (date_stop);
CREATE INDEX ix_resource_logs_id_dstop_attr ON resource_logs (resource_id, date_stop, attribute);


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
  cpuset varchar(255) NOT NULL default '0',
  besteffort varchar(3) check (besteffort in ('YES','NO')) NOT NULL default 'YES',
  deploy varchar(3) check (deploy in ('YES','NO')) NOT NULL default 'NO',
  expiry_date integer NOT NULL default '0',
  desktop_computing varchar(3) check (desktop_computing in ('YES','NO')) NOT NULL default 'NO',
  last_job_date integer NOT NULL default '0',
  available_upto integer NOT NULL default '2147483647',
  last_available_upto integer NOT NULL default '0',
  drain varchar(3) check (drain in ('YES','NO')) NOT NULL default 'NO',
  PRIMARY KEY (resource_id)
);
CREATE INDEX resource_state ON resources (state);
CREATE INDEX resource_next_state ON resources (next_state);
CREATE INDEX resource_suspended_jobs ON resources (suspended_jobs);
CREATE INDEX resource_type ON resources (type);
CREATE INDEX resource_network_address ON resources (network_address);

CREATE TABLE walltime_change (
  job_id integer NOT NULL default '0',
  pending integer NOT NULL default '0',
  force varchar(3) check (force in ('YES','NO')) NOT NULL default 'NO', 
  delay_next_jobs varchar(3) check (delay_next_jobs in ('YES','NO')) NOT NULL default 'NO', 
  whole varchar(3) check (whole in ('YES','NO')) NOT NULL default 'NO', 
  granted integer NOT NULL default '0',
  granted_with_force integer NOT NULL default '0',
  granted_with_delay_next_jobs integer NOT NULL default '0',
  granted_with_whole integer NOT NULL default '0',
  timeout integer NOT NULL default '0',
  PRIMARY KEY (job_id)
);
CREATE INDEX walltime_change_job_id ON walltime_change (job_id);
