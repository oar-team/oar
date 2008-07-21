# This is the libdb subclass for mysql databases.

package libdb_mysql;
use strict;
use warnings;

use libdb;

### GLOBAL VARIABLES DECLARATION ###
# @ISA is the superclasses table, used for heritage
our @ISA = ("libdb");

# our object
our $self;
### END GLOBAL VARIABLES DECLARATION ###

### METHODS ###
# instance()
# this method calls the SUPER::instance method setting the database type to 'mysql'
sub instance() {
    unless (defined $self) {
	    my $class = shift;
	    my $params = shift;
	    $params->{'db_type'} = 'mysql';
		$self = $class->SUPER::instance($params);
		bless ($self, $class);       
    }
    return $self;
}

### LOCK FUNCTIONS ###

# get_lock
# lock a sql mutex variable
# parameters : mutex, timeout
# return value : 1 if the lock was obtained successfully, 0 if the attempt timed out or undef if an error occurred  
# side effects : a second get_lock of the same mutex will be blocked until release_lock is called on the mutex
sub get_lock($$) {
    my $mutex = shift;
    my $timeout = shift;

    my $dbh = $self->{connection};
    my $sth = $dbh->prepare("SELECT GET_LOCK(\"$mutex\",$timeout)");
    $sth->execute();
    my ($res) = $sth->fetchrow_array();
    $sth->finish();
	if ($res eq "0") {
        return 0;
    } elsif ($res eq "1") {
        return 1;
    }
    
    return undef;
}

# release_lock
# unlock a sql mutex variable
# parameters : mutex
# return value : 1 if the lock was released, 0 if the lock wasn't locked by this thread , and NULL if the named lock didn't exist
# side effects : unlock the mutex, a blocked get_lock may be unblocked
sub release_lock($) {
    my $mutex = shift;

	my $dbh = $self->{connection};
    my $sth = $dbh->prepare("SELECT RELEASE_LOCK(\"$mutex\")");
    $sth->execute();
    my ($res) = $sth->fetchrow_array();
    $sth->finish();
	if ($res eq "0") {
        return 0;
    } elsif ($res eq "1") {
        return 1;
    }
    
    return undef;
}

# lock_tables
# creates a sql lock on the tables given in param.
# params: tables to lock
sub lock_tables($) {
    my $tables= shift;

    my $str = "LOCK TABLE ";
    foreach my $t (@{$tables}){
        $str .= "$t WRITE,";
    }
    chop($str);
    $self->{'connection'}->do($str);
}

# unlock_tables
# removes the sql lock of the tables.
# params: none
sub unlock_tables(){
    $self->{'connection'}->do("UNLOCK TABLE");
}

### END LOCK FUNCTIONS ###


1;
