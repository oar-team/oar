require '/home/nk/lib/oarrestapi_lib'

$jobid = ""
describe OarApi do
  before :all do
  # Custom variables
  APIURI="http://www.grenoble.grid5000.fr/oarapi"
 
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
 
 
  #Delete the job
 it "should delete the currently submitted job using the post api and jobid" do
  begin
  @obj.del_job($jobid)
  rescue
    puts "#{$!}"
    exit
  end
  @obj.deletestatus['status'].should == "Delete request registered"    
  end

#Check the queue to ensure the job deleted is no more there #Negative Test
  it "should not contain the deleted job in the queue now" do
  @c=0
  sleep 35
  begin
  @obj.full_job_details
  rescue
    puts "#{$!}"
    exit
  end
  @obj.jobarray.each do |jhash|
  if jhash['job_id'] == $jobid
  @c=1
  end
  end
  @c.should_not == 1
end
  

=begin after :each do
APIURI = 0
@api = nil
end
=end
end
