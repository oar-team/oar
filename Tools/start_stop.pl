#!/usr/bin/perl
# $Id$

use strict;
use warnings;
use Data::Dumper;

my $pidFile = "/tmp/oar_almighty.pid";

sub usage {
    print STDERR "usage: start_stop.pl [start|stop]\n";
    exit 1;
}

my $usrName = getpwuid($<);
if ("$usrName" ne "root"){
	die("[ERROR] You must be root to run this script\n");
}

usage if (@ARGV < 1);

my $state = $ARGV[0];

if ( $state eq "start" ){
    system("su - oar -c \"Almighty >& /dev/null &\"");
}elsif ($state eq "stop"){
    # get Almighty pid
    if (open(FILE,"< $pidFile")){
        my $pid = <FILE>;
        chomp($pid);
        close(FILE);
        if ((defined($pid)) && ($pid =~ m/^\d+$/m)){
            print("kill -s USR1 $pid\n");
            #Kill Almigthy with the signal USR1
            #kill(-10,$pid);
            system("su - oar -c \"kill -s USR1 $pid && rm $pidFile\"");
            if ($? == 0){
                print("OAR is now stopped :-)\n");
            }else{
                print("Can t kill the process $pid :-(\n");
            }
        }else{
            die("Pid file $pidFile is malformed. Find Almighty pid and kill it!!!!\n");
        }
    }else{
        die("Can t open pid file $pidFile. Find Almighty pid and kill it or there is nothing running!!!!\n");
    }
}else{
    usage();
}

exit 0;
