ALTER TABLE jobs ADD array_id INTEGER NOT NULL default '0';
UPDATE jobs SET array_id = job_id ;

INSERT INTO schema VALUES ('2.3.2+svn1740');
