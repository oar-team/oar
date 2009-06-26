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

You can also access to the API using a browser. Make it point to http://www.myoarcluster.local/oarapi/index.html and you'll see a very simple HTML interface allowing you to browse the cluster resources and even post a job using a form. (of course, replace www.myoarcluster.local by a valid name allowing you to join the http service of the host where you installed the oar api)

But generally, you'll use a REST client or a REST library provided for your favorite language. You'll see examples using a ruby rest library in the next parts of this document. 

Authentication
--------------

Data structures and formats
---------------------------

Errors and debug
----------------


REST requests description
=========================

Examples are given in the YAML format because we think that it is the more human readable and so very suitable for this kind of documentation. But you can also use the JSON format for your input/output data. Each resource uri may be postfixed by .yaml, .jso of .html.

GET /index
----------
:description:
  Home page for the HTML browsing

:formats:
  html

:authentication:
  public

:output:
  *example*:
   ::

    <HTML>
    <HEAD>
    <TITLE>OAR REST API</TITLE>
    </HEAD>
    <BODY>
    <HR>
    <A HREF=./resources.html>RESOURCES</A>&nbsp;&nbsp;&nbsp;
    <A HREF=./jobs.html>JOBS</A>&nbsp;&nbsp;&nbsp;
    <A HREF=./jobs/form.html>SUBMISSION</A>&nbsp;&nbsp;&nbsp;
    <HR>
    Welcome on the oar API

:note:
  Header of the HTML resources may be customized into the **/etc/oar/api_html_header.pl** file.

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
  *structure*: array of hashes (a job is an array element described by a hash)

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

POST /jobs/<id>
---------------
:description:
  Updates a job.
  In fact, as some clients (www browsers) doesn't support the DELETE method, this POST resource has been created mainly to workaround this and provide another way to delete a job. It also provides *checkpoint*, *hold* and *resume* methods, but one should preferably use the /checkpoints, /holds and /resumes resources.

:formats:
  html , yaml , json

:authentication:
  user

:input:
  *structure*: hash {"action" => "delete"}

  *yaml example*:
   ::

    ---
    method: delete

:output:
  *structure*: hash

  *yaml example*:
   ::

    ---
    api_timestamp: 1245944206
    cmd_output: |
      Deleting the job = 554 ...REGISTERED.
      The job(s) [ 554 ] will be deleted in a near future.
    id: 554
    status: Delete request registered

:usage example:
  ::

   # Deleting a job in the ruby rest client
   puts post('/jobs/554.yaml','{"method":"delete"}',:content_type => "application/json")

DELETE /jobs/<id>
-----------------
:description:
  Delete or kill a job.

:formats:
  html , yaml , json

:authentication:
  user

:output:
  *structure*: hash returning the status

  *yaml example*:
   ::

    ---
    api_timestamp: 1245944206
    cmd_output: |
      Deleting the job = 554 ...REGISTERED.
      The job(s) [ 554 ] will be deleted in a near future.
    id: 554
    status: Delete request registered

:usage example:
  ::

   # Deleting a job in the ruby rest client
   puts delete('/jobs/554.yaml')

:note:
  Not all clients support the DELETE method, especially some www browsers. So, you can do the same thing with a POST of a {"method":"delete"} hash on the /jobs/<id> resource.

GET /jobs/form
--------------
:description:
  HTML form for posting (submiting) new jobs from a browser

:formats:
  html

:authentication:
  user

:output:
  *example*:
   ::

    <HTML>
     <HEAD>
     <TITLE>OAR REST API</TITLE>
     </HEAD>
     <BODY>
     <HR>
     <A HREF=../resources.html>RESOURCES</A>&nbsp;&nbsp;&nbsp;
     <A HREF=../jobs.html>JOBS</A>&nbsp;&nbsp;&nbsp;
     <A HREF=../jobs/form.html>SUBMISSION</A>&nbsp;&nbsp;&nbsp;
     <HR>
     
     <FORM METHOD=post ACTION=../jobs.html>
     <TABLE>
     <CAPTION>Job submission</CAPTION>
     <TR>
       <TD>Resources</TD>
       <TD><INPUT TYPE=text SIZE=40 NAME=resource VALUE="/nodes=1/cpu=1,walltime=00:30:00"></TD>
     </TR><TR>
       <TD>Name</TD>
       <TD><INPUT TYPE=text SIZE=40 NAME=name VALUE="Test_job"></TD>
     </TR><TR>
       <TD>Properties</TD>
       <TD><INPUT TYPE=text SIZE=40 NAME=property VALUE=""></TD>
     </TR><TR>
       <TD>Program to run</TD>
       <TD><INPUT TYPE=text SIZE=40 NAME=script_path VALUE='"/bin/sleep 300"'></TD>
     </TR><TR>
       <TD>Types</TD>
       <TD><INPUT TYPE=text SIZE=40 NAME=type></TD>
     </TR><TR>
       <TD>Reservation dates</TD>
       <TD><INPUT TYPE=text SIZE=40 NAME=reservation></TD>
     </TR><TR>
       <TD>Directory</TD>
       <TD><INPUT TYPE=text SIZE=40 NAME=directory></TD>
     </TR><TR>
       <TD></TD><TD><INPUT TYPE=submit VALUE=SUBMIT></TD>
     </TR>
     </TABLE>
     </FORM>
     
