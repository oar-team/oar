
ALTER TABLE resources ADD drain ENUM('YES','NO') DEFAULT 'NO' NOT NULL;

-- Update the database schema version
DELETE FROM `schema`;
INSERT INTO `schema`(version, name) VALUES ('2.5.4', '');

