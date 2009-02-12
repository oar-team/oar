Overview
========

This batch system is based on a database (MySql), a script language (Perl) and an optional scalable administrative tool (component of Taktuk framework). It is composed of modules which interact only with database and are executed as independent programs.  So formally, there is no API, the system is completely defined by the database schema. This approach eases the development of specific modules. Indeed, each module (such as schedulers) may be developed in any language having a database access library.

Main features :

    * Batch and Interactive jobs
    * Admission rules
    * Walltime
    * Matching of resources (job/node properties)
    * Hold and resume jobs
    * Multi-schedulers support (simple fifo and fifo with matching)
    * Multi-queues with priority
    * Best-effort queues (for exploiting idle resources)
    * Check compute nodes before launching
    * Epilogue/Prologue scriptsi
    * Activity visualization tools (Monika)
    * No Daemon on compute nodes
    * rsh and ssh as remote execution protocols (managed by Taktuk)
    * Dynamic insertion/deletion of compute node
    * Logging
    * Backfiling
    * First-Fit Scheduler with matching resource
    * Advance Reservation
    * Environnement of Demand support (Ka-tools integration)
    * Grid integration with Cigri system
    * Simple Desktop Computing Mode 

