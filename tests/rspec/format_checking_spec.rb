# Rspec tests for OAR REST API format checking
# Please, run this test on a kameleon appliance
# If this is the first time, run it twice and do not care about the first time.

require 'oarrestapi_lib'
require 'shared_examples'
APIURI="http://kameleon:kameleon@localhost/oarapi-priv/" 

$jobid=""
$rjobid=""

# Oar API specs
describe OarApi do
  before :all do
    @api = OarApi.new(APIURI)
  end

  #############################################################
  # Tests environment initialisation
  #############################################################
 
  describe "INITIAL QUEUE" do
 
    it "should have an 'items' array " do
      @api.get_hash('jobs')
      @api.value['items'].should_not == nil
    end

    it "should submit some jobs to populate the database" do
      jhash = { 'resource' => "/nodes=1/core=1" , 'script' => "id" , 'array' => '15' }
      @api.submit_job(jhash)
      $jobid = @api.jobstatus['id']
      $jobid.should be_a(Integer)
      $jobid.should > 0
      # Now, we wait for the 15th job to be terminated
      # It is necessary for the rest of the tests to pass
      timeout=180
      t=0
      c=0
      while t<timeout and c == 0
        @api.specific_job_details($jobid+14)
        if @api.specificjobdetails["state"] == "Terminated"
          c=1
        else
          printf "."
          $stdout.flush
        end
        sleep 1
        t+=1
      end
      t.should < timeout
    end

    it "should have an empty queue before running this tests " do
      @api.value['items'].should be_empty
    end

    it "should have an array of 10 test jobs just submitted" do
      jhash = { 'resource' => "/nodes=1/core=2" , 
                'property' => "network_address like 'node%'", 
                'script' => "ls;pwd;whoami;sleep 60" , 
                'array' => '10' }
      @api.submit_job(jhash)
      $jobid = @api.jobstatus['id']
      $jobid.should be_a(Integer)
      $jobid.should > 0
      # Now, we wait for the 4th job to be running
      # It is necessary for the rest of the tests to pass
      timeout=60
      t=0
      c=0
      while t<timeout and c == 0
        @api.specific_job_details($jobid+3)
        if @api.specificjobdetails["state"] == "Running"
          c=1
        else
          printf "."
          $stdout.flush
        end
        sleep 1
        t+=1
      end
      t.should < timeout
    end

    it "should have a reservation job just submitted" do
      jhash = { 'resource' => "/nodes=1/core=1" , 'script' => "ls;pwd;whoami;sleep 60" , 'reservation' => '2037-01-01 01:00:00' }
      @api.submit_job(jhash)
      $rjobid = @api.jobstatus['id']
      $rjobid.should be_a(Integer)
      $rjobid.should > 0
    end

  end

  #############################################################
  # URIs basic structure format checking
  #############################################################

  uris=[
         "jobs","jobs/details","jobs/table",
         "jobs?state=Running,Waiting,Launching","jobs?state=Terminated&limit=10",
         "jobs?state=Running,Terminated&limit=10","jobs?from=0&to=2147483647&limit=10",
         "resources","resources/full"
       ]
  uris.each do |uri|
    describe "#{uri} basic data structure" do
      before(:all) do
        @api = OarApi.new(APIURI)
        @api.get_hash(uri)
      end
      it_should_behave_like "All list structures"
    end
  end

  #############################################################
  # Specific URI tests
  #############################################################

  describe "JOBS CHECKINGS: /jobs data structure" do
    before(:all) do
      @api = OarApi.new(APIURI)
    end
    
    context "(using state=Running,Launching,Waiting&limit=2)" do
      before(:all) do
        $uri="jobs?state=Running,Launching,Waiting&limit=2"
        @api.get_hash($uri)
      end
      it "should correctly limit the number of results" do
        @api.value['items'].length.should == 2
      end
      it "should return 2 links" do
        @api.value['links'].length.should == 2
      end
      it "should return a total of 11" do
        @api.value['total'].to_i.should == 11
      end
      it "should return an offset of 0" do
        @api.value['offset'].to_i.should == 0
      end
      it "should return a correct self link" do
        @api.get_self_link_href.should == "/oarapi-priv/jobs?state=Running%2CLaunching%2CWaiting&limit=2&offset=0"
      end
      it "should return a correct next link" do
        @api.get_next_link_href.should == "/oarapi-priv/jobs?state=Running%2CLaunching%2CWaiting&limit=2&offset=2"
      end
    end

    context "(using /jobs?state=Running&limit=2&offset=3)" do
      before(:all) do
        $uri="jobs?state=Running,Waiting,Launching&limit=2&offset=3"
        @api.get_hash($uri)
      end
      it "should correctly limit the number of results" do
        @api.value['items'].length.should == 2
      end
      it "should return 3 links" do
        @api.value['links'].length.should == 3
      end
      it "should return a total of 11" do
        @api.value['total'].to_i.should == 11
      end
      it "should return an offset of 3" do
        @api.value['offset'].to_i.should == 3
      end
      it "should return a correct self link" do
        @api.get_self_link_href.should == "/oarapi-priv/jobs?state=Running%2CWaiting%2CLaunching&limit=2&offset=3"
      end
      it "should return a correct previous link" do
        @api.get_previous_link_href.should == "/oarapi-priv/jobs?state=Running%2CWaiting%2CLaunching&limit=2&offset=1"
      end
      it "should return a correct next link" do
        @api.get_next_link_href.should == "/oarapi-priv/jobs?state=Running%2CWaiting%2CLaunching&limit=2&offset=5"
      end
    end

    context "(using same as above plus Terminated jobs)" do
      before(:all) do
        $uri="jobs?state=Running,Waiting,Launching,Terminated&limit=15"
        @api.get_hash($uri)
      end
      it "should return a total >= 20" do
        @api.value['total'].to_i.should >= 20
      end
    end

    context "(with state=Terminated)" do
      before(:all) do
        @api.get_hash("jobs?state=Terminated")
      end
      it "should return only terminated jobs" do
        @api.value['items'].each do |item|
          item['state'].should == "Terminated"
        end
      end
    end

    context "(with state=Running [note: add a sleep if test jobs are not yet running])" do
      before(:all) do
        @api.get_hash("jobs?state=Running&user=kameleon")
      end
      it "should return a few running jobs" do
        @api.value['items'].length.should > 0
      end
      it "should return only running jobs" do
        @api.value['items'].each do |item|
          item['state'].should == "Running"
        end
      end
      it "should return jobs having a correct self link" do
        links=@api.value['items'][0]['links']
        id=@api.value['items'][0]['id']
        @api.get_link_href_from_array_by_rel(links,"self").should == "/oarapi-priv/jobs/#{id}"
      end
      it "should return jobs having a correct resources link" do
        links=@api.value['items'][0]['links']
        id=@api.value['items'][0]['id']
        @api.get_link_href_from_array(links,"resources").should == "/oarapi-priv/jobs/#{id}/resources"
      end
      it "should return jobs owned by the kameleon user" do
        @api.value['items'][0]['owner'].should == "kameleon"
      end
    end

    context "(with non-existent obiwankenobi user)" do
      before(:all) do
        @api.get_hash("jobs?state=Terminated&user=obiwankenobi")
      end
      it "should return no jobs" do
        @api.value['items'].length.should == 0
      end
    end
 
    context "(inside job)" do
      before(:all) do
        @api.get_hash("jobs?state=Running")
        @api.value=@api.value['items'][0]
      end
      it_should_behave_like "Job"
    end

    context "(with limit=1)" do
      before(:all) do
        @api.get_hash("jobs?limit=1")
      end
      it_should_behave_like "All list structures"
    end

    context "(with limit=1, insider job)" do
      before(:all) do
        @api.get_hash("jobs?limit=1")
        @api.value=@api.value['items'][0]
      end
      it_should_behave_like "Job"
    end
 
  end

  describe "JOB DETAILS CHECKING: /jobs/<id> data structure" do
    context "(with normal job)" do
      before(:all) do
        @api = OarApi.new(APIURI)
        @api.get_hash("jobs/#{$jobid}")
      end
      it_should_behave_like "Job"
      it "should be owned by the kameleon user" do
        @api.value['owner'].should == "kameleon"
      end
    end
    context "(with non-existent job)" do
      before(:all) do
        @api = OarApi.new(APIURI)
      end

      it "should raise an exception" do
        lambda {
            @api.get_hash("jobs/00")
        }.should raise_exception
      end

      it "should return a 404 error" do
        begin
          @api.get_hash("jobs/00")
        rescue => e
          e.should respond_to('http_code')
          e.http_code.should == 404
        end 
      end
    end
    context "(with finished job)" do
      before(:all) do
        @api = OarApi.new(APIURI)
        @api.get_hash("jobs/1")
      end
      it_should_behave_like "Job"
    end

  end

  describe "JOB DETAILS CHECKING: /jobs/details data structure" do
    before(:all) do
      @api = OarApi.new(APIURI)
      @api.get_hash("jobs/details")
    end
    context "(basic structure)" do
      it_should_behave_like "All list structures"
    end
    context "(insider job)" do
      before(:all) do
        @api.value=@api.value["items"][0]
      end
      it_should_behave_like "Job"
      it "should have resources and nodes details" do
        @api.value['resources'].should be_an(Array) 
        @api.value['nodes'].should be_an(Array)
      end
      context "should have resources behaving correctly" do
        before(:all) do
          @api.value=@api.value['resources'][0]
        end
        it_should_behave_like "ResourceId"
      end
      context "should have nodes behaving correctly" do
        before(:all) do
          @api.value=@api.value['nodes'][0]
        end
        it_should_behave_like "Node"
        it "should have a status" do
          @api.value.should have_key('status')
        end
      end
    end
  end

  describe "JOB RESOURCES: /jobs/<id>/resources" do
    before(:all) do
      @api = OarApi.new(APIURI)
      @api.get_hash("jobs/#{$jobid}/resources")
    end
    context "(basic data structure)" do
      it_should_behave_like "All list structures"
    end
    context "(inside resource)" do
      before(:all) do
        @api.value=@api.value['items'][0]
      end
      it_should_behave_like "ResourceId"
      it "should have a status field" do
        @api.value['status'].should_not be_nil
      end
      it "should have a valid status field (reserved or assigned)" do
        @api.value['status'].should match(/(reserved|assigned)/)
      end
    end
  end

  describe "JOB NODES: /jobs/<id>/nodes" do
    before(:all) do
      @api = OarApi.new(APIURI)
      @api.get_hash("jobs/#{$jobid}/nodes")
    end
    context "(basic data structure)" do
      it_should_behave_like "All list structures"
    end
    context "(inside node)" do
      before(:all) do
        @api.value=@api.value['items'][0]
      end
      it_should_behave_like "Node"
    end
  end

  describe "FUTUR JOBS CHECKING: /jobs" do
    before(:all) do
      @api = OarApi.new(APIURI)
    end
    context "(from 2036 to 2038)" do
      before(:all) do
        from=Time.local(2036,"jan",1,1,1,1).to_i
        to=Time.local(2038,"jan",1,1,1,1).to_i
        @api.get_hash("jobs?from=#{from}&to=#{to}")
      end
      it "should return only one job" do
        @api.value["items"].length.should == 1
      end
      it "should return the previously submitted reservation" do
        @api.value["items"][0]["id"].should == $rjobid
      end
    end
  end
    
  describe "RESOURCES CHECKING: /resources" do
    before(:all) do
      @api = OarApi.new(APIURI)
    end

    context "(with limit=2)" do
      before(:all) do
        @api.get_hash("resources?limit=2")
      end
      it "should correctly limit the number of results" do
        @api.value['items'].length.should == 2
      end
      it "should return 2 links" do
        @api.value['links'].length.should == 2
      end
      it "should return a total > 4" do
        @api.value['total'].to_i.should > 4
      end
      it "should return an offset of 0" do
        @api.value['offset'].to_i.should == 0
      end
      it "should return a correct self link" do
        @api.get_self_link_href.should == "/oarapi-priv/resources?limit=2&offset=0"
      end
      it "should return a correct next link" do
        @api.get_next_link_href.should == "/oarapi-priv/resources?limit=2&offset=2"
      end
    end

    context "(with limit=2&offset=2)" do
      before(:all) do
        @api.get_hash("resources?limit=2&offset=2")
      end
      it "should correctly limit the number of results" do
        @api.value['items'].length.should == 2
      end
      it "should return 3 links" do
        @api.value['links'].length.should == 3
      end
      it "should return a total > 4" do
        @api.value['total'].to_i.should > 4
      end
      it "should return an offset of 2" do
        @api.value['offset'].to_i.should == 2
      end
      it "should return a correct self link" do
        @api.get_self_link_href.should == "/oarapi-priv/resources?limit=2&offset=2"
      end
      it "should return a correct next link" do
        @api.get_next_link_href.should == "/oarapi-priv/resources?limit=2&offset=4"
      end
      it "should return a correct previous link" do
        @api.get_previous_link_href.should == "/oarapi-priv/resources?limit=2&offset=0"
      end
    end
    
    context "(inside resource)" do
      before(:all) do
        @api.get_hash("resources?limit=2&offset=1")
        @api.value=@api.value['items'][0]
      end
      it_should_behave_like "Resource"
    end

    context "(with limit=1)" do
      before(:all) do
        @api.get_hash("resources?limit=1")
      end
      it_should_behave_like "All list structures"
    end

    context "(with limit=1, insider job)" do
      before(:all) do
        @api.get_hash("resources?limit=1")
        @api.value=@api.value['items'][0]
      end
      it_should_behave_like "Resource"
    end
  end

  describe "RESOURCES DETAILS CHECKING: /resources/3 data structure" do
    before(:all) do
      @api = OarApi.new(APIURI)
      @api.get_hash("resources/3")
    end
    it_should_behave_like "Resource"
  end

  describe "NON-EXISTENT RESOURCE" do
    before(:all) do
      @api = OarApi.new(APIURI)
    end
    it "should raise an exception" do
      lambda {
          @api.get(@api.api,"resources/00")
      }.should raise_exception
    end

    it "should return a 404 error" do
      begin
        @api.get(@api.api,"resources/00")
      rescue => e
        e.should respond_to('http_code')
        e.http_code.should == 404
      end 
    end
  end

  describe "NODE RESOURCES: /resources/nodes/<node>" do
    before(:all) do
      @api = OarApi.new(APIURI)
      @api.get_hash("resources?limit=1")
      node_link=@api.get_link_href_from_array(@api.value["items"][0]["links"],"node")
      @api.get_hash(node_link)
    end
    context "(basic data structure)" do
      it_should_behave_like "All list structures"
    end
    context "(insider resource)" do
      before(:all) do
        @api.value=@api.value['items'][0]
      end
      it_should_behave_like "ResourceId"
    end
  end

  describe "RESOURCES JOBS: /resources/3/jobs" do
    before(:all) do
      @api = OarApi.new(APIURI)
      @api.get_hash("resources/3/jobs")
    end
    context "(basic data structure)" do
      it_should_behave_like "All list structures"
    end
    context "(inside job)" do
      before(:all) do
        @api.value=@api.value['items'][0]
      end
      it_should_behave_like "JobId"
    end
  end   

  describe "NODE JOBS: /resources/nodes/<node>/jobs" do
    before(:all) do
      @api = OarApi.new(APIURI)
      @api.get_hash("resources?limit=1")
      node_link=@api.get_link_href_from_array(@api.value["items"][0]["links"],"node")
      @api.get_hash(node_link+"/jobs")
    end
    context "(basic data structure)" do
      it_should_behave_like "All list structures"
    end
    context "(inside job)" do
      before(:all) do
        @api.value=@api.value['items'][0]
      end
      it_should_behave_like "JobId"
    end
  end   

  describe "NODE JOBS: /resources/nodes/<node>/jobs with state=Running filter" do
    before(:all) do
      @api = OarApi.new(APIURI)
      @api.get_hash("resources?limit=1")
      node_link=@api.get_link_href_from_array(@api.value["items"][0]["links"],"node")
      @api.get_hash(node_link+"/jobs?state=Running")
    end
    context "(basic data structure)" do
      it_should_behave_like "All list structures"
    end
    context "(inside job)" do
      before(:all) do
        @api.value=@api.value['items'][0]
      end
      it_should_behave_like "JobId"
    end
  end   

  describe "NODE JOBS: /resources/nodes/<node>/jobs with state=Obiwan filter" do
    before(:all) do
      @api = OarApi.new(APIURI)
      @api.get_hash("resources?limit=1")
      node_link=@api.get_link_href_from_array(@api.value["items"][0]["links"],"node")
      @api.get_hash(node_link+"/jobs?state=Obiwan")
    end
    it "should return an empty list of jobs" do
      @api.value=@api.value['items'].length.should==0
    end
  end   

  #############################################################
  # Job submission responses checks
  #############################################################
  describe "Job submission" do
    it "should return a self link" do
      jhash = { 'resource' => "/nodes=1/core=1" , 'script' => "ls;pwd;whoami;sleep 60"}
      @api.submit_job(jhash)
      $ljobid = @api.jobstatus['id']
      @api.value= @api.jobstatus
      @api.get_self_link_href.should == "/oarapi-priv/jobs/#{$ljobid}"
    end
    it "should return a 400 error on bad reservation date" do
      jhash = { 'resource' => "/nodes=1/core=1" , 'script' => "ls;pwd;whoami;sleep 60",
                'reservation' => '1973-06-03 18:00:00' }
      begin
        @api.submit_job(jhash)
      rescue => e
        #puts e.response.body
        e.should respond_to('http_code')
        e.http_code.should == 400
      end
    end
  end

  #############################################################
  # Cleaning
  #############################################################

  describe "Cleaning queue" do
    it "should delete the test jobs" do
      @api.del_array_job($jobid)
      @api.deletestatus['status'].should == "Delete request registered"
    end
    it "should delete the test reservation" do
      @api.del_array_job($rjobid)
      @api.deletestatus['status'].should == "Delete request registered"
    end
    it "should delete the test job" do
      @api.del_array_job($ljobid)
      @api.deletestatus['status'].should == "Delete request registered"
    end
  end

  #############################################################
  # Resubmission
  #############################################################
  describe "Re-submission of a terminated job" do
    before(:all) do
      # Wait for the 2nd job to be terminated
      timeout=180
      t=0
      c=0
      while t<timeout and c == 0
        @api.specific_job_details($jobid+1)
        if @api.specificjobdetails["state"] == "Terminated" || @api.specificjobdetails["state"] == "Error"
          c=1
        else
          printf "."
          $stdout.flush
        end
        sleep 1
        t+=1
      end
      t.should < timeout
      begin
        @api.value=@api.post(@api.api,"jobs/#{$jobid+1}/resubmissions/new",nil)
      rescue => e
        puts e.response.body
      end
    end
    it "should have a self link" do
      @api.get_self_link_href.should == "/oarapi-priv/jobs/#{@api.value['id']}"
    end
    it "should have a parent link" do
      @api.get_link_href_by_rel('parent').should == "/oarapi-priv/jobs/#{$jobid+1}"
    end
    it "should delete the test job (cleaning)" do
      @api.del_job(@api.value['id'])
      @api.deletestatus['status'].should == "Delete request registered"
    end
  end

end

