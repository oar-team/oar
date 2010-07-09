var welcome = {
	id: 'welcome-panel',
	title: 'Welcome Page',
	layout: 'fit',
	bodyStyle: 'padding:25px',
	contentEl: 'welcome-div'  
};



var rstore = new Ext.data.JsonStore({
   idProperty:'resource_id',
   remoteSort: true,
    fields: [
    {name: 'resource_id', type: 'string'},
    {name: 'jobs_uri', type: 'string'},
    {name: 'available_upto', type: 'string'},
    {name: 'api_timestamp', type: 'string'},
    {name: 'node_uri', type: 'string'},
    {name: 'uri', type: 'string'},
    {name: 'network_address', type: 'string'},
    {name: 'state', type: 'string'}
  ],
 proxy : new Ext.data.HttpProxy({
     url: 'http://localhost/oarapi/resources.json',
    method: 'GET'
  })    
    });


rstore.load();


var Rgrid = new Ext.grid.GridPanel({
	id:'Rgrid',
        title:'Resources Grid',
        store: rstore,
	trackMouseOver:false,
        disableSelection:true,
        loadMask: true,

    columns: [
    {header: "resource_id", dataIndex: 'resource_id',sortable:true,width:100},
    {header: "jobs_uri", dataIndex: 'jobs_uri',sortable:true,width:100}, 
    {header: "available_upto", dataIndex: 'available_upto',sortable:true,width:100},
    {header: "api_timestamp", dataIndex: 'api_timestamp',sortable:true,width:100},
    {header: "node_uri", dataIndex: 'node_uri',sortable:true,width:100},
    {header: "uri", dataIndex: 'uri',sortable:true,width:100},
    {header: "network_address", dataIndex: 'network_address',sortable:true,width:100},
    {header: "state", dataIndex: 'state',sortable:true,width:100}
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
        },

        // paging bar on the bottom
        bbar: new Ext.PagingToolbar({
            pageSize: 10,
            store: rstore,
            displayInfo: true,
            displayMsg: 'Displaying topics {0} - {1} of {2}',
            emptyMsg: "No topics to display",
            items:[
                '-', {
                pressed: true,
                enableToggle:true,
                text: 'Show Preview',
                cls: 'x-btn-text-icon details',
                toggleHandler: function(btn, pressed){
                    var view = Rgrid.getView();
                    view.showPreview = pressed;
                    view.refresh();
                }
            }]
        })


    });


var Resources = {
	id: 'Resources-panel',
	title: 'Resources',
	layout: 'fit',
	bodyStyle: 'padding:25px',
  items:[Rgrid]
};


var iframe_ganttchart = {
  id: 'iframe-ganttchart-panel',
  title: 'Gantt Chart',
  defaultType: 'iframepanel',
  items: {
    defaultSrc : 'http://localhost/cgi-bin/drawgantt.cgi'
  }
};


var iframe_monika = {
  id: 'iframe-monika-panel',
  title: 'Resources Status',
  defaultType: 'iframepanel',
  items: {
    defaultSrc : 'http://localhost/cgi-bin/monika.cgi'
  }
};


var store_job = new Ext.data.JsonStore({
  idProperty:'Job_Id',
  remoteSort:true,
  fields: [
    {name: 'owner', type: 'string'},
    {name: 'name', type: 'string'},
    {name: 'api_timestamp', type: 'string'},
    {name: 'uri', type: 'string'},
    {name: 'state', type: 'string'},
    {name: 'resources_uri', type: 'string'},
    {name: 'submission', type: 'string'},
    {name: 'id', type: 'string'},
    {name: 'queue', type: 'string'}
  ],
 proxy : new Ext.data.HttpProxy({
     url: 'http://localhost/oarapi/jobs.json',
    method: 'GET'
  }),
});

 store_job.setDefaultSort('id', 'desc');


