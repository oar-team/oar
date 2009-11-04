<?php
// OAR Drawgantt SVG version
// $Id$

////////////////////////////////////////////////////////////////////////////////
// Parameters
////////////////////////////////////////////////////////////////////////////////
$site = array_key_exists('site',$_GET)?$_GET['site']:"grenoble";
$gantt_start_date = array_key_exists('start',$_GET)?$_GET['start']:0;
$gantt_stop_date = array_key_exists('stop',$_GET)?$_GET['stop']:0;
$gantt_relative_start_date = (array_key_exists('relative_start',$_GET) or ($_GET['relative_start'] > 0))?($_GET['relative_start']):86400;
$gantt_relative_stop_date = (array_key_exists('relative_stop',$_GET) or ($_GET['relative_stop'] > 0))?($_GET['relative_stop']):86400;
$resource_filter = $_GET['filter'];

////////////////////////////////////////////////////////////////////////////////
// Configuration
////////////////////////////////////////////////////////////////////////////////

$CONF=array();
$CONF['hierarchy_resource_width'] = 10;
$CONF['scale'] = 10;
$CONF['time_ruler_scale'] = 5;
$CONF['gantt_top'] = 30;
$CONF['bottom_margin'] = 45;
$CONF['right_margin'] = 10;
$CONF['label_right_align'] = 105;
$CONF['hierarchy_left_align'] = 110;
$CONF['gantt_left_align'] = 160;
$CONF['gantt_width'] = 1000;
$CONF['gantt_min_job_width_for_label'] = 50;
$CONF['resource_hierarchy'] = array('cluster','host','cpu','core');
$CONF['resource_properties'] = array('ib10g', 'core', 'deploy', 'cpuset', 'besteffort', 'ip', 'ib10gmodel', 'disktype', 'nodemodel', 'memnode', 'memcore', 'ethnb', 'cluster', 'cpuarch', 'myri2gmodel', 'cpu', 'cpucore', 'myri10g', 'memcpu', 'network_address', 'virtual', 'host', 'rconsole', 'myri10gmodel', 'cputype', 'switch', 'cpufreq', 'type', 'myri2g');
$CONF['resource_labels'] = array('host','cpuset');
$CONF['state_colors'] = array('Absent' => 'url(#absentPattern)', 'Suspected' => 'url(#suspectedPattern)', 'Dead' => 'url(#deadPattern)');
$CONF['job_colors'] = array('besteffort' => 'url(#besteffortPattern)', 'deploy' => 'url(#deployPattern)', 'container' => 'url(#containerPattern)', 'timesharing=.*' => 'url(#timesharingPattern)');

////////////////////////////////////////////////////////////////////////////////
// Utility functions
////////////////////////////////////////////////////////////////////////////////

// conversion function from date to pixel coordinates in the gantt
function date2px($date) {
	global $CONF, $gantt_start_date, $gantt_stop_date, $gantt_now;
	if ($date < $gantt_start_date) {
		return $CONF['gantt_left_align'];
	}
	if ($date > $gantt_stop_date) {
		return $CONF['gantt_left_align'] +  $CONF['gantt_width'];
	}
	return round($CONF['gantt_left_align'] + ($CONF['gantt_width'] * ($date - $gantt_start_date)) / ($gantt_stop_date - $gantt_start_date));
}

// sort function for resource_ids
function resource_id_sort($r1, $r2) {
	$m1 = array();
	$m2 = array();
	$regex = '/^(\w+)-(\d+)\./';
	preg_match($regex, $r1->resources['host']->id, $m1);
	preg_match($regex, $r2->resources['host']->id, $m2);
	return ($m1[1] > $m2[1]) or (($m1[1] == $m2[1]) and ($m1[2] > $m2[2])) or (($m1[1] == $m2[1]) and ($m1[2] == $m2[2]) and ($r1->cpuset > $r2->cpuset));
}

// display function for resource labels
function custom_resource_label($r) {
	if ($r->type == 'host') {
		return preg_replace('/^(\w+-\d+)\..*$$/','$1',$r->id);
	}
	return $r->id;
}
////////////////////////////////////////////////////////////////////////////////
// Some classes to handle data
////////////////////////////////////////////////////////////////////////////////

// Storage class for State
class State {
	public $value, $start, $stop;
	function __construct($value, $start, $stop) {
		global $gantt_start_date, $gantt_stop_date;
		$this->value = $value;
		
		$this->start = ($start < $gantt_start_date)?$gantt_start_date:$start;
		$this->stop = (($stop == 0) or ($stop > $gantt_stop_date))?$gantt_stop_date:$stop;
	}
	function svg_text() {
		$output = "State: {$this->value}";
		$output .= "|Since: ".date("r", $this->start);
		$output .= "|Until: ".date("r", $this->stop);
		return $output;
	}
}

