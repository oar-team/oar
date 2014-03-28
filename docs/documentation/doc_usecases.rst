OAR Use Cases
=============

Interactive jobs
----------------

Job submission
~~~~~~~~~~~~~~

::

	jdoe@idpot:~$ oarsub -I -l /nodes=3/core=1
	[ADMISSION RULE] Set default walltime to 7200.
	[ADMISSION RULE] Modify resource description with type constraints
	OAR_JOB_ID=4924 
	Interactive mode : waiting...
	[2007-03-07 08:51:04] Starting...

	Connect to OAR job 4924 via the node idpot5.grenoble.grid5000.fr
	jdoe@idpot5:~$

Connecting to the other cores
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

::

	jdoe@idpot5:~$ cat $OAR_NODEFILE
	idpot5.grenoble.grid5000.fr
	idpot8.grenoble.grid5000.fr
	idpot9.grenoble.grid5000.fr
	jdoe@idpot5:~$ oarsh idpot8
	Last login: Tue Mar  6 18:00:37 2007 from idpot.imag.fr
	jdoe@idpot8:~$ oarsh idpot9
	Last login: Wed Mar  7 08:48:30 2007 from idpot.imag.fr
	jdoe@idpot9:~$ oarsh idpot5
	Last login: Wed Mar  7 08:51:45 2007 from idpot5.imag.fr
	jdoe@idpot5:~$

Copying a file from one node to another
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

::

	jdoe@idpot5:~$ hostname > /tmp/my_hostname
	jdoe@idpot5:~$ oarcp /tmp/my_hostname idpot8:/tmp/my_hostname  
	jdoe@idpot5:~$ oarsh idpot8 cat /tmp/my_hostname
	idpot5
	jdoe@idpot5:~$

Connecting to our job
~~~~~~~~~~~~~~~~~~~~~

::

	jdoe@idpot:~$ OAR_JOB_ID=4924 oarsh idpot9
	Last login: Wed Mar  7 08:52:09 2007 from idpot8.imag.fr
	jdoe@idpot9:~$ oarsh idpot5
	Last login: Wed Mar  7 08:52:18 2007 from idpot9.imag.fr
	jdoe@idpot5:~$


Batch mode job
--------------

Submission using a script
~~~~~~~~~~~~~~~~~~~~~~~~~

::

	jdoe@paramount:~$ oarsub -l core=10 ./runhpl
	Generate a job key...
	[ADMISSION RULE] Set default walltime to 3600.
	[ADMISSION RULE] Modify resource description with type constraints
	OAR_JOB_ID=199522

Watching results
~~~~~~~~~~~~~~~~

::

	jdoe@paramount:~$ cat OAR.199522.stdout
	...

Submission using an inline command
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Sometimes it is very useful to run a little command in oarsub:
::

	jdoe@paramount:~$ oarsub -l core=1 'echo $PATH;which ssh'
	Generate a job key...
	[ADMISSION RULE] Set default walltime to 3600.
	[ADMISSION RULE] Modify resource description with type constraints
	OAR_JOB_ID=199523

Watching results
~~~~~~~~~~~~~~~~

::

	jdoe@paramount:~$ cat OAR.199523.stdout
	...


Reservations
------------

The date format to pass to the -r option is YYYY-MM-DD HH:MM:SS:
::

	jdoe@paramount:~$ oarsub -l core=10 ./runhpl -r "2007-10-10 18:00:00"
	Generate a job key...
	[ADMISSION RULE] Set default walltime to 3600.
	[ADMISSION RULE] Modify resource description with type constraints
	OAR_JOB_ID=199524
	Reservation mode : waiting validation...
	Reservation valid --> OK
	jdoe@paramount:~$


Examples of resource requests
-----------------------------

Using the resource hierarchy
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ask for 1 core on 15 nodes on a same cluster (total = 15 cores) 
	
::

	oarsub -I -l /cluster=1/nodes=15/core=1
	
