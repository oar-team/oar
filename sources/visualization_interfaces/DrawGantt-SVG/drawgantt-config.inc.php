<?php
// OAR Drawgantt SVG configuration file

////////////////////////////////////////////////////////////////////////////////
// Configuration
////////////////////////////////////////////////////////////////////////////////

// Navigation bar configuration
$CONF['nav_filters'] = array(
  'all clusters' => "",
	'cluster1 only' => 'cluster="cluster1"',
	'cluster2 only' => 'cluster="cluster2"',
	'cluster3 only' => 'cluster="cluster3"',
);
$CONF['nav_custom_buttons'] = array(
	'my label' => 'http://my.url'
);

// Database access configuration
$CONF['db_type']="mysql"; // choices: mysql for Mysql or pg for PostgreSQL
$CONF['db_server']="127.0.0.1";
$CONF['db_port']="3306"; // usually 3306 for Mysql or 5432 for PostgreSQL
$CONF['db_name']="oar"; // OAR read only user account 
$CONF['db_user']="oar";
$CONF['db_passwd']="oar";

// Data display configuration
$CONF['site'] = "My OAR resources"; // name for your infrastructure or site
$CONF['resource_labels'] = array('network_address','cpuset'); // properties to use to describe resources (resource labels on the left)
$CONF['cpuset_label_display_string'] = "%02d";
$CONF['label_display_regex'] = array( // shortening regex for labels (e.g. to shorten node-1.mycluster to node-1
	'network_address' => '/^([^.]+)\..*$/',
	);
$CONF['label_cmp_regex'] = array( // substring selection regex for comparing and sorting labels (resources)
	'network_address' => '/^([^-]+)-(\d+)\..*$/',
	);
$CONF['resource_properties'] = array( // properties to display in the pop-up on top of the resources labels (on the left)
	'deploy', 'cpuset', 'besteffort', 'network_address', 'type');
$CONF['resource_hierarchy'] = array( // properties to use to build the resource hierarchy drawing
	'network_address','cpuset'); 
$CONF['state_colors'] = array( // colors for the states of the resources in the gantt
	'Absent' => 'url(#absentPattern)', 'Suspected' => 'url(#suspectedPattern)', 'Dead' => 'url(#deadPattern)', 'Standby' => 'url(#standbyPattern)');
$CONF['job_colors'] = array( // colors for the types of the jobs in the gantt
	'besteffort' => 'url(#besteffortPattern)', 
	'deploy' => 'url(#deployPattern)', 
	'container' => 'url(#containerPattern)', 
	'timesharing=\w+,\w+' => 'url(#timesharingPattern)', 
	'set_placeholder=\w+' => 'url(#placeholderPattern)',
	);

// Geometry customization
$CONF['hierarchy_resource_width'] = 10; // default: 10
$CONF['scale'] = 10; // default: 10
$CONF['time_ruler_scale'] = 6; // default: 6
$CONF['time_ruler_steps'] = array(60,120,180,300,600,1200,1800,3600,7200,10800,21600,28800,43200,86400,172800,259200,604800);
$CONF['gantt_top'] = 50; // default: 50
$CONF['bottom_margin'] = 45; // default: 45
$CONF['right_margin'] = 30; // default 30
$CONF['label_right_align'] = 105; // default: 105
$CONF['hierarchy_left_align'] = 110; // default: 110
$CONF['gantt_left_align'] = 160; // default: 160
$CONF['gantt_min_width'] = 1000; // default: 1000
$CONF['gantt_min_height'] = 400; // default: 400
$CONF['gantt_min_job_width_for_label'] = 0; // default: 0

// Colors and fill patterns for jobs and states
$CONF['job_color_saturation'] = "75%"; // saturation percentage for the color of the jobs
$CONF['job_color_lightness'] = "75%"; // lightness percentage for the color of the jobs
$CONF['magic_number'] = (1+sqrt(5))/2; // magic number used to compute the function hue(jod_id) 
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
<pattern id="standbyPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="5" height="5" viewBox="0 0 5 5" >
<line x1="5" y1="0" x2="0" y2="5" stroke="#00ff00" stroke-width="2" />
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

// Debugging
$CONF['debug'] = 0; // Set to 1 to enable php debug prints in the web server error logs


?>
