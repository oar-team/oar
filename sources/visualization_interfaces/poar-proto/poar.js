//oarapi_url = 'http://localhost/'
var oarapi_url = 'http://localhost:8888/oarapi/'

// http://localhost:8888/oarapi/resources?structure=simple uri example to acces extjs friendly format of resources list

//
// The default start page, also a simple example of a FitLayout.
var welcome = {
	id: 'welcome-panel',
	title: 'Welcome Page',
	layout: 'fit',
	bodyStyle: 'padding:25px',
	contentEl: 'welcome-div'  // pull existing content from the page see poar.html
};
// Page for Test
var test = {
	id: 'test-panel',
	title: 'Test Page',
	layout: 'fit',
//  autoScroll: true,
	bodyStyle: 'padding:25px',
  items:[{

   xtype:'form', // essai pour un inclure un form ???
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
//  root: '',
  fields: [
    {name: 'Job_Id', type: 'string'},
    {name: 'owner', type: 'string'},
    {name: 'submission', type: 'string'},
    {name: 'name', type: 'string'},
    {name: 'uri', type: 'string'},
    {name: 'state', type: 'string'}
  ],
//  proxy : new Ext.data.ScriptTagProxy({ // attention lire la doc pour ScriptTagProxy...)
 proxy : new Ext.data.HttpProxy({

//    url: '/test-extjs/poar/jobs-summary2.json',
     url: '/test-extjs/poar/jobs-summary.json',
//   url: oarapi_url + 'jobs?structure=simple', // TODO structure=simple passed by parameterer
    method: 'GET'
  }),
 // sortInfo:{field: 'Jobs_Id', direction: "ASC"}
});

store_job.load();
/*

  "Job_Id" : "1",
      "owner" : "baygon",
      "submission" : "1234786637",
      "name" : "Test_job",
      "queue" : "default",
      "uri" : "/jobs/1.json",
      "state" : "Running"
*/

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
    items:[jobs_summary
/*
      title: 'Jobs Summary',
      xtype: 'gridpanel',
      store: store,
      columns: [
        {header: "Jobs Id", dataIndex: 'Job_Id'},
        {header: "owner", dataIndex: 'owner'}, 
        {header: "submission", dataIndex: 'submission'},
        {header: "name", dataIndex: 'name'},
        {header: "uri", dataIndex: 'uri'},
        {header: "state", dataIndex: 'state'}
      ]
*/
    ]
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

  // NOTE: This is an example showing simple state management. During development,
  // it is generally best to disable state management as dynamically-generated ids
  // can change across page loads, leading to unpredictable results.  The developer
  // should ensure that stable state ids are set for stateful components in real apps.
  Ext.state.Manager.setProvider(new Ext.state.CookieProvider()); //???

  // history to provide backward/forward web support
  Ext.History.init();  

  // Content Panel at the center
	var contentPanel = {
		id: 'content-panel',
		region: 'center', // this is what makes this panel into a region within the containing layout
		layout: 'card',
		margins: '2 5 5 0',
		activeItem: 0,
		border: false,
		items: [
      welcome, test, iframe_ganttchart, iframe_monika, submissionForm, jobs
//, jobs_summary
	    ]
  };

	// TreePanel for navigation
  var treePanel = new Ext.tree.TreePanel({
    id: 'tree-panel',
//    title: 'Navigation Tree',
    split: true,
    height: 300,
    minSize: 100,
    autoScroll: true,
    border: false,

    // tree-specific configs:
    rootVisible: false,
    lines: false,
    useArrows: true,
        
    loader: new Ext.tree.TreeLoader({
      dataUrl:'tree-nav-poar.json'
    }),
        
    root: new Ext.tree.AsyncTreeNode()
  });

	// Assign the changeLayout function to be called on tree node click.
  treePanel.on('click', function(n){
    var sn = this.selModel.selNode || {}; // selNode is null on initial selection
    if(n.leaf && n.id != sn.id){  // ignore clicks on folders and currently selected node
      Ext.History.add(n.id);
      Ext.getCmp('content-panel').layout.setActiveItem(n.id + '-panel');
    }
  });

  // Global layout (north, west and center) 
  var viewport = new Ext.Viewport({
            layout:'border',
            items:[
                new Ext.BoxComponent({ // raw
                    region:'north',
                    el: 'north',
                    height:32
                }),{
//                    layout: 'border',
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

    // Handle this change event in order to restore the UI to the appropriate history state
    Ext.History.on('change', function(token){
      if(token){
        Ext.getCmp('content-panel').layout.setActiveItem(token + '-panel');
        treePanel.getNodeById(token).select();

      } else {
        // This is the initial default state.  Necessary if you navigate starting from the
        // page without any existing history token params and go back to the start state.
        Ext.getCmp('content-panel').layout.setActiveItem('welcome-panel'); 
        treePanel.getNodeById('welcome').select();
      }
    });
});
