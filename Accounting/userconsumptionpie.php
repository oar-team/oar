<?php
include("dbfunctions.inc");
require_once("/usr/share/jpgraph/jpgraph.php");
require_once("/usr/share/jpgraph/jpgraph_pie.php");
require_once("/usr/share/jpgraph/jpgraph_pie3d.php");

$link = dbconnect();

$graph = new PieGraph(650,450,"User usage",720);

$query = <<<EOF
SELECT
        user, SUM(consumption) as somme
FROM
        accounting
WHERE
        consumption_type='USED'
        AND DATE_SUB(NOW(), INTERVAL 7 DAY) <= window_start
GROUP BY
        user
ORDER BY
        somme DESC
LIMIT 10
EOF;

list($res,$nb) = sqlquery($query,$link);
$data = array();
$legend = array();

for ($i = 0; $i < $nb; $i++) {
	$data[$i] = $res[$i][1];
	$legend[$i] = $res[$i][0]." ". $data[$i] ."s";
}

if ($nb != 0) {

	$graph->title->Set("User consumption");
	$graph->title->SetFont(FF_FONT1,FS_BOLD);

	$p1 = new PiePlot3D($data);
//	$p1->SetSize(0.4);
//	$p1->SetCenter(0.35,0.65);
//	$p1->SetTheme("sand");
	$p1->SetLegends($legend);

	$graph->Add($p1);
	$graph->Stroke();
}
else {
	$graph->title->Set("no event recorded on clusters");
	$graph->Stroke();
}

mysql_close($link);
?>