// Storage class for jobs
class Job {
	public $job_id,$job_type,$state,$job_user,$command,$queue_name,$moldable_walltime,$properties,$launching_directory,$submission_time,$start_time,$stop_time,$resource_ids,$network_addresses,$types;
	protected $color;
	function __construct($job_id,$job_type,$state,$job_user,$command,$queue_name,$moldable_walltime,$properties,$launching_directory,$submission_time,$start_time,$stop_time) {
		$this->job_id = $job_id;
		$this->job_type = $job_type;
		$this->state = $state;
		$this->job_user = $job_user;
		$this->command = $command;
		$this->queue_name = $queue_name;
		$this->moldable_walltime = $moldable_walltime;
		$this->properties = $properties;
		$this->launching_directory = $launching_directory;
		$this->submission_time = $submission_time;
		$this->start_time = $start_time;
		$this->stop_time = $stop_time;
		$this->resource_ids = array();
		$this->network_addresses = array();
		$this->types = array();
		$this->color = NULL;
	}

	function add_resource_id($resource_id) {
		$this->resource_ids[$resource_id->id] = $resource_id;
	}

	function add_type($type) {
		if (! in_array($type, $this->types)) {
			array_push($this->types, $type);
		}
	}
	function add_network_address($network_address) {
		if (! in_array($network_address, $this->network_addresses)) {
			array_push($this->network_addresses, $network_address);
		}
	}
	function group_resource_ids($resource_ids) {
		$grp = NULL;
		foreach ($resource_ids as $rid) {
			if (array_key_exists($rid->id, $this->resource_ids)) {
				if ($grp == NULL) {
					$grp = new JobResourceIdGroup($this, $rid);
				} else {
					$grp->add_resource_id($rid);
				}
			} else {
				$grp = NULL;
			}
		}
	}
	function svg_text() {
		$output = "Jobid: {$this->job_id}";
		$output .= "|User: {$this->job_user}";
		$output .= "|Kind: {$this->job_type}";
		$output .= "|Queue: {$this->queue_name}";
		$output .= "|Types: ".join(", ",$this->types);
		$output .= "|Walltime: {$this->moldable_walltime}";
		$output .= "|Resources: ".count($this->resource_ids);
		$output .= "|Machines: ".count($this->network_addresses);
		$output .= "|Submission: ".date("r", $this->submission_time);
		$output .= "|Start: ".date("r", $this->start_time);
		$output .= "|Stop: ".(($this->stop_time > 0)?(date("r", $this->start_time)):(date("r", $this->start_time + $this->moldable_walltime)));
		$output .= "|State: {$this->state}";
		//$output .= "|Properties: {$this->properties}";
		return $output;
	}
	function color() {
		if ($this->color == NULL) {
			$this->color = 'rgb('.(rand(128,191)).','.(rand(64,255)).','.(rand(64,255)).')';
		}
		return $this->color;
	}
}

// Container class for a job resource_ids, split wrt the resource_ids display order (resources part and not part of job may be interleaved)
class JobResourceIdGroup {
	public $job, $resource_ids;
	function __construct($job, $resource_id) {
		$this->job = $job;
		$resource_id->add_job_resource_id_group($this);
		$this->resource_ids = array( $resource_id->id => $resource_id );
	}
	function add_resource_id($resource_id) {
		array_push($this->resource_ids, $resource_id);
	}
	function size() {
		return count($this->resource_ids);
	}
}

