
ALTER TABLE resources ADD maintenance ENUM('on','off') DEFAULT 'off' NOT NULL;

-- Update the database schema version
DELETE FROM `schema`;
INSERT INTO `schema`(version, name) VALUES ('2.5.4', '');

