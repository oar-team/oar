/* Create the Panel on which chart will be rendered */
var chart_values=[0,0,0,0,0,0,0,0,0,0,0];
var chart_labels=['Waiting','Terminated','Finishing','Running','Resuming','Suspended','Launching','toLaunch','Hold','Error','toAckReservation'];

/* Function to render the chart */
chart_func=function(abc){
	Raphael(raphael_chart.body.id, 800, 800).pieChart(450, 250, 150,chart_values,chart_labels, "#fff");	
}


/* Panel to contain the reaphael chart */

var  raphael_chart= new Ext.Panel({
   title:'Raphael-Status of Jobs'
   , id:'raphael'
   ,renderTo: document.body,
   frame:true,
   width:600,
   height:250,
   defaults:{autoScroll: true}
   ,items:{
	xtype: 'box',//box element to contain the chart
	autoEl:{
		tag: 'canvas'
         	,height:150
		}
 	,listeners:{
		render:{
			scope:this
			,fn:function(){
				chart_func();//Function to be called when the object is triggered 
				}
			}
		}
	}
});


var chart_flag=0;//Flag to tell whether the data has been loaded or not

//Ajax request to fetch the information about the jobs from the API
Ext.Ajax.request({
	type:'GET',
	url: API_URI+'jobs.json',/*Get the information about the jobs*/
	headers:{'Content-Type':'application/json'},
	params:{},
	success:function (result,request) {

/* Calculate the percentage of various kind of jobs */
        var chart_jobs=Ext.decode(result.responseText);

        var chart_i=0,chart_j=0;

	for(chart_i=0;chart_i<parseInt(chart_jobs.total);chart_i++)
        {
		for(chart_j=0;chart_j<chart_labels.length;chart_j++)
		{
			if(chart_jobs.items[chart_i].state==chart_labels[chart_j])
				chart_values[chart_j]=chart_values[chart_j]+1;
		}
        }
	var chart_sum=0;	

	for(chart_i=0;chart_i<chart_labels.length;chart_i++)
	{
		chart_sum=chart_sum+chart_values[chart_i];
	}

	var chart_count=0;
	for (chart_i=0;chart_i<chart_labels.length;chart_i++)
	{

			chart_values[chart_count]=(chart_values[chart_i]*100)*1.0/chart_sum;
			chart_labels[chart_count]=chart_labels[chart_i]+' '+ chart_values[chart_count].toFixed(2)+ '%';
			chart_count=chart_count+1;
	}
	chart_flag=1;
	},
	failure: function (result,request) {//if OAR-API returns failure
	Ext.Msg.show({
	title:'Failure'
	,msg:Ext.decode(result.responseText)
        ,modal:true
        ,icon:Ext.Msg.ERROR
        ,buttons:Ext.Msg.OK									                                                         
         }); 	     
        }
});


function draw(el,canvas_height,canvas_width,processing_values){//Functions to draw Processing chart
var add_send="";
add_send+=processing_values[0];
var process_i=0;
for(process_i=1;process_i<processing_values.length;process_i++)
{
add_send+=","+processing_values[process_i];
}
var send="";
send+="size("+canvas_width+","+canvas_height+");background(175,224,230);smooth();noStroke(); int diameter = 300;int[] angs = {"+add_send+"};float lastAng = 0;for (int i=0; i<angs.length; i++){fill(angs[i] * 3.0);arc(width/2, height/2, diameter, diameter, lastAng, lastAng+radians(angs[i]));lastAng += radians(angs[i]);  }arc(width/2, height/2, diameter, diameter, lastAng, lastAng+radians(angs[0]));";
new Processing(el, send);	
}

//Panel to contain Processing chart
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
							var processing_values=new Array(chart_values.length);
							chart_values.sort();
							chart_values.reverse();
							var pr_i=0;
							for(pr_i=0;pr_i<chart_values.length;pr_i++)
							{
							processing_values[pr_i]=(chart_values[pr_i]*360)*1.0/100;
							}
							draw(canvasPanel.items.items[0].el.dom,canvasPanel.getHeight(),canvasPanel.getWidth(),processing_values);
						}
					}
				}
			}
});

var rchart_el,rchart_height,rchart_width;

var send2="\
void draw(){\
var resource_values=[0,0,0,0],resource_labels=['Alive','Suspected','Dead','Absent'];\
Ext.Ajax.request({\
	type:'GET',\
	url: API_URI+'resources.json',\
	headers:{'Content-Type':'application/json'},\
	params:{},\
	success:function (result,request) {\
        var chart_resource=Ext.decode(result.responseText);\
        var chart_i=0,chart_j=0;\
	for(chart_i=0;chart_i<parseInt(chart_resource.total);chart_i++)\
        {\
		for(chart_j=0;chart_j<resource_labels.length;chart_j++)\
		{\
			if(chart_resource.items[chart_i].state==resource_labels[chart_j])\
				resource_values[chart_j]=resource_values[chart_j]+1;\
		}\
        }\
	var chart_sum=0;	\
	for(chart_i=0;chart_i<resource_labels.length;chart_i++)\
	{\
		chart_sum=chart_sum+resource_values[chart_i];\
	}\
	var chart_count=0;\
	for (chart_i=0;chart_i<resource_labels.length;chart_i++)\
	{\
			resource_values[chart_count]=(resource_values[chart_i]*100)*1.0/chart_sum;\
			resource_values[chart_count]=(resource_values[chart_count]*360*1.0)/100;\
			chart_count=chart_count+1;\
	}\
        int diameter = 300;\
	float lastAng = 0;\
	for (int i=0; i<resource_values.length; i++)\
	{\
		fill(resource_values[i] * 3.0);\
		arc(width/2, height/2, diameter, diameter, lastAng, lastAng+radians(resource_values[i]));\
		lastAng += radians(resource_values[i]);  \
	}\
	arc(width/2, height/2, diameter, diameter, lastAng, lastAng+radians(resource_values[0]));\
	},\
	failure: function (result,request) {//if OAR-API returns failure\
	Ext.Msg.show({\
	title:'Failure'\
	,msg:Ext.decode(result.responseText)\
        ,modal:true\
        ,icon:Ext.Msg.ERROR\
        ,buttons:Ext.Msg.OK\
	});\
        }\
});\
}";

var resourcePanel= new Ext.Panel({
			title:'Processing-Status of Resources',
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
							rchart_el=resourcePanel.items.items[0].el.dom;
							var send1="\
								void setup()\
								{\
								 	size("+resourcePanel.getWidth()+","+resourcePanel.getHeight()+");\
									background(175,224,230);\
									smooth();\
									noStroke();\
									frameRate(1);\
								}";
							new Processing(rchart_el, send1+send2);
						}
					}
				}
			}
});




//The chart panel containing both Raphael and Processing charts
var chart=new Ext.TabPanel({
			title:'Various Charts',
		        id: 'Chart-panel',
		        renderTo: document.body,
		        activeTab: 0,
                	width:600,
		        height:250,
		        plain:true,
		        defaults:{autoScroll: true},
        items:[raphael_chart,canvasPanel,resourcePanel]
});


