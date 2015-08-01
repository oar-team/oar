oarstat
-------

This command prints jobs in execution mode on the terminal.

Options
::

  -j, --job                 show informations only for the specified job
  -f, --full                show full informations
  -s, --state               show only the state of a job (optimized query)
  -u, --user                show informations for this user only
      --array               show informations for the specified array_job(s) and
                            toggle array view in
  -c, --compact             prints a single line for array jobs
  -g, --gantt               show job informations between two date-times
  -e, --events              show job events
  -p, --properties          show job properties
      --accounting          show accounting informations between two dates
      --sql                 restricts display by applying the SQL where clause
                            on the table jobs (ex: "project = 'p1'")
      --format              select the text output format. Available values
                            are:
                              - 1
                              - 2
  -D, --dumper              print result in DUMPER format
  -X, --xml                 print result in XML format
  -Y, --yaml                print result in YAML format
  -J, --json                print result in JSON format


Examples
::

  # oarstat
  # oarstat -j 42 -f
  # oarstat --sql "project='p1' and state='Waiting'"
  # oarstat -s -j 42
