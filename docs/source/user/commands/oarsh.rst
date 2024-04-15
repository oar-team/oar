oarsh & oarcp
-------------

Use oarsh to connect to a node from the job submission frontend of the cluster or any other node.

Use oarcp to copy files from a node or to a node.

Examples
::
   oarsh node-23

Connect from within our job, from one node to another one (node23).
:: 
   OAR_JOB_ID=4242 oarsh node-23

Connect to a node (node23) of our job (Id: 4242) from the frontal of the cluster.
:: 
   OAR_JOB_KEY_FILE=~/my_key oarsh node-23

Connect to a node (node23) of our job that was submitted using a job-key.
:: 
   oarsh -i ~/my_key node-23
 
Same thing but using OpenSSH-like *-i*  option.
