Dansie Mail 1.09
By Dansie Website Design
http://www.dansie.net
8/26/01
Works on Unix/Linux hosted sites that have sendmail
and Windows hosted sites that have Windmail or Blat.
Also works with a server's email socket.
May be used free of charge. There is no copyright. Feel free to edit.

### INSTALLATION INSTRUCTIONS ###

1. For Unix servers, set the first 2 variables inside the dansiemail.pl script.
   If using Windmail or Blat, set the $temp_file variable also.
   If using Blat, $smtp_server may also need to be set.
2. Upload the dansiemail.pl script in ASCII format to your cgi-bin.
3. For Unix, chmod dansiemail.pl 755 so that it will execute.
   For Windows, set write permissions on the $temp_file.
4. Replace the URL in the FORM tag of the BASIC FORM below 
   with the URL to your dansiemail.pl script.
5. Put a URL of your choice in the value of the hidden "redirect" tag.
   The use of the "redirect" and "required" hidden tags are optional.
   The email address field is required by default.
6. Copy and paste the basic form below into one of your web pages.


####### BASIC FORM ########

<FORM ACTION="http://www.YourName.com/cgi-bin/dansiemail.pl" METHOD=POST>
Name: <INPUT TYPE=TEXT NAME="name"><BR>
Email: <INPUT TYPE=TEXT NAME="email"><BR>
Subject: <INPUT TYPE=TEXT NAME="subject"><BR>
Message:<BR>
<TEXTAREA COLS=80 ROWS=10 NAME="body" WRAP></TEXTAREA><BR>
<INPUT TYPE=SUBMIT VALUE="Send Email">
<INPUT TYPE=HIDDEN NAME="required" VALUE="email,name,body">
<INPUT TYPE=HIDDEN NAME="redirect" VALUE="http://www.dansie.net/">
</FORM>


###### OTHER EXAMPLES ######

You could also use this SELECT menu in place of the subject TEXT tag above.

Subject: <SELECT NAME="subject">
<OPTION>Question
<OPTION>Comment
<OPTION>Support
<OPTION>Sales
</SELECT>

The script can accept custom form variables and values and email them to you
in the body of the email. This allows you to make large custom forms.
Use only letters, numbers and underscores for variable names. Some examples:

How do you rate this website?
<SELECT NAME="WebSite_Rating">
<OPTION>Best website I've ever seen
<OPTION>Awesome!
<OPTION>Don't give up your day job
</SELECT>

Your pet's name:
<INPUT TYPE=TEXT NAME="Pets_Name">

You can make the "Pets_Name" field required like so:

<INPUT TYPE=HIDDEN NAME="required" VALUE="email,name,Pets_Name">

Yes I would like to subscribe to the monthly newsletter!
<INPUT TYPE=CHECKBOX NAME="Newsletter" VALUE="Sign me up!">


###### VARIABLE NAMES OF STATIC FIELD POSITIONS ######

The first 8 standard fields that appear in the database are: name,email,subject,body,resolved IP address,IP address,browser and OS,date. These field positions wont change, even if you don't use all of them in your forms. The script can expect and make static field positions for your custom variable names in the database, even if they are blank positions due to a user not submitting data for a particular field. This will also control the order in which the custom variables appear in the emails. This consistency can help when importing the database into another program. So not only will the script send the email with the data appearing in a certain order, but also have fixed field positions in the database.


