require 'librestapi'

$jobid = ""
describe OarApis do
 
  before :all do
  # Custom variables
  APIURI="http://www.grenoble.grid5000.fr/oarapi"
   #Object of OarApis class
  @obj = OarApis.new(APIURI)
  end

 
  #Scenario : Submit a Job, check if the job is running after 1 minute


  #Test for Submitting a job
  it "should submit a job successfully " do
  resource = "/nodes=1/core=1"
  script = "/home/nk/test.sh"
  walltime = "1"
  jhash = { 'resource' => "#{resource}" , 'script' => "#{script}", 'walltime' => "#{walltime}" }
   begin
    @obj.submit_job(jhash) #Create a sample jhash
   rescue
    puts "#{$!}"
   exit 2
   end 
  $jobid = @obj.jobstatus['id'].to_s
  @obj.jobstatus['status'].to_s.should == "submitted"  ##Check here ok?
  end
  


 #Test if job is running after 1 minute
 it "should check if the submitted job is running after 60 seconds" do
  sleep 60
     begin
     @obj.specific_job_details($jobid)
     rescue
     puts "#{$!}"
     exit 2
    end

    @obj.specificjobdetails['state'].to_s.should == "Running"
end
end
