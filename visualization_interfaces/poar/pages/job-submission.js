/* Array to contain hours */
var hour = new Ext.data.ArrayStore({
	fields: ['Hours'],
	data : [['00'],['01'],['02'],['03'],['04'],['05'],['06'],['07'],['08'],['09'],['10'],['11'],['12'],['13'],['14'],['15'],['16'],['17'],['18'],['19'],['20'],['21'],['22'],['23']]
	});
/* Array to contain minutes  */
var minute=new Ext.data.ArrayStore({
fields: ['Minutes'],
data: [['01'],['02'],['03'],['04'],['05'],['06'],['07'],['08'],['09'],['10'],['11'],['12'],['13'],['14'],['15'],['16'],['17'],['18'],['19'],['20'],['21'],['22'],['23'],['24'],['25'],['26'],['27'],['28'],['29'],['30'],['31'],['32'],['33'],['34'],['35'],['36'],['37'],['38'],['39'],['40'],['41'],['42'],['43'],['44'],['45'],['46'],['47'],['48'],['49'],['50'],['51'],['52'],['53'],['54'],['55'],['56'],['57'],['58'],['59']]
		});
/* Array to contain seconds */
var second=new Ext.data.ArrayStore({
fields: ['Seconds'],
data: [['01'],['02'],['03'],['04'],['05'],['06'],['07'],['08'],['09'],['10'],['11'],['12'],['13'],['14'],['15'],['16'],['17'],['18'],['19'],['20'],['21'],['22'],['23'],['24'],['25'],['26'],['27'],['28'],['29'],['30'],['31'],['32'],['33'],['34'],['35'],['36'],['37'],['38'],['39'],['40'],['41'],['42'],['43'],['44'],['45'],['46'],['47'],['48'],['49'],['50'],['51'],['52'],['53'],['54'],['55'],['56'],['57'],['58'],['59']]
		});

/* Array to Number of Nodes */
var node=new Ext.data.ArrayStore({
fields: ['nodes'],
data: [['1'],['2'],['3'],['4'],['5'],['6'],['7'],['8'],['9'],['10']]
		});

/* Array to contain Number of cpus */
var cpu=new Ext.data.ArrayStore({
fields: ['cpus'],
data: [['1'],['2'],['3'],['4']]
		});

var order=new Ext.data.ArrayStore({
fields: ['order'],
data: [['1'],['2'],['3'],['4'],['5'],['6'],['7'],['8'],['9'],['10']]
		});

//Form Panel to hold various keys for various options
var submissionForm = new Ext.FormPanel({
	title: 'Submission Form',
	id: 'submission-form-panel',
	renderTo: document.body,
	width:600,
	height:500,
	plain:'true',
	autoHeight:'true',
	autoScroll:'true',
	defaults:{autoScroll: true},
	items:[{
			//Option -l starts
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

			{//Option -S starts
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
			//option -p starts
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
{			//option -r starts
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
			//option -t starts
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
},{			//option -d starts
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
{			//option -n starts
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
			//option -a starts
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
},{			//option -k starts
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
			//option -i starts
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
			//option -e starts
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
			//option -O starts
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
					/* Function to execute when job is submitted */
					handler:function(){
					/* Get various values */
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

					/* value to be send to the api */

					var send={"resource":resource,"script_path":lpath,"scanscript":spath,"queue":queue,"property":property,"reservation":reservation,"checkpoint":rcheck,"signal":rsignal,"type":ttype,"directory":dpath,"project":dproject,"name":nname,"anterior":ajid,"notify":anmethod,"resubmit":arsubmit,"use-job-key":kkey,"import-job-key-from-file":kfile,"import-job-key-inline":kjkey,"export-job-key-to-file":ejfile,"stdout":Ofile};


					Ext.Ajax.request({
						waitMsg: 'Submitting...',
						type:'POST',
						url: API_Priv_URI+'jobs',
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

