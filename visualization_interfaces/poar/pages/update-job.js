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
					var lnk="http://localhost/oarapi-priv/jobs/"+djid+".json";
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

