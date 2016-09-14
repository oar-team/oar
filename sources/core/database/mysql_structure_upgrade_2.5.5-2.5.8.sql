-- Create the extratime table
CREATE TABLE IF NOT EXISTS extratime (
job_id INT UNSIGNED NOT NULL ,
pending INT UNSIGNED NOT NULL DEFAULT 0,
granted INT UNSIGNED NOT NULL DEFAULT 0,
force ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
INDEX id (job_id),
PRIMARY KEY (job_id)
);

-- Update the database schema version
DELETE FROM `schema`;
INSERT INTO `schema`(version, name) VALUES ('2.5.8', '');

