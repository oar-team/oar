/* Create the Panel on which chart will be rendered */

var  chart= new Ext.Panel({
   title:'Status of Jobs'
 , id: 'Chart-panel'
 , collapsible: true
 , draggable: true
 , layout:'fit'
 , renderTo: Ext.getBody()
 , bodyStyle: 'padding:30px;'
});

/* Function to render the chart */
chart_func=function(){
Raphael(chart.body.id, 800, 800).pieChart(450, 250, 150,chart_values,chart_labels, "#fff");	
}

var chart_values=[0,0,0,0,0,0,0,0,0,0],chart_labels=['Waiting','Finishing','Running','Resuming','Suspended','Launching','toLaunch','Hold','Error','toAckReservation'];

var chart_flag=0;

Ext.Ajax.request({
	type:'GET',
	url: 'http://localhost/oarapi/jobs.json',/*Get the information about the jobs*/
	headers:{'Content-Type':'application/json'},
	params:{},
	success:function (result,request) {

/* Calculate the percentage of various kind of jobs */
        var chart_jobs=Ext.decode(result.responseText);

        var chart_i=0,chart_j=0;

	for(chart_i=0;chart_i<parseInt(chart_jobs.total);chart_i++)
        {
		for(chart_j=0;chart_j<10;chart_j++)
		{
			if(chart_jobs.items[chart_i].state==chart_labels[chart_j])
				chart_values[chart_j]=chart_values[chart_j]+1;
		}
        }
	
	var chart_sum=0;	

	for(chart_i=0;chart_i<10;chart_i++)
	{
		chart_sum=chart_sum+chart_values[chart_i];
	}

	var count=0;
	for (chart_i=0;chart_i<10;chart_i++)
	{

			chart_values[count]=(chart_values[chart_i]*100)*1.0/chart_sum;
			chart_labels[count]=chart_labels[chart_i]+' '+ chart_values[count].toFixed(2)+ '%';
			count=count+1;
	}
	

	chart_flag=1;

	},
	failure: function (result,request) {
	Ext.Msg.show({
	title:'Failure'
	,msg:Ext.decode(result.responseText)
        ,modal:true
        ,icon:Ext.Msg.ERROR
        ,buttons:Ext.Msg.OK									                                                         
         }); 	     
        }
});

