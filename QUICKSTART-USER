Using OAR - Basic steps
=======================

Visualising the cluster State
-----------------------------

Many tools are available to visualize the cluster state.

~~~~~~~~~~~~~~~
Shell commands:
~~~~~~~~~~~~~~~

* oarstat: this command shows information about running or planned jobs.
  (The -f option shows full infomation)

* oarnodes: this command shows the resources states. Warning: in our context, a
  resource is not necessary a machine. It is generally a cpu, a core or a host,
  but it can be much more... like licence tokens, vlan, ...
  The oarnodes command gives information about the network address where is
  located this resource, its type, its state and many other (interesting)
  information.

~~~~~~~~~~~~~~~~
Graphical tools:
~~~~~~~~~~~~~~~~

* Monika: this web page shows current resources states and jobs information.
  On this page you can have more information about a particular resource or job.

* DrawGantt: this web page shows the gantt diagram of the scheduling. It
  represents the current, former and future jobs.

Submitting a job in an interactive shell
----------------------------------------

~~~~~~~~~~
Submission
~~~~~~~~~~

To submit an interactive job we use the "oarsub" command with the "-I" option::

  frontend:~$> oarsub -I

OAR returns then an unique job ID that will identify your job in the system::

  OAR_JOB_ID=1234

Once the job is scheduled, when the requested resources are available, OAR
connects you to the first allocated node. OAR initiates environment variables
that inform you of your submission properties::

  node:~$> env | grep OAR

Particularly, the allocated nodes list is contained in the $OAR_NODEFILE::

  node:~$> cat $OAR_NODEFILE

~~~~~~~~~~~~~
Visualisation
~~~~~~~~~~~~~

You can get information about your job by looking at the Monika or DrawGantt
interfaces or by typing in a command line console::

  frontend:~$> oarstat -fj OAR_JOB_ID

~~~~~~~~~~~~~~~
Exiting the job
~~~~~~~~~~~~~~~

To terminate an interactive job you just have to disconnect from the resource::

  node:~$> exit

You can likewise kill the job by typing::

  frontend:~$> oardel OAR_JOB_ID

In this case, the session will be killed ("kill -9").

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Interactive submission on many resources
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The "-l" option allows to specify wanted resources. For example, if we need to
work in interactive mode on 2 cpu for a max duration of 30 minutes we will ask::

  frontend:~$> oarsub -I -l /cpu=2,walltime=00:30:00

The walltime is the job's max duration. If the job overruns its walltime, it will
be killed by the system. Thus, you better have to set your walltime correctly
depending on how long will take your job to prevent being killed if the
walltime has been set too short or being scheduled later if it is too long.
Then, once the job is scheduled and started, OAR connects you on the first
reserved node. You still can access the list of the other resources via the
$OAR_NODEFILE env variable.


Batch submission
----------------

OAR allows to execute scripts in "passive mode". In this mode, the user
specifies a script at the submission time. This script will be executed on the
first reserved node. It's within this script that the user will define the way
to operate parallel resources. All the ``$OAR_*`` env variables are reachable
within the script.

The script must be executable.

~~~~~~~~~~
Submission
~~~~~~~~~~

In this case, the principle is the same that interactive submission, just
replace the "-I" option with the path of your script::

  frontend:~$> oarsub -l /cpu=2,walltime=00:30:00 ./hello_mpi.sh

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Getting the results of the submission
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In passive mode, OAR creates 2 files: OAR.<OAR_JOB_ID>.stdout for the stdout and
OAR.<OAR_JOB_ID>.stderr for the stderr.
The name of these 2 files can be changed (see "man oarsub").

~~~~~~~~~~~~~~~~~~~~~~~~
Connecting a running job
~~~~~~~~~~~~~~~~~~~~~~~~

You can connect a running job with the "-C" option to oarsub::

  frontend:~$> oarsub -C <OAR_JOB_ID>

Thus, you will be connected to the first reserved node.

Reservations
------------

Until now we only asked for immediate start for our submission.
However it is also possible to plan a job in the future. This feature is
available through the "-r <date>" option::

  frontend:~$> oarsub -r '2008-03-07 16:45:00' -l nodes=2,walltime=0:10:00 ./hello_mpi.sh


