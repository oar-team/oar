package OAR::Modules::Judas;
require Exporter;
# this module allows to log on a file and stdout with three different level
# $Id$

use strict;
use Data::Dumper;
use OAR::Conf qw(init_conf get_conf get_conf_with_default_param is_conf);
use Net::SMTP;
use Sys::Hostname;
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday);
use OAR::IO;
use OAR::Tools;

require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(oar_warn oar_debug oar_error send_log_by_email set_current_log_category);

$| = 1;
my $CURRENT_LOG_CAT;

#Get log level in oar.conf file
init_conf($ENV{OARCONFFILE});
my $log_level = get_conf("LOG_LEVEL");
if (!defined($log_level)){
    $log_level = 2;
}
my $log_file = get_conf("LOG_FILE");
if (!defined($log_file)){
    $log_file = "/var/log/oar.log";
}
my %log_categories;
if (is_conf("LOG_CATEGORIES")){
    my @prelogs = split(/,/, get_conf("LOG_CATEGORIES"));
    foreach(@prelogs){
      $log_categories{$_} = 1;
    }
}
else{
  $log_categories{"all"} = 1;
}


my $mail_recipient = get_conf("MAIL_RECIPIENT");

my $Instance_name = get_conf_with_default_param("INSTANCE_NAME", hostname());

my $Openssh_cmd = get_conf("OPENSSH_CMD");
$Openssh_cmd = OAR::Tools::get_default_openssh_cmd() if (!defined($Openssh_cmd));

if (is_conf("OAR_SSH_CONNECTION_TIMEOUT")){
    OAR::Tools::set_ssh_timeout(get_conf("OAR_SSH_CONNECTION_TIMEOUT"));
}

# this function redirect STDOUT and STDERR into the log file
# return the pid of the fork process
sub redirect_everything(){
    return(0) if (! is_conf("LOG_FILE"));
    pipe(judas_read,judas_write);
    my $pid = fork();
    if ($pid == 0){
        close(judas_write);
        while (<judas_read>){
            if (open(REDIRECTFILE,">>$log_file")){
                print(REDIRECTFILE "$_");
                close(REDIRECTFILE);
            }
        }
        exit(1);
    }
    close(judas_read);
    my $old_fd = select(judas_write); $|=1; select($old_fd);
    open(STDOUT, ">&".fileno(judas_write));
    open(STDERR, ">&".fileno(judas_write));

    return($pid);
}

sub get_log_level(){
    return($log_level);
}
 
# this function must be called by each module that has something to say in
# the logs with his proper category name.
sub set_current_log_category($){
    $CURRENT_LOG_CAT = shift;
}

# this function writes both on the stdout and in the log file
sub write_log($){
    my $str = shift;
	$CURRENT_LOG_CAT = "all" if !defined $CURRENT_LOG_CAT;
    if(exists($log_categories{$CURRENT_LOG_CAT}) || exists($log_categories{"all"})){
      if (open(LOG,">>$log_file")){
          print(LOG "$str");
          close(LOG);
      }else{
          print("$str");
      }
    }
}

# Send an email to the admin
sub send_log_by_email($$){
    my $subject = shift;
    my $body = shift;

    if (!defined($subject)){
        my ($sub,@null) = split("\n",$body);
        $subject = substr($sub,0,70);
    }
    send_mail($mail_recipient, $subject,$body,0);
}

sub oar_debug($){
    my $string = shift;

    if ($log_level >= 3){
        my ($seconds, $microseconds) = gettimeofday();
        $microseconds = int($microseconds / 1000);
        $microseconds = sprintf("%03d",$microseconds);
        $string = "[".strftime("%F %T",localtime($seconds)).".$microseconds] $string";
        write_log("[debug] $string");
    }
}

sub oar_warn($){
    my $string = shift;

    if ($log_level >= 2){
        my ($seconds, $microseconds) = gettimeofday();
        $microseconds = int($microseconds / 1000);
        $microseconds = sprintf("%03d",$microseconds);
        $string = "[".strftime("%F %T",localtime($seconds)).".$microseconds] $string";
        write_log("[info] $string");
    }
}

