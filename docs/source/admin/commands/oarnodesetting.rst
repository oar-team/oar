oarnodesetting
--------------

This command allows to change the state or a property of a node or of several
resources resources.

By default the node name used by `oarnodesetting`_ is the result of the command
*hostname*.

Options are::

 -r, --resource [resource_id]         Resource id of the resource to modify
 -h, --hostname [hostname]            Hostname for the resources to modify
 -f, --file [file]                    Get a hostname list from a file (1
                                      hostname by line) for resources to modify
     --sql [SQL]                      Select resources to modify from database
                                      using a SQL where clause on the resource
                                      table (e.g.: "type = 'default'")
 -a, --add                            Add a new resource
 -s, --state=state                    Set the new state of the node
 -m, --maintenance [on|off]           Set/unset maintenance mode for resources,
                                      this is equivalent to setting its state
                                      to Absent and its available_upto to 0
 -d, --drain [on|off]                 Prevent new job to be scheduled on
                                      resources, this is equivalent to setting
                                      the drain property to YES
 -p, --property ["property=value"]    Set the property of the resource to the
                                      given value
 -n, --no-wait                        Do not wait for job end when the node
                                      switches to Absent or Dead
     --last-property-value [property] Get the last value used for a property (as
                                      sorted by SQL's ORDER BY DESC)
