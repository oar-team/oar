oarsub
------

The user can submit a job with this command. So, what is a job in our context?

  A job is defined by needed resources and a script/program to run. So, the user
  must specify how many resources and what kind of them are needed by his
  application. Thus, OAR system will give him or not what he wants and will
  control the execution. When a job is launched, OAR executes user program only
  on the first reservation node. So this program can access some environment
  variables to know its environment:
  ::

    $OAR_NODEFILE                 contains the name of a file which lists
                                  all reserved nodes for this job
    $OAR_JOB_ID                   contains the OAR job identificator
    $OAR_RESOURCE_PROPERTIES_FILE contains the name of a file which lists
                                  all resources and their properties
    $OAR_JOB_NAME                 name of the job given by the "-n" option
    $OAR_PROJECT_NAME             job project name

See the manual page of the command for its syntax.

Wanted resources have to be described in a hierarchical manner using the
"-l" syntax option.

Moreover it is possible to give a specification that must be matched on properties.

So the long and complete syntax is of the form::

    "{ sql1 }/prop1=1/prop2=3+{sql2}/prop3=2/prop4=1/prop5=1+...,walltime=1:00:00"

where:
 - *sql1* : SQL WHERE clause on the table of resources that filters resource
   names used in the hierarchical description
 - *prop1* : first type of resources
 - *prop2* : second type of resources
 - *+* : add another resource hierarchy to the previous one
 - *sql2* : SQL WHERE clause to apply on the second hierarchy request
 - ...

So we want to reserve 3 resources with the same value of the type *prop2* and
with the same property *prop1* and these resources must fit *sql1*. To that
possible resources we want to add 2 others which fit *sql2* and the hierarchy
*/prop3=2/prop4=1/prop5=1*.


.. figure:: ../../_static/hierarchical_resources.png
   :align: center
   :target: ../../_static/hierarchical_resources.png
   :alt: Hierarchical resource example

   Example of a resource hierarchy and 2 different oarsub commands

Examples
::

  # oarsub -l /nodes=4 test.sh

(the "test.sh" script will be run on 4 entire nodes in the default queue with
the default walltime)
::

  # oarsub --stdout='test12.%jobid%.stdout' --stderr='test12.%jobid%.stderr' -l
    /nodes=4 test.sh
    ...
    OAR_JOB_ID=702
    ...

(same example than above but here the standard output of "test.sh" will be
written in the file "test12.702.stdout" and the standard error in
"test12.702.stderr")

::

  # oarsub -q default -l /nodes=10/cpu=3,walltime=2:15:00 \
    -p "switch = 'sw1'" /home/users/toto/prog

(the "/home/users/toto/prog" script will be run on 10 nodes with 3 cpus (so a
total of 30 cpus) in the default queue with a walltime of  2:15:00.
Moreover "-p" option restricts resources only on the switch 'sw1')
::

  # oarsub -r "2009-04-27 11:00:00" -l /nodes=12/cpu=2

(a reservation will begin at "2009-04-27 11:00:00" on 12 nodes with 2 cpus
on each one)
::

  #  oarsub -C 42

(connects to the job 42 on the first node and set all OAR environment
variables)
::

  #  oarsub -p "not host like 'nodename.%'"

(To exclude a node from the request)
::

  # oarsub -I

(gives a shell on a resource)
