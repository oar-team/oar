require 'oarrestapi_lib'

When /^I submit a "([^"]*)" command job$/ do |command|

  APIURI="http://kameleon:kameleon@192.168.56.101/oarapi-priv" 
  @oar_server = OarApi.new(APIURI)
  job = { 'resource' => "/nodes=1/core=1" , 'script' => command }

  @oar_server.submit_job(job)
end

Then /^the job status should be "([^"]*)"$/ do |status|
  @oar_server.jobstatus['status'].to_s.should == status 
end

Then /^the job list should not be empty$/ do
  @oar_server.jobarray['items'].should_not be_empty
end

