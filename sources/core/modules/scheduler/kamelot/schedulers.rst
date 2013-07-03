

======================== =========== ==============
                           Schedulers
------------------------ --------------------------
  Features                    Perl     Simple_ocaml
======================== =========== ==============
multiple resources             Y           Y (1)
resources matching             Y           Y 
suspend/resume                 Y           Y (1)
hierarchies                    Y           Y
moldable job                   Y           N (2)
container job                  Y           Y 
job dependencies               Y           Y
conservative backfilling       Y           Y
fairsharing                    Y           Y
token script                   Y           N (3)
ORDER_BY on resource           Y           Y
besteffort task                Y           Y
security gap                   Y           Y
energy saving                  Y           Y
timesharing                    Y           N (4)
placeholder                    Y           N (5) 
ALL  resources request         Y           Y
BEST resources resquet         Y           Y
BESTHALF resources resquet     N           Y
========================= =========== ==============
                           Metaschuler
------------------------- -----------
advance reservation            Y
multiple queues                Y
queue priorities               Y
besteffort                     Y
energy saving                  Y

(1) Need more test.
(2) Consider only the first instance to schedule.
(3) On the roadmap.
(4) Can be considered for a next release (contact mailing-list).
(5) Not planned.
