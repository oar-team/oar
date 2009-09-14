alter table resources rename column cm_availability to available_upto;
alter table resources add last_available_upto integer NOT NULL default '0';
delete from schema;
alter table schema add name VARCHAR( 255 ) NOT NULL;
INSERT INTO schema(version, name) VALUES ('2.4.0', 'Thriller');
