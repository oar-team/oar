alter table resources change cm_availability available_upto INT UNSIGNED DEFAULT 0 NOT NULL;
alter table resources add last_available_upto INT UNSIGNED DEFAULT 0 NOT NULL;
delete from `schema`;
alter table `schema` add name VARCHAR( 255 ) NOT NULL;
INSERT INTO `schema`(version, name) VALUES ('2.4.0', 'Thriller');