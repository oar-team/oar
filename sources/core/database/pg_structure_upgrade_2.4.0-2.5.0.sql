-- Gantt output time optimization
CREATE INDEX date_start ON resource_logs (date_start);
CREATE INDEX date_stop ON resource_logs (date_stop);

-- Update the database schema version
DELETE FROM schema;
INSERT INTO schema(version, name) VALUES ('2.5.0', '');
