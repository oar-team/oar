-- $Id$
-- info version, change here if you have updated the db schema
DROP TABLE schema;
CREATE TABLE schema (
  version VARCHAR( 255 ) NOT NULL
);
INSERT INTO schema VALUES ('2.2.12');

CREATE TABLE gantt_jobs_predictions_log (
  sched_date integer NOT NULL default '0',
  moldable_job_id integer NOT NULL default '0',
  start_time integer NOT NULL default '0',
  PRIMARY KEY  (sched_date, moldable_job_id)
);

CREATE TABLE gantt_jobs_resources_log (
  sched_date integer NOT NULL default '0',
  moldable_job_id integer NOT NULL default '0',
  resource_id integer NOT NULL default '0',
  PRIMARY KEY  (sched_date, moldable_job_id,resource_id)
);
