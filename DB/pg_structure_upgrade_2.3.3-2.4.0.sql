alter table resources rename column cm_availability to available_upto;
alter table resources add last_available_upto integer NOT NULL default '0';
delete from schema;
alter table schema add name VARCHAR( 255 ) NOT NULL;
INSERT INTO schema(version, name) VALUES ('2.4.0', 'Thriller');
CREATE TABLE scheduler (
  name VARCHAR(100) NOT NULL,
  script VARCHAR(100) NOT NULL,
  description VARCHAR(255) NOT NULL,
  PRIMARY KEY (name)
);
CREATE INDEX job_array_id ON jobs(array_id);
CREATE INDEX event_job_id ON event_logs (job_id);
CREATE INDEX challenge_job_id ON challenges(job_id);
