$POSTFORM="
<FORM METHOD=post ACTION=$apiuri/jobs.html>
<TABLE>
<CAPTION>Job submission</CAPTION>
<TR>
  <TD>Resources</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=resource VALUE=\"/nodes=1/cpu=1,walltime=00:30:00\"></TD>
</TR><TR>
  <TD>Name</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=name VALUE=\"Test_job\"></TD>
</TR><TR>
  <TD>Properties</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=property VALUE=\"\"></TD>
</TR><TR>
  <TD>Program to run</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=command VALUE='\"/bin/sleep 300\"'></TD>
</TR><TR>
  <TD>Types</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=type></TD>
</TR><TR>
  <TD>Reservation dates</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=reservation></TD>
</TR><TR>
  <TD>Directory</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=directory></TD>
</TR><TR>
  <TD></TD><TD><INPUT TYPE=submit VALUE=SUBMIT></TD>
</TR>
</TABLE>
</FORM>
"

