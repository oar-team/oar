===================
 OAR Documentation 
===================

.. image:: oar_logo.png
   :alt: OAR logo
   :align: center
   :width: 8cm

:Author: Capit Nicolas
:Address: Laboratoire d'Informatique de Grenoble 
          Bat. ENSIMAG - antenne de Montbonnot
          ZIRST 51, avenue Jean Kuntzmann
          38330 MONTBONNOT SAINT MARTIN
:Contact: nicolas.capit@imag.fr, joseph.emeras@imag.fr
:Authors: LIG laboratory
:Organization: LIG laboratory
:Status: Stable
:Copyright: licenced under the GNU GENERAL PUBLIC LICENSE

:Dedication: For users, administrators and developpers.

:Abstract:

  OAR is a resource manager (or batch scheduler) for large clusters. In
  functionnalities, it's near of PBS, LSF, CCS and Condor. It's suitable for
  productive plateforms and research experiments.


**BE CAREFULL : THIS DOCUMENTATION IS FOR OAR >= 2.3.0**

PDF version : `<OAR-DOCUMENTATION.pdf>`_

.. section-numbering::
.. contents:: Table of Contents

-------------------------------------------------------------------------------

OAR capabilities
================
Oar is an opensource batch scheduler which provides a simple and flexible
exploitation of a cluster.

It manages resources of clusters as a traditional batch scheduler
(as PBS / Torque / LSF / SGE). In other words, it doesn't execute your job on 
the resources but manages them (reservation, acces granting) in order to allow
you to connect these resources and use them.

Its design is based on high level tools: 
  - relational database engine MySQL or PostgreSQL,
  - scripting language Perl,  
  - confinement system mechanism cpuset,
  - scalable exploiting tool Taktuk.

It is flexible enough to be suitable for production clusters and research
experiments.
It currently manages over than 5000 nodes and has executed more than 5 million
jobs.

OAR advantages:
  - No specific daemon on nodes.
  - No dependence on specific computing libraries like MPI. We support all
    sort of parallel user applications.
  - Upgrades are made on the servers, nothing to do on computing nodes.
  - CPUSET (2.6 linux kernel) integration which restricts the jobs on
    assigned resources (also useful to clean completely a job, even
    parallel jobs).
  - All administration tasks are performed with the taktuk command (a large
    scale remote execution deployment): http://taktuk.gforge.inria.fr/.
  - Hierarchical resource requests (handle heterogeneous clusters).
  - Gantt scheduling (so you can visualize the internal scheduler decisions).
  - Full or partial time-sharing.
  - Checkpoint/resubmit.
  - Licences servers management support.
  - Best effort jobs : if another job wants the same resources then it is
    deleted automatically (useful to execute programs like *SETI@home*).
  - Environment deployment support (Kadeploy):
    http://kadeploy.imag.fr/.

Other more *common* features:
  - Batch and Interactive jobs.
  - Admission rules.
  - Walltime.
  - Multi-schedulers support.
  - Multi-queues with priority.
  - Backfilling.
  - First-Fit Scheduler.
  - Reservation.
  - Support of moldable tasks.
  - Check compute nodes.
  - Epilogue/Prologue scripts.
  - Support of dynamic nodes.
  - Logging/Accounting.
  - Suspend/resume jobs.

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

  -f                    : prints each job in full details
  -j job_id             : prints the specified job_id informations (even if it is finished)
  --sql "sql where"     : Restricts display with the SQL where clause on the table jobs
  -g "d1,d2"            : prints history of jobs and state of resources between two dates.
  -D                    : formats outputs in Perl Dumper
  -X                    : formats outputs in XML
  -Y                    : formats outputs in YAML
                    
Examples
::
            
  # oarstat
  # oarstat -j 42 -f
  # oarstat --sql "project = 'p1'"
                    
*oarnodes*
~~~~~~~~~~

This command prints informations about cluster resources (state, which jobs on
which resources, resource properties, ...).

Options
::

  -a                : shows all resources with their properties
  -r                : show only properties of a resource
  -s                : shows only resource states
  -l                : shows only resource list
  --sql "sql where" : Display resources which matches this sql where clause
  -D                : formats outputs in Perl Dumper
  -X                : formats outputs in XML
  -Y                : formats outputs in YAML

Examples
::

  # oarnodes 
  # oarnodes -s
  # oarnodes --sql "state = 'Suspected'"

*oarsub*
~~~~~~~~

The user can submit a job with this command. So, what is a job in our context?
                  
  A job is defined by needed resources and a script/program to run. So, the user
  must specify how many resources and what kind of them are needed by his
  application. Thus, OAR system will give him or not what he wants and will
  control the execution. When a job is launched, OAR executes user program only
  on the first reservation node. So this program can access some environment
  variables to know its environment:
  ::
                  
    $OAR_NODEFILE                 contains the name of a file which lists
                                  all reserved nodes for this job
    $OAR_JOB_ID                   contains the OAR job identificator
    $OAR_RESOURCE_PROPERTIES_FILE contains the name of a file which lists
                                  all resources and their properties
    $OAR_JOB_NAME                 name of the job given by the "-n" option
    $OAR_PROJECT_NAME             job project name


