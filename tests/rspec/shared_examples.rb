# All data structures minimum requirements
shared_examples_for "All structures" do
      specify { @api.value.should have_key('api_timestamp') }
      specify('api_timestamp should be an integer') { @api.value['api_timestamp'].should be_a(Integer) }
      specify { @api.value.should have_key('links') }
      specify('links should be an array') { @api.value['links'].should be_an(Array) }
      specify('links should not be empty') { @api.value['links'].should_not be_empty }
      specify('self link should not be nil') { @api.get_self_link_href.should_not be_nil } 
end
shared_examples_for "All list structures" do
      it_should_behave_like "All structures"
      specify { @api.value.should have_key('items') }
      specify('items should be an array') { @api.value['items'].should be_an(Array) }
      specify { @api.value['items'].should_not be_empty }
      specify { @api.value.should have_key('total') }
      specify('total should be an integer') { @api.value['total'].should be_a(Integer) }
      specify('total should be positive') { @api.value['total'].to_i.should > 0}
      specify { @api.value.should have_key('offset') }
      specify('offset should be an integer') { @api.value['offset'].should be_a(Integer) }
end

# Item structure minimum requirements
shared_examples_for "Item" do
      it_should_behave_like "All structures"
      specify { @api.value.should have_key('id') }
      specify('id should be an integer') { @api.value['id'].should be_a(Integer) }
      specify('should have a self link') { @api.get_self_link_href.should be_a(String) }
end

# Job structure minimum requirements
shared_examples_for "JobId" do
      it_should_behave_like "Item"
      specify('self link should be correct') { 
           @api.get_self_link_href.should == "/oarapi-priv/jobs/#{@api.value['id']}"
      }
end 
shared_examples_for "Job" do
      it_should_behave_like "JobId"
      specify { @api.value.should have_key('owner') }
      specify('job owner should not be nil') { @api.value['owner'].should_not be_nil }
      specify { @api.value.should have_key('state') }
      specify('job state should not be nil') { @api.value['state'].should_not be_nil }
      specify { @api.value.should have_key('queue') }
      specify('job queue should not be nil') { @api.value['queue'].should_not be_nil }
      specify { @api.value.should have_key('name') }
      specify('resources link should not be nil') { @api.get_link_href('resources').should_not be_nil } 
      specify('resources link should be correct') { 
           @api.get_link_href('resources').should == "/oarapi-priv/jobs/#{@api.value['id']}/resources"
      }
      specify('array_id should be an integer') {
        if not @api.value['array_id'].nil?
          @api.value['array_id'].should be_a(Integer)
        end
      }
      specify('start_time should be an integer') {
        if not @api.value['start_time'].nil?
          @api.value['start_time'].should be_a(Integer)
        end
      }
      specify('exit_code should be an integer') {
        if not @api.value['exit_code'].nil?
          @api.value['exit_code'].should be_a(Integer)
        end
      }
end

# Resource structure minimum requirements
shared_examples_for "ResourceId" do
      it_should_behave_like "Item"
      specify('self link should be correct') { 
           @api.get_self_link_href.should == "/oarapi-priv/resources/#{@api.value['id']}"
      }
      specify('available_upto should be an integer') { 
        if not @api.value['available_upto'].nil?
          @api.value['available_upto'].should be_a(Integer) 
        end
      }
end

shared_examples_for "Resource" do
      it_should_behave_like "ResourceId"
      specify { @api.value.should have_key('state') }
      specify('resource state should not be nil') { @api.value['state'].should_not be_nil }
      specify { @api.value.should have_key('network_address') }
      specify { @api.value.should have_key('available_upto') }
      specify('node link should not be nil') { @api.get_link_href('node').should_not be_nil } 
      specify('jobs link should not be nil') { @api.get_link_href('jobs').should_not be_nil } 
end

# Node structure minimum requirements
shared_examples_for "Node" do
      it_should_behave_like "All structures"
      specify('should have a self link') { @api.get_self_link_href.should be_a(String) }
      specify('self link should be correct') { 
           @api.get_self_link_href.should == "/oarapi-priv/resources/nodes/#{@api.value['network_address']}"
      }
      specify { @api.value.should have_key('network_address') }
end

