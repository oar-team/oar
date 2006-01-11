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
        my $smtp = Net::SMTP->new($smtpServer, Timeout => 240);
        if (defined($smtp)){
            $smtp->mail($mailSenderAddress);
            $smtp->to($mailRecipientAddress);
            $smtp->data();
            $smtp->datasend("Subject: $object\n");
            $smtp->datasend($body);
            $smtp->quit;
        }
        exit(0);
    }
}

return 1;
