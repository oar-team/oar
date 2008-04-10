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

	jdoe@paramount:~$ oarsub -l core=10 runhpl/runhpl
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

	jdoe@paramount:~$ oarsub -l core=1 'echo $PATH;which ssh
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

	jdoe@paramount:~$ oarsub -l core=10 runhpl/runhpl -r "2007-10-10 18:00:00"
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

- ask for 10 cpus on 2 clusters (total = 20 cpus, information regarding the node ou core count depend on the topology of the machines) 

::

	oarsub -I -l /cluster=2/cpu=10

- ask for 1 core on 3 different network switches (total = 3 cores) 

::

	oarsub -I -l /switch=3/core=1


Using properties
~~~~~~~~~~~~~~~~

See OAR properties for a description of all available properties, and watch Monika.

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

- ask for 1 core on 2 nodes on the same cluster with 4096 GB of memory and Infiniband 10G + 1 cpu on 2 nodes on the same switch with bicore processors for a walltime of 4 hours 

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

OAR2 feature the concept of job "type". Among them, the type deploy (that used to be a queue with OAR 1.6) and the type besteffort.

- ask for 4 nodes on the same cluster in order to deploy a customized environment: 

::

	oarsub -I -l cluster=1/nodes=4,walltime=6 -t deploy

- submit besteffort jobs 

::

	for param in $(< ./paramlist); do
	    oarsub -t besteffort -l core=1 "./my_script.sh $param"
	done


X11 forwarding
--------------

Some users complained about the lack of X11 forwarding in oarsub or oarsh. It is now enabled.
We are using xeyes to test X: 2 big eyes should appear on your screen, and follow the moves of your mouse. 

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


