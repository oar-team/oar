*Fault Tolerance*
-----------------

We would like to make OAR fault tolerant.
For implanting such a solution, two nerve centers have to be taken in account and be reinforced:

* the database
* the OAR server

One part of the solution could be to set a monitoring system between the OAR server and an other spare server (by heartbeat system or any other watch method, see "this page":http://www.linuxvirtualserver.org ).

For the database fault tolerance, replication mono master / mono slave seems to be a good solution in our context (see "MySQL replication":http://dev.mysql.com/doc/refman/5.0/en/replication.html and "PostGres replication":http://slony.info ).

The system has to work with both Postgres and Mysql databases.
However this solution is not necessary the best regarding the overload if the database is much solicited.

The work of the intern will be to set benchmarks to test if database (Postgres and Mysql) replication is acceptable and to suggest other solutions.

At the end of this study, the intern will have to choose and implement a solution for both server and database fault tolerance.

The intern will be in constant relation with the team and will regularly discuss the work progression by audioconference and by mail.


Classification: 
_______________

Medium

Intern required skills:
_______________________

* Perl
* Fault tolerance on linux servers
* Databases: Postgres, Mysql
* Linux
 
