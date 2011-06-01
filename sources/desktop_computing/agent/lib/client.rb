require 'rest_client'
require 'json'
require File.join(File.dirname(__FILE__), "job.rb")
require File.join(File.dirname(__FILE__), "job_resource.rb")

class Client

  attr_accessor :remotehost, :localhost

  def initialize
    @remotehost = Configuration.instance.host
    @localhost = get_hostname
  end


  def get_jobs_to_run
    jobs = get_jobs
    jobs.each do |item|
      Job.new(item['id']).fork
    end
  end
  def get_jobs_to_kill

    response = RestClient.get "http://#@remotehost/oarapi/resources/nodes/#@localhost/jobs.json?state=toKill"
    JSON.parse(response.body)['items']
  end

  # Get a hostname from the server
  # The server will add this hostname to the resource pool
  def get_hostname
    response = RestClient.get "http://#@remotehost/oarapi/desktop/agents.json"
    JSON.parse(response.body)['hostname']
  end

  # Get the jobs for the given hostname
  def get_jobs
    response = RestClient.get "http://#@remotehost/oarapi/resources/nodes/#@localhost/jobs.json?state=toLaunch"
    JSON.parse(response.body)['items']
  end
end
