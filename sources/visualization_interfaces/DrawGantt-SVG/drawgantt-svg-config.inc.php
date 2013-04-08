<?php
// OAR Drawgantt SVG version

////////////////////////////////////////////////////////////////////////////////
// Configuration
////////////////////////////////////////////////////////////////////////////////

// Database access configuration
$CONF['db_type']="mysql"; // choices: mysql for Mysql or pg for PostgreSQL
$CONF['db_server']="127.0.0.1";
$CONF['db_port']="3306"; // usually 3306 for Mysql or 5432 for PostgreSQL
$CONF['db_name']="oar"; // OAR read only user account 
$CONF['db_user']="oar";
$CONF['db_passwd']="oar";
$CONF['site'] = "My OAR resources"; // name for your infrastructure or site
$CONF['resource_hierarchy'] = array( // properties to use to build the resource hierarchy drawing
	'network_address','cpuset'); 
$CONF['resource_labels'] = array(  // properties to use for resource labels on the left (any of the resource hierarchy or cpuset)
	'network_address','cpuset');
$CONF['cpuset_label_display_string'] = "%02d";
$CONF['label_display_regex'] = array( // shortening regex for labels (e.g. to shorten node-1.mycluster to node-1
	'network_address' => '/^([^.]+)\..*$/');
$CONF['label_cmp_regex'] = array( // string selection regex for comparing and sorting labels (resources)
	'network_address' => '/^[^.\d]+(\d+)\..*$/');
$CONF['resource_properties'] = array( // properties to display in the pop-up on top of the resources labels (on the left)
	'deploy', 'cpuset', 'besteffort', 'network_address', 'type');
$CONF['state_colors'] = array( // colors for the states of the resources in the gantt
	'Absent' => 'url(#absentPattern)', 'Suspected' => 'url(#suspectedPattern)', 'Dead' => 'url(#deadPattern)');
$CONF['job_colors'] = array( // colors for the types of the jobs in the gantt
	'besteffort' => 'url(#besteffortPattern)', 
	'deploy' => 'url(#deployPattern)', 
	'container' => 'url(#containerPattern)', 
	'timesharing=\w+,\w+' => 'url(#timesharingPattern)', 
	'set_placeholder=\w+' => 'url(#placeholderPattern)',
	);
// display geometry customization
$CONF['hierarchy_resource_width'] = 10; // default: 10
$CONF['scale'] = 10; // default: 10
$CONF['time_ruler_scale'] = 6; // default: 6
$CONF['gantt_top'] = 30; // default: 30
$CONF['bottom_margin'] = 45; // default: 45
$CONF['right_margin'] = 10; // default 10
$CONF['label_right_align'] = 105; // default: 105
$CONF['hierarchy_left_align'] = 110; // default: 110
$CONF['gantt_left_align'] = 160; // default: 160
$CONF['gantt_width'] = 1000; // default: 1000
$CONF['gantt_min_job_width_for_label'] = 0; // default: 0
// pattern definitions for the state_colors and job_colors configurations
$CONF['patterns'] = <<<EOT
<pattern id="absentPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="5" height="5" viewBox="0 0 5 5" >
<line x1="5" y1="0" x2="0" y2="5" stroke="#000000" stroke-width="2" />
</pattern> 
<pattern id="suspectedPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="5" height="5" viewBox="0 0 5 5" >
<line x1="5" y1="0" x2="0" y2="5" stroke="#ff0000" stroke-width="2" />
</pattern> 
<pattern id="deadPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="5" height="5" viewBox="0 0 5 5" >
<line x1="5" y1="0" x2="0" y2="5" stroke="#ff8080" stroke-width="2" />
</pattern> 
<pattern id="besteffortPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<text font-size="10" x="0" y="10" fill="#888888">B</text>
</pattern> 
<pattern id="containerPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<text font-size="10" x="0" y="20" fill="#888888">C</text>
</pattern> 
<pattern id="placeholderPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<line x1="0" y1="0" x2="20" y2="20" stroke="#000000" stroke-width="2" />
<text font-size="10" x="10" y="20" fill="#888888">P</text>
</pattern> 
<pattern id="deployPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<text font-size="10" x="10" y="10" fill="#888888">D</text>
</pattern> 
<pattern id="timesharingPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<text font-size="10" x="10" y="20" fill="#888888">T</text>
</pattern> 
EOT;
?>
