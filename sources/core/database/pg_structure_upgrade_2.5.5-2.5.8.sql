-- Create the extratime table
CREATE TABLE extratime (
  job_id integer NOT NULL default '0',
  pending integer NOT NULL default '0',
  delay_next_jobs varchar(3) check (delay_next_jobs in ('YES','NO')) NOT NULL default 'NO', 
  increment integer NOT NULL default '0',
  granted integer NOT NULL default '0',
  granted_with_delaying_next_jobs integer NOT NULL default '0',
  PRIMARY KEY (job_id)
);
CREATE INDEX extratime_job_id ON extratime (job_id);

-- Update the database schema version
DELETE FROM schema;
INSERT INTO schema(version, name) VALUES ('2.5.8', '');