var jobs_summary = new Ext.grid.GridPanel({
  frame:true,
  title: 'Jobs Summary',	
  id: 'jobs-summary-panel',
  trackMouseOver:false,
  disableSelection:true,
  loadMask: true,
  store: store_job,
  columns: [
    {header: "Jobs Id", dataIndex: 'id',sortable:true,width:200},
    {header: "owner", dataIndex: 'owner',sortable:true,width:200}, 
    {header: "submission", dataIndex: 'submission',sortable:true,width:200},
    {header: "name", dataIndex: 'name',sortable:true,width:200},
    {header: "uri", dataIndex: 'uri',sortable:true,width:200},
    {header: "state", dataIndex: 'state',sortable:true,width:200},
    {header: "resource_uri", dataIndex: 'resource_uri',sortable:true,width:200},
    {header: "queue", dataIndex: 'queue',sortable:true,width:200},
    {header: "api_timstamp", dataIndex: 'api_timestamp',sortable:true,width:200}

    ],

viewConfig: {
            forceFit:true,
            enableRowBody:true,
            showPreview:true,
	    getRowClass : function(record, rowIndex, p, store_job){
                if(this.showPreview){
                    p.body = '<p> </p>';
                    return 'x-grid3-row-expanded';
                }
                return 'x-grid3-row-collapsed';
            }

        },

 bbar: new Ext.PagingToolbar({
            pageSize:10,
            store: store_job,
            displayInfo: true,
            displayMsg: 'Displaying topics {0} - {1} of {2}',
            emptyMsg: "No topics to display",
            items:[
                '-', {
                pressed: true,
                enableToggle:true,
                text: 'Show Preview',
                cls: 'x-btn-text-icon details',
                toggleHandler: function(btn, pressed){
                    var view = jobs_summary.getView();
                    view.showPreview = pressed;
                    view.refresh();
                }
            }]
        })



    });




var jobs = {
title: 'Jobs List',
       id: 'jobs-panel',
       layout: 'fit',
       bodyStyle: 'padding:30px;',
       items:[jobs_summary]
	};

store_job.load({params:{start:0, limit:10}});


var hour = new Ext.data.ArrayStore({
	fields: ['Hours'],
	data : [['00'],['01'],['02'],['03'],['04'],['05'],['06'],['07'],['08'],['09'],['10'],['11'],['12'],['13'],['14'],['15'],['16'],['17'],['18'],['19'],['20'],['21'],['22'],['23']]
	});

var minute=new Ext.data.ArrayStore({
fields: ['Minutes'],
data: [['01'],['02'],['03'],['04'],['05'],['06'],['07'],['08'],['09'],['10'],['11'],['12'],['13'],['14'],['15'],['16'],['17'],['18'],['19'],['20'],['21'],['22'],['23'],['24'],['25'],['26'],['27'],['28'],['29'],['30'],['31'],['32'],['33'],['34'],['35'],['36'],['37'],['38'],['39'],['40'],['41'],['42'],['43'],['44'],['45'],['46'],['47'],['48'],['49'],['50'],['51'],['52'],['53'],['54'],['55'],['56'],['57'],['58'],['59']]
		});
var second=new Ext.data.ArrayStore({
fields: ['Seconds'],
data: [['01'],['02'],['03'],['04'],['05'],['06'],['07'],['08'],['09'],['10'],['11'],['12'],['13'],['14'],['15'],['16'],['17'],['18'],['19'],['20'],['21'],['22'],['23'],['24'],['25'],['26'],['27'],['28'],['29'],['30'],['31'],['32'],['33'],['34'],['35'],['36'],['37'],['38'],['39'],['40'],['41'],['42'],['43'],['44'],['45'],['46'],['47'],['48'],['49'],['50'],['51'],['52'],['53'],['54'],['55'],['56'],['57'],['58'],['59']]
		});


var node=new Ext.data.ArrayStore({
fields: ['nodes'],
data: [['1'],['2'],['3'],['4'],['5'],['6'],['7'],['8'],['9'],['10']]
		});
