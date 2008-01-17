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
This script has to be launched on the DB server itself.
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
system("sudo -u postgres psql -c \"CREATE ROLE $userName LOGIN PASSWORD \'$password\'\"");

print "Please enter the information of the read only user you want to create:\n";
print "\tread only user name: ";
my $ro_userName = <STDIN>;
chomp $ro_userName;
print "\tread only password: ";
system("tty &> /dev/null && stty -echo");
my $ro_password = <STDIN>;
chomp $ro_password;
print("\n");
system("tty &> /dev/null && stty echo");
system("sudo -u postgres psql -c \"CREATE ROLE $ro_userName LOGIN PASSWORD \'$ro_password\'\"");

print "Please enter the path to the script that fills the DB (default: ./oar_postgres.sql):\n";
print "\tpath: ";
my $sqlFile = <STDIN>;
chomp $sqlFile;
if (-r $sqlFile){
	system("psql -U$userName -h 127.0.0.1 -d$dbName -f$sqlFile");
	if ($? != 0){
		die("[ERROR] this command aborted : psql -U$userName -h 127.0.0.1 -d$dbName -f$sqlFile ; \$?=$?, $! \n");
	}
}else{
	die("[ERROR] Database installation : can't open $sqlFile \n");
}

system("sudo -u postgres psql oar -c \"GRANT ALL PRIVILEGES ON accounting,admission_rules,assigned_resources,challenges,event_log_hostnames,event_logs,files,frag_jobs,gantt_jobs_predictions,gantt_jobs_predictions_visu,gantt_jobs_resources,gantt_jobs_resources_visu,job_dependencies,job_resource_descriptions,job_resource_groups,job_state_logs,job_types,jobs,moldable_job_descriptions,queues,resource_logs,resources,admission_rules_id_seq,event_logs_event_id_seq,files_file_id_seq,job_resource_groups_res_group_id_seq,job_state_logs_job_state_log_id_seq,job_types_job_type_id_seq,moldable_job_descriptions_moldable_id_seq,resource_logs_resource_log_id_seq,resources_resource_id_seq,jobs_job_id_seq TO oar;\"");
system("sudo -u postgres psql oar -c \"GRANT SELECT ON accounting,admission_rules,assigned_resources,event_log_hostnames,event_logs,files,frag_jobs,gantt_jobs_predictions,gantt_jobs_predictions_visu,gantt_jobs_resources,gantt_jobs_resources_visu,job_dependencies,job_resource_descriptions,job_resource_groups,job_state_logs,job_types,jobs,moldable_job_descriptions,queues,resource_logs,resources,admission_rules_id_seq,event_logs_event_id_seq,files_file_id_seq,job_resource_groups_res_group_id_seq,job_state_logs_job_state_log_id_seq,job_types_job_type_id_seq,moldable_job_descriptions_moldable_id_seq,resource_logs_resource_log_id_seq,resources_resource_id_seq,jobs_job_id_seq TO oar_ro;\"");

print("\nTERMINATED\n");