- ask for 1 core on 15 nodes on 2 clusters (total = 30 cores) 

::

	oarsub -I -l /cluster=2/nodes=15/core=1

- ask for 1 core on 2 cpus on 15 nodes on a same cluster (total = 30 cores) 

::

	oarsub -I -l /cluster=1/nodes=15/cpu=2/core=1

- ask for 10 cpus on 2 clusters (total = 20 cpus, information regarding the
  node ou core count depend on the topology of the machines) 

::

	oarsub -I -l /cluster=2/cpu=10

- ask for 1 core on 3 different network switches (total = 3 cores) 

::

	oarsub -I -l /switch=3/core=1


Using properties
~~~~~~~~~~~~~~~~

See OAR properties for a description of all available properties, and watch
Monika.

-  ask for 10 cores of the cluster azur 

::

	oarsub -I -l core=10 -p "cluster='azur'"

- ask for 2 nodes with 4096 GB of memory and Infiniband 10G 

::

	oarsub -I -p "memnode=4096 and ib10g='YES'" -l nodes=2

- ask for any 4 nodes except gdx-45 

::

	oarsub -I -p "not host like 'gdx-45.%'" -l nodes=4


Mixing every together
~~~~~~~~~~~~~~~~~~~~~

- ask for 1 core on 2 nodes on the same cluster with 4096 GB of memory and
  Infiniband 10G + 1 cpu on 2 nodes on the same switch with bicore processors
  for a walltime of 4 hours 

::

	oarsub -I -l "{memnode=4096 and ib10g='YES'}/cluster=1/nodes=2/core=1+{cpucore=2}/switch=1/nodes=2/cpu=1,walltime=4:0:0"

Warning
_______

1. walltime must always be the last argument of -l <...>
2. if no resource matches your request, oarsub will exit with the message 

::

	Generate a job key...
	[ADMISSION RULE] Set default walltime to 3600.
	[ADMISSION RULE] Modify resource description with type constraints
	There are not enough resources for your request
	OAR_JOB_ID=-5
	Oarsub failed: please verify your request syntax or ask for support to your admin.
	
	
Moldable jobs
~~~~~~~~~~~~~

- ask for 4 nodes and a walltime of 2 hours or 2 nodes and a walltime of 4 hours 

::

	oarsub -I -l nodes=4,walltime=2 -l nodes=2,walltime=4


Types of job
~~~~~~~~~~~~

OAR2 feature the concept of job "type". Among them, the type deploy (that used
to be a queue with OAR 1.6) and the type besteffort.

- ask for 4 nodes on the same cluster in order to deploy a customized
  environment: 

::

	oarsub -I -l cluster=1/nodes=4,walltime=6 -t deploy

- submit besteffort jobs 

::

	for param in $(< ./paramlist); do
	    oarsub -t besteffort -l core=1 "./my_script.sh $param"
	done


X11 forwarding
--------------

Some users complained about the lack of X11 forwarding in oarsub or oarsh. It
is now enabled.
We are using xeyes to test X: 2 big eyes should appear on your screen, and
follow the moves of your mouse. 

Shell 1
~~~~~~~

Check DISPLAY
_____________

::

	jdoe@idpot:~$ echo $DISPLAY
	localhost:11.0

Job submission
______________

::

	jdoe@idpot:~$ oarsub -I -l /nodes=2/core=1
	[ADMISSION RULE] Set default walltime to 7200.
	[ADMISSION RULE] Modify resource description with type constraints
	OAR_JOB_ID=4926 
	Interactive mode : waiting...
	[2007-03-07 09:01:16] Starting...

	Initialize X11 forwarding...
	Connect to OAR job 4926 via the node idpot8.grenoble.grid5000.fr
	jdoe@idpot8:~$ xeyes &
	[1] 14656
	jdoe@idpot8:~$ cat $OAR_NODEFILE
	idpot8.grenoble.grid5000.fr
	idpot9.grenoble.grid5000.fr
	[1]+  Done                    xeyes
	jdoe@idpot8:~$ oarsh idpot9 xeyes
	Error: Can't open display: 
	jdoe@idpot8:~$ oarsh -X idpot9 xeyes

