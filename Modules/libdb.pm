# This is the database library which manages the layer between the modules and the
# database. This is the only base-dependent layer.
# Its implementation follows the Singleton pattern.
# When adding a new function, the following comments are required before the code of the function:
# - the name of the function
# - a short description of the function
# - the list of the parameters it expect
# - the list of the return values
# - the list of the side effects

package libdb;
use strict;
use warnings;

use Data::Dumper;
use DBI;
use POSIX qw(strftime);
use Time::Local;

### CONFIG STUFF ###
# suitable Data::Dumper configuration for serialization
$Data::Dumper::Purity = 1;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 0;
$Data::Dumper::Deepcopy = 1;

# Log category
# set_current_log_category('main');

### END CONFIG STUFF ###


### BEGIN PROTOTYPES DECLARATION ###
# TIME CONVERSION
sub ymdhms_to_sql;
sub sql_to_ymdhms;
sub ymdhms_to_local;
sub local_to_ymdhms;
sub sql_to_local;
sub local_to_sql;
sub sql_to_hms;
sub hms_to_duration;
sub hms_to_sql;
sub duration_to_hms;
sub duration_to_sql;
sub sql_to_duration;
sub get_date;

# LOCK FUNCTIONS:
sub get_lock;
sub release_lock;
sub lock_tables;
sub unlock_tables;

# QUEUES MANAGEMENT
sub get_active_queues;
sub get_all_queues_information;

### END PROTOTYPES DECLARATION ###


### GLOBAL VARIABLES DECLARATION ###
# our object reference
our $self;

# used for the AUTOLOAD method
our $AUTOLOAD;

# Hash matching states numbers and full name
my %State_to_num = (
    "Alive" => 1,
    "Absent" => 2,
    "Suspected" => 3,
    "Dead" => 4
);

# Duration to add to all jobs when matching the cm_availability resource property field
my $Cm_security_duration = 600;

### END GLOBAL VARIABLES DECLARATION ###


### METHODS ###
# instance()
# this method creates the libdb instance (which contains the connection
# to the database) if called for the first time, or returns the instance itself
# otherwise. (Singleton pattern)
sub instance() {
    unless (defined $self) {
	    my $class = shift;
	    my $params = shift;
	    
	    my $db_type = $params->{'db_type'};
	    my $db_name = $params->{'db_name'};    
	    my $host = $params->{'host'};
	    my $port = $params->{'port'};
	    my $user = $params->{'user'};
	    my $pwd = $params->{'pwd'};

		# we reconstruct the db connection param hash to be sure that is is correct
		my %fields = (
			db_type      => $db_type,
			db_name      => $db_name,
			host         => $host,
			port         => $port,
			user         => $user
    	);
		
		$self  = \%fields;
		bless $self, $class;
				
		my $connection_string = "DBI:$db_type:database=$db_name;host=$host;port=$port;";
	    unless (defined ($self->{'connection'} = DBI->connect($connection_string, $user, $pwd))) {
	        die("Cannot connect to database: $DBI::errstr\n");
	        # return failure;
	        return undef;
	    }        
    }
    return $self;
}

# disconnect()
# Closes the connection to the database and deletes the 
# libdb instance.
sub disconnect() {
    # Disconnect from the database.
    $self->{'connection'}->disconnect();
    $self = undef;
}

# AUTOLOAD
# Called when a method isn't known for an object of this class.
# This is used to create automatic getters/setters for the object
# attributes.
# if a param is given, used as a setter, used as a getter otherwise.
# ie: $object->foo() returns the foo attribute value of $object.
#	  $object->foo("new_value") sets the nez value to the foo attribute. 
sub AUTOLOAD {
	return if $AUTOLOAD =~ /DESTROY/;
	my $self = shift;
	my $type = ref($self) or die "$self is not an object";

	my $name = $AUTOLOAD;
	$name =~ s/.*://;   # strip fully-qualified portion

	unless (exists $self->{$name} ) {
	    die "Can't access `$name' field in class $type";
	}
	else{
		if (@_) {
		    return $self->{$name} = shift;
		} else {
	    	return $self->{$name};
		}
	}
}

