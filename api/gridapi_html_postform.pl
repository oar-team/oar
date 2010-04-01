$POSTFORM="
<FORM METHOD=post ACTION=$apiuri/grid/jobs.html>
<TABLE>
<CAPTION>Grid job submission</CAPTION>
<TR>
  <TD>Resources</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=resources VALUE=\"grenoble:rdef='/nodes=2',rennes:rdef='/cpu=1'\"></TD>
</TR><TR>
  <TD>Walltime</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=walltime VALUE=\"01:00:00\"></TD>
</TR><TR>
  <TD>Program to run</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=program VALUE=\"/bin/sleep 300\"></TD>
</TR><TR>
  <TD>Continue if rejected</TD>
  <TD><INPUT TYPE=checkbox NAME=FORCE></TD>
</TR><TR>
  <TD>Types</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=type></TD>
</TR><TR>
  <TD>Start date</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=start_date></TD>
</TR><TR>
  <TD>Directory</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=directory></TD>
</TR><TR>
  <TD>Verbose output</TD>
  <TD><INPUT TYPE=checkbox NAME=verbose></TD>
</TR><TR>
  <TD></TD><TD><INPUT TYPE=submit VALUE=SUBMIT></TD>
</TR>
</TABLE>
</FORM>
"

