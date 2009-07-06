-- phpMyAdmin SQL Dump
-- version 2.11.8.1deb1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Dec 23, 2008 at 10:31 AM
-- Server version: 5.0.67
-- PHP Version: 5.2.6-2ubuntu4

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `oar`
--

-- --------------------------------------------------------

--
-- Table structure for table `resources`
--

DROP TABLE IF EXISTS `resources`;
CREATE TABLE IF NOT EXISTS `resources` (
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
  `switch` varchar(50) NOT NULL default '0',
  `cpu` int(10) unsigned NOT NULL default '0',
  `cpuset` int(10) unsigned NOT NULL default '0',
  `besteffort` enum('YES','NO') NOT NULL default 'YES',
  `deploy` enum('YES','NO') NOT NULL default 'NO',
  `expiry_date` int(10) unsigned NOT NULL,
  `desktop_computing` enum('YES','NO') NOT NULL default 'NO',
  `last_job_date` int(10) unsigned default '0',
  `available_upto` int(10) unsigned NOT NULL default '0',
  `mem` int(10) unsigned NOT NULL default '0',
  `model` tinytext NOT NULL,
  `serial` tinytext NOT NULL,
  `eth0` char(17) NOT NULL,
  `eth1` char(17) NOT NULL,
  `eth2` char(17) NOT NULL,
  `eth3` char(17) NOT NULL,
  `IP_public` char(15) NOT NULL default '0.0.0.0',
  `IP_private` char(15) NOT NULL default '0.0.0.0',
  `managedBy` mediumint(8) unsigned NOT NULL,
  `city` tinytext NOT NULL,
  `isp` tinytext NOT NULL,
  `box` tinytext NOT NULL,
  `atype` enum('adsl','cable','fiber','lab','') NOT NULL,
  `person` mediumint(8) unsigned NOT NULL,
  `wakeup_1` char(5) default NULL,
  `wakeup_2` char(5) default NULL,
  `wakeup_3` char(5) default NULL,
  `wakeup_4` char(5) default NULL,
  PRIMARY KEY  (`resource_id`),
  KEY `state` (`state`),
  KEY `next_state` (`next_state`),
  KEY `suspended_jobs` (`suspended_jobs`),
  KEY `type` (`type`),
  KEY `network_address` (`network_address`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=41 ;

--
-- Dumping data for table `resources`
--

INSERT INTO `resources` (`resource_id`, `type`, `network_address`, `state`, `next_state`, `finaud_decision`, `next_finaud_decision`, `state_num`, `suspended_jobs`, `scheduler_priority`, `switch`, `cpu`, `cpuset`, `besteffort`, `deploy`, `expiry_date`, `desktop_computing`, `last_job_date`, `available_upto`, `mem`, `model`, `serial`, `eth0`, `eth1`, `eth2`, `eth3`, `IP_public`, `IP_private`, `managedBy`, `city`, `isp`, `box`, `atype`, `person`, `wakeup_1`, `wakeup_2`, `wakeup_3`, `wakeup_4`) VALUES
(1, 'default', 'dsl00', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 1, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000007', '00:30:18:4A:63:5F', '00:30:18:4A:63:5E', '00:30:18:4A:63:5D', '00:30:18:4A:63:5C', '82.228.144.32', '0.0.0.0', 1, '', '', '', 'adsl', 1, 'alway', NULL, NULL, NULL),
(2, 'default', 'dsl01', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 2, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000008', '00:30:18:4A:63:63', '00:30:18:4A:63:62', '00:30:18:4A:63:61', '00:30:18:4A:63:60', '82.236.229.116', '0.0.0.0', 1, '', '', '', 'adsl', 8, '9:00', NULL, 'alway', NULL),
(3, 'default', 'dsl02', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 3, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '705000027', '00:30:18:4A:25:A1', '00:30:18:4A:25:A0', '00:30:18:4A:25:9F', '00:30:18:4A:25:9E', '193.55.47.3', '0.0.0.0', 3, '', '', '', 'adsl', 0, '10:25', '12:00', '13:00', NULL),
(4, 'default', 'dsl03', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 4, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '705000028', '00:30:18:4A:25:C1', '00:30:18:4A:25:C0', '00:30:18:4A:25:BF', '00:30:18:4A:25:BE', '193.55.47.3', '0.0.0.0', 3, '', '', '', 'adsl', 10, '9:00', NULL, NULL, NULL),
(5, 'default', 'dsl04', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 5, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000011', '', '', '', '', '76.114.67.139', '0.0.0.0', 1, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(6, 'default', 'dsl05', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 6, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '', '', '', '', '', '0.0.0.0', '0.0.0.0', 1, '', '', '', 'adsl', 13, '9:00', NULL, NULL, NULL),
(7, 'default', 'dsl06', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 7, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000012', '00:30:18:4A:63:6F', '00:30:18:4A:63:6E', '00:30:18:4A:63:6D', '00:30:18:4A:63:6C', '82.244.180.88', '0.0.0.0', 1, '', '', '', 'adsl', 9, '9:00', NULL, NULL, NULL),
(8, 'default', 'dsl07', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 8, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '', '00:30:18:4A:24:AD', '00:30:18:4A:24:AC', '00:30:18:4A:24:AB', '00:30:18:4A:24:AA', '129.175.7.241', '0.0.0.0', 1, '', '', '', 'adsl', 1, '9:00', NULL, NULL, NULL),
(9, 'default', 'dsl08', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 9, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000025', '', '', '', '', '0.0.0.0', '0.0.0.0', 2, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(10, 'default', 'dsl09', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 10, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000026', '', '', '', '', '0.0.0.0', '0.0.0.0', 2, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(11, 'default', 'dsl10', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 11, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000004', '00:30:18:4A:64:23', '00:30:18:4A:64:22', '00:30:18:4A:64:21', '00:30:18:4A:64:20', '82.239.215.183', '0.0.0.0', 1, '', '', '', 'adsl', 14, '9:00', NULL, NULL, NULL),
(12, 'default', 'dsl11', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 12, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000003', '00:30:18:4A:63:5B', '00:30:18:4A:63:5A', '00:30:18:4A:63:59', '00:30:18:4A:63:58', '82.242.15.177', '0.0.0.0', 1, '', '', '', 'adsl', 2, '9:00', NULL, NULL, NULL),
(13, 'default', 'dsl12', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 13, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000024', '00:30:18:4A:63:83', '00:30:18:4A:63:82', '00:30:18:4A:63:81', '00:30:18:4A:63:80', '88.162.230.67', '0.0.0.0', 1, '', '', '', 'adsl', 15, '9:00', NULL, NULL, NULL),
(14, 'default', 'dsl13', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 14, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000023', '00:30:18:4A:63:7F', '00:30:18:4A:63:7E', '00:30:18:4A:63:7D', '00:30:18:4A:63:7C', '90.61.228.12', '0.0.0.0', 1, '', '', '', 'adsl', 16, '9:00', NULL, NULL, NULL),
(15, 'default', 'dsl14', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 15, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000014', '00:30:18:4A:64:5F', '00:30:18:4A:64:5E', '00:30:18:4A:64:5D', '00:30:18:4A:64:5C', '80.170.107.5', '0.0.0.0', 3, '', '', '', 'adsl', 10, '9:00', NULL, NULL, NULL),
(16, 'default', 'dsl15', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 16, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000013', '', '', '', '', '0.0.0.0', '0.0.0.0', 2, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(17, 'default', 'dsl16', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 17, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '705000034', '00:30:18:4A:3A:AA', '00:30:18:4A:3A:A9', '00:30:18:4A:3A:A8', '00:30:18:4A:3A:A7', '82.247.152.123', '0.0.0.0', 1, '', '', '', 'adsl', 20, '9:00', NULL, NULL, NULL),
(18, 'default', 'dsl17', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 18, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000007', '', '', '', '', '0.0.0.0', '0.0.0.0', 2, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(19, 'default', 'dsl18', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 19, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000018', '', '', '', '', '0.0.0.0', '0.0.0.0', 2, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(20, 'default', 'dsl19', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 20, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000006', '00:30:18:4A:63:57', '00:30:18:4A:63:56', '00:30:18:4A:63:55', '00:30:18:4A:63:54', '193.55.47.3', '0.0.0.0', 3, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(21, 'default', 'dsl20', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 21, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000005', '00:30:18:4A:64:27', '00:30:18:4A:64:26', '00:30:18:4A:64:25', '00:30:18:4A:64:24', '193.55.47.3', '0.0.0.0', 3, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(22, 'default', 'dsl21', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 22, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '704000088', '00:30:18:4A:25:09', '00:30:18:4A:25:08', '00:30:18:4A:25:07', '00:30:18:4A:25:06', '193.55.47.3', '0.0.0.0', 3, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(23, 'default', 'dsl22', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 23, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '704000087', '00:30:18:4A:25:11', '00:30:18:4A:25:10', '00:30:18:4A:25:0F', '00:30:18:4A:25:0E', '193.55.47.3', '0.0.0.0', 3, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(24, 'default', 'dsl23', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 24, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '704000058', '00:30:18:49:F7:8D', '00:30:18:49:F7:8C', '00:30:18:49:F7:8B', '00:30:18:49:F7:8A', '193.55.47.3', '0.0.0.0', 3, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(25, 'default', 'dsl24', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 25, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '704000057', '00:30:18:49:F6:E1', '00:30:18:49:F6:E0', '00:30:18:49:F6:DF', '00:30:18:49:F6:DE', '193.55.47.3', '0.0.0.0', 3, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(26, 'default', 'dsl25', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 26, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000016', '00:30:18:4A:64:5B', '00:30:18:4A:64:5A', '00:30:18:4A:64:59', '00:30:18:4A:64:58', '193.55.47.3', '0.0.0.0', 3, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(27, 'default', 'dsl26', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 27, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000015', '00:30:18:4A:63:73', '00:30:18:4A:63:72', '00:30:18:4A:63:71', '00:30:18:4A:63:70', '193.55.47.3', '0.0.0.0', 3, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(28, 'default', 'dsl27', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 28, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '705000002', '00:30:18:4A:26:09', '00:30:18:4A:26:08', '00:30:18:4A:26:07', '00:30:18:4A:26:06', '0.0.0.0', '0.0.0.0', 1, '', '', '', 'adsl', 2, '9:00', NULL, NULL, NULL),
(29, 'default', 'dsl28', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 29, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '705000001', '00:30:18:4A:25:C9', '00:30:18:4A:25:C8', '00:30:18:4A:25:C7', '00:30:18:4A:25:C6', '88.178.9.138', '0.0.0.0', 1, '', '', '', 'adsl', 3, '9:00', NULL, NULL, NULL),
(30, 'default', 'dsl29', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 30, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '', '', '', '', '', '88.162.203.163', '0.0.0.0', 1, '', '', '', 'adsl', 17, '9:00', NULL, NULL, NULL),
(31, 'default', 'dsl30', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 31, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '', '', '', '', '', '88.165.218.159', '0.0.0.0', 1, '', '', '', 'adsl', 18, '9:00', NULL, NULL, NULL),
(32, 'default', 'dsl31', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 32, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '', '', '', '', '', '0.0.0.0', '0.0.0.0', 1, '', '', '', 'adsl', 19, '9:00', NULL, NULL, NULL),
(33, 'default', 'dsl32', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 33, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '', '', '', '', '', '0.0.0.0', '0.0.0.0', 1, '', '', '', 'adsl', 23, '9:00', NULL, NULL, NULL),
(34, 'default', 'dsl33', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 34, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000010', '00:30:18:4A:63:93', '00:30:18:4A:63:92', '00:30:18:4A:63:91', '00:30:18:4A:63:90', '82.231.159.87', '0.0.0.0', 1, '', '', '', 'adsl', 21, '9:00', NULL, NULL, NULL),
(35, 'default', 'dsl34', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 35, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '705000046', '', '', '', '', '0.0.0.0', '0.0.0.0', 2, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(36, 'default', 'dsl35', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 36, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '705000045', '', '', '', '', '0.0.0.0', '0.0.0.0', 2, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(37, 'default', 'dsl36', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 37, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000022', '00:30:18:4A:64:6F', '00:30:18:4A:64:6E', '00:30:18:4A:64:6D', '00:30:18:4A:64:6C', '90.144.35.98', '0.0.0.0', 1, '', '', '', 'adsl', 16, '9:00', NULL, NULL, NULL),
(38, 'default', 'dsl37', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 38, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000021', '00:30:18:4A:63:7B', '00:30:18:4A:63:7A', '00:30:18:4A:63:79', '00:30:18:4A:63:78', '0.0.0.0', '0.0.0.0', 1, '', '', '', 'adsl', 22, '9:00', NULL, NULL, NULL),
(39, 'default', 'dsl38', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 39, 0, 'YES', 'YES', 0, 'NO', 1230018558, 0, 0, 'NE2208-9670', '708000001', '', '', '', '', '0.0.0.0', '0.0.0.0', 2, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL),
(40, 'default', 'dsl39', 'Alive', 'UnChanged', 'YES', 'NO', 3, 'NO', 0, '0', 40, 0, 'YES', 'YES', 0, 'NO', 1230018882, 0, 0, 'NE2208-9670', '708000002', '', '', '', '', '0.0.0.0', '0.0.0.0', 2, '', '', '', 'adsl', 0, '9:00', NULL, NULL, NULL);
