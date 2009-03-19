#!/usr/bin/ruby
# Example of a ruby script using restclient on the Oargrid RESTfull API.
# It first parses the grid to find 3 sites where 1 core is free and then
# submits a job and prints the properties of the nodes obtained.

require 'rubygems'
require 'rest_client'
require 'json'

APIURI="http://localhost/oargridapi"

# Function to get objects from the api
# We use the JSON format and the 'simple' data structure
def get(api,uri)
  begin
    return JSON::load(api[uri+'?structure=simple'].get(:content_type => 'application/json'))
  rescue => e
    puts "ERROR #{e.http_code}:\n #{e.response.body}"
    exit 1
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
# TODO
puts ok_sites.inspect
