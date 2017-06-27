<?php
/**
 * OAR Drawgantt-SVG
 * @author Pierre Neyron <pierre.neyron@imag.fr>
 *
 */

// OAR Drawgantt SVG configuration file

////////////////////////////////////////////////////////////////////////////////
// Configuration
////////////////////////////////////////////////////////////////////////////////

// Default settings for the default view 
$CONF['default_start'] = ""; // default start and stop times (ctime values) ; unless you want to always show a
$CONF['default_stop'] = "";  // same time frame, keep those values to "" 
$CONF['default_relative_start'] = ""; // default relative start and stop times ([+-]<seconds>), mind setting it
$CONF['default_relative_stop'] = "";  // accordingly to the nav_forecast values below, eg -24*3600*0.1 and 24*3600*0.9
$CONF['default_timespan'] = 6*3600; // default timespan, should be one of the nav_timespans below
$CONF['default_resource_base'] = 'cpuset'; // default base resource, should be one of the nav_resource_bases below
$CONF['default_scale'] = 10; // default vertical scale of the grid, should be one of the nav_scales bellow

// Navigation bar configuration
$CONF['nav_timespans'] = array( // proposed timespan in the "set" bar
  '1 hour' => 3600,
  '3 hours' => 3*3600,
  '6 hours' => 6*3600,
  '12 hours' => 12*3600,
  '1 day' => 24*3600,
  '3 day' => 3*24*3600,
  '1 week' => 7*24*3600,
);

$CONF['nav_forecast'] = array( // forecast display
  '1 day' => 24*3600,
  '3 days' => 3*24*3600,
  '1 week' => 7*24*3600,
  '2 weeks' => 2*7*24*3600,
  '3 weeks' => 3*7*24*3600,
);
$CONF['nav_forecast_past_part'] = 0.1; // past part to show (percentage if < 1, otherwise: number of seconds)

$CONF['nav_scales'] = array( // proposed scales for resources
  'small' => 10,
  'big' => 20,
  'huge' => 40,
);

$CONF['nav_timeshifts'] = array( // proposed time-shifting buttons
  '1h' => 3600,
  '6h' => 6*3600,
  '1d' => 24*3600,
  '1w' => 7*24*3600,
);

$CONF['nav_filters'] = array( // proposed filters in the "misc" bar
  'all clusters' => 'resources.type = \'default\'',
  'cluster1 only' => 'resources.cluster=\'cluster1\'',
  'cluster2 only' => 'resources.cluster=\'cluster2\'',
  'cluster3 only' => 'resources.cluster=\'cluster3\'',
);

$CONF['nav_resource_bases'] = array( // proposed base resources
  'network_address',
  'cpuset',
);

$CONF['nav_timezones'] = array( // proposed timezones in the "misc" bar (the first one will be selected by default)
  'UTC',
  'Europe/Paris',
);

$CONF['nav_custom_buttons'] = array( // custom buttons, click opens the url in a new window
  'my label' => 'http://my.url'      // remove all lines to disable (empty array)
);

// Database access configuration
$CONF['db_type']="pg"; // choices: mysql for Mysql or pg for PostgreSQL
$CONF['db_server']="127.0.0.1";
$CONF['db_port']="5432"; // usually 3306 for Mysql or 5432 for PostgreSQL
$CONF['db_name']="oar"; // OAR read only user account 
$CONF['db_user']="oar_ro";
$CONF['db_passwd']="oar_ro";
$CONF['db_max_job_rows']=20000; // max number of job rows retrieved from database, which can be handled.

// Data display configuration
$CONF['timezone'] = "UTC";
$CONF['site'] = "My OAR resources"; // name for your infrastructure or site
$CONF['resource_labels'] = array('network_address','cpuset'); // properties to describe resources (labels on the left). Must also be part of resource_hierarchy below 
$CONF['cpuset_label_display_string'] = "%02d";
$CONF['label_display_regex'] = array( // shortening regex for labels (e.g. to shorten node-1.mycluster to node-1). label will be replaced with the 1st selection of the regex, unless an array is used with the replacement string as the second argument.
  'network_address' => '/^([^.]+)\..*$/',
  );
$CONF['label_cmp_regex'] = array( // substring selection regex for comparing and sorting labels (resources)
  'network_address' => '/^([^-]+)-(\d+)\..*$/',
  );
$CONF['resource_properties'] = array( // properties to display in the pop-up on top of the resources labels (on the left)
  'deploy', 'cpuset', 'besteffort', 'network_address', 'type', 'drain');
$CONF['resource_hierarchy'] = array( // properties to use to build the resource hierarchy drawing
  'network_address','cpuset',
  ); 
