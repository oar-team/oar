UPDATE `oar`.`queues` SET `state` = 'notActive' WHERE CONVERT( `queues`.`queue_name` USING utf8 ) = 'default' LIMIT 1 ;
