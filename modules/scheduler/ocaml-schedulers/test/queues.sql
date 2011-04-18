-- phpMyAdmin SQL Dump
-- version 2.11.8.1deb1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Dec 23, 2008 at 10:33 AM
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
-- Table structure for table `queues`
--
DROP TABLE IF EXISTS `queues`;
CREATE TABLE IF NOT EXISTS `queues` (
  `queue_name` varchar(100) NOT NULL,
  `priority` int(10) unsigned NOT NULL,
  `scheduler_policy` varchar(100) NOT NULL,
  `state` enum('Active','notActive') NOT NULL default 'Active',
  PRIMARY KEY  (`queue_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `queues`
--

INSERT INTO `queues` (`queue_name`, `priority`, `scheduler_policy`, `state`) VALUES
('admin', 10, 'oar_sched_gantt_with_timesharing', 'Active'),
('default', 2, 'oar_sched_gantt_with_timesharing', 'Active'),
('besteffort', 0, 'oar_sched_gantt_with_timesharing', 'Active');
