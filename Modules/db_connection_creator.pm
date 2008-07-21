# This class is the temporary layer between the old OAR iolib system amd the new one: libdb
# with this class, you can read from the config file and create a libdb object that contains
# the connection to the database.

package db_connection_creator;

use strict;
use warnings;

use libdb_mysql;
use libdb_Pg;

use oar_conflib qw(init_conf get_conf is_conf reset_conf);

sub init($){
	my $class = shift;
	my $conf_path = shift;
	reset_conf();
	init_conf($conf_path);
	
	my $host = get_conf("DB_HOSTNAME");
	my $dbport = get_conf("DB_PORT");
	my $name = get_conf("DB_BASE_NAME");
	my $user = get_conf("DB_BASE_LOGIN");
	my $pwd = get_conf("DB_BASE_PASSWD");
	my $Db_type = get_conf("DB_TYPE");
	        
	my $params = {
		db_name      => $name,
		host         => $host,
		port         => $dbport,
		user         => $user,
		pwd			 => $pwd
	};
	
	if($Db_type eq 'Pg'){
		return(libdb_Pg->instance($params));
	}
	elsif($Db_type eq 'mysql'){ 
		return(libdb_mysql->instance($params));
	}
	else{
		die "/!\\ DB type not supported."
	}
}


### THE END ###
1;
