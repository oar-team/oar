#require 'rubygems'
require 'rest_client'
require 'json'
require 'pp'
require 'uri'

#######################################################################
#Coded By Narayanan K - GSOC Testsuites project  - RESTful API Library
# Modified by B. Bzeznik 2010-2011
#######################################################################


class OarApi
attr_accessor :jobhash, :statushash, :specificjobdetails, :oarv, :oartz, :jobarray, :deletehash, :apiuri, :value
attr_reader :deletestatus,:jobstatus,:api,:chkpointstatus,:holdjob,:rholdjob,:signalreturn,:resumejob,:resources,:resourcedetails,:resstatus,:specificres,:noderesources
def initialize(apiuri,get_uri="")
  @api = RestClient::Resource.new apiuri
  @apiuri = URI.parse(apiuri)
end

# Converts the given uri, to something relative
# to the base of the API
def rel_uri(uri)
  abs_uri=@apiuri.merge(uri).to_s
  target_uri=URI.parse(abs_uri).to_s
  @apiuri.route_to(target_uri).to_s
end

########################################################################
#
#			 GET REST OAR API
#
# Purpose: Function to get objects from the api
#
# Result: We use the JSON format
#
########################################################################

def get(api,uri)
    uri=rel_uri(uri)
#  begin
    return JSON.parse(api[uri].get(:accept => 'application/json'))
#  rescue => e
#    if e.respond_to?('http_code')
#      puts "ERROR #{e.http_code}:\n #{e.response.body}"
#    else
#      puts "Parse error:"
#      puts e.inspect
#    end
#    exit 1
#  end
end

########################################################################
#
#			 POST REST OAR API
#
# Purpose: Function to create/delete/hold/resume objects through the api
#
# Result: We use the JSON format.
#
########################################################################

def post(api,uri,j)
    uri=rel_uri(uri)
    j=j.to_json
    return JSON.parse(api[uri].post( j,:content_type  => 'application/json'))
end

########################################################################
#
#			 DELETE REST OAR API
#
# Purpose: Function to Delete objects through the api
#
# Result: We use the JSON format.
#
########################################################################

def delete(api, uri)
 uri=rel_uri(uri)
 begin
   return JSON.parse(api[uri].delete(:content_type => 'application/json'))
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

########################################################################
#
#	     GENERIC FUNCTIONS TO GET REST OBJECTS
#
########################################################################


def get_hash(uri)
  @value = get(@api, uri)
  if !@value.is_a?(Hash)
	raise "Error: GET #{uri} should return a hash" 
  end
end

########################################################################
#
# Method: oar_version
#
# Usecase01: Gives version info & Timezone about OAR and OAR API/Server. 
#
# Input: Nil
#
# Result: GETs the Version details(hash)and stores in Hash oarv
#
########################################################################


def  oar_version
@oarv = get(@api, '/version')
if !@oarv.is_a?(Hash) or @oarv.empty?
	raise 'Error: In return value of GET /version API' 
end
end


########################################################################
#
# Method: oar_timezone
#
# Usecase02: Gives the timezone of the OAR API server.
#
# Input: Nil
#
# Result: GETs the Timezone details(hash)and stores in Hash oart
#
########################################################################


def oar_timezone
@oartz = get(@api, '/timezone')
if !@oartz.is_a?(Hash) or @oartz.empty? 
	raise 'Error: In return value of GET /timezone API' 
end
end


########################################################################
#
# Method: full_job_details
#
# Usecase03: List the current jobs & some details like assigned resources 
#
# Input: Nil
#
# Result: GETs details of current jobs(array of hashes)& stores in jobhash
#
########################################################################


def full_job_details
@jobarray = get(@api,'jobs/details')
if !@jobarray.is_a?(Hash) 
	raise 'Error: In return value of GET /jobs/details API' 
end
end


########################################################################
#
# Method: run_job_details
#
# Usecase04: List currently running jobs
#
# Input: Nil
#
# Result: GETs details of running jobs(array of hashes)& stores in jobhash
#
########################################################################


def run_job_details
@jobarray = get(@api,'jobs')
if !@jobarray.is_a?(Hash) 
	raise 'Error: In return value of GET /jobs API' 
end
end


########################################################################
#
# Method: specific_job_details(jobid)
#
# Usecase05: Get Details of a specific job
#
# Input: jobid
#
# Result: GETs details of specific job & stores in hash specificjobdetails
#
########################################################################


def specific_job_details(jobid)
@specificjobdetails = get(@api, "jobs/#{jobid}")
if !@specificjobdetails.is_a?(Hash) or @specificjobdetails.empty?
	raise 'Error: In return value of GET /jobs/<jobid> API' 
end
end


########################################################################
#
# Method: dump_job_table
#
# Usecase06: Dump the jobs table (only current jobs)
#
# Input: None
#
# Result: Dumps details of current jobs into array of hash - jobhash
#
########################################################################


