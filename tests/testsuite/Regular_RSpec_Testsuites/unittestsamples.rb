require 'oarrestapi_lib'


#Global Constant variable
APIURI="http://www.grenoble.grid5000.fr/oarapi"

describe OarApis do

  #SetUp Method
  before :each do 
  @obj = OarApis.new(APIURI) #Object of OarApis class
  @flag = 0  
  end

###########################################################################
#
# Test Method 01: Testing the GET /version REST API
#
# Result:Returning hash must be error-free & contain correct values for keys
#
###########################################################################


 it "should return the OAR Version Details Successfully through GET /version REST API" do
   begin
    @obj.oar_version
   rescue
    puts "#{$!}"
    exit
   end
    @obj.oarv['oar'].should == "2.4.1 (Thriller)" 
    @obj.oarv['apilib'].should == "0.2.10"
    @obj.oarv['api'].should == "0.2.8"
   end


###########################################################################
#
# Test Method 02: Testing the GET /timezone REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


 it "should return the correct OAR Timezone of the OAR Server" do
 begin
    @obj.oar_timezone
   rescue
    puts "#{$!}"
    exit
   end
 @obj.oart['timezone'].should == "CEST"
 end


###########################################################################
#
# Test Method 03: Testing the GET /jobs/details REST API
#
# Result: The returning array must must be error-free & contain appropriate values for the keys
#
###########################################################################

  
 it "should check the correct functioning of GET /job/details API" do
 begin
    @obj.full_job_details
 rescue
    puts "#{$!}"
    exit
   end
 # Fill in other tests cases...
 $!.should == nil
 end


###########################################################################
#
# Test Method 04: Testing the GET /jobs REST API
#
# Result:Returning array must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of GET /jobs API" do
 begin
    @obj.run_job_details
 rescue
    puts "#{$!}"
    exit
   end
 # Fill in other tests cases...
 $!.should == nil
 end


###########################################################################
#
# Test Method 05: Testing the GET /jobs/<ID> REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of GET /jobs/<ID> API" do
 begin
    jobid = 1002202 ##Sample
    @obj.specific_job_details(jobid) #How to obtain <ID>?
 rescue
    puts "#{$!}"
    exit
   end
 # Fill in other tests cases...
 $!.should == nil
 end


###########################################################################
#
# Test Method 06: Testing the GET /jobs/table REST API
#
# Result:Returning array must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of GET /jobs/table API" do
 begin
    @obj.dump_job_table
 rescue
    puts "#{$!}"
    exit
   end
 # Fill in other tests cases...
 $!.should == nil
 end


###########################################################################
#
# Test Method 07: Testing the POST /jobs REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of POST /jobs API" do
 begin
    jhash = {}
    @obj.submit_job(jhash) #Create a sample jhash
 rescue
    puts "#{$!}"
    exit
   end
 # Fill in other tests cases...
 $!.should == nil
 end


###########################################################################
#
# Test Method 08: Testing the POST /jobs/id/deletions/new REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of POST /jobs/id/deletions/new" do
 begin
    jobid = 1002201 ##Sample
    @obj.del_job(jobid) #How to get a jobid?
 rescue
    puts "#{$!}"
    exit
   end
 # Fill in other tests cases...
 $!.should == nil
 end


###########################################################################
#
# Test Method 09: Testing the POST /jobs/<jobid>/checkpoints/new REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of POST /jobs/<jobid>/checkpoints/new" do
 begin
    jobid = 1002200 ##Sample
    @obj.send_checkpoint(jobid) 
 rescue
    puts "#{$!}"
    exit
   end
 # Fill in other tests cases...
 $!.should == nil
 end



###########################################################################
#
# Test Method 10: Testing the POST /jobs/<jobid>/holds/new REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of POST /jobs/<jobid>/holds/new" do
 begin
    jobid = 1002200 ##Sample
    @obj.hold_waiting_job(jobid) #How to get a jobid?
 rescue
    puts "#{$!}"
    exit
   end
 # Fill in other tests cases...
 $!.should == nil
 end



###########################################################################
#
# Test Method 11: Testing the POST /jobs/<id>/rholds/new REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of POST /jobs/<id>/rholds/new" do
 begin
    jobid = 1002200 ##Sample
    @obj.hold_running_job(jobid) #How to get a jobid?
 rescue
    puts "#{$!}"
    exit
 end
 # Fill in other tests cases...
 $!.should == nil
 end


###########################################################################
#
# Test Method 12: Testing the POST /jobs/<id>/resumption/new REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of POST /jobs/<id>/resumption/new" do
 begin
    jobid = 1002200 ##Sample
    @obj.resume_hold_job(jobid) #How to get a jobid?
 rescue
    puts "#{$!}"
    exit
 end
 # Fill in other tests cases...
 $!.should == nil
 end



###########################################################################
#
# Test Method 13: Testing the POST /jobs/<id>/signal/<signal> REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of POST /jobs/<id>/signal/<signal>" do
 begin
    jobid = 1002200 ##Sample
    signo = 12 ##Sample signo
    @obj.send_signal_job(jobid, signo) ##How to get a jobid?  
 rescue
    puts "#{$!}"
    exit
 end
 # Fill in other tests cases...
 $!.should == nil
 end


###########################################################################
#
# Test Method 14: Testing the POST /jobs/<id>/ REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of POST /jobs/<id>" do
 begin
    jobid = 1002200 ##Sample
    actionhash = {} ##Sample actionhash
    @obj.update_job(jobid, actionhash) ##How to get a jobid?  
 rescue
    puts "#{$!}"
    exit
 end
 # Fill in other tests cases...
 $!.should == nil
 end



###########################################################################
#
# Test Method 15: Testing the GET /resources REST API
#
# Result:Returning array must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of GET /resources" do
 begin
    @obj.resource_list_state 
 rescue
    puts "#{$!}"
    exit
 end
 # Fill in other tests cases...
 $!.should == nil
 end


###########################################################################
#
# Test Method 16: Testing the GET /resources/full REST API
#
# Result:Returning array must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of GET /resources/full" do
 begin
    @obj.list_resource_details 
 rescue
    puts "#{$!}"
    exit
 end
 # Fill in other tests cases...
 $!.should == nil
 end


###########################################################################
#
# Test Method 17: Testing the GET /jobs/<id>/resources REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of GET /jobs/<id>/resources" do
 begin
    @obj.list_resource_details 
 rescue
    puts "#{$!}"
    exit
 end
 # Fill in other tests cases...
 $!.should == nil
 end


###########################################################################
#
# Test Method 18: Testing the GET /resources/nodes/<netaddr> REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of GET /resources/nodes/<netaddr>" do
 begin
    netaddr = ""
    @obj.resource_of_nodes(netaddr)  
 rescue
    puts "#{$!}"
    exit
 end
 # Fill in other tests cases...
 $!.should == nil
 end


###########################################################################
#
# Test Method 19: Testing the POST /resources REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of POST /resources" do
 begin
    rhash = {}
    @obj.create_resource(rhash)
 rescue
    puts "#{$!}"
    exit
 end
 # Fill in other tests cases...
 $!.should == nil
 end


###########################################################################
#
# Test Method 20: Testing the POST /resources/<id>/state REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of POST /resources/<id>/state" do
 begin
    hasharray = {}
    jobid = 1002200
    @obj.statechange_resource(jobid, hasharray)
 rescue
    puts "#{$!}"
    exit
 end
 # Fill in other tests cases...
 $!.should == nil
 end



  #TearDown Method
  after :each do
  @obj.kill! rescue nil
  @flag = 0
  end

end