:note:
  This form may be customized in the **/etc/oar/api_html_postform.pl** file

GET /resources
--------------
:description:
  Get the list of resources and their state

:formats:
  html , yaml , json

:authentication:
  public

:output:
  *structure*: array of hashes

  *yaml example*:
    ::

     ---
     - api_timestamp: 1245861829
       id: 6
       node: liza-2
       node_uri: /resources/nodes/liza-2
       state: Suspected
       uri: /resources/6
     - api_timestamp: 1245861829
       id: 7
       node: liza-2
       node_uri: /resources/nodes/liza-2
       state: Suspected
       uri: /resources/7
     - api_timestamp: 1245861829
       id: 4
       node: liza-1
       node_uri: /resources/nodes/liza-1
       state: Suspected
       uri: /resources/4
     - api_timestamp: 1245861829
       id: 5
       node: liza-1
       node_uri: /resources/nodes/liza-1
       state: Suspected
       uri: /resources/5


  *note*: More details about a resource can be obtained with a GET on the provided *uri*. Details about all the resources of the same node may be obtained with a GET on *node_uri*.

:usage example:
  ::

   wget -q -O - http://localhost/oarapi/resources.yaml

GET /resources/all
------------------
:description:
  Get the list of resources and all the details about them

:formats:
  html , yaml , json

:authentication:
  public

:output:
  *structure*: array of hashes

  *yaml example*:
    ::

     ---
     - api_timestamp: 1245862386
       id: 3
       network_address: bart-3
       node: bart-3
       node_uri: /resources/nodes/bart-3
       properties:
         besteffort: YES
         cluster: 0
         cm_availability: 0
         cpu: 2
         cpuset: 0
         deploy: NO
         desktop_computing: NO
         expiry_date: 0
         finaud_decision: YES
         last_job_date: 1245825515
         licence: ~
         network_address: bart-3
         next_finaud_decision: NO
         next_state: UnChanged
         resource_id: 3
         scheduler_priority: 0
         state: Alive
         state_num: 1
         suspended_jobs: NO
         type: default
       state: Alive
       uri: /resources/3
     - api_timestamp: 1245862386
       id: 1
       network_address: bart-1
       node: bart-1
       node_uri: /resources/nodes/bart-1
       properties:
         besteffort: YES
         cluster: 0
         cm_availability: 0
         cpu: 20
         cpuset: 0
         deploy: NO
         desktop_computing: NO
         expiry_date: 0
         finaud_decision: NO
         last_job_date: 1245671400
         licence: ~
         network_address: bart-1
         next_finaud_decision: NO
         next_state: UnChanged
         resource_id: 1
         scheduler_priority: 0
         state: Suspected
         state_num: 3
         suspended_jobs: NO
         type: default
       state: Suspected
       uri: /resources/1
     - api_timestamp: 1245862386
       id: 26
       network_address: test2
       node: test2
       node_uri: /resources/nodes/test2
       properties:
         besteffort: YES
         cluster: ~
         cm_availability: 0
         cpu: 10
         cpuset: 0
         deploy: NO
         desktop_computing: NO
         expiry_date: 0
         finaud_decision: YES
         last_job_date: 1239978322
         licence: ~
         network_address: test2
         next_finaud_decision: NO
         next_state: UnChanged
         resource_id: 26
         scheduler_priority: 0
         state: Suspected
         state_num: 3
         suspended_jobs: NO
         type: default
       state: Suspected
       uri: /resources/26