Options::

 -I, --interactive             Request an interactive job. Open a login shell
                               on the first node of the reservation instead of
                               running a script.
 -C, --connect=<job id>        Connect to a running job
 -l, --resource=<list>         Set the requested resources for the job.
                               The different parameters are resource properties
                               registered in OAR database, and `walltime' which
                               specifies the duration before the job must be 
                               automatically terminated if still running.
                               Walltime format is [hour:mn:sec|hour:mn|hour].
                               Ex: nodes=4/cpu=1,walltime=2:00:00
 -S, --scanscript              Batch mode only: asks oarsub to scan the given
                               script for OAR directives (#OAR -l ...)
 -q, --queue=<queue>           Set the queue to submit the job to
 -p, --property="<list>"       Add constraints to properties for the job.
                               (format is a WHERE clause from the SQL syntax)
 -r, --reservation=<date>      Request a job start time reservation, 
                               instead of a submission. 
     --checkpoint=<delay>      Enable the checkpointing for the job. A signal 
                               is sent DELAY seconds before the walltime on
                               the first processus of the job 
     --signal=<#sig>           Specify the signal to use when checkpointing
                               Use signal numbers, default is 12 (SIGUSR2)
 -t, --type=<type>             Specify a specific type (deploy, besteffort,
                               cosystem, checkpoint, timesharing)
 -d, --directory=<dir>         Specify the directory where to launch the
                               command (default is current directory)
     --project=<txt>           Specify a name of a project the job belongs to
 -n, --name=<txt>              Specify an arbitrary name for the job
 -a, --anterior=<job id>       Anterior job that must be terminated to start
                               this new one
     --notify=<txt>            Specify a notification method
                               (mail or command to execute). Ex: 
                                   --notify "mail:name\@domain.com"
                                   --notify "exec:/path/to/script args"
     --resubmit=<job id>       Resubmit the given job as a new one
 -k, --use-job-key             Activate the job-key mechanism.
 -i, --import-job-key-from-file=<file>
                               Import the job-key to use from a files instead
                               of generating a new one.
     --import-job-key-inline=<txt>
                               Import the job-key to use inline instead of
                               generating a new one.
 -e  --export-job-key-to-file=<file>
                               Export the job key to a file. Warning: the
                               file will be overwritten if it already exists.
                               (the %jobid% pattern is automatically replaced)
 -O  --stdout=<file>           Specify the file that will store the standart
                               output stream of the job.
                               (the %jobid% pattern is automatically replaced)
 -E  --stderr=<file>           Specify the file that will store the standart
                               error stream of the job.
                               (the %jobid% pattern is automatically replaced)
     --hold                    Set the job state into Hold instead of Waiting,
                               so that it is not scheduled (you must run
                               "oarresume" to turn it into the Waiting state)
 -s, --stagein=<dir|tgz>       Set the stagein directory or archive
     --stagein-md5sum=<md5sum> Set the stagein file md5sum
 -D, --dumper                  Print result in DUMPER format
 -X, --xml                     Print result in XML format
 -Y, --yaml                    Print result in YAML format
 -h, --help                    Print this help message
 -V, --version                 Print OAR version number

Wanted resources have to be described in a hierarchical manner using the  
"-l" syntax option.

Moreover it is possible to give a specification that must be matched on properties.

So the long and complete syntax is of the form::

    "{ sql1 }/prop1=1/prop2=3+{sql2}/prop3=2/prop4=1/prop5=1+...,walltime=1:00:00"

where:
 - *sql1* : SQL WHERE clause on the table of resources that filters resource
   names used in the hierarchical description
 - *prop1* : first type of resources
 - *prop2* : second type of resources
 - *+* : add another resource hierarchy to the previous one
 - *sql2* : SQL WHERE clause to apply on the second hierarchy request
 - ...

So we want to reserve 3 resources with the same value of the type *prop2* and
with the same property *prop1* and these resources must fit *sql1*. To that
possible resources we want to add 2 others which fit *sql2* and the hierarchy
*/prop3=2/prop4=1/prop5=1*.


.. figure:: hierarchical_resources.png
   :width: 17cm
   :target: hierarchical_resources.png
   :alt: Hierarchical resource example

   Example of a resource hierarchy and 2 different oarsub commands

`hierarchical_resources.svg <hierarchical_resources.svg>`_



Examples
::

  # oarsub -l /node=4 test.sh

(the "test.sh" script will be run on 4 entire nodes in the default queue with
the default walltime)
::

  # oarsub --stdout='test12.%jobid%.stdout' --stderr='test12.%jobid%.stderr' -l /nodes=4 test.sh
    ...
    OAR_JOB_ID=702
    ...

(same example than above but here the standard output of "test.sh" will be
written in the file "test12.702.stdout" and the standard error in
"test12.702.stderr")

::

  # oarsub -q default -l /node=10/cpu=3,walltime=2:15:00 \
    -p "switch = 'sw1'" /home/users/toto/prog
    
(the "/home/users/toto/prog" script will be run on 10 nodes with 3 cpus (so a
total of 30 cpus) in the default queue with a walltime of  2:15:00.
Moreover "-p" option restricts resources only on the switch 'sw1')
::
     
  # oarsub -r "2009-04-27 11:00:00" -l /node=12/cpu=2

(a reservation will begin at "2009-04-27 11:00:00" on 12 nodes with 2 cpus
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
  
  --sql     : delete/checkpoint jobs which respond to the SQL where clause
              on the table jobs (ex: "project = 'p1'")
  -c job_id : send checkpoint signal to the job (signal was
              definedwith "--signal" option in oarsub)

Examples
::

  # oardel 14 42
    
(delete jobs 14 and 42)
::

  # oardel -c 42

(send checkpoint signal to the job 42)

*oarhold*
~~~~~~~~~

This command is used to remove a job from the scheduling queue if it is in
the "Waiting" state.

Moreover if its state is "Running" oarhold_ can suspend the execution and
enable other jobs to use its resources. In that way, a **SIGINT** signal
is sent to every processes.

Options
::

  --sql : hold jobs which respond to the SQL where clause on the table
          jobs (ex: "project = 'p1'")
  -r    : Manage not only Waiting jobs but also Running one
          (can suspend the job)


*oarresume*
~~~~~~~~~~~

This command resumes jobs in the states *Hold* or *Suspended*

Option
::

  --sql : resume jobs which respond to the SQL where clause on the table
          jobs (ex: "project = 'p1'")

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
and to know when a job will be launched in the future.


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

 -a    : add a new resource
 -s    : state to assign to the node:
         * "Alive" : a job can be run on the node.
         * "Absent" : administrator wants to remove the node from the pool
            for a moment.
         * "Dead" : the node will not be used and will be deleted. 
 -h    : specify the node name (override hostname).
 -r    : specify the resource number
 --sql : get resource identifiers which respond to the
         SQL where clause on the table jobs
         (ex: "type = 'default'")
 -p    : change the value of a property specified resources.
 -n    : specify this option if you do not want to wait the end of jobs running
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

Option "--reinitialize" removes everything in the `accounting`_ table and
switches the "accounted" field of the table `jobs`_ into "NO". So when you will
launch the oaraccounting_ command again, it will take the whole jobs.

Option "--delete_before" removes records from the `accounting`_ table that are
older than the amount of time specified. So if the table becomes too big you
can shrink old data; for example::

    oaraccounting --delete_before 2678400

(Remove everything older than 31 days)

*oarnotify*
~~~~~~~~~~~

This command sends commands to the `Almighty`_ module and manages scheduling
queues.

Option are: ::

      Almighty_tag    send this tag to the Almighty (default is TERM)                      
  -e                  active an existing queue
  -d                  inactive an existing queue
  -E                  active all queues
  -D                  inactive all queues
  --add_queue         add a new queue; syntax is name,priority,scheduler
                      (ex: "name,3,"oar_sched_gantt_with_timesharing"
  --remove_queue      remove an existing queue
  -l                  list all queues and there status
  -h                  show this help screen
  -v                  print OAR version number

*oarmonitor*
~~~~~~~~~~~~

This command collects monitoring data from compute nodes and stores them into
the database.

The TAKTUK_CMD_ is mandatory in the *oar.conf* and data comes from the sensor
file OARMONITOR_SENSOR_FILE_ (parse */proc* filesystem for example) and print
it in the right way.

For example, the user "oar" or "root" can run the following command on the
server:

    oarmonitor -j 4242 -f 10

(Retrieve data from compute nodes of the job 4242 every 10 seconds and store
them into database tables monitoring_*)

For now, there is just a very minimalist command for the user to view these
data. It creates PNG images and a movie...

    oarmonitor_graph_gen.pl -j 4242

Then the user can look into the directory *OAR.1653.monitoring* in the current
directory.

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

Note : all dates and duration are stored in an integer manner (number of
seconds since the EPOCH).

*accounting*
~~~~~~~~~~~~

==================  ====================  =======================================
Fields              Types                 Descriptions
==================  ====================  =======================================
window_start        INT UNSIGNED          start date of the accounting interval
window_stop         INT UNSIGNED          stop date of the accounting interval
accounting_user     VARCHAR(20)           user name
accounting_project  VARCHAR(255)          name of the related project
queue_name          VARCHAR(100)          queue name
consumption_type    ENUM("ASKED",         "ASKED" corresponds to the walltimes
                    "USED")               specified by the user. "USED"
                                          corresponds to the effective time
                                          used by the user.
consumption         INT UNSIGNED          number of seconds used
==================  ====================  =======================================

:Primary key: window_start, window_stop, accounting_user, queue_name,
              accounting_project, consumption_type
:Index fields: window_start, window_stop, accounting_user, queue_name,
               accounting_project, consumption_type

This table is a summary of the consumption for each user on each queue. This
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
rule              TEXT                  rule written in Perl applied when a
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

 - Restrict the maximum of the walltime for interactive jobs
   ::
 
      INSERT INTO admission_rules (rule) VALUES ('
        my $max_walltime = iolib::sql_to_duration("12:00:00");
        if ($jobType eq "INTERACTIVE"){ 
          foreach my $mold (@{$ref_resource_list}){
            if (
              (defined($mold->[1])) and
              ($max_walltime < $mold->[1])
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
      my $default_wall = iolib::sql_to_duration("2:00:00");
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
date              INT UNSIGNED          event date
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
 - "PROLOGUE_ERROR" : an error occurred during the execution of the job
   prologue (exit code != 0).
 - "EPILOGUE_ERROR" : an error occurred during the execution of the job
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
 - "LEON_KILL_BIPBIP_TIMEOUT" : Leon module has detected that something wrong
   occurred during the kill of a job and so kill the local *bipbip* process.
 - "EXTERMINATE_JOB" : Leon module has detected that something wrong occurred
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
   gives less nodes than the user wanted (this occurres when nodes become
   Suspected or Absent).
 - "BESTEFFORT_KILL" : the job is of the type *besteffort* and was killed
   because a normal job wanted the nodes.
 - "FRAG_JOB_REQUEST" : someone wants to delete a job.
 - "CHECKPOINT" : the checkpoint signal was sent to the job.
 - "CHECKPOINT_ERROR" : OAR cannot send the signal to the job.
 - "CHECKPOINT_SUCCESS" : system has sent the signal correctly.
 - "SERVER_EPILOGUE_TIMEOUT" : epilogue server script has time outed.
 - "SERVER_EPILOGUE_EXIT_CODE_ERROR" : epilogue server script did not return 0.
 - "SERVER_EPILOGUE_ERROR" : cannot find epilogue server script file.
 - "SERVER_PROLOGUE_TIMEOUT" : prologue server script has time outed.
 - "SERVER_PROLOGUE_EXIT_CODE_ERROR" : prologue server script did not return 0.
 - "SERVER_PROLOGUE_ERROR" : cannot find prologue server script file.
 - "CPUSET_CLEAN_ERROR" : OAR cannot clean correctly cpuset files for a job
   on the remote node.
 - "MAIL_NOTIFICATION_ERROR" : a mail cannot be sent.
 - "USER_MAIL_NOTIFICATION" : user mail notification cannot be performed.
 - "USER_EXEC_NOTIFICATION_ERROR" : user script execution notification cannot
   be performed.
 - "BIPBIP_BAD_JOBID" : error when retrieving informations about a running job.
 - "BIPBIP_CHALLENGE" : OAR is configured to detach jobs when they are launched
   on compute nodes and the job return a bad challenge number.
 - "RESUBMIT_JOB_AUTOMATICALLY" : the job was automatically resubmitted.
 - "WALLTIME" : the job reached its walltime.
 - "REDUCE_RESERVATION_WALLTIME" : the reservation job was shrunk.
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

This table stores hostnames related to events like
"PING_CHECKER_NODE_SUSPECTED".

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
frag_date         INT UNSIGNED                kill job decision date 
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
 - "LEON_EXTERMINATE" : the Sarko module has decided that the job time outed and
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
start_time        INT UNSIGNED          date when the job is scheduled to start
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
start_time        INT UNSIGNED          date when the job is scheduled to start
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
                      'Suspended',
                      'Resuming',
                      , 'Finishing',
                      'Terminated', 'Error')
reservation           ENUM('None',            specify if the job is a reservation
                      'toSchedule',           and the state of this one
                      'Scheduled') DEFAULT
                      'None'
message               VARCHAR(255)            readable information message for the
                                              user
job_user              VARCHAR(255)             user name
command               TEXT                    program to run
queue_name            VARCHAR(100)            queue name
properties            TEXT                    properties that assigned nodes must
                                              match
launching_directory   TEXT                    path of the directory where to launch
                                              the user process
submission_time       INT UNSIGNED            date when the job was submitted
start_time            INT UNSIGNED            date when the job was launched
stop_time             INT UNSIGNED            date when the job was stopped
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
project               VARCHAR(255)            arbitrary name given by the user or an
                                              admission rule
suspended             ENUM("YES","NO")        specify if the job was suspended
                                              (oarhold_)
job_env               TEXT                    environment variables to set for the
                                              job
exit_code             INT DEFAULT 0           exit code for passive jobs
job_group             VARCHAR(255)            not used
===================== ======================  =======================================

:Primary key: job_id
:Index fields: state, reservation, queue_name, accounted, suspended

Explications about the "state" field:

 - "Waiting" : the job is waiting OAR scheduler decision.
 - "Hold" : user or administrator wants to hold the job (`oarhold`_ command).
   So it will not be scheduled by the system.
 - "toLaunch" : the OAR scheduler has attributed some nodes to the job. So it
   will be launched.
 - "toError" : something wrong occurred and the job is going into the error
   state.
 - "toAckReservation" : the OAR scheduler must say "YES" or "NO" to the waiting
   `oarsub`_ command because it requested a reservation.
 - "Launching" : OAR has launched the job and will execute the user command
   on the first node.
 - "Running" : the user command is executing on the first node.
 - "Suspended" : the job was in Running state and there was a request
   (`oarhold`_ with "-r" option) to suspend this job. In this state other jobs
   can be scheduled on the same resources (these resources has the
   "suspended_jobs" field to "YES").
 - "Finishing" : the user command has terminated and OAR is doing work internally
 - "Terminated" : the job has terminated normally.
 - "Error" : a problem has occurred.

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

=================  ====================  =======================================
Fields             Types                 Descriptions
=================  ====================  =======================================
moldable_id        INT UNSIGNED          moldable job identifier
moldable_job_id    INT UNSIGNED          corresponding job identifier
moldable_walltime  INT UNSIGNED          instance duration
=================  ====================  =======================================

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

=================  ====================  =======================================
Fields             Types                 Descriptions
=================  ====================  =======================================
job_state_log_id   INT UNSIGNED          identifier
job_id             INT UNSIGNED          corresponding job identifier
job_state          ENUM('Waiting',       job state during the interval
                   'Hold', 'toLaunch',
                   'toError',
                   'toAckReservation',
                   'Launching',
                   'Finishing',
                   'Running',
                   'Suspended',
                   'Resuming',
                   'Terminated',
                   'Error')
date_start         INT UNSIGNED          start date of the interval
date_stop          INT UNSIGNED          end date of the interval
=================  ====================  =======================================

:Primary key: job_state_log_id
:Index fields: job_id, job_state

This table keeps informations about state changes of jobs.

*job_types*
~~~~~~~~~~~

================  ====================  =======================================
Fields            Types                 Descriptions
================  ====================  =======================================
job_type_id       INT UNSIGNED          identifier
job_id            INT UNSIGNED          corresponding job identifier
type              VARCHAR(255)          job type like "deploy", "timesharing",
                                        ...
type_index        ENUM('CURRENT',       index field
                  'LOG')
================  ====================  =======================================

:Primary key: job_type_id
:Index fields: job_id, type

This table stores job types given with the `oarsub`_ command and "-t" options.

*resources*
~~~~~~~~~~~

====================  ====================  =======================================
Fields                Types                 Descriptions
====================  ====================  =======================================
resource_id           INT UNSIGNED          resource identifier
type                  VARCHAR(100)          resource type (used for licence
                      DEFAULT "default"     resources for example)
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
state_num             INT                   corresponding state number (useful
                                            with the SQL "ORDER" query)
suspended_jobs        ENUM('YES','NO')      specify if there is at least one
                                            suspended job on the resource
scheduler_priority    INT UNSIGNED          arbitrary number given by the system
                                            to select resources with more
                                            intelligence
switch                VARCHAR(50)           name of the switch
cpu                   INT UNSIGNED          global cluster cpu number
cpuset                INT UNSIGNED          field used with the
                                            JOB_RESOURCE_MANAGER_PROPERTY_DB_FIELD_
besteffort            ENUM('YES','NO')      accept or not besteffort jobs
deploy                ENUM('YES','NO')      specify if the resource is deployable
expiry_date           INT UNSIGNED          field used for the desktop computing
                                            feature
desktop_computing     ENUM('YES','NO')      tell if it is a desktop computing
                                            resource (with an agent)
last_job_date         INT UNSIGNED          store the date when the resource
                                            was used for the last time
cm_availability       INT UNSIGNED          used with compute mode features to
                                            know if an Absent resource can be
                                            switch on
====================  ====================  =======================================

:Primary key: resource_id
:Index fields: state, next_state, type, suspended_jobs

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

This table permits to specify different properties for each resources. These can
be used with the `oarsub`_ command ("-p" and "-l" options).

You can add your own properties with `oarproperty`_ command.

These properties can be updated with the `oarnodesetting`_ command ("-p" option).

Several properties are added by default:

 - switch : you have to register the name of the switch where the node is
   plugged.
 - cpu : this is a unique name given to each cpus. This enables OAR scheduler
   to distinguish all cpus.
 - cpuset : this is the name of the cpu on the node. The Linux kernel sets this
   to an integer beginning at 0. This field is linked to the configuration tag
   JOB_RESOURCE_MANAGER_PROPERTY_DB_FIELD_.

*resource_logs*
~~~~~~~~~~~~~~~~~~~~~~~~

=================  ====================  =======================================
Fields             Types                 Descriptions
=================  ====================  =======================================
resource_log_id    INT UNSIGNED          unique id
resource_id        INT UNSIGNED          resource identifier
attribute          VARCHAR(255)          name of corresponding field in
                                         resources
value              VARCHAR(255)          value of the field
date_start         INT UNSIGNED          interval start date
date_stop          INT UNSIGNED          interval stop date
finaud_decision    ENUM('YES','NO')      store if this is a system change or a
                                         human one
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
ssh_private_key   TEXT DEFAULT NULL     ssh private key given by the user
                                        (in grid usage it enables to connect
                                        onto all nodes of the job of all
                                        clusers with oarsh_)
ssh_public_key    TEXT DEFAULT NULL     ssh public key
================  ====================  =======================================

:Primary key: job_id
:Index fields: *None*

This table is used to share a secret between OAR server and oarexec process on
computing nodes (avoid a job id being stolen/forged by malicious user).

For security reasons, this table **must not be readable** for a database
account given to users who want to access OAR internal informations(like statistics).

Configuration file
==================

Be careful, the syntax of this file must be bash compliant(so after editing
you must be able to launch in bash 'source /etc/oar.conf' and have variables
assigned).
Each configuration tag found in /etc/oar.conf is now described:

  - Database type : you can use a MySQL or a PostgreSQL database (tags are
    "mysql" or "Pg")::
      
      DB_TYPE=mysql
  
  - Database hostname::
  
      DB_HOSTNAME=localhost

  - Database base name::
  
      DB_BASE_NAME=oar

  - DataBase user name::
      
      DB_BASE_LOGIN=oar

  - DataBase user password::
      
      DB_BASE_PASSWD=oar

.. _DB_BASE_LOGIN_RO:

  - DataBase read only user name::
      
      DB_BASE_LOGIN_RO=oar_ro

.. _DB_BASE_PASSWD_RO:

  - DataBase read only user password::
      
      DB_BASE_PASSWD_RO=oar_ro


  - OAR server hostname::
      
      SERVER_HOSTNAME=localhost

.. _SERVER_PORT:

  - OAR server port::
      
      SERVER_PORT=6666

  - When the user does not specify a -l option then oar use this::
  
      OARSUB_DEFAULT_RESOURCES="/resource_id=1"
  
  - Force use of job key even if --use-job-key or -k is not set in oarsub::

      OARSUB_FORCE_JOB_KEY="no"

.. _DEPLOY_HOSTNAME:

  - Specify where we are connected in the deploy queue(the node to connect
    to when the job is in the deploy queue)::
      
      DEPLOY_HOSTNAME="127.0.0.1"

.. _COSYSTEM_HOSTNAME:

  - Specify where we are connected with a job of the cosystem type::

      COSYSTEM_HOSTNAME="127.0.0.1"

.. _DETACH_JOB_FROM_SERVER:

  - Set DETACH_JOB_FROM_SERVER to 1 if you do not want to keep a ssh
    connection between the node and the server. Otherwise set this tag to 0::
      
      DETACH_JOB_FROM_SERVER=1

  - Set the directory where OAR will store its temporary files on each nodes
    of the cluster. This value MUST be the same in all oar.conf on
    all nodes::

      OAR_RUNTIME_DIRECTORY="/tmp/oar_runtime"

  - Specify the database field to use to fill the file on the first node of
    the job in $OAR_NODE_FILE (default is 'network_address'). Only resources
    with type=default are displayed in this file::

      NODE_FILE_DB_FIELD="network_address"

  - Specify the database field that will be considered to fill the node file
    used by the user on the first node of the job. for each different value
    of this field then OAR will put 1 line in the node file(by default "cpu")::

      NODE_FILE_DB_FIELD_DISTINCT_VALUES="core"

  - By default OAR uses the ping command to detect if nodes are down or not.
    To enhance this diagnostic you can specify one of these other methods (
    give the complete command path):

      * OAR taktuk::
      
          PINGCHECKER_TAKTUK_ARG_COMMAND="-t 3 broadcast exec [ true ]"

        If you use sentinelle.pl then you must use this tag::

          PINGCHECKER_SENTINELLE_SCRIPT_COMMAND="/var/lib/oar/sentinelle.pl -t 5 -w 20"

      * OAR fping::
      
          PINGCHECKER_FPING_COMMAND="/usr/bin/fping -q"

      * OAR nmap : it will test to connect on the ssh port (22)::
      
          PINGCHECKER_NMAP_COMMAND="/usr/bin/nmap -p 22 -n -T5"

      * OAR generic : a specific script may be used instead of ping to check
        aliveness of nodes. The script must return bad nodes on STDERR (1 line
        for a bad node and it must have exactly the same name that OAR has
        given in argument of the command)::

          PINGCHECKER_GENERIC_COMMAND="/path/to/command arg1 arg2"

  - OAR log level: 3(debug+warnings+errors), 2(warnings+errors), 1(errors)::
      
      LOG_LEVEL=2

  - OAR log file::
      
      LOG_FILE="/var/log/oar.log"

  - If you want to debug oarexec on nodes then affect 1 (only effective if
    DETACH_JOB_FROM_SERVER = 1)::

      OAREXEC_DEBUG_MODE=0

  - OAR Allowed networks, Networks or hosts allowed to submit jobs to OAR and
    compute nodes may be specified here(0.0.0.0/0 means all IPs are allowed
    and 127.0.0.1/32 means only IP 127.0.0.1 is allowed)::
      
      ALLOWED_NETWORKS="127.0.0.1/32 0.0.0.0/0"

.. _ACCOUNTING_WINDOW:

  - Set the granularity of the OAR accounting feature (in seconds). Default is
    1 day (86400s)::
      
      ACCOUNTING_WINDOW="86400"

.. _MAIL:

  - OAR informations may be notified by email to the administror.
    Set accordingly to your configuration the next lines to activate
    this feature::
      
      MAIL_SMTP_SERVER="smtp.serveur.com"
      MAIL_RECIPIENT="user@domain.com"
      MAIL_SENDER="oar@domain.com"

  - Set the timeout for the prologue and epilogue execution on computing
    nodes::

      PROLOGUE_EPILOGUE_TIMEOUT=60

  - Files to execute before and after each job on the first computing node
    (by default nothing is executed)::

      PROLOGUE_EXEC_FILE="/path/to/prog"
      EPILOGUE_EXEC_FILE="/path/to/prog"

  - Set the timeout for the prologue and epilogue execution on the OAR server::

      SERVER_PROLOGUE_EPILOGUE_TIMEOUT=60

.. _SERVER_SCRIPT_EXEC_FILE:

  - Files to execute before and after each job on the OAR server
    (by default nothing is executed)::
      
      SERVER_PROLOGUE_EXEC_FILE="/path/to/prog"
      SERVER_EPILOGUE_EXEC_FILE="/path/to/prog"

  - Set the frequency for checking Alive and Suspected resources::
      
      FINAUD_FREQUENCY=300

.. _DEAD_SWITCH_TIME:

  - Set time after which resources become Dead (default is 0 and it means
    never)::

      DEAD_SWITCH_TIME=600

.. _SCHEDULER_TIMEOUT:

  - Maximum of seconds used by a scheduler::

      SCHEDULER_TIMEOUT=10

  - Time to wait when a reservation has not got all resources that it has
    reserved (some resources could have become Suspected or Absent since the
    job submission) before to launch the job in the remaining resources::

      RESERVATION_WAITING_RESOURCES_TIMEOUT=300
  
.. _SCHEDULER_JOB_SECURITY_TIME:

  - Time to add between each jobs (time for administration tasks or time to
    let computers to reboot)::

      SCHEDULER_JOB_SECURITY_TIME=1

.. _SCHEDULER_GANTT_HOLE_MINIMUM_TIME:

  - Minimum time in seconds that can be considered like a hole where a job
    could be scheduled in::
  
      SCHEDULER_GANTT_HOLE_MINIMUM_TIME=300

.. _SCHEDULER_RESOURCE_ORDER:

  - You can add an order preference on resource assigned by the system(SQL
    ORDER syntax)::

      SCHEDULER_RESOURCE_ORDER="switch ASC, network_address DESC, resource_id ASC"

.. _SCHEDULER_RESOURCES_ALWAYS_ASSIGNED_TYPE:

  - You can specify resources from a resource type that will be always assigned for
    each job (for example: enable all jobs to be able to log on the cluster
    frontales).
    For more information, see the FAQ_::

      SCHEDULER_RESOURCES_ALWAYS_ASSIGNED_TYPE="42 54 12 34"

  - This says to the scheduler to treate resources of these types, where there is
    a suspended job, like free ones. So some other jobs can be scheduled on these
    resources. (list resource types separate with spaces; Default value is
    nothing so no other job can be scheduled on suspended job resources)::
    
      SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE="default licence vlan"

  - Name of the perl script that manages suspend/resume. You have to install your
    script in $OARDIR and give only the name of the file without the entire path.
    (default is suspend_resume_manager.pl)::

      SUSPEND_RESUME_FILE="suspend_resume_manager.pl"

.. _JUST_AFTER_SUSPEND_EXEC_FILE:
.. _JUST_BEFORE_RESUME_EXEC_FILE:

  - Files to execute just after a job was suspended and just before a job was
    resumed::
    
      JUST_AFTER_SUSPEND_EXEC_FILE="/path/to/prog"
      JUST_BEFORE_RESUME_EXEC_FILE="/path/to/prog"

  - Timeout for the two previous scripts::
 
      SUSPEND_RESUME_SCRIPT_TIMEOUT=60

.. _JOB_RESOURCE_MANAGER_PROPERTY_DB_FIELD:

  - Indicate the name of the database field that contains the cpu number of
    the node. If this option is set then users must use `OARSH`_ instead of
    ssh to walk on each nodes that they have reserved via oarsub.
    ::

      JOB_RESOURCE_MANAGER_PROPERTY_DB_FIELD=cpuset

.. _JOB_RESOURCE_MANAGER_FILE:

  - Name of the perl script that manages cpuset. You have to install your
    script in $OARDIR and give only the name of the file without the
    entire path.
    (default is cpuset_manager.pl which handles the linux kernel cpuset)
    ::
    
      JOB_RESOURCE_MANAGER_FILE="cpuset_manager.pl"

.. _TAKTUK_CMD:

  - If you have installed taktuk and want to use it to manage cpusets
    then give the full command path (with your options except "-m" and "-o"
    and "-c").
    You don t also have to give any taktuk command.
    ::

      TAKTUK_CMD="/usr/bin/taktuk -s"

  - If you want to manage nodes to be started and stoped. OAR gives you this
    API:

.. _SCHEDULER_NODE_MANAGER_WAKE_UP_CMD:

    * When OAR scheduler wants some nodes to wake up then it launches this
      command and puts on its STDIN the list of nodes to wake up (one hostname
      by line).The scheduler looks at *cm_availability* field in the resources_
      table to know if the node will be started for enough time::

        SCHEDULER_NODE_MANAGER_WAKE_UP_CMD="/path/to/the/command with your args"

.. _SCHEDULER_NODE_MANAGER_SLEEP_CMD:

    * When OAR considers that some nodes can be shut down, it launches this
      command and puts the node list on its STDIN(one hostname by line)::

        SCHEDULER_NODE_MANAGER_SLEEP_CMD="/path/to/the/command args"

.. _SCHEDULER_NODE_MANAGER_IDLE_TIME:

      + Parameters for the scheduler to decide when a node is idle(number of
        seconds since the last job was terminated on the nodes)::
        
          SCHEDULER_NODE_MANAGER_IDLE_TIME=600

.. _SCHEDULER_NODE_MANAGER_SLEEP_TIME:

      + Parameters for the scheduler to decide if a node will have enough time
        to sleep(number of seconds before the next job)::

          SCHEDULER_NODE_MANAGER_SLEEP_TIME=600

.. _OPENSSH_CMD:

  - Command to use to connect to other nodes (default is "ssh" in the PATH)
    ::

      OPENSSH_CMD="/usr/bin/ssh"

  - These are configuration tags for OAR in the desktop-computing mode *(for now
    this functionality is not working. So don't try to use it)*::
  
      DESKTOP_COMPUTING_ALLOW_CREATE_NODE=0
      DESKTOP_COMPUTING_EXPIRY=10
      STAGEOUT_DIR="/var/lib/oar/stageouts/"
      STAGEIN_DIR="/var/lib/oar/stageins"
      STAGEIN_CACHE_EXPIRY=144
  
  - This variable must be set to enable the use of oarsh from a frontale node.
    Otherwise you must not set this variable if you are not on a frontale::

      OARSH_OARSTAT_CMD="/usr/bin/oarstat"

.. _OARSH_OPENSSH_DEFAULT_OPTIONS:

  - The following variable adds options to ssh. If one option is not handled
    by your ssh version just remove it BUT be careful because these options are
    there for security reasons::

      OARSH_OPENSSH_DEFAULT_OPTIONS="-oProxyCommand=none -oPermitLocalCommand=no"

.. _OARMONITOR_SENSOR_FILE:

  - Name of the perl script the retrive monitoring data from compute nodes.
    This is used in oarmonitor command.

      OARMONITOR_SENSOR_FILE="/etc/oar/oarmonitor_sensor.pl"

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

oar_sched_gantt_with_timesharing
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This is the default OAR scheduler. It implements all functionalities like
timesharing_, moldable jobs, `besteffort jobs`_, ...

By default, this scheduler is used by all default queues.

We have implemented the FIFO with backfilling algorithm. Some parameters
can be changed in the `configuration file`_ (see SCHEDULER_TIMEOUT_,
SCHEDULER_JOB_SECURITY_TIME_, SCHEDULER_GANTT_HOLE_MINIMUM_TIME_,
SCHEDULER_RESOURCE_ORDER_).

oar_sched_gantt_with_timesharing_and_fairsharing
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
the command oaraccounting_ have to be run periodically (in a cron job for
example). Otherwise the scheduler cannot be aware of new user consumptions.

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

The cpuset name is effectively created on each nodes and is composed as
"user_jobid".

OAR system steps:

 1. Before each job, the Runner_ initialize the CPUSET (see `CPUSET
    definition`_) with OPENSSH_CMD_ and an efficient launching tool :
    `Taktuk <http://taktuk.gforge.inria.fr/>`_. If it is not
    installed and configured (TAKTUK_CMD_) then OAR uses an internal
    launching tool less optimized.
    The processors assigned to this cpuset are taken from the defined database
    field by JOB_RESOURCE_MANAGER_PROPERTY_DB_FIELD_ in the table resources_.

 2. After each job, OAR deletes all processes stored in the associated CPUSET.
    Thus all nodes are clean after a OAR job.

