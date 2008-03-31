#!/usr/bin/perl
# $Id$
#

use strict;
use warnings;
use DBI;
use oar_conflib qw(init_conf get_conf is_conf);
use File::Basename;
use Getopt::Long;

Getopt::Long::Configure ("gnu_getopt");
my $usage;
GetOptions ("help|h"  => \$usage);

if ($usage){
    print <<EOS;
Usage: $0 [-h|--help]
Fills the database used by OAR
Options:
 -h, --help        show this help screen
EOS
    exit(0);
}

my $binpath;
my $conffile;

if (defined($ENV{OARDIR})){
    $binpath = $ENV{OARDIR}."/";
}else{
    $binpath = '/usr/local/oar/';
}
if (defined($ENV{OARCONFFILE})){
    $conffile = $ENV{OARCONFFILE};
}else{
    $conffile = '/etc/oar/oar.conf';
}


# use the pg_structure.sql file to create the database
my $sqlFile = $binpath.'pg_structure.sql';
my $admission_rules_file = $binpath.'pg_default_admission_rules.sql';
my $default_data = $binpath.'default_data.sql';
( -r $sqlFile ) or die "[ERROR] Initialization SQL file not found ($sqlFile)\n";

init_conf($conffile);
my $dbHost = get_conf("DB_HOSTNAME");
my $dbPort = get_conf("DB_PORT");
my $dbName = get_conf("DB_BASE_NAME");
my $dbUserName = get_conf("DB_BASE_LOGIN");
my $dbUserPassword = get_conf("DB_BASE_PASSWD");
print "## Initializing OAR Pg database ##\n";
print "Retrieving OAR base configuration for OAR configuration file:\n";
print "\tPg server hostname: $dbHost\n";
print "\tPg server port: $dbPort\n";
print "\tOAR base name: $dbName\n";
print "\tOAR base login: $dbUserName\n";
$| = 1;


if (-r $sqlFile){
	system("psql -U$dbUserName -h$dbHost -P$dbPort -d$dbName -f$sqlFile");
	if ($? != 0){
		die("[ERROR] this command aborted : psql -U$dbUserName -h$dbHost -P$dbPort -d$dbName -f$sqlFile ; \$?=$?, $! \n");
	}
}else{
	die("[ERROR] Database installation : can't open $sqlFile \n");
}
if (-r $admission_rules_file){
	system("psql -U$dbUserName -h$dbHost -P$dbPort -d$dbName -f$admission_rules_file");
	if ($? != 0){
		die("[ERROR] this command aborted : psql -U$dbUserName -h$dbHost -P$dbPort -d$dbName -f$admission_rules_file ; \$?=$?, $! \n");
	}
}
if (-r $default_data){
	system("psql -U$dbUserName -h$dbHost -P$dbPort -d$dbName -f$default_data");
	if ($? != 0){
		die("[ERROR] this command aborted : psql -U$dbUserName -h$dbHost -P$dbPort -d$dbName -f$default_data ; \$?=$?, $! \n");
	}
}
print "done.\n";
