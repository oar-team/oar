/* Create the Panel on which chart will be rendered */
var chart_values=[0,0,0,0,0,0,0,0,0,0],chart_labels=['Waiting','Finishing','Running','Resuming','Suspended','Launching','toLaunch','Hold','Error','toAckReservation'];

/* Function to render the chart */
chart_func=function(abc){
Raphael(raphael_chart.body.id, 800, 800).pieChart(450, 250, 150,chart_values,chart_labels, "#fff");	
}


var  raphael_chart= new Ext.Panel({
   title:'Raphael-Status of Jobs'
   , id:'raphael'
   ,renderTo: document.body,
   frame:true,
   width:600,
   height:250,
   defaults:{autoScroll: true}
   ,items:{

					xtype: 'box',
				autoEl:{
					tag: 'canvas'
					,height:150
					}
 			,listeners:{
				render:{
					scope:this
					,fn:function(){
					chart_func();
					}
				}
		}
}
});

var processing_values=[];

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
			processing_values[count]=(chart_values[count]*360)*1.0/100;
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


function draw(el,canvas_height,canvas_width){
var add_send="";
add_send+=processing_values[0];
var process_i=0;
for(process_i=1;process_i<processing_values.length;process_i++)
{
add_send+=","+processing_values[process_i];
}
var send="";
send+="size("+canvas_width+","+canvas_height+");background(175,224,230);smooth();noStroke(); int diameter = 300;int[] angs = {"+add_send +"};float lastAng = 0;for (int i=0; i<angs.length; i++){fill(angs[i] * 3.0);arc(width/2, height/2, diameter, diameter, lastAng, lastAng+radians(angs[i]));lastAng += radians(angs[i]);  }arc(width/2, height/2, diameter, diameter, lastAng, lastAng+radians(angs[0]));";
new Processing(el, send);	
}

var canvasPanel= new Ext.Panel({
			title:'Processing-Status of Jobs',
		        renderTo: document.body,
			frame:true,
                	width:600,
		        height:250,
		        defaults:{autoScroll: true},
			items:{
				xtype: 'box',
				autoEl:{
					tag: 'canvas'
					,height:150
					}
				,listeners:{
					render:{
						scope:this
						,fn:function(){
							draw(canvasPanel.items.items[0].el.dom,canvasPanel.getHeight(),canvasPanel.getWidth());
						}
					}
				}
			}
});
var chart=new Ext.TabPanel({
			title:'Various Charts',
		        id: 'Chart-panel',
		        renderTo: document.body,
		        activeTab: 0,
                	width:600,
		        height:250,
		        plain:true,
		        defaults:{autoScroll: true},
        items:[raphael_chart,canvasPanel]
});


