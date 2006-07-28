===================
 OAR Documentation 
===================

.. image:: oar_logo.png
   :alt: OAR logo
   :align: center
   :width: 8cm

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


**BE CAREFULL : THIS DOCUMENTION IS FOR THE NEXT OAR VERSION (2.0)**

.. section-numbering::
.. contents:: Table of Contents

-------------------------------------------------------------------------------

.. include:: ../../INSTALL

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
  -r : show only properties of a resource
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
                  
    $OAR_NODEFILE                 contains the name of a file which lists
                                  all reserved nodes for this job
    $OAR_JOBID                    contains the OAR job identificator
    $OAR_RESOURCE_PROPERTIES_FILE contains the name of a file which lists
                                  all resources and their properties
    $OAR_NB_NODES                 contains the number of reserved nodes

Options::
                  
  -q "queuename" : specify the queue for this job
  -I : turn on INTERACTIVE mode (OAR gives you a shell instead of executing a
       script)
  -l "resource description" : defines resource list requested for this job;
                              the different parameters are resource properties
                              registered in OAR database; see examples below.
                              (walltime : Request maximun time. Format is
                              [hour:mn:sec|hour:mn|hour]; after this elapsed
                              time, the job will be killed)
  -p "properties" : adds constraints for the job
                    (format is a WHERE clause from the SQL syntax)
  -r "2007-05-11 23:32:03" : asks for a reservation job to begin at the
                             date in argument
  -C job_id : connects to a reservation in Running state
  -k "duration" : asks OAR to send the checkpoint signal to the first processus
                  of the job "number_of_seconds" before the walltime
  --signal "signal name" : specify the signal to use when checkpointing
  -t "type name" : specify a specific type (deploy, besteffort, cosystem,
                   checkpoint)
  -d "directory path" : specify the directory where to launch the command
                        (default is current directory)
  -n "job name" :  specify an arbitrary name for the job
  -a job_id : anterior job that must be terminated to start this new one
  --notify "method" : specify a notification method(mail or command); ex:
                      --notify "mail:name@domain.com"
                      --notify "exec:/path/to/script args"
  --stdout "file name" : specify the name of the standard output file
  --stderr "file name" : specify the name of the error output file
  --resubmit job_id : resubmit the given job to a new one
  --force_cpuset_name "cpuset name" : Instead of using job_id for the cpuset
                                      name you can specify one (WARNING: if
                                      several jobs have the same cpuset name
                                      then processes of a job could be killed
                                      when another finished on the same
                                      computer)

Examples
::

  # oarsub -l /node=4 test.sh

(the "test.sh" script will be run on 4 entire nodes in the default queue with
the default walltime)
::

  # oarsub -q default -l walltime=50:30:00,/node=10/cpu=3,walltime=2:15:00 \
    -p "switch = 'sw1'" /home/users/toto/prog
    
(the "/home/users/toto/prog" script will be run on 10 nodes with 3 cpus (so a
total of 30 cpus) in the default queue with a walltime of  2:15:00.
Moreover "-p" option restricts resources only on the switch 'sw1')
::
     
  # oarsub -r "2004-04-27 11:00:00" -l /node=12/cpu=2

(a reservation will begin at "2004-04-27 11:00:00" on 12 nodes with 2 cpus
on each one)
::

  #  oarsub -C 42

(connects to the job 42 on the first node and set all OAR environment
variables)
::

  # oarsub -I

(gives a shell on a resource)

*oardel*
~~~~~~~~

This command is used to delete or checkpoint job(s). They are designed by
their identifier.

Option
::
  
  -c job_id : send checkpoint signal to the job (signal was
              definedwith "--signal" option in oarsub)

Exemples
::

  # oardel 14 42
    
(delete jobs 14 and 42)
::

  # oardel -c 42

(send checkpoint signal to the job 42)

*oarhold*
~~~~~~~~~

*oarresume*
~~~~~~~~~~~

Visualisation tools
-------------------

Monika
~~~~~~

This is a web cgi normally installed on the cluster frontal. This tool executes
`oarnodes`_ and `oarstat`_ then format data in a html page.

Thus you can have a global view of cluster state and where your jobs are
running.

DrawOARGantt
~~~~~~~~~~~~

This is also a web cgi. It creates a Gantt chart which shows job repartition on
nodes in the time. It is very useful to see cluster occupation in the past
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

By default the node name used by `oarnodesetting`_ is the result of the command
*hostname*.

Options are: ::

 -a : add a new resource
 -s : state to assign to the node:
    * "Alive" : a job can be run on the node.
    * "Absent" : administrator wants to remove the node from the pool for a
      moment.
    * "Dead" : the node will not be used and will be deleted. 
 -h : specify the node name (override hostname).
 -r : specify the resource number
 -p : change the value of a property specified resources.
 -n : specify this option if you do not want to wait the end of jobs running
      on this node when you change its state into "Absent" or "Dead".

