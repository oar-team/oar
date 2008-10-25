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

////////////////////////////////////////////////////////////////////////////////
// Configuration
////////////////////////////////////////////////////////////////////////////////

$CONF=array();
$CONF['hierarchy_resource_width'] = 10;
$CONF['scale'] = 10;
$CONF['time_ruler_scale'] = 5;
$CONF['gantt_top'] = 30;
$CONF['bottom_margin'] = 30;
$CONF['right_margin'] = 10;
$CONF['label_right_align'] = 105;
$CONF['hierarchy_left_align'] = 110;
$CONF['gantt_left_align'] = 160;
$CONF['gantt_width'] = 800;
$CONF['gantt_min_job_width_for_label'] = 50;
$CONF['resource_hierarchy'] = array('cluster','host','cpu','core');
$CONF['resource_labels'] = array('host','cpuset');
//$CONF['colors'] = array('Absent' => '#C62000', 'Suspected' => '#FF8080', 'Dead' => '#FF0000');
$CONF['colors'] = array('Absent' => 'url(#absentPattern)', 'Suspected' => 'url(#suspectedPattern)', 'Dead' => 'url(#deadPattern)');

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
//	preg_match($regex, $resource_ids[$r1]->resources['host']->id, $m1);
//	preg_match($regex, $resource_ids[$r2]->resources['host']->id, $m2);
//	return ($m1[1] > $m2[1]) or (($m1[1] == $m2[1]) and ($m1[2] > $m2[2])) or (($m1[1] == $m2[1]) and ($m1[2] == $m2[2]) and ($resource_ids[$r1]->cpuset > $resource_ids[$r2]->cpuset));
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
}

