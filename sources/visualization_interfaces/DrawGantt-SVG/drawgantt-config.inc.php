<?php
// OAR Drawgantt SVG configuration file

////////////////////////////////////////////////////////////////////////////////
// Configuration
////////////////////////////////////////////////////////////////////////////////

// Navigation bar configuration
$CONF['nav_default_timespan'] = 6*3600;
$CONF['nav_timespans'] = array(
  '1 hour' => 3600,
  '6 hours' => 6*3600,
  '1 day' => 24*3600,
  '1 week' => 7*24*3600,
);

$CONF['nav_filters'] = array(
  'all clusters' => "",
  'cluster1 only' => 'cluster=\'cluster1\'',
  'cluster2 only' => 'cluster=\'cluster2\'',
  'cluster3 only' => 'cluster=\'cluster3\'',
);

$CONF['nav_default_resource_base'] = 'cpuset';
$CONF['nav_resource_bases'] = array(
  'network_address',
  'cpuset',
);

$CONF['nav_timezones'] = array(
  'UTC' => "UTC",
  'Paris' => "Europe/Paris",
);
$CONF['nav_custom_buttons'] = array(
  'my label' => 'http://my.url'
);

// Database access configuration
$CONF['db_type']="pg"; // choices: mysql for Mysql or pg for PostgreSQL
$CONF['db_server']="127.0.0.1";
$CONF['db_port']="5432"; // usually 3306 for Mysql or 5432 for PostgreSQL
$CONF['db_name']="oar"; // OAR read only user account 
$CONF['db_user']="oar_ro";
$CONF['db_passwd']="oar_ro";

// Data display configuration
$CONF['site'] = "My OAR resources"; // name for your infrastructure or site
$CONF['resource_labels'] = array('network_address','cpuset'); // properties to describe resources (labels on the left). Must also be part of resource_hierarchy below 
$CONF['cpuset_label_display_string'] = "%02d";
$CONF['label_display_regex'] = array( // shortening regex for labels (e.g. to shorten node-1.mycluster to node-1
  'network_address' => '/^([^.]+)\..*$/',
  );
$CONF['label_cmp_regex'] = array( // substring selection regex for comparing and sorting labels (resources)
  'network_address' => '/^([^-]+)-(\d+)\..*$/',
  );
$CONF['resource_properties'] = array( // properties to display in the pop-up on top of the resources labels (on the left)
  'deploy', 'cpuset', 'besteffort', 'network_address', 'type', 'drain');
$CONF['resource_hierarchy'] = array( // properties to use to build the resource hierarchy drawing
  'network_address','cpuset'); 
$CONF['resource_base'] = "cpuset"; // ...
$CONF['resource_drain_property'] = "drain"; // if set, must also be one of the resource_properties above to activate the functionnality
$CONF['state_colors'] = array( // colors for the states of the resources in the gantt
  'Absent' => 'url(#absentPattern)', 'Suspected' => 'url(#suspectedPattern)', 'Dead' => 'url(#deadPattern)', 'Standby' => 'url(#standbyPattern)', 'Drain' => 'url(#drainPattern)');
$CONF['job_colors'] = array( // colors for the types of the jobs in the gantt
  'besteffort' => 'url(#besteffortPattern)', 
  'deploy' => 'url(#deployPattern)', 
  'container' => 'url(#containerPattern)', 
  'timesharing=(\*|user),(\*|name)' => 'url(#timesharingPattern)', 
  'set_placeholder=\w+' => 'url(#placeholderPattern)',
  );

// Geometry customization
$CONF['hierarchy_resource_width'] = 10; // default: 10
$CONF['scale'] = 10; // default: 10
$CONF['text_scale'] = 10; // default: 10
$CONF['time_ruler_scale'] = 6; // default: 6
$CONF['time_ruler_steps'] = array(60,120,180,300,600,1200,1800,3600,7200,10800,21600,28800,43200,86400,172800,259200,604800);
$CONF['gantt_top'] = 50; // default: 50
$CONF['bottom_margin'] = 45; // default: 45
$CONF['right_margin'] = 30; // default 30
$CONF['label_right_align'] = 105; // default: 105
$CONF['hierarchy_left_align'] = 110; // default: 110
$CONF['gantt_left_align'] = 160; // default: 160
$CONF['gantt_min_width'] = 900; // default: 900
$CONF['gantt_min_height'] = 400; // default: 400
$CONF['gantt_min_job_width_for_label'] = 0; // default: 0

// Colors and fill patterns for jobs and states
$CONF['job_color_saturation_lightness'] = "75%,75%"; // default: "75%,75%"
$CONF['job_color_saturation_lightness_highlight'] = "50%,50%"; // default: "50%,50%"
$CONF['static_patterns'] = <<<EOT
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
<pattern id="drainPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="15" height="10" viewBox="0 0 10 10" >
<circle cx="5" cy="5" r="4" fill="#ff0000" stroke="#ff0000" stroke-width="1" />
<line x1="2" y1="5" x2="9" y2="5" stroke="#ffffff" stroke-width="2" />
</pattern> 
<pattern id="containerPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<text font-size="10" x="0" y="20" fill="#888888">C</text>
</pattern> 
<pattern id="besteffortPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<text font-size="10" x="10" y="20" fill="#888888">B</text>
</pattern> 
<pattern id="placeholderPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<text font-size="10" x="10" y="20" fill="#888888">P</text>
</pattern> 
<pattern id="deployPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<text font-size="10" x="10" y="10" fill="#888888">D</text>
</pattern> 
<pattern id="timesharingPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<text font-size="10" x="10" y="20" fill="#888888">T</text>
</pattern> 
EOT;

// Besteffort job display options for the part shown in the future
$CONF['besteffort_truncate_job_to_now'] = 1; // default: 1
$CONF['besteffort_pattern'] = <<<EOT
<pattern id="%%PATTERN_ID%%" patternUnits="userSpaceOnUse" x="0" y="0" width="10" height="10" viewBox="0 0 10 10" >
<line x1="0" y1="0" x2="10" y2="10" stroke="%%PATTERN_COLOR%%" stroke-width="5"/>
<line x1="-5" y1="5" x2="5" y2="15" stroke="%%PATTERN_COLOR%%" stroke-width="5"/>
<line x1="5" y1="-5" x2="15" y2="5" stroke="%%PATTERN_COLOR%%" stroke-width="5"/>
</pattern>'
EOT;

// Advanced customization for the computation of the colors of the jobs
// Uncomment and adapt the following to override the default function
//class MyShuffle extends Shuffle {
//    // Default function: get the color's hue value as a function of the job_id
//    function job2int($job) {
//        // compute a suffled number for job_id, so that colors are not too close
//        $magic_number = (1+sqrt(5))/2;
//        return (int)(360 * fmod($job->job_id * $magic_number, 1));
//    }
//    // Other example: get the color's hue value as a function of the job_user value
//    protected $cache = array(); 
//    function job2int($job) { 
//        // shuffled number based on the job_user:
//        if (! array_key_exists($job->job_user, $this->cache)) {
//            $n = (int) base_convert(substr(md5($job->job_user) ,0, 5), 16, 10);
//            $magic_number = (1+sqrt(5))/2;
//            $this->cache[$job->job_user] = (int)(360 * fmod($n * $magic_number, 1));
//        }
//        return $this->cache[$job->job_user];
//    }
//}
//Shuffle::init(new MyShuffle()); // this line must be uncommented for the overiding to take effect

// Debugging
$CONF['debug'] = 0; // Set to 1 to enable php debug prints in the web server error logs

?>
