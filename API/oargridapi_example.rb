#!/usr/bin/ruby
# Example of a ruby script using restclient on the Oargrid RESTfull API.
# It first parses the grid to find 3 sites where 1 resource is free and
# then submits a job and prints the properties of the nodes obtained.
# The job is deleted at the end, as it is just an example :-)

require 'rubygems'
require 'rest_client'
require 'json'

# Custom variables
APIURI="http://www.grenoble.grid5000.fr/oargridapi"
IGNORE_SITES=['grenoble-obs','grenoble-exp','grenoble-ext','sophia','lille']
N_RESOURCES=3

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

# Function to get the properties of a node, given a node
# and a resources array
def get_properties(resources,node)
  resources.each do |r|
    return r['properties'] if r['network_address'] == node
  end
end

# Instanciate an api connection
api = RestClient::Resource.new APIURI

# Parse the sites and find at least N_RESOURCES free resources
puts "Getting sites..."
sites = get(api,'/sites')
puts "Got #{sites.length} sites"
ok_sites=[]
sites.each do |site|
  site_name = site['site']
  unless IGNORE_SITES.index(site_name) 
    puts "Checking #{site_name}..."
    resources = get(api,"/sites/#{site_name}/resources/all")
    resources.each do |resource|
      if resource['state'] == "Alive" && resource['jobs'].nil?
        ok_sites << site_name
	puts "   got 1 resource!"
        break
      end
    end
  end
  break if ok_sites.length >= N_RESOURCES
end

# If we got N_RESOURCES sites, submit the job
if ok_sites.length < N_RESOURCES
  puts "Not enough resources found on the grid!"
  exit 1
end
puts "OK, we got #{N_RESOURCES} free resources, let's submit a job..."
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
    puts "Deleting job because it was just for fun..."
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

