package oar_Judas;
require Exporter;
# this module allows to log on a file and stdout with three different level
# $Id$

use strict;
use Data::Dumper;
use oar_conflib qw(init_conf get_conf is_conf);
use Net::SMTP;
use Sys::Hostname;
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday);
use oar_iolib;
use oar_Tools;

require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(oar_warn oar_debug oar_error);

$| = 1;

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
my $mail_recipient = get_conf("MAIL_RECIPIENT");

my $Openssh_cmd = get_conf("OPENSSH_CMD");
$Openssh_cmd = oar_Tools::get_default_openssh_cmd() if (!defined($Openssh_cmd));


# this function redirect STDOUT and STDERR into the log file
# return the pid of the fork process
sub redirect_everything(){
    return() if (! is_conf("LOG_FILE"));
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
}

# this function writes both on the stdout and in the log file
sub write_log($){
    my $str = shift;
    if (open(LOG,">>$log_file")){
        print(LOG "$str");
        close(LOG);
    }else{
        print("$str");
    }
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
        send_mail(undef,$mail_recipient, "Info: ".substr($string,0,70),$string,0);
    }
}

sub oar_error($){
    my $string = shift;
    my ($seconds, $microseconds) = gettimeofday();
    $microseconds = int($microseconds / 1000);
    $microseconds = sprintf("%03d",$microseconds);
    $string = "[".strftime("%F %T",localtime($seconds)).".$microseconds] $string";
    write_log("[error] $string");
    send_mail(undef,$mail_recipient, "Error: ".substr($string,0,70),$string,0);
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

    my $base = iolib::connect();

    iolib::add_new_event($base,"MAIL_NOTIFICATION_ERROR",$job_id,"$error --> SMTP server used : $smtpServer, sender : $mailSenderAddress, recipients : $mailRecipientAddress, object : $object, body : $body");

    iolib::disconnect($base);
    exit(1);
}



# send mail to OAR admin
# arg1 --> object
# arg2 --> body
sub send_mail($$$$$){
    my $base = shift;
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
        undef($base);
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
# args : DB ref, notify method string, frontal host, user, job id, job name, tag, commentaries
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

    if ($method =~ m/^\s*mail:(.+)$/m){
        iolib::add_new_event($base,"USER_MAIL_NOTIFICATION",$job_id,"[Judas] Send a mail to $1 --> $tag");
        my $server_hostname = hostname();
        send_mail($base,$1,"*OAR* [$tag]: $job_id ($job_name) on $server_hostname",$comments,$job_id);
    }elsif($method =~ m/\s*exec:(.+)$/m){
        my $cmd = "$Openssh_cmd -x -T $host sudo -H -u $user '$1 $job_id $job_name $tag \"$comments\"' > /dev/null 2>&1";
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
                alarm(oar_Tools::get_ssh_timeout());
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
                        my ($children,$cmd_name) = oar_Tools::get_one_process_children($ssh_pid);
                        kill(9,@{$children});
                    }
                    my $dbh = iolib::connect();
                    my $str = "[Judas] User notification failed : ssh timeout, on node $host (cmd : $cmd)";
                    oar_error("$str\n");
                    iolib::add_new_event($dbh,"USER_EXEC_NOTIFICATION_ERROR",$job_id,"$str");
                    iolib::disconnect($dbh);
                }
            }else{
                my $dbh = iolib::connect();
                my $str = "[Judas] Launched user notification command : $cmd; exit value = $exit_value, signal num = $signal_num, dumped core = $dumped_core";
                oar_debug("$str\n");
                iolib::add_new_event($dbh,"USER_EXEC_NOTIFICATION",$job_id,"$str");
                iolib::disconnect($dbh);
            }
            # Exit from child
            exit(0);
        }elsif (!defined($pid)){
            oar_error("[Judas] Error when forking process to execute notify user command : $cmd\n");
        }
    }else{
        oar_debug("[Judas] No correct notification method found ($method) for the job $job_id\n");
    }
}

return(1);
