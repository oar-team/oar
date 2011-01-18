require '/home/kameleon/lib/oarrestapi_lib'

$jobid = ""
describe OarApi do
  before :all do
  # Custom variables
 # APIURI="http://www.grenoble.grid5000.fr/oarapi"
 APIURI = "http://kameleon:kameleon@localhost/oarapi-priv"


  #Object of OarApis class
  @obj = OarApi.new(APIURI)
  @c=0 
  @jid=0
  end

  
  #Submitting a job
  it "should submit a job successfully " do
  jhash = { 'resource' => "/nodes=1/core=1" , 'script' => "ls;pwd;whoami;sleep 60" }
  begin
  @obj.submit_job(jhash)
  $jobid = @obj.jobstatus['id'].to_s
  rescue
    puts "#{$!}"
    exit
  end
  $!.should == nil
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


  @obj.jobarray['items'].each do |value|
  @jid = value['job_id'].to_s
  end

  if  @jid == $jobid
  @c=1
  end
  
  $!.should ==nil
  @c.should == 1
  end 

 #Hold the submitted job 
 it "should hold the running submitted job" do
 begin
    @obj.hold_running_job($jobid) 
 rescue
    puts $!
    exit
 end
 $!.should == nil
 @obj.rholdjob['status'].should == "Hold request registered"
 end


 #Test if the held job is absent in the queue of running jobs
 it "should check if the queue of running job must not contain the holded job" do
  begin
    @obj.specific_job_details($jobid)
 rescue
    puts $! 
    exit
 end
 $!.should == nil
 @obj.specificjobdetails['status'].should_not == "Running"
end

#Resume the held job
it "should resume the holded job" do
begin
    @obj.resume_hold_job($jobid) 
 rescue
    puts $!
    exit
 end
 $!.should == nil
 @obj.resumejob['status'].should == "Resume request registered"
end

#Check if the resumed job is back in the queue of running jobs
 it "should contain the resumed job in queue of running job" do
  begin
    @obj.specific_job_details($jobid)
 rescue
    puts $! 
    exit
 end
 $!.should == nil
 @obj.specificjobdetails['status'].should == "Running" 
end

end
