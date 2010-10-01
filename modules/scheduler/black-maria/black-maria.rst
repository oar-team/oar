=======================================
Black-Maria: a coupling with other JRMS
=======================================

Black-Maria (BKM) is an extension to couple foreign job and resource management system (JRMS) with OAR. BKM is primarly developed to meet the needs of ANR-SPADES project. 

Principle:
----------
Workflow
1) submission to oar to a specific queue
2) oar metascheduler launch black-maria-sched
3) black-maria-sched submit to foreign JRMS and set parameter for black_maria_pilot.sh
4) black_maria_pilot.sh is launched when foreign JRMS started job
5) black_maria_pilot.sh signals black-maria-synch daemon (throught tcp)
6) black-maria-synch set node allocated by foreign JRMS in oar's db and signal Almigthy (OAR?)
7) black_maria_pilot.sh sleep

Limitations:
------------
* Caution it's a prototype and only developed for experimentation purpose 

Installation:
-------------


Running:
--------

Todo:
-----
* an alpha version ;)
* more connector

Comments, bugs, request:
------------------------

Log:
----


