##########
# FIELDS #
##########

#ALTER TABLE event_log ADD toCheck ENUM("YES","NO") NOT NULL DEFAULT "YES" ;
#ALTER TABLE event_log ADD INDEX eventCheck (toCheck);

DROP TABLE IF EXISTS event_log;
CREATE TABLE IF NOT EXISTS event_log (
idEvent INT UNSIGNED NOT NULL AUTO_INCREMENT,
type VARCHAR(50) NOT NULL,
idJob INT UNSIGNED NOT NULL ,
date DATETIME NOT NULL ,
description VARCHAR(255) NOT NULL,
toCheck ENUM('YES','NO') NOT NULL DEFAULT 'YES',
INDEX eventType (type),
INDEX eventCheck (toCheck),
PRIMARY KEY (idEvent)
);

CREATE TABLE IF NOT EXISTS event_log_hosts (
idEvent INT UNSIGNED NOT NULL,
hostname VARCHAR(255) NOT NULL,
INDEX eventHostname (hostname)
);

CREATE TABLE IF NOT EXISTS jobState_log (
jobId INT UNSIGNED NOT NULL ,
jobState ENUM('Waiting','Hold','toLaunch','toError','toAckReservation','Launching','Running','Terminated','Error')  NOT NULL ,
dateStart DATETIME NOT NULL,
dateStop DATETIME ,
INDEX id (jobId),
INDEX state (jobState)
);

CREATE TABLE IF NOT EXISTS nodeProperties_log (
hostname VARCHAR( 100 ) NOT NULL ,
property VARCHAR( 50 ) NOT NULL ,
value VARCHAR( 100 ) NOT NULL,
dateStart DATETIME NOT NULL,
dateStop DATETIME ,
INDEX host (hostname),
INDEX prop (property),
INDEX val (value)
);

