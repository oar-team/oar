oarnodes
--------

This command prints informations about cluster resources (state, which jobs on
which resources, resource properties, ...).

Options
::

 -r, --resource     show the properties of the resource whose id is given as
                    parameter
 -s, --state        show the states of the nodes
 -l, --list         show the nodes list
 -e, --events       show the events recorded for a node either since the date
                    given as parameter or the last 20
     --sql          display resources which matches the SQL where clause
                    (ex: "state = 'Suspected'")
 -D, --dumper       print result in Perl Data::Dumper format
 -X, --xml          print result in XML format
 -Y, --yaml         print result in YAML format
 -J, --json         print result in JSON format

Examples
::

  # oarnodes
  # oarnodes -s
  # oarnodes --sql "state = 'Suspected'"