Shell 2
~~~~~~~

::

	jdoe@idpot:~$ echo $DISPLAY
	localhost:13.0
	jdoe@idpot:~$ OAR_JOB_ID=4928 oarsh -X idpot9 xeyes


Using a parallel launcher: taktuk
---------------------------------

Warning: Taktuk MUST BE installed on all nodes to test this point

Shell 1
~~~~~~~

Unset DISPLAY so that X does not bother...
__________________________________________

::

	jdoe@idpot:~$ unset DISPLAY

Job submission
______________

::

	jdoe@idpot:~$ oarsub -I -l /nodes=20/core=1
	[ADMISSION RULE] Set default walltime to 7200.
	[ADMISSION RULE] Modify resource description with type constraints
	OAR_JOB_ID=4930 
	Interactive mode : waiting...
	[2007-03-07 09:15:13] Starting...

	Connect to OAR job 4930 via the node idpot1.grenoble.grid5000.fr

Running the taktuk command
__________________________

::

	jdoe@idpot1:~$ taktuk -c "oarsh" -f $OAR_FILE_NODES broadcast exec [ date ]
	idcalc12.grenoble.grid5000.fr-1: date (11567): output > Thu May  3 18:56:58 CEST 2007
	idcalc12.grenoble.grid5000.fr-1: date (11567): status > Exited with status 0
	idcalc4.grenoble.grid5000.fr-8: date (31172): output > Thu May  3 19:00:09 CEST 2007
	idcalc2.grenoble.grid5000.fr-2: date (32368): output > Thu May  3 19:01:56 CEST 2007
	idcalc3.grenoble.grid5000.fr-5: date (31607): output > Thu May  3 18:56:44 CEST 2007
	idcalc3.grenoble.grid5000.fr-5: date (31607): status > Exited with status 0
	idcalc7.grenoble.grid5000.fr-13: date (31188): output > Thu May  3 18:59:54 CEST 2007
	idcalc9.grenoble.grid5000.fr-15: date (32426): output > Thu May  3 18:56:45 CEST 2007
	idpot6.grenoble.grid5000.fr-20: date (16769): output > Thu May  3 18:59:54 CEST 2007
	idcalc4.grenoble.grid5000.fr-8: date (31172): status > Exited with status 0
	idcalc5.grenoble.grid5000.fr-9: date (10288): output > Thu May  3 18:56:39 CEST 2007
	idcalc5.grenoble.grid5000.fr-9: date (10288): status > Exited with status 0
	idcalc6.grenoble.grid5000.fr-11: date (11290): output > Thu May  3 18:57:52 CEST 2007
	idcalc6.grenoble.grid5000.fr-11: date (11290): status > Exited with status 0
	idcalc7.grenoble.grid5000.fr-13: date (31188): status > Exited with status 0
	idcalc8.grenoble.grid5000.fr-14: date (10450): output > Thu May  3 18:57:34 CEST 2007
	idcalc8.grenoble.grid5000.fr-14: date (10450): status > Exited with status 0
	idcalc9.grenoble.grid5000.fr-15: date (32426): status > Exited with status 0
	idpot1.grenoble.grid5000.fr-16: date (18316): output > Thu May  3 18:57:19 CEST 2007
	idpot1.grenoble.grid5000.fr-16: date (18316): status > Exited with status 0
	idpot10.grenoble.grid5000.fr-17: date (31547): output > Thu May  3 18:56:27 CEST 2007
	idpot10.grenoble.grid5000.fr-17: date (31547): status > Exited with status 0
	idpot2.grenoble.grid5000.fr-18: date (407): output > Thu May  3 18:56:21 CEST 2007
	idpot2.grenoble.grid5000.fr-18: date (407): status > Exited with status 0
	idpot4.grenoble.grid5000.fr-19: date (2229): output > Thu May  3 18:55:37 CEST 2007
	idpot4.grenoble.grid5000.fr-19: date (2229): status > Exited with status 0
	idpot6.grenoble.grid5000.fr-20: date (16769): status > Exited with status 0
	idcalc2.grenoble.grid5000.fr-2: date (32368): status > Exited with status 0
	idpot11.grenoble.grid5000.fr-6: date (12319): output > Thu May  3 18:59:54 CEST 2007
	idpot7.grenoble.grid5000.fr-10: date (7355): output > Thu May  3 18:57:39 CEST 2007
	idpot5.grenoble.grid5000.fr-12: date (13093): output > Thu May  3 18:57:23 CEST 2007
	idpot3.grenoble.grid5000.fr-3: date (509): output > Thu May  3 18:59:55 CEST 2007
	idpot3.grenoble.grid5000.fr-3: date (509): status > Exited with status 0
	idpot8.grenoble.grid5000.fr-4: date (13252): output > Thu May  3 18:56:32 CEST 2007
	idpot8.grenoble.grid5000.fr-4: date (13252): status > Exited with status 0
	idpot11.grenoble.grid5000.fr-6: date (12319): status > Exited with status 0
	idpot9.grenoble.grid5000.fr-7: date (17810): output > Thu May  3 18:57:42 CEST 2007
	idpot9.grenoble.grid5000.fr-7: date (17810): status > Exited with status 0
	idpot7.grenoble.grid5000.fr-10: date (7355): status > Exited with status 0
	idpot5.grenoble.grid5000.fr-12: date (13093): status > Exited with status 0
	
