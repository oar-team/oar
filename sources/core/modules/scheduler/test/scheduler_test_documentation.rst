
Schedulers Testing 
====================

These documentation notes are only for schedulers.
Tests are set of ruby scripts which help to manipulate database and to launch targed scheduler.

Requirements
------------

 Before testing, database must be initiated by *oar_mysql_db_init.pl* or/and *oar_psql_db_init.pl* script together with *oar.conf*. Scheduler to test must located accordingly to your installation, by example  in /usr/lib/oar/schedulers/ or /usr/local/lib/oar/schedulers/ directory. Tests *must* be launched as oar or root. 

Scritps and files purposes
--------------------------

oar_db_setting.rb: 
  provides function to manipulate oar tables. It uses ./oar_test_conf as oar.conf.

oar_test_scheduler_helpers.rb:

scheduler_test.rb:



Usage and tips
---------------

* we highly recommend you to use pry in place to irb 
  http://pryrepl.org/
  pry -r ./oar_db_setting.rb   


* [alternative to pry] irb enhancement with wirble (completion, color and so on)
  http://pablotron.org/software/wirble/


* halt oar server
  $ sudo service oar-server stop

* time conversion in ruby
  >> Time.now.to_i
  => 1313765725
  >> Time.at(1313765725)
  => Fri Aug 19 16:55:25 0200 2011

* launch pry with oar_db_setting.rb preloading (it uses ./oar_test_conf as oar.conf)
 $ pry -r ./oar_db_setting.rb

* launch irb with oar_db_setting.rb preloading (it uses ./oar_test_conf as oar.conf)
 $ irb -r oar_db_setting.rb

* launch tests
 $ ./scheduler_test.rb  scheduler

