#!/usr/bin/perl
# Prologue script for OAR/SGE besteffort coupling
# Needs the Epilogue script for the same purpose

use strict;

####################################################################
# CUSTOMIZATION

# Status directory
#my $STATUSDIR="/home_nfs/bzizou/oar_status_tests/";
my $STATUSDIR = "/home_nfs/bzizou/oar_status/";

# SGE resources
#my $PE_HOSTS="/home_nfs/bzizou/test_pe_hosts" ;
my $PE_HOSTS = "$ENV{SGE_JOB_SPOOL_DIR}/pe_hostfile";

#my $JOB_ID=9999;
my $JOB_ID = $ENV{JOB_ID};

# Oarnodesetting cmd
#my $OAR_REMOTE_CMD="echo";
my $OAR_REMOTE_CMD     = "ssh p2chpd-cluster";
my $OARNODESETTING_CMD = "/usr/local/sbin/oarnodesetting -s Absent";

#######################################################################

#print "Prologue starting...\n";

open(FILE, $PE_HOSTS);
my @NODES = (<FILE>);
close(FILE);
my $host;
my $sge_weight;
my $cond = "false";
foreach (@NODES) {
    ($host, $sge_weight) = split();
    my $cpu        = 1;
    my $max_cpus   = 8;    # <- TODO: this has to be guessed (qstat -f)
    my $oar_weight = 0;

    while ($cpu <= $max_cpus && $oar_weight < $sge_weight) {
        if (!(-r "$STATUSDIR/$host.$cpu")) {

            # Touch a file corresponding to the OAR resource
            open(FILE, ">", "$STATUSDIR/$host.$cpu");
            close(FILE);

            # Put this resource in the Absent state
            #print "Setting cpuset $cpu on OAR node $host in the Absent state\n";
            $cond .= " or (network_address='$host' and cpuset=";
            $cond .= $cpu - 1;
            $cond .= ")";

#my $CMD="ssh p2chpd-cluster \" /usr/local/sbin/oarnodesetting -s Absent --sql \\\"network_address='$host' and cpuset=";
#$CMD.= $cpu - 1 ."\\\" \"";
#print $CMD."\n";
#`$CMD`;

            # Update the status file that will be used by the epilogue script
            open(FILE, ">>", "$STATUSDIR/$JOB_ID");
            printf FILE "$host:$cpu\n";
            close(FILE);

            $oar_weight++;
        }
        $cpu++;
    }
}

# Send the command
if ("$cond" ne "false") {
    my $CMD = "$OAR_REMOTE_CMD \"$OARNODESETTING_CMD --sql \\\"$cond\\\"\"";

    #print $CMD;
    `$CMD`;
}

#print "Prologue end.\n";

exit 0;
