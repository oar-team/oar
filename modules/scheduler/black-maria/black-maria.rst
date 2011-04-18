=======================================
Black-Maria: a coupling with other JRMS
=======================================

Black-Maria (BKM) is an extension to couple foreign resource and job management system (RJMS) with OAR. BKM is primarly developed to meet the needs of ANR-SPADES project. 

Principle:
----------
Workflow
1) submission to oar to a specific queue
2) oar metascheduler launch black-maria-sched
3) black-maria-sched submit to foreign RJMS and set parameter for black_maria_pilot.sh
4) black_maria_pilot.sh is launched when foreign RJMS started job
5) black_maria_pilot.sh signals black-maria-synch daemon (throught tcp via nc)
6) black-maria-synch set node allocated by foreign RJMS in oar's db and signal Almigthy (OAR?)
7) black_maria_pilot.sh sleep (default oar walltime minus a timeguard)

Limitations:
------------
* Only Slurm is supported as foreign RJMS (04/03/11)
* Walltime must be expressed in second

Dependencies:
-------------
* lua: 5.1 or higher
* lua libraries: liblua5.1-copas0 blua5.1-coxpcall0 liblua5.1-sql-mysql-2
* nc for bkm-pilot script to communicate to bkm-synch (not secure !!!)

Installation:
-------------
* see black-maria-test.rst

Running:
--------
* see black-maria-test.rst

Todo:
-----
* an alpha version ;)
* more RJMS connector
* support node nodelist with slurm node list grammar ex: dev[0-8,12,13,18-25]

* recette/makefile installation 

Comments, bugs, request:
------------------------

* Caution it's a prototype and only developed for experimentation purpose 

Log:
----

