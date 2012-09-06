#!/usr/bin/ruby

# Simple example ruby script using the OAR RESTFUL API
# It prints a colored textmode status of the cluster

require 'rubygems'
require 'rest_client'
require 'json'
require 'pp'
require 'natural_sort'

# Custom variables
APIURI="http://mu.grenoble.grid5000.fr/oarapi"
NODENAME_REGEX="(.*)\.grenoble\.grid5000\.fr"
COLS=3

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
puts
printf ("Please, wait while querying OAR API...\n\033[1A")

# Get the resources
resources = get(api,'/resources/full')

# Get the running jobs
jobs = get(api,'jobs/details')

# Erase the waiting message
printf ("\033[2K")

# Construct a hash of used resources
used_resources={}
resource_jobs={}
jobs.each do |job|
  v=1
  if job['types'].grep(/^timesharing=\*,name$/).any?
    v=2
  end
  job['assigned_resources'].each do |r|
    resources.select{|rr| rr['resource_id']==r}.each do |rr| 
      h = rr['network_address']   
      if resource_jobs[h].nil?
        resource_jobs[h] = [job]
      else
        resource_jobs[h] << job
      end
    end
    used_resources[r]=v
  end
end

# Print summary
puts "#{jobs.length} jobs, #{resources.length} resources, #{used_resources.length} used"

# For each node
col=0
NaturalSort::naturalsort(resources.collect{|r| r['network_address']}.uniq).each do |node|
  if node!="" # some resources are not nodes (subnets)
    resources.select{|r| r['network_address']==node}.each do |resource|
      if resource['state'] == "Dead"
	printf("\033[41m\033[30mD\033[0m")
      elsif resource['state'] == "Absent"
	if resource['available_upto'].to_i > Time.new().to_i
	  printf("\033[46m \033[0m")
	else
	  printf("\033[41m\033[30mA\033[0m")
	end
      elsif resource['state'] == "Suspected"
	printf("\033[41m\033[30mS\033[0m")
      elsif resource['state'] == "Alive"
	#jobs=get(api,resource['jobs_uri'])
	#if jobs.nil?
	if used_resources[resource['resource_id']].nil?
	  printf("\033[42m \033[0m")
	elsif used_resources[resource['resource_id']] == 2
	  printf("\033[47m\033[30mT\033[0m")
        else
	  printf("\033[43m\033[30mJ\033[0m")
	end
      end
    end
    node=~/#{NODENAME_REGEX}/
    print " ",$1," \t"
    col+=1
    if col >= COLS
      col = 0
      puts
    end
  end
end
printf("\n\n\033[42m \033[0m=Free \033[46m \033[0m=Standby \033[43m\033[30mJ\033[0m=Exclusive job \033[47m\033[30mT\033[0m=Timesharing job \033[41m\033[30mS\033[0m=Suspected \033[41m\033[30mA\033[0m=Absent \033[41m\033[30mD\033[0m=Dead\n\n")

NaturalSort::naturalsort(resource_jobs).each do |k,v|
  print k,"\n"
  v.uniq.each do |j|
    print "  [",j['job_id'],"] ",j['owner']," (",j['name'],")\n"
  end
  print "\n"
end