// Storage class for jobs
class Job {
	public $job_id,$job_type,$state,$job_user,$command,$queue_name,$moldable_walltime,$properties,$launching_directory,$submission_time,$start_time,$stop_time,$resource_ids,$network_addresses;
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
		$this->color = NULL;
	}

	function add_resource_id($resource_id) {
		$this->resource_ids[$resource_id->id] = $resource_id;
	}

	function add_network_address($network_address) {
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
	public $id, $cpuset, $states, $job_resource_id_groups, $resources;
	function __construct($id, $cpuset) {
		$this->id = $id;
		$this->cpuset = $cpuset;
		$this->states = array();
		$this->job_resource_id_groups = array();
		$this->resources = array();
	}
	function add_state($value, $start, $stop) {
		array_push($this->states, new State($value, $start, $stop));
	}
	function add_resource($resource) {
		$this->resources[$resource->type] = $resource;
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
	function svg_label($y) {
		global $CONF;
		$output = '<text x="'.$CONF['label_right_align'].'" y="'.($y + $CONF['scale']).'" text-anchor="end">';
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
			$output .= '<rect x="'.date2px($state->start).'" y="'.$y.'" width="'.(date2px($state->stop) - date2px($state->start)).'" height="'.$CONF['scale'].'" fill="'.$CONF['colors'][$state->value].'" stroke="#00FF00" stroke-width="0" style="opacity: 0.75" onmouseover="mouseOver(evt, \''.$state->value.'\')" onmouseout="mouseOut(evt)" onmousemove="mouseMove(evt)" />';
		}
		return $output;
	}
	function svg_jobs($y) {
		global $CONF;
		foreach ($this->job_resource_id_groups as $grp) {
			$width = (date2px($grp->job->stop_time) - date2px($grp->job->start_time));
			$output .= '<rect x="'.date2px($grp->job->start_time).'" y="'.$y.'" width="'.$width.'" height="'.($grp->size() * $CONF['scale']).'" fill="'.$grp->job->color().'" stroke="#008800" stroke-width="1"  style="opacity: 0.5" onmouseover="mouseOver(evt,\''.$grp->job->job_id.'\')" onmouseout="mouseOut(evt)" onmousemove="mouseMove(evt)" />';
			if ($width > $CONF['gantt_min_job_width_for_label']) {
				$output .= '<text x="'.(date2px($grp->job->start_time) + (date2px($grp->job->stop_time) - date2px($grp->job->start_time)) / 2).'" y="'.($y + ($grp->size() + 1) * $CONF['scale'] / 2).'" text-anchor="middle" >';
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
	function svg_hierarchy_label() {
		if ($this->parent == NULL) {
			return $this->id;
		} else {
			return $this->parent->svg_hierarchy_label()."/".$this->id;
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

$query = 'SELECT ' . join(',',$CONF['resource_hierarchy']) . ',cpuset, resource_id FROM resources';
$result = mysql_query($query) or die('Query failed: ' . mysql_error());

while ($line = mysql_fetch_array($result, MYSQL_ASSOC)) {
	$rid = new ResourceId($line['resource_id'], $line['cpuset']);
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
	$resource_ids[$line['resource_id']]->add_state($line['value'], $line['date_start'], $line['date_stop']);
}
mysql_free_result($result);

// Retrieve predicted jobs (future)
$jobs = array();
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
	(gantt_jobs_predictions_visu.start_time + moldable_job_descriptions.moldable_walltime) AS stop_time,
	gantt_jobs_resources_visu.resource_id,
	resources.network_address
FROM 
	jobs, moldable_job_descriptions, gantt_jobs_resources_visu, gantt_jobs_predictions_visu, resources
WHERE
	gantt_jobs_predictions_visu.moldable_job_id = gantt_jobs_resources_visu.moldable_job_id AND
	gantt_jobs_predictions_visu.moldable_job_id = moldable_job_descriptions.moldable_id AND
	jobs.job_id = moldable_job_descriptions.moldable_job_id AND
	gantt_jobs_predictions_visu.start_time < {$gantt_stop_date} AND
	resources.resource_id = gantt_jobs_resources_visu.resource_id AND
	gantt_jobs_predictions_visu.start_time + moldable_job_descriptions.moldable_walltime >= {$gantt_start_date} AND
	jobs.job_id NOT IN ( SELECT job_id FROM job_types WHERE type = 'besteffort' AND types_index = 'CURRENT' )
ORDER BY 
	jobs.job_id
EOT;
$result = mysql_query($query) or die('Query failed: ' . mysql_error());
while ($line = mysql_fetch_array($result, MYSQL_ASSOC)) {
	if (! array_key_exists($line['job_id'], $jobs)) {
		$jobs[$line['job_id']] = new Job($line['job_id'], $line['job_type'], $line['state'], $line['job_user'], $line['command'], $line['queue_name'], $line['moldable_walltime'], $line['properties'], $line['launching_directory'], $line['submission_time'], $line['start_time'], $line['stop_time']);
	}
	$jobs[$line['job_id']]->add_resource_id($resource_ids[$line['resource_id']]);
	$jobs[$line['job_id']]->add_network_address($line['network_address']);
}
mysql_free_result($result);

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
	resources.network_address
FROM 
	jobs, assigned_resources, moldable_job_descriptions, resources
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
	$jobs[$line['job_id']]->add_resource_id($resource_ids[$line['resource_id']]);
	$jobs[$line['job_id']]->add_network_address($line['network_address']);
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
$page_width = $CONF['gantt_left_align'] + $CONF['gantt_width'] + $CONF['right_margin'] + 100;

// begin SVG doc + script + texture patterns
$output = <<<EOT
<?xml version="1.0" standalone="no"?>
<svg width="{$page_width}px" height="{$page_height}px" viewBox="0 0 {$page_width} {$page_height}" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xml:space="preserve" zoomAndPan="disable" onload="init(evt)" color-rendering="optimizeSpeed" image-rendering="optimizeSpeed" text-rendering="optimizeSpeed" shape-rendering="optimizeSpeed" >

<script type="text/ecmascript"><![CDATA[
var svgDocument;
var infobox;
function init(evt) {
	if ( window.svgDocument == null ) {
		svgDocument = evt.target.ownerDocument;
	}
}
function mouseOver(evt, text) {
	infobox = svgDocument.getElementById("infobox");
	infobox.setAttribute("visibility", "visible");
	infobox.firstChild.data = text;
}
function mouseOut(evt) {
	infobox = svgDocument.getElementById("infobox");
	infobox.setAttribute("visibility", "hidden");
	infobox.firstChild.data = "infobox";
}
function mouseMove(evt) {
	infobox = svgDocument.getElementById("infobox");
	infobox.setAttribute("x", evt.pageX + 5);
	infobox.setAttribute("y", evt.pageY + 30);
}
]]></script>

<defs>
<pattern id="suspectedPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="5" height="5" viewBox="0 0 5 5" >
<line x1="0" y1="0" x2="5" y2="5" stroke="#c62000" stroke-width="2" />
</pattern> 
<pattern id="absentPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="5" height="5" viewBox="0 0 5 5" >
<line x1="0" y1="0" x2="5" y2="5" stroke="#ff8080" stroke-width="2" />
</pattern> 
<pattern id="deadPattern" patternUnits="userSpaceOnUse" x="0" y="0" width="5" height="5" viewBox="0 0 5 5" >
<line x1="0" y1="0" x2="5" y2="5" stroke="#ff0000" stroke-width="2" />
</pattern> 
</defs>
EOT;

// print gantt border
$output .= '<rect x="'.$CONF['gantt_left_align'].'" y="'.$CONF['gantt_top'].'" width="'.$CONF['gantt_width'].'" height="'.count($resource_ids) * $CONF['scale'].'" stroke="#0000FF" stroke-width="1" fill="#FFFFFF" />';
// print start datetime label, bottom and top
$output .= '<text x="'.$CONF['gantt_left_align'].'" y="'.($CONF['gantt_top'] - 15).'" text-anchor="start" >'.date("Y-m-d",$gantt_start_date).'</text>';
$output .= '<text x="'.$CONF['gantt_left_align'].'" y="'.($CONF['gantt_top'] - 5).'" text-anchor="start" >'.date("H:i:s",$gantt_start_date).'</text>';
$output .= '<text x="'.$CONF['gantt_left_align'].'" y="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 20).'" text-anchor="start" >'.date("Y-m-d",$gantt_start_date).'</text>';
$output .= '<text x="'.$CONF['gantt_left_align'].'" y="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 10).'" text-anchor="start" >'.date("H:i:s",$gantt_start_date).'</text>';
// print stop datetime label, bottom and top
$output .= '<text x="'.($CONF['gantt_left_align'] + $CONF['gantt_width']).'" y="'.($CONF['gantt_top'] - 15).'" text-anchor="end" >'.date("Y-m-d",$gantt_stop_date).'</text>';
$output .= '<text x="'.($CONF['gantt_left_align'] + $CONF['gantt_width']).'" y="'.($CONF['gantt_top'] - 5).'" text-anchor="end" >'.date("H:i:s",$gantt_stop_date).'</text>';
$output .= '<text x="'.($CONF['gantt_left_align'] + $CONF['gantt_width']).'" y="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 20).'" text-anchor="end" >'.date("Y-m-d",$gantt_stop_date).'</text>';
$output .= '<text x="'.($CONF['gantt_left_align'] + $CONF['gantt_width']).'" y="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 10).'" text-anchor="end" >'.date("H:i:s",$gantt_stop_date).'</text>';

// print time in between, bottom and top
for($i=1;$i<($CONF['time_ruler_scale']);$i++) {
	$d = $gantt_start_date + $i * ($gantt_stop_date - $gantt_start_date) / ($CONF['time_ruler_scale']);
	$output .= '<text x="'.date2px($d).'" y="'.($CONF['gantt_top'] - 10).'" text-anchor="middle" >'.date("H:i:s",$d).'</text>';
	$output .= '<text x="'.date2px($d).'" y="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 15).'" text-anchor="middle" >'.date("H:i:s",$d).'</text>';
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
			$output .= '<rect x="'.$x.'" y="'.$y0.'" width="'.$CONF['hierarchy_resource_width'].'" height="'.($y-$y0).'" fill="#ffff80" stroke="#000000" stroke-width="1" style="opacity: 1" onmouseover="mouseOver(evt, \''.$r0->svg_hierarchy_label().'\')" onmouseout="mouseOut(evt)" onmousemove="mouseMove(evt)" />';
			$y0 = $y;
		}		
		$r0 = $rid->resources[$rh]; 
		$y += $CONF['scale'];
	}
	$output .= '<rect x="'.$x.'" y="'.$y0.'" width="'.$CONF['hierarchy_resource_width'].'" height="'.($y-$y0).'" fill="#ffff80" stroke="#000000" stroke-width="1" style="opacity: 1" onmouseover="mouseOver(evt, \''.$r0->svg_hierarchy_label().'\')" onmouseout="mouseOut(evt)" onmousemove="mouseMove(evt)" />';
	$x += $CONF['scale'];
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

// print now line
$output .= '<line x1="'.date2px($gantt_now).'" y1="'.($CONF['gantt_top'] - 5).'" x2="'.date2px($gantt_now).'" y2="'.($CONF['gantt_top'] + count($resource_ids) * $CONF['scale'] + 5).'" stroke="#FF0000" stroke-width="2" />';

// end SVG doc
$output .=  <<<EOT
<text x="0" y="10" id="infobox" fill="#008800" visibility="hidden" >infobox</text>
</svg>
EOT;

header("Content-Type: image/svg+xml");
print $output;

?>
