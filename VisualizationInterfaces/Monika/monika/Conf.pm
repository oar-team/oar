## Modified on November 2007 by Joseph.Emeras@imag.fr
## added: OAR2 compatibility
##        added 4 parameters to acces OAR2 DB: hostname, dbname, username, password

## This package handles monika.conf file.
## it uses ConfNode.pm to store nodes description got from the configuration file.
package monika::Conf;

use strict;
use warnings;
use AppConfig qw(:expand :argcount);
use monika::ConfNode;

## class constructor
my $myself;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  $self->{ALLNODES} = {};
  bless ($self, $class);
  $myself = $self;
  return $self;
}

sub myself () {
  defined $myself or die "do first a new and parse please...";
  return $myself;
}

## parse config file
sub parse {
  my $self = shift;
  if (@_) {
    $self->{FILE} = shift;
  } else {
    $self->{FILE} = "/etc/monika.conf";
  }
  my $config = AppConfig->new({
				  GLOBAL => {
					     DEFAULT  => "<unset>",
					     ARGCOUNT => ARGCOUNT_ONE,
					    }
				 });
  $config->define("clustername",
		  {
		   DEFAULT => "Cluster"
		  });
  $config->define("gridname",
		  {
		   DEFAULT => "Grid"
		  });
  $config->define("hostname",
		  {
		   DEFAULT => ""
		  });
  $config->define("dbname",
		  {
		   DEFAULT => ""
		  });
  $config->define("username",
		  {
		   DEFAULT => ""
		  });
  $config->define("password",
		  {
		   DEFAULT => ""
		  });
  $config->define("nodes_per_line",
		  {
		   DEFAULT => 10
		  });
  $config->define("nodename_regex",
		  {
		   DEFAULT => '(.*)'
		  });
  $config->define("nodename_regex_display",
		  {
		   DEFAULT => '(.*)'
		  });
  $config->define("loadimgpath",
      {
       DEFAULT => "/tmp/"
      });
  $config->define("oargridstat",
		  {
		   DEFAULT => "oargridstat --monitor"
		  });
  $config->define("server_do_mail",
		  {
		   DEFAULT => "no",
		  });
  $config->define("user_infos",
                  {
                   DEFAULT => "",
                  });
  $config->define("node_group",
		  {
		   ARGCOUNT => ARGCOUNT_HASH
		  });
  $config->define("default_state",
		  {
		   ARGCOUNT => ARGCOUNT_HASH
		  });
  $config->define("set_color",
		  {
		   ARGCOUNT => ARGCOUNT_HASH
		  });
  $config->define("color_pool",
		  {
		   ARGCOUNT => ARGCOUNT_LIST
		  });
  $config->define("hidden_property",
		  {
		   ARGCOUNT => ARGCOUNT_LIST
		  });
  $config->file($self->{FILE});

  $self->{CLUSTERNAME} = $config->clustername();
  $self->{GRIDNAME} = $config->gridname();
  $self->{HOSTNAME} = $config->hostname();
  $self->{DBNAME} = $config->dbname();
  $self->{USERNAME} = $config->username();
  $self->{PASSWORD} = $config->password();
  $self->{NODESPERLINE} = $config->nodes_per_line();
  my $regex = $config->nodename_regex();
  $self->{NODENAMEREGEX} = qr/$regex/;
  my $regex_display = $config->nodename_regex_display();
  $self->{NODENAMEREGEXDISPLAY} = qr/$regex_display/;
  $self->{LOADIMGPATH} = $config->loadimgpath();
  $self->{OARGRIDSTATCMD} = $config->oargridstat();
  $self->{SERVER_DO_MAIL} = $config->server_do_mail();
  $self->{NODE_GROUP} = $config->node_group();
  $self->{DEFAULT_STATE} = $config->default_state();
  $self->{SET_COLOR} = $config->set_color();
  $self->{COLOR_POOL} = $config->color_pool();
  $self->{HIDDEN_PROPERTIES} = $config->hidden_property();
  $self->{USER_INFOS} = $config->user_infos();

  my $allnodes = $self->{ALLNODES};

  foreach my $nodeType (keys %{$self->{NODE_GROUP}}) {
    my $state;
    if ($self->{DEFAULT_STATE}->{$nodeType}) {
      $state = $self->{DEFAULT_STATE}->{$nodeType};
    } else {
      $state = $nodeType;
    }
    my @nodes = split /\s+/,$self->{NODE_GROUP}->{$nodeType};
    foreach (@nodes) {
      if (/^(\d+)-(\d+)$/) {
	foreach ($1..$2) {
	  $allnodes->{$_} = monika::ConfNode->new($_,$state);
	}
      } else {
	$allnodes->{$_} = monika::ConfNode->new($_,$state);
      }
    }
  }
  return 1;
}

## return cluster name
sub clustername {
  my $self = shift;
  return $self->{CLUSTERNAME};
}
## return grid name
sub gridname {
  my $self = shift;
  return $self->{GRIDNAME};
}

## return the hostname
sub hostname {
  my $self = shift;
  return $self->{HOSTNAME};
}

## return the dbname
sub dbname {
  my $self = shift;
  return $self->{DBNAME};
}

## return the username
sub username {
  my $self = shift;
  return $self->{USERNAME};
}

## return the password
sub password {
  my $self = shift;
  return $self->{PASSWORD};
}

## return the number of node to be diplayed per line in the reservation table
sub nodes_per_line {
  my $self = shift;
  return $self->{NODESPERLINE};
}

## return the regex to extract a node display name from its real name
sub nodenameRegex {
  my $self = shift;
  return $self->{NODENAMEREGEX};
}

## return the regex to extract a the name displayed on the www page
sub nodenameRegexDisplay {
  my $self = shift;
  return $self->{NODENAMEREGEXDISPLAY};
}

## return oargridstat command (with arg) line as set in config file
sub oargridstatCmd {
  my $self = shift;
  return $self->{OARGRIDSTATCMD};
}

## return loadimgPath path
sub loadimgPath {
  my $self = shift;
  return $self->{LOADIMGPATH};
}



## return true if config file says server also is a mail server
sub server_do_mail {
  my $self = shift;
  $_ = $self->{SERVER_DO_MAIL};
  return (/^\s*yes\s*$/i or /^\s*true\s*$/i);
}

## return a hash containing (state,color) couples
sub colorHash {
  my $self = shift;
  return $self->{SET_COLOR};
}

sub colorPool {
  my $self = shift;
  return $self->{COLOR_POOL};
}

## return the list of properties not to be shown in the property chooser
sub hiddenProperties {
	my $self = shift;
	return @{$self->{HIDDEN_PROPERTIES}};
}

## return a hash containing all node descriptions got from the config file
sub allnodes {
  my $self = shift;
  return $self->{ALLNODES};
}

## retrun the string for property USER_INFOS
sub user_infos {
  my $self = shift;
  return $self->{USER_INFOS};
}

## that's all.
return 1;
