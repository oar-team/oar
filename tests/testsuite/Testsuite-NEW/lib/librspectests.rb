require '/home/kameleon/lib/librestapi.rb' 


#Global Constant variable
#APIURI="http://www.grenoble.grid5000.fr/oarapi"

$id = 0
class Tests 

attr_accessor :jobid, :obj, :flag, :jobstatus

def initialize
@obj = OarApis.new  #Object of OarApis class
end

def headfoot(body)
header = "describe \"OarApis\" do" 
footer = "end" 
str = header+"\n"+body+"\n"+footer
File.open("tmpfile.rb", 'w') {|f| f.write(str) }
system("spec tmpfile.rb --format specdoc")
system("rm tmpfile.rb")
end


###########################################################################
#
# Test Method 01: Testing the GET /version REST API
#
# Result:Returning hash must be error-free & contain correct values for keys
#
###########################################################################


def test_get_version
 begin
  @obj.oar_version
 rescue 
  puts $!   
  exit
 end
 testelement = "it \"should return the OAR Version Details Successfully through GET /version REST API\" do
    \"#{$!}\".should == \"\" 
    \"#{@obj.oarv['oar']}\".should == \"2.5.0 (SID)\" 
    \"#{@obj.oarv['apilib']}\".should == \"0.2.10\"
    \"#{@obj.oarv['api']}\".should == \"0.2.8\"
   end" 
headfoot(testelement)
end

###########################################################################
#
# Test Method 02: Testing the GET /timezone REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################

def test_get_timezone
 begin
    @obj.oar_timezone
 rescue 
    puts $!  
    exit
 end

 testelement = "it \"should return the correct OAR Timezone of the OAR Server\" do
 \"#{$!}\".should == \"\"
 \"#{@obj.oartz['timezone']}\".should == \"UTC\"
 end"  
headfoot(testelement)
end

###########################################################################
#
# Test Method 03: Testing the GET /jobs/details REST API
#
# Result: The returning array must must be error-free & contain appropriate values for the keys
#
###########################################################################

def test_get_jobs_details
 begin
    @obj.full_job_details
 rescue
    puts $! 
    exit
 end  

testelement = "it \"should check the correct functioning of GET /job/details API\" do
 # Fill in other tests cases...
 \"#{$!}\".should == \"\"
 end" 
headfoot(testelement)
end


###########################################################################
#
# Test Method 04: Testing the GET /jobs REST API
#
# Result:Returning array must be error-free & contain appropriate values for keys
#
###########################################################################

def test_get_running_jobs
 begin
    @obj.run_job_details
 rescue
    puts $! 
    exit
 end

testelement = "it \"should check the correct functioning of GET /jobs API\" do
 # Fill in other tests cases...
 \"#{$!}\".should == \"\"
 end" 
headfoot(testelement)
end


###########################################################################
#
# Test Method 05: Testing the GET /jobs/<ID> REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################

def test_get_jobs_id(jid)
 begin
    jobid = jid
    @obj.specific_job_details(jobid) 
 rescue
    puts $!
    exit
 end  


testelement = "it \"should check the correct functioning of GET /jobs/<ID> API\" do
 # Fill in other tests cases...
 \"#{$!}\".should == \"\"
 end"
headfoot(testelement)
end


###########################################################################
#
# Test Method 06: Test to check if job is there in queue GET /jobs/details API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


def test_job_in_queue(jid)
@flag =0
 begin
    jobid = jid
    @obj.full_job_details
    @obj.jobarray.each do |jhash|
    if  jhash['job_id'] == jobid
    @flag=1
    end
    end  

 rescue
    puts $!
    exit
 end  
testelement = "it \"should contain jobid in queue of created job\" do
  \"#{@flag}\".should == \"1\"
  end "
headfoot(testelement)
end


###########################################################################
#
# Test Method 07: Test to check if job is deleted from queue using GET /jobs/details API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


