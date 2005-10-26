
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
            
  -f    prints each job in full details
  -a    prints more details and keeps table format
                    
Examples
::
            
  # oarstat
  # oarstat -f
                    
*oarnodes*
~~~~~~~~~~

This command prints informations about cluster nodes (state, which jobs on
which nodes, node properties, ...)
      
Example
::

  # oarnodes

*oarsub*
~~~~~~~~

The user can submit a job with this command. So, what is a job in our context?
                  
  A job is defined by needed resources and a script/program to run. So, the user
  must specify how many nodes and what kind of resources needed by his
  application. Thus, OAR system will give him or not what he wants and will
  control the execution. When a job is launched, OAR executes user program only
  on the first reservation node. So this program can access some environnement
  variables to know its environnement
  ::
                  
    $OAR_NODEFILE    contains the name of a file which lists all reserved nodes
                     for this job
    $OAR_JOBID       contains the OAR job identificator
    $OAR_NB_NODES    contains the number of reserved nodes

Options::
                  
  -q "queuename" : specify the queue for this job
  -I : turn on INTERACTIVE mode (OAR gives you a shell instead of executing a script)
  -l : defines resource list requested for this job; the different parameters are: 
        nodes : request number of nodes
        weight : the weight that you want to reserve on each node
        walltime : Request maximun time. Format is [hour:mn:sec|hour:mn|hour];
                   after this elapsed time, the job will be killed 
  -p "properties" : specify with SQL syntax reservation properties
  -r "2004-05-11 23:32:03" : ask for a reservation job to begin at the date in argument
  -c jobId : connect to a reservation in Running state
  -v : turn on verbose mode

Exemples
::

    # oarsub test.sh

(the "test.sh" script will be run on 1 node of default weight in the default 
queue with a walltime of 1 hour)
::

  # oarsub -l nodes=2,walltime=2:15:00 test.sh
    
(the "test.sh" script will be run on 2 nodes of default weight in the default
queue with a walltime of  2:15:00)
::
     
  # oarsub -p "hostname = 'host2' OR hostname = 'host3'" test.sh

(the "test.sh" script will be run on the node host2 or on the node host3)
::

# oarsub -I

(gives a shell on a node)

*oardel*
~~~~~~~~

The user can delete his jobs with this command.

Exemples
::
                         
  # oardel 14
    
(delete job 14)

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

*oarnodesetting*
~~~~~~~~~~~~~~~~

This command permits to change the state or a property of a node. If it does
not exist it is created.

By default the node name used by *oarnodesetting* is the result of the command
*hostname*.

Options are:

 - -s : state to assign to the node:

    * "Alive" : a job can be run on the node.
    * "Absent" : administrator wants to remove the node from the pool for a moment.
    * "Dead" : the node will not be used and will be deleted.
    
 - -h : specify the node name.
 - -w : if the node does not exist, it will be created in the database and its
   maxWeight will be the value of this option (default is 1).
 - -p : change the value of a property of the node.
 - -n : specify this option if you do not want to wait the end of jobs running
   on this node when you change its state into "Absent" or "Dead".

*oarremovenode*
~~~~~~~~~~~~~~~

This command permits to remove a node from the database.

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
user              VARCHAR(20)           user name
queue_name        VARCHAR(100)          queue name
consumption_type  ENUM("ASKED","USED")  "ASKED" corresponds to the walltimes
                                        specified by the user. "USED"
                                        corresponds to the effective time
                                        used by the user.
consumption       INT UNSIGNED          number of seconds used
================  ====================  =======================================

:Primary key: window_start, window_stop, user, queue_name, consumption_type
:Index fields: window_start, window_stop, user, queue_name, consumption_type

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

*admissionRules*
~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
rule              VARCHAR(255)          rule written in Perl applied when a
                                        job is going to be registered
================  ====================  =======================================

:Primary key: *None*
:Index fields: *None*

You can use these rules to change some values of some properties when a job is
submitted. Some examples are better than a long description :

 - Specify the default walltime
   ::
   
      INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES
      ('if (not defined($maxTime)) {
          $maxTime = "1:00:00";
      }');

 - Specify the default value for queue parameter
   ::
      
      INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES
      ('if (not defined($queueName)) {
          $queueName="default";
      }');

 - Restrict the maximum of the walltime for intercative jobs
   ::
      
      INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES
      ('if ((defined($maxTime)) &&
            ($jobType eq "INTERACTIVE") &&
            (sql_to_duration($maxTime) > sql_to_duration("12:00:00"))){
            $maxTime = "12:00:00";
      }');

 - Avoid users except oar to go in the admin queue
   ::
      
      INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES
      ('if (($queueName eq "admin") && ($user ne "oar")) {
          $queueName="default";
      }');
      
 - Force besteffort jobs to go on nodes with the besteffort property
   ::
   
      INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES
      ('if ( "$queueName" eq "besteffort" ){
          if ($jobproperties ne ""){
              $jobproperties = "($jobproperties)
              AND besteffort = \\\\\\"YES\\\\\\"";
          }else{
              $jobproperties = "besteffort = \\\\\\"YES\\\\\\"";
          } 
      }');

 - Force deploy jobs to go on nodes with the deploy property
   ::
   
      INSERT IGNORE INTO `admissionRules` ( `rule` ) VALUES
      ('if ( "$queueName" eq "deploy" ){
          if ($jobproperties ne ""){
              $jobproperties = "($jobproperties)
              AND deploy = \\\\\\"YES\\\\\\"";
          }else{
              $jobproperties = "deploy = \\\\\\"YES\\\\\\"";
          }
      }');

