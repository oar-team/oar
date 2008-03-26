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

