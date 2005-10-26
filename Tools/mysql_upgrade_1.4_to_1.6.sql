##########
# TABLES #
##########

CREATE TABLE IF NOT EXISTS accounting (
window_start DATETIME NOT NULL ,
window_stop DATETIME NOT NULL ,
user VARCHAR( 20 ) NOT NULL ,
queue_name VARCHAR( 100 ) NOT NULL ,
consumption_type ENUM("ASKED","USED") NOT NULL ,
consumption INT UNSIGNED NOT NULL ,
INDEX accounting_start (window_start),
INDEX accounting_stop (window_stop),
INDEX accounting_user (user),
INDEX accounting_queue (queue_name),
INDEX accounting_type (consumption_type),
PRIMARY KEY (window_start,window_stop,user,queue_name,consumption_type)
);

CREATE TABLE IF NOT EXISTS event_log (
#eventId INT UNSIGNED NOT NULL AUTO_INCREMENT,
type VARCHAR(50) NOT NULL,
idJob INT UNSIGNED NOT NULL ,
#hostname VARCHAR( 100 ) NOT NULL ,
date DATETIME NOT NULL ,
description VARCHAR(255) NOT NULL,
INDEX eventType (type)
);

CREATE TABLE IF NOT EXISTS ganttJobsNodes_visu (
idJob INT UNSIGNED NOT NULL ,
hostname VARCHAR( 100 ) NOT NULL ,
PRIMARY KEY (idJob,hostname)
);

CREATE TABLE IF NOT EXISTS ganttJobsPrediction_visu (
idJob INT UNSIGNED NOT NULL ,
startTime DATETIME NOT NULL ,
PRIMARY KEY (idJob)
);

DROP TABLE nodeState_log;
CREATE TABLE IF NOT EXISTS nodeState_log (
hostname VARCHAR( 100 ) NOT NULL ,
changeState ENUM('Alive','Dead','Suspected','Absent')  NOT NULL ,
dateStart DATETIME NOT NULL,
dateStop DATETIME ,
finaudDecision ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
INDEX host (hostname),
INDEX state (changeState),
INDEX finaud (finaudDecision)
);

##########
# FIELDS #
##########

ALTER TABLE jobs ADD accounted ENUM("YES","NO") NOT NULL DEFAULT "NO" ;
ALTER TABLE jobs ADD INDEX accounted (accounted);

ALTER TABLE nodeProperties ADD deploy ENUM('YES','NO') DEFAULT 'YES' NOT NULL ;

ALTER TABLE nodeState_log ADD finaudDecision ENUM('YES','NO') DEFAULT 'NO' NOT NULL ;
ALTER TABLE nodeState_log ADD INDEX finaud (finaudDecision);

ALTER TABLE nodes ADD finaudDecision ENUM('YES','NO') DEFAULT 'NO' NOT NULL ;
ALTER TABLE nodes ADD nextFinaudDecision ENUM('YES','NO') DEFAULT 'NO' NOT NULL ;


ALTER TABLE jobs CHANGE properties properties TEXT DEFAULT NULL ;


########
# ROWS #
########

INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES ('if ( "$queueName" eq "deploy" ){ if ($jobproperties ne ""){ $jobproperties = "($jobproperties) AND deploy = \\\\\\"YES\\\\\\""; }else{ $jobproperties = "deploy = \\\\\\"YES\\\\\\"";} }');

INSERT IGNORE INTO `queue` (`queueName` , `priority` , `schedulerPolicy`)  VALUES ('deploy','1','oar_sched_gant');

