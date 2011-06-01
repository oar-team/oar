package mailer;

# BE CAREFULL : This module creates a child process for each senMail call and they are not waited.
# So it is a background mail sending system.
# Moreover each child process will become zombie, so you must consider this in your code (you must
# launch waitpid to delete these zombies or make $SIG{CHLD} = 'IGNORE' ). As you want...

use Data::Dumper;
use warnings;
use strict;
use Net::SMTP;

# arg1 --> adress of the smtp server
# arg2 --> mail sender address
# arg3 --> mail recipient address
# arg4 --> mail object 
# arg5 --> mail body
sub sendMail($$$$$){
    my $smtpServer = shift;
    my $mailSenderAddress = shift;
    my $mailRecipientAddress = shift;
    my $object = shift;
    my $body = shift;

    my $pid=fork;
    if ($pid == 0){
        print("[MAILER] I send a mail to $mailRecipientAddress with the sender $mailSenderAddress on the server $smtpServer\n");
        my $smtp = Net::SMTP->new($smtpServer, Timeout => 240);
        if (!defined($smtp)){
            my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
            $year += 1900;
            $mon += 1;
            #if (open(FILE, ">> /tmp/ERROR_OAR_GRID_MAILER.log")){
                my $str = "Can not send an email to $mailRecipientAddress from $mailSenderAddress; Object : $object ;; Body : $body";
                print(STDERR "[MAILER] [$year-$mon-$mday $hour:$min:$sec] $str\n");
                #print("[ERROR MAILER] $str\n");
            #    close(FILE);
            #}
        }else{
            $smtp->mail($mailSenderAddress);
            $smtp->to($mailRecipientAddress);
            $smtp->data();
            $smtp->datasend("Subject: $object\n");
            $smtp->datasend($body);
            $smtp->quit;
            #print("Mailer OK\n");
        }
        exit(0);
    }
}

return 1;

