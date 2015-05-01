
ALTER TABLE job_dependencies ADD gap INT UNSIGNED NOT NULL DEFAULT 0;

-- Update the database schema version
DELETE FROM `schema`;
INSERT INTO `schema`(version, name) VALUES ('2.6.0', '');

