#!/usr/bin/perl

BEGIN{
    $ENV{PERL5LIB} = $ENV{PERL5LIB}.":".$ENV{OARLIB};
}

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

init_conf("oar.conf");
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
# Database build
$query = $dbh->prepare("CREATE DATABASE IF NOT EXISTS $dbName") or die $dbh->errstr;
$query->execute();
# Add oar user
# Test if this user already exists
$query = $dbh->prepare("SELECT * FROM user WHERE User=\"".$dbUserName."\" and (Host=\"localhost\" or Host=\"%\")");
$query->execute();
if (! $query->fetchrow_hashref()){
	$query = $dbh->prepare("INSERT INTO user (Host,User,Password) VALUES('localhost','".$dbUserName."',PASSWORD('".$dbUserPassword."'))") or die $dbh->errstr;
	$query->execute();

	$query = $dbh->prepare("INSERT INTO user (Host,User,Password) VALUES('%','".$dbUserName."',PASSWORD('".$dbUserPassword."'))") or die $dbh->errstr;
	$query->execute();

	my $rightError = 0;

	$dbh->do("INSERT INTO db (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv,Create_tmp_table_priv,Lock_tables_priv) VALUES ('localhost','".$dbName."','".$dbUserName."','Y','Y','Y','Y','Y','Y','Y','Y')") or $rightError = 1;

	if ($rightError == 1){
		print("--- not enough rights; it is not a bug, it is a feature ---\n");
		# the properties  Create_tmp_table_priv and Lock_tables_priv dose not exist
		$dbh->do("INSERT INTO db (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) VALUES ('localhost','".$dbName."','".$dbUserName."','Y','Y','Y','Y','Y','Y')") or die $dbh->errstr;
		$dbh->do("INSERT INTO db (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) VALUES ('%','".$dbName."','".$dbUserName."','Y','Y','Y','Y','Y','Y')") or die $dbh->errstr;
	}else{
		$dbh->do("INSERT INTO db (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv,Create_tmp_table_priv,Lock_tables_priv) VALUES ('%','".$dbName."','".$dbUserName."','Y','Y','Y','Y','Y','Y','Y','Y')") or $rightError = 1;
	}

	$query = $dbh->prepare("FLUSH PRIVILEGES") or die $dbh->errstr;
	$query->execute();
}else{
	print("Warning: the database user is already created.\n");
}

# Grant user
$query = $dbh->prepare("GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON ".$dbName.".* TO ".$dbUserName."\@localhost") or die $dbh->errstr;
$query->execute();

$query = $dbh->prepare("GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON ".$dbName.".* TO ".$dbUserName."@\"%\"") or die $dbh->errstr;
$query->execute();

$query = $dbh->prepare("FLUSH PRIVILEGES") or die $dbh->errstr;
$query->execute();

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