var cpu=new Ext.data.ArrayStore({
fields: ['cpus'],
data: [['1'],['2'],['3'],['4']]
		});

var order=new Ext.data.ArrayStore({
fields: ['order'],
data: [['1'],['2'],['3'],['4'],['5'],['6'],['7'],['8'],['9'],['10']]
		});


var submissionForm = new Ext.FormPanel({
	title: 'Submission Form',
	id: 'submission-form-panel',
	renderTo: document.body,
	width:600,
	height:500,
	plain:true,
	autoHeight:true,
	defaults:{autoScroll: true},
	items:[{
			xtype:'fieldset',
		        title: '-l',
		        collapsible: true,
			collapsed: true,
	                autoHeight:true,
	                defaults: {width: 210},
	                defaultType: 'textfield',
	            items :[
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:node,
			displayField:'nodes',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Node',
			name:'Node',
			id:'Node'
				}),
		new Ext.form.ComboBox({
			renderTo: document.body,
			store:cpu,
			displayField:'cpus',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			id:'Cpu',
			fieldLabel:'Cpu',
			name:'Cpu'
			}),
			new Ext.form.TextField({
				fieldLabel:'Script-Path',
				id:'lpath',
				name:'lpath',
				}),
		new Ext.form.ComboBox({
			renderTo: document.body,
			store:hour,
			displayField:'Hours',
			typeAhead: true,
			mode: 'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Hours',
			name:'lHours',
			id:'lhours'
			}),

		new Ext.form.ComboBox({
			renderTo: document.body,
			store:minute,
			displayField:'Minutes',
			typeAhead: true,
			mode: 'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Minutes',
			name:'lMinutes',
			id:'lminutes'
			}),
		new Ext.form.ComboBox({
			renderTo: document.body,
			store:second,
			displayField:'Seconds',
			typeAhead: true,
			mode: 'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,

			fieldLabel:'Seconds',
			name:'lSeconds',
			id:'lseconds'
			})
	            ]

			},

			{
			xtype:'fieldset',
		        title: '-S',
		        collapsible: true,
			collapsed: true,
	                autoHeight:true,
	                defaults: {width: 210},
	                defaultType: 'textfield',
	            items :[
			new Ext.form.TextField({
				fieldLabel:'Script-Path',
				id:'spath',
				name:'Spath'
				})
	            ]

},{
			xtype:'fieldset',
		        title: '-q',
		        collapsible: true,
			collapsed: true,
	                autoHeight:true,
	                defaults: {width: 210},
	                defaultType: 'textfield',
	            items :[
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:new Ext.data.ArrayStore({
			fields: ['type'],
			data: [['defalut']]
				})
			,displayField:'type',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'type',
			name:'queue',
			id:'queue'
				})
			
	            ]


},{
			xtype:'fieldset',
		        title: '-p',
		        collapsible: true,
			collapsed: true,
	                autoHeight:true,
	                defaults: {width: 210},
	                defaultType: 'textfield',
	            items :[
			new Ext.form.TextField({
				fieldLabel:'Script-Path',
				id:'property',
				name:'property'
				})
			
	            ]


},
{
			xtype:'fieldset',
		        title: '-r',
		        collapsible: true,
			collapsed: true,
	                autoHeight:true,
	                defaults: {width: 210},
	                defaultType: 'textfield',
	            items :[
		new Ext.form.DateField({
			fieldLabel:'Date',
			name:'Date',
			format:'Y-m-d',
			id:'rdate'
		}),
		new Ext.form.ComboBox({
			renderTo: document.body,
			store:hour,
			displayField:'Hours',
			typeAhead: true,
			mode: 'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Hours',
			name:'Hours',
			id:'rhours'
			}),

		new Ext.form.ComboBox({
			renderTo: document.body,
			store:minute,
			displayField:'Minutes',
			typeAhead: true,
			mode: 'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Minutes',
			name:'Minutes',
			id:'rminutes'
			}),
		new Ext.form.ComboBox({
			renderTo: document.body,
			store:second,
			displayField:'Seconds',
			typeAhead: true,
			mode: 'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Seconds',
			name:'Seconds',
			id:'rseconds'
			}),
			new Ext.form.TextField({
				fieldLabel:'checkpoint',
				name:'rcheck',
				id:'rcheck'
				}),
			new Ext.form.TextField({
				fieldLabel:'signal',
				name:'rsignal',
				id:'rsignal'
				})

	            ]
},{

			xtype:'fieldset',
		        title: '-t',
		        collapsible: true,
			collapsed: true,
	                autoHeight:true,
	                defaults: {width: 210},
	                defaultType: 'textfield',
	            items :[
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:new Ext.data.ArrayStore({
			fields: ['type'],
			data: [['deploy'], ['besteffort'],
                              ['cosystem'], ['checkpoint'], ['timesharing']]
				})
			,displayField:'type',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Specific Type',
			name:'ttype',
			id:'ttype'
				})
			
	            ]
},{
			xtype:'fieldset',
		        title: '-d',
		        collapsible: true,
			collapsed: true,
	                autoHeight:true,
	                defaults: {width: 210},
	                defaultType: 'textfield',
	            items :[
			new Ext.form.TextField({
				fieldLabel:'Directory-Path',
				name:'dpath',
				id:'dpath'
				}),
		    new Ext.form.TextField({
				fieldLabel:'Project Name',
				name:'dproject',
				id:'dproject'
				})
	            ]


},
{
			xtype:'fieldset',
		        title: '-n',
		        collapsible: true,
			collapsed: true,
	                autoHeight:true,
	                defaults: {width: 210},
	                defaultType: 'textfield',
	            items :[
			new Ext.form.TextField({
				fieldLabel:'Name for the Job',
				name:'nname',
				id:'nname'
				})
	            ]
},{
			xtype:'fieldset',
		        title: '-a',
		        collapsible: true,
			collapsed: true,
	                autoHeight:true,
	                defaults: {width: 210},
	                defaultType: 'textfield',
	            items :[
			new Ext.form.TextField({
				fieldLabel:'Job id',
				name:'ajid',
				id:'ajid'
				}),
			new Ext.form.TextField({
				fieldLabel:'Notify Method',
				name:'anmethod',
				id:'anmethod'
				}),
			new Ext.form.TextField({
				fieldLabel:'resubmit job id',
				name:'arsubmit',
				id:'arsubmit'
				})
	            ]
},{			
			xtype:'fieldset',
		        title: '-k',
		        collapsible: true,
			collapsed: true,
	                autoHeight:true,
	                defaults: {width: 210},
	                defaultType: 'textfield',
	            items :[
			
			new Ext.form.TextField({
				fieldLabel:'Use Job Key',
				name:'kkey',
				id:'kkey'
				})
				]


},{
			xtype:'fieldset',
		        title: '-i',
		        collapsible: true,
			collapsed: true,
	                autoHeight:true,
	                defaults: {width: 210},
	                defaultType: 'textfield',
	            items :[
			
			new Ext.form.TextField({
				fieldLabel:'Job key file Path',
				name:'kfile',
				id:'kfile'
				}),
				new Ext.form.TextField({
				fieldLabel:'Job key inline:',
				name:'kjkey',
				id:'kjkey'
				})
				]
			
	},{
			xtype:'fieldset',
		        title: '-e',
		        collapsible: true,
			collapsed: true,
	                autoHeight:true,
	                defaults: {width: 210},
	                defaultType: 'textfield',
	            items :[
			new Ext.form.TextField({
				fieldLabel:'Export Job key file Path',
				name:'ejfile',
				id:'ejfile'
				})
				]

},{
			xtype:'fieldset',
		        title: '-O',
		        collapsible: true,
			collapsed: true,
	                autoHeight:true,
	                defaults: {width: 210},
	                defaultType: 'textfield',
	            items :[
			new Ext.form.TextField({
				fieldLabel:'Standard Output file',
				name:'Ofile',
				id:'Ofile'
				})
				]
}

		],
		buttons: [{
					text: 'Submit',
					type: 'submit',
					handler:function(){
					var Node=Ext.getCmp('Node').getValue();
					var Cpu=Ext.getCmp('Cpu').getValue();
					var lpath=Ext.getCmp('lpath').getValue();
					var lhours=Ext.getCmp('lhours').getValue();
					var lminutes=Ext.getCmp('lminutes').getValue();
					var lseconds=Ext.getCmp('lseconds').getValue();
					var spath=Ext.getCmp('spath').getValue();
					var queue=Ext.getCmp('queue').getValue();
					var property=Ext.getCmp('property').getValue();
					var rdate=Ext.getCmp('rdate').getValue();
					var rhours=Ext.getCmp('rhours').getValue();
					var rminutes=Ext.getCmp('rminutes').getValue();
					var rseconds=Ext.getCmp('rseconds').getValue();
					var rcheck=Ext.getCmp('rcheck').getValue();
					var rsignal=Ext.getCmp('rsignal').getValue();
					var ttype=Ext.getCmp('ttype').getValue();
					var dpath=Ext.getCmp('dpath').getValue();
					var dproject=Ext.getCmp('dproject').getValue();
					var nname=Ext.getCmp('nname').getValue();
					var ajid=Ext.getCmp('ajid').getValue();
					var anmethod=Ext.getCmp('anmethod').getValue();
					var arsubmit=Ext.getCmp('arsubmit').getValue();
					var kkey=Ext.getCmp('kkey').getValue();
					var kfile=Ext.getCmp('kfile').getValue();
					var kjkey=Ext.getCmp('kjkey').getValue();
					var ejfile=Ext.getCmp('ejfile').getValue();
					var Ofile=Ext.getCmp('Ofile').getValue();
					var resource="";
					if(Node!="")
						resource+="/nodes="+Node;
					

					if(Cpu!="")
						resource+="/cpu="+Cpu;			
						

					if(lhours!="" &&  lminutes!="" &&  lseconds!="")
							resource+=",walltime="+lhours+":"+lminutes+":"+lseconds;

					var reservation=rdate+" "+rhours+":"+rminutes+":"+rseconds;
					if(reservation==" ::")
						reservation="";

					var send={"resource":resource,"script_path":lpath,"scanscript":spath,"queue":queue,"property":property,"reservation":reservation,"checkpoint":rcheck,"signal":rsignal,"type":ttype,"directory":dpath,"project":dproject,"name":nname,"anterior":ajid,"notify":anmethod,"resubmit":arsubmit,"use-job-key":kkey,"import-job-key-from-file":kfile,"import-job-key-inline":kjkey,"export-job-key-to-file":ejfile,"stdout":Ofile};


					//console.log(Ext.encode(send));
					Ext.Ajax.request({
						waitMsg: 'Submitting...',
						type:'POST',
						url: 'http://kameleon:kameleon@localhost/oarapi-priv/jobs',
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
	                                                      ,buttons:Ext.Msg.OK									                                                                }); 
									


								     }
						});
   				     }
					},{
					text: 'Cancel',
					type:'reset'
					}]

});


