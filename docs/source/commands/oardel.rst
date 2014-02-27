*oardel*
--------

This command is used to delete or checkpoint job(s). They are designed by
their identifier.

Options
::

  --sql     : delete/checkpoint jobs which respond to the SQL where clause
              on the table jobs (ex: "project = 'p1'")
  -c job_id : send checkpoint signal to the job (signal was
              definedwith "--signal" option in oarsub)

Examples
::

  # oardel 14 42

(delete jobs 14 and 42)
::

  # oardel -c 42

(send checkpoint signal to the job 42)