:usage example:
  ::

   wget -q -O - http://localhost/oarapi/resources/all.yaml

GET /resources/<id>
-------------------
:description:
  Get details about the resource identified by *id*

:formats:
  html , yaml , json

:authentication:
  public

:output:
  *structure*: 1 element array of hash

  *yaml example*:
    ::

     ---
     - api_timestamp: 1245862386
       id: 3
       network_address: bart-3
       node: bart-3
       node_uri: /resources/nodes/bart-3
       properties:
         besteffort: YES
         cluster: 0
         cm_availability: 0
         cpu: 2
         cpuset: 0
         deploy: NO
         desktop_computing: NO
         expiry_date: 0
         finaud_decision: YES
         last_job_date: 1245825515
         licence: ~
         network_address: bart-3
         next_finaud_decision: NO
         next_state: UnChanged
         resource_id: 3
         scheduler_priority: 0
         state: Alive
         state_num: 1
         suspended_jobs: NO
         type: default
       state: Alive
       uri: /resources/3

:usage example:
  ::

   wget -q -O - http://localhost/oarapi/resources/3.yaml

GET /resources/nodes/<network_address>
--------------------------------------
:description:
  Get details about the resources belonging to the node identified by *network_address*

:formats:
  html , yaml , json

:authentication:
  public

:output:
  *structure*: array of hashes

  *yaml example*:
    ::

     ---
     - api_timestamp: 1245945275
       id: 4
       network_address: liza-1
       node: liza-1
       node_uri: /resources/nodes/liza-1
       properties:
         besteffort: YES
         cluster: 0
         cm_availability: 0
         cpu: 3
         cpuset: 0
         deploy: YES
         desktop_computing: NO
         expiry_date: 0
         finaud_decision: NO
         last_job_date: 1245825515
         licence: ~
         network_address: liza-1
         next_finaud_decision: NO
         next_state: UnChanged
         resource_id: 4
         scheduler_priority: 4294967289
         state: Suspected
         state_num: 3
         suspended_jobs: NO
         type: default
       state: Suspected
       uri: /resources/4
     - api_timestamp: 1245945275
       id: 5
       network_address: liza-1
       node: liza-1
       node_uri: /resources/nodes/liza-1
       properties:
         besteffort: YES
         cluster: 0
         cm_availability: 0
         cpu: 4
         cpuset: 1
         deploy: YES
         desktop_computing: NO
         expiry_date: 0
         finaud_decision: NO
         last_job_date: 1240244422
         licence: ~
         network_address: liza-1
         next_finaud_decision: NO
         next_state: UnChanged
         resource_id: 5
         scheduler_priority: 4294967293
         state: Suspected
         state_num: 3
         suspended_jobs: NO
         type: default
       state: Suspected
       uri: /resources/5

:usage example:
  ::

   wget -q -O - http://localhost/oarapi/resources/nodes/liza-1.yaml


POST /resources
---------------
:description:
  Creates a new resource

:formats:
  html , yaml , json

:authentication:
  oar

:input:
  A [hostname] or [network_address] entry is mandatory 

  *structure*: hash describing the resource to be created

  *fields*:
     - **hostname** alias **network_address** (*string*): the network address given to the resource
     - **properties** (*hash*): an optional hash defining some properties for this new resource

  *yaml example*:
    ::

     ---
     hostname: test2
     properties:
       besteffort: "NO"
       cpu: "10"

:output:
  *structure*: hash returning the id of the newly created resource and status

  *yaml example*:
    ::

     ---
     api_timestamp: 1245946199
     id: 32
     status: ok
     uri: /resources/32
     warnings: []

:usage example:
  ::

   # Adding a new resource with the ruby rest client (oar user only)
   irb(main):078:0> r={ 'hostname'=>'test2', 'properties'=> { 'besteffort'=>'NO' , 'cpu' => '10' } }
   irb(main):078:0> puts post('/resources', r.to_json , :content_type => 'application/json')

DELETE /resources/<id>
----------------------
:description:
  Delete the resource identified by *id*

:formats:
  html , yaml , json

:authentication:
  oar

:output:
  *structure*: hash returning the status

  *yaml example*:
    ::

     ---
     api_timestamp: 1245946801
     status: deleted

:usage example:
  ::

   # Deleting a resource with the ruby rest client
   puts delete('/resources/32.yaml')

:note:
  If the resource could not be deleted, returns a 403 and the reason into the message body.
