# $Id: ping_checker.pm,v 1.17 2005/09/16 13:53:37 capitn Exp $
package ping_checker;
require Exporter;

use strict;
use Data::Dumper;
use oar_Judas qw(oar_debug oar_warn oar_error);
use oar_conflib qw(init_conf dump_conf get_conf is_conf);
use IPC::Open3;

require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(ping_hosts sentinelle_hosts test_hosts);

my $timeoutPing = 5;
my $timeoutFping = 15;
my $timeoutNmap = 30;
my $timeoutSentinelle = 60;
my $timeoutScriptSentinelle = 60;

#resolve host name and give its IP or return 0
sub getHostIp($){
    my ($hostName) = shift;
    my (@addrlist,$name,$altnames,$addrtype,$len);
    my ($ip);
 
    if (!(($name, $altnames, $addrtype, $len, @addrlist) = gethostbyname ($hostName))) {
        return (0);
    }else{
        $ip=join('.',(unpack("C4",$addrlist[0])));
        return ($ip);
    }
}

#Launch the right sub
sub test_hosts(@){
    init_conf("oar.conf");
    if (is_conf("SENTINELLE_COMMAND")){
        return(sentinelle_hosts(@_));
    }elsif (is_conf("SENTINELLE_SCRIPT_COMMAND")){
        return(sentinelle_script_hosts(@_));
    }elsif (is_conf("FPING_COMMAND")){
        return(fping_hosts(@_));
    }elsif (is_conf("NMAP_COMMAND")){
        return(nmap_hosts(@_));
    }else{
        return(ping_hosts(@_));
    }
}

#Ping hosts and return each one dead
# arg1 --> array of hosts to test
sub ping_hosts(@){
    my @hosts = @_;

    my @badHosts;
    my $exit_value;
    foreach my $i (@hosts){
        oar_debug("[PingChecker] PING $i\n");
        $ENV{IFS}="";
        $ENV{ENV}="";
        eval {
            $SIG{ALRM} = sub { die "alarm\n" };
            alarm($timeoutPing);
            #$exit_value = system("ping -c 1 $i > /dev/null");
            $exit_value = system("sudo ping -c 10 -l 9 $i > /dev/null");
            alarm(0);
        };
        oar_debug("[PingChecker] PONG with exit_value=$exit_value and alarm=$@\n");
        if (($exit_value != 0) || ($@)){
            push(@badHosts, $i);
        }
    }

    return(@badHosts);
}

#Test hosts with sentinelle and return each one dead
# arg1 --> array of hosts to test
sub sentinelle_hosts(@){
    my @hosts = @_;

    # Set the parameter of the -c option of sentinelle
    init_conf("oar.conf");
    my $sentinelleCmd = get_conf("SENTINELLE_COMMAND");
    oar_debug("[PingChecker] command to run : $sentinelleCmd\n");
    my ($cmd, @null) = split(" ",$sentinelleCmd);
    oar_debug("[PingChecker] command to run with arguments : $cmd\n");
    if (!defined($sentinelleCmd) || (! -x $cmd)){
        oar_warn("[PingChecker] You call sentinelle_hosts but SENTINELLE_COMMAND in oar.conf is not valid\n");
        return(@hosts);
    }

    my %checkTestNodes;
    foreach my $i (@hosts){
        $sentinelleCmd .= " -m$i";
        $checkTestNodes{$i} = 1;
    }

    my @badHosts;
    oar_debug("[PingChecker] $sentinelleCmd \n");
    $ENV{IFS}="";
    $ENV{ENV}="";
    eval {
        $SIG{ALRM} = sub { die("alarm\n") };
        alarm($timeoutSentinelle);
        open3(\*WRITER, \*READER, \*ERROR, $sentinelleCmd);
        while(<ERROR>){
            chomp($_);
            $_ =~ m/^\s*([\w\.]+)\s*$/m;
            if ($checkTestNodes{$1} == 1){
                oar_debug("[PingChecker] Bad host = $1 \n");
                push(@badHosts, $1);
            }
        }
        close(ERROR);
        close(WRITER);
        close(READER);
        alarm(0);
    };
    oar_debug("[PingChecker] End of command; alarm=$@\n");
    if ($@){
        oar_warn("[PingChecker] sentinelle command times out : it is bad\n");
        return(@hosts);
    }else{
        return(@badHosts);
    }
}


#Test hosts with sentinelle script and return each one dead
# arg1 --> array of hosts to test
sub sentinelle_script_hosts(@){
    my @hosts = @_;

    # Set the parameter of the -c option of sentinelle
    init_conf("oar.conf");
    my $sentinelleCmd = get_conf("SENTINELLE_SCRIPT_COMMAND");
    oar_debug("[PingChecker] command to run : $sentinelleCmd\n");
    my ($cmd, @null) = split(" ",$sentinelleCmd);
    oar_debug("[PingChecker] command to run with arguments : $cmd\n");
    if (!defined($sentinelleCmd) || (! -x $cmd)){
        oar_warn("[PingChecker] You call sentinelle_script_hosts but SENTINELLE_script_COMMAND in oar.conf is not valid\n");
        return(@hosts);
    }

    my %checkTestNodes;
    foreach my $i (@hosts){
        $sentinelleCmd .= " -m $i";
        $checkTestNodes{$i} = 1;
    }

    my @badHosts;
    oar_debug("[PingChecker] $sentinelleCmd \n");
    $ENV{IFS}="";
    $ENV{ENV}="";
    eval {
        $SIG{ALRM} = sub { die("alarm\n") };
        alarm($timeoutScriptSentinelle);
        open3(\*WRITER, \*READER, \*ERROR, $sentinelleCmd);
        while(<READER>){
            chomp($_);
            if ($_ =~ m/^([\w\.]+)\s:\sBAD\s.*$/m){
                if ($checkTestNodes{$1} == 1){
                    oar_debug("[PingChecker] Bad host = $1 \n");
                    push(@badHosts, $1);
                }
            }
        }
        close(ERROR);
        close(WRITER);
        close(READER);
        alarm(0);
    };
    oar_debug("[PingChecker] End of command; alarm=$@\n");
    if ($@){
        oar_warn("[PingChecker] sentinelle script command times out : it is bad\n");
        return(@hosts);
    }else{
        return(@badHosts);
    }
}