Setting the connector definitively and running taktuk again
___________________________________________________________

::

	jdoe@idpot1:~$ export TAKTUK_CONNECTOR=oarsh
	jdoe@idpot1:~$ taktuk -m idpot3 -m idpot4 broadcast exec [ date ]
	idpot3-1: date (12293): output > Wed Mar  7 09:20:25 CET 2007
	idpot4-2: date (7508): output > Wed Mar  7 09:20:19 CET 2007
	idpot3-1: date (12293): status > Exited with status 0
	idpot4-2: date (7508): status > Exited with status 0
	

Using MPI with OARSH
--------------------

To use MPI, you must setup your MPI stack so that it use OARSH instead of the
default RSH or SSH connector. All required steps for the main different flavors
of MPI are presented below. 

MPICH1
~~~~~~

Mpich1 connector can be changed using the P4_RSHCOMMAND environment variable.
This variable must be set in the shell configuration files. For instance for
bash, within ~/.bashrc

::

	export P4_RSHCOMMAND=oarsh

Please consider setting the P4_GLOBMEMSIZE as well.

You can then run your mpich1 application:

::

	jdoe@idpot4:~/mpi/mpich$ mpirun.mpich -machinefile $OAR_FILE_NODES -np 6 ./hello
	Hello world from process 0 of 6 running on idpot4.grenoble.grid5000.fr
	Hello world from process 4 of 6 running on idpot6.grenoble.grid5000.fr
	Hello world from process 1 of 6 running on idpot4.grenoble.grid5000.fr
	Hello world from process 3 of 6 running on idpot5.grenoble.grid5000.fr
	Hello world from process 2 of 6 running on idpot5.grenoble.grid5000.fr
	Hello world from process 5 of 6 running on idpot6.grenoble.grid5000.fr

MPICH2
~~~~~~

Tested version: 1.0.5p2

MPICH2 uses daemons on nodes that may be started with the "mpdboot" command.
This command takes oarsh has an argument (--rsh=oarsh) and all goes well:

::

	jdoe@idpot2:~/mpi/mpich/mpich2-1.0.5p2/bin$ ./mpicc -o hello ../../../hello.c 
	jdoe@idpot2:~/mpi/mpich/mpich2-1.0.5p2/bin$ ./mpdboot --file=$OAR_NODEFILE --rsh=oarsh -n 2
	jdoe@idpot2:~/mpi/mpich/mpich2-1.0.5p2/bin$ ./mpdtrace -l
	idpot2_39441 (129.88.70.2)
	idpot4_36313 (129.88.70.4)
	jdoe@idpot2:~/mpi/mpich/mpich2-1.0.5p2/bin$ ./mpiexec -np 8 ./hello
	Hello world from process 0 of 8 running on idpot2
	Hello world from process 1 of 8 running on idpot4
	Hello world from process 3 of 8 running on idpot4
	Hello world from process 2 of 8 running on idpot2
	Hello world from process 5 of 8 running on idpot4
	Hello world from process 4 of 8 running on idpot2
	Hello world from process 6 of 8 running on idpot2
	Hello world from process 7 of 8 running on idpot4

MVAPICH2
~~~~~~~~

You can use the hydra launcher with the options "-launcher" and
"-launcher-exec", for example:

::

    mpiexec -launcher ssh -launcher-exec /usr/bin/oarsh -f hosts -n 4 ./app

LAM/MPI
~~~~~~~

Tested version: 7.1.3

You can use export LAMRSH=oarsh before starting lamboot; otherwise the
"lamboot" command takes -ssi boot_rsh_agent "oarsh" option has an argument
(this is not in the manual!). Also note that OARSH doesn't automatically sends
the environnement of the user, so, you may need to specify the path to LAM
distribution on the nodes with this option: -prefix

::

	jdoe@idpot2:~/mpi/lam$ ./bin/lamboot -prefix ~/mpi/lam \
                                         -ssi boot_rsh_agent "oarsh" \
                                         -d $OAR_FILE_NODES
	jdoe@idpot2:~/mpi/lam$ ./bin/mpirun -np 8 hello
	Hello world from process 2 of 8 running on idpot2
	Hello world from process 3 of 8 running on idpot2
	Hello world from process 0 of 8 running on idpot2
	Hello world from process 1 of 8 running on idpot2
	Hello world from process 4 of 8 running on idpot4
	Hello world from process 6 of 8 running on idpot4
	Hello world from process 5 of 8 running on idpot4
	Hello world from process 7 of 8 running on idpot4

OpenMPI
~~~~~~~

Tested version: 1.1.4

The magic option to use with OpenMPI and OARSH is "-mca pls_rsh_agent "oarsh"".
Also note that OpenMPI works with daemons that are started on the nodes
(orted), but "mpirun" starts them on-demand. The "-prefix" option can help if
OpenMPI is not installed in a standard path on the cluster nodes (you can
replace the "-prefix" option by using the absolute path when invoking the
"mpirun" command).

::

	jdoe@idpot2:~/mpi/openmpi$ ./bin/mpirun -prefix ~/mpi/openmpi \
                                -machinefile $OAR_FILE_NODES \
                                -mca pls_rsh_agent "oarsh" \
                                -np 8 hello
	Hello world from process 0 of 8 running on idpot2
	Hello world from process 4 of 8 running on idpot4	
	Hello world from process 1 of 8 running on idpot2
	Hello world from process 5 of 8 running on idpot4
	Hello world from process 2 of 8 running on idpot2
	Hello world from process 6 of 8 running on idpot4
	Hello world from process 7 of 8 running on idpot4
	Hello world from process 3 of 8 running on idpot2

You can make the option "oarsh" automatically by adding it in a configuration
file in the OpenMPI installation directory named
"$OPENMPI_INSTALL_DIR/etc/openmpi-mca-params.conf"

::

    plm_rsh_agent=/usr/bin/oarsh

So, with this configuration, this is transparent for the users.

**Note**: In OpenMPI 1.6, "pls_rsh_agent" was replaced by "orte_rsh_agent".

Intel MPI
~~~~~~~~~
Example using the hydra launcher:
::

    mpiexec.hydra -genvall -f $OAR_NODE_FILE -bootstrap-exec oarsh -env I_MPI_DEBUG 5 -n 8 ./ring

