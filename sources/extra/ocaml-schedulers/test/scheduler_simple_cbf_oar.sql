UPDATE `oar`.`queues` SET `scheduler_policy` = 'simple_cbf_oar' WHERE CONVERT( `queues`.`queue_name` USING utf8 ) = 'default' LIMIT 1 ;
