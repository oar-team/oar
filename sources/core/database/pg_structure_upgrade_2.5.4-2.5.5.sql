
ALTER TABLE accounting ALTER COLUMN consumption TYPE bigint;

-- Update the database schema version
DELETE FROM schema;
INSERT INTO schema(version, name) VALUES ('2.5.5', '');