If you don't want to use this feature, you can, but nothing will warranty that
every user processes will be killed after the end of a job.

If you want you can implement your own cpuset management. This is done by
editing 3 files (see also `CPUSET installation`_):

 - cpuset_manager.pl : this script creates the cpuset on each nodes
   and also delete it at the end of the job. For more informations, you have to
   look at this script (there are several comments).

 - oarsh : (OARSH_) this script is used to replace the standard "ssh"
   command. It gets the cpuset name where it is running and transfer this
   information via "ssh" and the "SendEnv" option. In this file, you have
   to change the "get_current_cpuset" function.

 - oarsh_shell : (OARSH_SHELL_) this script is the shell of the oar user on
   each nodes. It gets environment variables and look at if there is a cpuset
   name. So if there is one it assigns the current process and its father to
   this cpusetname. So all further user processes will remind in the cpuset.
   In this file you just have to change the "add_process_to_cpuset" function.

SSH connection key definition
-----------------------------

This function is performed by oarsub_ with the --ssh_private_key and
--ssh_public_key options.

It enables the user to define a ssh key pair to connect on their nodes.
So oarsh_ can be used on nodes of different clusters to connect
each others if the same ssh keys are used with each oarsub_.

So a grid reservation ("-r" option of oarsub_ on each OAR batch scheduler of
each wanted clusters) can be done with this functionality. 

