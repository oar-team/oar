*oarstat*
---------

This command prints jobs in execution mode on the terminal.

Options
::

  -j, --job                 show informations only for the specified job (even if it is finished)
  -f, --full                show full informations
  -s, --state               show only the state of a job (optimized query)
  -u, --user                show informations for this user only
  -g, --gantt               show job informations between two date-times
  -e, --events              show job events
  -p, --properties          show job properties
      --accounting          show accounting informations between two dates
      --sql                 restricts display by applying the SQL where clause
                            on the table jobs (ex: "project = 'p1'")
  -D, --dumper              print result in DUMPER format
  -X, --xml                 print result in XML format
  -Y, --yaml                print result in YAML format
      --backward-compatible OAR 1.* version like display
  -V, --version             print OAR version number
  -h, --help                show this help screen

Examples
::
            
  # oarstat
  # oarstat -j 42 -f
  # oarstat --sql "project = 'p1'"
  # oarstat -s -j 42
