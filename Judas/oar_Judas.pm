package oar_Judas;
require Exporter;
# this module allows to log on a file and stdout with three different level

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


#Get log level in oar.conf file
init_conf("oar.conf");
my $logLevel = get_conf("LOG_LEVEL");
if (!defined($logLevel)){
    $logLevel = 2;
}
my $logFile = get_conf("LOG_FILE");
if (!defined($logFile)){
    $logFile = "/var/log/oar.log";
}
my $mail_recipient = get_conf("MAIL_RECIPIENT");

# this function writes both on the stdout and in the log file
sub write_log($){
    my $str = shift;
    #print("$str");
    if (-w $logFile){
        open(LOG,">>$logFile");
        print(LOG "$str");
        close(LOG);
    }
}

sub oar_warn($){
    my $string = shift;
    
    if ($logLevel >= 2){
        my ($seconds, $microseconds) = gettimeofday();
        $microseconds = sprintf("%06d",$microseconds);
        $string = "[".strftime("%F %T",localtime($seconds)).".$microseconds] $string";
        print("$string");
        write_log("[info] $string");
        send_mail($mail_recipient, "OAR Info on ".hostname()." : ".substr($string,0,70),$string);
    }
}

sub oar_debug($){
    my $string = shift;
    
    if ($logLevel >= 3){
        my ($seconds, $microseconds) = gettimeofday();
        $microseconds = sprintf("%06d",$microseconds);
        $string = "[".strftime("%F %T",localtime($seconds)).".$microseconds] $string";
        write_log("[debug] $string");
    }
}

sub oar_error($){
    my $string = shift;
    my ($seconds, $microseconds) = gettimeofday();
    $microseconds = sprintf("%06d",$microseconds);
    $string = "[".strftime("%F %T",localtime($seconds)).".$microseconds] $string";
    print("$string");
    write_log("[error] $string");
    send_mail($mail_recipient, "OAR Error on ".hostname()." : ".substr($string,0,70),$string);
}


# Must be only used in the fork of the send_mail function to store errors in OAR DB
sub treate_mail_error($$$$$$){
    my $smtpServer = shift;
    my $mailSenderAddress = shift;
    my $mailRecipientAddress = shift;
    my $object = shift;
    my $body = shift;
    my $error = shift;

    my $base = iolib::connect();

    iolib::add_new_event($base,"MAIL_NOTIFICATION",0,"$error --> SMTP server used : $smtpServer, sender : $mailSenderAddress, recipients : $mailRecipientAddress, object : $object, body : $body");

    iolib::disconnect($base);
    exit(1);
}



# send mail to OAR admin
# arg1 --> object
# arg2 --> body
sub send_mail($$$){
    my $mailRecipientAddress = shift;
    my $object = shift;
    my $body = shift;

    my $smtpServer = get_conf("MAIL_SMTP_SERVER");
    my $mailSenderAddress = get_conf("MAIL_SENDER");
    if (!defined($smtpServer) || !defined($mailSenderAddress) || !defined($mailRecipientAddress)){
        oar_debug("[Judas] Mail is not configured\n");
        return();
    }

    my $pid=fork;
    if ($pid == 0){
        my $smtp = Net::SMTP->new(  Host    => $smtpServer ,
                                    Timeout => 120 ,
                                    Hello   => hostname(),
                                    Debug   => 0
                                 )
            or treate_mail_error($smtpServer,$mailSenderAddress,$mailRecipientAddress,$object,$body,"No SMTP connexion");
        $smtp->mail($mailSenderAddress)
            or treate_mail_error($smtpServer,$mailSenderAddress,$mailRecipientAddress,$object,$body,"MAIL FROM");
        my @recipients = split(',',$mailRecipientAddress);
        $smtp->to(@recipients)
            or treate_mail_error($smtpServer,$mailSenderAddress,$mailRecipientAddress,$object,$body,"RCPT TO");
        $smtp->data()
            or treate_mail_error($smtpServer,$mailSenderAddress,$mailRecipientAddress,$object,$body,"DATA");
        $smtp->datasend("To: $mailRecipientAddress\n")
            or treate_mail_error($smtpServer,$mailSenderAddress,$mailRecipientAddress,$object,$body,"Cannot send");
        $smtp->datasend("Subject: $object\n")
            or treate_mail_error($smtpServer,$mailSenderAddress,$mailRecipientAddress,$object,$body,"Cannot send");
        $smtp->datasend($body)
            or treate_mail_error($smtpServer,$mailSenderAddress,$mailRecipientAddress,$object,$body,"Cannot send");
        $smtp->dataend()
            or treate_mail_error($smtpServer,$mailSenderAddress,$mailRecipientAddress,$object,$body,"DATA END");
        $smtp->quit
            or treate_mail_error($smtpServer,$mailSenderAddress,$mailRecipientAddress,$object,$body,"QUIT");
        exit(0);
    }
}


# Parse notify method and send an email or execute a command
# args : notify method string,user , job id, job name, tag, commentaries
sub notify_user($$$$$$){
    my $method = shift;
    my $user = shift;
    my $job_id = shift;
    my $job_name = shift;
    my $tag = shift;
    my $comments = shift;

    if ($method =~ m/^\s*mail:(.+)$/m){
        my $base = iolib::connect();
        iolib::add_new_event($base,"USER_MAIL_NOTIFICATION",$job_id,"[Judas] Send a mail to $1 --> $tag");
        iolib::disconnect($base);
        send_mail($1,"-OAR- $tag: $job_id($job_name)",$comments);
    }elsif($method =~ m/\s*exec:(.+)$/m){
        my $cmd = "sudo -H -u $user '$1 $job_id $job_name $tag $comments'";
        my $pid;
        $pid = fork();
        if (defined($pid)){
            system($cmd);
            my $exit_value  = $? >> 8;
            my $signal_num  = $? & 127;
            my $dumped_core = $? & 128;
            my $base = iolib::connect();
            iolib::add_new_event($base,"USER_EXEC_NOTIFICATION",$job_id,"[Judas] Launched user notification command : $cmd; exit value = $exit_value, signal num = $signal_num, dumped core = $dumped_core");
            iolib::disconnect($base);
        }else{
            oar_error("[Judas] Error when forking process to execute noty user command : $cmd; Not enough resources???\n");
        }
    }else{
        oar_error("[Judas] Notification error when parsing $method for the job $job_id\n");
    }
}

return 1;
