#!/usr/bin/perl
# OAR Script to check and automatically reboot Suspected nodes.
# This script is intended to be started periodically from cron
# for example:
#    */10 * * * *	root /usr/sbin/oar_phoenix
# It needs the nodes to be configured to set up themselves
# in the Alive state at boot time.
# !!! Work in progress: this script needs to be improved !!!
# - No locking!
# - No logging!
# - Timed out processes may still run!
# - Hard timeout is not yet implemented:
#     it should trig a call to Judas to send an e-mail
#     to the admin.

use strict;
use warnings;
use YAML;
use OAR::IO;


################### CUSTOMIZABLE PART #######################

# File where phoenix stores the states of the broken nodes
my $PHOENIX_DBFILE="/var/lib/oar/phoenix/oar_phoenix.db";

# Directory where logfiles are created in case of problems
# !! NOT YET IMPLEMENTED !!
my $PHOENIX_LOGDIR="/var/lib/oar/phoenix/";

# Command sent to reboot a node (first attempt)
#my $PHOENIX_SOFT_REBOOTCMD="ssh -p 6667 {NODENAME} oardodo reboot";
my $PHOENIX_SOFT_REBOOTCMD="echo 'Soft reboot command for {NODENAME}: PHOENIX_SOFT_REBOOTCMD not configured'";

# Timeout for a soft rebooted node to be considered hard rebootable
my $PHOENIX_SOFT_TIMEOUT=300;

# Command sent to rebopot a node (seond attempt)
#my $PHOENIX_HARD_REBOOTCMD="oardodo ipmitool -U USERID -P PASSW0RD -H {NODENAME}-mgt power off;sleep 2;oardodo ipmitool -U USERID -P PASSW0RD -H {NODENAME}-mgt power on";
my $PHOENIX_HARD_REBOOTCMD="echo 'Hard reboot command for {NODENAME}: PHOENIX_HARD_REBOOTCMD not configured'";

# Timeout (s) for a hard rebooted node to be considered really broken, then
# an email is sent
# !! NOT YET IMPLEMENTED!!
my $PHOENIX_HARD_TIMEOUT=300;

# Max number of simultaneous reboots (soft OR hard)
my $PHOENIX_MAX_REBOOTS=10;

# Timout (s) for unix commands
my $PHOENIX_CMD_TIMEOUT=15;

# Get the broken nodes list (SQL request to customize)
my $base = OAR::IO::connect();
#my $date=OAR::IO::get_date($base);
#my @db=OAR::IO::get_nodes_with_given_sql($base,"(state='Absent' AND (available_upto < $date OR available_upto = 0))  or state='Suspected'");
#my @broken_nodes=OAR::IO::get_nodes_with_given_sql($base,"state='Suspected' and network_address NOT IN (SELECT distinct(network_address) FROM resources where resource_id IN (SELECT resource_id  FROM assigned_resources WHERE assigned_resource_index = 'CURRENT')) and network_address != '6po'");
my @broken_nodes=OAR::IO::get_nodes_with_given_sql($base,"state='Suspected' and network_address != '6po'");
OAR::IO::disconnect($base);

################ END OF CUSTOMIZABLE PART ####################

# Send a unix command ant timeout if necessary
sub send_cmd($) {
  my $cmd=shift;
  eval {
    open(my $LOGFILE,">>$PHOENIX_LOGDIR/oar_phoenix.log") or die "can't open logfile into $PHOENIX_LOGDIR/ for writing!: $!";
    local $SIG{ALRM} = sub {die "alarm\n"};
    alarm $PHOENIX_CMD_TIMEOUT;
    my $res = `$cmd 2>&1`;
    print $LOGFILE $res ."\n";
    close($LOGFILE);
    alarm 0;
  };
  if ($@) {
    die unless $@ eq "alarm\n";
    return "Timed out!\n";
  }
}

# Load the DB file
sub load_db($) {
  my $file = shift;
  open(my $YAMLFILE,$file) or die "can't open db file $file for reading: $!";
  return YAML::LoadFile($YAMLFILE);
  close($YAMLFILE);
}

# Export DB to file
sub save_db($$) {
  my $file = shift;
  my $ref = shift;
  open (my $YAMLFILE,">$file") or die "can't open db file $file for writing: $!";
  print $YAMLFILE YAML::Dump($ref);
  close($YAMLFILE);
}

# Init DB file
sub init_db($) {
  my $file = shift;
  if (!-s $file) {
    my %empty_hash;
    save_db($file,\%empty_hash);
  }
}

# Remove nodes that are no longer broken from DB
sub clean_db($$) {
  my $db=shift;
  my $broken_nodes=shift;
  foreach my $node (keys %$db) {
    if (!grep {$_ eq $node} @broken_nodes) {
      delete($db->{$node});
      # TODO: add a log entry
    }
  }
}

# Get nodes to soft_reboot
sub get_nodes_to_soft_reboot($$) {
  my $db=shift;
  my $broken_nodes=shift;
  my $nodes;
  my $c=0;
  foreach my $node (@broken_nodes) {
    if (!defined($db->{$node})) {
      $c++;
      push (@$nodes,$node);
    }
    last if ($c>=$PHOENIX_MAX_REBOOTS);
  }
  return $nodes;
}


# Get nodes to hard_reboot
sub get_nodes_to_hard_reboot($$) {
  my $db=shift;
  my $broken_nodes=shift;
  my $nodes;
  my $c=0;
  foreach my $node (@broken_nodes) {
    if (defined($db->{$node})) {
      if (defined($db->{$node}->{"soft_reboot"})) {
        if (time() > $db->{$node}->{"soft_reboot"} + $PHOENIX_SOFT_TIMEOUT) {
          $c++;
          push (@$nodes,$node);
        }
        last if ($c>=$PHOENIX_MAX_REBOOTS);
      }
    }
  }
  return $nodes;
}

# Soft reboot nodes
sub soft_reboot_nodes($$) {
  my $db=shift;
  my $nodes=shift;
  my $cmd;
  my $res;
  foreach my $node (@$nodes) {
    $cmd=$PHOENIX_SOFT_REBOOTCMD;
    $cmd =~ s/\{NODENAME\}/$node/g;
    print "Soft rebooting the broken node $node\n"; 
    $db->{$node}={ 'soft_reboot' => time() };
    send_cmd($cmd);
  }
}

# Hard reboot nodes
sub hard_reboot_nodes($$) {
  my $db=shift;
  my $nodes=shift;
  my $cmd;
  my $res;
  foreach my $node (@$nodes) {
    $cmd=$PHOENIX_HARD_REBOOTCMD;
    $cmd =~ s/\{NODENAME\}/$node/g;
    print "Hard rebooting the broken node $node\n"; 
    delete($db->{$node});
    $db->{$node}={ 'hard_reboot' => time() };
    $res=send_cmd($cmd);
  }
}

init_db($PHOENIX_DBFILE);
my $db=load_db($PHOENIX_DBFILE);
clean_db($db,@broken_nodes);
my $nodes=get_nodes_to_soft_reboot($db,@broken_nodes);
soft_reboot_nodes($db,$nodes);
$nodes=get_nodes_to_hard_reboot($db,@broken_nodes);
hard_reboot_nodes($db,$nodes);
save_db($PHOENIX_DBFILE,$db);