Example::

    ssh-keygen -f oar_key
    oarsub --ssh_private_key "$(cat oar_key)" --ssh_public_key "$(cat oar_key.pub)" ./script.sh
    

Suspend/resume
--------------

Jobs can be suspended with the command oarhold_ (send a "SIGSTOP" on every
processes on every nodes) to allow other jobs to be executed.

"Suspended" jobs can be resumed with the command oarresume_ (send a "SIGSTOP"
on every suspended processes on every nodes). They will
pass into "Running" when assigned resources will be free.

IMPORTANT: This feature is available only if CPUSET_ is configured.

You can specify 2 scripts if you have to perform any actions just after
(JUST_AFTER_SUSPEND_EXEC_FILE_) suspend and just before resume
(JUST_BEFORE_RESUME_EXEC_FILE_).

Moreover you can perform other actions (than send signals to processes)
if you want: just edit the "suspend_resume_manager.pl" file.

Job deletion
------------

Leon_ tries to connect to OAR Perl script running on the first job node (find
it thanks to the file */tmp/oar/pid_of_oarexec_for_jobId_id*) and sends a
"SIGTERM" signal. Then the script catch it and normally end the job (kill
processes that it has launched).

If this method didn't succeed then Leon_ will flush the OAR database for the
job and nodes will be "Suspected" by NodeChangeState_.

