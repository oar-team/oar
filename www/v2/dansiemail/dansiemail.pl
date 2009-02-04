#!/usr/bin/perl

# Dansie Mail 1.09
# By Dansie Website Design
# http://www.dansie.net

# 08/26/01 Version 1.00. Works on Unix/Linux hosted sites that have
#                        sendmail.
# 05/06/02 Version 1.01. Updated to accept any variable name and value
#                        from a form and include them in the email 
#                        body. New "required" and "redirect" fields 
#                        and append to email log file.
# 05/14/02 Version 1.02. Works with Windmail and Blat on Windows servers.
# 01/12/03 Version 1.04. Preserves line breaks in the database with char
#                        20 () instead of space characters.
# 04/17/03 Version 1.05. Works with a server's email socket.
# 04/21/03 Version 1.06. Tries to auto detect sendmail program.
# 12/09/03 Version 1.07. Prevents abuse from website visitors by logging
#                        their IP address and limiting the number of 
#                        times they are allowed to access the script 
#                        according to the maximum number of times you 
#                        set. Will yield a 500 Internal Server Error 
#                        after maximum is met. Delete the IP log file
#                        to continue running tests with the script or 
#                        disable the $ip_log variable below.
# 12/10/03 Version 1.08. Filters allows you to redirect messages
#                        containing certain words to an alternate email
#                        address.
# 11/17/04 Version 1.09. Allows you to define static field positions for
#                        specific custom variable names.

# May be used free of charge. There is no copyright. Feel free to edit.
# Need help with installation or customization? Visit:
# http://www.dansie.net/mail.html


#######################################################
# Variables

$HeadSubject ='[oar]';


# Put the exact system path to your host's sendmail program here.
# Examples: '/usr/sbin/sendmail' or 'C:/winnt/system32/windmail.exe' or 'C:/winnt/system32/blat.exe'.
# Can also work with a server's socket on both Unix and Windows servers. Example: 'socket|mail.yourdomain.com'.
# Put "socket", then a pipe character "|" followed by your server's SMTP address.
$sendmail_path = '';

# Put your email address here. Use single quotes as you see below.
# You may insert more than one email address separated by commas.
# Or you may use no email address and merely have the script append to the database file.
$email = 'auguste@imag.fr';

# System path to a temp file if using Windmail or Blat on a Windows server.
# Make sure permissions on this file are set to writable.
# Example: 'c:/system/path/to/temp.txt'
$temp_file = '';

# SMTP server. Sometimes needs to be set if using Blat.
# Example: 'mail.server.com'. Your host will know what the Blat server address is, if needed.
$smtp_server = 'smtp.free.fr';


#######################################################
# Variables for bonus features!

# Optional email log. Set this variable to a system path of a file you want the script to record all submitted info to.
$append_to_database = '/tmp/oar_mail_log.txt';

# Set with variable names that you would like to have static field positions like so:
# @variable_names_of_static_field_positions = ("color","size","weight");
# Or you may leave this blank to disable and not utilize this feature. See ReadMe for more details.
@variable_names_of_static_field_positions = ();

# Set system path to your IP address log file. Make blank to disable this security feature.
$ip_log = '/tmp/oar_mail_log_ip_and_deny.txt';


# Set the maximum number of times you will allow users to use your script per day
# if using the $ip_log feature above.
$maximum_allow = 4;

# By setting this variable, if one of these words are found in the message, Dansie Mail will send
# the message to the alternate email address that you specify below. Can be used as a filter for
# foul words, or for redirecting important emails. Examples:
# @filters = ("badword","foulword","unmentionable");
# @filters = ("ImportantCustomer@somewhere.com","ImportantPerson@VIP.com");
# To disable, leave blank like so:
# @filters = ();
@filters = ();

# To be used with the filters feature above.
$alternate_email = 'otherusername@YourDomain.net';


########################################################
# That's all. No need to edit anything below this line #
# But edit if you so desire at your own risk.          #
########################################################

$date = &get_date_time;

$ip_log_date = localtime(time);
$ip_log_date =~ s/(.+)( \d\d:\d\d:\d\d)(.+)/$1\,$3/;

#######################################################
# Main Program

