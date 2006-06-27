

===================
 OAR Documentation 
===================

.. image:: ../oar_logo.png
   :align: center

:Author: Capit Nicolas
:Address: Laboratoire Informatique et Distribution (ID)-IMAG
          ENSIMAG - antenne de Montbonnot
          ZIRST 51, avenue Jean Kuntzmann
          38330 MONTBONNOT SAINT MARTIN
:Contact: nicolas.capit@imag.fr
:Authors: ID laboratory
:organization: ID laboratory
:status: This is a "work in progress"
:license: GNU GENERAL PUBLIC LICENSE

:Dedication: For users, administrators and developpers.

:abstract:

  OAR is a resource manager or (batch scheduler) for large clusters. In
  functionnalities, it's near of PBS, LSF, CCS and Condor. It's suitable for
  productive plateforms and research experiments.


.. section-numbering::
.. contents:: Table of Contents

.. include:: ../../../INSTALL

User guide
==========

Description of the different commands
-------------------------------------
           
All user commands are installed on cluster login nodes. So you must connect to
one of these computers first.

*oarstat*
~~~~~~~~~
This command prints jobs in execution mode on the terminal.

Options
::

  -f        : prints each job in full details
  -j job_id : prints the specified job_id informations (even if it is finished)
  -g "d1,d2": prints history of jobs and state of resources between two dates.
  -D        : formats outputs in Perl Dumper
  -X        : formats outputs in XML
  -Y        : formats outputs in YAML
                    
Examples
::
            
  # oarstat
  # oarstat -j 42 -f
                    
*oarnodes*
~~~~~~~~~~

This command prints informations about cluster resources (state, which jobs on
which resources, resource properties, ...).

Options
::

  -a : shows all resources with their properties
  -s : shows only resource states
  -l : shows only resource list
  -D : formats outputs in Perl Dumper
  -X : formats outputs in XML
  -Y : formats outputs in YAML

Examples
::

  # oarnodes 
  # oarnodes -s

*oarsub*
~~~~~~~~

The user can submit a job with this command. So, what is a job in our context?
                  
  A job is defined by needed resources and a script/program to run. So, the user
  must specify how many resources and what kind of them are needed by his
  application. Thus, OAR system will give him or not what he wants and will
  control the execution. When a job is launched, OAR executes user program only
  on the first reservation node. So this program can access some environnement
  variables to know its environnement:
  ::
                  
    $OAR_NODEFILE                 contains the name of a file which lists all reserved nodes for this job
    $OAR_JOBID                    contains the OAR job identificator
    $OAR_RESOURCE_PROPERTIES_FILE contains the name of a file which lists all resources and their properties
    $OAR_NB_NODES                 contains the number of reserved nodes

Options::
                  
  -q "queuename" : specify the queue for this job
  -I : turn on INTERACTIVE mode (OAR gives you a shell instead of executing a script)
  -l "resource description" : defines resource list requested for this job;
                              the different parameters are resource properties
                              registered in OAR database; see examples below.
                              (walltime : Request maximun time. Format is
                              [hour:mn:sec|hour:mn|hour]; after this elapsed time,
                              the job will be killed)
  -p "properties" : adds constraints for the job
                    (format is a WHERE clause from the SQL syntax)
  -r "2007-05-11 23:32:03" : asks for a reservation job to begin at the date in argument
  -C job_id : connects to a reservation in Running state
  -k "duration" : asks OAR to send the checkpoint signal to the first processus
                  of the job "number_of_seconds" before the walltime
  --signal "signal name" : specify the signal to use when checkpointing
  -t "type name" : specify a specific type (deploy, besteffort, cosystem, checkpoint)
  -d "directory path" : specify the directory where to launch the command
                        (default is current directory)
  -n "job name" :  specify an arbitrary name for the job
  -a job_id : anterior job that must be terminated to start this new one
  --notify "method" : specify a notification method(mail or program to launch); ex:
                      --notify "mail:name@domain.com"
                      --notify "exec:/path/to/script args"
  --stdout "file name" : specify the name of the standard output file
  --stderr "file name" : specify the name of the error output file
  --resubmit job_id : resubmit the given job to a new one
  --force_cpuset_name "cpuset name" : Instead of using job_id for the cpuset name you
                                      can specify one (WARNING: if several jobs have the
                                      same cpuset name then processes of a job could be
                                      killed when another finished on the same computer)

