#!/usr/bin/env ruby

require 'job'
job = Job.new("4", {      "stderr_file" => "OAR.4.stderr",      "stdout_file" => "OAR.4.stdout",      "directory" => "/home/thiago/myjob",      "command" => "sleep 90",      "state" => "toLaunch"   })

job2 = Job.new("1", {      "stderr_file" => "OAR.4.stderr",      "stdout_file" => "OAR.4.stdout",      "directory" => "/home/thiago/myjob",      "command" => "sleep 90",      "state" => "toLaunch"   })
pid = job.fork
puts pid
pid = job2.fork
puts pid
sleep 60
