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
jobName VARCHAR( 255 ) NOT NULL ,
jobType ENUM('INTERACTIVE','PASSIVE') DEFAULT 'PASSIVE' NOT NULL ,
infoType VARCHAR( 255 ) ,
state ENUM('Waiting','Hold','toLaunch','toError','toAckReservation','Launching','Running','Terminated','Error')  NOT NULL ,
reservation ENUM('None','toSchedule','Scheduled') DEFAULT 'None'  NOT NULL ,
message VARCHAR( 255 ) ,
user VARCHAR( 20 ) NOT NULL ,
command TEXT ,
bpid VARCHAR( 255 ) ,
queueName VARCHAR( 100 ) NOT NULL ,
properties TEXT ,
launchingDirectory VARCHAR( 255 ) DEFAULT ' ' NOT NULL ,
submissionTime DATETIME NOT NULL ,
startTime DATETIME NOT NULL ,
stopTime DATETIME NOT NULL ,
idFile INT UNSIGNED,
accounted ENUM("YES","NO") NOT NULL DEFAULT "NO" ,
mail VARCHAR( 255 ) DEFAULT NULL ,
assignedMoldableJob INT UNSIGNED DEFAULT 0 ,
checkpoint INT UNSIGNED NOT NULL DEFAULT 0 ,
INDEX state (state),
INDEX reservation (reservation),
INDEX queueName (queueName),
INDEX accounted (accounted),
PRIMARY KEY (idJob)
);

#DROP TABLE IF EXISTS job_types;
CREATE TABLE IF NOT EXISTS job_types (
jobId INT UNSIGNED NOT NULL ,
type VARCHAR(255) NOT NULL ,
typesIndex ENUM('CURRENT','LOG') DEFAULT 'CURRENT' NOT NULL ,
INDEX log (typesIndex)
);

#DROP TABLE IF EXISTS challenges;
CREATE TABLE IF NOT EXISTS challenges (
jobId INT UNSIGNED NOT NULL ,
challenge VARCHAR(255) NOT NULL ,
PRIMARY KEY (jobId)
);

#DROP TABLE IF EXISTS moldableJobs_description;
CREATE TABLE IF NOT EXISTS moldableJobs_description (
moldableId INT UNSIGNED NOT NULL AUTO_INCREMENT,
moldableJobId INT UNSIGNED NOT NULL ,
moldableWalltime VARCHAR(255) NOT NULL ,
moldableIndex ENUM('CURRENT','LOG') DEFAULT 'CURRENT' NOT NULL ,
INDEX job (moldableJobId) ,
INDEX log (moldableIndex) ,
PRIMARY KEY (moldableId)
);

#DROP TABLE IF EXISTS jobResources_group;
CREATE TABLE IF NOT EXISTS jobResources_group (
resGroupId INT UNSIGNED NOT NULL AUTO_INCREMENT ,
resGroupMoldableId INT UNSIGNED NOT NULL ,
resGroupProperty TEXT ,
resGroupIndex ENUM('CURRENT','LOG') DEFAULT 'CURRENT' NOT NULL ,
INDEX moldableJob (resGroupMoldableId),
INDEX log (resGroupIndex) ,
PRIMARY KEY (resGroupId)
);

#DROP TABLE IF EXISTS jobResources_description;
CREATE TABLE IF NOT EXISTS jobResources_description (
resJobGroupId INT UNSIGNED NOT NULL,
resJobResourceType VARCHAR(255) NOT NULL,
resJobValue INT NOT NULL,
resJobOrder INT UNSIGNED NOT NULL DEFAULT 0,
resJobIndex ENUM('CURRENT','LOG') DEFAULT 'CURRENT' NOT NULL ,
INDEX resgroup (resJobGroupId),
INDEX log (resJobIndex) ,
PRIMARY KEY (resJobGroupId,resJobResourceType)
);

