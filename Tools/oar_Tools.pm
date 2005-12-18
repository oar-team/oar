package oar_Tools;

use IO::Socket::INET;
use warnings;
use strict;

# Constants
my $defaultLeonSoftWalltime = 20;
my $defaultLeonWalltime = 60;

# Prototypes
sub getAllProcessChilds();
sub getOneProcessChilds($);
sub notifyAlmighty($$$);
sub signalOarexec($$$);
sub getOarPidFileName($);
sub getSSHTimeout();
sub getDefaultLeonSoftWalltime();
sub getDefaultLeonWalltime();


# Get default Leon walltime value for Sarko
sub getDefaultLeonSoftWalltime(){
    return($defaultLeonSoftWalltime);
}

# Get default Leon soft walltime value for Sarko
sub getDefaultLeonWalltime(){
    return($defaultLeonWalltime);
}

# return a hashtable of all child arrays
sub getAllProcessChilds(){
    my %processHash;
    open(CMD, "ps -e -o pid,ppid |");
    while (<CMD>){
        chomp($_);
        $_ =~ /(\d+)\s+(\d+)/;
        if (defined($1) && defined($2)){
            if (!defined($processHash{$2})){
                $processHash{$2} = [$1];
            }else{
                push(@{$processHash{$2}}, $1);
            }
        }
    }
    close(CMD);

    return(%processHash);
}

# return an array of childs
sub getOneProcessChilds($){
    my $oneFather = shift;

    my %processHash = getAllProcessChilds();
    my @childPids;
    my @potentialFather;
    while (defined($oneFather)){
        push(@childPids, $oneFather);
        #Get childs of this process
        foreach my $i (@{$processHash{$oneFather}}){
            push(@potentialFather, $i);
        }
        $oneFather = shift(@potentialFather);
    }

    return(@childPids);
}

# Send a Tag on a socket of an Almighty
# args = hostname, socket port, Tag 
sub notifyAlmighty($$$){
    my $almightyHost = shift;
    my $almightyPort = shift;
    my $tag = shift;

    my $socket = IO::Socket::INET->new(PeerAddr => $almightyHost,
                                       PeerPort => $almightyPort,
                                       Proto => "tcp",
                                       Type  => SOCK_STREAM)
             or return("Could not connect to Almighty $almightyHost:$almightyPort");

    print($socket "$tag\n");

    close($socket);

    return(undef);
}


# Return the constant SSH timeout to use
sub getSSHTimeout(){
    return 30;
}


# Get the name of the file which contains the pid of oarexec
# arg : job id
sub getOarPidFileName($){
    my $jobId = shift;

    return("/tmp/pid_of_oarexec_for_jobId_$jobId");
}

# Send the given signal to the right oarexec process
# args : host name, job id, signal
# return an array with exit values
sub signalOarexec($$$){
    my $host = shift;
    my $jobId = shift;
    my $signal = shift;

    my $file = getOarPidFileName($jobId);
    system("ssh $host \"test -e $file && cat $file | xargs kill -s $signal\"");
    my $exitiValue  = $? >> 8;
    my $signalNum  = $? & 127;
    my $dumpedCore = $? & 128;

    return($exitiValue,$signalNum,$dumpedCore);
}
return 1;
