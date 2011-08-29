UPDATE `oar`.`queues` SET `scheduler_policy` = 'oar_sched_gantt_with_timesharing' WHERE CONVERT( `queues`.`queue_name` USING utf8 ) = 'default' LIMIT 1 ;
