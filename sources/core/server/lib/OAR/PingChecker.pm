package OAR::PingChecker;
require Exporter;

use strict;
use Data::Dumper;
use OAR::Modules::Judas
  qw(oar_debug oar_warn oar_info oar_error send_log_by_email set_current_log_category);
use OAR::Conf qw(init_conf dump_conf get_conf is_conf);
use IPC::Open3;
use OAR::Tools;

require Exporter;
our (@ISA, @EXPORT, @EXPORT_OK);
@ISA       = qw(Exporter);
@EXPORT_OK = qw(ping_hosts sentinelle_hosts test_hosts);

my $Module_name = "PingChecker";
my $Session_id  = $$;

# Log category
set_current_log_category('main');

my $Timeout_ping              = 5;
my $Timeout_fping             = 15;
my $Timeout_nmap              = 30;
my $Timeout_sentinelle        = 300;
my $Timeout_script_sentinelle = 300;
my $Default_timeout           = 300;

#resolve host name and give its IP or return 0
sub get_host_ip($) {
    my ($host_name) = shift;
    my (@addrlist, $name, $altnames, $addrtype, $len);
    my ($ip);

    if (!(($name, $altnames, $addrtype, $len, @addrlist) = gethostbyname($host_name))) {
        return (0);
    } else {
        $ip = join('.', (unpack("C4", $addrlist[0])));
        return ($ip);
    }
}

#Launch the right sub
sub test_hosts(@) {
    init_conf($ENV{OARCONFFILE});
    if (is_conf("OAR_SSH_CONNECTION_TIMEOUT")) {
        OAR::Tools::set_ssh_timeout(get_conf("OAR_SSH_CONNECTION_TIMEOUT"));
    }
    if (is_conf("PINGCHECKER_TAKTUK_ARG_COMMAND") and is_conf("TAKTUK_CMD")) {
        return (taktuk_hosts(@_));
    } elsif (is_conf("PINGCHECKER_SENTINELLE_SCRIPT_COMMAND")) {
        return (sentinelle_script_hosts(@_));
    } elsif (is_conf("PINGCHECKER_FPING_COMMAND")) {
        return (fping_hosts(@_));
    } elsif (is_conf("PINGCHECKER_NMAP_COMMAND")) {
        return (nmap_hosts(@_));
    } elsif (is_conf("PINGCHECKER_GENERIC_COMMAND")) {
        return (generic_hosts(@_));
    } else {
        return (ping_hosts(@_));
    }
}

#Ping hosts and return each one dead
# arg1 --> array of hosts to test
sub ping_hosts(@) {
    my @hosts = @_;

    my @bad_hosts;
    my $exit_value;
    foreach my $i (@hosts) {
        oar_info($Module_name, "PING $i\n", $Session_id);
        $ENV{IFS} = "";
        $ENV{ENV} = "";
        eval {
            $SIG{ALRM} = sub { die "alarm\n" };
            alarm($Timeout_ping);

            #$exit_value = system("ping -c 1 $i > /dev/null");
            $exit_value = system("oardodo ping -c 10 -l 9 $i > /dev/null");
            alarm(0);
        };
        oar_info($Module_name, "PONG with exit_value=$exit_value and alarm=$@\n", $Session_id);
        if (($exit_value != 0) || ($@)) {
            push(@bad_hosts, $i);
        }
    }

    return (@bad_hosts);
}

