require 'job_client.rb'

describe JobClient, "#get_jobs" do
  context 'there is a job to be run' do

    before(:each) do
      # Once for the agent sign up and another for the job list
      RestClient.should_receive(:get).with('http://192.168.56.101/oarapi/resources/nodes/vnode1/jobs.json').and_return('{
     "api_timestamp" : 1285582177,
     "total" : 1,
     "links" : [
        {
           "rel" : "self",
           "href" : "/resources/nodes/vnodg1/jobs.json"
        }
     ],
     "offset" : 0,
     "items" : [
        {
           "api_timestamp" : 1285582177,
           "id" : 72,
           "links" : [
              {
                 "rel" : "self",
                 "href" : "/jobs/72"
              },
              {
                 "rel" : "resources",
                 "href" : "/jobs/72/resources"
              }
           ]
        }
     ]
  }')
      RestClient.should_receive(:get).with('http://192.168.56.101/oarapi/desktop/agents.json').and_return('{
     "hostname" : "vnode1"
  }')
      @client = JobClient.new('192.168.56.101')
    end
    it "should return a empty JobSet to run" do
      @client.get_jobs_to_run.should be_empty
    end
    it "should return an empty JobSet to kill" do
      @client.get_jobs_to_kill.should be_empty
    end
  end
  end
