<?php
// OAR Drawgantt SVG version

////////////////////////////////////////////////////////////////////////////////
// Configuration
////////////////////////////////////////////////////////////////////////////////

$CONF['mysql_server']="localhost";
$CONF['mysql_user']="oar_ro";
$CONF['mysql_passwd']="oar";
$CONF['mysql_db']="oar";
$CONF['site'] = "My OAR resources";
$CONF['hierarchy_resource_width'] = 10;
$CONF['scale'] = 10;
$CONF['time_ruler_scale'] = 6;
$CONF['gantt_top'] = 30;
$CONF['bottom_margin'] = 45;
$CONF['right_margin'] = 10;
$CONF['label_right_align'] = 105;
$CONF['hierarchy_left_align'] = 110;
$CONF['gantt_left_align'] = 160;
$CONF['gantt_width'] = 1000;
$CONF['gantt_min_job_width_for_label'] = 0;
$CONF['resource_hierarchy'] = array('network_address','resource_id');
$CONF['resource_properties'] = array('deploy', 'cpuset', 'besteffort', 'network_address', 'type');
$CONF['resource_labels'] = array('network_address','cpuset');
$CONF['state_colors'] = array('Absent' => 'url(#absentPattern)', 'Suspected' => 'url(#suspectedPattern)', 'Dead' => 'url(#deadPattern)');
$CONF['job_colors'] = array(
	'besteffort' => 'url(#besteffortPattern)', 
	'deploy' => 'url(#deployPattern)', 
	'container' => 'url(#containerPattern)', 
	'timesharing=\w+,\w+' => 'url(#timesharingPattern)', 
	'set_placeholder=\w+' => 'url(#placeholderPattern)',
	);
$CONF['short_hostname_regex'] = '/^([^.]+)\..*$/';
$CONF['cmp_hostname_regex'] = '/^[^.\d]+(\d+)\..*$/';
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
