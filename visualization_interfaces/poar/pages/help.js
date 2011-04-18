var q1="<b> Q1: </b>I am not able to get the job-list and resource-list.<br>";
var ans1="<b>Ans1:</b><i>Kindly change the variables in variables.js present in Web Portal Directory. Point it to the location where oarapi is present.</i><br><br>";

var q2="<b> Q2: </b> What is the UserName and Password it asks during the start?<br>";
var ans2="<b>Ans2:</b><i>It is for authentication. Since only authenticated users can perform certain kind of actions. Kindly input valid username and password.</i><br><br>";

var q3="<b> Q3: </b> How to add a new user and password?<br>";
var ans3="<b>Ans3:</b><i> If no other user is present in '/etc/oar/api-users' , execute following command as root to add a new user:-<br> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>htpasswd -b -c /etc/oar/api-users username password</b> <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;If already some users are present in '/etc/oar/api-users' , execute following command as root to add a new user:-<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>htpasswd -b /etc/oar/api-users username password</b></i><br><br>";

var q4="<b> Q4: </b>Where Can I find the rights of various kind of users?<br>";
var ans4="<b>Ans4:</b><i>You can find it in the User Manual in the Authentication part.</i><br><br>";

var q5="<b> Q5: </b>I am not able to view the full information about single job/resource.<br>";
var ans5="<b>Ans5:</b><i>Only an authenticated user can use this facility. Make sure that you have entered valid username and password.</i><br><br>";

var q6="<b> Q6: </b>Not able to get any result out of iframeGanttchart and iframeStatus.<br>";
var ans6="<b>Ans6:</b><i>Kindly check the variables Drawgantt_URI and Monika_URI in variable.js present in the Web Portal Directory. Whether they are pointing to the location of drawgantt chart api and monika api.</i><br><br>";

var q7="<b> Q7: </b>Not able to get any results from Charts section.<br>";
var ans7="<b>Ans7:</b><i>Kindly check the variable API_JOBS_URI_DEFAULT_PARAMS object of /etc/oar/oar.conf. It should not have any limit restriction.</i><br><br>";


var q8="<b> Q8: </b>Not able to change the state of resources/submit a new admission rule/Delete any admission rule/add any resources/ view Configuration variables/set the value of configuration variables.<br>";
var ans8="<b>Ans8:</b><i>Only 'oar' user perform this action.</i><br><br>";


var q9="<b> Q9: </b>Not able to submit a job/Get admission rule info.<br>";
var ans9="<b>Ans9:</b><i>Only an authenticated user can perform these actions.</i><br><br>";

var q10="<b> Q10: </b>There is some error during creation of a new resource.<br>";
var ans10="<b>Ans10:</b><i>Make sure that you have logged in as 'oar' user and there is no space in the property specification.</i><br><br>";

var q11="<b> Q11: </b>While expanding various options of Job submission the submit button disappears.<br>";
var ans11="<b>Ans11:</b><i>Kindly collapse all the options to access the submit button.</i><br><br>";


//Help Panel
var help = new Ext.Panel({ 
      title: 'help',
       id: 'help-panel',
       layout: 'vbox',
       bodyStyle: 'padding:30px;',
       autoScroll:'true',
       html:'<h2><b>FAQ\'s</b> </h2><hr>'+q1+ans1+q2+ans2+q3+ans3+q4+ans4+q5+ans5+q6+ans6+q7+ans7+q8+ans8+q9+ans9+q10+ans10+q11+ans11,
       items:[]
       });  
