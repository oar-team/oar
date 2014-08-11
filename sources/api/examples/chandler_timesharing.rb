#!/usr/bin/ruby

# "Chandler"
# Simple example ruby script using the OAR RESTFUL API
# It prints a colored textmode status of the cluster
#
# This is a modified version of the original chandler to
# better display information regarding timesharing jobs

require 'rubygems'
require 'rest_client'
require 'json'
require 'pp'
require 'natural_sort'
require 'date'

# Custom variables
APIURI="http://localhost/oarapi"
NODENAME_REGEX="(.*)\.grenoble\.grid5000\.fr"
NODENAME_MAX_LENGTH=12

# Function to get objects from the api
# We use the JSON format and the 'simple' data structure
def get(api,uri)
  begin
    return JSON.parse(api[uri+'?structure=simple'].get(:accept => 'application/json'))
  rescue => e
    if e.respond_to?('http_code')
      puts "ERROR #{e.http_code}:\n #{e.response.body}"
    else
      puts "Parse error:"
      puts e.inspect
    end
    exit 1
  end
end

# Instanciate an api connection
api = RestClient::Resource.new APIURI

# Print a waiting message
printf ("Please, wait while querying OAR API...\n\033[1A")

# Get the resources
resources = get(api,'/resources')

# Get the running jobs
jobs = get(api,'jobs/details')

# Erase the waiting message
printf ("\033[2K")

# Construct a has of used resources
used_resources={}
resource_jobs={}
jobs['items'].select{|job| job['state'] == "Running"}.each do |job|
  v=1
  if job['types'].grep(/^timesharing=\*,name$/).any?
    v=2
  end
  job['resources'].each do |r|
    resources['items'].select{|rr| rr['id']==r['id']}.each do |rr| 
      h = rr['network_address']
      if resource_jobs[h].nil?
        resource_jobs[h] = [job]
      else
        resource_jobs[h] << job
      end
    end
    used_resources[r['id']]=v if r['status']=="assigned"
  end
end

# Print summary
puts "#{resources['items'].length} resources, #{used_resources.length} used, by #{jobs['items'].length} job(s)"

# For each node
col=0
NaturalSort::naturalsort(resources['items'].collect{|r| r['network_address']}.uniq).each do |node|
  state = ""
  if node!="" # some resources are not nodes (subnets)
    n = resources['items'].select{|r| r['network_address']==node}
    n.each do |resource|
      if resource['state'] == "Dead"
        state << "\033[41m\033[30mD\033[0m"
      elsif resource['state'] == "Absent"
        if resource['available_upto'].to_i > Time.new().to_i
          state << "\033[46m \033[0m"
        else
          state << "\033[41m\033[30mA\033[0m"
        end
      elsif resource['state'] == "Suspected"
        state << "\033[41m\033[30mS\033[0m"
      elsif resource['state'] == "Alive"
        #jobs=get(api,resource['jobs_uri'])
        #if jobs.nil?
        if used_resources[resource['id']].nil?
          state << "\033[42m \033[0m"
        elsif used_resources[resource['id']] == 2
          state << "\033[47m\033[30mT\033[0m"
        else
          state << "\033[43m\033[30mJ\033[0m"
        end
      end
    end
    node=~/#{NODENAME_REGEX}/
    puts "#{$1.rjust(NODENAME_MAX_LENGTH)}: #{state}"
  end
end
puts "\nNode state: \033[42m \033[0m=Free \033[46m \033[0m=Standby \033[41m\033[30mS\033[0m=Suspected \033[41m\033[30mA\033[0m=Absent \033[41m\033[30mD\033[0m=Dead\n"
puts "Job kind: \033[43m\033[30mJ\033[0m=Exclusive job \033[47m\033[30mT\033[0m=Shared job\n\n"

NaturalSort::naturalsort(resource_jobs).each do |k,v|
  print k,"\n"
  v.uniq.each do |j|
    d = Time.at(j['start_time'].to_i + j['walltime'].to_i) - Time.now
    puts "  [#{j['id']}] #{j['owner']} (#{j['name']}), ends in #{(d/3600).to_i}h#{(d%3600/60).to_i}m#{(d%60).to_i}s"
  end
  print "\n"
end
