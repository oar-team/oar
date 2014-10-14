===============
DRMAAv1 for OAR
===============

:Authors: Olivier Richard <olivier.richard _at_ imag _ fr>  
:Contact: <oar-contact@lists.gforge.inria.fr>

:Copyright:     Copyright (C) 2012 Joseph Fourier University - France for specific OAR parts.
                Copyright (C) 2006-2008 FedStage Systems for other parts.


:Abstract: This document describes installation, configuration and usage
  of DRMAA for OAR_, which is based on `DRMAA for Torque/PBS Pro`_ library (PBS DRMAA for short).


.. contents::

Introduction
============

DRMAA for OAR is an implementation of `Open Grid Forum`_ DRMAA_
(Distributed Resource Management Application API) specification_ (version 1) for
submission and control jobs to OAR_ resources and tasks management system (also known as *batch scheduler*).  

Using DRMAA, grid applications builders, portal developers
and ISVs can use the same high-level API to link their software with
different cluster/resource management systems.

**This implemtation is based on** `DRMAA for Torque/PBS Pro`_ library developed by `FedStage Computing`_ and `Poznan Supercomputing and Networking Center`_.

Installation
============

The required librairies to compilation are following:
  * json-glib (version **0.12 or higher**)
  * libcurl
  * glib 2.0
  
Other required tools are :
 * GNU autotools (autoconf, automake, libtool),
 * GUN m4 macro processeur
 * gperf perfect hash function generator,
  
All these requirements are availble in major GNU/Linux distribution. 

For ``Debian``::

  $ apt-get install libjson-glib-dev libcurl3 

For ``Centos``::

  $ yum install glib2 glib2-devel  libcurl libcurl-devel json-glib json-glib-devel

Note for ``Centos 6.5`` json-glib package can be found at: https://github.com/project-hatohol/json-glib-for-distribution/blob/master/RPMS/x86_64/

To compile the library just go to main source directory and type::

  $ ./configure [--prefix=/installation/directory] && make
  $ make install


Configuration
=============

This librairy exploits the `OAR Restful API`_ to communicate with OAR system. The machine where DRMAA will be use must have access to the server API (see `OAR Restful API`_ documentation). By default the location of the API is ``http://localhost/oarapi``, it can be change by ``OAR_API_SERVER_URL`` environment variable.  


During DRMAA session initialization (``drmaa_init``) library tries to read
its configuration parameters from locations:
``/etc/oar_drmaa.conf``, ``~/.oar_drmaa.conf`` and from file given in
``OAR_DRMAA_CONF`` environment variable (if set to non-empty string).
If multiple configuration sources are present then all configurations
are merged with values from user-defined files taking precedence
(in following order: ``$OAR_DRMAA_CONF``, ``~/.oar_drmaa.conf``,
``/etc/oar_drmaa.conf``).

Currently recognized configuration parameters are:

  pool_delay
    Amount of time (in seconds) between successive checks of unfinished job(s).

     Type: integer, Default: 5

  wait_thread
    Value 1 enables single "wait thread" for updating jobs status. 
     
     Type: integer, Default: 0
     
  job_categories
    Dictionary of job categories.  It's keys are job categories names
    mapped to `native specification` strings.  Attributes set by
    job category can be overridden by corresponding DRMAA attributes
    or native specification.  Special category name ``default``
    is used when ``drmaa_job_category`` job attribute was not set.

  cache_job_state
    According to the DRMAA specification every `drmaa_job_ps()` call should
    query DRM system for job state.  With this option one may optimize
    communication with DRM.  If set to positive integer `drmaa_job_ps()`
    returns remembered job state without communicating with DRM for
    `cache_job_state` seconds since last update.  By default library
    conforms to specification (no caching will be performed).

    Type: integer, default: 0

.. table::
  Different modes of operation

  =========== ======== ======================= ===================================
  wait_thread   mode    keep_completed needed         comments
  =========== ======== ======================= ===================================
       0       polling           yes              default configuration
       1       polling           yes              more effective than above
  =========== ======== ======================= ===================================
  

Configuration file syntax
-------------------------

Configuration file is in form a dictionary.
Dictionary is set of zero or more key-value pairs.
Key is a string while value could be a string, an integer
or another dictionary.
::

  configuration: dictionary | dictionary_body
  dictionary: '{' dictionary_body '}'
  dictionary_body: (string ':' value ',')*
  value: integer | string | dictionary
  string: unquoted-string | single-quoted-string | double-quoted-string
  unquoted-string: [^ \t\n\r:,0-9][^ \t\n\r:,]*
  single-quoted-string: '[^']*'
  double-quoted-string: "[^"]*"
  integer: [0-9]+

Configuration file example
--------------------------

::
  
  # oar_drmaa.conf - Sample pbs_drmaa configuration file.
  
  wait_thread: 0,

  #pool_delay: 5,

  job_categories: {
	#default: "-q default", # 
	be: "-t besteffort",
	#test: "-N test -q testing",
  },
  

DRMAA attributes support and Native Specification
==================================================

DRMAA for OAR support main DRMAA attributes at the exception of `drmaa_start_time`  and `drmaa_block_email`.
There are not currently planned in the OAR roadmap if you need them please contact the developers. 

DRMAA interface allows to pass DRM dependant job submission options.
Those options may be specified by settings ``drmaa_native_specification`` and corresponds to `oarsub` 
command (the submission CLI tool). Note that all `oarsub` options are not available (see table below). 
For detailed description of each option see OAR documentation. Also note that all DRMAA attributes have not direct equivalent in `oarsub` options but remains. 

Attributes set in native specification overrides corresponding DRMAA job attributes.

