
ALTER TABLE resources ADD maintenance varchar(3) check (maintenance in ('on','off')) NOT NULL default 'off';

-- Update the database schema version
DELETE FROM schema;
INSERT INTO schema(version, name) VALUES ('2.5.4', '');