// Storage class for the resource_ids
class ResourceId {
	public $id, $cpuset, $states, $job_resource_id_groups, $resources, $properties;
	function __construct($id, $cpuset) {
		$this->id = $id;
		$this->cpuset = $cpuset;
		$this->states = array();
		$this->job_resource_id_groups = array();
		$this->resources = array();
		$this->properties = array();
	}
	function add_state($value, $start, $stop) {
		array_push($this->states, new State($value, $start, $stop));
	}
	function add_resource($resource) {
		$this->resources[$resource->type] = $resource;
	}
	function add_property($key, $value) {
		$this->properties[$key] = $value;
		ksort($this->properties);
	}
	function add_job_resource_id_group($job_resource_id_group) {
		array_push($this->job_resource_id_groups, $job_resource_id_group);
	}
	function resource_label($type) {
		if ($type == 'cpuset') {
			return $this->cpuset;
		} else {
			return custom_resource_label($this->resources[$type]);
		}
	}
	function svg_text() {
		$sep = "";
		$output = "";
		foreach ($this->properties as $key => $value) {
			$output .= $sep."{$key}: {$value}";
			$sep = "|";
		}
		return $output;
	}
	function svg_label($y) {
		global $CONF;
		$output = '<text font-size="10" x="'.$CONF['label_right_align'].'" y="'.($y + $CONF['scale']).'" text-anchor="end" onmouseover="mouseOver(evt, \''.$this->svg_text().'\')" onmouseout="mouseOut(evt)" onmousemove="mouseMove(evt)">';
		$labels = array();
		foreach ($CONF['resource_labels'] as $type) {
			array_push($labels, $this->resource_label($type));
		}
		$output .= join("/", $labels);
		$output .= '</text>';
		return $output;
	}
	function svg_lines($y) {
		global $CONF;
		$output .= '<line x1="'.$CONF['gantt_left_align'].'" y1="'.$y.'" x2="'.($CONF['gantt_left_align'] + $CONF['gantt_width']).'" y2="'.$y.'" stroke="'.($this->cpuset?"#888888":"#0000FF").'" stroke-width="1" />';
		return $output;
	}
	function svg_states($y) {
		global $CONF;
		foreach ($this->states as $state) {
			$output .= '<rect x="'.date2px($state->start).'" y="'.$y.'" width="'.(date2px($state->stop) - date2px($state->start)).'" height="'.$CONF['scale'].'" fill="'.$CONF['state_colors'][$state->value].'" stroke="#00FF00" stroke-width="0" style="opacity: 0.75" onmouseover="mouseOver(evt, \''.$state->svg_text().'\')" onmouseout="mouseOut(evt)" onmousemove="mouseMove(evt)" />';
		}
		return $output;
	}
	function svg_jobs($y) {
		global $CONF, $gantt_now;
		foreach ($this->job_resource_id_groups as $grp) {
			if($grp->job->stop_time > 0) {
				$width = date2px($grp->job->stop_time) - date2px($grp->job->start_time);
			} else {
				if (in_array('besteffort', $grp->job->types) and ($grp->job->state == "Running")) {
					$width = date2px($gantt_now) - date2px($grp->job->start_time);
				} else {
					$width = date2px($grp->job->start_time + $grp->job->moldable_walltime) - date2px($grp->job->start_time);
				}
			}
			foreach ($CONF['job_colors'] as $type => $color) {
				if (preg_grep("/^{$type}$/", $grp->job->types)) {
					$output .= '<rect x="'.date2px($grp->job->start_time).'" y="'.$y.'" width="'.$width.'" height="'.($grp->size() * $CONF['scale']).'" fill="'.$color.'" stroke-width="0"  style="opacity: 0.5" />';
				}
			}		
			$output .= '<rect x="'.date2px($grp->job->start_time).'" y="'.$y.'" width="'.$width.'" height="'.($grp->size() * $CONF['scale']).'" fill="'.$grp->job->color().'" stroke="#008800" stroke-width="1"  style="opacity: 0.5" onmouseover="mouseOver(evt,\''.$grp->job->svg_text().'\')" onmouseout="mouseOut(evt)" onmousemove="mouseMove(evt)" />';
			if ($width > $CONF['gantt_min_job_width_for_label']) {
				$output .= '<text font-size="10" x="'.(date2px($grp->job->start_time) + $width / 2).'" y="'.($y + ($grp->size() + 1) * $CONF['scale'] / 2).'" text-anchor="middle" >';
				$output .= $grp->job->job_id;
				$output .= '</text>';
			}
		}
		return $output;
	}
}

// Storage for the abstract resources, e.g. host, cpu, core, a.s.o, i.e. not resource_id
class Resource {
	public $id, $type, $parent, $childs, $resource_ids;
	function __construct($id, $type, $parent) {
		$this->id = $id;
		$this->type = $type;
		$this->parent = $parent;
		$this->childs = array();
		$this->resource_ids = array();
	}
	function add_child($id, $type) {
		if (! array_key_exists($id,$this->childs)) {
			$this->childs[$id] = new Resource($id, $type, $this);
		}
		return $this->childs[$id];
	}
	function add_resource_id($rid) {
		$this->resource_ids[$rid->id] = $rid;
		$rid->add_resource($this);
	}
	function svg_hierarchy_text() {
		if ($this->parent == NULL) {
			return $this->type.": ".$this->id;
		} else {
			return $this->parent->svg_hierarchy_text()."|".$this->type.": ".$this->id;
		}
	}
}


///////////////////////////////////////////////////////////////////////////////
// Retrieve OAR data from database
///////////////////////////////////////////////////////////////////////////////