.. table::
  DRMAA attributes with native specification equivalent when available or comment.

  ========================== ========================================================
  DRMAA attributes            OAR native specification and/or comment
  ========================== ========================================================
  drmaa_remote_command        job executable (submitted remote command)
  drmaa_v_argv                added to submitted remote command
  drmaa_job_name              `-n` job name
  drmaa_output_path           `-O` stdout   
  drmaa_error_path            `-E` stderr
  drmaa_input_path            added to submitted remote command
  drmaa_job_category          provided by drmaa library
  drmaa_join_files            added to submitted remote command
  drmaa_v_email               not yet available see --notify option as alternative                 
  drmaa_block_email           not yet available   
  drmaa_start_time            not yet available see -r (advance reservation) 
                              as alternative      
  drmaa_js_state              `-h`         
  drmaa_v_env                 added to submitted remote command
  drmaa_wd                    `-d` working directory
  drmaa_run_duration_hlimit   -l walltime=h:m:s
  ..                          `-l` resources for the job
  ..                          `-p` properties for the job,
  ..                          `-r` <DATE> The job will starts at a specified time
  ..                          `-checkpoint` <DELAY> Enable the checkpointing 
                              mechanism for the job. 
  ..                          `--signal` <#SIG> Specify the signal to use when 
                              checkpointing
  ..                          `-t` Specify a specific type for job
  ..                          `--project` <TXT> Specify a name of a project
  ..                          `-a` <OAR JOB ID> Job dependency
  ..                          `--notify` <TXT> Specify a notification method 
                              (mail or command to execute)
  ..                          `--resubmit` <OAR JOB ID> Resubmit the given job
  ..                          `--use-job-key`  Activate the job-key mechanism (see
                              oarsub manpage)
  ..                          `--import-job-key-from-file`  (see oarsub manpage)
  ..                          `--import-job-key-inline`  (see oarsub manpage)
  ========================== ========================================================

Test-suite
==========

The DRMAA for OAR library was successfully tested with OAR_ 2.5.3 and 2.5.4 on Debian and Centos.  Following
table presents results of tests from `Official DRMAA test-suite`_ (originally developed for Sun Grid Engine).

Note, the test with Suspending/Resuming job test require the ``USERS_ALLOWED_HOLD_RESUME="yes"`` is set on frontend's  OAR configuration file (`oar.conf`).

Known bugs and limitations
==========================

 * Job termination (when job is running) is realized by PBS
   by sending SIGTERM and/or SIGKILL therefore retrieving
   those signals cannot be distinguished from abort using
   ``drmaa_control(DRMAA_CONTROL_TERMINATE)``.  Then job termination
   state is marked as "aborted" and "signaled" whatever is the state.

 * ``drmaa_wcoredump()`` always returns ``false``.

 * Waiting functions (``drmaa_wait()`` and ``drmaa_synchronize()``)
   must pool DRM to find out whether job finished.


Release notes
=============

 * 1.0.1 support for 1.0.2 oarapi version and use pbs-drmaa-1.0.17 as intermediate library.
 * 1.0.0 first release 

Developers
==========

This library is based on `DRMAA for Torque/PBS Pro`_ and the core functionality of DRMAA is put into ``drmaa_utils`` library. `OAR`_ exploits the `OAR Restful API`_.

Developer tools
---------------
Although not needed for library user the following tools may be required
if you intend to develop DRMAA library for OAR or run tests:

 * GNU autotools (autoconf, automake, libtool, m4),
 * gperf_ perfect hash function generator,
 * glib
 * curl
 * glib_json

To initialize OAR DRMAA source files from OAR git repositoty go to ``sources/extra/oar-drmaa`` directory, launch ``./extract_from_pbs-drmaa_tgz.sh`` followed by  ``./autogen.sh``. To clean source files execute ``make clean`` and ``./extract_from_pbs-drmaa_tgz.sh rm``. 

.. _gperf:     http://www.gnu.org/software/gperf/

Contact and Bug Report
=======================
 
  For support or bug report:

      ``oar-users _at_ lists.gforge.inria.fr``

  For others concerns:

      ``oar-contact _at_ lists.gforge.inria.fr``

Acknowledgments
===============

  The `Poznan Supercomputing and Networking Center` and `FedStage Computing`_ compagny and their respective implied members for providing and open sourced  `PBS DRMAA`_  

.. _OAR: http:oar.imag.fr
.. _OAR Restful API: http:oar.imag.fr/documentation/
.. _DRMAA: http://drmaa.org/
.. _Open Grid Forum: http://www.gridforum.org/
.. _specification: http://www.ogf.org/documents/GFD.22.pdf
.. _Official DRMAA test-suite: http://www.drmaa.org/wiki/index.php?pagename=DrmaaTestsuite
.. _DRMAA for Torque/PBS Pro: http://apps.man.poznan.pl/trac/pbs-drmaa/
.. _PBS DRMAA: http://apps.man.poznan.pl/trac/pbs-drmaa/
.. _FedStage Computing: http://www.fedstage.com/wiki/FedStage_Computing
.. _PBS: http://en.wikipedia.org/wiki/Portable_Batch_System
.. _PBS Professional: http://www.pbsgridworks.com/
.. _PBS Pro: http://www.pbsgridworks.com/
.. _Torque: http://www.clusterresources.com/pages/products/torque-resource-manager.php
.. _OpenPBS: http://www.openpbs.org/
.. _Poznan Supercomputing and Networking Center: http://www.man.poznan.pl/online/en/

License
=======

Copyright (C) 2012 Joseph Fourier University - France for OAR parts
Copyright (C) 2006-2008 FedStage Systems for other parts

This program is free software: you can redistribute it and/or modify
it under the terms of the `GNU General Public License` as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the `GNU General Public License`
along with this program.  If not, see <http://www.gnu.org/licenses/>.




