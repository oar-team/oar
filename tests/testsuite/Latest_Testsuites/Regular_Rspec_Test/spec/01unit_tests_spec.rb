require '/home/kameleon/lib/oarrestapi_lib'

describe OarApi do
  before :all do
  # Custom variables
#  APIURI="http://www.grenoble.grid5000.fr/oarapi"
  APIURI = "http://kameleon:kameleon@localhost/oarapi-priv"
 
  #Object of OarApis class
  @obj = OarApi.new(APIURI)
  @c=0 
  end

###########################################################################
#
# Test Method 01: Testing the GET /version REST API
#
# Result:Returning hash must be error-free & contain correct values for keys
#
###########################################################################

 it "should return OAR Version Details Successfully - GET /version REST API" do
   begin
    @obj.oar_version
   rescue
    puts "#{$!}"
    exit
   end
    @obj.oarv['oar'].should == "2.5.0 (SID)" 
    @obj.oarv['apilib'].should == "0.2.10"
    @obj.oarv['api'].should == "0.3.0"
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
 $!.should == nil
 @obj.oartz['timezone'].should == "UTC"
 end

###########################################################################
#
# Test Method 03: Testing the POST /jobs REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


it "should check the correct functioning of POST /jobs API" do
 begin
    jhash = { 'resource' => "/nodes=1/core=1" , 'script' => "ls;pwd;whoami;sleep 60" }
    @obj.submit_job(jhash) 
 rescue
    puts "#{$!}"
    exit
   end
 
 $!.should == nil
 @obj.jobstatus['status'].to_s.should == "submitted"
# Fill in other tests cases...
 end


###########################################################################
#
# Test Method 04: Testing the GET /jobs/details REST API
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
 $!.should == nil
 # Fill in other tests cases...
 end

###########################################################################
#
# Test Method 05: Testing the GET /jobs REST API
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
 $!.should == nil
 # Fill in other tests cases...
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
 $!.should == nil
 # Fill in other tests cases...
 end


###########################################################################
#
# Test Method 07: Testing the GET /resources REST API
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
 $!.should == nil
 # Fill in other tests cases...
 end

###########################################################################
#
# Test Method 08: Testing the GET /resources/full REST API
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
$!.should == nil
# Fill in other tests cases...
 end


end