// Connecting, selecting database
$link = mysql_connect("mysql.$site.grid5000.fr", 'oarreader', 'read')
    or die('Could not connect: ' . mysql_error());
mysql_select_db('oar2') or die('Could not select database');

// Retrieve the "now" date
$query = 'SELECT UNIX_TIMESTAMP()';
$result = mysql_query($query) or die('Query failed: ' . mysql_error());
$array = mysql_fetch_array($result,MYSQL_NUM);
$gantt_now = $array[0];
mysql_free_result($result);

if ($gantt_start_date == 0) {
	$gantt_start_date = $gantt_now - $gantt_relative_start_date;
}
if ($gantt_stop_date == 0) {
	$gantt_stop_date = $gantt_now + $gantt_relative_stop_date;
}

// Retrieve the resource hierarchy 
$resource_root = new Resource($site, 'site', NULL);
$resource_ids = array();

$query = 'SELECT ' . join(',',array_unique(array_merge($CONF['resource_properties'], $CONF['resource_hierarchy'], array('cpuset', 'resource_id')))) . ' FROM resources' . ($resource_filter?' WHERE '.stripslashes($resource_filter):'');
$result = mysql_query($query) or die('Query failed: ' . mysql_error());

while ($line = mysql_fetch_array($result, MYSQL_ASSOC)) {
	$rid = new ResourceId($line['resource_id'], $line['cpuset']);
	foreach ($CONF['resource_properties'] as $rp) {
		$rid->add_property($rp, $line[$rp]);
	}
	$resource_ids[$line['resource_id']] = $rid;
	$resource_root->add_resource_id($rid);
	$r = $resource_root;
	foreach ($CONF['resource_hierarchy'] as $rh) {
		$r = $r->add_child($line[$rh],$rh);
		$r->add_resource_id($rid);
	}
}
mysql_free_result($result);

// sort resource_ids
uasort($resource_ids, "resource_id_sort");

// Retrieve the states of resources
$query = <<<EOT
SELECT resource_id, date_start, date_stop, value
FROM resource_logs
WHERE
	attribute = 'state' AND
	(
	    value = 'Absent' OR
	    value = 'Dead' OR
	    value = 'Suspected'
	) AND
	date_start <= {$gantt_stop_date} AND
	(
	    date_stop = 0 OR
	    date_stop >= {$gantt_start_date}
	)
EOT;
$result = mysql_query($query) or die('Query failed: ' . mysql_error());
while ($line = mysql_fetch_array($result, MYSQL_ASSOC)) {
	if (array_key_exists($line['resource_id'], $resource_ids)) {
		$resource_ids[$line['resource_id']]->add_state($line['value'], $line['date_start'], $line['date_stop']);
	}
}
mysql_free_result($result);

// Array to store jobs
$jobs = array();

// Retrieve past and current jobs 
$query = <<<EOT
SELECT 
	jobs.job_id,
	jobs.job_type,
	jobs.state,
	jobs.job_user,
	jobs.command,
	jobs.queue_name,
	moldable_job_descriptions.moldable_walltime,
	jobs.properties,
	jobs.launching_directory,
	jobs.submission_time,
	jobs.start_time,
	jobs.stop_time,
	assigned_resources.resource_id,
	resources.network_address,
	job_types.type
FROM 
	(jobs, assigned_resources, moldable_job_descriptions, resources) LEFT JOIN job_types ON (job_types.job_id = jobs.job_id)
WHERE
	( jobs.stop_time >= {$gantt_start_date} OR
		( jobs.stop_time = '0' AND 
			( jobs.state = 'Running' OR
			jobs.state = 'Suspended' OR
			jobs.state = 'Resuming'
			)
		)
	) AND
	jobs.start_time < {$gantt_stop_date} AND
	jobs.assigned_moldable_job = assigned_resources.moldable_job_id AND
	moldable_job_descriptions.moldable_job_id = jobs.job_id AND
	resources.resource_id = assigned_resources.resource_id
ORDER BY 
	jobs.job_id
EOT;
$result = mysql_query($query) or die('Query failed: ' . mysql_error());
while ($line = mysql_fetch_array($result, MYSQL_ASSOC)) {
	if (! array_key_exists($line['job_id'], $jobs)) {
		$jobs[$line['job_id']] = new Job($line['job_id'], $line['job_type'], $line['state'], $line['job_user'], $line['command'], $line['queue_name'], $line['moldable_walltime'], $line['properties'], $line['launching_directory'], $line['submission_time'], $line['start_time'], $line['stop_time']);
	}
	if (array_key_exists($line['resource_id'], $resource_ids)) {
		$jobs[$line['job_id']]->add_resource_id($resource_ids[$line['resource_id']]);
	} else {
		// create new resource_id so than the job gets the right resource_id count, even if that resource_id is not diplayed in the grid... (filter)
		$jobs[$line['job_id']]->add_resource_id(new ResourceId($line['resource_id'], -1));
	}
	$jobs[$line['job_id']]->add_network_address($line['network_address']);
	$jobs[$line['job_id']]->add_type($line['type']);
}
mysql_free_result($result);

