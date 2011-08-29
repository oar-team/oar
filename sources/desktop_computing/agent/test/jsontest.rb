#!/usr/bin/env ruby

require 'rubygems'
require 'json'

job_hash = JSON.parse('{   "1" : {      "stderr_file" : "OAR.1.stderr",      "stdout_file" : "OAR.1.stdout",      "directory" : "/root",      "command" : "date",      "state" : "toLaunch"   }}')

job_hash.each_key do |k|
  system job_hash[k]["command"]
end

puts 'working!'
