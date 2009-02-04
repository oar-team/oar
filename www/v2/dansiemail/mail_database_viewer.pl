#!/usr/bin/perl

# Dansie Mail database viewer
# By Dansie Website Design
# http://www.dansie.net
# 6/22/2002
# 4/27/2004 - Entry deletion feature added. Be advised that there is no file locking.
#             If another script appends to the database while this script is removing an entry,
#             the new entry may be lost.
# 4/27/2004 - Navigation feature added.
# 5/11/2004 - Password feature added.

# If information in your database is of a sensitive nature such as credit card data, SSL is advised.
# Set the $append_to_database variable in the dansiemail.pl script.
# Point your browser at this script and you can view all your email as recorded in the database log.

######################################################
# Variables to set:

# Set this variable with the system path that the dansiemail.pl script is appending info to.
$database = 'tell_a_friend_log.txt';

# Your database's field delimiter.
$field_delimiter = '\|';

# URL to this script
$url = "http://www.YourName.com/cgi-bin/mail_database_viewer.pl";

# Maximum number of entries to display per page.
$display = 5;

# Change your password now!!!
$password = "abcd1234";


######################################################


&parse_form_data;



######################################################
# Check password
if ($FORM{pw} ne $password)
{
   print "Content-Type: text/html\n\n";
   print <<PASSWORD;

   Password:

   <FORM ACTION=$url METHOD=post>
   <INPUT TYPE=password NAME=pw SIZE=10>
   <INPUT TYPE=SUBMIT VALUE="Log in">
   </FORM>

PASSWORD

   exit;
}


######################################################
# Open database

$record_separator = chr(20);

open(FILE,"$database");
@lines=<FILE>;
close(FILE);




######################################################
# Delete an entry from the database
if ($FORM{delete})
{
   $n = 0;
   foreach $line (@lines)
   {
      if ($n != $FORM{entry})
      {
         push(@lines2,$line);
      }
      $n++;
   }

   @lines = @lines2;

   $whole_database = join("",@lines);

   open(FILE,">$database");
   print FILE "$whole_database";
   close(FILE);
}





######################################################
# Display database
{
   print "Content-Type: text/html\n\n";
   print "<FONT FACE=\"Courier New\">Dansie Email database viewer.<BR>\n\n";


   ######################################################
   # Navigation toolbar

   $total_lines_in_database = @lines;

   if ( $FORM{begin} + $display <= $total_lines_in_database )
   {
      $next = $FORM{begin} + $display;
   }
   if ( $FORM{begin} - $display >= 0 )
   {
      $previous = $FORM{begin} - $display;
   }

   $last_entry_on_page = $FORM{begin} + $display;
   if ( $last_entry_on_page > $total_lines_in_database )
   {
      $last_entry_on_page = $total_lines_in_database;
   }

   $first_entry_on_page = $FORM{begin} + 1;

   if ( $first_entry_on_page == 1 )
   {
      $previous_button = "";
   }
   else
   {
      $previous_button = "<INPUT TYPE=SUBMIT NAME=display VALUE=\"<-- Previous $display entries\">";
   }

   if ( $first_entry_on_page + $display > $total_lines_in_database )
   {
      $next_button = "";
   }
   else
   {
      $next_button = "<INPUT TYPE=SUBMIT NAME=display VALUE=\"Next $display entries -->\">";
   }

   print <<FORM;
   <BR><BR>
   <B>Showing entries $first_entry_on_page - $last_entry_on_page of $total_lines_in_database</B><BR>
   <TABLE BORDER=0><TR><TD WIDTH=150>
   <FORM ACTION=$url METHOD=POST>
   <INPUT TYPE=HIDDEN NAME="begin" VALUE="$previous">
   $previous_button
   <INPUT TYPE=HIDDEN NAME="pw" VALUE="$FORM{pw}">
   </FORM>
   </TD><TD WIDTH=150>
   <FORM ACTION=$url METHOD=POST>
   <INPUT TYPE=HIDDEN NAME="begin" VALUE="$next">
   $next_button
   <INPUT TYPE=HIDDEN NAME="pw" VALUE="$FORM{pw}">
   </FORM>
   </TD></TR></TABLE>

FORM


   print <<FORM;
   <FORM ACTION=$url METHOD=POST>
   <B>Jump to entry #</B> 
   <SELECT NAME="begin">
FORM

   for($i=0;$i<$total_lines_in_database;$i+=$display)
   {
      $jump_begin = $i + 1;
      print "<OPTION VALUE=\"$i\">$jump_begin\n";
   }

   print <<FORM;
   </SELECT>
   <INPUT TYPE=SUBMIT NAME=display VALUE="GO">
   <INPUT TYPE=HIDDEN NAME="pw" VALUE="$FORM{pw}">
   </FORM>
   </FONT>
   <BR>
   <HR>
FORM





   ######################################################
   # Display database entries within range
   $n = 0;
   foreach $line (@lines)
   {

      if ( $n >= $FORM{begin} && $n < ($FORM{begin} + $display) )
      {
         (@fields) = split(/$field_delimiter/,$line);

        $entry_number = $n + 1;
        print "<B>Entry #$entry_number</B><BR>\n";

        foreach $field (@fields)
         {
               $field =~ s/$record_separator/<BR>\n/g;
               $field =~ s/</&lt;/g;
               print "$field<BR>\n";
         }
         print <<FORM;
         <FORM ACTION=$url METHOD=POST>
         <INPUT TYPE=HIDDEN NAME="entry" VALUE="$n">
         <INPUT TYPE=HIDDEN NAME="begin" VALUE="$n">
         <INPUT TYPE=SUBMIT NAME="delete" VALUE="Delete this entry" onClick=\"return confirm('Delete this entry?');\">
         <INPUT TYPE=HIDDEN NAME="pw" VALUE="$FORM{pw}">
         </FORM>
         <HR>
FORM
      }
      $n++;
   }






   exit;
}




#######################################################
sub parse_form_data
{
   read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
   # Split the name-value pairs
   @pairs = split(/&/, $buffer);
   foreach $pair (@pairs)
   {
      ($name, $value) = split(/=/, $pair);
      $value =~ tr/+/ /;
      $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
      $value =~ s/~!/ ~!/g;
      $value =~ s/\|/ /g;
      $value =~ s/\^/ /g;
      $FORM{$name} = $value;
   }
}




