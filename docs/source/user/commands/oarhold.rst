oarhold
-------

This command is used to remove a job from the scheduling queue if it is in
the "Waiting" state.

Moreover if its state is "Running" oarhold_ can suspend the execution and
enable other jobs to use its resources.

Options

::

  -r, --running manage not only Waiting jobs but also Running one
                (can suspend the job)
      --array   hold array job(s) passed as parameter (all the sub-jobs)
      --sql     hold jobs which respond to the SQL where clause on the table
                jobs (ex: "project = 'p1'")
