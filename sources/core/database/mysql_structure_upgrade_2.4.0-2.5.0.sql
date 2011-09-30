# Gantt output time optimization
alter table resource_logs add index date_stop(date_stop);
alter table resource_logs add index date_start(date_start);

