oar_dramaa
===========

A try to provide drmaa api for oar based on pbs-drmaa


Main adpatation
================
* remove log reader stuff because OAR keep job history in database. 

Features
=========
- DRMAA_REMOTE_COMMAND (TODO/totest)
- DRMAA_WD (TODO)/totest
- DRMAA_V_ARGV (TODO/totest)
- DRMAA_INPUT_PATH (TODO/totested)
Limitation and not supported features
======================================
- DRMAA_START_TIME (oar can do it by dependenct on advance reservation job

log
===

oar_drmaa/Makefile.am
modify configure.ace

autoreconf --install

adapt drmaa s/pbs/oar/

todo
====

* oar_statjob (id / attrl = NULL see man pbs_statjob)
* oar_sumbit / attributs
* end_time
* start_time
* frag trick
* doc
* testing
* glib-json
* install / packaging
* attributes
* ressources
* native specification  options
* default_attributes
* system/user hold event
* resume/suspend-user/system event
* curl/json-glib/error modularities
* OAR_ERROR
* free json_reader result
* complet copyright header
* example with basic authentification/httpsn, other ???

log of modification
====================

basic tests: curl and json-glib
-------------------------------
- use json-glib-0.12.0 for reader / builder
 json_builder_reset (builder);


oar_drmaa file
--------------
- in general: s/pbs/oar/
- drmaa.c: general fonction nothing tricky)
- session.h: remove some struct pbsdrmaa_session_s fields
- session.c: remove PBS_PRO, comment some code to adpat later
- job.h:
- job.c: big function to adapt: oardrmaa_job_update
- submit.h:
- submit.c:
- util.h:
- util.c: remove pbsdrmaa_write_tmpfile, fsd_getline and fsd_getline_buffered.Todo: Maps PBS error code into DMRAA code.
- oar.h: to replace pbs_ifl.h
- oar_error.h: to replace pbs_error.h
- oar.c:

general:
~~~~~~~~
- do we need of  oar_attrib.gperf (hash between drmaa / oar attributes) .
- OAR_ERRNO_X in oar_erroh.h
- oar_errno (global variable ! Do we need a mutex ? Not sure, must verify that there are mutexes around oar_drmaa function 
build system
------------
-  oar_drmaa/Makefile.am
-  modify configure.ac

- autoreconf --install



