#!/usr/bin/perl
#

use strict;
use warnings;

use Getopt::Long;

Getopt::Long::Configure ("gnu_getopt");
my $usage;
GetOptions ("help|h"  => \$usage);

if ($usage){
    print <<EOS;
Usage: $0 [-h|--help]
Setup the database used by OAR.
This script has to be launched first on the DB server itself.
Then the oar_pg_db_init script can be launched from anywhere.
Options:
 -h, --help        show this help screen
EOS
    exit(0);
}

my $usrName = getpwuid($<);
# test user name
("$usrName" eq "root") or die "[ERROR] You must be root to run this script\n";

# DataBase name
print "Please enter the name of the DB you want to create:\n";
print "\tDB name: ";
my $dbName = <STDIN>;
chomp $dbName;
system("sudo -u postgres createdb $dbName");

print "Please enter the information of the user you want to create:\n";
print "\tuser name: ";
my $userName = <STDIN>;
chomp $userName;
print "\tpassword: ";
system("tty &> /dev/null && stty -echo");
my $password = <STDIN>;
chomp $password;
print("\n");
system("tty &> /dev/null && stty echo");

system("sudo -u postgres psql -c \"CREATE ROLE $userName CREATEDB LOGIN PASSWORD \'$password\'\"");

print("\nTERMINATED\n");
