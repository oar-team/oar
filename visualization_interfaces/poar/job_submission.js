var onSubmit=function(){
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
					/*
					if(Cpu!="")
						resources+="/cpu="+Cpu;
						*/

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
						url: 'http://anshu:bhole101@localhost/oarapi-priv/jobs',
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

