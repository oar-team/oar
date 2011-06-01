require 'rest_client'

require 'job_resource.rb'


describe JobResource, "#has_stagein" do
  context "there is a stagein" do
    before :each do
     @job = JobResource.new("75")
    end
    it "should return true" do
      @job.has_stagein.should be_true
    end
  end
  context "there is no stagein" do
    before :each do
     @job = JobResource.new(74)
    end
    it "should return true" do
      @job.has_stagein.should be_false
    end
  end
end
