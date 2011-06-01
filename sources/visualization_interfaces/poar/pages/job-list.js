/* Create the container to store the information about the jobs in json format */
var store_job = new Ext.data.JsonStore({
  idProperty:'Job_Id',
  root:'items',
  remoteSort:true,
  totalProperty: 'total', 
  fields: [
    {name: 'owner',type:'string'},
    {name: 'name', type: 'string'},
    {name: 'api_timestamp', type: 'string'},
    {name: 'state', type: 'string'},
    {name: 'submission', type: 'string'},
    {name: 'id', type: 'string'},
    {name: 'queue', type: 'string'},
    {name:'uri',mapping:'links[0].href'},
    {name:'resource_uri',mapping:'links[1].href'}
  ],
 proxy : new Ext.data.HttpProxy({
     url: API_URI+'jobs.json',
    method: 'GET'
  })
});

store_job.setDefaultSort('id', 'desc'); /*sort the jobs according to the id in descending order*/

/* Create the Grid to display the job */
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

        }
,

 bbar: new Ext.PagingToolbar({
            pageSize:10,//Number of jobs in a page
            store: store_job,
            displayInfo: true,
            displayMsg: 'Displaying topics {0} - {1} of {2}',
            emptyMsg: "No topics to display",
	    paramNames:{start:'offset',limit:'limit'},
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



//Panel to contain the Job-list grid
var jobs = {
      title: 'Jobs List',
       id: 'jobs-panel',
       layout: 'fit',
       bodyStyle: 'padding:30px;',
       items:[jobs_summary]
	};

store_job.load({params:{offset:0, limit:10}});/* Get first 10 jobs */

