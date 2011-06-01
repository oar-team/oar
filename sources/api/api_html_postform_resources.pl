$POSTFORM="
<FORM METHOD=post ACTION=$apiuri/resources/generate.html>
<TABLE>
<CAPTION>Resources generation</CAPTION>
<TR>
  <TD>Resources</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=resources VALUE=\"/nodes=node-{2}/cpu={2}/core={2}\"></TD>
</TR><TR>
  <TD>Properties</TD>
  <TD><INPUT TYPE=text SIZE=40 NAME=properties VALUE=\"besteffort=YES\">(commas separated)</TD>
</TR><TR>
  <TD></TD><TD><INPUT TYPE=submit VALUE=SUBMIT></TD>
</TR>
</TABLE>
</FORM>
"

