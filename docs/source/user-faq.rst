FAQ - USER
==========

Release policy
--------------

Since the version 2.2, release numbers are divided into 3 parts:
 - The first represents the design and the implementation used.
 - The second represents a set of OAR functionalities.
 - The third is incremented after bug fixes.

How can I submit a moldable job?
--------------------------------

You just have to use several "-l" :ref:`oarsub-anchor` option (one for each
moldable description). By default the OAR scheduler will launch the moldable
job which will end first.

So you can see some free resources but the scheduler can decide to start your
job later because they will have more free resources and the job walltime will
be smaller.

How can I submit a job with a non uniform description?
------------------------------------------------------

Example:
::
    
    oarsub -I -l '{switch = "sw1" or switch = "sw5"}/switch=1+/node=1'

This example asks OAR to reserve all resources from the switch sw1 or the
switch sw2 **and** a node on another switch.

You can see the "+" syntax as a sub-reservation directive.

Can I perform a fix scheduled reservation and then launch several jobs in it?
-----------------------------------------------------------------------------

Yes. You have to use the OAR scheduler "timesharing" feature.
To use it, the reservation and your further jobs must be of the type
timesharing (only for you).

Example:

  1. Make your reservation:
     ::
        
        oarsub -r "2006-09-12 8:00:00" -l /switch=1 -t 'timesharing=user,*'

     This command asks all resources from one switch at the given date for the
     default walltime. It also specifies that this job can be shared with
     himself and without a constraint on the job name.

  2. Once your reservation has begun then you can launch:
     ::

        oarsub -I -l /node=2,walltime=0:50:00 -p 'switch = "nom_du_switch_schedule"'\
        -t 'timesharing=user,*'

     So this job will be scheduled on nodes assigned from the previous reservation.

The "timesharing" :ref:`oarsub-anchor` command possibilities are enumerated in
:ref:`timesharing-anchor`.


How can a checkpointable job be resubmitted automatically?
----------------------------------------------------------

You have to specify that your job is *idempotent* and exit from your script
with the exit code 99. So, after a successful checkpoint, if the job is
resubmitted then all will go right and there will have no problem (like file
creation, deletion, ...).

Example:
::
    
    oarsub --checkpoint 600 --signal 2 -t idempotent /path/to/prog

So this job will send a signal *SIGINT* (see *man kill* to know signal
numbers) 10 minutes before the walltime ends. Then if everything goes
well and the exit code is 99 it will be resubmitted.

How to submit a non disturbing job for other users?
---------------------------------------------------

You can use the *besteffort* job type. Thus your job will be launched only
if there is a hole and will be deleted if another job wants its resources.

Example:
::

    oarsub -t besteffort /path/to/prog

