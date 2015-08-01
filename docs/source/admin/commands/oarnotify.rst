oarnotify
---------

This command sends commands to the :ref:`module-almighty-anchor` module and manages scheduling
queues.

Option are: ::

      Almighty_tag    send this tag to the Almighty (default is TERM)
  -e                  active an existing queue
  -d                  inactive an existing queue
  -E                  active all queues
  -D                  inactive all queues
  --add_queue         add a new queue; syntax is name,priority,scheduler
                      (ex: "name,3,oar_sched_gantt_with_timesharing"
  --remove_queue      remove an existing queue
  -l                  list all queues and there status
  -h                  show this help screen
  -v                  print OAR version number
