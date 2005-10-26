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