// Retrieve predicted jobs (future)
$query = <<<EOT
SELECT 
	jobs.job_id,
	jobs.job_type,
	jobs.state,
	jobs.job_user,
	jobs.command,
	jobs.queue_name,
	moldable_job_descriptions.moldable_walltime,
	jobs.properties,
	jobs.launching_directory,
	jobs.submission_time,
	gantt_jobs_predictions_visu.start_time,
	jobs.stop_time,
	gantt_jobs_resources_visu.resource_id,
	resources.network_address,
	job_types.type
FROM 
	(jobs, moldable_job_descriptions, gantt_jobs_resources_visu, gantt_jobs_predictions_visu, resources) LEFT JOIN job_types ON (job_types.job_id = jobs.job_id)
WHERE
	gantt_jobs_predictions_visu.moldable_job_id = gantt_jobs_resources_visu.moldable_job_id AND
	gantt_jobs_predictions_visu.moldable_job_id = moldable_job_descriptions.moldable_id AND
	jobs.job_id = moldable_job_descriptions.moldable_job_id AND
	gantt_jobs_predictions_visu.start_time < {$gantt_stop_date} AND
	resources.resource_id = gantt_jobs_resources_visu.resource_id AND
	gantt_jobs_predictions_visu.start_time + moldable_job_descriptions.moldable_walltime >= {$gantt_start_date} AND
	jobs.job_id NOT IN ( SELECT job_id FROM job_types WHERE type = 'besteffort' AND types_index = 'CURRENT' ) AND
	job_types.job_id = jobs.job_id
ORDER BY 
	jobs.job_id
EOT;
$result = mysql_query($query) or die('Query failed: ' . mysql_error());
while ($line = mysql_fetch_array($result, MYSQL_ASSOC)) {
	if (! array_key_exists($line['job_id'], $jobs)) {
		$jobs[$line['job_id']] = new Job($line['job_id'], $line['job_type'], $line['state'], $line['job_user'], $line['command'], $line['queue_name'], $line['moldable_walltime'], $line['properties'], $line['launching_directory'], $line['submission_time'], $line['start_time'], $line['stop_time']);
	}
	if (array_key_exists($line['resource_id'], $resource_ids)) {
		$jobs[$line['job_id']]->add_resource_id($resource_ids[$line['resource_id']]);
	} else {
		// create new resource_id so than the job gets the right resource_id count, even if that resource_id is not displayed in the grid... (filter)
		$jobs[$line['job_id']]->add_resource_id(new ResourceId($line['resource_id'], -1));
	}	
	$jobs[$line['job_id']]->add_network_address($line['network_address']);
	$jobs[$line['job_id']]->add_type($line['type']);
}
mysql_free_result($result);

// Split resource_ids for jobs in groups for gantt display: resources which belong to the job may be interleaved with resources which don't
foreach ($jobs as $job) {
	$job->group_resource_ids($resource_ids);
}

// Closing connection to the database
mysql_close($link);

///////////////////////////////////////////////////////////////////////////////
// SVG document generation
///////////////////////////////////////////////////////////////////////////////

// compute page size
$page_height = $CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + $CONF['bottom_margin'];
$page_width = $CONF['gantt_left_align'] + $CONF['gantt_width'] + $CONF['right_margin'];

// begin SVG doc + script + texture patterns
$output = <<<EOT
<?xml version="1.0" standalone="no"?>
<svg width="{$page_width}px" height="{$page_height}px" viewBox="0 0 {$page_width} {$page_height}" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:ev="http://www.w3.org/2001/xml-events" xml:space="preserve" zoomAndPan="magnify" onload="init(evt)" color-rendering="optimizeSpeed" image-rendering="optimizeSpeed" text-rendering="optimizeSpeed" shape-rendering="optimizeSpeed" onmousedown="rootMouseDown(evt)" onmouseup="rootMouseUp(evt)" onmousemove="rootMouseMove(evt)" >