sub oar_error($){
    my $string = shift;

    #send_log_by_email(undef,"[error] $string");
    my ($seconds, $microseconds) = gettimeofday();
    $microseconds = int($microseconds / 1000);
    $microseconds = sprintf("%03d",$microseconds);
    $string = "[".strftime("%F %T",localtime($seconds)).".$microseconds] $string";
    write_log("[error] $string");
}

# Must be only used in the fork of the send_mail function to store errors in OAR DB
sub treate_mail_error($$$$$$$){
    my $smtpServer = shift;
    my $mailSenderAddress = shift;
    my $mailRecipientAddress = shift;
    my $object = shift;
    my $body = shift;
    my $error = shift;
    my $job_id = shift;

    #my $base = OAR::IO::connect();
    #
    #OAR::IO::add_new_event($base,"MAIL_NOTIFICATION_ERROR",$job_id,"$error --> SMTP server used: $smtpServer, sender: $mailSenderAddress, recipients: $mailRecipientAddress, object: $object, body: $body");
    #
    #OAR::IO::disconnect($base);
    oar_debug("[Judas] Mail ERROR: $job_id $error --> SMTP server used: $smtpServer, sender: $mailSenderAddress, recipients: $mailRecipientAddress, object: $object, body: $body\n");
    exit(1);
}



# send mail to OAR admin
sub send_mail($$$$){
    my $mail_recipient_address = shift;
    my $object = shift;
    my $body = shift;
    my $job_id = shift;

    my $smtp_server = get_conf("MAIL_SMTP_SERVER");
    my $mail_sender_address = get_conf("MAIL_SENDER");
    if (!defined($smtp_server) || !defined($mail_sender_address) || !defined($mail_recipient_address)){
        oar_debug("[Judas] Mail is not configured\n");
        return();
    }

    $SIG{PIPE} = 'IGNORE';
    my $pid=fork;
    if ($pid == 0){
        $SIG{USR1} = 'IGNORE';
        $SIG{INT}  = 'IGNORE';
        $SIG{TERM} = 'IGNORE';
        my $smtp = Net::SMTP->new(  $smtp_server,
#                                    Host    => $smtp_server ,
                                    Timeout => 120 ,
                                    Hello   => hostname(),
                                    Debug   => 0
                                 )
            or treate_mail_error($smtp_server,$mail_sender_address,$mail_recipient_address,$object,$body,"No SMTP connexion",$job_id);
        $smtp->mail($mail_sender_address)
            or treate_mail_error($smtp_server,$mail_sender_address,$mail_recipient_address,$object,$body,"MAIL FROM",$job_id);
        my @recipients = split(',',$mail_recipient_address);
        $smtp->to(@recipients)
            or treate_mail_error($smtp_server,$mail_sender_address,$mail_recipient_address,$object,$body,"RCPT TO",$job_id);
        $smtp->data()
            or treate_mail_error($smtp_server,$mail_sender_address,$mail_recipient_address,$object,$body,"DATA",$job_id);
        $smtp->datasend("To: $mail_recipient_address\n")
            or treate_mail_error($smtp_server,$mail_sender_address,$mail_recipient_address,$object,$body,"Cannot send",$job_id);
        $smtp->datasend("Subject: $object\n")
            or treate_mail_error($smtp_server,$mail_sender_address,$mail_recipient_address,$object,$body,"Cannot send",$job_id);
        $smtp->datasend($body)
            or treate_mail_error($smtp_server,$mail_sender_address,$mail_recipient_address,$object,$body,"Cannot send",$job_id);
        $smtp->dataend()
            or treate_mail_error($smtp_server,$mail_sender_address,$mail_recipient_address,$object,$body,"DATA END",$job_id);
        $smtp->quit
            or treate_mail_error($smtp_server,$mail_sender_address,$mail_recipient_address,$object,$body,"QUIT",$job_id);
        exit(0);
    }
}