### TIME CONVERSION ###

# ymdhms_to_sql
# converts a date specified as year, month, day, minutes, secondes to a string
# in the format used by the sql database
# parameters : year, month, day, hours, minutes, secondes
# return value : date string
# side effects : /
sub ymdhms_to_sql {
	my $class = shift;
    my ($year,$mon,$mday,$hour,$min,$sec)=@_;
    return ($year+1900)."-".($mon+1)."-".$mday." $hour:$min:$sec";
}

# sql_to_ymdhms
# converts a date specified in the format used by the sql database to year,
# month, day, minutes, secondes values
# parameters : date string
# return value : year, month, day, hours, minutes, secondes
# side effects : /
sub sql_to_ymdhms {
	my $class = shift;
    my $date=shift;
    $date =~ tr/-:/  /;
    my ($year,$mon,$mday,$hour,$min,$sec) = split / /,$date;
    # adjustment for localtime (since 1st january 1900, month from 0 to 11)
    $year-=1900;
    $mon-=1;
    return ($year,$mon,$mday,$hour,$min,$sec);
}

# ymdhms_to_local
# converts a date specified as year, month, day, minutes, secondes into an
# integer local time format
# parameters : year, month, day, hours, minutes, secondes
# return value : date integer
# side effects : /
sub ymdhms_to_local {
	my $class = shift;
    my ($year,$mon,$mday,$hour,$min,$sec)=@_;
    return Time::Local::timelocal_nocheck($sec,$min,$hour,$mday,$mon,$year);
}

# local_to_ymdhms
# converts a date specified into an integer local time format to year, month,
# day, minutes, secondes values
# parameters : date integer
# return value : year, month, day, hours, minutes, secondes
# side effects : /
sub local_to_ymdhms {
	my $class = shift;
    my $date=shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($date);
    $year += 1900;
    $mon += 1;
    return ($year,$mon,$mday,$hour,$min,$sec);
}

# sql_to_local
# converts a date specified in the format used by the sql database to an
# integer local time format
# parameters : date string
# return value : date integer
# side effects : /
sub sql_to_local {
	my $class = shift;
    my $date=shift;
    my ($year,$mon,$mday,$hour,$min,$sec)=sql_to_ymdhms($date);
    #if ($year <= 1971){
    #    return(0);
    #}else{
        return ymdhms_to_local($year,$mon,$mday,$hour,$min,$sec);
    #}
}

# local_to_sql
# converts a date specified in an integer local time format to the format used
# by the sql database
# parameters : date integer
# return value : date string
# side effects : /
sub local_to_sql {
	my $class = shift;
    my $local=shift;
    #my ($year,$mon,$mday,$hour,$min,$sec)=local_to_ymdhms($local);
    #return ymdhms_to_sql($year,$mon,$mday,$hour,$min,$sec);
    #return $year."-".$mon."-".$mday." $hour:$min:$sec";
    return(strftime("%F %T",localtime($local)));
}

# sql_to_hms
# converts a date specified in the format used by the sql database to hours,
# minutes, secondes values
# parameters : date string
# return value : hours, minutes, secondes
# side effects : /
sub sql_to_hms {
	my $class = shift;
    my $date=shift;
    my ($hour,$min,$sec) = split /:/,$date;
    return ($hour,$min,$sec);
}

# hms_to_duration
# converts a date specified in hours, minutes, secondes values to a duration
# in seconds
# parameters : hours, minutes, secondes
# return value : duration
# side effects : /
sub hms_to_duration {
	my $class = shift;
    my ($hour,$min,$sec) = @_;
    return $hour*3600 +$min*60 +$sec;
}

