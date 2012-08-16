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
 
To compile the library just go to main source directory and type::

  $ ./configure [--prefix=/installation/directory] && make


Configuration
=============

This librairy exploits the `OAR Restfull API`_ to communicate with OAR system. The machine where DRMAA will be use must have access to the server API (see `OAR Restfull API`_ documentation). By default the location of the API is ``http://localhost/oarapi``, it can be change by ``OAR_API_SERVER_URL`` environment variable.  


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
    mapped to `native specification`_ strings.  Attributes set by
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
  

Native specification
====================

DRMAA interface allows to pass DRM dependant job submission options.
Those options may be specified by settings ``drmaa_native_specification``. ``drmaa_native_specification``
accepts space delimited ``qsub``. ``qsub``
options which does not set job attributes (`-b`, `-z`, `-C`) as
well as meant for submission of interactive jobs (`-I`, `-X`) or
to specify directories (`-d`, `-D`) are *not* supported.
Also instead of `-W` option following long options are accepted
within native specification: `--depend`, `--group-list`, `--stagein`
and `--stageout`.  For detailed description of each option see PBS
documentation.

Attributes set in native specification overrides corresponding DRMAA job
attributes.

.. table::
  Native specification strings with corresponding DRMAA attributes.

  ===================== =============== ============ ====================
  DRMAA attribute       OAR attribute   OAR resource native specification
  ===================== =============== ============ ====================
                      Attributes which get overridden                   
  -----------------------------------------------------------------------
  drmaa_job_name        name                         `-N` job name       
  drmaa_output_path     Output_Path                  `-o` output path    
  drmaa_error_path      Error_Path                   `-e` error path     
  drmaa_join_files      Join_Path                    `-j` join options   
  drmaa_block_email     Mail_Points                  `-m` mail options   
  drmaa_start_time      Execution_Time               `-a` start time     
  drmaa_js_state        Hold_Types                   `-h`                
  ..                    Account_Name                 `-A` account string 
  ..                    Checkpoint                   `-c` interval       
  ..                    Keep_Files                   `-k` keep           
  ..                    Priority                     `-p` priority       
  ..                    destination                  `-q` queue          
  ..                    Rerunable                    `-r` y/n            
  ..                    Shell_Path_List              `-S` path list      
  ..                    User_List                    `-u` user list      
  ..                    group_list                   `--group_list=`\groups 
  drmaa_v_env           Variable_List                `-v` variable list  
  ..                    Variable_List                `-V`                
  drmaa_v_email         Mail_Users                   `-M` user list      
  drmaa_duration_hlimit Resource_List   cput         `-l cput=`\limit    
  drmaa_wct_hlimit      Resource_List   walltime     `-l walltime=`\limit
  ..                    Resource_List                `-l` resources      
  ===================== =============== ============ ====================

Limitations
===========
Library covers nearly all DRMAA 1.0 specification_ with exceptions
listed below.  It passes the `official DRMAA test-suite`_ .

Test-suite
==========

The DRMAA for OAR library was successfully tested with OAR_ 2.5.4 on Linux OS.  Following
table presents results of tests from `Official DRMAA test-suite`_ (originally developed for Sun Grid Engine).


Developers
==========

This library is based on `DRMAA for Torque/PBS Pro`_ and the core functionality of DRMAA is put into ``drmaa_utils`` library. `OAR`_ exploits the Rest OAR API .

Developer tools
---------------
Although not needed for library user the following tools may be required
if you intend to develop DRMAA for Torque/PBS Pro library or run tests:

 * GNU autotools (autoconf, automake, libtool),
 * gperf_ perfect hash function generator,
 * glib
 * curl
 * glib_json

.. _gperf:     http://www.gnu.org/software/gperf/



Contact
=======

Acknowledgments
===============

Release notes
=============



.. _OAR: http:oar.imag.fr
.. _OAR Restfull API: http:oar.imag.fr/documentation/
.. _DRMAA: http://drmaa.org/
.. _Open Grid Forum: http://www.gridforum.org/
.. _specification: http://www.ogf.org/documents/GFD.22.pdf
.. _Official DRMAA test-suite: http://www.drmaa.org/wiki/index.php?pagename=DrmaaTestsuite
.. _DRMAA for Torque/PBS Pro: http://apps.man.poznan.pl/trac/pbs-drmaa/

.. _FedStage DRMAA for PBS Pro:
  http://www.fedstage.com/wiki/FedStage_DRMAA_for_PBS_Pro
.. _PBS DRMAA: http://www.fedstage.com/wiki/FedStage_DRMAA_for_PBS_Pro
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
it under the terms of the `GNU General Public License`_ as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the `GNU General Public License`_
along with this program.  If not, see <http://www.gnu.org/licenses/>.