*oarremoveresource*
~~~~~~~~~~~~~~~~~~~

This command permits to remove a resource from the database.

The node must be in the state "Dead" (use `oarnodesetting`_ to do this) and then
you can use this command to delete it.

*oaraccounting*
~~~~~~~~~~~~~~~

This command permits to update the `accounting`_ table for jobs ended since the
last launch.

*oarnotify*
~~~~~~~~~~~

This command sends commands to the `Almighty`_ module. It is dedicated to
developpers.

You can use the "-v" option to show the OAR version.

Database scheme
---------------

.. figure:: db_scheme.png
   :width: 17cm
   :target: db_scheme.png
   :alt: Database scheme

   Database scheme
   (red lines seem PRIMARY KEY,
   blue lines seem INDEX)
   
`db_scheme.svg <db_scheme.svg>`_

*accounting*
~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
window_start      DATETIME              start date of the accounting interval
window_stop       DATETIME              stop date of the accounting interval
accounting_user   VARCHAR(20)           user name
queue_name        VARCHAR(100)          queue name
consumption_type  ENUM("ASKED",         "ASKED" corresponds to the walltimes
                  "USED")               specified by the user. "USED"
                                        corresponds to the effective time
                                        used by the user.
consumption       INT UNSIGNED          number of seconds used
================  ====================  =======================================

:Primary key: window_start, window_stop, accounting_user, queue_name,
              consumption_type
:Index fields: window_start, window_stop, accounting_user, queue_name,
               consumption_type

This table is a summary of the comsumption for each user on each queue. This
increases the speed of queries about user consumptions and statistic
generation.

Data are inserted through the command `oaraccounting`_ (when a job is treated
the field *accounted* in table jobs is passed into "YES"). So it is possible to
regenerate this table completely in this way :
 
 - Delete all data of the table:
   ::
     
       DELETE FROM accounting;

 - Set the field *accounted* in the table jobs to "NO" for each row:
   ::

       UPDATE jobs SET accounted = "NO";

 - Run the `oaraccounting`_ command.

You can change the amount of time for each window : edit the oar configuration
file and change the value of the tag ACCOUNTING_WINDOW_.

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
submitted. So each admission rule is executed in the order of the id field and
it can set several variables. If one of them exits then the others will not
be evaluated and oarsub_ returns an error.

