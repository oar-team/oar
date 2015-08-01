oarproperty
-----------

This command manages OAR resource properties stored in the database.

Options are: ::

  -l : list properties
  -a NAME : add a property
    -c : sql new field of type VARCHAR(255) (default is integer)
  -d NAME : delete a property
  -r "OLD_NAME,NEW_NAME" : rename property OLD_NAME into NEW_NAME

Examples: ::

  # oarproperty -a cpu_freq
  # oarproperty -r "cpu_freq,freq"
