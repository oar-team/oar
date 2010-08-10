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
					var lnk="http://localhost/oarapi-priv/resources/"+urid+"/state";
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

