ALTER TABLE job_dependencies ADD min_start_shift  varchar(12) NOT NULL default '';
ALTER TABLE job_dependencies ADD max_start_shift  varchar(12) NOT NULL default '';

-- Update the database schema version
DELETE FROM schema;
INSERT INTO schema(version, name) VALUES ('2.6.0', '');

