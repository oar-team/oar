# $Id: oar_jobs.sql,v 1.62 2005/10/26 12:32:21 capitn Exp $

# Creation de la base de donnees
#CREATE DATABASE IF NOT EXISTS oar;

# Creation de l utilisateur oar
#CONNECT mysql;
#INSERT INTO user (Host,User,Password) VALUES('localhost','oar',PASSWORD('oar'));

#INSERT INTO user (Host,User,Password) VALUES('%.imag.fr','oar',PASSWORD('oar'));
#INSERT INTO db  (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) VALUES
#				('localhost','oar','oar','Y','Y','Y','Y','Y','Y');
#INSERT INTO db  (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) VALUES
#				('%.imag.fr','oar','oar','Y','Y','Y','Y','Y','Y');
#FLUSH PRIVILEGES;

#GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON oar.* TO oar@localhost;
#GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON oar.* TO oar@"%.imag.fr";
#FLUSH PRIVILEGES;

#CONNECT oar;
# Creation des tables dans la base de donnees oar
#DROP TABLE IF EXISTS jobs;
CREATE TABLE IF NOT EXISTS jobs (
idJob INT UNSIGNED NOT NULL AUTO_INCREMENT,
jobType ENUM('INTERACTIVE','PASSIVE') DEFAULT 'PASSIVE' NOT NULL ,
infoType VARCHAR( 255 ) ,
state ENUM('Waiting','Hold','toLaunch','toError','toAckReservation','Launching','Running','Terminated','Error')  NOT NULL ,
reservation ENUM('None','toSchedule','Scheduled') DEFAULT 'None'  NOT NULL ,
message VARCHAR( 255 ) ,
user VARCHAR( 20 ) NOT NULL ,
nbNodes INT UNSIGNED NOT NULL ,
weight INT UNSIGNED NOT NULL ,
command TEXT ,
bpid VARCHAR( 255 ) ,
queueName VARCHAR( 100 ) NOT NULL ,
maxTime TIME NOT NULL ,
properties TEXT ,
launchingDirectory VARCHAR( 255 ) DEFAULT ' ' NOT NULL ,
submissionTime DATETIME NOT NULL ,
startTime DATETIME NOT NULL ,
stopTime DATETIME NOT NULL ,
idFile INT UNSIGNED,
accounted ENUM("YES","NO") NOT NULL DEFAULT "NO" ,
INDEX state (state),
INDEX reservation (reservation),
INDEX queueName (queueName),
INDEX accounted (accounted),
PRIMARY KEY (idJob)
);

#DROP TABLE IF EXISTS jobState_log;
CREATE TABLE IF NOT EXISTS jobState_log (
jobId INT UNSIGNED NOT NULL ,
jobState ENUM('Waiting','Hold','toLaunch','toError','toAckReservation','Launching','Running','Terminated','Error')  NOT NULL ,
dateStart DATETIME NOT NULL,
dateStop DATETIME ,
INDEX id (jobId),
INDEX state (jobState)
);

#DROP TABLE IF EXISTS fragJobs;
CREATE TABLE IF NOT EXISTS fragJobs (
fragIdJob INT UNSIGNED NOT NULL ,
fragDate DATETIME NOT NULL ,
fragState ENUM('LEON','TIMER_ARMED','LEON_EXTERMINATE','FRAGGED') DEFAULT 'LEON' NOT NULL ,
INDEX fragState (fragState),
PRIMARY KEY (fragIdJob)
);

#DROP TABLE IF EXISTS processJobs;
CREATE TABLE IF NOT EXISTS processJobs (
idJob INT UNSIGNED NOT NULL ,
hostname VARCHAR( 100 ) NOT NULL,
INDEX idJob (idJob),
PRIMARY KEY (idJob,hostname)
);

#DROP TABLE IF EXISTS processJobs_log;
CREATE TABLE IF NOT EXISTS processJobs_log (
idJob INT UNSIGNED NOT NULL ,
hostname VARCHAR( 100 ) NOT NULL,
INDEX idJob (idJob),
PRIMARY KEY (idJob,hostname)
);

#DROP TABLE IF EXISTS nodes;
CREATE TABLE IF NOT EXISTS nodes (
hostname VARCHAR( 100 ) NOT NULL ,
state ENUM('Alive','Dead','Suspected','Absent')  NOT NULL ,
maxWeight INT UNSIGNED DEFAULT 1 NOT NULL ,
weight INT UNSIGNED NOT NULL ,
nextState ENUM('UnChanged','Alive','Dead','Absent','Suspected') DEFAULT 'UnChanged'  NOT NULL ,
finaudDecision ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
nextFinaudDecision ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
INDEX state (state),
INDEX nextState (nextState),
PRIMARY KEY (hostname)
);

#DROP TABLE IF EXISTS nodeState_log;
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

