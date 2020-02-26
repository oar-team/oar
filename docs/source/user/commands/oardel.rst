oardel
------

This command is used to delete or checkpoint job(s). They are designed by
their identifier.

Examples
::

  # oardel 14 42

(delete jobs 14 and 42)
::

  # oardel -c 42

(send checkpoint signal to the job 42)
