-- Add `whole` to the walltime_change table

ALTER TABLE walltime_change ADD whole varchar(3) check (force in ('YES','NO')) NOT NULL default 'NO',
ALTER TABLE walltime_change ADD granted_with_whole integer NOT NULL default '0',

-- Add `timeout` to the walltime_change table
ALTER TABLE walltime_change ADD timeout integer NOT NULL default '3600',

-- Update the database schema version
DELETE FROM schema;
INSERT INTO schema(version, name) VALUES ('2.5.10', '');
