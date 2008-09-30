
*oaradmin*
----------

This command permits to create resources and manage admission rules easily. An optional feature permits versioning changes in admission rules and conf files.

:Requirements:

For oaradmin, the following packages must be installed:
 
    - Perl-Yaml 
    - Ruby 1.8 or greater
    - Ruby-Yaml
    - Ruby-DBI
    - Subversion for the optional versioning feature


Options for resources subcommand are: :: 

  -a, --add                        Add new resources
      --cpusetproperty=prop        Property name for cpuset numbers
  -s, --select                     Select resources for update
  -p, --property                   Set value for a property
  -d, --delete                     Delete resources
  -c, --commit                     Commit in oar database

Examples: ::

  # oaradmin resources -a /node=mycluster{12}.domain/cpu={2}/core={2} 
  # oaradmin resources -a /node=mycluster-[1-250].domain/cpu={2}   
  # oaradmin resources -a /node=mycluster-[1-250].domain/cpu={2} -p memnode=1024 -p cpufreq=3.2 -p cputype=xeon 


Options for rules subcommand are: :: 

  -l, --list                       List admission rules
  -a, --add                        Add an admission rule
  -f, --file                       File which contains script for admission rule
  -d, --delete                     Delete admission rules
  -x, --export                     Export admission rules
  -e, --edit                       Edit an admission rule
  -1, --enable                     Enable the admission rule (removing comments)
  -0, --disable                    Disable the admission rule (commenting the code)
  -H, --history                    Show all changes made on the admission rule
  -R, --revert                     Revert to the admission rule as it existed in a revision number

Examples: ::

  # oaradmin rules -l
  # oaradmin rules -lll 3
  # oaradmin rules -e 3


Options for conf subcommand are: :: 

  -e, --edit                       Edit the conf file
  -H, --history                    Show all changes made on the conf file
  -R, --revert                     Revert to the conf file as it existed in a revision number

Examples: ::

  # oaradmin conf -e /etc/oar/oar.conf
  # oaradmin conf -R /etc/oar/oar.conf 3



