
ALTER TABLE resources ADD drain varchar(3) check (drain in ('YES','NO')) NOT NULL default 'NO';
ALTER TABLE resources ALTER COLUMN cpuset DROP DEFAULT,
                      ALTER COLUMN cpuset TYPE varchar(255),
                      ALTER COLUMN cpuset SET NOT NULL,
                      ALTER COLUMN cpuset SET default '0';

ALTER TABLE admission_rules ADD priority integer NOT NULL DEFAULT '0',
                            ADD enabled varchar(3) check (enabled in ('YES','NO')) NOT NULL default 'YES';

UPDATE admission_rules SET priority = id;

-- Update the database schema version
DELETE FROM schema;
INSERT INTO schema(version, name) VALUES ('2.5.4', '');