Some examples are better than a long description :

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
            if (
              (defined($mold->[1])) and
              (sql_to_duration($max_walltime) < sql_to_duration($mold->[1]))
            ){
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
  
    INSERT INTO admission_rules (rule) VALUES ('
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
to_check          ENUM('YES', 'NO')     specify if the module *NodeChangeState*
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
   to contain the node list on the first node (*/tmp/OAR_job_id*).
 - "CAN_NOT_WRITE_PID_FILE" : the system was not able to write the file which
   had to contain the pid of oarexec process on the first node
   (*/tmp/pid_of_oarexec_for_job_id*).
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
 - "CANNOT_NOTIFY_OARSUB" : OAR cannot notify the `oarsub`_ process for an
   interactive job (maybe the user has killed this process).
 - "WALLTIME" : the job has reached its walltime.
 - "SCHEDULER_REDUCE_NB_NODES_FOR_RESERVATION" : this means that there is not
   enough nodes for the reservation and so the scheduler do the best and
   gives less nodes than the user wanted (this occures when nodes become
   Suspected or Absent).
 - "BESTEFFORT_KILL" : the job is of the type *besteffort* and was killed
   because a normal job wanted the nodes.
 - "FRAG_JOB_REQUEST" : someone wants to delete a job.
 - "CHECKPOINT" : the checkpoint signal was sent to the job.
 - "CHECKPOINT_ERROR" : OAR cannot send the signal to the job.
 - "CHECKPOINT_SUCCESS" : system has sent the signal correctly.
 - "SERVER_EPILOGUE_TIMEOUT" : epilogue server script has timeouted.
 - "SERVER_EPILOGUE_EXIT_CODE_ERROR" : epilogue server script did not return 0.
 - "SERVER_EPILOGUE_ERROR" : cannot find epilogue server script file.
 - "SERVER_PROLOGUE_TIMEOUT" : prologue server script has timeouted.
 - "SERVER_PROLOGUE_EXIT_CODE_ERROR" : prologue server script did not return 0.
 - "SERVER_PROLOGUE_ERROR" : cannot find prologue server script file.
 - "CPUSET_CLEAN_ERROR" : OAR cannot clean correctly cpuset files for a job
   on the remote node.
 - "MAIL_NOTIFICATION_ERROR" : a mail cannot be sent.
 - "USER_MAIL_NOTIFICATION" : user mail notification cannot be performed.
 - "USER_EXEC_NOTIFICATION_ERROR" : user script execution notification cannot
   be performed.
 - "BIPBIP_BAD_JOBID" : error when retriving informations about a running job.
 - "BIPBIP_CHALLENGE" : OAR is configured to detach jobs when they are launched
   on compute nodes and the job return a bad challenge number.
 - "RESUBMIT_JOB_AUTOMATICALLY" : the job was automatically resubmitted.
 - "WALLTIME" : the job reached its walltime.
 - "REDUCE_RESERVATION_WALLTIME" : the reservation job was shrinked.
 - "SSH_TRANSFER_TIMEOUT" : node OAR part script was too long to transfer.
 - "BAD_HASHTABLE_DUMP" : OAR transfered a bad hashtable.
 - "LAUNCHING_OAREXEC_TIMEOUT" : oarexec was too long to initialize itself.
 - "RESERVATION_NO_NODE" : All nodes were detected as bad for the reservation
   job.

*event_log_hostnames*
~~~~~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
event_id          INT UNSIGNED          event identifier
hostname          VARCHAR(255)          name of the node where the event
                                        has occured
================  ====================  =======================================

:Primary key: event_id
:Index fields: hostname

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
frag_state        ENUM('LEON', 'TIMER_ARMED'  state to tell Leon what to do
                  , 'LEON_EXTERMINATE',
                  'FRAGGED')
                  DEFAULT 'LEON'
================  ==========================  =================================

:Primary key: frag_id_job
:Index fields: frag_state

What do these states mean:

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

This table is the same as `gantt_jobs_resources`_ and is used by visualisation
tools. It is updated atomically (a lock is used).

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

With this table and `gantt_jobs_resources`_ you can know exactly what are the
decisions taken by the schedulers for each waiting jobs.

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

This table is the same as `gantt_jobs_predictions`_ and is used by visualisation
tools. It is made up to date in an atomic action (with a lock).

*jobs*
~~~~~~

===================== ======================  =======================================
Fields                Types                   Descriptions
===================== ======================  =======================================
job_id                INT UNSIGNED            job identifier
job_name              VARCHAR(100)            name given by the user
cpuset_name           VARCHAR(255)            name of the cpuset directory used for
                                              this job on each nodes
job_type              ENUM('INTERACTIVE',     specify if the user wants to launch a
                      'PASSIVE') DEFAULT      program or get an interactive shell
                      'PASSIVE'
info_type              VARCHAR(255)           some informations about `oarsub`_
                                              command
state                 ENUM('Waiting','Hold',  job state
                      'toLaunch', 'toError',
                      'toAckReservation',
                      'Launching', 'Running'
                      , 'Finishing',
                      'Terminated', 'Error')
reservation           ENUM('None',            specify if the job is a reservation
                      'toSchedule',           and the state of this one
                      'Scheduled') DEFAULT
                      'None'
message               VARCHAR(255)            readable information message for the
                                              user
job_user              VARCHAR(20)             user name
command               TEXT                    program to run
queue_name            VARCHAR(100)            queue name
properties            TEXT                    properties that assigned nodes must
                                              match
launching_directory   VARCHAR(255)            path of the directory where to launch
                                              the user process
submission_time       DATETIME                date when the job was submitted
start_time            DATETIME                date when the job was launched
stop_time             DATETIME                date when the job was stopped
file_id               INT UNSIGNED
accounted             ENUM("YES", "NO")       specify if the job was considered by
                      DEFAULT "NO"            the accounting mechanism or not
notify                VARCHAR(255)            gives the way to notify the user about
                                              the job (mail or script )
assigned_moldable_job INT UNSIGNED            moldable job chosen by the scheduler
checkpoint            INT UNSIGNED            number of seconds before the walltime
                                              to send the checkpoint signal to the
                                              job
checkpoint_signal     INT UNSIGNED            signal to use when checkpointing the
                                              job
stdout_file           TEXT                    file name where to redirect program
                                              STDOUT
stderr_file           TEXT                    file name where to redirect program
                                              STDERR

resubmit_job_id       INT UNSIGNED            if a job is resubmitted then the new
                                              one store the previous
===================== ======================  =======================================

:Primary key: job_id
:Index fields: state, reservation, queue_name, accounted

Explications about the "state" field:

 - "Waiting" : the job is waiting OAR sheduler decision.
 - "Hold" : user or administrator wants to hold the job (`oarhold`_ command).
   So it will not be scheduled by the system.
 - "toLaunch" : the OAR scheduler has attributed some nodes to the job. So it
   will be launched.
 - "toError" : something wrong occured and the job is going into the error
   state.
 - "toAckReservation" : the OAR sheduler must say "YES" or "NO" to the waiting
   `oarsub`_ command because it requested a reservation.
 - "Launching" : OAR has launched the job and will execute the user command
   on the first node.
 - "Running" : the user command is executing on the first node.
 - "Finishing" : the user command has terminated and OAR is doing work internally
 - "Terminated" : the job has terminated normally.
 - "Error" : a problem has occured.

Explications about the "reservation" field:

 - "None" : the job is not a reservation.
 - "toSchedule" : the job is a reservation and must be approved by the
   scheduler.
 - "Scheduled" : the job is a reservation and is scheduled by OAR.

*job_dependencies*
~~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
job_id            INT UNSIGNED          job identifier
job_id_required   INT UNSIGNED          job needed to be completed before
                                        launching job_id
================  ====================  =======================================

:Primary key: job_id, job_id_required
:Index fields: job_id, job_id_required

This table is feeded by `oarsub`_ command with the "-a" option.

*moldable_job_descriptions*
~~~~~~~~~~~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
moldable_id       INT UNSIGNED          job identifier
moldable_job_id   INT UNSIGNED          corresponding job identifier
moldable_wallime  VARCHAR(255)          instance duration
================  ====================  =======================================

:Primary key: moldable_id
:Index fields: moldable_job_id

A job can be described with several instances. Thus OAR scheduler can choose one
of them. For example it can calculate which instance will finish first.
So this table stores all instances for all jobs.

*job_resource_groups*
~~~~~~~~~~~~~~~~~~~~~

===================== ====================  =======================================
Fields                Types                 Descriptions
===================== ====================  =======================================
res_group_id          INT UNSIGNED          group identifier
res_group_moldable_id INT UNSIGNED          corresponding moldable job identifier
res_group_property    TEXT                  SQL constraint properties
===================== ====================  =======================================

:Primary key: res_group_id
:Index fields: res_group_moldable_id

As you can specify job global properties with `oarsub`_ and the "-p" option,
you can do the same thing for each resource groups that you define with
the "-l" option.

*job_resource_descriptions*
~~~~~~~~~~~~~~~~~~~~~~~~~~~

===================== ====================  =======================================
Fields                Types                 Descriptions
===================== ====================  =======================================
res_job_group_id      INT UNSIGNED          corresponding group identifier
res_job_resource_type VARCHAR(255)          resource type (name of a field in
                                            resources)
res_job_value         INT                   wanted resource number
res_job_order         INT UNSIGNED          order of the request
===================== ====================  =======================================

:Primary key: res_job_group_id, res_job_resource_type, res_job_order
:Index fields: res_job_group_id

This table store the hierarchical resource description given with `oarsub`_ and
the "-l" option.

*job_state_logs*
~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
job_id            INT UNSIGNED          corresponding job identifier
job_state         ENUM('Alive', 'Dead'  job state during the interval
                  , 'Suspected',
                  'Absent')
date_start        DATETIME              start date of the interval
date_stop         DATETIME              end date of the interval
================  ====================  =======================================

:Primary key: *None*
:Index fields: job_id, job_state

This table keeps informations about state changes of jobs.

*job_types*
~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
job_id            INT UNSIGNED          corresponding job identifier
type              VARCHAR(255)          job type like "deploy", "timesharing",
                                        ...
================  ====================  =======================================

:Primary key: *None*
:Index fields: job_id, type

This table stores job types given with the `oarsub`_ command and "-t" options.

*resources*
~~~~~~~~~~~

====================  ====================  =======================================
Fields                Types                 Descriptions
====================  ====================  =======================================
resource_id           INT UNSIGNED          resource identifier
network_address       VARCHAR(100)          node name (used to connect via SSH)
state                 ENUM('Alive', 'Dead'  resource state
                      , 'Suspected',
                      'Absent')
next_state            ENUM('UnChanged',     state for the resource to switch
                      'Alive', 'Dead',
                      'Absent',
                      'Suspected') DEFAULT
                      'UnChanged'
finaud_decision       ENUM('YES', 'NO')     tell if the actual state results in a
                      DEFAULT 'NO'          "finaud" module decision
next_finaud_decision  ENUM('YES', 'NO')     tell if the next node state results in
                      DEFAULT 'NO'          a "finaud" module decision
====================  ====================  =======================================

:Primary key: resource_id
:Index fields: state, next_state

State explications:

 - "Alive" : the resource is ready to accept a job.
 - "Absent" : the oar administrator has decided to pull out the resource. This
   computer can come back.
 - "Suspected" : OAR system has detected a problem on this resource and so has
   suspected it (you can look in the `event_logs`_ table to know what has
   happened). This computer can come back (automatically if this is a 
   "finaud" module decision).
 - "Dead" : The oar administrator considers that the resource will not come back
   and will be removed from the pool.

*resource_state_logs*
~~~~~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
resource_id       INT UNSIGNED          resource identifier
change_state      ENUM('Alive', 'Dead'  resource state during the interval
                  , 'Suspected',
                  'Absent')
date_start        DATETIME              start date of the interval
date_stop         DATETIME              end date of the interval
finaud_decision   ENUM('YES', 'NO')     specify if that was a "finaud" module
                  DEFAULT 'NO'          decision
================  ====================  =======================================

:Primary key: *None*
:Index fields: resource_id, change_state, finaud_decision

This table keeps informations about state changes of resources.

*resource_properties*
~~~~~~~~~~~~~~~~~~~~~

=================  ====================  =======================================
Fields             Types                 Descriptions
=================  ====================  =======================================
resource_id        INT UNSIGNED          resource identifier
node               VARCHAR(200)          node name
besteffort         ENUM('YES', 'NO')     specify if the resource accepts or not
                   DEFAULT 'YES'         besteffort jobs
deploy             ENUM('YES', 'NO')     specify if the resource accepts or not
                   DEFAULT 'NO'          deployment jobs
expiry_date        DATETIME              used in desktop computing mode to know
                                         when a resource is considered to be
                                         offline
desktop_computing  ENUM('YES', 'NO')     specify if the resource is a desktop
                   DEFAULT 'NO'          computing resource or not
last_job_date      INT UNSIGNED          unix time of the end of the last job
cm_availability    INT UNSIGNED          unix time when the resource will not be
                                         available anymore
cpuset             INT UNSIGNED          cpu number in the node
cpu                INT UNSIGNED          cpu number in the cluster
switch             VARCHAR(50)           switch name
=================  ====================  =======================================

:Primary key: resource_id
:Index fields: *None*

This table permits to specify different properties for each resources. These can
be used with the `oarsub`_ command ("-p" and "-l" options).

You can add your own properties with `oarproperty`_ command.

These properties can be updated with the `oarnodesetting`_ command ("-p" option).

*resource_property_logs*
~~~~~~~~~~~~~~~~~~~~~~~~

=================  ====================  =======================================
Fields             Types                 Descriptions
=================  ====================  =======================================
resource_id        INT UNSIGNED          resource identifier
attribute          VARCHAR(255)          name of corresponding field in
                                         resource_properties
value              VARCHAR(255)          value of the field
date_start         DATETIME              interval start date
date_stop          DATETIME              interval stop date
=================  ====================  =======================================

:Primary key: *None*
:Index fields: resource_id, attribute

This table permits to keep a trace of every property changes (consequence of
the `oarnodesetting`_ command with the "-p" option).

*assigned_resources*
~~~~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
moldable_job_id   INT UNSIGNED          job id
resource_id       INT UNSIGNED          resource assigned to the job
================  ====================  =======================================

:Primary key: moldable_job_id, resource_id
:Index fields: moldable_job_id

This table keeps informations for jobs on which resources they were
scheduled.

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

*challenges*
~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
job_id            INT UNSIGNED          job identifier
challenge         VARCHAR(255)          challenge string
================  ====================  =======================================

:Primary key: job_id
:Index fields: *None*

This table is used to share a secret between OAR server and oarexec process on
computing nodes (avoid a job id being stolen/forged by malicious user).

For security reasons, this table **must not be readable** for a database
account given to users who want to access OAR internal informations(like statistics).

Configuration file
==================

Each configuration tag found in /etc/oar.conf is now described:

  - Database type : you can use a MySQL or a PostgreSQL database (tags are
    "mysql" or "Pg")::
      
      DB_TYPE = mysql
  
  - Database hostname::
  
      DB_HOSTNAME=localhost

  - Database base name::
  
      DB_BASE_NAME=oar

  - DataBase user name::
      
      DB_BASE_LOGIN=oar

  - DataBase user password::
      
      DB_BASE_PASSWD=oar

  - OAR server hostname::
      
      SERVER_HOSTNAME=localhost

.. _SERVER_PORT:

  - OAR server port::
      
      SERVER_PORT=6666

  - When the user does not specify a -l option then oar use this::
  
      OARSUB_DEFAULT_RESOURCES = /resource_id=1
  
.. _DEPLOY_HOSTNAME:

  - Specify where we are connected in the deploy queue(the node to connect
    to when the job is in the deploy queue)::
      
      DEPLOY_HOSTNAME = 127.0.0.1

.. _DETACH_JOB_FROM_SERVER:

  - Set DETACH_JOB_FROM_SERVER to 1 if you do not want to keep a ssh
    connection between the node and the server. Otherwise set this tag to 0::
      
      DETACH_JOB_FROM_SERVER=1

  - By default OAR uses the ping command to detect if nodes are down or not.
    To enhance this diagnostic you can specify one of these other methods (
    give the complete command path):

      * OAR sentinelle::
      
          SENTINELLE_COMMAND=/usr/bin/sentinelle -cconnect=ssh,timeout=3000

        If you use sentinelle.pl or sentinelle.rb then you must use this tag::

          SENTINELLE_SCRIPT_COMMAND=/usr/bin/sentinelle.pl -t 5 -w 20

      * OAR fping::
      
          FPING_COMMAND=/usr/bin/fping -q 

      * OAR nmap : it will test to connect on the ssh port (22)::
      
          NMAP_COMMAND=/usr/bin/nmap -p 22 -n -T5

      * OAR generic : a specific script may be used instead of ping to check
        aliveness of nodes. The script must return bad nodes on STDERR (1 line
        for a bad node and it must have exactly the same name that OAR has
        given in argument of the command)::

          GENERIC_COMMAND=/path/to/command arg1 arg2

  - OAR log level: 3(debug+warnings+errors), 2(warnings+errors), 1(errors)::
      
      LOG_LEVEL=2

  - OAR log file::
      
      LOG_FILE=/var/log/oar.log

  - If you want to debug oarexec on nodes then affect 1 (only effective if
    DETACH_JOB_FROM_SERVER = 1)::

      OAREXEC_DEBUG_MODE=0

  - OAR Allowed networks, Networks or hosts allowed to submit jobs to OAR and
    compute nodes may be specified here(0.0.0.0/0 means all IPs are allowed
    and 127.0.0.1/32 means only IP 127.0.0.1 is allowed)::
      
      ALLOWED_NETWORKS= 127.0.0.1/32 0.0.0.0/0

.. _ACCOUNTING_WINDOW:

  - Set the granularity of the OAR accounting feature (in seconds). Default is
    1 day (86400s)::
      
      ACCOUNTING_WINDOW= 86400

.. _MAIL:

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

  - Set the timeout for the prologue and epilogue execution on computing
    nodes::

      PROLOGUE_EPILOGUE_TIMEOUT = 60

  - Files to execute before and after each job on the first computing node
    (default is ~oar/oar_prologue ans ~oar/oar_epilogue)::

      PROLOGUE_EXEC_FILE = /path/to/prog
      EPILOGUE_EXEC_FILE = /path/to/prog

  - Set the timeout for the prologue and epilogue execution on the OAR server::

      SERVER_PROLOGUE_EPILOGUE_TIMEOUT = 60

  - Files to execute before and after each job on the OAR server::
      
      SERVER_PROLOGUE_EXEC_FILE = /path/to/prog
      SERVER_EPILOGUE_EXEC_FILE = /path/to/prog

  - Set the frequency for checking Alive and Suspected resources::
      
      FINAUD_FREQUENCY = 300

.. _DEAD_SWITCH_TIME:

  - Set time after which resources become Dead (default is 0 and it means
    never)::

      DEAD_SWITCH_TIME = 600

  - Maximum of seconds used by a scheduler::

      SCHEDULER_TIMEOUT = 10

  - Time to wait when a reservation has not got all resources that it has
    reserved (some resources could have become Suspected or Absent since the
    job submission) before to launch the job in the remaining resources::

      RESERVATION_WAITING_RESOURCES_TIMEOUT = 300
  
  - Time to add between each jobs (time for administration tasks or time to
    let computers to reboot)::

      SCHEDULER_JOB_SECURITY_TIME = 1

  - Minimum time in seconds that can be considered like a hole where a job
    could be scheduled in::
  
      SCHEDULER_GANTT_HOLE_MINIMUM_TIME = 300

  - You can add an order preference on resource assigned by the system(SQL
    ORDER syntax)::

      SCHEDULER_RESOURCE_ORDER = switch ASC, node DESC, resource_id ASC

  - Indicate the name of the database field that contains the cpu number of
    the node. If this option is set then users must use `OARSH`_ instead of
    ssh to walk on each nodes that they have reserved via oarsub.
    ::

      CPUSET_RESOURCE_PROPERTY_DB_FIELD = cpuset

  - If you want to manage nodes to be started and stoped. OAR gives you this
    API:

.. _SCHEDULER_NODE_MANAGER_WAKE_UP_CMD:

    * When OAR scheduler wants some nodes to wake up then it launches this
      command with the node list in arguments(the scheduler looks at the
      *cm_availability* field in resource_properties_ table to know if the
      node will be started for enough time)::

        SCHEDULER_NODE_MANAGER_WAKE_UP_CMD = /path/to/the/command with your args

.. _SCHEDULER_NODE_MANAGER_SLEEP_CMD:

    * When OAR considers that some nodes can be shut down, it launches this
      command with the node list in arguments::

        SCHEDULER_NODE_MANAGER_SLEEP_CMD = /path/to/the/command args

.. _SCHEDULER_NODE_MANAGER_IDLE_TIME:

      + Parameters for the scheduler to decide when a node is idle(number of
        seconds since the last job was terminated on the nodes)::
        
          SCHEDULER_NODE_MANAGER_IDLE_TIME = 600

.. _SCHEDULER_NODE_MANAGER_SLEEP_TIME:

      + Parameters for the scheduler to decide if a node will have enough time
        to sleep(number of seconds before the next job)::

          SCHEDULER_NODE_MANAGER_SLEEP_TIME = 600

.. _OPENSSH_CMD:

  - Command to use to connect to other nodes (default is "ssh" in the PATH)
    ::

      OPENSSH_CMD = /usr/bin/ssh

  - These are configuration tags for OAR in the desktop-computing mode::
  
      DESKTOP_COMPUTING_ALLOW_CREATE_NODE=0
      DESKTOP_COMPUTING_EXPIRY=10
      STAGEOUT_DIR=/var/lib/oar/stageouts/
      STAGEIN_DIR=/var/lib/oar/stageins
      STAGEIN_CACHE_EXPIRY=144

Module descriptions
===================

OAR can be decomposed into several modules which perform different tasks.

Almighty
--------

This module is the OAR server. It decides what actions must be performed. It
is divided into 2 processes:

 - One listens to a TCP/IP socket. It waits informations or commands from OAR
   user program or from the other modules.
 - Another one deals with commands thanks to an automaton and launch right
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
 - Can change "Suspected" resources into "Dead" after DEAD_SWITCH_TIME_ seconds.

Judas
-----

This is the module dedicated to print and log every debugging, warning and
error messages.

Leon
----

This module is in charge to delete the jobs. Other OAR modules or commands
can ask to kill a job and this is Leon which performs that.

There are 2 frag types :

 - *normal* : Leon tries to connect to the first node allocated for the job and
   terminates the job.
   oarexec to end itself.
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

Runner
------

This module launches OAR effective jobs. These processes are run asynchronously
with all modules.

For each job, the Runner_ uses OPENSSH_CMD_ to connect to the first node of the
reservation and propagate a Perl script which handles the execution of the user
command. 

Mechanisms
==========

.. _INTERACTIVE:

How does an interactive *oarsub* work?
--------------------------------------

.. figure:: interactive_oarsub_scheme.png
   :width: 17cm
   :alt: interactive oarsub decomposition
   :target: interactive_oarsub_scheme.png

   Interactive oarsub decomposition

`interactive_oarsub_scheme.svg <interactive_oarsub_scheme.svg>`_

Job launch
----------

For PASSIVE jobs, the mechanism is similar to the INTERACTIVE_ one, except for
the shell launched from the frontal node.

The job is finished when the user command ends. Then oarexec return its exit
value (what errors occured) on the Almighty_ via the SERVER_PORT_ if
DETACH_JOB_FROM_SERVER_ was set to 1 otherwise it returns directly.


CPUSET
------

If the "--force_cpuset_name" option of the oarsub_ command is not defined then
OAR will use job identifier. The CPUSET name is effectively created on each
nodes is composed as "user_cpusetname".

So if a user specifies "--force_cpuset_name" option, he will not be able to
disturb other users.

OAR system steps:

 1. Before each job, the Runner_ initialize the CPUSET (see `CPUSET
    definition`_) with OPENSSH_CMD_ and an efficient launching tool : `Taktuk
    <https://gforge.inria.fr/projects/taktuk/>`_. If it is not installed then OAR
    uses an internal launching tool less optimized.

 2. Afer each job, OAR deletes all processes stored in the associated CPUSET.
    Thus all nodes are clean after a OAR job.

If you don't want to use this feature, you can, but nothing will waranty that
every user processes will be killed after the end of a job.

Job deletion
------------

Leon_ tries to connect to OAR Perl script running on the first job node (find
it thanks to the file */tmp/oar/pid_of_oarexec_for_jobId_id*) and sends a
"SIGTERM" signal. Then the script catch it and normally end the job (kill
processes that it has launched).

If this method didn't succeed then Leon_ will flush the OAR database for the
job and nodes will be "Suspected" by NodeChangeState_.

Checkpoint
----------

The checkpoint is just a signal sent to the program specified with the oarsub_
command.

If the user uses "-k" option then Sarko_ will ask the OAR Perl script running
on the first node to send the signal to the process (SIGUSR2 or the one
specified with "--signal").

You can also use oardel_ command to send the signal.

Scheduling
----------

General steps used to schedule a job:
  
  1. All previous scheduled jobs are stored in a Gantt data strucuture.
  
  2. All resources that match property constraints of the job("-p" option and
     indication in the "{...}" from the "-l" option of the oarsub_) are stored in
     a tree datat structure according to the hierarchy given with the "-l" option.
  
  3. Then this tree is given to the Gantt library to find the first hole where
     the job can be launched.
  
  4. The scheduler stores its decision into the database in the
     gantt_jobs_predictions_ and gantt_jobs_resources_ tables.

See User_ section from the FAQ_ for more examples and features.

User notification
-----------------

This section explains how the "--notify" oarsub_ option is handled by OAR:

 - The user wants to receive an email:
     
     The syntax is "mail:name@domain.com". Mail_ section in the `Configuration
     file`_ must be present otherwise the mail cannot be sent.
 - The user wants to launch a script:

     The syntax is "exec:/path/to/script args". OAR server will connect (using
     OPENSSH_CMD_) on the node where the oarsub_ command was invoked and then
     launches the script with in argument : *job_id*, *job_name*, *tag*,
     *comments*.
     
     (*tag* is a value in : "START", "END", "ERROR")

Accounting aggregator
---------------------

In the `Configuration file`_ you can set the ACCOUNTING_WINDOW_ parameter. Thus
the command oaraccounting_ will split the time with this amount and feed the
table accounting_.

So this is very easily and faster to get usage statistics of the cluster. We
can see that like a "datawarehousing" information extraction method.

Dynamic nodes coupling features
-------------------------------

We are working with the `Icatis <http://www.icatis.com/>`_ company on clusters
composed by intranet computers. These nodes can be switch in computing mode
only at specific times. So we have implemented a functionality that can
request to power on some hardware if they can be in the cluster.

We are using the field *cm_availability* from the table resource_properties_
to know when a node will be inaccessible in the cluster mode (easily setable
with oarnodesetting_ command). So when the OAR scheduler wants some potential
available computers to launch the jobs then it executes the command
SCHEDULER_NODE_MANAGER_WAKE_UP_CMD_.

Moreover if a node didn't execute a job for SCHEDULER_NODE_MANAGER_IDLE_TIME_
seconds and no job is scheduled on it before SCHEDULER_NODE_MANAGER_SLEEP_TIME_
seconds then OAR will launch the command SCHEDULER_NODE_MANAGER_SLEEP_CMD_.

Timesharing
-----------

It is possible to share the slot time of a job with other ones.
To perform this feature you have to specify the type *timesharing* when you use
oarsub_.

You have 4 different ways to share your slot:
  1. *timesharing=\*,\** : This is the default behavior if nothing but
     timesharing is specified.
     It indicates that the job can be shared with all users and every job
     names.
  
  2. *timesharing=user,\** : This indicates that the job can be shared only
     with the same user and every job names.

  3. *timesharing=\*,job_name\** : This indicates that the job can be shared
     with all users but only one with the same name.

  4. *timesharing=user,job_name* : This indicates that the job can be shared
     only with the same user and one with the same job name.

See User_ section from the FAQ_ for more examples and features.

Besteffort jobs
---------------

Besteffort jobs are scheduled in the besteffort queue. Their particularity is
that they are deleted if another not besteffort job want resources where they
are running.

For example you can use this feature to maximize the use of your cluster with
multiparametric jobs. This what it is done by the
`CIGRI <http://cigri.ujf-grenoble.fr>`_ project.

When you submit a job you have to use "-t besteffort" option of oarsub_ to
specify that this is a besteffort job.

Note : a besteffort job cannot be a reservation.

Cosystem jobs
-------------

This feature enables to reserve some resources without launching any
program on corresponding nodes. Thus nothing is done by OAR when a
job is starting (no prologue, no epilogue on the server nor on the nodes).

This is usefull with an other launching system that will declare its time
slot in OAR. So yo can have two different batch scheduler.

When you submit a job you have to use "-t cosystem" option of oarsub_ to
specify that this is a besteffort job.

These jobs are stopped by the oardel_ command or when they reach their
walltime.

Deploy jobs
-----------

This feature is usefull when you want to enable the users to reinstall their
reserved nodes. So the OAR jobs will not log on the first computer of the
reservation but on the DEPLOY_HOSTNAME_.

So prologue and epilogue scripts are executed on DEPLOY_HOSTNAME_ and if the
user wants to launch a script it is also executed on DEPLOY_HOSTNAME_.

OAR does nothing on computing nodes because they normally will be rebooted to
install a new system image.

This feature is strongly used in the `Grid5000 <https://www.grid5000.fr/>`_
project with `Kadeploy <http://ka-tools.imag.fr/>`_ tools.

When you submit a job you have to use "-t deploy" option of oarsub_ to
specify that this is a deploy job.

.. include:: ../../FAQ

.. include:: ../../CHANGELOG