def dump_job_table
@jobarray = get(@api,'jobs/table')
if !@jobarray.is_a?(Hash) 
	raise 'Error: In return value of GET /jobs/table API' 
end
end


########################################################################
#
# Method: submit_job(jhash)
#
# Usecase07: Submits job
#
# Input: jhash containing details of resources,jobscript in hash form
#
# Result: Returns the submitted job Details in Hash and stores in jobstatus
#
########################################################################


def submit_job(jhash)
@jobstatus = post(@api, 'jobs', jhash)
if !@jobstatus.is_a?(Hash) or @jobstatus.empty?
	raise 'Error: In return value of POST /jobs API' 
end
end


########################################################################
#
# Method: del_job(jobid)
#
# Usecase08: Delete job - POST /jobs/id/deletions/new
#
# Input:  jobid
#
# Result: Returns the deleted job Details in Hash and stores in deletestatus
#
########################################################################


def del_job(jobid)
@deletestatus = post(@api,"jobs/#{jobid}/deletions/new", '')
if !@deletestatus.is_a?(Hash) or @deletestatus.empty?
	raise 'Error: In return value of POST /jobs/<id>/deletions/new API' 
end
end

def del_array_job(jobid)
@deletestatus = post(@api,"jobs/array/#{jobid}/deletions/new", '')
if !@deletestatus.is_a?(Hash) or @deletestatus.empty?
	raise 'Error: In return value of POST /jobs/array/<id>/deletions/new API' 
end
end




########################################################################
#
# Method: send_checkpoint(jobid)
#
# Usecase09: Send checkpoint signal to a job
#
# Input: jobid
#
# Result: Returns details of checkpointed job in hash - chkpointstatus
#
########################################################################


def send_checkpoint(jobid)
@chkpointstatus = post(@api,"jobs/#{jobid}/checkpoints/new", '')
if !@chkpointstatus.is_a?(Hash) or @chkpointstatus.empty?
	raise 'Error: In return value of POST /jobs/<id>/checkpoints/new API' 
end
end


########################################################################
#
# Method: hold_waiting_job(jobid)
#
# Usecase10: Hold a Waiting job
#
# Input: jobid
#
# Result: Returns details of holded job in hash - holdjob
#
########################################################################


def hold_waiting_job(jobid)
@holdjob = post(@api,"jobs/#{jobid}/holds/new", '')
if !@holdjob.is_a?(Hash) or @holdjob.empty?
	raise 'Error: In return value of POST /jobs/<id>/holds/new API' 
end
end


########################################################################
#
# Method: hold_running_job(jobid)
#
# Usecase11: Hold a Running job
#
# Input: jobid
#
# Result: Returns details of holded job in hash - rholdjob
#
########################################################################


def hold_running_job(jobid)
@rholdjob = post(@api,"jobs/#{jobid}/rholds/new", '')
if !@rholdjob.is_a?(Hash) or @rholdjob.empty?
	raise 'Error: In return value of POST /jobs/<id>/rholds/new API' 
end
end


########################################################################
#
# Method: resume_hold_job(jobid)
#
# Usecase12: Resume a Holded job
#
# Input: jobid
#
# Result: Returns details of resumed job in hash - resumejob
#
########################################################################


def resume_hold_job(jobid)
@resumejob = post(@api,"jobs/#{jobid}/resumption/new", '')
if !@resumejob.is_a?(Hash) or @resumejob.empty?
	raise 'Error: In return value of POST /jobs/<id>/resumption/new API' 
end
end


########################################################################
#
# Method: send_signal_job(jobid, signo)
#
# Usecase13: Send signal to a job with signalno.
#
# Input: jobid, signal number
#
# Result: Returns details of signalled job in hash - signalreturn
#
########################################################################


def send_signal_job(jobid, signo)
@signalreturn = post(@api,"jobs/#{jobid}/signal/#{signo}", '')
if !@signalreturn.is_a?(Hash) or @signalreturn.empty?
	raise 'Error: In return value of POST /jobs/<id>/signal/<signal> API' 
end
end


########################################################################
#
# Method: update_job(jobid, actionhash)
#
# Usecase14: Update a job
#
# Input: jobid, actionhash
#
# Result: Returns details of updated job in hash - updatehash
#
########################################################################


def update_job(jobid, actionhash)
@updatehash = post(@api, "jobs/#{jobid}",actionhash)
if !@updatehash.is_a?(Hash) or @updatehash.empty?
	raise 'Error: In return value of POST /jobs/<id>/ API' 
end
end


########################################################################
#
# Method: resource_list_state 
#
# Usecase15: Get list of Resources and state
#
# Input: None
#
# Result: Returns details of resources & states in array of hashes - resources
#
########################################################################


def resource_list_state   	
@resources = get(@api, 'resources')
if !@resources.is_a?(Hash)
	raise 'Error: In return value of GET /resources API' 
