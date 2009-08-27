alter table resources rename column cm_availability to available_upto;
update schema set version='2.4';

