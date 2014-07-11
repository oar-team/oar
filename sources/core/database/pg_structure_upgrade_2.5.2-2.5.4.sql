
ALTER TABLE resources ADD drain varchar(3) check (drain in ('YES','NO')) NOT NULL default 'NO';

-- Update the database schema version
DELETE FROM schema;
INSERT INTO schema(version, name) VALUES ('2.5.4', '');
