var welcome = {
	id: 'welcome-panel',
	title: 'Welcome Page',
	layout: 'fit',
	bodyStyle: 'padding:25px',
	contentEl: 'welcome-div'  
};

var test = {
	id: 'test-panel',
	title: 'Test Page',
	layout: 'fit',
	bodyStyle: 'padding:25px',
  items:[{

   xtype:'form', 
   id: "form-gantt", 
   url: '/cgi-bin/poar-test.cgi',
   items: [{
      tbar: [
        { xtype: 'tbbutton',
          text: 'Submit',
          handler:function(){
            Ext.getCmp('form-gantt').getForm().submit({
              success: function(f,a){
                Ext.Msg.alert('Success', 'It worked');
              },
              failure: function(f,a){
                Ext.Msg.alert('Warning', a.result.errormsg);
              }
            });
          }
        },{
          xtype: 'tbbutton',
	    	  text: 'Change',
          handler:function(){
            Ext.getCmp('gantt_image').el.dom.src = 'gantt_month.png';
          }
        },{
          xtype: 'radio',
          name: 'testhello',
          boxLabel: 'Color'
        },{
          xtype: 'datefield',
          name: 'essai'
        }]
    },{
      xtype:'box',
      id:'gantt_image',
       autoScroll: true,

      autoEl: {tag:'img', src:'gantt.png'}
    }]
  }]
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
  root:'data',
  fields: [
    {name: 'Job_Id', type: 'string'},
    {name: 'owner', type: 'string'},
    {name: 'submission', type: 'string'},
    {name: 'name', type: 'string'},
    {name: 'uri', type: 'string'},
    {name: 'state', type: 'string'}
  ],
 proxy : new Ext.data.HttpProxy({

     url: 'jobs-summary.json',
    method: 'GET'
  }),
});

store_job.load();

var jobs_summary = new Ext.grid.GridPanel({
  frame:true,
  title: 'Jobs Summary',	
  id: 'jobs-summary-panel',

  store: store_job,
  columns: [
    {header: "Jobs Id", dataIndex: 'Job_Id'},
    {header: "owner", dataIndex: 'owner'}, 
    {header: "submission", dataIndex: 'submission'},
    {header: "name", dataIndex: 'name'},
    {header: "uri", dataIndex: 'uri'},
    {header: "state", dataIndex: 'state'}
    ]
    });


var jobs = {
title: 'Jobs List',
       id: 'jobs-panel',
       layout: 'fit',
       bodyStyle: 'padding:30px;',
       items:[jobs_summary]
	};

var hour = new Ext.data.ArrayStore({
	fields: ['Hours'],
	data : [['0'],['1'],['2'],['3'],['4'],['5'],['6'],['7'],['8'],['9'],['10'],['11'],['12'],['13'],['14'],['15'],['16'],['17'],['18'],['19'],['20'],['21'],['22'],['23']]
	});

var minute=new Ext.data.ArrayStore({
fields: ['Minutes'],
data: [['1'],['2'],['3'],['4'],['5'],['6'],['7'],['8'],['9'],['10'],['11'],['12'],['13'],['14'],['15'],['16'],['17'],['18'],['19'],['20'],['21'],['22'],['23'],['24'],['25'],['26'],['27'],['28'],['29'],['30'],['31'],['32'],['33'],['34'],['35'],['36'],['37'],['38'],['39'],['40'],['41'],['42'],['43'],['44'],['45'],['46'],['47'],['48'],['49'],['50'],['51'],['52'],['53'],['54'],['55'],['56'],['57'],['58'],['59']]
		});