#Test hosts with taktuk and return each one dead
# arg1 --> array of hosts to test
sub taktuk_hosts(@) {
    my @hosts = @_;

    init_conf($ENV{OARCONFFILE});
    my $taktuk_cmd = get_conf("TAKTUK_CMD");
    oar_info($Module_name, "command to run: $taktuk_cmd\n", $Session_id);
    my ($cmd, @null) = split(" ", $taktuk_cmd);
    oar_info($Module_name, "command to run with arguments: $cmd\n", $Session_id);
    if (!defined($taktuk_cmd) || (!-x $cmd)) {
        oar_error($Module_name, "You call taktuk_hosts but TAKTUK_CMD in oar.conf is not valid.\n",
            $Session_id);
        return (@hosts);
    }

    my $openssh_cmd = get_conf("OPENSSH_CMD");
    $openssh_cmd = OAR::Tools::get_default_openssh_cmd() if (!defined($openssh_cmd));

    my %check_test_nodes;

    $taktuk_cmd .= " -c '$openssh_cmd'" .
      ' -o status=\'"STATUS $host $line\n"\' -f - ' . get_conf("PINGCHECKER_TAKTUK_ARG_COMMAND");

    my @bad_hosts;
    oar_info($Module_name, "$taktuk_cmd\n", $Session_id);
    $ENV{IFS} = "";
    $ENV{ENV} = "";
    my $pid;
    eval {
        $SIG{ALRM} = sub { kill(19, $pid); die("alarm\n") };
        alarm(OAR::Tools::get_taktuk_timeout());
        $pid = open3(\*WRITER, \*READER, \*ERROR, $taktuk_cmd);
        foreach my $i (@hosts) {
            print(WRITER "$i\n");
            $check_test_nodes{$i} = 1;
        }
        close(WRITER);
        while (<READER>) {
            if ($_ =~ /^STATUS ([\w\.\-\d]+) (\d+)$/) {
                if ($2 == 0) {
                    delete($check_test_nodes{$1}) if (defined($check_test_nodes{$1}));
                }
            } else {
                oar_info($Module_name, "[TAKTUK OUTPUT] $_", $Session_id);
            }
        }
        close(ERROR);
        close(READER);
        waitpid($pid, 0);
        alarm(0);
    };
    oar_info($Module_name, "End of command; alarm=$@\n", $Session_id);
    if ($@) {
        oar_error($Module_name, "taktuk command times out: it is bad\n", $Session_id);
        if (defined($pid)) {

            # Kill all taktuk children
            my ($children, $cmd_name) = OAR::Tools::get_one_process_children($pid);
            kill(9, @{$children});
        }

        #        return(@hosts);
    }    #else{
    @bad_hosts = keys(%check_test_nodes);
    return (@bad_hosts);

    #    }
}

#Test hosts with sentinelle script and return each one dead
# arg1 --> array of hosts to test
sub sentinelle_script_hosts(@) {
    my @hosts = @_;

    # Set the parameter of the -c option of sentinelle
    init_conf($ENV{OARCONFFILE});
    my $sentinelle_cmd = get_conf("PINGCHECKER_SENTINELLE_SCRIPT_COMMAND");
    oar_info($Module_name, "command to run: $sentinelle_cmd\n", $Session_id);
    my ($cmd, @null) = split(" ", $sentinelle_cmd);
    oar_info($Module_name, "command to run with arguments: $cmd\n", $Session_id);
    if (!defined($sentinelle_cmd) || (!-x $cmd)) {
        oar_error(
            $Module_name,
            "You call sentinelle_script_hosts but PINGCHECKER_SENTINELLE_SCRIPT_COMMAND in oar.conf is not valid\n",
            $Session_id);
        return (@hosts);
    }

    my $openssh_cmd = get_conf("OPENSSH_CMD");
    $openssh_cmd = OAR::Tools::get_default_openssh_cmd() if (!defined($openssh_cmd));

    my %check_test_nodes;
    $sentinelle_cmd .= " -c '$openssh_cmd' -f - ";

    my @bad_hosts;
    oar_info($Module_name, "$sentinelle_cmd \n", $Session_id);
    $ENV{IFS} = "";
    $ENV{ENV} = "";
    eval {
        my $pid;
        $SIG{ALRM} = sub { kill(9, $pid); die("alarm\n") };
        alarm($Timeout_script_sentinelle);
        $pid = open3(\*WRITER, \*READER, \*ERROR, $sentinelle_cmd);
        foreach my $i (@hosts) {
            print(WRITER "$i\n");
            $check_test_nodes{$i} = 1;
        }
        close(WRITER);
        while (<ERROR>) {
            chomp($_);

            #if ($_ =~ m/^([\w\.]+)\s:\sBAD\s.*$/m){
            if ($_ =~ m/^([\w\.\-]+)\s:\sBAD\s.*$/m) {
                if ($check_test_nodes{$1} == 1) {
                    oar_info($Module_name, "Bad host = $1 \n", $Session_id);
                    push(@bad_hosts, $1);
                }
            }
        }
        close(READER);
        close(ERROR);
        waitpid($pid, 0);
        alarm(0);
    };
    oar_info($Module_name, "End of command; alarm=$@\n", $Session_id);
    if ($@) {
        oar_error($Module_name, "sentinelle script command times out: it is bad\n", $Session_id);
        return (@hosts);
    } else {
        return (@bad_hosts);
    }
}

