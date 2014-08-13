OAR capabilities
================
Oar is an opensource batch scheduler which provides a simple and flexible
exploitation of a cluster.

It manages resources of clusters as a traditional batch scheduler
(as PBS / Torque / LSF / SGE). In other words, it doesn't execute your job on 
the resources but manages them (reservation, acces granting) in order to allow
you to connect these resources and use them.

Its design is based on high level tools:

  - relational database engine MySQL or PostgreSQL,
  - scripting language Perl,  
  - confinement kernel system mechanism cpuset,
  - scalable exploiting tool Taktuk.

It is flexible enough to be suitable for production clusters and research
experiments.
It currently manages over than 5000 nodes and has executed more than 20 million
jobs.

OAR advantages:

  - No specific daemon on nodes.
  - No dependence on specific computing libraries like MPI. We support all
    sort of parallel user applications.
  - Upgrades are made on the servers, nothing to do on computing nodes.
  - CPUSET (2.6 linux kernel) integration which restricts the jobs on
    assigned resources (also useful to clean completely a job, even
    parallel jobs).
  - All administration tasks are performed with the taktuk command (a large
    scale remote execution deployment): http://taktuk.gforge.inria.fr/.
  - Hierarchical resource requests (handle heterogeneous clusters).
  - Gantt scheduling (so you can visualize the internal scheduler decisions).
  - Full or partial time-sharing.
  - Checkpoint/resubmit.
  - Licences servers management support.
  - Best effort jobs : if another job wants the same resources then it is
    deleted automatically (useful to execute programs like *SETI@home*).
  - Environment deployment support (Kadeploy):
    http://kadeploy.imag.fr/.

Other more *common* features:

  - Batch and Interactive jobs.
  - Admission rules.
  - Walltime.
  - Multi-schedulers support.
  - Multi-queues with priority.
  - Backfilling.
  - First-Fit Scheduler.
  - Reservation.
  - Support of moldable tasks.
  - Check compute nodes.
  - Epilogue/Prologue scripts.
  - Support of dynamic nodes.
  - Logging/Accounting.
  - Suspend/resume jobs.
  
