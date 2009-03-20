#!/usr/bin/ruby
# Example of a ruby script using restclient on the Oargrid RESTfull API.
# It first parses the grid to find 3 sites where 1 resource is free and
# then submits a job and prints the properties of the nodes obtained.
# The job is deleted at the end, as it is just an example :-)

require 'rubygems'
require 'rest_client'
require 'json'

APIURI="http://localhost/oargridapi"

# Function to get objects from the api
# We use the JSON format and the 'simple' data structure
def get(api,uri)
  begin
    return JSON.parse(api[uri+'?structure=simple'].get(:accept => 'application/json'))
  rescue => e
    puts "ERROR #{e.http_code}:\n #{e.response.body}"
    exit 1
  end
end

# Function to get the properties of a node, given a node
# and a resources array
def get_properties(resources,node)
  resources.each do |r|
    return r['properties'] if r['network_address'] == node
  end
end

# Instanciate an api connection
api = RestClient::Resource.new APIURI

# Parse the sites and find at least 3 free resources
sites = get(api,'/sites')
ok_sites=[]
sites.each do |site|
  site_name = site['site']
  resources = get(api,"/sites/#{site_name}/resources")
  resources.each do |resource|
    if resource['state'] == "Alive" && resource['jobs'].nil?
      ok_sites << site_name 
      break
    end
  end
  break if ok_sites.length >= 3
end

# If we got 3 sites, submit the job
if ok_sites.length < 3
  puts "Not enough resources found on the grid!"
  exit 1
end
j={ 'resources' => ok_sites.join(':rdef=/resource_id=1,')+':rdef=/resource_id=1' }
#j={ 'resources' => ok_sites.join(':rdef=/resource_id=1,')+':rdef=/resource_id=1' , 'verbose' => 1 }
begin
  job=JSON.parse(api['/grid/jobs'].post(j.to_json,:content_type => 'application/json'))
rescue => e
    puts "ERROR #{e.http_code}:\n #{JSON.parse(e.response.body)['message']}"
    exit 2
end

# Check the job
if job['state'] == "submitted"
  puts "GRID JOB SUCCESSFUL :-)"
  puts "-----------------------------------------------"
  puts "Id: #{job['id']}"
  puts "Waiting for resources to be allocated..."

# Wait for allocated resources
  nodes=[]
  while nodes.length < ok_sites.length do
    nodes=get(api,"/grid/jobs/#{job['id']}/resources/nodes")
    sleep(2)
  end

# Ok, print nodes
  puts "Ok, all nodes are there:"
  puts nodes.join(',')

# Fetching properties of the resources
  puts "Properties:"
  resources=get(api,"/grid/jobs/#{job['id']}/resources")
  resources.each do |r|
    site=r['site']
    # Fetching all resource properties of this site
    resources_properties=get(api,"/sites/#{site}/resources")
    r['jobs'].each_value do |j|
      j['nodes'].each do |node|
        puts node + " : "
        prop=get_properties(resources_properties,node)
        puts prop.inspect
      end
    end
  end

# Delete the job
  begin
    puts "Deleting job..."
    api["/grid/jobs/#{job['id']}.json"].delete
    puts "Job deleted"
  rescue => e
    puts "ERROR #{e.http_code} DELETING THE GRID JOB :\n #{JSON.parse(e.response.body)['message']}"
  end

# If the job has failed:
else
  puts "PROBLEM: Grid job #{job['state']}"
  puts "OUTPUT MESSAGE:"
  puts job['output']
end

