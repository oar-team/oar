require 'oarrestapi_lib'
require 'shared_examples'
APIURI="http://oar:kameleon@localhost/oarapi-priv" 

describe OarApi do
  before :all do
    @oar_server = OarApi.new(APIURI)
  end
  
  describe "Array of resources submission" do
    before(:all) do
      $resources = [
                   {'network_address' => "rtest1" , 
                    'besteffort' => "NO",
                    'cpuset' => 0 },
                   {'network_address' => "rtest1",
                    'besteffort' => "NO",
                    'cpuset' => 1 },
                   {'network_address' => "rtest2" , 
                    'besteffort' => "YES",
                    'cpuset' => 0 },
                   {'network_address' => "rtest2",
                    'besteffort' => "YES",
                    'cpuset' => 1 }
                   ]
      lambda {
        @oar_server.create_resources($resources)
      }.should_not raise_exception
    end

    #Checking the resources
    it "should return an items array " do
      @oar_server.resstatus['items'].should_not be_empty
    end
    it "should return 4 items " do
      @oar_server.resstatus['items'].length.should == 4
    end
    it "should contain ids of newly created resources" do
      @oar_server.resstatus['items'].each do |item|
        item["id"].to_i.should be_a(Fixnum)    
      end
    end
    it "should return the new resources links" do
      @oar_server.resstatus['items'].each do |item|
         @oar_server.get_link_href_from_array(item["links"],"self").should be_a(String)
      end
    end
    it "should have created resources having asked properties" do
      i=0
      @oar_server.resstatus['items'].each do |item|
        link=@oar_server.get_link_href_from_array(item["links"],"self")
        @oar_server.get_hash(link)
        #puts @oar_server.value["network_address"]
        @oar_server.value["network_address"].should == $resources[i]["network_address"]
        @oar_server.value["besteffort"].should == $resources[i]["besteffort"]
        @oar_server.value["cpuset"].to_i.should == $resources[i]["cpuset"].to_i
        i+=1
      end
    end
    it "should have created Alive resources" do
      i=0
      @oar_server.resstatus['items'].each do |item|
        link=@oar_server.get_link_href_from_array(item["links"],"self")
        @oar_server.get_hash(link)
        @oar_server.value["state"].should == "Alive"
        i+=1
      end
    end


    # Cleaning
    it "should delete the test resources" do
      @oar_server.resstatus['items'].each do |item|
        @oar_server.post(@oar_server.api,"/resources/#{item['id']}/state",{"state" => "Dead"})
        @oar_server.delete_resource(item["id"])
      end
    end
  end 

  describe "Unique resource submission" do
    before(:all) do
      $resource =  {'network_address' => "rtest" , 
                    'besteffort' => "NO",
                    'cpuset' => 1 }
      lambda {
        @oar_server.create_resources($resource)
      }.should_not raise_exception
    end

    #Checking the resources
    it "should return an items array " do
      @oar_server.resstatus['items'].should_not be_empty
    end
    it "should return 1 item " do
      @oar_server.resstatus['items'].length.should == 1
    end
    it "should contain id of newly created resource" do
      @oar_server.resstatus['items'][0]["id"].to_i.should be_a(Fixnum)    
    end
    it "should return the new resource link" do
      links=@oar_server.resstatus['items'][0]["links"]
      @oar_server.get_link_href_from_array(links,"self").should be_a(String)
    end
    it "should have created a resource having asked properties" do
      links=@oar_server.resstatus['items'][0]["links"]
      link=@oar_server.get_link_href_from_array(links,"self")
      @oar_server.get_hash(link)
      @oar_server.value["network_address"].should == $resource["network_address"]
      @oar_server.value["besteffort"].should == $resource["besteffort"]
      @oar_server.value["cpuset"].to_i.should == $resource["cpuset"].to_i
    end
    it "should have created an Alive resource" do
      links=@oar_server.resstatus['items'][0]["links"]
      link=@oar_server.get_link_href_from_array(links,"self")
      @oar_server.get_hash(link)
      @oar_server.value["state"].should == "Alive"
    end

    # Cleaning
    it "should delete the test resource" do
      id=@oar_server.resstatus['items'][0]["id"]
      @oar_server.post(@oar_server.api,"/resources/#{id}/state",{"state" => "Dead"})
      @oar_server.delete_resource(id)
    end
  end 

  describe "Error checking" do
    context "(when submitting system properties)" do
      before(:all) do
        $resources = [
                   {'network_address' => "rtest1",
                    'besteffort' => "NO",
                    'cpuset' => 1 },
                   {'network_address' => "rtest2" , 
                    'besteffort' => "YES",
                    'state' => 'Alive' }
                   ]
      end
      it "should raise an exception" do
        lambda {
            @oar_server.create_resources($resources)
        }.should raise_exception
      end
      it "should raise a 403 error" do
        begin
          @oar_server.create_resources($resources)
        rescue => e
          e.should respond_to('http_code')
          e.http_code.should == 403
        end
      end
    end

    context "(when forgetting network_address)" do
      before(:all) do
        $resources = [
                   {'besteffort' => "NO",
                    'cpuset' => 1 },
                   {'network_address' => "rtest2" , 
                    'besteffort' => "YES",
                    'state' => 'Alive' }
                   ]
      end
      it "should raise an exception" do
        lambda {
            @oar_server.create_resources($resources)
        }.should raise_exception
      end
      it "should raise a 400 error" do
        begin
          @oar_server.create_resources($resources)
        rescue => e
          e.should respond_to('http_code')
          e.http_code.should == 400
        end
      end
    end
  end

  describe "GENERATE RESOURCES: post /resources/generate" do
    before(:all) do
      @api = OarApi.new(APIURI)
      generate = {
                   'resources' => '/nodes=node{2}.test.generate/cpu={2}/core={2}',
                   'properties' => {
                                     'besteffort' => 'NO',
                                     'available_upto' => '42'
                                   }
                 }
      lambda {
        begin
          @api.value=@api.post(@api.api,"/resources/generate",generate)
        rescue => e
          if e.respond_to?('http_code')
            puts "ERROR #{e.http_code}:\n #{e.response.body}"
          else
            puts "Parse error:"
            puts e.inspect
          end
          exit 1
        end
      }.should_not raise_exception
    end
    it_should_behave_like "All list structures"
    it "should return correct resources" do
      resources=[ 
                  { 'network_address' => 'node1.test.generate', 'available_upto' => 42, 
                    'besteffort' => 'NO', 'cpu' => '1', 'cpuset' => 0, 'core' => '1' },
                  { 'network_address' => 'node1.test.generate', 'available_upto' => 42, 
                    'besteffort' => 'NO', 'cpu' => '1', 'cpuset' => 1, 'core' => '2' },
                  { 'network_address' => 'node1.test.generate', 'available_upto' => 42, 
                    'besteffort' => 'NO', 'cpu' => '2', 'cpuset' => 2, 'core' => '3' },
                  { 'network_address' => 'node1.test.generate', 'available_upto' => 42, 
                    'besteffort' => 'NO', 'cpu' => '2', 'cpuset' => 3, 'core' => '4' },
                  { 'network_address' => 'node2.test.generate', 'available_upto' => 42, 
                    'besteffort' => 'NO', 'cpu' => '3', 'cpuset' => 0, 'core' => '5' },
                  { 'network_address' => 'node2.test.generate', 'available_upto' => 42, 
                    'besteffort' => 'NO', 'cpu' => '3', 'cpuset' => 1, 'core' => '6' },
                  { 'network_address' => 'node2.test.generate', 'available_upto' => 42, 
                    'besteffort' => 'NO', 'cpu' => '4', 'cpuset' => 2, 'core' => '7' },
                  { 'network_address' => 'node2.test.generate', 'available_upto' => 42, 
                    'besteffort' => 'NO', 'cpu' => '4', 'cpuset' => 3, 'core' => '8' }
                ]
      i=0
      @api.value["items"].each do |resource|
        resource.should == resources[i]
        i+=1
      end
    end

    context "(when injecting results into POST /resources)" do
      before(:all) do
        lambda {
          @api.create_resources(@api.value["items"])
        }.should_not raise_exception
      end
      it "should have created the resources (should return 8 items) " do
        @api.resstatus['items'].length.should == 8
      end
      # Cleaning
      it "should delete the test resources" do
        @api.resstatus['items'].each do |item|
          @api.post(@api.api,"/resources/#{item['id']}/state",{"state" => "Dead"})
          @api.delete_resource(item["id"])
        end
      end
    end
  end

  describe "GENERATE RESOURCES: post /resources/generate with auto_offset" do
    before(:all) do
      @api = OarApi.new(APIURI)
      generate = {'resources' => '/nodes=node{3}.test.generate/cpu={2}',
                  'auto_offset' => 1 }
      lambda {
        begin
          @api.value=@api.post(@api.api,"/resources/generate",generate)
        rescue => e
          if e.respond_to?('http_code')
            puts "ERROR #{e.http_code}:\n #{e.response.body}"
          else
            puts "Parse error:"
            puts e.inspect
          end
          exit 1
        end
      }.should_not raise_exception
    end
    it_should_behave_like "All list structures"
    it "should return resources with cpu number > 4" do
      @api.value["items"][0]["cpu"].to_i.should > 4
    end
  end 

end