#DROP TABLE IF EXISTS nodeProperties;
CREATE TABLE IF NOT EXISTS nodeProperties (
hostname VARCHAR( 100 ) NOT NULL ,
besteffort ENUM('YES','NO') DEFAULT 'YES' NOT NULL ,
deploy ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
expiryDate DATETIME NOT NULL ,
desktopComputing ENUM('YES','NO') DEFAULT 'NO' NOT NULL,
PRIMARY KEY (hostname)
);

#DROP TABLE IF EXISTS nodeProperties_log;
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

#DROP TABLE IF EXISTS queue;
CREATE TABLE IF NOT EXISTS queue (
queueName VARCHAR( 100 ) NOT NULL ,
priority INT UNSIGNED NOT NULL ,
schedulerPolicy VARCHAR( 100 ) NOT NULL ,
state ENUM('Active','notActive')  NOT NULL DEFAULT 'Active',
PRIMARY KEY (queueName)
);

#DROP TABLE IF EXISTS admissionRules;
CREATE TABLE IF NOT EXISTS admissionRules (
rule VARCHAR( 255 ) NOT NULL
#priority INT UNSIGNED NOT NULL DEFAULT 1
);

#DROP TABLE IF EXISTS ganttJobsPrediction;
CREATE TABLE IF NOT EXISTS ganttJobsPrediction (
idJob INT UNSIGNED NOT NULL ,
startTime DATETIME NOT NULL ,
PRIMARY KEY (idJob)
);

#DROP TABLE IF EXISTS ganttJobsPrediction_visu;
CREATE TABLE IF NOT EXISTS ganttJobsPrediction_visu (
idJob INT UNSIGNED NOT NULL ,
startTime DATETIME NOT NULL ,
PRIMARY KEY (idJob)
);

#DROP TABLE IF EXISTS ganttJobsNodes;
CREATE TABLE IF NOT EXISTS ganttJobsNodes (
idJob INT UNSIGNED NOT NULL ,
hostname VARCHAR( 100 ) NOT NULL ,
PRIMARY KEY (idJob,hostname)
);

#DROP TABLE IF EXISTS ganttJobsNodes_visu;
CREATE TABLE IF NOT EXISTS ganttJobsNodes_visu (
idJob INT UNSIGNED NOT NULL ,
hostname VARCHAR( 100 ) NOT NULL ,
PRIMARY KEY (idJob,hostname)
);

#DROP TABLE IF EXISTS files;
CREATE TABLE IF NOT EXISTS files (
idFile INT UNSIGNED NOT NULL AUTO_INCREMENT,
md5sum VARCHAR( 255 ) ,
location VARCHAR( 255 ) ,
method VARCHAR( 255 ) ,
compression VARCHAR( 255 ) ,
size INT UNSIGNED NOT NULL ,
INDEX md5sum (md5sum),
PRIMARY KEY (idFile)
);

#DROP TABLE IF EXISTS event_log;
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

#DROP TABLE IF EXISTS event_log_hosts;
CREATE TABLE IF NOT EXISTS event_log_hosts (
idEvent INT UNSIGNED NOT NULL,
hostname VARCHAR(255) NOT NULL,
INDEX eventHostname (hostname)
);

#DROP TABLE IF EXISTS accounting;
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

#Insertion par defaut
# Specify the default walltime
INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES ('if (not defined($maxTime)) {$maxTime = "1:00:00";}');
# Specify the default value for queue parameter
INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES ('if (not defined($queueName)) {$queueName="default";}');
# Restrict the maximum of the walltime for intercative jobs
INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES ('if ((defined($maxTime)) && ($jobType eq "INTERACTIVE") && (sql_to_duration($maxTime) > sql_to_duration("12:00:00"))) {$maxTime = "12:00:00";}');
# Avoid users except oar to go in the admin queue
INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES ('if (($queueName eq "admin") && ($user ne "oar")) {$queueName="default";}');
# Force besteffort jobs to go on nodes with the besteffort property
INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES ('if ( "$queueName" eq "besteffort" ){ if ($jobproperties ne ""){ $jobproperties = "($jobproperties) AND besteffort = \\\\\\"YES\\\\\\""; }else{ $jobproperties = "besteffort = \\\\\\"YES\\\\\\"";} }');
# Force deploy jobs to go on nodes with the deploy property
INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES ('if ( "$queueName" eq "deploy" ){ if ($jobproperties ne ""){ $jobproperties = "($jobproperties) AND deploy = \\\\\\"YES\\\\\\""; }else{ $jobproperties = "deploy = \\\\\\"YES\\\\\\"";} }');

INSERT IGNORE INTO `queue` (`queueName` , `priority` , `schedulerPolicy`)  VALUES ('admin','10','oar_sched_gant');
INSERT IGNORE INTO `queue` (`queueName` , `priority` , `schedulerPolicy`)  VALUES ('default','2','oar_sched_gant');
INSERT IGNORE INTO `queue` (`queueName` , `priority` , `schedulerPolicy`)  VALUES ('deploy','1','oar_sched_gant');
INSERT IGNORE INTO `queue` (`queueName` , `priority` , `schedulerPolicy`)  VALUES ('besteffort','0','oar_sched_gant');