var ujob=new Ext.TabPanel({
			title:'Delete Job',
			id: 'update-job-panel',
		        renderTo: document.body,
		        activeTab: 0,
                	width:600,
		        height:250,
		        plain:true,
		        defaults:{autoScroll: true},
        items:[{
		title: 'Delete Job',
                html: "<b>Submit Job Id to Delete job.</b><hr>",
                layout:'vbox',
                items:[
			new Ext.FormPanel({
			title: 'Delete Job',
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
					fieldLabel:'Job Id',
					id:'djid',
					name:'djid',
					})
			],
		buttons: [{
					text: 'Submit',
					type: 'submit',
					handler:function(){
					var djid=Ext.getCmp('djid').getValue();
					var lnk="http://kameleon:kameleon@localhost/oarapi-priv/jobs/"+djid+".json";
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
		   },{
			text:'Cancel',
			type:'reset'
		   }
			]
})

			
		]
		}
]

});

var uResource=new Ext.TabPanel({
			title:'Add/Update Resource',
			id: 'update-resource-panel',
		        renderTo: document.body,
		        activeTab: 0,
                	width:600,
		        height:250,
		        plain:true,
		        defaults:{autoScroll: true},
        items:[
		{
		title: 'Update Resource State',
                html: "<b>Asks to hold a waiting job.</b><hr>",
                layout:'vbox',
                items:[
		new Ext.FormPanel({
			title: 'Update Resource State',
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
			fieldLabel:'Resource Id',
			id:'urid',
			name:'urid',
			}),
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:new Ext.data.ArrayStore({
			fields: ['state'],
			data: [['Absent'], ['Alive'],['Dead']]
				})
			,displayField:'state',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'State',
			name:'urstate',
			id:'urstate'
				})		


			],
			buttons: [{
					text: 'Submit',
					type: 'submit',
					handler:function(){
					var urid=Ext.getCmp('urid').getValue();
					var urstate=Ext.getCmp('urstate').getValue();
					var lnk="http://kameleon:kameleon@localhost/oarapi-priv/resources/"+urid+"/state";
					var send={"state":urstate};
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
	                                                      ,buttons:Ext.Msg.OK									                                                                }); 								     }
						});
					
					
					}
				   },{
					text:'Cancel',
					type:'reset'
				   }
					]
				})



				]
				}
		]

});








