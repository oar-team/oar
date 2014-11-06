Modules descriptions
====================

OAR can be decomposed into several modules which perform different tasks.

Almighty
--------

This module is the OAR server. It decides what actions must be performed. It
is divided into 3 processes:

 - One listens to a TCP/IP socket. It waits informations or commands from OAR
   user program or from the other modules.
   
 - Another one deals with commands thanks to an automaton and launch right
   modules one after one.

 - The third one handles a pool of forked processes that are used to launch and
   stop the jobs.
   
It's behaviour is represented in these schemes.
    
  - General schema:

  .. image:: ../schemas/almighty_automaton_general.png
  
When the Almighty automaton starts it will first open a socket and creates a 
pipe for the process communication with it's forked son. Then, Almighty will 
fork itself in a process called "appendice" which role is to listen to incoming 
connections on the socket and catch clients messages. These messages will be
thereafter piped to Almighty. Then, the automaton will change it's state
according to what message has been received. 
  
--------------------------------------------------------------------------------

  - Scheduler schema:

  .. image:: ../schemas/almighty_automaton_scheduler_part.png
  
--------------------------------------------------------------------------------

  - Finaud schema: 

  .. image:: ../schemas/almighty_automaton_finaud_part.png
  
--------------------------------------------------------------------------------

  - Leon schema:

  .. image:: ../schemas/almighty_automaton_leon_part.png
  
--------------------------------------------------------------------------------

  - Sarko schema:
      
  .. image:: ../schemas/almighty_automaton_villains_part.png
  
--------------------------------------------------------------------------------

  - ChangeNode schema:

  .. image:: ../schemas/almighty_automaton_changenode_part.png

Sarko
-----

This module is executed periodically by the Almighty (default is every
30 seconds).

The jobs of Sarko are :

 - Look at running job walltimes and ask to frag them if they had expired.
 
 - Detect if fragged jobs are really fragged otherwise asks to exterminate
   them.
   
 - In "Desktop Computing" mode, it detects if a node date has expired and
   asks to change its state into "Suspected".
   
 - Can change "Suspected" resources into "Dead" after DEAD_SWITCH_TIME_ seconds.

Judas
-----

This is the module dedicated to print and log every debugging, warning and
error messages.

The notification functions are the following:

  - send_mail(mail_recipient_address, object, body, job_id) that sends 
    emails to the OAR admin
    
  - notify_user(base, method, host, user, job_id, job_name, tag, comments)
    that parses the notify method. This method can be a user script or a 
    mail to send. If the "method" field begins with 
    "mail:", notify_user will send an email to the user. If the 
    beginning is "exec:", it will execute the script as the "user".
    
The main logging functions are the following:

  - redirect_everything() this function redirects STDOUT and STDERR into 
    the log file
    
  - oar_debug(message)
  
  - oar_warn(message)
  
  - oar_error(message)
  
The three last functions are used to set the log level of the message.

Leon
----

This module is in charge to delete the jobs. Other OAR modules or commands
can ask to kill a job and this is Leon which performs that.

There are 2 frag types :

 - *normal* : Leon tries to connect to the first node allocated for the job and
   terminates the job.
   
 - *exterminate* : after a timeout if the *normal* method did not succeed
   then Leon notifies this case and clean up the database for these jobs. So
   OAR doesn't know what occured on the node and Suspects it.
   
   
NodeChangeState
---------------

This module is in charge of changing resource states and checking if there are
jobs on these.

It also checks all pending events in the table event_logs_.

Scheduler
---------

This module checks for each reservation jobs if it is valid and launches them
at the right time.

Scheduler_ launches all gantt scheduler in the order of the priority specified
in the database and update all visualization tables
(gantt_jobs_predictions_visu_ and gantt_jobs_resources_visu_).

It also trigger if a job has to be launched.

oar_sched_gantt_with_timesharing
________________________________

This is a OAR scheduler. It implements functionalities like
timesharing, moldable jobs, `besteffort jobs`, ...

