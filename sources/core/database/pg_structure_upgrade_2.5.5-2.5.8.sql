-- Create the walltime_change table
CREATE TABLE walltime_change (
  job_id integer NOT NULL default '0',
  pending integer NOT NULL default '0',
  force varchar(3) check (force in ('YES','NO')) NOT NULL default 'NO', 
  delay_next_jobs varchar(3) check (delay_next_jobs in ('YES','NO')) NOT NULL default 'NO', 
  granted integer NOT NULL default '0',
  granted_with_force integer NOT NULL default '0',
  granted_with_delay_next_jobs integer NOT NULL default '0',
  PRIMARY KEY (job_id)
);
CREATE INDEX walltime_change_job_id ON walltime_change (job_id);

GRANT SELECT ON walltime_change TO %%DB_RO_USER%%;

-- Update the database schema version
DELETE FROM schema;
INSERT INTO schema(version, name) VALUES ('2.5.8', '');
