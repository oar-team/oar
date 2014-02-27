*oarnodes*
----------

This command prints informations about cluster resources (state, which jobs on
which resources, resource properties, ...).

Options
::

  -a                : shows all resources with their properties
  -r                : show only properties of a resource
  -s                : shows only resource states
  -l                : shows only resource list
  --sql "sql where" : Display resources which matches this sql where clause
  -D                : formats outputs in Perl Dumper
  -X                : formats outputs in XML
  -Y                : formats outputs in YAML

Examples
::

  # oarnodes 
  # oarnodes -s
  # oarnodes --sql "state = 'Suspected'"
