/* Function to render all the pages */
final_func=function(){
/* Function to be executed when everything is ready */
Ext.onReady(function(){

/* Function to render the chart */

//chart_func();
Ext.state.Manager.setProvider(new Ext.state.CookieProvider()); 

  Ext.History.init();  

  /* Content Panel of the Portal */
	var contentPanel = {
		id: 'content-panel',
		region: 'center', 
		layout: 'card',
		margins: '2 5 5 0',
		activeItem: 0,
		border: false,
		items: [
/* Add the page object here */
      welcome, Resources, iframe_ganttchart, iframe_monika, submissionForm, jobs,ujob,uResource,chart,single_job_resource,oaradmin,help
	    ]
  };


/* Tree panel on the top left of the portal */
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
        treePanel.getNodeById('welcome').select(); /* Set welcome as the start page */
      }
    });
});

}

/* Has the chart values loaded */
if(chart_flag==0)
{
	setTimeout('final_func()',1000);// if chart is not rendered, wait for 500 miliseconds.
}
else
{
	final_func();
}





