require 'oarrestapi_lib'

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
  it "should submit a job successfully " do
  jhash = { 'resource' => "/nodes=1/core=1" , 'script' => "ls;pwd;whoami;sleep 60" }
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
  $!.should == ""
  @c.should == 1
  end 

 #Checkpoint the running job
 it "should checkpoint the submitted running job successfully" do
 begin
    @obj.send_checkpoint($jobid) 
 rescue
    puts $!
    exit
   end
  $!.should == ""
  @obj.updatehash['status'].should == "Checkpoint request registered"
end

 end
