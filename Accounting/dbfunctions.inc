<?php

function dbconnect() {
    if (!@function_exists('mysql_connect')) {
        @dl('mysql.so');
    }
    $link = mysql_connect("localhost", "reader", "read")
        or die("Connection failed : " . mysql_error());
    mysql_select_db("oar",$link) or die( "Connection failed : " . mysql_error());
    return $link;
}

function sqlquery($query,$link) {
	$nb=0;
	$result = mysql_query($query,$link);
	$return_array = array();
	while ($row = mysql_fetch_array($result)) {
		$nb= array_push($return_array, $row);
	}
	mysql_free_result($result);
	return array ($return_array, $nb);
}
?>
