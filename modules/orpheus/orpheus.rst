=======
Orpheus
=======

 Orpheus is a simple jobs executor simulator. It replaces the use of runner, oarexec, bipbip and real or sleeping execution jobs.
Its purposes is to experiment and benchmark oar's frontend, scheduling modules and some part of resource management.

Principle:
----------

 A daemon named Orpheus is launched before the firsts job submission. This daemon will simulate jobs' launching and jobs' termination.
Runner module is replaced be a symbolic link to /tmp/orpheus_signal_sender (created by orpheus daemon at its launching).
When Metascheduler launchs runner, the orpheus_signal_sender is executed and send a signal to orpheus which will retrieve jobs to launch from the database.

Jobs' execution times are fixed with command argument (field command in table jobs). The argument's format follow the Lua's table one. At second accuracy Orpheus tests if jobs have terminated, if this is the case it sets these jobs to terminated state in database and sends a "Scheduling" command in Almighty's TCP socket.

Orpheus provides some basic IO contention simple. Up to now only one IO model is provided. It is qualified of linear model where central IO capacity is share among competing jobs wich have IO requirements during all their execution. At contention, jobs face to slowdown equal to capacity divide amount of jobs' IO requirement. This factor is update at each start or end of job with IO requirements.  
 

Limitations:
------------

 * no support of Interactive job (no way)
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

 * Can be compiled with llvm-lua  

Running:
--------

 * sudo -u oar lua orpheus.lua -> launch the executor

Todo:
-----

 * Support Killing job (for best effort and enerfy saving)
 * Use of "oarlib.lua" for db, config functions
 * test
 * support Hulot ?
 * install/uninstall(active/unactive?) command
 * kameleon step
 * simple I/O simulation

Comments, bugs, request:
------------------------

  * send mail to: oar-devel@lists.gforge.inria.fr
