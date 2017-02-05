-- Create the extratime table
CREATE TABLE IF NOT EXISTS extratime (
job_id INT UNSIGNED NOT NULL ,
pending INT NOT NULL DEFAULT 0,
delay_next_jobs ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
increment INT NOT NULL DEFAULT 0,
granted INT NOT NULL DEFAULT 0,
granted_with_delaying_next_jobs INT NOT NULL DEFAULT 0,
INDEX id (job_id),
PRIMARY KEY (job_id)
);

-- Update the database schema version
DELETE FROM `schema`;
INSERT INTO `schema`(version, name) VALUES ('2.5.8', '');