if ( $ENV{'REQUEST_METHOD'} =~ /GET/i )
{
   print "Content-Type: text/html\n\n";
   print "<CENTER><SMALL>Dansie Mail - Free at <A HREF=\"http://www.dansie.net\">www.dansie.net</A></SMALL></CENTER>\n";
   exit;
}

&parse_form_data;

&filters if (@filters);

# Security check for headers
$FORM{'name'} =~ s/\r\n//g;
$FORM{'name'} =~ s/\n//g;
$FORM{'subject'} =~ s/\r\n//g;
$FORM{'subject'} =~ s/\n//g;

if ( $FORM{'required'} )
{
   (@required) = split(/\,/,$FORM{'required'});

   foreach (@required)
   {
      if (!$FORM{$_})
      {
         $blank_fields .= "$_<BR>\n";
      }
   }

   if ($blank_fields)
   {
      print "Content-Type: text/html\n\n";
      print <<ERROR;
      The following form fields were blank:
      <BLOCKQUOTE>
      $blank_fields
      </BLOCKQUOTE>
      Please go back and enter all required fields.
ERROR
      exit;
   }

}

if ( $email && $FORM{'email'} !~ /^([\w|\-|\.|\_]+)(\@)([\w|\-|\.|\_]+)(\.)(\w+)$/ )
{
   print "Content-Type: text/html\n\n";
   print <<ERROR;
   Please go back and enter a proper email address. A proper email address has a username, a domain and an extension.<BR>
   Example: yourname\@domain.com
ERROR
}
else
{
   &organize_custom_variables;

   # Abuse prevention. Just before appending to database and sending out email.
   # Need to allow for required fields above.
   if ($ip_log)
   {
      &log_ip($ip_log,$maximum_allow,$ip_log_date);
   }

   if ($append_to_database) { &append_to_database; }

   if ($email)
   {
      &verify_sendmail_path;
      &send_email;
   }

   if ($socket_output and $socket_output ne "1")
   {
      print "Content-Type: text/html\n\n";
      print "There was an error trying to connect to the server's email socket. Error message:<BR>";
      print "$socket_output";
      exit;
   }

   if ( $FORM{'redirect'} )
   {
      print "Location: $FORM{'redirect'}\n\n";
      exit;
   }
   else
   {
      print "Content-Type: text/html\n\n";
      print <<THANKYOU;
      Thank you, $FORM{'name'}, for sending us an email. We will reply to it shortly.<BR><BR>
      Here is what you wrote:<BR><BR>
      <HR>
      From: $FORM{'name'} &lt;$FORM{'email'}><BR>
      Subject: $FORM{'subject'}<BR>
      Message:<BR><BR>
     $FORM{'body'}<BR><BR>
THANKYOU

      # Print variables with static field positions.
      foreach $variable_name (@variable_names_of_static_field_positions)
      {
         print "$variable_name: $FORM2{$variable_name}<BR><BR>\n\n";
         delete($FORM3{$variable_name});
      }

      # Print remaining custom variables with no defined static field positions.
      foreach $variable_name (sort {$a cmp $b}  keys (%FORM3))
      {
         print "$variable_name: $FORM3{$variable_name}<BR><BR>\n\n";
      }
      print "<CENTER><SMALL>Dansie Mail - Free at <A HREF=\"http://www.dansie.net\">www.dansie.net</A></SMALL></CENTER>\n";
   }
}