We have implemented the FIFO with backfilling algorithm. Some parameters
can be changed in the `configuration file`_ (see SCHEDULER_TIMEOUT_,
SCHEDULER_JOB_SECURITY_TIME_, SCHEDULER_GANTT_HOLE_MINIMUM_TIME_,
SCHEDULER_RESOURCE_ORDER_).

oar_sched_gantt_with_timesharing_and_fairsharing
________________________________________________

This scheduler is the same than oar_sched_gantt_with_timesharing_ but it looks
at the consumption past and try to order waiting jobs with fairsharing in mind.

Some parameters can be changed directly in the file::

    ###############################################################################
    # Fairsharing parameters #
    ##########################
    # Avoid problems if there are too many waiting jobs
    my $Karma_max_number_of_jobs_treated = 1000;
    # number of seconds to consider for the fairsharing
    my $Karma_window_size = 3600 * 30;
    # specify the target percentages for project names (0 if not specified)
    my $Karma_project_targets = {
        first => 75,
        default => 25
    };

    # specify the target percentages for users (0 if not specified)
    my $Karma_user_targets = {
        oar => 100
    };
    # weight given to each criteria
    my $Karma_coeff_project_consumption = 3;
    my $Karma_coeff_user_consumption = 2;
    my $Karma_coeff_user_asked_consumption = 1;
    ###############################################################################

This scheduler takes its historical data in the accounting_ table. To fill this,
the command oaraccounting_ has to be run periodically (in a cron job for
example). Otherwise the scheduler cannot be aware of new user consumptions.

oar_sched_gantt_with_timesharing_and_fairsharing_and_quotas
___________________________________________________________

This scheduler is the same than
oar_sched_gantt_with_timesharingand_fairsharing but it implements quotas which
are configured in "/etc/oar/scheduler_quotas.conf".

Hulot
-----

This module is responsible of the advanced management of the standby mode of the
nodes. It's related to the energy saving features of OAR. It is an optional module
activated with the ENERGY_SAVING_INTERNAL=yes configuration variable.

It runs as a fourth "Almighty" daemon and opens a pipe on which it receives commands
from the MetaScheduler. It also communicates with a library called "WindowForker"
that is responsible of forking shut-down/wake-up commands in a way that not too much
commands are started at a time.
  
--------------------------------------------------------------------------------

  - Hulot general commands process schema:

  .. image:: ../schemas/hulot_general_commands_process.png
  
When Hulot is activated, the metascheduler sends, each time it is executed, a
list of nodes that need to be woken-up or may be halted. Hulot maintains a
list of commands that have already been sent to the nodes and asks to the
windowforker to actually execute the commands only when it is appropriate.
A special feature is the "keepalive" of nodes depending on some properties:
even if the metascheduler asks to shut-down some nodes, it's up to Hulot to
check if the keepalive constraints are still satisfied. If not, Hulot refuses
to halt the corresponding nodes.

--------------------------------------------------------------------------------

  - Hulot checking process schema:
      
  .. image:: ../schemas/hulot_checking_process.png

Hulot is called each time the metascheduler is called, to do all the checking
process. This process is also executed when Hulot receives normal halt or wake-up
commands from the scheduler. Hulot checks if waking-up nodes are actually Alive
or not and suspects the nodes if they haven't woken-up before the timeout.
It also checks keepalive constraints and decides to wake-up nodes if a constraint
is no more satisfied (for example because new jobs are running on nodes that are
now busy, and no more idle).
Hulot also checks the results of the commands sent by the windowforker and may
also suspect a node if the command exited with non-zero status.
  
--------------------------------------------------------------------------------  

  - Hulot wake-up process schema

  .. image:: ../schemas/hulot_wakeup_process.png

--------------------------------------------------------------------------------  

  - Hulot shutdown process schema

  .. image:: ../schemas/hulot_shutdown_process.png

--------------------------------------------------------------------------------  
