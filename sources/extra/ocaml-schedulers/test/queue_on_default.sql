UPDATE `oar`.`queues` SET `state` = 'Active' WHERE CONVERT( `queues`.`queue_name` USING utf8 ) = 'default' LIMIT 1 ;
