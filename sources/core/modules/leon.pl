#!/usr/bin/perl
# $Id$
#

use English;
use OAR::IO;
#use Sys::Hostname;
use OAR::Conf qw(init_conf dump_conf get_conf is_conf);
#use IPC::Open2;
#use IPC::Open3;
#use Data::Dumper;
use OAR::Modules::Judas qw(oar_debug oar_warn oar_error set_current_log_category);
#use IO::Socket::INET;
use OAR::Tools;
use OAR::PingChecker qw(test_hosts);

# Log category
set_current_log_category('main');

init_conf($ENV{OARCONFFILE});
my $Server_hostname = get_conf("SERVER_HOSTNAME");
my $Server_port = get_conf("SERVER_PORT");

my $Deploy_hostname = get_conf("DEPLOY_HOSTNAME");
if (!defined($Deploy_hostname)){
    $Deploy_hostname = $Server_hostname;
}

my $Cosystem_hostname = get_conf("COSYSTEM_HOSTNAME");
if (!defined($Cosystem_hostname)){
    $Cosystem_hostname = $Server_hostname;
}

my $Server_epilogue = get_conf("SERVER_EPILOGUE_EXEC_FILE");

my $Openssh_cmd = get_conf("OPENSSH_CMD");
$Openssh_cmd = OAR::Tools::get_default_openssh_cmd() if (!defined($Openssh_cmd));

if (is_conf("OAR_SSH_CONNECTION_TIMEOUT")){
    OAR::Tools::set_ssh_timeout(get_conf("OAR_SSH_CONNECTION_TIMEOUT"));
}

if (is_conf("OAR_RUNTIME_DIRECTORY")){
    OAR::Tools::set_default_oarexec_directory(get_conf("OAR_RUNTIME_DIRECTORY"));
}

# Test if we must launch a finishing sequence on a specific job
if (defined($ARGV[0])){
    my $job_id = $ARGV[0];
    if ($job_id !~ m/^\d+$/m){
        oar_error("[Leon_exterminator] Leon was called to exterminate a job but \"$job_id\" is not a correct value\n");
    }
    my $base = OAR::IO::connect();
    my $frag_state = OAR::IO::get_job_frag_state($base, $job_id);
    if (defined($frag_state) and ($frag_state eq "LEON_EXTERMINATE")){
        $SIG{PIPE} = 'IGNORE';
        $SIG{USR1} = 'IGNORE';
        $SIG{INT}  = 'IGNORE';
        $SIG{TERM} = 'IGNORE';
        my $str = "[Leon] I exterminate the job $job_id";
        my @events; push(@events, {type => "EXTERMINATE_JOB", string => $str});
        oar_debug("[Leon_exterminator] Leon was called to exterminate ithe job \"$job_id\"\n");
        OAR::IO::job_arm_leon_timer($base,$job_id);
        OAR::IO::job_finishing_sequence($base, $Server_epilogue, $Server_hostname, $Server_port, $job_id, \@events);
        OAR::Tools::notify_tcp_socket($Server_hostname, $Server_port, "ChState");
    }else{
        oar_error("[Leon_exterminator] Leon was called to exterminate the job \"$job_id\" but its frag_state is not LEON_EXTERMINATE\n");
    }
    OAR::IO::disconnect($base);
    exit(0);
}

my $Exit_code = 0;

my $base = OAR::IO::connect();

#do it for all job in state LEON in the data base table fragJobs
OAR::IO::lock_table($base,["jobs","job_state_logs","resources","assigned_resources","frag_jobs","event_logs","moldable_job_descriptions","job_types","job_resource_descriptions","job_resource_groups","challenges","job_dependencies","gantt_jobs_predictions"]);

