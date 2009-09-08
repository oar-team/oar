alter table resources rename column cm_availability to available_upto;
alter table resources add last_available_upto integer NOT NULL default '0';
update schema set version='2.4';

