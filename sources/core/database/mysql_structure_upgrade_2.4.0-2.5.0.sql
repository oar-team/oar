-- Gantt output time optimization
alter table resource_logs add index date_stop(date_stop);
alter table resource_logs add index date_start(date_start);

-- Update the database schema version
DELETE FROM `schema`;
INSERT INTO `schema`(version, name) VALUES ('2.5.0', '');

