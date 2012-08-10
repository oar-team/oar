===============
DRMAAv1 for OAR
===============

:Authors: Olivier Richard <olivier.richard _at_ imag _ fr>  
:Contact: <oar-contact@lists.gforge.inria.fr>

:Copyright:     Copyright (C) 2012 Joseph Fourier University - France
                Copyright (C) 2006-2008 FedStage Systems for inital version


:Abstract: This document describes installation, configuration and usage
  of `DRMAA for OAR`_ , *which is based on* `DRMAA for Torque/PBS Pro`_ library (PBS DRMAA for short).



Drmaa v1 for OAR
=================

Introduction
============

DRMAA for OAR is an implementation of `Open Grid Forum`_ DRMAA_
(Distributed Resource Management Application API) specification_ for
submission and control jobs to OAR_ resource anf task management system (also known as batch scheduler).  

Using DRMAA, grid applications builders, portal developers
and ISVs can use the same high-level API to link their software with
different cluster/resource management systems.

**This implemtation is based on `DRMAA for Torque/PBS Pro`_ library developed by  FedStage Systems**

Installation
============

  require oar api

Configuration
=============

During DRMAA session initialization (``drmaa_init``) library tries to read
its configuration parameters from locations:
``/etc/oar_drmaa.conf``, ``~/.oar_drmaa.conf`` and from file given in
``PBS_DRMAA_CONF`` environment variable (if set to non-empty string).
If multiple configuration sources are present then all configurations
are merged with values from user-defined files taking precedence
(in following order: ``$OAR_DRMAA_CONF``, ``~/.oar_drmaa.conf``,
``/etc/oar_drmaa.conf``).

Currently recognized configuration parameters are:

  pool_delay
    Amount of time (in seconds) between successive checks of unfinished job(s).

     Type: integer, Default: 5
     
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
  =========== ================================ ===================================
  

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
	#default: "-k n", # delete output files from execution hosts
	longterm: "-p -100 -l nice=5",
	amd64: "-l arch=amd64",
	python: "-l software=python",
	java: "-l software=java,vmem=500mb -v PATH=/opt/sun-jdk-1.6:/usr/bin:/bin",
	#test: "-u test -q testing",
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
  drmaa_job_name        name                     `-N` job name       
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
  ..                    depend                       `--depend=`\dependency
  ..                    stagein                      `--stagein=`\stagein 
  ..                    stageout                     `--stageout=`\stageout
  ===================== =============== ============ ====================

Limitations
===========
Library covers nearly all DRMAA 1.0 specification_ with exceptions
listed below.  It passes the `official DRMAA test-suite`_ .

Test-suite
==========

The DRMAA for OAR library was successfully tested with OAR_ 2.5.2 on Linux OS.  Following
table presents results of tests from `Official DRMAA test-suite`_ (originally developed for Sun Grid Engine).

.. table::
  Mode - Polling

  =============================================== =========== ============ 
                  Test name                        PBS Pro 10  Torque 2.5.1 
  =============================================== =========== ============ 
  test_mt_exit_during_submit                        passed       passed           
  test_mt_exit_during_submit_or_wait                passed       passed           
  test_mt_submit_before_init_wait                   passed       passed            
  test_mt_submit_mt_wait                            passed       passed            
  test_mt_submit_wait                               passed       passed            
  test_st_attribute_change                          passed       passed            
  test_st_bulk_singlesubmit_wait_individual         passed       passed            
  test_st_bulk_submit_in_hold_session_delete        passed       passed            
  test_st_bulk_submit_in_hold_session_release       passed       passed            
  test_st_bulk_submit_in_hold_single_delete         passed       passed            
  test_st_bulk_submit_in_hold_single_release        passed       passed            
  test_st_bulk_submit_wait                          passed       passed            
  test_st_contact                                   passed       passed            
  test_st_drm_system                                passed       passed            
  test_st_drmaa_impl                                passed       passed            
  test_st_empty_session_control                     passed       passed            
  test_st_empty_session_synchronize_dispose         passed       passed            
  test_st_empty_session_synchronize_nodispose       passed       passed            
  test_st_empty_session_wait                        passed       passed            
  test_st_error_file_failure                      FAILED [1]_    passed       
  test_st_exit_status                             FAILED [1]_    passed       
  test_st_input_file_failure                      FAILED [1]_    passed       
  test_st_mult_exit                                 passed       passed        
  test_st_mult_init                                 passed       passed         
  test_st_output_file_failure                     FAILED [1]_    passed      
  test_st_submit_in_hold_delete                     passed       passed         
  test_st_submit_in_hold_release                    passed       passed         
  test_st_submit_kill_sig                         FAILED [1]_    passed       
  test_st_submit_polling_synchronize_timeout        passed       passed        
  test_st_submit_polling_synchronize_zerotimeout    passed       passed        
  test_st_submit_polling_wait_timeout               passed       passed        
  test_st_submit_polling_wait_zerotimeout           passed       passed       
  test_st_submit_suspend_resume_wait                passed       passed       
  test_st_submit_wait                               passed       passed       
  test_st_submitmixture_sync_all_dispose            passed       passed      
  test_st_submitmixture_sync_all_nodispose          passed       passed       
  test_st_submitmixture_sync_allids_dispose         passed       passed      
  test_st_submitmixture_sync_allids_nodispose       passed       passed     
  test_st_supported_attr                            passed       passed    
  test_st_supported_vattr                           passed       passed    
  test_st_usage_check                               passed       passed    
  test_st_version                                   passed       passed    
  =============================================== =========== ============ 


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

Release notes
=============



.. _OAR: http:oar.imag.fr
.. _DRMAA: http://drmaa.org/
.. _Open Grid Forum: http://www.gridforum.org/
.. _specification: http://www.ogf.org/documents/GFD.22.pdf
.. _Official DRMAA test-suite: http://www.drmaa.org/wiki/index.php?pagename=DrmaaTestsuite
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
.. _OAR: http:oar.imag.fr

License
=======

Copyright (C) 2006-2008 FedStage Systems

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




