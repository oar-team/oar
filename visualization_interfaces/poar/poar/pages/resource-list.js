/* Create the container to store the information about resource in json format */
var rstore = new Ext.data.JsonStore({
   root:'items',
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


/* Create the grid to display resource list */
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
            pageSize: 10,//Number of resources displayed per page
            store: rstore,
            displayInfo: true,
	    paramNames:{start:'offset',limit:'limit'},
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
rstore.load({params:{offset:0, limit:10}});//Get information about first 10 resources 