end
end


########################################################################
#
# Method: list_resource_details
#
# Usecase16: Get list of all the resources and all their details
#
# Input: None
#
# Result: Returns details of resource list in array of hashes - resourcedetails
#
########################################################################


def list_resource_details
@resourcedetails = get(@api, 'resources/full')
if !@resourcedetails.is_a?(Hash) 
	raise 'Error: In return value of GET /resources/full API' 
end
end


########################################################################
#
# Method: specific_resource_details(jobid)
#
# Usecase17: Get details of resources identified by an ID
#
# Input: jobid
#
# Result: Returns details of specific resource in array of hashes - specificres
#
########################################################################


def specific_resource_details(jobid)   	
@specificres = get(@api, "jobs/#{jobid}/resources")
if !@specificres.is_a?(Hash) or @specificres.empty?
	raise 'Error: In return value of GET /jobs/<id>/resources API' 
end
end


########################################################################
#
# Method: resource_of_nodes(netaddr)
#
# Usecase18: Get details about the resources belonging to the node identified by network address
#
# Input: netaddr
#
# Result: Returns details of resource of nodes  - noderesources
#
########################################################################


def resource_of_nodes(netaddr)
@noderesources = get(@api,"resources/nodes/#{netaddr}")
if !@noderesources.is_a?(Hash) or @noderesources.empty? 
	raise 'Error: In return value of GET /resources/nodes/<netaddr> API' 
end
end


########################################################################
# Resource creation methods
########################################################################

def create_resource(rhash)
  @resstatus = post(@api,'resources', rhash)
  if !@resstatus.is_a?(Hash) or @resstatus.empty?
	raise 'Error: In return value of POST /resources API' 
  end
end

def create_resources(array)
  @resstatus = post(@api,'resources', array)
  if !@resstatus.is_a?(Hash) or @resstatus.empty?
	raise 'Error: In return value of POST /resources API' 
  end
end

########################################################################
#
# Method: statechange_resource(jobid, hasharray)
#
# Usecase20: Change the state of resources of a job
#
# Input: jobid, hasharray
#
# Result: Returns details of created resources in hash- statushash
#
########################################################################


def statechange_resource(jobid, hasharray)
@statushash = post(@api, 'resources/#{jobid}/state', hasharray)
if !@statushash.is_a?(Hash) or @statushash.empty?
	raise 'Error: In return value of POST /resources/<id>/state API' 
end
end


########################################################################
#
# Method: delete_job(jobid)
#
# Usecase21: Delete or kill a job.
#
# Input: jobid
#
# Result: Returns details of deleted job in hash- deletehash
#
########################################################################


def delete_job(jobid)
@deletehash = delete(@api,"/jobs/#{jobid}")
if !@deletehash.is_a?(Hash) or @deletehash.empty?
	raise 'Error: In return value of DELETE /jobs/<id> API' 
end
end


########################################################################
#
# Method: delete_resource(resid)
#
# Usecase22: Delete the resource identified by id
#
# Input: resid
#
# Result: Returns details of deleted resources in hash- deletehash
#
########################################################################


def delete_resource(resid)
@deletehash = delete(@api,"resources/#{resid}")
if !@deletehash.is_a?(Hash) or @deletehash.empty?
	raise 'Error: In return value of DELETE /resources/<id> API' 
end
end


########################################################################
#
# Method: delete_resource_cpuset(node, cpuid)
#
# Usecase23: Delete the resource corresponding to cpuset id on node node.
#
# Input: node, cpuid
#
# Result: Returns details of deleted resources in hash- deletehash
#
########################################################################


def delete_resource_cpuset(node, cpuid)
@deletehash = delete(@api,"/resources/#{node}/#{cpuid}")
if !@deletehash.is_a?(Hash) or @deletehash.empty?
	raise 'Error: In return value of DELETE /resources/<node>/<cpuset id> API' 
end
end

def get_link_href(title)
  @value['links'].each do |link|
    if link.is_a?(Hash) && link['title'] == title
      return link['href']
    end
  end
  raise "#{title} link not found!"
end

def get_link_href_by_rel(rel)
  @value['links'].each do |link|
    if link.is_a?(Hash) && link['rel'] == rel
      return link['href']
    end
  end
  raise "#{rel} link not found!"
end

def get_self_link_href
  get_link_href_by_rel("self")
end

def get_next_link_href
  get_link_href_by_rel("next")
end

def get_previous_link_href
  get_link_href_by_rel("previous")
end

def get_link_href_from_array(array,title)
  array.each do |link|
    if link.is_a?(Hash) && link['title'] == title 
      return link['href']
    end
  end
  raise "#{title} link not found!"
end

def get_link_href_from_array_by_rel(array,rel)
  array.each do |link|
    if link.is_a?(Hash) && link['rel'] == rel 
      return link['href']
    end
  end
  raise "#{rel} link not found!"
end



end