Examples
::

  # oarsub -l /node=4 test.sh

(the "test.sh" script will be run on 4 entire nodes in the default queue with
the default walltime)
::

  # oarsub -q default -l walltime=50:30:00,/node=10/cpu=3,walltime=2:15:00 -p "switch = 'sw1'" /home/users/toto/prog
    
(the "/home/users/toto/prog" script will be run on 10 nodes with 3 cpus (so a total of 30 cpus) in the default
queue with a walltime of  2:15:00. Mooreover "-p" option restricts resources only on the switch 'sw1')
::
     
  # oarsub -r "2004-04-27 11:00:00" -l /node=12/cpu=2

(a reservation will begin at "2004-04-27 11:00:00" on 12 nodes with 2 cpus on each one)
::

  #  oarsub -C 42

(connects to the job 42 on the first node and set all OAR environment variables)
::

# oarsub -I

(gives a shell on a resource)

*oardel*
~~~~~~~~

This command is used to delete or checkpoint job(s). Jobs are designed by their job's identifier.

Option
::
  
  -c job_id : send checkpoint signal to the job (signal was definedwith "--signal" option in oarsub)

Exemples
::

  # oardel 14 42
    
(delete jobs 14 and 42)
::

  # oardel -c 42

(send checkpoint signal to the job 42)

Visualisation tools
-------------------

Monika
~~~~~~
This is a web cgi normally installed on the cluster frontal. This tool executes
*oarnodes* and *oarstat* then format data in a html page.

Thus you can have a global view of cluster state and where your jobs are running.

DrawOARGantt
~~~~~~~~~~~~
This is also a web cgi. It creates a Gantt chart which shows job repartition on
nodes in the time. It is very usefull to see cluster occupation in the past
and to know when a job will be launched in the futur.


Administrator guide
===================

Administrator commands
----------------------

*oarproperty*
~~~~~~~~~~~~~

This command manages OAR resource properties stored in the database.

Options are: ::

  -l : list properties
  -a NAME : add a property
    -c : sql new field of type VARCHAR(255) (default is integer)
  -d NAME : delete a property
  -r "OLD_NAME,NEW_NAME" : rename property OLD_NAME into NEW_NAME

Examples: ::

  # oarproperty -a cpu_freq
  # oarproperty -a type
  # oarproperty -r "cpu_freq,freq"

*oarnodesetting*
~~~~~~~~~~~~~~~~

This command permits to change the state or a property of a node or of several
resources resources.

By default the node name used by *oarnodesetting* is the result of the command
*hostname*.

Options are: ::

 -a : add a new resource
 -s : state to assign to the node:
    * "Alive" : a job can be run on the node.
    * "Absent" : administrator wants to remove the node from the pool for a moment.
    * "Dead" : the node will not be used and will be deleted. 
 -h : specify the node name (override hostname).
 -r : specify the resource number
 -p : change the value of a property specified resources.
 -n : specify this option if you do not want to wait the end of jobs running
      on this node when you change its state into "Absent" or "Dead".

*oarremoveresource*
~~~~~~~~~~~~~~~~~~~

This command permits to remove a resource from the database.

The node must be in the state "Dead" (use *oarnodesetting* to do this) and then
you can use this command to delete it.

*oaraccounting*
~~~~~~~~~~~~~~~

This command permits to update the *accounting* table for jobs ended since the
last launch.

*oarnotify*
~~~~~~~~~~~

This command sends commands to the "Almighty" module. It is dedicated to
developpers.

You can use the "-v" option to show the OAR version.

Database scheme
---------------

*accounting*
~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
window_start      DATETIME              start date of the accounting interval
window_stop       DATETIME              stop date of the accounting interval
accounting_user   VARCHAR(20)           user name
queue_name        VARCHAR(100)          queue name
consumption_type  ENUM("ASKED","USED")  "ASKED" corresponds to the walltimes
                                        specified by the user. "USED"
                                        corresponds to the effective time
                                        used by the user.
consumption       INT UNSIGNED          number of seconds used
================  ====================  =======================================

:Primary key: window_start, window_stop, accounting_user, queue_name, consumption_type
:Index fields: window_start, window_stop, accounting_user, queue_name, consumption_type