#Ping hosts with fping program return each one dead
# arg1 --> array of hosts to test
sub fping_hosts(@) {
    my @hosts = @_;

    # Get fping command from oar.conf
    init_conf($ENV{OARCONFFILE});
    my $fping_cmd = get_conf("PINGCHECKER_FPING_COMMAND");
    oar_info($Module_name, "command to run: $fping_cmd\n", $Session_id);
    my ($cmd, @null) = split(" ", $fping_cmd);
    oar_info($Module_name, "command to run with arguments: $cmd\n", $Session_id);
    if (!defined($fping_cmd) || (!-x $cmd)) {
        oar_error(
            $Module_name,
            "You want to call fping test method but PINGCHECKER_FPING_COMMAND in oar.conf is not valid\n",
            $Session_id);
        return (@hosts);
    }

    $fping_cmd .= " -u";
    my %check_test_nodes;
    foreach my $i (@hosts) {
        $fping_cmd .= " $i";
        $check_test_nodes{$i} = 1;
    }

    my @bad_hosts;
    oar_info($Module_name, "$fping_cmd\n", $Session_id);
    $ENV{IFS} = "";
    $ENV{ENV} = "";
    eval {
        my $pid;
        $SIG{ALRM} = sub { kill(9, $pid); die("alarm\n") };
        alarm($Timeout_fping);
        $pid = open3(\*WRITER, \*READER, \*ERROR, $fping_cmd);
        close(WRITER);
        foreach my $i (\*READER, \*ERROR) {
            while (<$i>) {
                chomp($_);

                #$_ =~ m/^\s*([\w\.]+)\s*$/m;
                $_ =~ m/^\s*([\w\.-\d]+)\s*(.*)$/m;
                if ($check_test_nodes{$1} == 1) {
                    if (!defined($2) || !($2 =~ m/alive/m)) {
                        oar_info($Module_name, "Bad host = $1 \n", $Session_id);
                        push(@bad_hosts, $1);
                    }
                }
            }
        }
        close(ERROR);
        close(READER);
        waitpid($pid, 0);
        alarm(0);
    };
    oar_info($Module_name, "End of command; alarm=$@\n", $Session_id);
    if ($@) {
        oar_error($Module_name, "fping command times out: it is bad\n", $Session_id);
        return (@hosts);
    } else {
        return (@bad_hosts);
    }
}

