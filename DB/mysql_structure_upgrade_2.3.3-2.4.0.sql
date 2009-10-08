alter table resources change cm_availability available_upto INT UNSIGNED DEFAULT 0 NOT NULL;
alter table resources add last_available_upto INT UNSIGNED DEFAULT 0 NOT NULL;
delete from `schema`;
alter table `schema` add name VARCHAR( 255 ) NOT NULL;
INSERT INTO `schema`(version, name) VALUES ('2.4.0', 'Thriller');
CREATE TABLE IF NOT EXISTS scheduler (
name VARCHAR( 100 ) NOT NULL,
script VARCHAR( 100 ) NOT NULL,
description VARCHAR( 255 ) NOT NULL,
PRIMARY KEY (name)
);
CREATE INDEX array_id ON jobs(array_id);
CREATE INDEX job_id ON event_logs (job_id);
CREATE INDEX job_id ON challenges(job_id);
