
oar damaa-v1
============

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
- DRMAA_START_TIME (oar can do it by dependenct on advance reservation job or sumit hold job and do "at oarresume jobid" c)

log
===

oar_drmaa/Makefile.am
modify configure.ac

autoreconf --install

adapt drmaa s/pbs/oar/

todo
====
* mandory job attributes see GFD-R.133 section 3.2.3 p15
* oar_statjob (id / attrl = NULL see man pbs_statjob)
* oar_sumbit / attributs / default attributs
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



build system
------------
-  oar_drmaa/Makefile.am
-  modify configure.ac

- autoreconf --install



