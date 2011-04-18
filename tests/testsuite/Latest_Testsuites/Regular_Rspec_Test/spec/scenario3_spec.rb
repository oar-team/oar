require '/home/kameleon/lib/oarrestapi_lib'

$jobid = ""
describe OarApi do
  before :all do
  # Custom variables
  #APIURI="http://www.grenoble.grid5000.fr/oarapi"
  APIURI ="http://kameleon:kameleon@localhost/oarapi-priv"
 
  #Object of OarApis class
  @obj = OarApi.new(APIURI)
  @c=0 
  end

  
  #Submitting a job
  it "should submit a job successfully " do
  #Sample job submitted. Ensure job is running when it is checkpointed.
  jhash = { 'resource' => "/nodes=1/core=1" , 'script' => "ls;pwd;top;whoami;sleep 30" }
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
  $!.should == nil
  @c.should == 1
  end 

 #Checkpoint the running job
 it "should checkpoint the submitted running job successfully" do
 sleep 30
 begin
    @obj.send_checkpoint($jobid) 
 rescue
    puts $!
    exit
   end
  $!.should == nil
  @obj.chkpointstatus['status'].should == "Checkpoint request registered"
end

 end
