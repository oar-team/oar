oar_resource_add
----------------

Yet another helper script to define OAR resources

This tool generates the oarproperty and oarnodesetting commands to create OAR resources following the host / cpu / core (/ thread) hierarchy, possibly with GPU alongside.

REMINDER: Each physical element (each cpu, each core, each thread, each gpu) must have a unique identifier in the OAR resources database. If some resources already exists in the database (e.g. from a previously installed cluster), offsets can be given in the command line or guessed with the auto-offset option, so that identifiers for newly created resources are unique.

This tool is also a good example of how one can create OAR resources using script loops and the oarnodesetting command. If it does not exactly fit your needs, feel free to read the script code and adapt it.

The oar_resource_add tool does not look at the actual hardware topology of the target machines. Core and GPU device affinity to CPU may not be correct. See the *hwloc*  commands for instance to find out the correct topology and affinity, and use the --cputopo and --gputopo options accordingly.
