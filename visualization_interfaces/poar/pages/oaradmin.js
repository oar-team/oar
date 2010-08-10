var admission_rules_store = new Ext.data.JsonStore({
   root:'',
   idProperty:'id',
   remoteSort: true,
    fields: [
    {name: 'id', type: 'string'},
    {name: 'rules', type: 'string'}
  ],  
 proxy : new Ext.data.HttpProxy({
     url: 'http://localhost/oarapi-priv/admission_rules.json',
    method: 'GET'
  })    
    }); 
admission_rules_store.load();

var show_admission_rules=new Ext.Panel({
        title: 'Get Admission rule info',
        width: 300,
	layout:'fit',
	autoScroll:'true',
        html: '<p><i>Enter admission rule id to get Full information about the rule.</i></p>',
        tbar: [
        'admissoin rule Id:',' ',
	new Ext.form.ComboBox({
	id:'admission-rule-id',
        name:'admissoin-rule-id',
        store: admission_rules_store,
        displayField:'id',
        typeAhead: true,
        mode: 'local',
        forceSelection: true,
        triggerAction: 'all',
        emptyText:'Select or type and id...',
        selectOnFocus:true
    	})

	,'  ',{   
            text: 'Submit',
	    pressed:'true',
            handler: function(){
		var tpl = new Ext.Template(
                    '<p><b>admission rule id:</b> &nbsp;&nbsp;{id}</p>',
                    '<p><b>admission rule:</b> &nbsp;&nbsp; {rule}</p>'
                    
                );

		
		var sval=Ext.getCmp('admission-rule-id').getValue();
   		var lnk="http://localhost/oarapi-priv/admission_rules/"+sval+".json";
		Ext.Ajax.request({
						waitMsg: 'Submitting...',
						type:'GET',
						url: lnk,
						headers:{'Content-Type':'application/json'},
						params:{},
						success:function (result,request) {
						        tpl.overwrite(show_admission_rules.body, Ext.decode(result.responseText)[0]);
					                show_admission_rules.highlight('#c3daf9', {block:true});
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


var new_admission_rule=new Ext.Panel({
        title: 'Admission Rule submission',
        width: 300,
	layout:'vbox',
	autoScroll:'true',
        html: '<p><i>Submit a new admission rule.</i></p>',
        items: [

	new Ext.FormPanel({
			title: 'Admission Rule',
			labelWidth: 75,
			renderTo: document.body,
			bodyStyle:'padding:5px 5px 0',
			frame:true,
			width:400,
			plain:true,
			autoHeight:true,
			defaults:{width:230},
			items:[
				new Ext.form.TextArea({
					fieldLabel:'New Rule',
					id:'new-rule',
					name:'new-rule',
					})
			],
		buttons: [{
					text: 'Submit',
					type: 'submit',
					handler:function(){
					var djid=Ext.getCmp('new-rule').getValue();
					var lnk="http://localhost/oarapi-priv/admission_rules.json";
					var send={"method":"put","rule":djid};
					Ext.Ajax.request({
						waitMsg: 'Submitting...',
						type:'POST',
						url: lnk,
						headers:{'Content-Type':'application/json'},
						params:Ext.encode(send),
						success:function (result,request) {
							Ext.Msg.show({
								title:'Success'
								,msg:result.responseText
								,modal:true
								,icon:Ext.Msg.INFO
								,buttons:Ext.Msg.OK
								});
								admission_rules_store.load();

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
		   }
			]
	})
	
	], 
        renderTo: document.body
    });

var delete_admission_rule=new Ext.Panel({
        title: 'Delete Admission Rule',
        width: 300,
	layout:'vbox',
	autoScroll:'true',
        html: '<p><i>Delete an admission rule.</i></p>',
        items: [

	new Ext.FormPanel({
			title: 'Delete Admission Rule',
			labelWidth: 75,
			renderTo: document.body,
			bodyStyle:'padding:5px 5px 0',
			frame:true,
			width:400,
			plain:true,
			autoHeight:true,
			defaults:{width:230},
			items:[
				new Ext.form.ComboBox({
				id:'delete-rule-id',
				fieldLabel:'Rule id',
			        name:'delete-rule-id',
			        store: admission_rules_store,
			        displayField:'id',
			        typeAhead: true,
			        mode: 'local',
			        forceSelection: true,
			        triggerAction: 'all',
			        emptyText:'Select or type and id...',
			        selectOnFocus:true
			    	})

			],
		buttons: [{
					text: 'Submit',
					type: 'submit',
					handler:function(){
					var djid=Ext.getCmp('delete-rule-id').getValue();
					var lnk="http://localhost/oarapi-priv/admission_rules/"+djid+".json";
					var send={"method":"delete"};
					Ext.Ajax.request({
						waitMsg: 'Submitting...',
						type:'POST',
						url: lnk,
						headers:{'Content-Type':'application/json'},
						params:Ext.encode(send),
						success:function (result,request) {
							Ext.Msg.show({
								title:'Success'
								,msg:result.responseText
								,modal:true
								,icon:Ext.Msg.INFO
								,buttons:Ext.Msg.OK
								});
								admission_rules_store.load();

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
		   }
			]
	})
	
	], 
        renderTo: document.body
    });
var oaradmin_admission_rules=new Ext.TabPanel({
			title:'Oar-admin-admission-rules',
		        renderTo: document.body,
		        activeTab: 0,
                	width:600,
		        height:250,
		        plain:true,
		        defaults:{autoScroll: true},
        items:[show_admission_rules,new_admission_rule,delete_admission_rule]
});


var resource_generation=new Ext.Panel({
        title: 'Generate Resources',
        width: 300,
	layout:'vbox',
	autoScroll:'true',
        html: '<p><i>Genearte Resources</i></p>',
        items: [

	new Ext.FormPanel({
			title: 'Resource Specification',
			labelWidth: 75,
			renderTo: document.body,
			bodyStyle:'padding:5px 5px 0',
			frame:true,
			width:400,
			plain:true,
			autoHeight:true,
			defaults:{width:230},
			items:[
				new Ext.form.TextField({
					fieldLabel:'Resources',
					id:'oaradmin-resources',
					name:'oaradmin-resources',
					}),
				new Ext.form.TextArea({
					fieldLabel:'Properties',
					id:'resource-properties',
					name:'resource-properties',
					emptyText:'All Properties Should be Comma Separated. No Spaces. Example -->   memnode:1024,cpufreq:\'3.2\',cputype:\'xeon\''
					})

			],
		buttons: [{
					text: 'Submit',
					type: 'submit',
					handler:function(){
					var djid=Ext.getCmp('oaradmin-resources').getValue();
					var properties=Ext.getCmp('resource-properties').getValue();
					var lnk="http://localhost/oarapi-priv/resources/generate.json";
					var final_prop={};
					if(properties.length>0)
					{
					var prop=properties.split(',');
					var i=0,j=0;
					for(i=0;i<prop.length;i++)
					{
					
						var temp_prop=prop[i];
						temp_prop=temp_prop.split(':'); 
						if(temp_prop.length==2)
						final_prop[temp_prop[0]]=temp_prop[1];
						else
						final_prop[temp_prop[0]]="";
					}
					}
					var send={"resources":djid,"properties":final_prop};
					Ext.Ajax.request({
						waitMsg: 'Submitting...',
						type:'POST',
						url: lnk,
						headers:{'Content-Type':'application/json'},
						params:Ext.encode(send),
						success:function (result,request) {
							Ext.Msg.show({
								title:'Success'
								,msg:result.responseText
								,modal:true
								,icon:Ext.Msg.INFO
								,buttons:Ext.Msg.OK
								});
							},

						failure: function (result,request) {
							Ext.Msg.show({
						               title:'Failure'
							      ,msg:Ext.decode(result.responseText).message
	                                                      ,modal:true
	                                                      ,icon:Ext.Msg.ERROR
	                                                      ,buttons:Ext.Msg.OK
								});
						}
						});
					
					
					}
		   }
			]
	})
	
	], 
        renderTo: document.body
    });





var oaradmin_resources=new Ext.TabPanel({
			title:'Oar-resources',
		        renderTo: document.body,
		        activeTab: 0,
                	width:600,
		        height:250,
		        plain:true,
		        defaults:{autoScroll: true},
        items:[resource_generation]
});



var config_store = new Ext.data.JsonStore({
   root:'',
   idProperty:'id',
   remoteSort: true,
    fields: [
    {name: 'id', type: 'string'},
    {name: 'value', type: 'string'},
    {name: 'link', mapping:'links.href'}
  ],
 proxy : new Ext.data.HttpProxy({
     url: 'http://localhost/oarapi-priv/config.json',
    method: 'GET'
  })    
    });


config_store.load();
var config_grid = new Ext.grid.GridPanel({
	id:'config-grid',
        title:'Configuration Variable  Grid',
        store: config_store,
	trackMouseOver:false,
        disableSelection:true,
        loadMask: true,

    columns: [
    {header: "Variable Id", dataIndex: 'id',sortable:true,width:100},
    {header: "value", dataIndex: 'value',sortable:true,width:100}, 
    {header: "link", dataIndex: 'link',sortable:true,width:100}
    ],
	viewConfig: {
            forceFit:true,
            enableRowBody:true,
            showPreview:true,
            getRowClass : function(record, rowIndex, p, rstore){
                if(this.showPreview){
                    p.body = '<p> </p>';
                    return 'x-grid3-row-expanded';
                }
                return 'x-grid3-row-collapsed';
            }
        }

    });

var set_config_variable=new Ext.Panel({
        title: 'Set Configuration Variable',
        width: 300,
	layout:'vbox',
	autoScroll:'true',
        html: '<p><i>Set the value of Configuration Variable.</i></p>',
        items: [

	new Ext.FormPanel({
			title: 'Configuration Variable',
			labelWidth: 75,
			renderTo: document.body,
			bodyStyle:'padding:5px 5px 0',
			frame:true,
			width:400,
			plain:true,
			autoHeight:true,
			defaults:{width:230},
			items:[
				new Ext.form.TextField({
					fieldLabel:'Variable Name',
					id:'var-name',
					name:'var-name',
					}),				
				new Ext.form.TextField({
					fieldLabel:'Value',
					id:'var-val',
					name:'var-val',
					})
			],
		buttons: [{
					text: 'Submit',
					type: 'submit',
					handler:function(){
					var djid=Ext.getCmp('var-name').getValue();
					var var_val=Ext.getCmp('var-val').getValue();
					var lnk="http://localhost/oarapi-priv/config/"+djid+".json";
					var send={"value":var_val};
					Ext.Ajax.request({
						waitMsg: 'Submitting...',
						type:'POST',
						url: lnk,
						headers:{'Content-Type':'application/json'},
						params:Ext.encode(send),
						success:function (result,request) {
							Ext.Msg.show({
								title:'Success'
								,msg:result.responseText
								,modal:true
								,icon:Ext.Msg.INFO
								,buttons:Ext.Msg.OK
								});
								admission_rules_store.load();
							config_store.load();

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
		   }
			]
	})
	
	], 
        renderTo: document.body
    });






var oaradmin_configuration_variable=new Ext.TabPanel({
			title:'Oar-Configuration Variable',
		        renderTo: document.body,
		        activeTab: 0,
                	width:600,
		        height:250,
		        plain:true,
		        defaults:{autoScroll: true},
        items:[config_grid,set_config_variable]
});





var oaradmin=new Ext.TabPanel({
			title:'Oar-admin',
			id: 'oaradmin-panel',
		        renderTo: document.body,
		        activeTab: 0,
                	width:600,
		        height:250,
		        plain:true,
		        defaults:{autoScroll: true},
        items:[oaradmin_admission_rules,oaradmin_resources,oaradmin_configuration_variable]
});
