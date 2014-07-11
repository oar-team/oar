
ALTER TABLE resources ADD drain ENUM('YES','NO') DEFAULT 'NO' NOT NULL;

ALTER TABLE resources MODIFY cpuset VARCHAR( 255 ) NOT NULL DEFAULT "0";

-- Update the database schema version
DELETE FROM `schema`;
INSERT INTO `schema`(version, name) VALUES ('2.5.4', '');

