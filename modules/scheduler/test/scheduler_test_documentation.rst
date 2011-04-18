
Scheduler only Tests
====================

These documentation notes are only for testing scheduler core modules of OAR.
Tests are ruby scripts which manipulate database and launch targed scheduler.

Requirements
------------

 Before testing, database must be initiated by *oar_mysql_db_init.pl* or/and *oar_psql_db_init.pl* script together with *oar.conf*. Scheduler to test *must* be in /usr/lib/oar/schedulers/ directory. Tests *must* be launched as oar or root. 

Usage
-----

Launch all tests

 $ ./scheduler_test.rb  scheduler

Interactive Use
---------------

Session example:

 $ irb -r oar_db_setting -r oar_test_scheduler_helpers.rb

*Note*: You can use irb tab-completion to access all oar_* helper functions. There are several ways to have completion enable in irb (irb/completion or wirble gem by example).  

Todo (for developer)
--------------------
 * more tests
 * more docs