Ext.onReady(function(){

  Ext.state.Manager.setProvider(new Ext.state.CookieProvider()); 

  Ext.History.init();  

	var contentPanel = {
		id: 'content-panel',
		region: 'center', 
		layout: 'card',
		margins: '2 5 5 0',
		activeItem: 0,
		border: false,
		items: [
      welcome, Resources, iframe_ganttchart, iframe_monika, submissionForm, jobs,ujob,uResource
	    ]
  };

  var treePanel = new Ext.tree.TreePanel({
    id: 'tree-panel',
    split: true,
    height: 300,
    minSize: 100,
    autoScroll: true,
    border: false,

    rootVisible: false,
    lines: false,
    useArrows: true,
        
    loader: new Ext.tree.TreeLoader({
      dataUrl:'tree-nav-poar.json'
    }),
        
    root: new Ext.tree.AsyncTreeNode()
  });

  treePanel.on('click', function(n){
    var sn = this.selModel.selNode || {}; 
    if(n.leaf && n.id != sn.id){  
      Ext.History.add(n.id);
      Ext.getCmp('content-panel').layout.setActiveItem(n.id + '-panel');
    }
  });

  var viewport = new Ext.Viewport({
            layout:'border',
            items:[
                new Ext.BoxComponent({ 
                    region:'north',
                    el: 'north',

                    height:32
                }),{
                    region:'west',
                    id:'west-panel',
                    title:'Navigation Tree',
                    split:true,
                    width: 150,
                    minSize: 150,
                    maxSize: 200,
                    collapsible: true,
                    margins:'0 0 0 5',
                    items: treePanel                    
                },
              contentPanel
             ]
        });

    Ext.History.on('change', function(token){
      if(token){
        Ext.getCmp('content-panel').layout.setActiveItem(token + '-panel');
        treePanel.getNodeById(token).select();

      } else {
        Ext.getCmp('content-panel').layout.setActiveItem('welcome-panel'); 
        treePanel.getNodeById('welcome').select();
      }
    });
});
