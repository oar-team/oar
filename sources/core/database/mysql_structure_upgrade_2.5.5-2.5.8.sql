-- Create the extratime table
CREATE TABLE IF NOT EXISTS extratime (
job_id INT UNSIGNED NOT NULL ,
pending INT NOT NULL DEFAULT 0,
force ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
delay_next_jobs ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
granted INT NOT NULL DEFAULT 0,
granted_with_force INT NOT NULL DEFAULT 0,
granted_with_delay_next_jobs INT NOT NULL DEFAULT 0,
INDEX id (job_id),
PRIMARY KEY (job_id)
);

GRANT SELECT ON %%DB_NAME%%.walltime_change TO '%%DB_RO_USER%%'@'%' IDENTIFIED BY '%%DB_RO_PASS%%';

-- Update the database schema version
DELETE FROM `schema`;
INSERT INTO `schema`(version, name) VALUES ('2.5.8', '');