Tests of the CPUSET mechanism
-----------------------------

Processus isolation
~~~~~~~~~~~~~~~~~~~

In this test, we run 4 yes commands in a job whose resources is only one core.
(syntax tested with bash as the user's shell)

::

	jdoe@idpot:~$ oarsub -l core=1 "yes > /dev/null & yes > /dev/null & yes > /dev/null & yes > /dev/null"
	[ADMISSION RULE] Set default walltime to 7200.
	[ADMISSION RULE] Modify resource description with type constraints
	OAR_JOB_ID=8683 

Then we connect to the node and run top

::

	jdoe@idpot:~$ oarsub -C 8683
	Initialize X11 forwarding...
	Connect to OAR job 8683 via the node idpot9.grenoble.grid5000.fr
	jdoe@idpot9:~$ ps -eo fname,pcpu,psr | grep yes
	yes      23.2   1
	yes      23.1   1
	yes      24.0   1
	yes      23.0   1

This shows that the 4 processus are indeed restricted to the core the job was
assigned to, as expected.

Don't forget to delete your job:

::

	jdoe@idpot:~$ oardel 8683

Using best effort mode jobs
---------------------------

Best effort job campaign
~~~~~~~~~~~~~~~~~~~~~~~~

OAR 2 provides a way to specify that jobs are best effort, which means that the
server can delete them if room is needed to fit other jobs. One can submit such
jobs using the besteffort type of job.

For instance you can run a job campaign as follows:

::

	for param in $(< ./paramlist); do
	    oarsub -t besteffort -l core=1 "./my_script.sh $param"
	done

In this example, the file ./paramlist contains a list of parameters for a
parametric application.

The following demonstrates the mechanism. 

Best effort job mechanism
~~~~~~~~~~~~~~~~~~~~~~~~~

Running a besteffort job in a first shell
_________________________________________

::

	jdoe@idpot:~$ oarsub -I -l nodes=23 -t besteffort
	[ADMISSION RULE] Added automatically besteffort resource constraint
	[ADMISSION RULE] Redirect automatically in the besteffort queue
	[ADMISSION RULE] Set default walltime to 7200.
	[ADMISSION RULE] Modify resource description with type constraints
	OAR_JOB_ID=9630 
	Interactive mode : waiting...
	[2007-05-10 11:06:25] Starting...

	Initialize X11 forwarding...
	Connect to OAR job 9630 via the node idcalc1.grenoble.grid5000.fr

Running a non best effort job on the same set of resources in a second shell
____________________________________________________________________________

::

	jdoe@idpot:~$ oarsub -I
	[ADMISSION RULE] Set default walltime to 7200.
	[ADMISSION RULE] Modify resource description with type constraints
	OAR_JOB_ID=9631 
	Interactive mode : waiting...
	[2007-05-10 11:06:50] Start prediction: 2007-05-10 11:06:50 (Karma = 0.000)
	[2007-05-10 11:06:53] Starting...

	Initialize X11 forwarding...
	Connect to OAR job 9631 via the node idpot9.grenoble.grid5000.fr

As expected, meanwhile the best effort job was stopped (watch the first shell):

::

	jdoe@idcalc1:~$ bash: line 1: 23946 Killed                  /bin/bash -l
	Connection to idcalc1.grenoble.grid5000.fr closed.
	Disconnected from OAR job 9630
	jdoe@idpot:~$

Testing the checkpointing trigger mechanism
-------------------------------------------

Writing the test script
~~~~~~~~~~~~~~~~~~~~~~~

Here is a script feature an infinite loop and a signal handler trigged by
SIGUSR2 (default signal for OAR's checkpointing mechanism).

::

	#!/bin/bash

	handler() { echo "Caught checkpoint signal at: `date`"; echo "Terminating."; exit 0; }
	trap handler SIGUSR2

	cat <<EOF
	Hostname: `hostname`
	Pid: $$
	Starting job at: `date`
	EOF
	while : ; do sleep 1; done

Running the job
~~~~~~~~~~~~~~~

We run the job on 1 core, and a walltime of 1 hour, and ask the job to be
checkpointed if it lasts (and it will indeed) more that walltime - 900 sec = 45
min.

::

	jdoe@idpot:~/oar-2.0/tests/checkpoint$ oarsub -l "core=1,walltime=1:0:0" --checkpoint 900 ./checkpoint.sh 
	[ADMISSION RULE] Modify resource description with type constraints
	OAR_JOB_ID=9464 
	jdoe@idpot:~/oar-2.0/tests/checkpoint$

Result
~~~~~~

Taking a look at the job output:

::

	jdoe@idpot:~/oar-2.0/tests/checkpoint$ cat OAR.9464.stdout 
	Hostname: idpot9
	Pid: 26577
	Starting job at: Fri May  4 19:41:11 CEST 2007
	Caught checkpoint signal at: Fri May  4 20:26:12 CEST 2007
	Terminating.

The checkpointing signal was sent to the job 15 minutes before the walltime as
expected so that the job can finish nicely.

Interactive checkpointing
~~~~~~~~~~~~~~~~~~~~~~~~~

The oardel command provides the capability to raise a checkpoint event
interactively to a job.

We submit the job again

::

	jdoe@idpot:~/oar-2.0/tests/checkpoint$ oarsub -l "core=1,walltime=1:0:0" --checkpoint 900 ./checkpoint.sh 
	[ADMISSION RULE] Modify resource description with type constraints
	OAR_JOB_ID=9521
	
Then run the oardel -c #jobid command...

::

	jdoe@idpot:~/oar-2.0/tests/checkpoint$ oardel -c 9521
	Checkpointing the job 9521 ...DONE.
	The job 9521 was notified to checkpoint itself (send SIGUSR2).
	
And then watch the job's output:

::

	jdoe@idpot:~/oar-2.0/tests/checkpoint$ cat OAR.9521.stdout 
	Hostname: idpot9
	Pid: 1242
	Starting job at: Mon May  7 16:39:04 CEST 2007
	Caught checkpoint signal at: Mon May  7 16:39:24 CEST 2007
	Terminating.

The job terminated as expected. 

Testing the mechanism of dependency on an anterior job termination
------------------------------------------------------------------

First Job
~~~~~~~~~

We run a first interactive job in a first Shell

::

	jdoe@idpot:~$ oarsub -I 
	[ADMISSION RULE] Set default walltime to 7200.
	[ADMISSION RULE] Modify resource description with type constraints
	OAR_JOB_ID=9458 
	Interactive mode : waiting...
	[2007-05-04 17:59:38] Starting...

	Initialize X11 forwarding...
	Connect to OAR job 9458 via the node idpot9.grenoble.grid5000.fr
	jdoe@idpot9:~$

And leave that job pending.

Second Job
~~~~~~~~~~

Then we run a second job in another Shell, with a dependence on the first one

::

	jdoe@idpot:~$ oarsub -I -a 9458
	[ADMISSION RULE] Set default walltime to 7200.
	[ADMISSION RULE] Modify resource description with type constraints
	OAR_JOB_ID=9459 
	Interactive mode : waiting...
	[2007-05-04 17:59:55] Start prediction: 2007-05-04 19:59:39 (Karma = 4.469)

So this second job is waiting for the first job walltime (or sooner
termination) to be reached to start.

Job dependency in action
~~~~~~~~~~~~~~~~~~~~~~~~

We do a logout on the first interactive job...

::

	jdoe@idpot9:~$ logout
	Connection to idpot9.grenoble.grid5000.fr closed.
	Disconnected from OAR job 9458
	jdoe@idpot:~$ 
	
... then watch the second Shell and see the second job starting

::

	[2007-05-04 18:05:05] Starting...
	
	Initialize X11 forwarding...
	Connect to OAR job 9459 via the node idpot7.grenoble.grid5000.fr
	
... as expected. 