#######################################################
sub send_email
{
   if ( $ENV{'REMOTE_HOST'} eq "$ENV{'REMOTE_ADDR'}" ) { &map_ip_addresses_to_domain_names; }

   ### Open mail program ###

   # Open temp file for windows mailers
   if ( $sendmail_path =~ /(windmail\.exe)$/i || $sendmail_path =~ /(blat\.exe)$/i )
   {
      open (MAIL, ">$temp_file");
   }
   # If socket, do nothing
   elsif ( $sendmail_path =~ /^(socket\|)/i )
   {
   }
   # Open output for Unix sendmail
   elsif ( $sendmail_path )
   {
      open (MAIL, "|$sendmail_path -t");
   }

   ### Headers ###

   # Windows mailer headers
   if ( ($sendmail_path =~ /(windmail\.exe)$/i) || ( $sendmail_path eq "windmail -t" ) )
   {
      print MAIL "From: $FORM{'email'}\n";
      print MAIL "To: $email\n";
      print MAIL "Subject: $FORM{'subject'}\n\n";
   }
   # If Blat, do nothing
   elsif ( $sendmail_path =~ /(blat\.exe)$/i )
   {
   }
   # If socket, do nothing
   elsif ( $sendmail_path =~ /^(socket\|)/i )
   {
   }
   # Unix sendmail headers
   elsif ( $sendmail_path )
   {
      print MAIL "From: $FORM{'name'} <$FORM{'email'}>\n";
      print MAIL "To: $email\n";
      print MAIL "Subject: $HeadSubject$FORM{'subject'}\n\n";
   }


   ### Make complete message body ###

   $complete_body .= "$FORM{'body'}\n\n";

   # Print variables with static field positions.
   foreach $variable_name (@variable_names_of_static_field_positions)
   {
      $complete_body .= "$variable_name: $FORM2{$variable_name}\n\n";
      delete($FORM3{$variable_name});
   }

   # Print remaining custom variables with no defined static field positions.
   foreach $variable_name (sort {$a cmp $b}  keys (%FORM3))
   {
      $complete_body .=  "$variable_name: $FORM3{$variable_name}\n\n";
   }


   $complete_body .= "---------------------------------------\n";
   $complete_body .= "Remote host:       $ENV{'REMOTE_HOST'}\n";
   $complete_body .= "Remote IP address: $ENV{'REMOTE_ADDR'}\n";
   $complete_body .= "Browser:           $ENV{'HTTP_USER_AGENT'}\n";
   $complete_body .= "Date and time:     $date\n";
   $complete_body .= "I Love Dansie Mail! Free at www.dansie.net\n";

   # Send output to Unix sendmail or file but not for socket.
   if ( $sendmail_path !~ /^(socket\|)/i )
   {
      print MAIL "$complete_body";
      close (MAIL);
   }


   ### Call misc mailers ###

   if ( $sendmail_path =~ /(blat\.exe)$/i )
   {
      if ($smtp_server)
      {
         $smtp_server = " -server \"$smtp_server\"";
      }
      # Security precaution. Prevents subject from being exploited.
      $FORM{'subject'} =~ s/\"//g;
      $FORM{'from'} =~ s/\"//g;
      $FORM{'from'} =~ s/\s//g;
      open(MAIL,"|$sendmail_path \"$temp_file\" -t $email -s \"$FORM{'subject'}\" -f $FORM{'email'}$smtp_server");
      close(MAIL);
   }

   if ( $sendmail_path =~ /(windmail\.exe)$/i )
   {
      system("\"$sendmail_path\" -t -t -n \"$temp_file\"");
   }

   if ( $sendmail_path =~ /^(socket\|)(.+)/i )
   {
      $smtp_server = "$2";
      $socket_output = &socket_email($email,$FORM{'email'},$FORM{'subject'},$complete_body,$smtp_server);
   }

}


