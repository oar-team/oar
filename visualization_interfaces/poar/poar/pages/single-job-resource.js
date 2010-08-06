var single_job=new Ext.Panel({
        title: 'Single Job Info',
        width: 300,
	layout:'fit',
	autoScroll:'true',
        html: '<p><i>Enter Job id to get Full information about the job.</i></p>',
        tbar: [
        'Job Id:',' ',
        new Ext.form.TextField({
        id:'single-job-id',
        name:'single-job-id'
        }),'  ',{   
            text: 'Submit',
	    pressed:'true',
            handler: function(){
		var tpl = new Ext.Template(
                    '<p>job_uid: {job_uid}</p>',
                    '<p>reservation: {reservation}</p>',
                    '<p>dependencies: {dependencies}</p>',
                    '<p>state: {state}</p>',
                    '<p>job_user: {job_user}</p>',
                    '<p>id: {id}</p>',
		    '<p>startTime: {startTime}</p>',
                    '<p>initial_request: {initial_request}</p>',
                    '<p>name: {name}</p>',
                    '<p>jobType: {jobType}</p>',
                    '<p>uri: {uri}</p>',
                    '<p>properties: {properties}</p>',
                    '<p>queue: {queue}</p>',
                    '<p>Job_Id: {Job_Id}</p>',
                    '<p>walltime: {walltime}</p>',
                    '<p>resubmit_job_id: {resubmit_job_id}</p>',
                    '<p>types: {types}</p>',
                    '<p>array_index: {array_index}</p>',
                    '<p>assigned_network_address: {assigned_network_address}</p>',
                    '<p>project: {project}</p>',
                    '<p>submissionTime: {submissionTime}</p>',
                    '<p>scheduledStart: {scheduledStart}</p>',
                    '<p>array_id: {array_id}</p>',
                    '<p>resources_uri: {resources_uri}</p>',
                    '<p>exit_code: {exit_code}</p>',
                    '<p>command: {command}</p>',
                    '<p>owner: {owner}</p>',
                    '<p>cpuset_name: {cpuset_name}</p>',
                    '<p>api_timestamp: {api_timestamp}</p>',
                    '<p>message: {message}</p>',
                    '<p>assigned_resources: {assigned_resources}</p>',
                    '<p>wanted_resources: {wanted_resources}</p>',
                    '<p>launchingDirectory: {launchingDirectory}</p>'
                    
                );  
		var sval=Ext.getCmp('single-job-id').getValue();
   		var lnk="http://localhost/oarapi-priv/jobs/"+sval+".json";
		Ext.Ajax.request({
						waitMsg: 'Submitting...',
						type:'GET',
						url: lnk,
						headers:{'Content-Type':'application/json'},
						params:{},
						success:function (result,request) {
						        tpl.overwrite(single_job.body, Ext.decode(result.responseText));
					                single_job.body.highlight('#c3daf9', {block:true});
						},

						failure: function (result,request) {
							Ext.Msg.show({
						               title:'Failure'
							      ,msg:Ext.decode(result.responseText).message
	                                                      ,modal:true
	                                                      ,icon:Ext.Msg.ERROR
	                                                      ,buttons:Ext.Msg.OK									                                                                }); 								     }
						});
            }
	}], 
        renderTo: document.body
    });


var single_resource=new Ext.Panel({
        title: 'Single resource Info',
        width: 300,
	layout:'fit',
	autoScroll:'true',
        html: '<p><i>Enter resource id to get Full information about the resource.</i></p>',
        tbar: [
        'Resource Id:',' ',
        new Ext.form.TextField({
        id:'single-resource-id',
        name:'single-resource-id'
        }),'  ',{   
            text: 'Submit',
	    pressed:'true',
            handler: function(){
		var tpl = new Ext.Template(
                    '<p>scheduler_priority: {scheduler_priority}</p>',
                    '<p>finaud_decision: {finaud_decision}</p>',
                    '<p>deploy: {deploy}</p>',
                    '<p>besteffort: {besteffort}</p>',
                    '<p>cpuset: {cpuset}</p>',
                    '<p>jobs_uri: {jobs_uri}</p>',
                    '<p>last_job_date: {last_job_date}</p>',
                    '<p>desktop_computing: {desktop_computing}</p>',
                    '<p>state: {state}</p>',
                    '<p>resource_id: {resource_id}</p>',
                    '<p>available_upto: {available_upto}</p>',
                    '<p>api_timestamp: {api_timestamp}</p>',
                    '<p>expiry_date: {expiry_date}</p>',
                    '<p>uri: {uri}</p>',
                    '<p>network_address: {network_address}</p>',
                    '<p>suspended_jobs: {suspended_jobs}</p>',
                    '<p>next_finaud_decision: {next_finaud_decision}</p>',
                    '<p>last_available_upto: {last_available_upto}</p>',
                    '<p>state_num: {state_num}</p>',
                    '<p>type: {type}</p>',
                    '<p>node_uri: {node_uri}</p>',
                    '<p>next_state: {next_state}</p>'

                );  
		var sval=Ext.getCmp('single-resource-id').getValue();
   		var lnk="http://localhost/oarapi-priv/resources/"+sval+".json";
		Ext.Ajax.request({
						waitMsg: 'Submitting...',
						type:'GET',
						url: lnk,
						headers:{'Content-Type':'application/json'},
						params:{},
						success:function (result,request) {
						        tpl.overwrite(single_resource.body, Ext.decode(result.responseText).items);
					                single_resource.body.highlight('#c3daf9', {block:true});
						},

						failure: function (result,request) {
							Ext.Msg.show({
						               title:'Failure'
							      ,msg:Ext.decode(result.responseText).message
	                                                      ,modal:true
	                                                      ,icon:Ext.Msg.ERROR
	                                                      ,buttons:Ext.Msg.OK									                                                                }); 								     }
						});
            }
	}], 
        renderTo: document.body
    });







var single_job_resource=new Ext.TabPanel({
			title:'Single Job Resource Info',
			id: 'Single-job-resource-panel',
		        renderTo: document.body,
		        activeTab: 0,
                	width:600,
		        height:250,
		        plain:true,
		        defaults:{autoScroll: true},
        items:[single_job,single_resource]
});
