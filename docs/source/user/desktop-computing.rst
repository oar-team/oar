Desktop computing
=================
If you want to compute jobs on nodes without SSH connections then this
feature is for you.

On the nodes you have to run "oar-agent.pl". This script polls the OAR
server via a CGI HTTP script.

Usage examples:
 - if you want to run a program that you know is installed on nodes::

    oarsub -t desktop_computing /path/to/program

   Then /path/to/program is run and the files created in the
   oar-agent.pl running directory is retrieved where oarsub was
   launched.

 - if you want to copy a working environment and then launch the program::

    oarsub -t desktop_computing -s . ./script.sh

   The content of "." is transfred to the node, "./script.sh" is run and
   everything will go back.
