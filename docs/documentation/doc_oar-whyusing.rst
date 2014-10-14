Why using OAR
=============

OAR advantages
--------------

We present below some points that explain benefits of the new version of OAR.

A better resource management
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Using Linux kernel new feature called cpuset, OAR allows a more reliable 
management of the resources:

  * No unattended processes should remain from previous jobs.
  * Access to the resources is now restricted to the owner of the resources.

Beside, features like job dependency and check-pointing are now available, 
allowing a better resources use.

A cpuset is attached to every process, and allows:

  * to specify which resource processor/memory can be used by a process, e.g. 
    resources allocated to the job in OAR 2 context.
  * to group and identify processes that share the same cpuset, e.g. the 
    processes of a job in OAR 2 context, so that actions like clean-up can be 
    efficiently performed. (here, cpusets provide a replacement for the 
    group/session of processes concept that is not efficient in Linux). 

Multi-cluster
~~~~~~~~~~~~~

OAR can manage complex hierarchies of resources. For example:
   1. clusters
   2. switchs
   3. nodes
   4. cpus
   5. cores 

A modern cluster management system
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

By providing a mechanism to isolate the jobs at the core level, OAR is one of 
the most modern cluster management systems. Users developing cluster or grid 
algorithms and programs will then work in a today's up-to-date environment 
similar to the ones they will meet with other recent cluster management systems 
on production platforms for instance.

Optimization of the resources usage
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now a day, machines with more than 10 cores become common. Thus, it is then very 
important to be able to handle cores efficiently. By providing resources 
selection and processes isolation at the core level, OAR allows users running 
experiments that do not require the exclusivity of a node (at least during a 
preparation phase) to have access to many nodes on one core only, but leave the 
remaining cores free for other users. This can allow to optimize the number of 
available resources.

Beside, OAR also provide a time-sharing feature which will allow to share a 
same set of resources among users.

Easier access to the resources
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Using OAR OARSH connector to access the job resources, basic usages will not 
anymore require the user to configure his SSH environment as everything is 
handled internally (known host keys management, etc). Beside, users that would 
actually prefer not using OARSH can still use SSH with just the cost of some 
options to set (one of the features of the OARSH wrapper is to actually hide 
these options).

Grid resources interconnection
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

As access to one cluster resources is restricted to an attached job, one may 
wonder if connections from job to job, from cluster to cluster, from site to 
site would still be possible. OAR provides a mechanism called job-key than 
allows inter job communication, even on several sites managed by several OAR 
servers (this mechanism is indeed used by OARGrid2 for instance).

Management of abstract resources
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

OAR features a mechanism to manage resources like software licenses or other 
non-material resources the same way it manages classical resources.

OAR Uses and Users
------------------

At the present time, OAR is used in several countries (France, Slovakia, Brazil)
by several types of users.
These users are not only programmers and computer specialists but also simple
scientists, novices at programming. Thus the spread of users type is wide.

They are mainly:

- physicists 
- biologists that work on medical imaging, radioactivity study...
- weathermen
- chemical engineers
- computer sciences engineers and researchers that work on many subjects as 
  cryptography, data mining, HPC...
- stargazers that work on subjetcs like trajectory computation and data analysis
  from probes

