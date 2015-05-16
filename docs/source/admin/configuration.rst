Configuration file
==================

Be careful, the syntax of this file must be bash compliant(so after editing
you must be able to launch in bash 'source /etc/oar.conf' and have variables
assigned).
Each configuration tag found in /etc/oar.conf is now described:

  - Database hostname (where the PostgreSQL server is running)::

      DB_HOSTNAME=127.0.0.1

  - Database port::

      DB_PORT=5432

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

          PINGCHECKER_TAKTUK_ARG_COMMAND="-t 30 broadcast exec [ true ]"

        If you use sentinelle.pl then you must use this tag::

          PINGCHECKER_SENTINELLE_SCRIPT_COMMAND="/var/lib/oar/sentinelle.pl -t 30 -w 20"

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

      SCHEDULER_TIMEOUT=20

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
    For more information, see the FAQ::

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
    the node. If this option is set then users must use oarsh instead of
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

.. _JOB_RESOURCE_MANAGER_JOB_UID_TYPE:

  - Resource "type" DB field to use if you want to enable the job uid feature.
    (create a unique user id per job on each nodes of the job)
    ::

      JOB_RESOURCE_MANAGER_JOB_UID_TYPE="userid"

.. _TAKTUK_CMD:

  - If you have installed taktuk and want to use it to manage cpusets
    then give the full command path (with your options except "-m" and "-o"
    and "-c").
    You don't also have to give any taktuk command.(taktuk version must be >=
    3.6)
    ::

      TAKTUK_CMD="/usr/bin/taktuk -s"

  - If you want to manage nodes to be started and stoped. OAR gives you this
    API:

.. _SCHEDULER_NODE_MANAGER_WAKE_UP_CMD:

    * When OAR scheduler wants some nodes to wake up then it launches this
      command and puts on its STDIN the list of nodes to wake up (one hostname
      by line).The scheduler looks at *available_upto* field in the
      :ref:`database-resources-anchor`
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

  - These are configuration tags for OAR in the desktop-computing mode::

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
