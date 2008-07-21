# This is the libdb subclass for postgres databases.

package libdb_Pg;
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
# this method calls the SUPER::instance method setting the database type to 'Pg'
sub instance() {
    unless (defined $self) {
	    my $class = shift;
	    my $params = shift;
	    $params->{'db_type'} = 'Pg';
		$self = $class->SUPER::instance($params);
		bless ($self, $class);       
    }
    return $self;
}

### LOCK FUNCTIONS ###

# get_lock
# lock a sql mutex
sub get_lock() {
    $self->{connection}->begin_work();
}

# release_lock
# unlock a sql mutex
sub release_lock() {
    $self->{connection}->commit();
}

# lock_tables
# creates a sql lock
sub lock_tables($) {
    $self->{'connection'}->begin_work();
}

# unlock_tables
# removes the sql lock
sub unlock_tables() {
    $self->{'connection'}->commit();
}

### END LOCK FUNCTIONS ###

1;
