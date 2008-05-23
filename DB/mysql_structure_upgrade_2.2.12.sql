# $Id$

DROP TABLE IF EXISTS `schema`;
CREATE TABLE IF NOT EXISTS `schema` (
version VARCHAR( 255 ) NOT NULL
);
INSERT INTO `schema` VALUES ('2.2.12');

#DROP TABLE IF EXISTS gantt_jobs_predictions_log;
CREATE TABLE IF NOT EXISTS gantt_jobs_predictions_log (
sched_date INT UNSIGNED NOT NULL ,
moldable_job_id INT UNSIGNED NOT NULL ,
start_time INT UNSIGNED NOT NULL ,
PRIMARY KEY (sched_date,moldable_job_id)
);

#DROP TABLE IF EXISTS gantt_jobs_resources_log;
CREATE TABLE IF NOT EXISTS gantt_jobs_resources_log (
sched_date INT UNSIGNED NOT NULL ,
moldable_job_id INT UNSIGNED NOT NULL ,
resource_id INT UNSIGNED NOT NULL ,
PRIMARY KEY (sched_date,moldable_job_id,resource_id)
);
