#!/usr/bin/perl
# Epilogue script for OAR/SGE besteffort coupling
# Needs the Prologue script for the same purpose


use strict;

####################################################################
# CUSTOMIZATION

# Status directory
#my $STATUSDIR="/home_nfs/bzizou/oar_status_tests/";
my $STATUSDIR="/home_nfs/bzizou/oar_status/";

# SGE resources
#my $PE_HOSTS="/home_nfs/bzizou/test_pe_hosts" ;
my $PE_HOSTS="$ENV{SGE_JOB_SPOOL_DIR}/pe_hostfile";
#my $JOB_ID=9999;
my $JOB_ID=$ENV{JOB_ID};

# Oarnodesetting cmd
#my $OAR_REMOTE_CMD="echo";
my $OAR_REMOTE_CMD="ssh p2chpd-cluster";
my $OARNODESETTING_CMD="/usr/local/sbin/oarnodesetting -s Alive";

#######################################################################

#print "Epilogue starting...\n";

open (FILE,"$STATUSDIR/$JOB_ID");
my @NODES=(<FILE>);
close(FILE);
my $host,
my $cpu;
my $cond="false";
foreach (@NODES) {
    ($host,$cpu)=split(/:/);
    $cond.=" or (network_address='$host' and cpuset=";
    $cond.= $cpu - 1;
    $cond.=")";
    #my $CMD="ssh p2chpd-cluster \" /usr/local/sbin/oarnodesetting -s Alive --sql \\\"network_address='$host' and cpuset=";
    #$CMD.= $cpu - 1 ."\\\" \"";
    #print $CMD."\n";
    #`$CMD`;
    `rm -f $STATUSDIR/$host.$cpu`;
}

# Send the command
if ("$cond" ne "false") {
  my $CMD="$OAR_REMOTE_CMD \"$OARNODESETTING_CMD --sql \\\"$cond\\\"\"";
  #print $CMD;
  `$CMD`
}

unlink("$STATUSDIR/$JOB_ID");

#print "Prologue end.\n";

exit 0;