If your job is check pointed and is of the type *idempotent* (oarsub_ "-t"
option) and its exit code is equal to 0 then another job is automatically
created and scheduled with same behaviours. 

Checkpoint
----------

The checkpoint is just a signal sent to the program specified with the oarsub_
command.

If the user uses "--checkpoint" option then Sarko_ will ask the OAR Perl script running
on the first node to send the signal to the process (SIGUSR2 or the one
specified with "--signal").

You can also use oardel_ command to send the signal.

Scheduling
----------

General steps used to schedule a job:
  
  1. All previous scheduled jobs are stored in a Gantt data structure.
  
  2. All resources that match property constraints of the job("-p" option and
     indication in the "{...}" from the "-l" option of the oarsub_) are stored in
     a tree data structure according to the hierarchy given with the "-l" option.
  
  3. Then this tree is given to the Gantt library to find the first hole where
     the job can be launched.
  
  4. The scheduler stores its decision into the database in the
     gantt_jobs_predictions_ and gantt_jobs_resources_ tables.

See User_ section from the FAQ_ for more examples and features.

Job dependencies
----------------

A job dependency is a situation where a job needs the ending of another job
to start. OAR deals with job dependency problems by refusing to schedule 
dependant jobs if their required job is in Terminated state and have an exit 
code != 0 (an error occured). If the required job is resubmited, its jobId is
no longer the same and OAR updates the database and sets the job_id_required 
field to this new jobId for the dependant job.

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
can see that like a "data warehousing" information extraction method.

