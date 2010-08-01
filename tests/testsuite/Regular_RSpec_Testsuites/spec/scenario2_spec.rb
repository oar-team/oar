require 'oarrestapi_lib'

#
# Scenario to test if a lengthy job submitted is still running after some time; or doesnt terminate before its expected finish time
#

$jobid = ""
describe OarApi do
  before :all do
  # Custom variables
  APIURI="http://www.grenoble.grid5000.fr/oarapi"
#APIURI="http://kameleon:kameleon@localhost/oarapi-priv"  
  #Object of OarApis class
  @obj = OarApi.new(APIURI)
  @c=0 
  end

  
  #Submitting a job
  it "should submit a job successfully that runs for 2 minutes" do
  jhash = { 'resource' => "/nodes=1/core=1" , 'script' => "ls;pwd;whoami;sleep 120" }
  begin
  @obj.submit_job(jhash)
  $jobid = @obj.jobstatus['id'].to_s
  rescue
    puts "#{$!}"
    exit
  end
  $!.should == ""
  @obj.jobstatus['status'].to_s.should == "submitted"  
  end


  #Checking the queue (Can use GET /jobs to check) immediately.
  it "should contain jobid in queue of created job" do
  begin
  @obj.full_job_details
  rescue
    puts "#{$!}"
    exit
  end
  @obj.jobarray.each do |jhash|
  if  jhash['job_id'] == $jobid
  @c=1
  end
  end  
  @c.should == 1
  $!.should == ""
  end 
 
 
 it "it should check if job is still running after 1 minute" do
   begin
    sleep 60
    @obj.specific_job_details($jobid)
 rescue
    puts $! 
    exit
 end

  $!.should == ""
  @obj.specificjobdetails['status'].should == "Running"
  end



=begin after :each do
APIURI = 0
@api = nil
end
=end
end
