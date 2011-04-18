require 'job.rb'
require 'client.rb'

describe Job, "#new" do
  it "should create a new job instance" do
    @job = Job.new("72")
    @job.should_not be_nil
    @job.should be_instance_of(Job)
  end
  it "should get the job details from the server" do
    RestClient.should_receive(:get).and_return('{
   "job_uid" : null,
   "reservation" : "None",
   "dependencies" : [],
   "state" : "toLaunch",
   "job_user" : "kameleon",
   "id" : 72,
   "startTime" : "1285579830",
   "links" : [
      {
         "rel" : "self",
         "href" : "/jobs/72"
      },
      {
         "rel" : "resources",
         "href" : "/jobs/72/resources"
      }
   ],
   "initial_request" : "oarsub -t desktop_computing date",
   "name" : null,
   "jobType" : "PASSIVE",
   "properties" : "desktop_computing = \'YES\'",
   "queue" : "default",
   "Job_Id" : 72,
   "walltime" : "7200",
   "resubmit_job_id" : 0,
   "types" : [
      "desktop_computing"
   ],
   "array_index" : 1,
   "assigned_network_address" : [
      "vnodg1"
   ],
   "project" : "default",
   "submissionTime" : "1285579829",
   "scheduledStart" : "1285579830",
   "array_id" : 72,
   "wanted_resources" : "-l \"{type = \'default\'}/resource_id=1,walltime=2:0:0\" ",
   "exit_code" : null,
   "command" : "date",
   "owner" : "kameleon",
   "cpuset_name" : "kameleon_72",
   "api_timestamp" : 1285586457,
   "message" : "FIFO scheduling OK",
   "assigned_resources" : [
      "38"
   ],
   "events" : [],
   "launchingDirectory" : "/root"
}
')
    @job = Job.new("72")
  end
end

describe Job, "#run" do
  context "there is no stagein file" do
    before :each do
      @job_resource = double(RestClient::Resource).as_null_object
      @job_resource.stub!(:has_stagein).and_return(false)
      RestClient::Resource.stub!(:new).and_return(@job_resource)
      @job = Job.new("1")
    end
    it "should not get the stagein" do
      @job_resource.should_not_receive(:get_stagein)
      @job.run
    end
    it "should not signalize error" do
      @job_resource.should_not_receive(:error)
      @job.run
    end
    it "should not raise exceptions" do
      lambda { @job.run }.should_not raise_exception
    end
  end
end
