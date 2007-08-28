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
Setup the database used by OAR
Options:
 -h, --help        show this help screen
EOS
    exit(0);
}


#my $usrName = getpwuid($<);
# test user name
#("$usrName" eq "root") or die "[ERROR] You must be root to run this script\n";

# use the oar_jobs.sql file to create the database
my $mysqlFile = $ENV{'OARDIR'}.'/oar_jobs.sql';
print "Using $mysqlFile for the database creation\n";
( -r $mysqlFile ) or die "[ERROR] Initialization SQL file not found ($mysqlFile)\n";

init_conf($ENV{OARCONFFILE});
my $dbHost = get_conf("DB_HOSTNAME");
my $dbName = get_conf("DB_BASE_NAME");
my $dbUserName = get_conf("DB_BASE_LOGIN");
my $dbUserPassword = get_conf("DB_BASE_PASSWD");

print "## Initializing OAR MySQL database ##\n";
print "Retrieving OAR base configuration for OAR configuration file:\n";
print "\tMySQL server hostname: $dbHost\n";
print "\tOAR base name: $dbName\n";
print "\tOAR base login: $dbUserName\n";

$| = 1;
# DataBase login
print "Please enter MySQL admin login information:\n";
print "\tAdmin login: ";
my $dbLogin = <STDIN>;
chomp $dbLogin;
# DataBase password or the dbLogin
print "\tAdmin password: ";
system("tty &> /dev/null && stty -echo");
my $dbPassword = <STDIN>;
chomp $dbPassword;
print("\n");
system("tty &> /dev/null && stty echo");

# Connect to the database.
my $dbh = DBI->connect("DBI:mysql:database=mysql;host=$dbHost", $dbLogin, $dbPassword, {'RaiseError' => 0});
my $query;
# Database creation
$dbh->do("CREATE DATABASE IF NOT EXISTS $dbName") or die $dbh->errstr;

# Grant user the basic privileges
$dbh->do('GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER ON '.$dbName.'.* TO '.$dbUserName.'@localhost IDENTIFIED BY "'.$dbUserPassword.'"') or die $dbh->errstr;

$dbh->do('GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER ON '.$dbName.'.* TO '.$dbUserName.'@"%" IDENTIFIED BY "'.$dbUserPassword.'"') or die $dbh->errstr;

# Grant user some more privileges, wrt the new version of mysql
$dbh->do('GRANT CREATE TEMPORARY TABLES, LOCK TABLES ON '.$dbName.'.* TO '.$dbUserName.'@localhost') and $dbh->do('GRANT CREATE TEMPORARY TABLES, LOCK TABLES ON '.$dbName.'.* TO '.$dbUserName.'@"%"') or warn "* CREATE TEMPORARY TABLES and LOCK TABLES privileges seems not supported by your mysql server, please ignore this error in that case.\n";

$dbh->disconnect();

# Connection to the oar database with oar user
$dbh = DBI->connect("DBI:mysql:database=$dbName;host=$dbHost", $dbLogin, $dbPassword, {'RaiseError' => 1});

if (-r $mysqlFile){
	system("mysql -u$dbLogin -p$dbPassword -h$dbHost -D$dbName < $mysqlFile");
	if ($? != 0){
		die("[ERROR] this command aborted : mysql -u$dbLogin -p$dbPassword -h$dbHost -D$dbName < $mysqlFile; \$?=$?, $! \n");
	}
}else{
	die("[ERROR] Database installation : can't open $mysqlFile \n");
}
$dbh->disconnect();
print "done.\n";
