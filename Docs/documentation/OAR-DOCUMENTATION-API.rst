================================
 OAR Documentation - REST API
================================

:Dedication: For users whishing to make programs interfaced with OAR

.. include:: doc_abstract.rst

**BE CAREFULL : THIS DOCUMENTATION IS FOR OAR >= 2.4.0**

PDF version : `<OAR-DOCUMENTATION-API.pdf>`_

.. section-numbering::
.. contents:: Table of Contents

-------------------------------------------------------------------------------

Introduction
============

Concepts
========

Access
------
A simple GET query to the API using wget may look like this::

    # Get the list of resources
    wget -O - http://www.mydomain.org/oarapi/resources.yaml?structure=simple

Authentication
--------------

Data structures and formats
---------------------------

Errors and debug
----------------


REST requests description
=========================

Examples are given in the YAML format because we think that it is the more human readable and so very suitable for this kind of documentation. But you can also use the JSON format for your input/output data. Each resource uri may be postfixed by .yaml, .jso of .html.

GET /version
------------
:description: 
  Gives version informations about OAR and OAR API. Also gives the timezone of the API server.

:formats:
  html , yaml , json

:authentication:
  public

:output:
  *structure*: 
    hash

  *yaml example*: 
    ::

     ---
     api: 0.1.2
     api_timestamp: 1245582255
     api_timezone: CEST
     apilib: 0.1.6
     oar: 2.4.0

:usage example:
  ::

   wget -q -O - http://localhost/oarapi/version.yaml

GET /timezone
-------------
:description:
  Gives the timezone of the OAR API server

:formats:
  html , yaml , json

:authentication:
  public

:output:
  *structure*: hash

  *yaml example*: 
    ::

     ---
     api_timestamp: 1245768107
     timezone: CEST

:usage example:
  ::

   wget -q -O - http://localhost/oarapi/timezone.yaml

GET /jobs
---------
:description:
  List currently running jobs

:formats:
  html , yaml , json

:authentication:
  public

:output:
  *structure*: array of hash (a job is an array element described by a hash)

  *yaml example*:
    ::

     ---
     - api_timestamp: 1245768256
       id: 547
       name: ~
       owner: bzizou
       queue: default
       state: Running
       submission: 1245768249
       uri: /jobs/547
     - api_timestamp: 1245768256
       id: 546
       name: ~
       owner: bzizou
       queue: default
       state: Running
       submission: 1245768241
       uri: /jobs/546

  *note*: You can make a GET on the *uri* value for more details about a given job.

:usage example:
  ::

   wget -q -O - http://localhost/oarapi/jobs.yaml

GET /jobs/<id>
--------------
:description:
  Get details about the given job

:parameters:
  -**id**: the id of a job

:formats:
  html , yaml , json

:authentication:
  user

:output:
  *structure*: hash

  *yaml example*:
    ::

     ---
     547:
       Job_Id: 547
       array_id: 547
       array_index: 1
       assigned_network_address:
         - liza-2
       assigned_resources:
         - 6
       command: ''
       cpuset_name: bzizou_547
       dependencies: []
       events: []
       exit_code: ~
       initial_request: oarsub -I
       jobType: INTERACTIVE
       job_uid: ~
       job_user: bzizou
       launchingDirectory: /home/bzizou
       message: FIFO scheduling OK
       name: ~
       owner: bzizou
       project: default
       properties: desktop_computing = 'NO'
       queue: default
       reservation: None
       resubmit_job_id: 0
       scheduledStart: 1245768251
       startTime: 1245768251
       state: Running
       submissionTime: 1245768249
       types: []
       walltime: 7200
       wanted_resources: "-l \"{type = 'default'}/resource_id=1,walltime=2:0:0\" "

:usage example:
  ::

   wget --user test --password test -q -O - http://localhost/oarapi/jobs/547.yaml

POST /jobs
----------
:description:
  Creates (submit) a new job

:formats:
  html , yaml , json

:authentication:
  user

:input:
  Only [resource] and [script_path or script] are mandatory

  *structure*: hash with possible arrays (for options that may be passed multiple times)

  *fields*:
     - **resource** (*string*): the resources description as required by oar (example: "/nodes=1/cpu=2")
     - **script_path** (*string*): the name and path of a script that is launched when the job starts
     - **script** (*text*): an inline provided script that will is launched when the job starts
     - **workdir** (*string*): the path of the directory from where the job will be submited
     - **All other option accepted by the oarsub unix command**: every long option that may be passed to the oarsub command is known as a key of the input hash. If the option is a toggle (no value), you just have to set it to "1" (for example: 'use-job-key' => '1'). Some options may be arrays (for example if you want to specify several 'types' for a job)
  *yaml example*:
    ::

     ---
     stdout: /tmp/outfile
     script_path: /usr/bin/id
     resource: /nodes=2/cpu=1
     workdir: ~bzizou/tmp
     type:
     - besteffort
     - timesharing
     use-job-key: 1

:output:
  *structure*: hash

  *yaml example*:
    ::

     ---
     api_timestamp: 1245858042
     id: 551
     status: submitted
     uri: /jobs/551

  *note*: more informations about the submited job may be obtained with a GET on the provided *uri*.

:usage example:
  ::

   # Submitting a job using ruby rest client
   irb(main):010:0> require 'json'
   irb(main):012:0> j={ 'resource' => '/nodes=2/cpu=1', 'script_path' => '/usr/bin/id' }
   irb(main):015:0> job=post('/jobs' , j.to_json , :content_type => 'application/json')

