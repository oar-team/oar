oar_dramaa
===========

A try to provide drmaa api for oar based on pbs-drmaa


Main adpatation
================
* remove log reader stuff because OAR keep job history in database. 

Features
=========
- DRMAA_REMOTE_COMMAND (TODO)
- DRMAA_WD (TODO)
- DRMAA_V_ARGV (TODO)
- DRMAA_INPUT_PATH (not tested)
Limitation and not supported features
======================================
- DRMAA_START_TIME (oar can do it by dependenct on advance reservation job

log
===

oar_drmaa/Makefile.am
modify configure.ace

autoreconf --install

adapt drmaa s/pbs/oar/


oar_statjob
------------
Based on pbs_statjob (see man 3 pbs_statjob for details)

 ``struct batch_status *pbs_statjob(int connect, char *id, struct attrl *attrib, char *extend)``

Note: If attrib is given, then only the attributes in the list are returned by the server.

man pbs_statjob (several mode , information on attrl)
http://linux.die.net/man/3/pbs_statjob

 if id == NULL -> return the status of all jobs <- not implemented yet
 if id == queue Identifier ->  return the status of all jobs in the queue  <- not implemented yet
 if id == job id -> return the status of this job
 if attrl == NULL -> return all attributes
 if attrl != NULL -> return the attributes whose names are pointed by the attrl member "name".

todo
====
* complet copyright header
* use ident for REST api access
* example with basic authentification/httpsn, other ???
* use:  json_builder_reset (builder); (see builder-test.c in json-glib-0.12.0/json-glib/tests)
* use: getinmemory.c curl example for

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