def test_job_notin_queue(jid)
 @flag=0
 begin
    jobid = jid
    system("sleep 45")   # This is arbitrary as queue will be freed only based on its queue contents.. So might have to increase sleeping when queue is busy
    @obj.full_job_details
    @obj.jobarray.each do |jhash|  
    if jhash['job_id'] == jobid
    @flag=1
    end
    end
 rescue
    puts $!
    exit
  end  
testelement = "it \"should not contain the deleted job in the queue now\" do
  \"#{@flag}\".should_not == \"1\"
end "
headfoot(testelement)
end


###########################################################################
#
# Test Method 08: Testing the GET /jobs/table REST API
#
# Result:Returning array must be error-free & contain appropriate values for keys
#
###########################################################################


def test_get_jobs_table
begin
    @obj.dump_job_table
rescue
    puts $!
    exit
end 

testelement = "it \"should check the correct functioning of GET /jobs/table API\" do
  # Fill in other tests cases...
 \"#{$!}\".should == \"\"
 end"
headfoot(testelement)
end


###########################################################################
#
# Test Method 09: Testing the POST /jobs REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################

def test_submit_job (jhash)
 begin
#    jhash.each do |key,value|
#    puts key.to_s+ " => " +value.to_s
#   end
    @obj.submit_job(jhash) 
    @jobid = @obj.jobstatus['id'].to_s    
    puts @jobid.to_s
   $id = @jobid
 rescue 
    puts $!
    exit
 end
#testelement = "hi"
testelement = "it \"should check the correct functioning of POST /jobs API\" do
  \"#{$!}\".should == \"\"
  \"#{@obj.jobstatus['status']}\".to_s.should == \"submitted\" 
 end"
headfoot(testelement)
#puts testelement
end 


###########################################################################
#
# Test Method 10: Testing the POST /jobs/id/deletions/new REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


def test_jobs_delete_post (jid)
 begin
    jobid = jid
    @obj.del_job(jobid) 
 rescue
    puts $!
    exit
 end
 
testelement = "it \"should check the correct functioning of POST /jobs/id/deletions/new\" do
  \"#{$!}\".should == \"\"
  \"#{@obj.deletestatus['status']}\".should == \"Delete request registered\"
 end"
headfoot(testelement)
end 


###########################################################################
#
# Test Method 11: Testing the DELETE /jobs/<id> REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


def test_jobs_delete (jid)
 begin
    jobid = jid
    @obj.delete_job(jobid) 
 rescue
    puts $!
    exit
 end
 
testelement = "it \"should check the correct functioning of DELETE /jobs/<id>\" do
  \"#{$!}\".should == \"\"
  \"#{@obj.deletehash['status']}\".should == \"Delete request registered\"
 end"
headfoot(testelement)
end 
###########################################################################
#
# Test Method 12: Testing the GET /resources REST API
#
# Result:Returning array must be error-free & contain appropriate values for keys
#
###########################################################################


def test_get_resources
 begin
    @obj.resource_list_state 
rescue
    puts $!
    exit
end
testelement = "it \"should check the correct functioning of GET /resources\" do
 \"#{$!}\".should == \"\"
 end"
headfoot(testelement)
end


###########################################################################
#
# Test Method 13 : Testing the GET /resources/full REST API
#
# Result:Returning array must be error-free & contain appropriate values for keys
#
###########################################################################


def test_get_resources_full
 begin
    @obj.list_resource_details 
 rescue
    puts $!
    exit
 end

testelement = "it \"should check the correct functioning of GET /resources/full\" do
 # Fill in other tests cases...
 \"#{$!}\".should == \"\"
 end"
headfoot(testelement)
end 


###########################################################################
#
# Test Method 14 : Testing the POST /jobs/<id>/rholds/new REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


def test_job_rholds (jid)
 begin
    jobid = jid
    @obj.hold_running_job(jobid) 
    
 rescue
    puts $!
    exit
 end
