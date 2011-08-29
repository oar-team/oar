-- MySQL dump 10.11
--
-- Host: localhost    Database: oar
-- ------------------------------------------------------
-- Server version	5.0.51a-15

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `accounting`
--

DROP TABLE IF EXISTS `accounting`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `accounting` (
  `window_start` int(10) unsigned NOT NULL,
  `window_stop` int(10) unsigned NOT NULL,
  `accounting_user` varchar(255) NOT NULL,
  `accounting_project` varchar(255) NOT NULL,
  `queue_name` varchar(100) NOT NULL,
  `consumption_type` enum('ASKED','USED') NOT NULL,
  `consumption` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`window_start`,`window_stop`,`accounting_user`,`accounting_project`,`queue_name`,`consumption_type`),
  KEY `accounting_user` (`accounting_user`),
  KEY `accounting_project` (`accounting_project`),
  KEY `accounting_queue` (`queue_name`),
  KEY `accounting_type` (`consumption_type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `accounting`
--

LOCK TABLES `accounting` WRITE;
/*!40000 ALTER TABLE `accounting` DISABLE KEYS */;
/*!40000 ALTER TABLE `accounting` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `admission_rules`
--

DROP TABLE IF EXISTS `admission_rules`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `admission_rules` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `rule` text NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=15 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `admission_rules`
--

LOCK TABLES `admission_rules` WRITE;
/*!40000 ALTER TABLE `admission_rules` DISABLE KEYS */;
INSERT INTO `admission_rules` VALUES (1,'if (not defined($queue_name)) {$queue_name=\"default\";}'),(2,'die (\"[ADMISSION RULE] root and oar users are not allowed to submit jobs.\\n\") if ( $user eq \"root\" or $user eq \"oar\" );'),(3,'\nmy $admin_group = \"admin\";\nif ($queue_name eq \"admin\") {\n    my $members; \n    (undef,undef,undef, $members) = getgrnam($admin_group);\n    my %h = map { $_ => 1 } split(/\\s+/,$members);\n    if ( $h{$user} ne 1 ) {\n        {die(\"[ADMISSION RULE] Only member of the group \".$admin_group.\" can submit jobs in the admin queue\\n\");}\n    }\n}\n'),(4,'\nmy @bad_resources = (\"type\",\"state\",\"next_state\",\"finaud_decision\",\"next_finaud_decision\",\"state_num\",\"suspended_jobs\",\"besteffort\",\"deploy\",\"expiry_date\",\"desktop_computing\",\"last_job_date\",\"available_upto\",\"scheduler_priority\");\nforeach my $mold (@{$ref_resource_list}){\n    foreach my $r (@{$mold->[0]}){\n        my $i = 0;\n        while (($i <= $#{$r->{resources}})){\n            if (grep(/^$r->{resources}->[$i]->{resource}$/, @bad_resources)){\n                die(\"[ADMISSION RULE] \'$r->{resources}->[$i]->{resource}\' resource is not allowed\\n\");\n            }\n            $i++;\n        }\n    }\n}\n'),(5,'\nif (grep(/^besteffort$/, @{$type_list}) and not $queue_name eq \"besteffort\"){\n    $queue_name = \"besteffort\";\n    print(\"[ADMISSION RULE] Automatically redirect in the besteffort queue\\n\");\n}\nif ($queue_name eq \"besteffort\" and not grep(/^besteffort$/, @{$type_list})) {\n    push(@{$type_list},\"besteffort\");\n    print(\"[ADMISSION RULE] Automatically add the besteffort type\\n\");\n}\nif (grep(/^besteffort$/, @{$type_list})){\n    if ($jobproperties ne \"\"){\n        $jobproperties = \"($jobproperties) AND besteffort = \\\'YES\\\'\";\n    }else{\n        $jobproperties = \"besteffort = \\\'YES\\\'\";\n    }\n    print(\"[ADMISSION RULE] Automatically add the besteffort constraint on the resources\\n\");\n}\n'),(6,'\nif ((grep(/^besteffort$/, @{$type_list})) and ($reservationField ne \"None\")){\n    die(\"[ADMISSION RULE] Error: a job cannot both be of type besteffort and be a reservation.\\n\");\n}\n'),(7,'\nif (grep(/^deploy$/, @{$type_list})){\n    if ($jobproperties ne \"\"){\n        $jobproperties = \"($jobproperties) AND deploy = \\\'YES\\\'\";\n    }else{\n        $jobproperties = \"deploy = \\\'YES\\\'\";\n    }\n}\n'),(8,'\nmy @bad_resources = (\"core\",\"cpu\",\"resource_id\",);\nif (grep(/^(deploy|allow_classic_ssh)$/, @{$type_list})){\n    foreach my $mold (@{$ref_resource_list}){\n        foreach my $r (@{$mold->[0]}){\n            my $i = 0;\n            while (($i <= $#{$r->{resources}})){\n                if (grep(/^$r->{resources}->[$i]->{resource}$/, @bad_resources)){\n                    die(\"[ADMISSION RULE] \'$r->{resources}->[$i]->{resource}\' resource is not allowed with a deploy or allow_classic_ssh type job\\n\");\n                }\n                $i++;\n            }\n        }\n    }\n}\n'),(9,'\nif (grep(/^desktop_computing$/, @{$type_list})){\n    print(\"[ADMISSION RULE] Added automatically desktop_computing resource constraints\\n\");\n    if ($jobproperties ne \"\"){\n        $jobproperties = \"($jobproperties) AND desktop_computing = \\\'YES\\\'\";\n    }else{\n        $jobproperties = \"desktop_computing = \\\'YES\\\'\";\n    }\n}else{\n    if ($jobproperties ne \"\"){\n        $jobproperties = \"($jobproperties) AND desktop_computing = \\\'NO\\\'\";\n    }else{\n        $jobproperties = \"desktop_computing = \\\'NO\\\'\";\n    }\n}\n'),(10,'\nif ($reservationField eq \"toSchedule\") {\n    my $unlimited=0;\n    if (open(FILE, \"< $ENV{HOME}/unlimited_reservation.users\")) {\n        while (<FILE>){\n            if (m/^\\s*$user\\s*$/m){\n                $unlimited=1;\n            }\n        }\n        close(FILE);\n    }\n    if ($unlimited > 0) {\n        print(\"[ADMISSION RULE] $user is granted the privilege to do unlimited reservations\\n\");\n    } else {\n        my $max_nb_resa = 2;\n        my $nb_resa = $dbh->do(\"    SELECT job_id\n                                    FROM jobs\n                                    WHERE\n                                        job_user = \\\'$user\\\' AND\n                                        (reservation = \\\'toSchedule\\\' OR\n                                        reservation = \\\'Scheduled\\\') AND\n                                        (state = \\\'Waiting\\\' OR state = \\\'Hold\\\')\n                               \");\n        if ($nb_resa >= $max_nb_resa){\n            die(\"[ADMISSION RULE] Error : you cannot have more than $max_nb_resa waiting reservations.\\n\");\n        }\n    }\n}\n'),(11,'\nmy $max_walltime = OAR::IO::sql_to_duration(\"12:00:00\");\nif (($jobType eq \"INTERACTIVE\") and ($reservationField eq \"None\")){ \n    foreach my $mold (@{$ref_resource_list}){\n        if ((defined($mold->[1])) and ($max_walltime < $mold->[1])){\n            print(\"[ADMISSION RULE] Walltime to big for an INTERACTIVE job so it is set to $max_walltime.\\n\");\n            $mold->[1] = $max_walltime;\n        }\n    }\n}\n'),(12,'\nmy $default_wall = OAR::IO::sql_to_duration(\"2:00:00\");\nforeach my $mold (@{$ref_resource_list}){\n    if (!defined($mold->[1])){\n        print(\"[ADMISSION RULE] Set default walltime to $default_wall.\\n\");\n        $mold->[1] = $default_wall;\n    }\n}\n'),(13,'\nmy @types = (\"container\",\"inner\",\"deploy\",\"desktop_computing\",\"besteffort\",\"cosystem\",\"idempotent\",\"timesharing\",\"allow_classic_ssh\");\nforeach my $t (@{$type_list}){\n    my $i = 0;\n    while (($types[$i] ne $t) and ($i <= $#types)){\n        $i++;\n    }\n    if (($i > $#types) and ($t !~ /^(timesharing|inner)/)){\n        die(\"[ADMISSION RULE] The job type $t is not handled by OAR; Right values are : @types\\n\");\n    }\n}\n'),(14,'\nforeach my $mold (@{$ref_resource_list}){\n    foreach my $r (@{$mold->[0]}){\n        my $prop = $r->{property};\n        if (($prop !~ /[\\s\\(]type[\\s=]/) and ($prop !~ /^type[\\s=]/)){\n            if (!defined($prop)){\n                $r->{property} = \"type = \\\'default\\\'\";\n            }else{\n                $r->{property} = \"($r->{property}) AND type = \\\'default\\\'\";\n            }\n        }\n    }\n}\nprint(\"[ADMISSION RULE] Modify resource description with type constraints\\n\");\n');
/*!40000 ALTER TABLE `admission_rules` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `assigned_resources`
--

DROP TABLE IF EXISTS `assigned_resources`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `assigned_resources` (
  `moldable_job_id` int(10) unsigned NOT NULL,
  `resource_id` int(10) unsigned NOT NULL,
  `assigned_resource_index` enum('CURRENT','LOG') NOT NULL default 'CURRENT',
  PRIMARY KEY  (`moldable_job_id`,`resource_id`),
  KEY `mjob_id` (`moldable_job_id`),
  KEY `log` (`assigned_resource_index`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `assigned_resources`
--

LOCK TABLES `assigned_resources` WRITE;
/*!40000 ALTER TABLE `assigned_resources` DISABLE KEYS */;
/*!40000 ALTER TABLE `assigned_resources` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `challenges`
--

DROP TABLE IF EXISTS `challenges`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `challenges` (
  `job_id` int(10) unsigned NOT NULL,
  `challenge` varchar(255) NOT NULL,
  `ssh_private_key` text NOT NULL,
  `ssh_public_key` text NOT NULL,
  PRIMARY KEY  (`job_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `challenges`
--

LOCK TABLES `challenges` WRITE;
/*!40000 ALTER TABLE `challenges` DISABLE KEYS */;
INSERT INTO `challenges` VALUES (1,'841021991175','','');
/*!40000 ALTER TABLE `challenges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_log_hostnames`
--

DROP TABLE IF EXISTS `event_log_hostnames`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `event_log_hostnames` (
  `event_id` int(10) unsigned NOT NULL,
  `hostname` varchar(255) NOT NULL,
  PRIMARY KEY  (`event_id`,`hostname`),
  KEY `event_hostname` (`hostname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `event_log_hostnames`
--

LOCK TABLES `event_log_hostnames` WRITE;
/*!40000 ALTER TABLE `event_log_hostnames` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_log_hostnames` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_logs`
--

DROP TABLE IF EXISTS `event_logs`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `event_logs` (
  `event_id` int(10) unsigned NOT NULL auto_increment,
  `type` varchar(50) NOT NULL,
  `job_id` int(10) unsigned NOT NULL,
  `date` int(10) unsigned NOT NULL,
  `description` varchar(255) NOT NULL,
  `to_check` enum('YES','NO') NOT NULL default 'YES',
  PRIMARY KEY  (`event_id`),
  KEY `event_type` (`type`),
  KEY `event_check` (`to_check`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `event_logs`
--

LOCK TABLES `event_logs` WRITE;
/*!40000 ALTER TABLE `event_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `files`
--

DROP TABLE IF EXISTS `files`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `files` (
  `file_id` int(10) unsigned NOT NULL auto_increment,
  `md5sum` varchar(255) default NULL,
  `location` varchar(255) default NULL,
  `method` varchar(255) default NULL,
  `compression` varchar(255) default NULL,
  `size` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`file_id`),
  KEY `md5sum` (`md5sum`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `files`
--

LOCK TABLES `files` WRITE;
/*!40000 ALTER TABLE `files` DISABLE KEYS */;
/*!40000 ALTER TABLE `files` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `frag_jobs`
--

DROP TABLE IF EXISTS `frag_jobs`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `frag_jobs` (
  `frag_id_job` int(10) unsigned NOT NULL,
  `frag_date` int(10) unsigned NOT NULL,
  `frag_state` enum('LEON','TIMER_ARMED','LEON_EXTERMINATE','FRAGGED') NOT NULL default 'LEON',
  PRIMARY KEY  (`frag_id_job`),
  KEY `frag_state` (`frag_state`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `frag_jobs`
--

LOCK TABLES `frag_jobs` WRITE;
/*!40000 ALTER TABLE `frag_jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `frag_jobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gantt_jobs_predictions`
--

DROP TABLE IF EXISTS `gantt_jobs_predictions`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `gantt_jobs_predictions` (
  `moldable_job_id` int(10) unsigned NOT NULL,
  `start_time` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`moldable_job_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `gantt_jobs_predictions`
--

LOCK TABLES `gantt_jobs_predictions` WRITE;
/*!40000 ALTER TABLE `gantt_jobs_predictions` DISABLE KEYS */;
INSERT INTO `gantt_jobs_predictions` VALUES (0,1223567271),(1,1223575200);
/*!40000 ALTER TABLE `gantt_jobs_predictions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gantt_jobs_predictions_log`
--

DROP TABLE IF EXISTS `gantt_jobs_predictions_log`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `gantt_jobs_predictions_log` (
  `sched_date` int(10) unsigned NOT NULL,
  `moldable_job_id` int(10) unsigned NOT NULL,
  `start_time` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`sched_date`,`moldable_job_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `gantt_jobs_predictions_log`
--

LOCK TABLES `gantt_jobs_predictions_log` WRITE;
/*!40000 ALTER TABLE `gantt_jobs_predictions_log` DISABLE KEYS */;
/*!40000 ALTER TABLE `gantt_jobs_predictions_log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gantt_jobs_predictions_visu`
--

DROP TABLE IF EXISTS `gantt_jobs_predictions_visu`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `gantt_jobs_predictions_visu` (
  `moldable_job_id` int(10) unsigned NOT NULL,
  `start_time` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`moldable_job_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `gantt_jobs_predictions_visu`
--

LOCK TABLES `gantt_jobs_predictions_visu` WRITE;
/*!40000 ALTER TABLE `gantt_jobs_predictions_visu` DISABLE KEYS */;
INSERT INTO `gantt_jobs_predictions_visu` VALUES (0,1223567271),(1,1223575200);
/*!40000 ALTER TABLE `gantt_jobs_predictions_visu` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gantt_jobs_resources`
--

DROP TABLE IF EXISTS `gantt_jobs_resources`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `gantt_jobs_resources` (
  `moldable_job_id` int(10) unsigned NOT NULL,
  `resource_id` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`moldable_job_id`,`resource_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `gantt_jobs_resources`
--

LOCK TABLES `gantt_jobs_resources` WRITE;
/*!40000 ALTER TABLE `gantt_jobs_resources` DISABLE KEYS */;
INSERT INTO `gantt_jobs_resources` VALUES (1,1),(1,2),(1,3);
/*!40000 ALTER TABLE `gantt_jobs_resources` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gantt_jobs_resources_log`
--

DROP TABLE IF EXISTS `gantt_jobs_resources_log`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `gantt_jobs_resources_log` (
  `sched_date` int(10) unsigned NOT NULL,
  `moldable_job_id` int(10) unsigned NOT NULL,
  `resource_id` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`sched_date`,`moldable_job_id`,`resource_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `gantt_jobs_resources_log`
--

LOCK TABLES `gantt_jobs_resources_log` WRITE;
/*!40000 ALTER TABLE `gantt_jobs_resources_log` DISABLE KEYS */;
/*!40000 ALTER TABLE `gantt_jobs_resources_log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gantt_jobs_resources_visu`
--

DROP TABLE IF EXISTS `gantt_jobs_resources_visu`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `gantt_jobs_resources_visu` (
  `moldable_job_id` int(10) unsigned NOT NULL,
  `resource_id` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`moldable_job_id`,`resource_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `gantt_jobs_resources_visu`
--

LOCK TABLES `gantt_jobs_resources_visu` WRITE;
/*!40000 ALTER TABLE `gantt_jobs_resources_visu` DISABLE KEYS */;
INSERT INTO `gantt_jobs_resources_visu` VALUES (1,1),(1,2),(1,3);
/*!40000 ALTER TABLE `gantt_jobs_resources_visu` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `job_dependencies`
--

DROP TABLE IF EXISTS `job_dependencies`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `job_dependencies` (
  `job_id` int(10) unsigned NOT NULL,
  `job_id_required` int(10) unsigned NOT NULL,
  `job_dependency_index` enum('CURRENT','LOG') NOT NULL default 'CURRENT',
  PRIMARY KEY  (`job_id`,`job_id_required`),
  KEY `id` (`job_id`),
  KEY `log` (`job_dependency_index`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `job_dependencies`
--

LOCK TABLES `job_dependencies` WRITE;
/*!40000 ALTER TABLE `job_dependencies` DISABLE KEYS */;
/*!40000 ALTER TABLE `job_dependencies` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `job_resource_descriptions`
--

DROP TABLE IF EXISTS `job_resource_descriptions`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `job_resource_descriptions` (
  `res_job_group_id` int(10) unsigned NOT NULL,
  `res_job_resource_type` varchar(255) NOT NULL,
  `res_job_value` int(11) NOT NULL,
  `res_job_order` int(10) unsigned NOT NULL default '0',
  `res_job_index` enum('CURRENT','LOG') NOT NULL default 'CURRENT',
  PRIMARY KEY  (`res_job_group_id`,`res_job_resource_type`,`res_job_order`),
  KEY `resgroup` (`res_job_group_id`),
  KEY `log` (`res_job_index`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `job_resource_descriptions`
--

LOCK TABLES `job_resource_descriptions` WRITE;
/*!40000 ALTER TABLE `job_resource_descriptions` DISABLE KEYS */;
INSERT INTO `job_resource_descriptions` VALUES (1,'resource_id',3,0,'CURRENT');
/*!40000 ALTER TABLE `job_resource_descriptions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `job_resource_groups`
--

DROP TABLE IF EXISTS `job_resource_groups`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `job_resource_groups` (
  `res_group_id` int(10) unsigned NOT NULL auto_increment,
  `res_group_moldable_id` int(10) unsigned NOT NULL,
  `res_group_property` text,
  `res_group_index` enum('CURRENT','LOG') NOT NULL default 'CURRENT',
  PRIMARY KEY  (`res_group_id`),
  KEY `moldable_job` (`res_group_moldable_id`),
  KEY `log` (`res_group_index`)
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `job_resource_groups`
--

LOCK TABLES `job_resource_groups` WRITE;
/*!40000 ALTER TABLE `job_resource_groups` DISABLE KEYS */;
INSERT INTO `job_resource_groups` VALUES (1,1,'type = \'default\'','CURRENT');
/*!40000 ALTER TABLE `job_resource_groups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `job_state_logs`
--

DROP TABLE IF EXISTS `job_state_logs`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `job_state_logs` (
  `job_state_log_id` int(10) unsigned NOT NULL auto_increment,
  `job_id` int(10) unsigned NOT NULL,
  `job_state` enum('Waiting','Hold','toLaunch','toError','toAckReservation','Launching','Finishing','Running','Suspended','Resuming','Terminated','Error') NOT NULL,
  `date_start` int(10) unsigned NOT NULL,
  `date_stop` int(10) unsigned default '0',
  PRIMARY KEY  (`job_state_log_id`),
  KEY `id` (`job_id`),
  KEY `state` (`job_state`)
) ENGINE=MyISAM AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `job_state_logs`
--

LOCK TABLES `job_state_logs` WRITE;
/*!40000 ALTER TABLE `job_state_logs` DISABLE KEYS */;
INSERT INTO `job_state_logs` VALUES (1,1,'Waiting',1223567218,1223567219),(2,1,'toAckReservation',1223567219,1223567219),(3,1,'Waiting',1223567219,0);
/*!40000 ALTER TABLE `job_state_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `job_types`
--

DROP TABLE IF EXISTS `job_types`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `job_types` (
  `job_type_id` int(10) unsigned NOT NULL auto_increment,
  `job_id` int(10) unsigned NOT NULL,
  `type` varchar(255) NOT NULL,
  `types_index` enum('CURRENT','LOG') NOT NULL default 'CURRENT',
  PRIMARY KEY  (`job_type_id`),
  KEY `log` (`types_index`),
  KEY `type` (`type`),
  KEY `id_types` (`job_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `job_types`
--

LOCK TABLES `job_types` WRITE;
/*!40000 ALTER TABLE `job_types` DISABLE KEYS */;
/*!40000 ALTER TABLE `job_types` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `jobs`
--

DROP TABLE IF EXISTS `jobs`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `jobs` (
  `job_id` int(10) unsigned NOT NULL auto_increment,
  `initial_request` text,
  `job_name` varchar(100) default NULL,
  `job_env` text,
  `job_type` enum('INTERACTIVE','PASSIVE') NOT NULL default 'PASSIVE',
  `info_type` varchar(255) default NULL,
  `state` enum('Waiting','Hold','toLaunch','toError','toAckReservation','Launching','Running','Suspended','Resuming','Finishing','Terminated','Error') NOT NULL,
  `reservation` enum('None','toSchedule','Scheduled') NOT NULL default 'None',
  `message` varchar(255) NOT NULL,
  `scheduler_info` varchar(255) NOT NULL,
  `job_user` varchar(255) NOT NULL,
  `project` varchar(255) NOT NULL,
  `job_group` varchar(255) NOT NULL,
  `command` text,
  `exit_code` int(11) default NULL,
  `queue_name` varchar(100) NOT NULL,
  `properties` text,
  `launching_directory` text NOT NULL,
  `submission_time` int(10) unsigned NOT NULL,
  `start_time` int(10) unsigned NOT NULL,
  `stop_time` int(10) unsigned NOT NULL,
  `file_id` int(10) unsigned default NULL,
  `accounted` enum('YES','NO') NOT NULL default 'NO',
  `notify` varchar(255) default NULL,
  `assigned_moldable_job` int(10) unsigned default '0',
  `checkpoint` int(10) unsigned NOT NULL default '0',
  `checkpoint_signal` int(11) NOT NULL,
  `stdout_file` text,
  `stderr_file` text,
  `resubmit_job_id` int(10) unsigned default '0',
  `suspended` enum('YES','NO') NOT NULL default 'NO',
  PRIMARY KEY  (`job_id`),
  KEY `state` (`state`),
  KEY `state_id` (`state`,`job_id`),
  KEY `reservation` (`reservation`),
  KEY `queue_name` (`queue_name`),
  KEY `accounted` (`accounted`),
  KEY `suspended` (`suspended`)
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `jobs`
--

LOCK TABLES `jobs` WRITE;
/*!40000 ALTER TABLE `jobs` DISABLE KEYS */;
INSERT INTO `jobs` VALUES (1,'oarsub -r 2008-10-09 20:00:00 -l nodes=3',NULL,NULL,'INTERACTIVE','grelon-41.nancy.grid5000.fr:43469','Waiting','Scheduled','','','pneyron','default','','',NULL,'default','desktop_computing = \'NO\'','/home/grenoble/pneyron',1223567218,1223575200,0,NULL,'NO',NULL,0,0,12,'OAR.%jobid%.stdout','OAR.%jobid%.stderr',0,'NO');
/*!40000 ALTER TABLE `jobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `moldable_job_descriptions`
--

DROP TABLE IF EXISTS `moldable_job_descriptions`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `moldable_job_descriptions` (
  `moldable_id` int(10) unsigned NOT NULL auto_increment,
  `moldable_job_id` int(10) unsigned NOT NULL,
  `moldable_walltime` int(10) unsigned NOT NULL,
  `moldable_index` enum('CURRENT','LOG') NOT NULL default 'CURRENT',
  PRIMARY KEY  (`moldable_id`),
  KEY `job` (`moldable_job_id`),
  KEY `log` (`moldable_index`)
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `moldable_job_descriptions`
--

LOCK TABLES `moldable_job_descriptions` WRITE;
/*!40000 ALTER TABLE `moldable_job_descriptions` DISABLE KEYS */;
INSERT INTO `moldable_job_descriptions` VALUES (1,1,7200,'CURRENT');
/*!40000 ALTER TABLE `moldable_job_descriptions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `queues`
--

DROP TABLE IF EXISTS `queues`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `queues` (
  `queue_name` varchar(100) NOT NULL,
  `priority` int(10) unsigned NOT NULL,
  `scheduler_policy` varchar(100) NOT NULL,
  `state` enum('Active','notActive') NOT NULL default 'Active',
  PRIMARY KEY  (`queue_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `queues`
--

LOCK TABLES `queues` WRITE;
/*!40000 ALTER TABLE `queues` DISABLE KEYS */;
INSERT INTO `queues` VALUES ('admin',10,'oar_sched_gantt_with_timesharing','Active'),('default',2,'oar_sched_gantt_with_timesharing','Active'),('besteffort',0,'oar_sched_gantt_with_timesharing','Active');
/*!40000 ALTER TABLE `queues` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `resource_logs`
--

DROP TABLE IF EXISTS `resource_logs`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `resource_logs` (
  `resource_log_id` int(10) unsigned NOT NULL auto_increment,
  `resource_id` int(10) unsigned NOT NULL,
  `attribute` varchar(255) NOT NULL,
  `value` varchar(255) NOT NULL,
  `date_start` int(10) unsigned NOT NULL,
  `date_stop` int(10) unsigned default '0',
  `finaud_decision` enum('YES','NO') NOT NULL default 'NO',
  PRIMARY KEY  (`resource_log_id`),
  KEY `resource` (`resource_id`),
  KEY `attribute` (`attribute`),
  KEY `finaud` (`finaud_decision`),
  KEY `val` (`value`)
) ENGINE=MyISAM AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `resource_logs`
--

LOCK TABLES `resource_logs` WRITE;
/*!40000 ALTER TABLE `resource_logs` DISABLE KEYS */;
INSERT INTO `resource_logs` VALUES (1,1,'state','Alive',1223566377,0,'NO'),(2,2,'state','Alive',1223566380,0,'NO'),(3,3,'state','Alive',1223566381,0,'NO');
/*!40000 ALTER TABLE `resource_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `resources`
--

DROP TABLE IF EXISTS `resources`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `resources` (
  `resource_id` int(10) unsigned NOT NULL auto_increment,
  `type` varchar(100) NOT NULL default 'default',
  `network_address` varchar(100) NOT NULL,
  `state` enum('Alive','Dead','Suspected','Absent') NOT NULL,
  `next_state` enum('UnChanged','Alive','Dead','Absent','Suspected') NOT NULL default 'UnChanged',
  `finaud_decision` enum('YES','NO') NOT NULL default 'NO',
  `next_finaud_decision` enum('YES','NO') NOT NULL default 'NO',
  `state_num` int(11) NOT NULL default '0',
  `suspended_jobs` enum('YES','NO') NOT NULL default 'NO',
  `scheduler_priority` int(10) unsigned NOT NULL default '0',
  `cpuset` int(10) unsigned NOT NULL default '0',
  `besteffort` enum('YES','NO') NOT NULL default 'YES',
  `deploy` enum('YES','NO') NOT NULL default 'NO',
  `expiry_date` int(10) unsigned NOT NULL,
  `desktop_computing` enum('YES','NO') NOT NULL default 'NO',
  `last_job_date` int(10) unsigned default '0',
  `available_upto` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`resource_id`),
  KEY `state` (`state`),
  KEY `next_state` (`next_state`),
  KEY `suspended_jobs` (`suspended_jobs`),
  KEY `type` (`type`),
  KEY `network_address` (`network_address`)
) ENGINE=MyISAM AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `resources`
--

LOCK TABLES `resources` WRITE;
/*!40000 ALTER TABLE `resources` DISABLE KEYS */;
INSERT INTO `resources` VALUES (1,'default','127.0.2.1','Alive','Dead','NO','NO',1,'NO',0,0,'YES','NO',0,'NO',0,0),(2,'default','127.0.2.2','Alive','UnChanged','NO','NO',1,'NO',0,0,'YES','NO',0,'NO',0,0),(3,'default','127.0.2.3','Alive','UnChanged','NO','NO',1,'NO',0,0,'YES','NO',0,'NO',0,0);
/*!40000 ALTER TABLE `resources` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `schema`
--

DROP TABLE IF EXISTS `schema`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `schema` (
  `version` varchar(255) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `schema`
--

LOCK TABLES `schema` WRITE;
/*!40000 ALTER TABLE `schema` DISABLE KEYS */;
INSERT INTO `schema` VALUES ('2.3.0+svn1369');
/*!40000 ALTER TABLE `schema` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2008-10-09 15:50:05