#Ping hosts with fping program return each one dead
# arg1 --> array of hosts to test
sub fping_hosts(@){
    my @hosts = @_;

    # Get fping command from oar.conf
    init_conf("oar.conf");
    my $fpingCmd = get_conf("FPING_COMMAND");
    oar_debug("[PingChecker] command to run : $fpingCmd\n");
    my ($cmd, @null) = split(" ",$fpingCmd);
    oar_debug("[PingChecker] command to run with arguments : $cmd\n");
    if (!defined($fpingCmd) || (! -x $cmd)){
        oar_warn("[PingChecker] You want to call fping test method but FPING_COMMAND in oar.conf is not valid\n");
        return(@hosts);
    }

    $fpingCmd .= " -u";
    my %checkTestNodes;
    foreach my $i (@hosts){
        $fpingCmd .= " $i";
        $checkTestNodes{$i} = 1;
    }

    my @badHosts;
    oar_debug("[PingChecker] $fpingCmd\n");
    $ENV{IFS}="";
    $ENV{ENV}="";
    eval {
        $SIG{ALRM} = sub { die("alarm\n") };
        alarm($timeoutFping);
        open3(\*WRITER, \*READER, \*ERROR, $fpingCmd);
        close(WRITER);
        foreach my $i (\*READER, \*ERROR){
            while(<$i>){
                chomp($_);
                #$_ =~ m/^\s*([\w\.]+)\s*$/m;
                $_ =~ m/^\s*([\w\.-\d]+)\s*(.*)$/m;
                if ($checkTestNodes{$1} == 1){
                    if (!defined($2) || !($2 =~ m/alive/m)){
                        oar_debug("[PingChecker] Bad host = $1 \n");
                        push(@badHosts, $1);
                    }
                }
            }
        }
        close(ERROR);
        close(READER);
        alarm(0);
    };
    oar_debug("[PingChecker] End of command; alarm=$@\n");
    if ($@){
        oar_warn("[PingChecker] fping command times out : it is bad\n");
        return(@hosts);
    }else{
        return(@badHosts);
    }
}
 

# use nmap to determine if hosts are alive or not
# arg1 --> array of hosts to test
sub nmap_hosts(@){
    my @hosts = @_;

    # Get nmap command from oar.conf
    init_conf("oar.conf");
    my $nmapCmd = get_conf("NMAP_COMMAND");
    oar_debug("[PingChecker] command to run : $nmapCmd\n");
    my ($cmd, @null) = split(" ",$nmapCmd);
    oar_debug("[PingChecker] command to run with arguments : $cmd\n");
    if (!defined($nmapCmd) || (! -x $cmd)){
        oar_warn("[PingChecker] You want to call nmap test method but NMAP_COMMAND in oar.conf is not valid\n");
        return(@hosts);
    }

    $nmapCmd .= " -oG -";
    my %ip2name;
    my @badHosts;
    foreach my $i (@hosts){
        my $ip = getHostIp($i);
        if ($ip == 0){
            push(@badHosts, $i);
        }else{
            if (!defined($ip2name{$ip})){
                $nmapCmd .= " $ip";
            }
            push(@{$ip2name{$ip}}, $i);
        }
    }

    my %goodHosts;
    oar_debug("[PingChecker] $nmapCmd\n");
    $ENV{IFS}="";
    $ENV{ENV}="";
    eval {
        $SIG{ALRM} = sub { die("alarm\n") };
        alarm($timeoutNmap);
        open3(\*WRITER, \*READER, \*ERROR, $nmapCmd);
        close(WRITER);
        while(<READER>){
            chomp($_);
            if ($_ =~ m/^Host:\s(\d+\.\d+\.\d+\.\d+)\s(.*)$/m){
                if (defined($ip2name{$1})){
                    my $tmpIp = $1;
                    if (defined($2) && ($2 =~ m/open/m)){
                        oar_debug("[PingChecker] Good host = $tmpIp \n");
                        foreach my $i (@{$ip2name{$tmpIp}}){
                            $goodHosts{$i} = 1;
                        }
                    }
                }
            }
        }
        close(ERROR);
        close(READER);
        alarm(0);
    };
    oar_debug("[PingChecker] End of command; alarm=$@\n");
    if ($@){
        oar_warn("[PingChecker] nmap command times out : it is bad\n");
        return(@hosts);
    }else{
        foreach my $n (@hosts){
            if (!defined($goodHosts{$n})){
                push(@badHosts, $n);
            }
        }
        return(@badHosts);
    }
}   

return 1;