# Do not over notify Almighty
OAR::Tools::inhibit_notify_tcp_socket();
foreach my $j (OAR::IO::get_to_kill_jobs($base)){
    if (OAR::IO::is_job_desktop_computing($base,$j->{job_id})) {
        oar_debug("[Leon] Job $j->{job_id} is affected to a DesktopComputing resource, I do not handle it\n");
        next;
    }

    oar_debug("[Leon] Normal kill : I treate the job $j->{job_id}\n");
    if (($j->{state} eq "Waiting") || ($j->{state} eq "Hold")){
        oar_debug("[Leon] Job is not launched\n");
        OAR::IO::set_job_state($base,$j->{job_id},"Error");
        OAR::IO::set_job_message($base,$j->{job_id},"Job killed by Leon directly");
        if ($j->{job_type} eq "INTERACTIVE"){
            oar_debug("[Leon] I notify oarsub in waiting mode\n");
            #answer($Jid,$refJob->{'infoType'},"JOB KILLED");
            OAR::Tools::enable_notify_tcp_socket();
            my ($addr,$port) = split(/:/,$j->{info_type});
            if (!defined(OAR::Tools::notify_tcp_socket($addr, $port, "JOB KILLED"))){
                oar_debug("[Leon] Notification done\n");
            }else{
                oar_debug("[Leon] Cannot open connection to oarsub client for job $j->{job_id}, it is normal if user typed Ctrl-C !!!!!!\n");
            }
            OAR::Tools::inhibit_notify_tcp_socket();
        }
        $Exit_code = 1;
    }elsif (($j->{state} eq "Terminated") || ($j->{state} eq "Error") || ($j->{state} eq "Finishing")){
        oar_debug("[Leon] Job is terminated or is terminating I do nothing\n");
    }else{
        my $types = OAR::IO::get_job_types_hash($base,$j->{job_id});
        if (defined($types->{noop})){
            oar_debug("[Leon] Kill the NOOP job $j->{job_id}\n");
            OAR::IO::set_finish_date($base,$j->{job_id});
            OAR::IO::set_job_state($base,$j->{job_id},"Terminated");
            OAR::IO::set_job_message($base,$j->{job_id},"NOOP job killed by Leon");
            OAR::IO::job_finishing_sequence($base, $Server_epilogue, $Server_hostname, $Server_port, $j->{job_id}, []);
            $Exit_code = 1;
        }else{
            my @hosts = OAR::IO::get_job_current_hostnames($base,$j->{job_id});
            my $host_to_connect_via_ssh = $hosts[0];
            #deploy, cosystem and no host part
            if ((defined($types->{cosystem})) or ($#hosts < 0)){
                $host_to_connect_via_ssh = $Cosystem_hostname;
            }elsif (defined($types->{deploy})){
                $host_to_connect_via_ssh = $Deploy_hostname;
            }
            #deploy, cosystem and no host part
            if (defined($host_to_connect_via_ssh)){
                OAR::IO::add_new_event($base,"SEND_KILL_JOB",$j->{job_id},"[Leon] Send kill signal to oarexec on $host_to_connect_via_ssh for the job $j->{job_id}");
                OAR::Tools::signal_oarexec($host_to_connect_via_ssh, $j->{job_id}, "TERM", 0, $base, $Openssh_cmd, '');
            }
        }
    }
    OAR::IO::job_arm_leon_timer($base,$j->{job_id});
}
OAR::Tools::enable_notify_tcp_socket();

#I treate jobs in state EXTERMINATED in the table fragJobs
foreach my $j (OAR::IO::get_to_exterminate_jobs($base)){
    oar_debug("[Leon] EXTERMINATE the job $j->{job_id}\n");
    OAR::IO::set_job_state($base,$j->{job_id},"Finishing");
    if ($j->{start_time} == 0){
        OAR::IO::set_running_date($base,$j->{job_id});
    }
    OAR::IO::set_finish_date($base,$j->{job_id});
    OAR::IO::set_job_message($base,$j->{job_id},"Job exterminated by Leon");
    OAR::Tools::notify_tcp_socket($Server_hostname, $Server_port, "LEONEXTERMINATE_$j->{job_id}");
}
OAR::IO::unlock_table($base);

OAR::IO::disconnect($base);

exit($Exit_code);
