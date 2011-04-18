require '/home/kameleon/lib/oarrestapi_lib'

$jobid = ""
describe OarApi do
  before :all do
  #apiuri="http://www.grenoble.grid5000.fr/oarapi"
  apiuri ="http://kameleon:kameleon@localhost/oarapi-priv"
  #Object of OarApis class
  @obj = OarApi.new(apiuri)
  @c=0 
  @jid = 0
  end

  
  #Submitting a job
  it "should submit a job successfully " do
  #infiniteloop_script.sh must contain an infinitely running job
  jhash = { 'resource' => "/nodes=1/core=1" , 'script_path' => "infiniteloop_script.sh", 'walltime' => "00:05:00" }
  begin
  @obj.submit_job(jhash)
  $jobid = @obj.jobstatus['id'].to_s
  rescue
    puts "#{$!}"
    exit
  end

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
  @jid =  value['job_id'].to_s
  end


  if  @jid == $jobid
  @c=1
  end
  
  @c.should == 1
  end 
 
#Check the queue to ensure the job is killed and is no more there in the queue after the walltime 
  it "should not contain the killed job in the queue past walltime" do
  @c=0
  sleep 350
  begin
  @obj.full_job_details
  rescue
    puts "#{$!}"
    exit
  end
  @obj.jobarray['items'].each do |value|
  if value['job_id'] == $jobid
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
