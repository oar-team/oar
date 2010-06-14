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

var submissionForm = {
    title: 'Submission Form',
    id: 'submission-form-panel',
    layout: 'fit',
    bodyStyle: 'padding:15px;',
    items: {
	    layout: 'fit',
	    frame: true,
	    bodyStyle: 'padding:10px 5px 5px;',
	    tbar: [{
	    	text: 'Send',
	    	iconCls: 'icon-send'
	    },'-',{
	    	text: 'Save',
	    	iconCls: 'icon-save'
	    },{
	    	text: 'Check Spelling',
	    	iconCls: 'icon-spell'
	    },'-',{
	    	text: 'Print',
	    	iconCls: 'icon-print'
	    },'->',{
	    	text: 'Attach a File',
	    	iconCls: 'icon-attach'
	    }]
    }
};



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
