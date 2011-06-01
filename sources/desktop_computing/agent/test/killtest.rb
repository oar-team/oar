#!/usr/bin/env ruby

require 'job'

job = Job.new("1", {"command"=>"sleep 60", "directory"=>"/root", "stdout_file"=>"OAR.1.stdout", "stderr_file"=>"OAR.1.stderr", "state"=>"toLaunch"})
pid = job.fork
sleep 5

Process.kill("HUP", pid)
