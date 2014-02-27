*oarhold*
---------

This command is used to remove a job from the scheduling queue if it is in
the "Waiting" state.

Moreover if its state is "Running" oarhold_ can suspend the execution and
enable other jobs to use its resources. In that way, a **SIGINT** signal
is sent to every processes.

Options
::

  --sql : hold jobs which respond to the SQL where clause on the table
          jobs (ex: "project = 'p1'")
  -r    : Manage not only Waiting jobs but also Running one
          (can suspend the job)
