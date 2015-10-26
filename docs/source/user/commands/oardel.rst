oardel
------

This command is used to delete or checkpoint job(s). They are designed by
their identifier.

Option
::

  -c, --checkpoint        send checkpoint signal to the jobs
  -s, --signal <SIG>      send signal SIG to the jobs
  -b, --besteffort        change the specified jobs to besteffort jobs (or
                          remove them if they are already besteffort)
      --array             handle array job ids, and their sub jobs.
      --sql <SQL>         select jobs using a SQL WHERE clause on table jobs
                          (e.g. "project = 'p1'")
      --force-terminate-finishing-job
                          force jobs stuck in the Finishing state to switch to
                          Terminated (Warning: only use as a last resort)

Examples
::

  # oardel 14 42

(delete jobs 14 and 42)
::

  # oardel -c 42

(send checkpoint signal to the job 42)