<script type="text/ecmascript"><![CDATA[
var svgDocument;
var infobox, infoboxtext, infoboxrect;
var timeruler;
var zoom, zoom_do, zoom_x1, zoom_x2, zoom_y1, zoom_y2;
function init(evt) {
	if ( window.svgDocument == null ) {
		svgDocument = evt.target.ownerDocument;
	} else {
		svgDocument = window.svgDocument;
	}
	infobox = svgDocument.getElementById("infobox");
  infoboxrect = svgDocument.getElementById("infoboxrect");
  infoboxtext = svgDocument.getElementById("infoboxtext");
	timeruler=svgDocument.getElementById("timeruler");
	zoom = svgDocument.getElementById("zoom");
	zoom_x1 = 0;
	zoom_x2 = 0;
	zoom_y1 = 0;
	zoom_y2 = 0;
	window.addEventListener("scroll", drawTimeRuler, false);
	window.addEventListener("resize", drawTimeRuler, false);
	drawTimeRuler();
}
function zoomDraw() {
	zoom.setAttribute("x", Math.min(zoom_x1,zoom_x2));
	zoom.setAttribute("y", Math.min(zoom_y1,zoom_y2));
	zoom.setAttribute("width", Math.abs(zoom_x2 - zoom_x1));
	zoom.setAttribute("height", Math.abs(zoom_y2 - zoom_y1));
	zoom.setAttribute("visibility", "visible");
}
function rootMouseDown(evt) {
	zoom_x1 = evt.pageX;
	zoom_y1 = evt.pageY;
	zoom_x2 = zoom_x1;
	zoom_y2 = zoom_y1;
	zoom_do = true;
}
function rootMouseUp(evt) {
	zoom_do = false;
	zoom.setAttribute("visibility", "hidden");
	//svgDocument.rootElement.setAttribute("viewBox", Math.min(zoom_x1,zoom_x2) + " " + Math.min(zoom_y1,zoom_y2) + " " + Math.abs(zoom_x2 - zoom_x1) + " " + Math.abs(zoom_y2 - zoom_y1));
	//svgDocument.rootElement.setAttribute("width", window.innerWidth);
	//svgDocument.rootElement.setAttribute("height", window.innerHeight);
}
function rootMouseMove(evt) {
	if (zoom_do) {
		zoom_x2 = evt.pageX;
		zoom_y2 = evt.pageY;
		zoomDraw();
	}
}
function drawTimeRuler(evt) {
	if ({$page_height} > window.innerHeight) {
		timeruler.setAttribute("transform","translate(0," + (window.scrollY + window.innerHeight - 45) + ")");
		timeruler.setAttribute("display", "inline");
	} else {
		timeruler.setAttribute("display", "none");
	}
}
function mouseOver(evt, message) {
  var length = 0;
  var array;
  var i = 0;
  var tspan;
	while (infoboxtext.hasChildNodes()) { 
		infoboxtext.removeChild(infoboxtext.lastChild);
	}
  array = message.split("|");
	infobox.setAttribute("display", "inline");
  for (i in array) {
    tspan = svgDocument.createElementNS("http://www.w3.org/2000/svg","tspan");
    tspan.setAttribute("x",10);
    tspan.setAttribute("dy",10);
    tspan.appendChild(svgDocument.createTextNode(array[i]));  
    infoboxtext.appendChild(tspan);
    length = Math.max(length, tspan.getComputedTextLength());
  }
  infoboxrect.setAttribute("width", length + 20);
  infoboxrect.setAttribute("height", array.length * {$CONF['scale']} + 20);
}
function mouseOut(evt) {
	infobox.setAttribute("display", "none");
}
function mouseMove(evt) {
	var width=parseInt(infoboxrect.getAttribute("width")); 
	var height=parseInt(infoboxrect.getAttribute("height")); 
	var x,y;
	if ((evt.pageX + 10 + width) < {$page_width}) {
		x = (evt.pageX + 10);
	} else {
		x = ({$page_width} - width);
	}
	if ((evt.pageY + 20 + height) < Math.min({$page_height}, window.scrollY + window.innerHeight)) {
		y = (evt.pageY + 20);
	} else {
		y = (evt.pageY - height - 5 );
	}
	infobox.setAttribute("transform", "translate(" + x + "," + y + ")");
}
]]></script>

