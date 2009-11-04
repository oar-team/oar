#!/usr/bin/perl

# Epilogue script for OAR/PBS besteffort coupling
# Needs the Prologue script for the same purpose

use strict;

####################################################################
# CUSTOMIZATION

# Configuration variables
my $PBSNODES_CMD="/usr/pbs/bin/pbsnodes -v";
my @NODES=("healthphy[1]",
           "healthphy[2]",
           "healthphy[3]",
           "healthphy[4]",
           "healthphy[5]",
           "healthphy[6]",
           "healthphy[7]",
           "healthphy[8]",
           "healthphy[9]",
           "healthphy[10]",
           "healthphy[11]",
           "healthphy[12]",
           "healthphy[13]",
           "healthphy[14]",
           "healthphy[15]",
           "healthphy[16]",
           "healthphy[17]",
           "healthphy-xeon1",
           "healthphy-xeon2",
           "healthphy-xeon3",
           "healthphy-xeon4",
           "healthphy-xeon5",
           "healthphy-xeon6",
           "healthphy-xeon7"
);
my $OARNODESETTING_CMD="ssh healthphy /usr/local/sbin/oarnodesetting";

# Definition of how PBS resources correspond to OAR resources:
my %oar_resource_id;

  # Healthphy (from core 4 to 71 -> resources 5 to 72):
  my $oar_id=5;
  for (my $pbs_node = 1; $pbs_node <= 17; $pbs_node++) {
     for (my $pbs_id = 0; $pbs_id <= 3; $pbs_id++) {
        $oar_resource_id{"healthphy[$pbs_node]"}{$pbs_id}=$oar_id;
        $oar_id++;
     }
  }

  # Healthphy-xeon (-> resources 73 to 100)
  for (my $pbs_node = 1; $pbs_node <= 7; $pbs_node++) {
     for (my $pbs_id = 0; $pbs_id <= 3; $pbs_id++) {
        $oar_resource_id{"healthphy-xeon$pbs_node"}{$pbs_id}=$oar_id;
        $oar_id++;
     }
  }

#######################################################################

print "Epilogue starting...\n";

foreach my $node (@NODES) { 
  my $FILE;
  my $key;
  my $value;
  open($FILE,"$PBSNODES_CMD $node|");
  my @PBSRESOURCES=(<$FILE>);
  close($FILE);
  foreach (@PBSRESOURCES) {
    ($key,$value)=split(/\s*=\s*/);
    $key=~s/^\s*//;
    $key=~s/\s*$//;
    if ($key eq "jobs") {
      $value=~s/^\s*//;
      $value=~s/\s*$//;
      my @jobs=split(/\s*,\s*/,$value);
      foreach my $job (@jobs) {
        chomp($job);
        (my $j,my $cpu)=split(/\//,$job);
        if ($j eq $ARGV[0]) {
          print "Setting OAR resource $oar_resource_id{$node}{$cpu} to alive state\n";
          `$OARNODESETTING_CMD -r $oar_resource_id{$node}{$cpu} -s Alive`;
          ######### Healthphy specific:
               my $second_resource=sprintf("1%02i",$oar_resource_id{$node}{$cpu});
               `$OARNODESETTING_CMD -r $second_resource -s Alive`;
          #########
        }
      } 
    }
  }
}


print "Epilogue end.\n";