Dynamic nodes coupling features
-------------------------------

We are working with the `Icatis <http://www.icatis.com/>`_ company on clusters
composed by Intranet computers. These nodes can be switch in computing mode
only at specific times. So we have implemented a functionality that can
request to power on some hardware if they can be in the cluster.

We are using the field *cm_availability* from the table resources_
to know when a node will be inaccessible in the cluster mode (easily settable
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

  3. *timesharing=\*,job_name* : This indicates that the job can be shared
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

Important : a besteffort job cannot be a reservation.

If your job is of the type *besteffort* and *idempotent* (oarsub_ "-t"
option) and killed by the OAR scheduler then another job is automatically
created and scheduled with same behaviours.

Cosystem jobs
-------------

This feature enables to reserve some resources without launching any
program on corresponding nodes. Thus nothing is done by OAR on computing nodes
when a job is starting except on the COSYSTEM_HOSTNAME_ defined in the
configuration file.

This is useful with an other launching system that will declare its time
slot in OAR. So yo can have two different batch scheduler.

When you submit a job you have to use "-t cosystem" option of oarsub_ to
specify that this is a cosystem job.

These jobs are stopped by the oardel_ command or when they reach their
walltime or their command has finished.
They also use the node COSYSTEM_HOSTNAME_ to launch the specified program
or shell.

Deploy jobs
-----------

This feature is useful when you want to enable the users to reinstall their
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

Desktop computing
-----------------

*(for now this functionality is not working. So don't try to use it)*

If you cannot contact the computers via SSH you can install the "desktop
computing" OAR mode.
This kind of installation is based on two programs:
 
 - oar-cgi : this is a web CGI used by the nodes to communicate with
   the OAR server.
 - oar-agent.pl : This program asks periodically the server web CGI to know what it
   has to do.

This method replaces the SSH command. Computers which want to register them into
OAR just has to be able to contact OAR HTTP server.

In this situation we don't have a NFS file system to share the same repertories
over all nodes so we have to use a stagein/stageout solution. In this case you
can use the oarsub_ option "stagein" to migrate your data.

.. include:: ../../FAQ

.. include:: ../../CHANGELOG

$Id$
