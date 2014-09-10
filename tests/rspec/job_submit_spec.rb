$LOAD_PATH << '.'

require 'oarrestapi_lib'

USER=ENV['USER']
$jobid = ""

describe OarApi do
  before :all do
    # Custom variables
    # APIURI="http://www.grenoble.grid5000.fr/oarapi"
    #Object of OarApis class
    @oar_server = OarApi.new(APIURI)
  end
  describe "Submission" do  
    #Submitting a job
    it "should submit a job successfully " do
      script="#!/bin/bash
#OAR --name rspec_test
wc -l $OAR_FILE_NODES > /tmp/$OAR_JOB_ID.count
echo \"Hello World\"
pwd
whoami
sleep 120
"
      job = { 'resource' => "/nodes=1/core=2" , 'script' => script, 'scanscript' => 1 }
      lambda {
         @oar_server.submit_job(job)
      }.should_not raise_exception

      @oar_server.jobstatus['id'].to_i.should > 0  
      $jobid=@oar_server.jobstatus['id']
    end
  end


  #Checking the queue (Can use GET /jobs to check) immediately.
  describe "Submitted job" do
    before :all do
      lambda {
        @oar_server.full_job_details
      }.should_not raise_exception
    end
    it "should have id in current queue" do
      timeout=60
      found=0
      t=0
      while found==0 && t < timeout do
        @oar_server.jobarray['items'].each do |j|
          found=1 if j["id"] == $jobid && j["state"] == "Running"
        end
        @oar_server.full_job_details
        sleep 1
        t += 1
        printf "."
        $stdout.flush
      end
      found.should==1
    end  
    it "should be named 'rspec_test'" do
      @oar_server.specific_job_details($jobid)
      @oar_server.specificjobdetails["name"].should == "rspec_test"
    end
    it "should have created a file into /tmp" do
      sleep 1
      File.exists?("/tmp/#{$jobid}.count").should == true
    end
    it "should return the good number of resources into the created file" do
      f = File.open("/tmp/#{$jobid}.count")
      f.gets.to_i.should == 2
    end
  end 
 
 
  #Delete the job
  describe "Deletion" do
    it "should delete the currently submitted job using the post api and jobid" do
      lambda {
        @oar_server.del_job($jobid)
      }.should_not raise_exception

      @oar_server.deletestatus['status'].should == "Delete request registered"    
    end

    #Check the queue to ensure the job deleted is no more there #Negative Test
    it "should not contain the deleted job in the queue now" do
      timeout=60
     
      lambda {
        @oar_server.full_job_details
      }.should_not raise_exception

      t=0
      c=1
      while t<timeout and c==1
        c=0
        @oar_server.full_job_details
        unless @oar_server.jobarray['items'].nil? 
          @oar_server.jobarray['items'].each do |value|
            printf "."
            $stdout.flush
            @jid = value['id']
            if @jid == $jobid
              c=1
            end
          end
        end
        sleep 1
        t+=1
      end
      puts "TIMEOUT!" if c==1
      puts
      c.should_not == 1
    end 
  end
end
