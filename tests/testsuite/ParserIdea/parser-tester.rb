#!/usr/bin/ruby -w

# required for parsing config files
require 'yaml'
require 'librestapi'

require 'rubygems'
require 'rest_client'
require 'json'
require 'pp'

#Global Constant variable
APIURI="http://www.grenoble.grid5000.fr/oarapi"
path = "/home/nk/newidea/testfile.yaml"
$jobid = ""
begin
  $testfile = YAML.load(File.open(path))
rescue
  print "Failed to open testfile file. ", $!, "\n"
  exit(2)
end

obj = OarApis.new(APIURI) #Object of OarApis class

$testfile['test_submit'].each do
|name|
#if name.kind_of?(Hash)
hname = name.keys[0]
puts hname+" is a kind of Hash"
#end
if hname == "submission"
puts "Job Submission"    
name['submission'].each do |param|
param.each do |key,value|
puts key.to_s+ " : "+value.to_s

if key == "script"
$script = value
elsif key == "resources"
$resource = value
elsif key == "walltime"
$walltime = value
end
end
end
script = $script
resource = $resource
walltime =  $walltime
  jhash = { 'resource' => "#{resource}" , 'script' => "#{script}", 'walltime' => "#{walltime}" }
 
 begin
    obj.submit_job(jhash) #Create a sample jhash
 rescue
    puts "#{$!}"
 exit 2
end
 
   obj.jobstatus.each do|m,n|
    puts m.to_s+" : " + n.to_s
    if m == "id"
    $jobid = n   
    end
    end
#puts $jobid
elsif hname == "exec"
command = "sleep 60"
system(command)
elsif hname == "check"
 puts "Testing starts here"
name['check'].each do |chk1|
if chk1.is_a?(Hash)
#puts "chk1 is hash - yes"
chk1.each do |chk2|
if chk2.is_a?(Array)
#puts "chk2 is a Array - yes"
chk2.each do |a|
if a.is_a?(Array)
#puts "a is a array"
a.each do |b|
if b.is_a?(Hash)
#puts "b is a hash"
b.each do |key,value|
puts key.to_s+":"+value.to_s
 #TESTING IF STATE IS RUNNING

   if key == "state"

    begin
     obj.specific_job_details($jobid)
    rescue
     puts "#{$!}"
     exit 2
    end

    if  obj.specificjobdetails['state'] == "Running"
      puts "Test Succeeded"
    else
      puts "Test Failed"
      exit 1
    end
   end


end
end
end
end
end
end
end
end
end
end
end



