=======
Orpheus
=======

 Orpheus is a simple jobs executor simulator. It replaces the use of runner, oarexec, bipbip and real or sleeping execution jobs.
Its purposes is to experiment and benchmark oar's frontend, scheduling modules and some part of resource management.

Principle:
----------

 A daemon named Orpheus is launched before firsts job submission. This daemon will simulate jobs' launching and jobs' termination.
Runner module is replaced be a symbolic link to /tmp/orpheus_signal_sender (created be orpheus daemon at its launching).
When Metascheduler execute runner, the orpheus_signal_sender is executed and send a signal to orpheus which will retrieve jobs to launch from the database.
Orpheus use the first argument of submitted job's command as execution time (field command in table jobs). Each second Orpheus tests if jobs have terminated, if this is the case it sets these jobs to terminated in database and sends a "Scheduling" command in Almighty's TCP socket. 

Limitations:
------------

 *  no support of Interactive job (no way)
 * besteffort and kill/delete job (in todo)
 * does not read oar.conf for db parameters and almighty port (aloso todo)
 * not validated/extensively tested

Installation:
-------------

 Note: execute following commands as oar user
 * cd /usr/lib/oar/
 * mv runner orig.runner
 * touch /tmp/orpheus_signal_sender
 * ln -s /tmp/orpheus_signal_sender runner
 * in oar.conf you must stop periodic node checking by setting FINAUD_FREQUENCY="0"
 
 * install lua5.1 liblua5.1-socket2
 * as root:
    * cd lua-signal
    * make && make install

Running:
--------

 * sudo -u oar lua orpheus.lua -> launch the executor

Todo:
-----

 * Support Killing job (for best effort and enerfy saving)
 * Use of "oarlib.lua" for db, config functions
 * test
 * support Hulot 
 * install/uninstall(active/unactive?) command
 
Comments, bugs, request:
------------------------

  * send mail to: oar-devel@lists.gforge.inria.fr