#DROP TABLE IF EXISTS jobStates_log;
CREATE TABLE IF NOT EXISTS jobStates_log (
jobId INT UNSIGNED NOT NULL ,
jobState ENUM('Waiting','Hold','toLaunch','toError','toAckReservation','Launching','Running','Terminated','Error')  NOT NULL ,
dateStart DATETIME NOT NULL,
#dateStop DATETIME ,
dateStop INT UNSIGNED NOT NULL DEFAULT 0,
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

#DROP TABLE IF EXISTS assignedResources;
CREATE TABLE IF NOT EXISTS assignedResources (
idMoldableJob INT UNSIGNED NOT NULL ,
idResource INT UNSIGNED NOT NULL ,
assignedResourceIndex ENUM('CURRENT','LOG') DEFAULT 'CURRENT' NOT NULL ,
INDEX idMJob (idMoldableJob),
INDEX log (assignedResourceIndex),
PRIMARY KEY (idMoldableJob,idResource)
);

#DROP TABLE IF EXISTS resources;
CREATE TABLE IF NOT EXISTS resources (
resourceId INT UNSIGNED NOT NULL AUTO_INCREMENT,
networkAddress VARCHAR( 100 ) NOT NULL ,
state ENUM('Alive','Dead','Suspected','Absent')  NOT NULL ,
nextState ENUM('UnChanged','Alive','Dead','Absent','Suspected') DEFAULT 'UnChanged'  NOT NULL ,
finaudDecision ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
nextFinaudDecision ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
INDEX state (state),
INDEX nextState (nextState),
PRIMARY KEY (resourceId)
);

#DROP TABLE IF EXISTS resourceProperties_log;
CREATE TABLE IF NOT EXISTS resourceProperties_log (
resourceId INT UNSIGNED NOT NULL ,
attribute VARCHAR( 50 ) NOT NULL ,
value VARCHAR( 100 ) NOT NULL ,
dateStart DATETIME NOT NULL,
dateStop DATETIME ,
INDEX resource (resourceId),
INDEX attribute (attribute)
);


#DROP TABLE IF EXISTS resourceStates_log;
CREATE TABLE IF NOT EXISTS resourceStates_log (
resourceId INT UNSIGNED NOT NULL ,
changeState ENUM('Alive','Dead','Suspected','Absent')  NOT NULL ,
dateStart DATETIME NOT NULL,
dateStop DATETIME ,
finaudDecision ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
INDEX resourceId (resourceId),
INDEX state (changeState),
INDEX finaud (finaudDecision)
);


#DROP TABLE IF EXISTS resourceProperties;
CREATE TABLE IF NOT EXISTS resourceProperties (
resourceId INT UNSIGNED NOT NULL ,
switch  VARCHAR( 50 ) NOT NULL DEFAULT "0" ,
node VARCHAR( 100 ) NOT NULL DEFAULT "default" ,
cpu INT UNSIGNED NOT NULL DEFAULT 0 ,
besteffort ENUM('YES','NO') DEFAULT 'YES' NOT NULL ,
deploy ENUM('YES','NO') DEFAULT 'NO' NOT NULL ,
expiryDate DATETIME NOT NULL ,
desktopComputing ENUM('YES','NO') DEFAULT 'NO' NOT NULL,
PRIMARY KEY (resourceId)
);

#DROP TABLE IF EXISTS queues;
CREATE TABLE IF NOT EXISTS queues (
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

#DROP TABLE IF EXISTS ganttJobsPredictions;
CREATE TABLE IF NOT EXISTS ganttJobsPredictions (
idMoldableJob INT UNSIGNED NOT NULL ,
startTime DATETIME NOT NULL ,
PRIMARY KEY (idMoldableJob)
);

#DROP TABLE IF EXISTS ganttJobsPredictions_visu;
CREATE TABLE IF NOT EXISTS ganttJobsPredictions_visu (
idMoldableJob INT UNSIGNED NOT NULL ,
startTime DATETIME NOT NULL ,
PRIMARY KEY (idMoldableJob)
);

#DROP TABLE IF EXISTS ganttJobsResources;
CREATE TABLE IF NOT EXISTS ganttJobsResources (
idMoldableJob INT UNSIGNED NOT NULL ,
idResource INT UNSIGNED NOT NULL ,
PRIMARY KEY (idMoldableJob,idResource)
);

#DROP TABLE IF EXISTS ganttJobsResources_visu;
CREATE TABLE IF NOT EXISTS ganttJobsResources_visu (
idMoldableJob INT UNSIGNED NOT NULL ,
idResource INT UNSIGNED NOT NULL ,
PRIMARY KEY (idMoldableJob,idResource)
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

#DROP TABLE IF EXISTS events_log;
CREATE TABLE IF NOT EXISTS events_log (
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

#DROP TABLE IF EXISTS events_log_hostnames;
CREATE TABLE IF NOT EXISTS events_log_hostnames (
idEvent INT UNSIGNED NOT NULL,
hostname VARCHAR( 255 ) NOT NULL ,
INDEX eventHostname (hostname),
PRIMARY KEY (idEvent, hostname)
);

#DROP TABLE IF EXISTS accounting;
CREATE TABLE IF NOT EXISTS accounting (
window_start DATETIME NOT NULL ,
window_stop DATETIME NOT NULL ,
user VARCHAR( 20 ) NOT NULL ,
queue_name VARCHAR( 100 ) NOT NULL ,
consumption_type ENUM("ASKED","USED") NOT NULL ,
consumption INT UNSIGNED NOT NULL ,
INDEX accounting_user (user),
INDEX accounting_queue (queue_name),
INDEX accounting_type (consumption_type),
PRIMARY KEY (window_start,window_stop,user,queue_name,consumption_type)
);

#DROP TABLE IF EXISTS jobDependencies;
CREATE TABLE IF NOT EXISTS jobDependencies (
idJob INT UNSIGNED NOT NULL ,
idJobRequired INT UNSIGNED NOT NULL,
INDEX id (idJob),
PRIMARY KEY (idJob,idJobRequired)
);

#Insertion par defaut
# Specify the default walltime
#INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES ('if (not defined($maxTime)) {$maxTime = "1:00:00";}');
# Specify the default value for queue parameter
INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES ('if (not defined($queueName)) {$queueName="default";}');
# Restrict the maximum of the walltime for intercative jobs
#INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES ('if ((defined($maxTime)) && ($jobType eq "INTERACTIVE") && (sql_to_duration($maxTime) > sql_to_duration("12:00:00"))) {$maxTime = "12:00:00";}');
# Avoid users except oar to go in the admin queue
INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES ('if (($queueName eq "admin") && ($user ne "oar")) {$queueName="default";}');
# Force besteffort jobs to go on nodes with the besteffort property
INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES ('if ( "$queueName" eq "besteffort" ){ if ($jobproperties ne ""){ $jobproperties = "($jobproperties) AND besteffort = \\\\\\"YES\\\\\\""; }else{ $jobproperties = "besteffort = \\\\\\"YES\\\\\\"";} }');
# Force deploy jobs to go on nodes with the deploy property
INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES ('if ( "$queueName" eq "deploy" ){ if ($jobproperties ne ""){ $jobproperties = "($jobproperties) AND deploy = \\\\\\"YES\\\\\\""; }else{ $jobproperties = "deploy = \\\\\\"YES\\\\\\"";} }');

INSERT IGNORE INTO `queues` (`queueName` , `priority` , `schedulerPolicy`)  VALUES ('admin','10','oar_sched_gantt');
INSERT IGNORE INTO `queues` (`queueName` , `priority` , `schedulerPolicy`)  VALUES ('default','2','oar_sched_gantt');
INSERT IGNORE INTO `queues` (`queueName` , `priority` , `schedulerPolicy`)  VALUES ('deploy','1','oar_sched_gantt');
INSERT IGNORE INTO `queues` (`queueName` , `priority` , `schedulerPolicy`)  VALUES ('besteffort','0','oar_sched_gantt');

INSERT IGNORE INTO `ganttJobsPredictions` (`idMoldableJob` , `startTime`)  VALUES ('0','1970-01-01 01:00:01');

