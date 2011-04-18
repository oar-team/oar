#!/usr/bin/env ruby

require 'job'

job = Job.new("1", {"command"=>"sleep 60", "directory"=>"/root", "stdout_file"=>"OAR.1.stdout", "stderr_file"=>"OAR.1.stderr", "state"=>"toLaunch"})

Signal.trap("TERM") do
  job.kill
  exit
end
pid = job.wrap "sleep 60"