$CONF['resource_base'] = "cpuset"; // base resource of the hierarchy/grid
$CONF['resource_group_level'] = "network_address"; // level of resources to separate with blue lines in the grid
$CONF['resource_drain_property'] = "drain"; // if set, must also be one of the resource_properties above to activate the functionnality
$CONF['state_colors'] = array( // colors for the states of the resources in the gantt
  'Absent' => 'url(#absentPattern)', 'Suspected' => 'url(#suspectedPattern)', 'Dead' => 'url(#deadPattern)', 'Standby' => 'url(#standbyPattern)', 'Drain' => 'url(#drainPattern)');
$CONF['job_colors'] = array( // colors for the types of the jobs in the gantt
  'besteffort' => 'url(#besteffortPattern)', 
  'deploy(=\w)?' => 'url(#deployPattern)', 
  'container(=\w+)?' => 'url(#containerPattern)', 
  'timesharing=(\*|user),(\*|name)' => 'url(#timesharingPattern)', 
  'placeholder=\w+' => 'url(#placeholderPattern)',
  );
$CONF['job_click_url'] = ''; // set a URL to open when a job is double-clicked, %%JOBID%% is to be replaced by the jobid in the URL
$CONF['resource_click_url'] = ''; // set a URL to open when a resource is double-clicked, %%TYPE%% is to be replaced by the resource type and %%ID%% by the resource id in the URL

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
$CONF['gantt_min_height'] = 100; // default: 100
$CONF['gantt_min_job_width_for_label'] = 40; // default: 40
$CONF['min_state_duration'] = 2; // default: 2

// Colors and fill patterns for jobs and states
$CONF['job_color_saturation_lightness'] = "75%,75%"; // default: "75%,75%"
$CONF['job_color_saturation_lightness_highlight'] = "50%,50%"; // default: "50%,50%"
$CONF['static_patterns'] = <<<EOT
<pattern id="absentPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="10" height="10" viewBox="0 0 10 10" >
<polygon points="0,0 3,0 0,3" fill="#0000ff" stroke="#0000ff" stroke-width="1" />
<polygon points="7,0 10,0 10,3 3,10 0,10 0,7" fill="#0000ff" stroke="#0000ff" stroke-width="1" />
<polygon points="10,7 10,10 7,10" fill="#0000ff" stroke="#0000ff" stroke-width="1" />
</pattern> 
<pattern id="suspectedPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="10" height="10" viewBox="0 0 10 10" >
<polygon points="0,0 3,0 0,3" fill="#ff0000" stroke="#ff0000" stroke-width="1" />
<polygon points="7,0 10,0 10,3 3,10 0,10 0,7" fill="#ff0000" stroke="#ff0000" stroke-width="1" />
<polygon points="10,7 10,10 7,10" fill="#ff0000" stroke="#ff0000" stroke-width="1" />
</pattern> 
<pattern id="deadPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="10" height="10" viewBox="0 0 10 10" >
<polygon points="0,0 3,0 0,3" fill="#404040" stroke="#404040" stroke-width="1" />
<polygon points="7,0 10,0 10,3 3,10 0,10 0,7" fill="#404040" stroke="#404040" stroke-width="1" />
<polygon points="10,7 10,10 7,10" fill="#404040" stroke="#404040" stroke-width="1" />
</pattern> 
<pattern id="standbyPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="10" height="10" viewBox="0 0 10 10" >
<polygon points="0,0 3,0 0,3" fill="#88ffff" stroke="#88ffff" stroke-width="1" />
<polygon points="7,0 10,0 10,3 3,10 0,10 0,7" fill="#88ffff" stroke="#88ffff" stroke-width="1" />
<polygon points="10,7 10,10 7,10" fill="#88ffff" stroke="#88ffff" stroke-width="1" />
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

// Standby state display options for the part shown in the future
$CONF['standby_truncate_state_to_now'] = 1; // default: 1
// Besteffort job display options for the part shown in the future
$CONF['besteffort_truncate_job_to_now'] = 1; // default: 1
$CONF['besteffort_pattern'] = <<<EOT
<pattern id="%%PATTERN_ID%%" patternUnits="userSpaceOnUse" x="0" y="0" width="10" height="10" viewBox="0 0 10 10" >
<polygon points="0,0 7,0 10,5 7,10 0,10 3,5" fill="%%PATTERN_COLOR%%" stroke-width="0"/>
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

// Minimum timespan the gantt can handle
$CONF['min_timespan']= 480; // gantt does not show if (stop date - start date) < 8 minutes

// Debugging
$CONF['debug'] = 0; // Set to > 0 to enable debug prints in the web server error logs

?>