# Parse notify method and send an email or execute a command
# args: notify method string, frontal host, user, job id, job name, tag, comments
sub notify_user($$$$$$$$){
    my $base = shift;
    my $method = shift;
    my $host = shift;
    my $user = shift;
    my $job_id = shift;
    my $job_name = shift;
    my $tag = shift;
    my $comments = shift;

    return() if (!defined($method));

    if ($method =~ m/^\s*\[\s*(.+)\s*\]\s*(mail|exec)\s*:.+$/m){
        my $skip = undef;
        foreach my $t (split('\s*,\s*',$1)){
            $t =~ s/\s//g;
            if (uc($t) eq uc($tag)){
                $skip = 0;
            }else{
                $skip = 1 if (!defined($skip));
            }
        }
        return() if (defined($skip) and ($skip == 1));
    }

    if ($method =~ m/^.*mail\s*:(.+)$/m){
        OAR::IO::add_new_event($base,"USER_MAIL_NOTIFICATION",$job_id,"[Judas] Send a mail to $1 --> $tag");
        send_mail($1,"*OAR* [$tag]: $job_id ($job_name) on $Instance_name",$comments,$job_id);
    }elsif($method =~ m/^.*exec\s*:([a-zA-Z0-9_.\/ -]+)$/m){
        my $cmd = "$Openssh_cmd -x -T $host OARDO_BECOME_USER=$user oardodo $1 $job_id $job_name $tag \\\"$comments\\\" > /dev/null 2>&1";
        $SIG{PIPE} = 'IGNORE';
        my $pid = fork();
        if ($pid == 0){
            undef($base);
            $SIG{USR1} = 'IGNORE';
            $SIG{INT}  = 'IGNORE';
            $SIG{TERM} = 'IGNORE';
            my $exit_value;
            my $signal_num;
            my $dumped_core;
            my $ssh_pid;
            eval{
                $SIG{ALRM} = sub { die "alarm\n" };
                alarm(OAR::Tools::get_ssh_timeout());
                $ssh_pid = fork();
                if ($ssh_pid == 0){
                    exec($cmd);
                    warn("[ERROR] Cannot find $cmd\n");
                    exit(-1);
                }
                my $wait_res = 0;
                # Avaoid to be disrupted by a signal
                while ($wait_res != $ssh_pid){
                    $wait_res = waitpid($ssh_pid,0);
                }
                alarm(0);
                $exit_value  = $? >> 8;
                $signal_num  = $? & 127;
                $dumped_core = $? & 128;
            };
            if ($@){
                if ($@ eq "alarm\n"){
                    if (defined($ssh_pid)){
                        my ($children,$cmd_name) = OAR::Tools::get_one_process_children($ssh_pid);
                        kill(9,@{$children});
                    }
                    my $dbh = OAR::IO::connect();
                    my $str = "[Judas] User notification failed: ssh timeout, on node $host (cmd: $cmd)";
                    oar_error("$str\n");
                    OAR::IO::add_new_event($dbh,"USER_EXEC_NOTIFICATION_ERROR",$job_id,"$str");
                    OAR::IO::disconnect($dbh);
                }
            }else{
                my $dbh = OAR::IO::connect();
                my $str = "[Judas] Launched user notification command: $cmd; exit value = $exit_value, signal num = $signal_num, dumped core = $dumped_core";
                oar_debug("$str\n");
                OAR::IO::add_new_event($dbh,"USER_EXEC_NOTIFICATION",$job_id,"$str");
                OAR::IO::disconnect($dbh);
            }
            # Exit from child
            exit(0);
        }elsif (!defined($pid)){
            oar_error("[Judas] Error when forking process to execute notify user command: $cmd\n");
        }
    }else{
        oar_debug("[Judas] No correct notification method found ($method) for the job $job_id\n");
    }
}

return(1);
