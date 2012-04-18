
ALTER TABLE jobs ADD array_index INT UNSIGNED NOT NULL DEFAULT 1;

-- Update the database schema version
DELETE FROM `schema`;
INSERT INTO `schema`(version, name) VALUES ('2.5.2', '');