testelement =  "it \"should check the correct functioning of POST /jobs/<id>/rholds/new\" do
 # Fill in other tests cases...
 \"#{$!}\".should == \"\"
 \"#{@obj.rholdjob['status']}\".should == \"Hold request registered\"
 end"
headfoot(testelement)
end


###########################################################################
#
# Test Method 15: Testing the POST /jobs/<jobid>/holds/new REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


def test_job_hold (jid)
begin
    jobid = jid
    @obj.hold_waiting_job(jobid)
 rescue
    puts $!
    exit
   end
testelement = "it \"should check the correct functioning of POST /jobs/<jobid>/holds/new\" do
  # Fill in other tests cases...
 \"#{$!}\".should == \"\"
 end"
headfoot(testelement)
end

###########################################################################
#
# Test Method 16: Testing the POST /jobs/<id>/resumption/new REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


def test_job_resumption (jid)
begin
    jobid = jid
    @obj.resume_hold_job(jobid) 
 rescue
    puts $!
    exit
 end
testelement = "it \"should check the correct functioning of POST /jobs/<id>/resumption/new\" do
  # Fill in other tests cases...
 \"#{$!}\".should == \"\"
 end"
headfoot(testelement)
end


###########################################################################
#
# Test Method 17: Testing POST /jobs/<id>/ API (deleting use when browsers dont support DELETE)
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


def test_job_update (jid, actionhash)
begin
     jobid = jid
     @obj.update_job(jobid, actionhash) 
 rescue
    puts $!
    exit
 end
testelement = "it \"should check the correct functioning of POST /jobs/<id>\" do
 \"#{$!}\".should == \"\"
 end"
headfoot(testelement)
end


###########################################################################
#
# Test Method 18: Testing POST /jobs/<id>/ to see if job is updated with actionhash
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
############################################################################

#Execute this method after the test_job_update method
def test_if_job_delete_updated (jid)
testelement = "it \"should check the correct functioning of POST /jobs/<id>\" do
\"#{@obj.updatehash['status']}\".should == \"Delete request registered\"
 end"
headfoot(testelement)
end


###########################################################################
#
# Test Method 19: Testing the POST /jobs/<jobid>/checkpoints/new REST API
#
# Result:Returning hash must be error-free & contain appropriate values for keys
#
###########################################################################


def test_job_checkpoint (jid)
 begin
    jobid = jid
    @obj.send_checkpoint(jid) 
 rescue
    puts $!
    exit
   end
testelement = "it \"should check the correct functioning of POST /jobs/<jobid>/checkpoints/new\" do
 \"#{$!}\".should == \"\"
\"#{@obj.updatehash['status']}\".should == \"Checkpoint request registered\"
 end"
headfoot(testelement)
end


###########################################################################
#
# Test Method 20 : Testing if job is running
#
# Result:Returning array must be error-free & contain appropriate values for keys
#
###########################################################################

def test_job_running (jid)
 begin
    @obj.specific_job_details(jid)
 rescue
    puts $! 
    exit
 end


testelement = "it \"should check if job is still running\" do
 # Fill in other tests cases...
 \"#{$!}\".should == \"\"
  \"#{@obj.specificjobdetails['status']}\".should == \"Running\"
 end" 
headfoot(testelement)
end

end

#objct = Tests.new
#jhash = {'resource' => '/nodes=1/core=1', 'script' => 'ls;sleep 100'}
#objct.test_get_version
#objct.test_get_timezone
#objct.test_get_jobs_details
#objct.test_get_running_jobs
#objct.test_submit_job(jhash)
#objct.test_job_in_queue($id)
#objct.test_jobs_delete($id)
#objct.test_job_notin_queue($id)
#objct.test_get_jobs_id(33)
#objct.test_get_jobs_table
#objct.test_jobs_delete_post(32)
#objct.test_jobs_delete(37)  #Must give last submitted jobid
#objct.test_get_resources_full
#objct.test_get_resources