<defs>
<pattern id="besteffortPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<text font-size="10" x="0" y="10" fill="#888888">B</text>
</pattern> 
<pattern id="containerPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<text font-size="10" x="0" y="20" fill="#888888">C</text>
</pattern> 
<pattern id="deployPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<text font-size="10" x="10" y="10" fill="#888888">D</text>
</pattern> 
<pattern id="timesharingPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" viewBox="0 0 20 20" >
<text font-size="10" x="10" y="20" fill="#888888">T</text>
</pattern> 
<pattern id="suspectedPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="5" height="5" viewBox="0 0 5 5" >
<line x1="5" y1="0" x2="0" y2="5" stroke="#ff8080" stroke-width="2" />
</pattern> 
<pattern id="absentPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="5" height="5" viewBox="0 0 5 5" >
<line x1="5" y1="0" x2="0" y2="5" stroke="#ff0000" stroke-width="2" />
</pattern> 
<pattern id="deadPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="5" height="5" viewBox="0 0 5 5" >
<line x1="5" y1="0" x2="0" y2="5" stroke="#000000" stroke-width="2" />
</pattern> 
</defs>
EOT;

// print gantt border
$output .= '<rect x="'.$CONF['gantt_left_align'].'" y="'.$CONF['gantt_top'].'" width="'.$CONF['gantt_width'].'" height="'.count($resource_ids) * $CONF['scale'].'" stroke="#0000FF" stroke-width="1" fill="#FFFFFF" />';

// print top time ruler
$output .= '<text font-size="10" x="'.$CONF['gantt_left_align'].'" y="'.($CONF['gantt_top'] - 15).'" text-anchor="start" >'.date("Y-m-d",$gantt_start_date).'</text>';
$output .= '<text font-size="10" x="'.$CONF['gantt_left_align'].'" y="'.($CONF['gantt_top'] - 5).'" text-anchor="start" >'.date("H:i:s",$gantt_start_date).'</text>';
$output .= '<text font-size="10" x="'.($CONF['gantt_left_align'] + $CONF['gantt_width']).'" y="'.($CONF['gantt_top'] - 15).'" text-anchor="end" >'.date("Y-m-d",$gantt_stop_date).'</text>';
$output .= '<text font-size="10" x="'.($CONF['gantt_left_align'] + $CONF['gantt_width']).'" y="'.($CONF['gantt_top'] - 5).'" text-anchor="end" >'.date("H:i:s",$gantt_stop_date).'</text>';

for($i=1;$i<($CONF['time_ruler_scale']);$i++) {
	$d = $gantt_start_date + $i * ($gantt_stop_date - $gantt_start_date) / ($CONF['time_ruler_scale']);
	$output .= '<text font-size="10" x="'.date2px($d).'" y="'.($CONF['gantt_top'] - 15).'" text-anchor="middle" >'.date("Y-m-d",$d).'</text>';
	$output .= '<text font-size="10" x="'.date2px($d).'" y="'.($CONF['gantt_top'] - 5).'" text-anchor="middle" >'.date("H:i:s",$d).'</text>';
}

// print bottom time ruler
$output .= '<text font-size="10" x="'.($CONF['gantt_left_align'] + $CONF['gantt_width']).'" y="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 25).'" text-anchor="end" >'.date("Y-m-d",$gantt_stop_date).'</text>';
$output .= '<text font-size="10" x="'.($CONF['gantt_left_align'] + $CONF['gantt_width']).'" y="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 15).'" text-anchor="end" >'.date("H:i:s",$gantt_stop_date).'</text>';
$output .= '<text font-size="10" x="'.$CONF['gantt_left_align'].'" y="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 25).'" text-anchor="start" >'.date("Y-m-d",$gantt_start_date).'</text>';
$output .= '<text font-size="10" x="'.$CONF['gantt_left_align'].'" y="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 15).'" text-anchor="start" >'.date("H:i:s",$gantt_start_date).'</text>';

for($i=1;$i<($CONF['time_ruler_scale']);$i++) {
	$d = $gantt_start_date + $i * ($gantt_stop_date - $gantt_start_date) / ($CONF['time_ruler_scale']);
	$output .= '<text font-size="10" x="'.date2px($d).'" y="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 25).'" text-anchor="middle" >'.date("Y-m-d",$d).'</text>';
	$output .= '<text font-size="10" x="'.date2px($d).'" y="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 15).'" text-anchor="middle" >'.date("H:i:s",$d).'</text>';
}

// print time grid lines
for($i=1;$i<($CONF['time_ruler_scale']);$i++) {
	$d = $gantt_start_date + $i * ($gantt_stop_date - $gantt_start_date) / ($CONF['time_ruler_scale']);
	$output .= '<line x1="'.date2px($d).'" y1="'.($CONF['gantt_top'] - 5).'" x2="'.date2px($d).'" y2="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 5).'" stroke="#0000FF" stroke-width="1" />';
}

// print resource_id labels
$y = $CONF['gantt_top'];
foreach ($resource_ids as $rid) {
	$output .= $rid->svg_label($y);
	$y += $CONF['scale'];
}

