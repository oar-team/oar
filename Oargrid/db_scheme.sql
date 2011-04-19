
CREATE DATABASE IF NOT EXISTS oar_grid;

CONNECT mysql;
INSERT INTO user (Host,User,Password) VALUES('localhost','oar_grid',PASSWORD('oar_grid'));

INSERT INTO user (Host,User,Password) VALUES('%.imag.fr','oar_grid',PASSWORD('oar_grid'));
INSERT INTO db  (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) VALUES
                               ('localhost','oar_grid','oar_grid','Y','Y','Y','Y','Y','Y');
INSERT INTO db  (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) VALUES
                               ('%.imag.fr','oar_grid','oar_grid','Y','Y','Y','Y','Y','Y');
FLUSH PRIVILEGES;
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, LOCK TABLES ON oar_grid.* TO oar_grid@localhost;
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, LOCK TABLES ON oar_grid.* TO oar_grid@"%.imag.fr";
FLUSH PRIVILEGES;


CONNECT oar_grid;

#DROP TABLE IF EXISTS clusters;
CREATE TABLE IF NOT EXISTS clusters (
clusterName VARCHAR( 255 ) NOT NULL ,
clusterHostname VARCHAR(255) NOT NULL ,
clusterDBHostname VARCHAR(255) NOT NULL ,
clusterOARDBName VARCHAR(30) NOT NULL ,
clusterDBUser VARCHAR(30) NOT NULL ,
clusterDBPassword VARCHAR(30) NOT NULL ,
clusterProperties VARCHAR(255),
parent VARCHAR(255),
deprecated int,
PRIMARY KEY (clusterName)
);

#DROP TABLE IF EXISTS cpusetPool;
CREATE TABLE IF NOT EXISTS cpusetPool (
name INT UNSIGNED NOT NULL ,
PRIMARY KEY (name)
);
INSERT INTO cpusetPool (name) VALUES (1);

#DROP TABLE IF EXISTS reservations;
CREATE TABLE IF NOT EXISTS reservations (
reservationId INT UNSIGNED NOT NULL AUTO_INCREMENT ,
reservationCommandLine TEXT NOT NULL ,
reservationUser VARCHAR(50) NOT NULL ,
reservationStartDate DATETIME NOT NULL ,
reservationWallTime VARCHAR(50) NOT NULL ,
reservationProgram TEXT NOT NULL ,
reservationDirectory TEXT NOT NULL ,
reservationSubmissionDate DATETIME NOT NULL ,
PRIMARY KEY (reservationId)
);

#DROP TABLE IF EXISTS clusterJobs;
CREATE TABLE IF NOT EXISTS clusterJobs (
clusterJobsReservationId INT UNSIGNED NOT NULL ,
clusterJobsClusterName VARCHAR(255) ,
clusterJobsBatchId INT UNSIGNED NOT NULL ,
clusterJobsNbNodes INT UNSIGNED NOT NULL ,
clusterJobsWeight INT UNSIGNED NOT NULL ,
clusterJobsProperties VARCHAR(255) , 
clusterJobsEnvironment VARCHAR(255) , 
clusterJobsPartition VARCHAR(50) , 
clusterJobsQueue VARCHAR(50) NOT NULL ,
clusterJobsName VARCHAR(255) DEFAULT "" ,
clusterJobsStatus VARCHAR(50) ,
clusterJobsResources varchar(255) , 
INDEX clusterName (clusterJobsClusterName) ,
PRIMARY KEY (clusterJobsReservationId,clusterJobsClusterName,clusterJobsBatchId)
);

#DROP TABLE IF EXISTS clusterProperties;
CREATE TABLE IF NOT EXISTS clusterProperties (
clusterName VARCHAR(255) ,
site VARCHAR(255) NOT NULL ,
architecture VARCHAR(255) NOT NULL ,
resourceUnit VARCHAR(128) NOT NULL ,
PRIMARY KEY (clusterName)
);