var second=new Ext.data.ArrayStore({
fields: ['Seconds'],
data: [['1'],['2'],['3'],['4'],['5'],['6'],['7'],['8'],['9'],['10'],['11'],['12'],['13'],['14'],['15'],['16'],['17'],['18'],['19'],['20'],['21'],['22'],['23'],['24'],['25'],['26'],['27'],['28'],['29'],['30'],['31'],['32'],['33'],['34'],['35'],['36'],['37'],['38'],['39'],['40'],['41'],['42'],['43'],['44'],['45'],['46'],['47'],['48'],['49'],['50'],['51'],['52'],['53'],['54'],['55'],['56'],['57'],['58'],['59']]
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
	url:'process.py/sub',
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
			store:order,
			displayField:'order',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Option Order',
			name:'lorder'


				}),
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
			name:'Node'


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
			fieldLabel:'Cpu',
			name:'Cpu'
			}),
			new Ext.form.TextField({
				fieldLabel:'Script-Path',
				name:'lpath'
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
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:order,
			displayField:'order',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Option Order',
			name:'Sorder'
				}),
			new Ext.form.TextField({
				fieldLabel:'Script-Path',
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
			store:order,
			displayField:'order',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Option Order',
			name:'qorder'
				}),

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
			name:'tpe'
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
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:order,
			displayField:'order',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Option Order',
			name:'porder'
				}),

			new Ext.form.ComboBox({
			renderTo: document.body,
			store:new Ext.data.ArrayStore({
			fields: ['switch'],
			data: [['sw1'],['sw2'],['sw3'],['sw4'],['sw5']]
				})
			,displayField:'switch',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Switch Number',
			name:'snumber'
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
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:order,
			displayField:'order',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Option Order',
			name:'rorder'
				}),
		new Ext.form.DateField({
			fieldLabel:'Date',
			name:'Date'
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
			name:'Hours'
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
			name:'Minutes'
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
			name:'Seconds'
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
			store:order,
			displayField:'order',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Option Order',
			name:'torder'
				}),

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
			name:'ttype'
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
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:order,
			displayField:'order',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Option Order',
			name:'dorder'
				}),
			new Ext.form.TextField({
				fieldLabel:'Directory-Path',
				name:'dpath'
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
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:order,
			displayField:'order',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Option Order',
			name:'norder'
				}),
			new Ext.form.TextField({
				fieldLabel:'Name for the Job',
				name:'nname'
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
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:order,
			displayField:'order',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Option Order',
			name:'aorder'
				}),
			new Ext.form.TextField({
				fieldLabel:'Job id',
				name:'ajid'
				}),
			new Ext.form.TextField({
				fieldLabel:'Notify Method',
				name:'anmethod'
				}),
			new Ext.form.TextField({
				fieldLabel:'resubmit job id',
				name:'arsubmit'
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
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:order,
			displayField:'order',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Option Order',
			name:'korder'
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
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:order,
			displayField:'order',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Option Order',
			name:'iorder'
				}),
			new Ext.form.TextField({
				fieldLabel:'Job key file Path',
				name:'kfile'
				}),
				new Ext.form.TextField({
				fieldLabel:'Job key inline:',
				name:'kjkey'
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
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:order,
			displayField:'order',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Option Order',
			name:'eorder'
				}),
			new Ext.form.TextField({
				fieldLabel:'Export Job key file Path',
				name:'ejfile'
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
			new Ext.form.ComboBox({
			renderTo: document.body,
			store:order,
			displayField:'order',
			typeAhead:true,
			mode:'local',
			triggerAction: 'all',
			selectOnFocus: true,
			width:360,
			fieldLabel:'Option Order',
			name:'Oorder'
				}),
			new Ext.form.TextField({
				fieldLabel:'Standard Output file',
				name:'Ofile'
				})
				]
}

		],
		buttons: [{
					text: 'Submit',
					type: 'submit',
					handler:function(){
					Ext.getCmp('submission-form-panel').form.submit({
					url:'process.py/sub',
	          			waitMsg: 'Submitting...',
		            		success: function(form, action) {
						Ext.Msg.show({
						title:'Success'
						,msg:'Job Submitted successfully'
						,modal:true
						,icon:Ext.Msg.INFO
						,buttons:Ext.Msg.OK
						});}
					,failure: function(form, action) {
						Ext.Msg.show({
						title:'Failure'
						,msg:'Some Problem Occurred'
						,modal:true
						,icon:Ext.Msg.INFO
						,buttons:Ext.Msg.OK
						});
						}

						          });
   				     }
					},{
					text: 'Cancel',
					type:'reset'
					}]

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
      welcome, test, iframe_ganttchart, iframe_monika, submissionForm, jobs
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
