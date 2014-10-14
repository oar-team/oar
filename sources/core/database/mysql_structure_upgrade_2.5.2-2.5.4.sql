
ALTER TABLE resources ADD drain ENUM('YES','NO') DEFAULT 'NO' NOT NULL;

ALTER TABLE resources MODIFY cpuset VARCHAR( 255 ) NOT NULL DEFAULT "0";

ALTER TABLE admission_rules ADD priority INT UNSIGNED NOT NULL DEFAULT 0;

ALTER TABLE admission_rules ADD enabled ENUM('YES','NO') NOT NULL DEFAULT 'YES';

UPDATE admission_rules SET priority = id;

-- Update the database schema version
DELETE FROM `schema`;
INSERT INTO `schema`(version, name) VALUES ('2.5.4', '');