# hms_to_sql
# converts a date specified in hours, minutes, secondes values to the format
# used by the sql database
# parameters : hours, minutes, secondes
# return value : date string
# side effects : /
sub hms_to_sql {
	my $class = shift;
    my ($hour,$min,$sec) = @_;
    return "$hour:$min:$sec";
}

# duration_to_hms
# converts a date specified as a duration in seconds to hours, minutes,
# secondes values
# parameters : duration
# return value : hours, minutes, secondes
# side effects : /
sub duration_to_hms {
	my $class = shift;
    my $date=shift;
    my $sec=$date%60;
    $date/=60;
    my $min=$date%60;
    $date = int($date / 60);
    my $hour=$date;
    return ($hour,$min,$sec);
}

# duration_to_sql
# converts a date specified as a duration in seconds to the format used by the
# sql database
# parameters : duration
# return value : date string
# side effects : /
sub duration_to_sql {
	my $class = shift;
    my $duration=shift;
    my ($hour,$min,$sec)=duration_to_hms($duration);
    return hms_to_sql($hour,$min,$sec);
}

# sql_to_duration
# converts a date specified in the format used by the sql database to a
# duration in seconds
# parameters : date string
# return value : duration
# side effects : /
sub sql_to_duration {
	my $class = shift;
    my $date=shift;
    my ($hour,$min,$sec)=sql_to_hms($date);
    return hms_to_duration($hour,$min,$sec);
}

# get_date
# gets the current date from the database
# parameters : none
# return value : hasref containing the date.
# side effects : /
sub get_date {
    my $req = "SELECT UNIX_TIMESTAMP()";
    my $sth = $self->{connection}->prepare($req);
    $sth->execute();
    my @ref = $sth->fetchrow_array();
    $sth->finish();
    return({'date' => int($ref[0])});
}

### END TIME CONVERSION ###

### QUEUES MANAGEMENT ###

# get_active_queues
# create the list of active queues sorted by descending priority.
# return value : a hashtable with the queue names and their scheduling policies
sub get_active_queues {
    my $sth = $self->{'connection'}->prepare("   SELECT queue_name,scheduler_policy
                                FROM queues
                                WHERE
                                    state = \'Active\'
                                ORDER BY priority DESC
                            ");
    $sth->execute();
    
    my %res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        $res{$ref->{queue_name}} = $ref ;
    }
    $sth->finish();
   
    return \%res;
}


# get_all_queue_informations
# return a hashtable with all queues and their properties
sub get_all_queues_information{

    my $sth = $self->{'connection'}->prepare(" SELECT *
                              FROM queues
                            ");
    $sth->execute();
    my %res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        $res{$ref->{queue_name}} = $ref ;
    }
    $sth->finish();
   
    return \%res;
}


# stop_all_queues
sub stop_all_queues {
    $self->{'connection'}->do("  UPDATE queues
                SET state = \'notActive\'
             ");
}

# start_all_queues
sub start_all_queues {
    $self->{'connection'}->do("  UPDATE queues
                SET state = \'Active\'
             ");
}

# stop_a_queue
sub stop_a_queue {
	my $class = shift;
    my $queue = shift;   
    $self->{'connection'}->do("  UPDATE queues
                SET state = \'notActive\'
                WHERE
                    queue_name = \'$queue\'
             ");
}

# start_a_queue
sub start_a_queue {
	my $class = shift;	
    my $queue = shift;
    $self->{'connection'}->do("  UPDATE queues
                SET state = \'Active\'
                WHERE
                    queue_name = \'$queue\'
             ");
}

# delete a queue
sub delete_a_queue {
	my $class = shift;
    my $queue = shift;   
    $self->{'connection'}->do("DELETE FROM queues WHERE queue_name = \'$queue\'");
}

# create a queue
sub create_a_queue {
	my $class = shift;
    my $queue = shift;
    my $policy = shift;
    my $priority = shift;
    
    $self->{'connection'}->do("  INSERT INTO queues (queue_name,priority,scheduler_policy)
                VALUES (\'$queue\',$priority,\'$policy\')");
}

### THE END ###
1;