*event_log*
~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
type              VARCHAR(50)           event type
idJob             INT UNSIGNED          job related of the event
date              DATETIME              event date
description       VARCHAR(255)          textual description of the event
toCheck           ENUM('YES','NO')      specify if the module *NodeChangeState*
                                        must check this event to Suspect or not
                                        some nodes
================  ====================  =======================================

:Primary key: *None*
:Index fields: type, toCheck

The different event types are:

 - "PING_CHECKER_NODE_SUSPECTED" : the system detected via the module "finaud"
   that a node is not responding.
 - "PROLOGUE_ERROR" : an error occured during the execution of the job
   prologue (exit code != 0).
 - "EPILOGUE_ERROR" : an error occured during the execution of the job
   epilogue (exit code != 0).
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
 - "OUTPUT_FILES" : OAR can not write the output files (stdout and stderr) in
   the working directory.
 - "CAN_NOT_NOTIFY_OARSUB" : OAR can not notify the oarsub process for an
   interactive job (maybe the user has killed this process).
 - "WALLTIME" : the job has reached its walltime.
 - "SCHEDULER_REDUCE_NB_NODES_FOR_RESERVATION" : this means that there is not
   enough nodes for the reservation and so the scheduler do the best and
   gives less nodes than the user wanted (this occures when nodes become
   Suspected or Absent).
 - "BESTEFFORT_KILL" : the job is of the type *besteffort* and was killed
   because a normal job wanted the nodes.

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

*fragJobs*
~~~~~~~~~~

================  ==========================  =================================
Fields            Types                       Descriptions
================  ==========================  =================================
fragIdJob         INT UNSIGNED                job id
fragDate          DATETIME                    kill job decision date 
fragState         ENUM('LEON','TIMER_ARMED',  state to tell Leon what to do
                  'LEON_EXTERMINATE',
                  'FRAGGED')
                  DEFAULT 'LEON'
================  ==========================  =================================

:Primary key: fragIdJob
:Index fields: fragState

What mean the states:

 - "LEON" : the Leon module must try to kill the job and change the state into
   "TIMER_ARMED".
 - "TIMER_ARMED" : the Sarko module must wait a response from the job during
   a timeout (default is 60s)
 - "LEON_EXTERMINATE" : the Sarko module has decided that the job timeouted and
   asked Leon to clean up the database.
 - "FRAGGED" : job is fragged.

*ganttJobsNodes*
~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
idJob             INT UNSIGNED          job id
hostname          VARCHAR(100)          node assigned to the job
================  ====================  =======================================

:Primary key: idJob, hostname
:Index fields: *None*

This table specifies which node is attributed to which job.

*ganttJobsNode_visu*
~~~~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
idJob             INT UNSIGNED          job id
hostname          VARCHAR(100)          node assigned to the job
================  ====================  =======================================

:Primary key: idJob, hostname
:Index fields: *None*

This table is the same as *ganttJobsNode* and is used by visualisation tools.
It is made up to date in an atomic action (with a lock).

*ganttJobsPrediction*
~~~~~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
idJob             INT UNSIGNED          job id
startTime         DATETIME              date when the job is scheduled to start
================  ====================  =======================================

:Primary key: idJob
:Index fields: *None*

With this table and *ganttJobsNode* you can know exactly what are the decisions
taken by the schedulers for each waiting jobs.

:note: The special job id "0" is ued to store the scheduling reference date.

*ganttJobsPrediction_visu*
~~~~~~~~~~~~~~~~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
idJob             INT UNSIGNED          job id
startTime         DATETIME              date when the job is scheduled to start
================  ====================  =======================================

:Primary key: idJob
:Index fields: *None*

This table is the same as *ganttJobsPrediction* and is used by visualisation
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

*queue*
~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
queueName         VARCHAR(100)          queue name
priority          INT UNSIGNED          the scheduling priority
schedulerPolicy   VARCHAR(100)          path of the associated scheduler
state             ENUM('Active',        permits to stop the scheduling for a
                  'notActive')          queue
                  DEFAULT 'Active'
================  ====================  =======================================

:Primary key: queueName
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
