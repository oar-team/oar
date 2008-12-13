ALTER TABLE jobs ADD array_id INT UNSIGNED NOT NULL DEFAULT 0;
UPDATE jobs SET array_id = job_id ;

INSERT INTO `schema` VALUES ('2.3.3');