#######################################################
sub parse_form_data
{
   if ($ENV{'OS'})
   {
      sysread(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
   }
   else
   {
      read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
   }
   # Split the name-value pairs
   @pairs = split(/&/, $buffer);
   foreach $pair (@pairs)
   {
      ($name, $value) = split(/=/, $pair);
      $value =~ tr/+/ /;
      $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
      $value =~ s/~!/ ~!/g;
      $FORM{$name} = $value;
   }
}


#######################################################
sub map_ip_addresses_to_domain_names
{
   if ( !$ENV{'REMOTE_HOST'} ) { $ENV{'REMOTE_HOST'} = "$ENV{'REMOTE_ADDR'}"; }
   $temp = $ENV{'REMOTE_HOST'};
   @numbers = split(/\./, $ENV{'REMOTE_HOST'});
   $ip_number = pack("C4", @numbers);
   ($ENV{'REMOTE_HOST'}) = (gethostbyaddr($ip_number, 2))[0];
   if (!$ENV{'REMOTE_HOST'}) { $ENV{'REMOTE_HOST'} = $temp; }
}


#######################################################
sub append_to_database
{
   $delimiter = '|';
   $delimiter2 = "\\" . "$delimiter";

   # Hash of standard 8 fields.
   %FORM_DB = %FORM;
   # Hash of custom fields possibly with defined static field positions.
   %FORM2_DB = %FORM2;
   # Hash of custom fields remaining with no static field positions.
   %FORM3_DB = %FORM2;

   foreach $variable_name (keys (%FORM_DB))
   {
      $FORM_DB{$variable_name} =~ s/$delimiter2/ /g;
   }

   foreach $variable_name (keys (%FORM2_DB))
   {
      $FORM2_DB{$variable_name} =~ s/$delimiter2/ /g;
   }

   # Print standard 8 variables.
   $database_entry = "$FORM_DB{'name'}$delimiter$FORM_DB{'email'}$delimiter$FORM_DB{'subject'}$delimiter$FORM_DB{'body'}$delimiter$ENV{'REMOTE_HOST'}$delimiter$ENV{'REMOTE_ADDR'}$delimiter$ENV{'HTTP_USER_AGENT'}$delimiter$date";

   # Print variables with static field positions.
   foreach $variable_name (@variable_names_of_static_field_positions)
   {
      $database_entry .= "$delimiter$FORM2_DB{$variable_name}";
      delete($FORM3_DB{$variable_name});
   }

   # Print remaining custom variables with no defined static field positions.
   foreach $variable_name (sort {$a cmp $b}  keys (%FORM3_DB))
   {
      $database_entry .= "$delimiter$FORM3_DB{$variable_name}";
   }

   $record_separator = chr(20);
   $database_entry =~ s/\r\n/$record_separator/g;
   $database_entry =~ s/\n/$record_separator/g;

   open(FILE,">>$append_to_database");
   print FILE "$database_entry\n";
   close(FILE);

}


#######################################################
sub get_date_time
{
   @date = localtime(time);
   $date[5] += 1900;
   foreach (@date)
   {
      if ( $_ < 10 ) { $_ = "0" . $_; }
   }
   $date[4] = (Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$date[4]];
   $date[6] = (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$date[6]];
   return "$date[6] $date[4] $date[3], $date[5] $date[2]:$date[1]:$date[0]";
}


#######################################################
sub organize_custom_variables
{
   %FORM2 = %FORM;
   delete($FORM2{'name'});
   delete($FORM2{'email'});
   delete($FORM2{'subject'});
   delete($FORM2{'body'});
   delete($FORM2{'required'});
   delete($FORM2{'redirect'});

   # Make a copy of custom variables to be used for static field positions.
   %FORM3 = %FORM2;
}



#######################################################
sub socket_email
{
   my $recipient = $_[0];
   my $emailfrom = $_[1];
   my $subject = $_[2];
   my $message = $_[3];
   my $smtp_server = $_[4];
   my $smtp_test = $_[5];

   ($x,$x,$x,$x, $here) = gethostbyname($null);
   ($x,$x,$x,$x, $there) = gethostbyname($smtp_server);
   my $thisserver = pack('S n a4 x8',2,0,$here);
   my $remoteserver = pack('S n a4 x8',2,25,$there);
   (!(socket(S,2,1,6))) && (return "Connect error! socket");
   (!(bind(S,$thisserver))) && (return "Connect error! bind");
   (!(connect(S,$remoteserver))) && (return "!! connection to $smtp_server has failed!");

   select(S);
   $| = 1;
   select(STDOUT);

   $DATA_IN = <S>;
   if ($DATA_IN !~ /^220/) { return "data in Connect error - 220"; }

   print S "HELO localhost\r\n";
   $DATA_IN = <S>;
   if ($DATA_IN !~ /^250/) { return "$DATA_IN - data in Connect error - 250"; }

   if ($smtp_test) { return "1"; }

   print S "MAIL FROM:<$emailfrom>\r\n";
   $DATA_IN = <S>;
   if ($DATA_IN !~ /^250/) { return "'From' address not valid"; }

   print S "RCPT TO:<$recipient>\r\n";
   $DATA_IN = <S>;
   if ($DATA_IN !~ /^250/) { return "'Recipient' address not valid"; }

   print S "DATA\r\n";
   $DATA_IN = <S>;
   if ($DATA_IN !~ /^354/) { return "Message send failed - 354"; }

   $message =~ s/\n/\r\n/g;
   print S "From: $emailfrom\r\nTo: $recipient\r\nSubject: $subject\r\n\r\n$message\r\n.\r\n";
   $DATA_IN = <S>;
   if ($DATA_IN !~ /^250/) { return "Message send failed - try again - 250"; }

   print S "QUIT\n";
   return "1";
}




#######################################################
sub verify_sendmail_path
{
   # If sendmail path is not defined or not accurate, try to find it.
   if ( !$sendmail_path || (!-e "$sendmail_path") )
   {
      @common_sendmail_paths = ("/usr/sbin/sendmail", "/usr/lib/sendmail", "/usr/bin/sendmail", "/bin/sendmail", "/var/qmail/bin/qmail-inject", "/bin/cgimail", "C:/winnt/system32/windmail.exe", "C:/winnt/system32/blat.exe", "c:/windmail/windmail.exe", 'C:\httpd\windmail\windmail.exe', 'C:\httpd\Blat\Blat.exe');

      foreach (@common_sendmail_paths)
      {
         if (-e "$_")
         {
            $sendmail_path = "$_";
            last;
         }
      }
   }

   # If still can't find a sendmail program, try SMTP socket.
   if ( !$sendmail_path )
   {
      @smtp_servers = ();
      if (!$ENV{SERVER_NAME})
      {
         $ENV{SERVER_NAME} = $ENV{HTTP_HOST};
         $ENV{SERVER_NAME} =~ s/^(www\.)//;
      }

      $temp = "mail." . $ENV{SERVER_NAME};
      push (@smtp_servers,$temp);
      $temp = "smtp." . $ENV{SERVER_NAME};
      push (@smtp_servers,$temp);
      push (@smtp_servers,$ENV{SERVER_ADDR});

      foreach (@smtp_servers)
      {
         $smtp_test = &socket_email(0,0,0,0,$_,"test");
         if ($smtp_test eq "1")
         {
            $sendmail_path = "socket|$_";
            last;
         }
      }
   }

   # If still can't find a sendmail program, issue error message.
   if ( !$sendmail_path )
   {
      print "Content-Type: text/html\n\n";
      print "No sendmail path set in \$sendmail_path variable. Email cannot be sent. Correctly set \$sendmail_path.<BR>\n";
      exit;
   }
   if ( $sendmail_path && $sendmail_path !~ /^(socket\|)/ && !-e "$sendmail_path" )
   {
      print "Content-Type: text/html\n\n";
      print "No sendmail program appears to exist at this system path: <B>$sendmail_path</B>. Correctly set \$sendmail_path.<BR>\n.";
      exit;
   }
}




##################################################################
sub log_ip
{
   # Declare local variables and get input.
   my ($ip_log,@lines,$ip,$deny,$date,$maximum_allow);
   ($ip_log,$maximum_allow,$date) = @_;

   # Open log
   open(FILE,"$ip_log");
   @lines=<FILE>;
   close(FILE);

   # See how many times this IP address has accessed this script.
   $deny = 0;
   if (!$ENV{'REMOTE_HOST'}) { $ENV{'REMOTE_HOST'} = "$ENV{'REMOTE_ADDR'}"; }
   foreach $ip (@lines)
   {
      chomp($ip);
      if ( $ENV{'REMOTE_HOST'} eq $ip ) { $deny++; }
   }

   # Flush log if a new day has come.
   chomp($lines[0]);
   if ( $lines[0] ne "$date" )
   {
      open(FILE,">$ip_log");
      print FILE "$date\n";
      close(FILE);
   }

   # Deny use of script if they have had too many repeat visits. Issue ambiguous 500 error message.
   if ( $deny >= $maximum_allow ) { exit; }

   # Append their IP address to the log and allow them to proceed.
   open(FILE,">>$ip_log");
   print FILE "$ENV{'REMOTE_HOST'}\n";
   close(FILE);
}


##################################################################
sub filters
{
   foreach $filter_word (@filters)
   {
      foreach $key (keys %FORM)
      {
         if ( $FORM{$key} =~ /$filter_word/i )
         {
            $email = $alternate_email;
         }
      }
   }
}

