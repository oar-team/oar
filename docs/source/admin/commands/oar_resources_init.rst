oar_resource_init
-----------------

Connect to a list of hosts to gather system information and create the corresponding OAR resources.

Hosts are read one per line from a file or STDIN.

The command either generates a script which could be executed afterward, or directly executes the OAR commands (oarnodesetting and oarproperty).

The following OAR resource hierarchy is assumed:

host > cpu > core

Or if the *-T*  option is set:

host > cpu > core > thread

The mem property is set along with the hierarchy.

Other properties are not set, however the generated script can be modified to do so, or the oarnodesetting command can be used to set them afterward.
