alter table resources change cm_availability available_upto INT UNSIGNED DEFAULT 0 NOT NULL;
alter table resources add last_available_upto INT UNSIGNED DEFAULT 0 NOT NULL;
update `schema` set version='2.4';