This table is a summary of the comsumption for each user on each queue. This
increases the speed of queries about user consumptions and statistic
generation.

Data are inserted through the command *oaraccounting* (when a job is treated
the field *accounted* in table jobs is passed into "YES"). So it is possible to
regenerate this table completely in this way :
 
 - Delete all data of the table:
   ::
     
       DELETE FROM accounting;

 - Set the field *accounted* in the table jobs to "NO" for each row:
   ::

       UPDATE jobs SET accounted = "NO";

 - Run the *oaraccounting* command.

You can change the amount of time for each window : edit the oar configuration
file and change the value of the tag *ACCOUNTING_WINDOW*.

*admission_rules*
~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
id                INT UNSIGNED          id number
rule              VARCHAR(255)          rule written in Perl applied when a
                                        job is going to be registered
================  ====================  =======================================

:Primary key: id
:Index fields: *None*

You can use these rules to change some values of some properties when a job is
submitted. Some examples are better than a long description :

 - Specify the default value for queue parameter
   ::
      
      INSERT INTO admission_rules (rule) VALUES('
        if (not defined($queue_name)) {
            $queue_name="default";
        }
      ');

 - Avoid users except oar to go in the admin queue
   ::
      
      INSERT INTO admission_rules (rule) VALUES ('
        if (($queue_name eq "admin") && ($user ne "oar")) {
          die("[ADMISSION RULE] Only oar user can submit jobs in the admin queue\\n");
        }
      ');

 - Restrict the maximum of the walltime for intercative jobs
   ::
 
      INSERT INTO admission_rules (rule) VALUES ('
        my $max_walltime = "12:00:00";
        if ($jobType eq "INTERACTIVE"){ 
          foreach my $mold (@{$ref_resource_list}){
            if ((defined($mold->[1])) and (sql_to_duration($max_walltime) < sql_to_duration($mold->[1]))){
              print("[ADMISSION RULE] Walltime to big for an INTERACTIVE job so it is set to $max_walltime.\\n");
              $mold->[1] = $max_walltime;
            }
          }
        }
      ');

 - Specify the default walltime
   ::
   
    INSERT INTO admission_rules (rule) VALUES ('
      my $default_wall = "2:00:00";
      foreach my $mold (@{$ref_resource_list}){
        if (!defined($mold->[1])){
          print("[ADMISSION RULE] Set default walltime to $default_wall.\\n");
          $mold->[1] = $default_wall;
        }
      }
    ');
 
 - How to perform actions if the user name is in a file
   ::
  
    INSERT IGNORE INTO admission_rules (rule) VALUES ('
      open(FILE, "/tmp/users.txt");
      while (($queue_name ne "admin") and ($_ = <FILE>)){
        if ($_ =~ m/^\\s*$user\\s*$/m){
          print("[ADMISSION RULE] Change assigned queue into admin\\n");
          $queue_name = "admin";
        }
      }
      close(FILE);
    ');
    
*event_logs*
~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
event_id          INT UNSIGNED          event identifier
type              VARCHAR(50)           event type
job_id            INT UNSIGNED          job related of the event
date              DATETIME              event date
description       VARCHAR(255)          textual description of the event
to_check          ENUM('YES','NO')      specify if the module *NodeChangeState*
                                        must check this event to Suspect or not
                                        some nodes
================  ====================  =======================================

:Primary key: event_id
:Index fields: type, to_check

The different event types are:

 - "PING_CHECKER_NODE_SUSPECTED" : the system detected via the module "finaud"
   that a node is not responding.
 - "PROLOGUE_ERROR" : an error occured during the execution of the job
   prologue (exit code != 0).
 - "EPILOGUE_ERROR" : an error occured during the execution of the job
   epilogue (exit code != 0).
 - "CANNOT_CREATE_TMP_DIRECTORY" : OAR cannot create the directory where all
                                   information files will be stored.
 - "CAN_NOT_WRITE_NODE_FILE" : the system was not able to write file which had
   to contain the node list on the first node (*/tmp/OAR_idJob*).
 - "CAN_NOT_WRITE_PID_FILE" : the system was not able to write the file which had
   to contain the pid of oarexec process on the first node
   (*/tmp/pid_of_oarexec_for_jobId_idJob*).
 - "USER_SHELL" : the system was not able to get informations about the user
   shell on the first node.
 - "EXIT_VALUE_OAREXEC" : the oarexec process terminated with an unknown exit
   code.
 - "SEND_KILL_JOB" : signal that OAR has transmitted a kill signal to the
   oarexec of the specified job.
 - "LEON_KILL_BIPBIP_TIMEOUT" : Leon module has detected that somehing wrong
   occured during the kill of a job and so kill the local *bipbip* process.
 - "EXTERMINATE_JOB" : Leon module has detected that something wrong occured
   during the kill of a job and so clean the database and terminate the job
   artificially.
 - "WORKING_DIRECTORY" : the directory from which the job was submitted does
   not exist on the node assigned by the system.
 - "OUTPUT_FILES" : OAR cannot write the output files (stdout and stderr) in
   the working directory.
 - "CANNOT_NOTIFY_OARSUB" : OAR cannot notify the oarsub process for an
   interactive job (maybe the user has killed this process).
 - "WALLTIME" : the job has reached its walltime.
 - "SCHEDULER_REDUCE_NB_NODES_FOR_RESERVATION" : this means that there is not
   enough nodes for the reservation and so the scheduler do the best and
   gives less nodes than the user wanted (this occures when nodes become
   Suspected or Absent).
 - "BESTEFFORT_KILL" : the job is of the type *besteffort* and was killed
   because a normal job wanted the nodes.
 - "FRAG_JOB_REQUEST" : someone wants to delete a job.
 - "CHECKPOINT" : the checkpoint signal was send to the job.
 - "CHECKPOINT_ERROR" : OAR cannot send the signal to the job.
 - "CHECKPOINT_SUCCESS" : system has sent the signal correctly.
 - "SERVER_EPILOGUE_TIMEOUT" : epilogue server script has timeouted.
 - "SERVER_EPILOGUE_EXIT_CODE_ERROR" : epilogue server script did not return 0.
 - "SERVER_EPILOGUE_ERROR" : cannot find epilogue server script file.
 - "SERVER_PROLOGUE_TIMEOUT" : prologue server script has timeouted.
 - "SERVER_PROLOGUE_EXIT_CODE_ERROR" : prologue server script did not return 0.
 - "SERVER_PROLOGUE_ERROR" : cannot find prologue server script file.
 - "CPUSET_CLEAN_ERROR" : OAR cannot clean correctly cpuset files for a job on the remote node.
 - "MAIL_NOTIFICATION_ERROR" : a mail cannot be sent.
 - "USER_MAIL_NOTIFICATION" : user mail notification cannot be performed.
 - "USER_EXEC_NOTIFICATION_ERROR" : user script execution notification cannot be performed.
 - "BIPBIP_BAD_JOBID" : error when retriving informations about a running job.
 - "BIPBIP_CHALLENGE" : OAR is configured to detach jobs when they are launched
                        on compute nodes and the job return a bad challenge number.
 - "RESUBMIT_JOB_AUTOMATICALLY" : the job was automatically resubmitted.
 - "WALLTIME" : the job reached its walltime.
 - "REDUCE_RESERVATION_WALLTIME" : the reservation job was shrinked.
 - "SSH_TRANSFER_TIMEOUT" : node OAR part script was too long to transfer.
 - "BAD_HASHTABLE_DUMP" : OAR transfered a bad hashtable.
 - "LAUNCHING_OAREXEC_TIMEOUT" : oarexec was too long to initialize itself.

*files*
~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
idFile            INT UNSIGNED
md5sum            VARCHAR(255)
location          VARCHAR(255)
method            VARCHAR(255)
compression       VARCHAR(255)
size              INT UNSIGNED
================  ====================  =======================================

:Primary key: idFile
:Index fields: md5sum

*frag_jobs*
~~~~~~~~~~~

================  ==========================  =================================
Fields            Types                       Descriptions
================  ==========================  =================================
frag_id_job       INT UNSIGNED                job id
frag_date         DATETIME                    kill job decision date 
frag_state        ENUM('LEON','TIMER_ARMED',  state to tell Leon what to do
                  'LEON_EXTERMINATE',
                  'FRAGGED')
                  DEFAULT 'LEON'
================  ==========================  =================================

:Primary key: frag_id_job
:Index fields: frag_state

What mean the states:

 - "LEON" : the Leon module must try to kill the job and change the state into
   "TIMER_ARMED".
 - "TIMER_ARMED" : the Sarko module must wait a response from the job during
   a timeout (default is 60s)
 - "LEON_EXTERMINATE" : the Sarko module has decided that the job timeouted and
   asked Leon to clean up the database.
 - "FRAGGED" : job is fragged.

*gantt_jobs_resources*
~~~~~~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
moldable_job_id   INT UNSIGNED          moldable job id
resource_id       INT UNSIGNED          resource assigned to the job
================  ====================  =======================================

:Primary key: moldable_job_id, resource_id
:Index fields: *None*

This table specifies which resources are attributed to which jobs.

*gantt_jobs_resources_visu*
~~~~~~~~~~~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
moldable_job_id   INT UNSIGNED          moldable job id
resource_id       INT UNSIGNED          resource assigned to the job
================  ====================  =======================================

:Primary key: moldable_job_id, resource_id
:Index fields: *None*

This table is the same as *gantt_jobs_resources* and is used by visualisation tools.
It is made up to date in an atomic action (with a lock).

*gantt_jobs_predictions*
~~~~~~~~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
moldable_job_id   INT UNSIGNED          job id
start_time        DATETIME              date when the job is scheduled to start
================  ====================  =======================================

:Primary key: moldable_job_id
:Index fields: *None*

With this table and *gantt_jobs_resources* you can know exactly what are the decisions
taken by the schedulers for each waiting jobs.

:note: The special job id "0" is used to store the scheduling reference date.

*gantt_jobs_predictions_visu*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
moldable_job_id   INT UNSIGNED          job id
start_time        DATETIME              date when the job is scheduled to start
================  ====================  =======================================

:Primary key: job_id
:Index fields: *None*

This table is the same as *gantt_jobs_predictions* and is used by visualisation
tools. It is made up to date in an atomic action (with a lock).

*jobs*
~~~~~~

==================  ======================  =======================================
Fields              Types                   Descriptions
==================  ======================  =======================================
idJob               INT UNSIGNED            job id
jobType             ENUM('INTERACTIVE',     specify if the use want to launch a
                    'PASSIVE') DEFAULT      program or get an interactive shell
                    'PASSIVE'
infoType            VARCHAR(255)            some informations about *oarsub*
                                            command
state               ENUM('Waiting','Hold',  job state
                    'toLaunch','toError',
                    'toAckReservation',
                    'Launching','Running',
                    'Terminated','Error')
reservation         ENUM('None',            specify if the job is a reservation
                    'toSchedule',           and the state of this one
                    'Scheduled') DEFAULT
                    'None'
message             VARCHAR(255)            readable information message for the
                                            user
user                VARCHAR(20)             user name
nbNodes             INT UNSIGNED            number of requested nodes
weight              INT UNSIGNED            number of subdivision per node
                                            requested
command             TEXT                    program to run
bpid                VARCHAR(255)            pid of the "bipbip" process
queueName           VARCHAR(100)            queue name
maxTime             TIME                    walltime
properties          TEXT                    properties that assigned nodes must
                                            match
launchingDirectory  VARCHAR(255)            path of the directory where *oarsub*
                                            command was launched
submissionTime      DATETIME                date when the job was submitted
startTime           DATETIME                date when the job was launched
stopTime            DATETIME                date when the job was stopped
idFile              INT
accounted           ENUM("YES","NO")        specify if the job was considered by
                    DEFAULT "NO"            the accounting mechanism or not
==================  ======================  =======================================

:Primary key: idJob
:Index fields: state, reservation, queueName, accounted

Explications about the "state" field:

 - "Waiting" : the job is waiting OAR sheduler decision.
 - "Hold" : user or administrator wants to hold the job (*oarhold* command).
   So it will not be scheduled by the system.
 - "toLaunch" : the OAR scheduler has attributed some nodes to the job. So it
   will be launched.
 - "toError" : something wrong occured and the job is going into the error
   state.
 - "toAckReservation" : the OAR sheduler must say "YES" or "NO" to the waiting
   *oarsub* command because it requested a reservation.
 - "Launching" : OAR has launched the job and will execute the user command
   on the first node.
 - "Running" : the user command is executing on the first node.
 - "Terminated" : the job is terminated normally.
 - "Error" : a problem has occured.

Explications about the "reservation" field:

 - "None" : the job is not a reservation.
 - "toSchedule" : the job is a reservation and must be approved by the
   scheduler.
 - "Scheduled" : the job is a reservation and is scheduled by OAR.

*nodeProperties*
~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
hostname          VARCHAR(100)          node name
besteffort        ENUM('YES','NO')      specify if the node accepts or not
                  DEFAULT 'YES'         besteffort jobs
deploy            ENUM('YES','NO')      specify if the node accepts or not
                  DEFAULT 'NO'          deployment jobs
expiryDate        DATETIME              used in desktop computing mode to know
                                        when a node is considered to be offline
desktopComputing  ENUM('YES','NO')      specify if the node is a desktop
                  DEFAULT 'NO'          computing node or not
================  ====================  =======================================

:Primary key: hostname
:Index fields: *None*

This table permits to specify differents properties for each nodes. These can
be used with the *oarsub* command ("-p" option).

You can add your own properties, for exemple:
::

  ALTER TALE nodeProperties ADD memory INT DEFAULT 256;

This adds a column "memory" where you can specify the amount of memory for each
nodes.

These properties can be updated with the *oarnodesetting* command ("-p" option).

*nodeState_log*
~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
hostname          VARCHAR(100)          node name
changeState       ENUM('Alive','Dead'   node state during the interval
                  ,'Suspected',
                  'Absent')
dateStart         DATETIME              start date of the interval
dateStop          DATETIME              end date of the interval
finaudDecision    ENUM('YES','NO')      specify if that was a "finaud" module
                  DEFAULT 'NO'          decision
================  ====================  =======================================

:Primary key: *None*
:Index fields: hostname, changeState, finaudDecision

This table keeps informations about state changes of nodes.

*nodes*
~~~~~~~

==================  ====================  =======================================
Fields              Types                 Descriptions
==================  ====================  =======================================
hostname            VARCHAR(100)          node name
state               ENUM('Alive','Dead',  node state
                    'Suspected',
                    'Absent')
maxWeight           INT UNSIGNED          maximum of the subdivision number
                    DEFAULT 1
weight              INT UNSIGNED          number of subdivision used
nextState           ENUM('UnChanged',     state for the node to switch
                    'Alive','Dead',
                    'Absent','Suspected'
                    ) DEFAULT
                    'UnChanged'
finaudDecision      ENUM('YES','NO')      tell if the actual state results in a
                    DEFAULT 'NO'          "finaud" module decision
nextFinaudDecision  ENUM('YES','NO')      tell if the next node state results in
                    DEFAULT 'NO'          a "finaud" module decision
==================  ====================  =======================================

:Primary key: hostname
:Index fields: state, nextState

States explication:

 - "Alive" : the node is ready to accept a job.
 - "Absent" : the oar administrator has decided to pull out the node. This
   computer can come back.
 - "Suspected" : OAR system has detected a problem on this node and so has
   supectected it (you can look in the *event_log* table to know what has
   happened). This computer can come back (automatically if this is a 
   "finaud" module decision).
 - "Dead" : The oar administrator considers that the node will not come back
   and will be removed from the pool.

*processJobs*
~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
idJob             INT UNSIGNED          job id
hostname          VARCHAR(100)          node assigned to the job
================  ====================  =======================================

:Primary key: idJob, hostname
:Index fields: idJob

This table keeps information for running jobs on which nodes they are
scheduled.

*processJobs_log*
~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
idJob             INT UNSIGNED          job id
hostname          VARCHAR(100)          node assigned to the job
================  ====================  =======================================

:Primary key: idJob, hostname
:Index fields: idJob

It is a log table for terminated jobs. It keeps the information on which nodes
was scheduled a job.

*queues*
~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
queue_name        VARCHAR(100)          queue name
priority          INT UNSIGNED          the scheduling priority
scheduler_policy  VARCHAR(100)          path of the associated scheduler
state             ENUM('Active',        permits to stop the scheduling for a
                  'notActive')          queue
                  DEFAULT 'Active'
================  ====================  =======================================

:Primary key: queue_name
:Index fields: *None*

This table contains the schedulers executed by the *oar_meta_scheduler* module.
Executables are launched one after one in the specified priority.

Configuration file
==================

This is the meanings for each configuration tags that you can find in /etc/oar.conf:

  - DataBase hostname::
  
      DB_HOSTNAME=localhost

  - Database base name::
  
      DB_BASE_NAME=oar

  - DataBase user name::
      
      DB_BASE_LOGIN=oar

  - DataBase user password::
      
      DB_BASE_PASSWD=oar

  - OAR server hostname::
      
      SERVER_HOSTNAME=localhost

  - OAR server port::
      
      SERVER_PORT=6666

  - Specify where we are connected in the deploy queue(the node to connect
    to when the job is in the deploy queue)::
      
      DEPLOY_HOSTNAME = 127.0.0.1

  - Set DETACH_JOB to 1 if you do not want to keep a ssh connection between the
    node and the server. Otherwise set this tag to 0::
      
      DETACH_JOB=1

  - By default OAR uses the ping command to detect if nodes are down or not.
    To enhance this diagnostic you can specify one of these other methods (
    give the complete command path):

      * OAR sentinelle::
      
          SENTINELLE_COMMAND=/usr/bin/sentinelle -cconnect=ssh,timeout=3000

      * OAR fping::
      
          FPING_COMMAND=/usr/bin/fping -q 

      * OAR nmap : it will test to connect on the ssh port (22)::
      
          NMAP_COMMAND=/usr/bin/nmap -p 22 -n -T5

  - OAR nodes default weight(when the user does not specify a weight in the
    oarsub invocation, then it is the used value)::
      
      NODE_DEFAULT_WEIGHT=1

  - OAR log level: 3(debug+warnings+errors), 2(warnings+errors), 1(errors)::
      
      LOG_LEVEL=2

  - OAR log file::
      
      LOG_FILE=/var/log/oar.log

  - OAR Allowed networks, Networks or hosts allowed to submit jobs to OAR and
    compute nodes may be specified here(0.0.0.0/0 means all IPs are allowed
    and 127.0.0.1/32 means only IP 127.0.0.1 is allowed)::
      
      ALLOWED_NETWORKS= 127.0.0.1/32 0.0.0.0/0

  - Set the granularity of the OAR accounting feature (in seconds). Default is
    1 day (86400s)::
      
      ACCOUNTING_WINDOW= 86400

  - OAR informations may be notified by email to the administror.
    Set accordingly to your configuration the next lines to activate
    the feature::
      
      MAIL_SMTP_SERVER = smtp.serveur.com
      MAIL_RECIPIENT = user@domain.com
      MAIL_SENDER = oar@domain.com

  - Limitation configuration for the oar_sched_gant_g5k scheduler
    (0:Sunday, 1:Monday, 2:Tuesday, 3:Wednesday, 4:Thursday, 5:Friday,
    6:Saturday)::
      
      G5K_LIMIT_WEEK_DAYS = 1 2 3 4 5
      G5K_LIMIT_DAY_HOURS = 7 22

  - These are configuration tags for OAR in the desktop-computing mode::
  
      DESKTOP_COMPUTING_ALLOW_CREATE_NODE=0
      DESKTOP_COMPUTING_EXPIRY=10
      STAGEOUT_DIR=/var/lib/oar/stageouts/
      STAGEIN_DIR=/var/lib/oar/stageins
      STAGEIN_CACHE_EXPIRY=144

Module description
==================

OAR can be decomposed into several modules which perform different tasks.

Almighty
--------

This module is the OAR server. It decides what actions must be performed. It
is divided into 2 processes:

 - One listen to a TCP/IP socket. It waits informations or commands from OAR
   user program or from the other modules.
 - Another one treates each commands thanks to an automaton and launch right
   modules one after one.

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

Judas
-----

This is the module dedicated to print and log every debugging, warning and
error text.

Leon
----

This module is in charge of the frag of jobs. Other OAR modules or commands
can ask to kill a job and this is Leon which perform that.

There are 2 frag types :

 - *normal* : Leon tries to connect to on the first node of the job and tell it
   to kill itself.
 - *exterminate* : after a timeout if the *normal* method did not succeeded
   then Leon notifies this case and clean up the database for these jobs.

NodeChangeState
---------------

This module is in charge of changing node states and check if there are jobs
on these.

Scheduler
---------

This module checks for each reservation job it validity and the moment to
launch it. And it launches all gantt scheduler in the order of the priority
of the database.

Runner
------

This module launches OAR effective jobs. These processes are run asynchronously
with all modules.
