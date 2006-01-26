package oar_Tools;

use IO::Socket::INET;
use oar_Judas qw(oar_debug oar_warn oar_error);
use warnings;
use strict;

# Constants
my $defaultLeonSoftWalltime = 20;
my $defaultLeonWalltime = 60;
my $timeoutSSH = 30;
my $oarexecPidFileName = "/tmp/pid_of_oarexec_for_jobId_";

# Prototypes
sub getAllProcessChilds();
sub getOneProcessChilds($);
sub notifyTCPSocket($$$);
sub signalOarexec($$$$);
sub getOarPidFileName($);
sub getSSHTimeout();
sub getDefaultLeonSoftWalltime();
sub getDefaultLeonWalltime();
sub checkClientHostIP($$$);


# Get default Leon walltime value for Sarko
sub getDefaultLeonSoftWalltime(){
    return($defaultLeonSoftWalltime);
}

# Get default Leon soft walltime value for Sarko
sub getDefaultLeonWalltime(){
    return($defaultLeonWalltime);
}

# return a hashtable of all child in arrays
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

# Send a Tag on a socket
# args = hostname, socket port, Tag 
sub notifyTCPSocket($$$){
    my $almightyHost = shift;
    my $almightyPort = shift;
    my $tag = shift;

    my $socket = IO::Socket::INET->new(PeerAddr => $almightyHost,
                                       PeerPort => $almightyPort,
                                       Proto => "tcp",
                                       Type  => SOCK_STREAM)
             or return("Could not connect to the socket $almightyHost:$almightyPort");

    print($socket "$tag\n");

    close($socket);

    return(undef);
}


# Return the constant SSH timeout to use
sub getSSHTimeout(){
    return($timeoutSSH);
}


# Get the name of the file which contains the pid of oarexec
# arg : job id
sub getOarPidFileName($){
    my $jobId = shift;

    return($oarexecPidFileName.$jobId);
}

# Send the given signal to the right oarexec process
# args : host name, job id, signal, wait or not (0 or 1)
# return an array with exit values
sub signalOarexec($$$$){
    my $host = shift;
    my $jobId = shift;
    my $signal = shift;
    my $wait = shift;

    my $file = getOarPidFileName($jobId);
    my $cmd = "ssh $host \"test -e $file && cat $file | xargs kill -s $signal\"";
    my $pid;
    if($pid == 0){
        #CHILD
        exec("$cmd");
    }
    if ($wait > 0){
        waitpid($pid,0);
        my $exitiValue  = $? >> 8;
        my $signalNum  = $? & 127;
        my $dumpedCore = $? & 128;

        return($exitiValue,$signalNum,$dumpedCore);
    }else{
        return(undef);
    }
}


# Check if a client socket is authorized to connect to us
# args : OAR module name, client socket, ref of an array of authorized networks
# return 1 for success else 0
sub checkClientHostIP($$$){
    my $moduleName = shift;
    my $client = shift;
    my $refArray = shift;

    my @authorizedHosts = @{$refArray};

    my $extrem = getpeername($client);
    my ($remotePort,$addr_in) = unpack_sockaddr_in($extrem);
    my $remoteHost = inet_ntoa($addr_in);
    oar_debug("[$moduleName] [checkClientHostIP] Remote host = $remoteHost ; remote port = $remotePort\n");
    $remoteHost =~ m/^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$/m;
    $remoteHost = ($1 << 24)+($2 << 16)+($3 << 8)+$4;
    my $i = 0;
    my $hostAllow = 0;
    while (($hostAllow == 0) && ($#authorizedHosts >= $i)){
        my $str = "Check host with $authorizedHosts[$i]->[0].$authorizedHosts[$i]->[1].$authorizedHosts[$i]->[2].$authorizedHosts[$i]->[3]/$authorizedHosts[$i]->[4] --> ";
        my $network = ($authorizedHosts[$i]->[0] << 24)+($authorizedHosts[$i]->[1] << 16)+($authorizedHosts[$i]->[2] << 8)+$authorizedHosts[$i]->[3];
        my $mask = 2**32 - 2**(32-$authorizedHosts[$i]->[4]);
        if (($remoteHost & $mask) == $network){
            $str .= "OK";
            $hostAllow = 1;
        }else{
            $str .= "BAD";
            oar_warn("[$moduleName] [checkClientHostIP] $str\n");
        }
        oar_debug("[$moduleName] [checkClientHostIP] $str\n");
        $i++;
    }
    return($hostAllow);
}

return 1;