# use nmap to determine if hosts are alive or not
# arg1 --> array of hosts to test
sub nmap_hosts(@) {
    my @hosts = @_;

    # Get nmap command from oar.conf
    init_conf($ENV{OARCONFFILE});
    my $nmap_cmd = get_conf("PINGCHECKER_NMAP_COMMAND");
    oar_info($Module_name, "command to run: $nmap_cmd\n", $Session_id);
    my ($cmd, @null) = split(" ", $nmap_cmd);
    oar_info($Module_name, "command to run with arguments: $cmd\n", $Session_id);
    if (!defined($nmap_cmd) || (!-x $cmd)) {
        oar_error(
            $Module_name,
            "You want to call nmap test method but PINGCHECKER_NMAP_COMMAND in oar.conf is not valid\n",
            $Session_id);
        return (@hosts);
    }

    $nmap_cmd .= " -oG -";
    my %ip2name;
    my @bad_hosts;
    foreach my $i (@hosts) {
        my $ip = get_host_ip($i);
        if ($ip != 0) {
            if (!defined($ip2name{$ip})) {
                $nmap_cmd .= " $ip";
            }
            push(@{ $ip2name{$ip} }, $i);
        }
    }

    my %good_hosts;
    oar_info($Module_name, "$nmap_cmd\n", $Session_id);
    $ENV{IFS} = "";
    $ENV{ENV} = "";
    eval {
        my $pid;
        $SIG{ALRM} = sub { kill(9, $pid); die("alarm\n") };
        alarm($Timeout_nmap);
        $pid = open3(\*WRITER, \*READER, \*ERROR, $nmap_cmd);
        close(WRITER);
        while (<READER>) {
            chomp($_);
            if ($_ =~ m/^Host:\s(\d+\.\d+\.\d+\.\d+)\s(.*)$/m) {
                if (defined($ip2name{$1})) {
                    my $tmp_ip = $1;
                    if (defined($2) && ($2 =~ m/open/m)) {
                        oar_info($Module_name, "Good host = $tmp_ip \n", $Session_id);
                        foreach my $i (@{ $ip2name{$tmp_ip} }) {
                            $good_hosts{$i} = 1;
                        }
                    }
                }
            }
        }
        close(ERROR);
        close(READER);
        waitpid($pid, 0);
        alarm(0);
    };
    oar_info($Module_name, "End of command; alarm=$@\n", $Session_id);
    if ($@) {
        oar_error($Module_name, "nmap command times out: it is bad\n", $Session_id);
        return (@hosts);
    } else {
        foreach my $n (@hosts) {
            if (!defined($good_hosts{$n})) {
                push(@bad_hosts, $n);
            }
        }
        return (@bad_hosts);
    }
}

# use a command which takes the list of nodes in arguments and write on STDERR
# the list of bad nodes
# arg1 --> array of hosts to test
sub generic_hosts(@) {
    my @hosts = @_;

    # Get generic command from oar.conf
    init_conf($ENV{OARCONFFILE});
    my $test_cmd = get_conf("PINGCHECKER_GENERIC_COMMAND");
    oar_info($Module_name, "command to run: $test_cmd\n", $Session_id);
    my ($cmd, @null) = split(" ", $test_cmd);
    oar_info($Module_name, "command to run with arguments: $cmd\n", $Session_id);
    if (!defined($test_cmd) || (!-x $cmd)) {
        oar_error(
            $Module_name,
            "You want to call a generic test method but PINGCHECKER_GENERIC_COMMAND in oar.conf is not valid\n",
            $Session_id);
        return (@hosts);
    }

    my %check_test_nodes;
    foreach my $i (@hosts) {
        $test_cmd .= " $i";
        $check_test_nodes{$i} = 1;
    }

    my @bad_hosts;
    oar_info($Module_name, "$test_cmd \n", $Session_id);
    $ENV{IFS} = "";
    $ENV{ENV} = "";
    eval {
        my $pid;
        $SIG{ALRM} = sub { kill(9, $pid); die("alarm\n") };
        alarm($Default_timeout);
        $pid = open3(\*WRITER, \*READER, \*ERROR, $test_cmd);
        while (<ERROR>) {
            chomp($_);

            #$_ =~ m/^\s*([\w\.]+)\s*$/m;
            $_ =~ m/^\s*([\w\.\-]+)\s*$/m;
            if ($check_test_nodes{$1} == 1) {
                oar_info($Module_name, "Bad host = $1 \n", $Session_id);
                push(@bad_hosts, $1);
            }
        }
        close(ERROR);
        close(WRITER);
        close(READER);
        waitpid($pid, 0);
        alarm(0);
    };
    oar_info($Module_name, "End of command; alarm=$@\n", $Session_id);
    if ($@) {
        oar_error($Module_name, "PINGCHECKER_GENERIC_COMMAND timed out: it is bad\n", $Session_id);
        return (@hosts);
    } else {
        return (@bad_hosts);
    }
}

return 1;