// print resource hierarchy
$x = $CONF['hierarchy_left_align'];
foreach ($CONF['resource_hierarchy'] as $rh) {
	$r0 = NULL;
	$y0 = $CONF['gantt_top'];
	$y = $y0;
	foreach ($resource_ids as $rid) {
		if (($r0 != NULL) and ($rid->resources[$rh]->id != $r0->id)) {
			$output .= '<rect x="'.$x.'" y="'.$y0.'" width="'.$CONF['hierarchy_resource_width'].'" height="'.($y-$y0).'" fill="#ffff80" stroke="#000000" stroke-width="1" style="opacity: 1" onmouseover="mouseOver(evt, \''.$r0->svg_hierarchy_text().'\')" onmouseout="mouseOut(evt)" onmousemove="mouseMove(evt)" />';
			$y0 = $y;
		}		
		$r0 = $rid->resources[$rh]; 
		$y += $CONF['scale'];
	}
	if ($r0) {
		$output .= '<rect x="'.$x.'" y="'.$y0.'" width="'.$CONF['hierarchy_resource_width'].'" height="'.($y-$y0).'" fill="#ffff80" stroke="#000000" stroke-width="1" style="opacity: 1" onmouseover="mouseOver(evt, \''.$r0->svg_hierarchy_text().'\')" onmouseout="mouseOut(evt)" onmousemove="mouseMove(evt)" />';
	$x += $CONF['scale'];
	}
}

// print resource_id lines
$y = $CONF['gantt_top'];
foreach ($resource_ids as $rid) {
	$output .= $rid->svg_lines($y);
	$y += $CONF['scale'];
}

// print resource states
$y = $CONF['gantt_top'];
foreach ($resource_ids as $rid) {
	$output .= $rid->svg_states($y);
	$y += $CONF['scale'];
}

// print jobs
$y = $CONF['gantt_top'];
foreach ($resource_ids as $rid) {
	$output .= $rid->svg_jobs($y);
	$y += $CONF['scale'];
}

// print mobile time ruler
$output .= '<g id="timeruler" display="none">';
$output .= '<rect x="'.($CONF['gantt_left_align'] - 5).'" y="0" width="'.($CONF['gantt_width'] + 10).'" height="30" stroke="#000000" stroke-width="1" fill="#FFFFFF" style="opacity: 0.5"/>';
$output .= '<text font-size="10" x="'.$CONF['gantt_left_align'].'" y="25" text-anchor="start" >'.date("Y-m-d",$gantt_start_date).'</text>';
$output .= '<text font-size="10" x="'.$CONF['gantt_left_align'].'" y="15" text-anchor="start" >'.date("H:i:s",$gantt_start_date).'</text>';
$output .= '<text font-size="10" x="'.($CONF['gantt_left_align'] + $CONF['gantt_width']).'" y="25" text-anchor="end" >'.date("Y-m-d",$gantt_stop_date).'</text>';
$output .= '<text font-size="10" x="'.($CONF['gantt_left_align'] + $CONF['gantt_width']).'" y="15" text-anchor="end" >'.date("H:i:s",$gantt_stop_date).'</text>';

for($i=1;$i<($CONF['time_ruler_scale']);$i++) {
	$d = $gantt_start_date + $i * ($gantt_stop_date - $gantt_start_date) / ($CONF['time_ruler_scale']);
	$output .= '<text font-size="10" x="'.date2px($d).'" y="25" text-anchor="middle" >'.date("Y-m-d",$d).'</text>';
	$output .= '<text font-size="10" x="'.date2px($d).'" y="15" text-anchor="middle" >'.date("H:i:s",$d).'</text>';
}
$output .= '</g>';

// print now line
$output .= '<line x1="'.date2px($gantt_now).'" y1="'.($CONF['gantt_top'] - 5).'" x2="'.date2px($gantt_now).'" y2="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 5).'" stroke="#FF0000" stroke-width="2" />';

// end SVG doc
$output .=  <<<EOT
<g id="infobox" display="none">
<rect id="infoboxrect" x="0" y="0" rx="10" ry="10" width="200" height="150" fill="#FFFFFF" stroke="#888888" stroke-width="1" style="opacity: 0.9" />
<text font-size="10" id="infoboxtext" x="10" y="10" fill="#000000" />
</g>
<rect x="0" y="0" width="0" height="0" id="zoom" stroke="#0000FF" stroke-width="1" fill="#8888FF" style="opacity: 0.25" visibility="hidden" />
</svg>
EOT;

header("Content-Type: image/svg+xml");
header('Content-Encoding: gzip');
print gzencode($output);

?>
