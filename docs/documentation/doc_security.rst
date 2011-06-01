Security aspects in OAR
=======================

In OAR2, security and user switching is managed by the "oardodo" script.
It is a suid script executable only by root and the oar group members that
is used to launch a command, a terminal or a script with
the privileges of a particular user.
When "oardodo" is called, it checks the value of an environment variable: 
OARDO_BECOME_USER.

  - If this variable is empty, "oardodo" will execute the command with the 
    privileges of the superuser (root).
  - Else, this variable contains the name of the user that will be used to 
    execute the command.


Here are the scripts/modules where "oardodo" is called and which user is used 
during this call:

  - OAR::Modules::Judas:
	  this module is used for logging and notification.
	  
    * user notification: email or command execution.OARDO_BECOME_USER = user

  - oarsub:
	  this script is used for submitting jobs or reservations.
	  
    * read user script
    * connection to the job and the remote shell
    * keys management
    * job key export

	  for all these functions, the user used in the OARDO_BECOME_USER variable is
	  the user that submits the job.
	
  - pingchecker:
	  this module is used to check resources health. Here, the user is root.
	  
  - oarexec: 
	  executed on the first reserved node, oarexec executes the job prologue and 
	  initiate the job.
	  
    * the "clean" method kills every oarsub connection process in superuser mode
    * "kill_children" method kills every child of the process in superuser mode
    * execution of a passive job in user mode
    * getting of the user shell in user mode
    * checkpointing in superuser mode


  - job_resource_manager:
	  The job_resource_manager script is a perl script that oar server deploys on 
	  nodes to manage cpusets, users, job keys...
	  
    * cpuset creation and clean is executed in superuser mode

  - oarsh_shell: 
	  shell program used with the oarsh script. It adds its own process in the 
	  cpuset and launches the shell or the script of the user.
	  
    * cpuset filling, "nice" and display management are executed as root.
    * TTY login is executed as user.

  - oarsh:
	  oar's ssh wrapper to connect from node to node. It contains all the context 
	  variables usefull for this connection.
	  
    * display management and connection with a user job key file are executed 
 		  as user.
 		  
