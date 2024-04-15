-- Add `whole` to the walltime_change table
ALTER TABLE walltime_change ADD whole ENUM('YES','NO') DEFAULT 'NO' NOT NULL;

ALTER TABLE walltime_change ADD granted_with_whole INT NOT NULL DEFAULT 0;

-- Add `timeout` to the walltime_change table
ALTER TABLE walltime_change ADD timeout INT UNSIGNED NOT NULL DEFAULT 0;

-- Update the database schema version
DELETE FROM `schema`;
INSERT INTO `schema`(version, name) VALUES ('2.5.4', '');
