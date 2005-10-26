#!/usr/bin/perl
# $Id: DrawOARGantt.pl,v 1.6 2005/10/04 16:35:29 capitn Exp $
#
# requirements : 
# 	libgd1 or libgd2
# 	libgd-perl
# 	libgd-text-perl
#	oar_conflib
#

use GD;
use GD::Text::Align;
use CGI qw/:standard/;
use POSIX qw(strftime);
use Time::Local;

use oar_conflib qw(init_conf get_conf is_conf);                                                                                                

#nb of month
my %mon=( 'Jan'=>'0','Feb'=>'1','Mar'=>'2','Apr'=>'3','May'=>'4',
       'Jun'=>'5','Jul'=>'6','Aug'=>'7','Sep'=>'8','Oct'=>'9',
       'Nov'=>'10','Dec'=>'11');

my %litteral_month = ( '0'=>'Jan','1'=>'Feb','2'=>'Mar','3'=>'Apr','4'=>'May',
			'5'=>'Jun','6'=>'Jul','7'=>'Aug','8'=>'Sep','9'=>'Oct',
			'10'=>'Nov','11'=>'Dec');

#name of afterday
my %daysuc = ('Sun'=>'Mon','Mon'=>'Tue','Tue'=>'Wed','Wed'=>'Thu',
	'Thu'=>'Fri','Fri'=>'Sat','Sat'=>'Sun');
	
my @wday = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');

#nb of sec in a range 
my %range_sec = ('1/6 day'=>14400,'1/2 day'=>43200,'1 day'=>86400,'3 days'=>259200,
		'week'=>604800,'month'=>2678400,'year'=>31622400);

my %range_step = ('1/6 day'=>3600,'1/2 day'=>10800,'1 day'=>43200,'3 days'=>86400,
		'week'=>345600,'month'=>604800);
		
my %zoom_in = ('1/6 day'=>'1/6 day','1/2 day'=>,'1/6 day','1 day'=>'1/2 day','3 days'=>'1 day',
		'week'=>'3 days','month'=>'week');
my %zoom_out =('1/6 day'=>,'1/2 day','1/2 day'=>'1 day','1 day'=>'3 days','3 days'=>'week',
		'week'=>'month','month'=>'month');
		
# Field Number of Job_Info 
$f_jobid = 0;
$f_jobtype = 1;
$f_jobuser = 2;
$f_jobstate =3;
$f_jobcmd = 4;
$f_jobproperty = 5;
$f_jobsubmission = 6;
#$f_jobsubmission_cont = 7;
$f_jobqueue = 7;
$f_begin = 8;
#$f_begin_cont = 10;
$f_end = 9;
#$f_end_cont = 12;
$f_node = 10; 

#############################################################
#
#configuration setting	
#TODO: Seperate config file as oar_conflib.pm
#
#############################################################
	     
my $sizex = 800;
my $sizey = 400;
my $offsetgridy = 20;
my $offsetgridx = 100;

my $font = 'times'; #'arial'
my $font_size = 20;

my $offsetx= 10;
my $gap = 2;

my $title = 'Gantt Chart';


#Default setting for BestEffort Job Drawing 
#my $drawBestEffort = 'BestEffort';
my $drawBestEffortbox = 'no';
#my $drawBestEffort = 'BestEffort';
my $drawBestEffortDefault = 'BestEffort';

#retrieve commands (old up to now and futur plus)
#my $oarstat = "/home/auguste/Prog/DrawGantt/oarstat-old ";
my $oarstat = "oarstat";
#my $ganschedulerCmd = "/home/auguste/Prog/DrawGantt/ganttscheduler2 -visu |";

# cache directory for image and map files
my $path_cache_directory = '/tmp/';
my $web_cache_directory = '../tmp/';
my $web_icons_directory = '../Icons';
my $web_path_js_directory = '../js/';

#my $path_cache_directory = '/var/www/tmp/';
#my $web_cache_directory = '/tmp/';

# number file limit in cache
my $nb_file_cache_limit = 200;

##############################################################
#
# job color 
#
##############################################################

#my @abackground = (255,255,255);

my @abackground = (0,0,0);
my @agridcolor = (200,200,200);

my @acolor = (
175,7,178,
250,0,255,
255,0,42,
244,117,138,
191,122,133,
153,0,25,
139,10,178,
195,0,255,
0,0,255,
0,255,255,
0,255,170,
66,147,25,
85,255,0,
255,255,0,
183,180,9,
255,255,155,
255,200,0,
255,150,0,
255,201,135,
180,0,0,
255,140,140,
130,70,70
);

#############################################################

my $gridcolor ;
my $indexmap = 0;
my @coordsdmap; 
my @job_index_map;

my $default_range = '1 day';
#$default_range = '3 days';
my $default_hour = '12:00';

my $gd;

# TIME CONVERSION

# ymdhms_to_sql
# converts a date specified as year, month, day, minutes, secondes to a string
# in the format used by the sql database
# parameters : year, month, day, hours, minutes, secondes
# return value : date string
# side effects : /
sub ymdhms_to_sql($$$$$$) {
    my ($year,$mon,$mday,$hour,$min,$sec)=@_;
    return ($year+1900)."-".($mon+1)."-".$mday." $hour:$min:$sec";
}

# sql_to_ymdhms [copy from Iolib.pm (OAR)]
# converts a date specified in the format used by the sql database to year,
# month, day, minutes, secondes values
# parameters : date string
# return value : year, month, day, hours, minutes, secondes
# side effects : /
sub sql_to_ymdhms($) {
    my $date=shift;
    $date =~ tr/-:/  /;
    my ($year,$mon,$mday,$hour,$min,$sec) = split / /,$date;
    # adjustment for localtime (since 1st january 1900, month from 0 to 11)
    $year-=1900;
    $mon-=1;
    return ($year,$mon,$mday,$hour,$min,$sec);
}

# ymdhms_to_local [copy from Iolib.pm (OAR)]
# converts a date specified as year, month, day, minutes, secondes into an
# integer local time format
# parameters : year, month, day, hours, minutes, secondes
# return value : date integer
# side effects : /
sub ymdhms_to_local($$$$$$) {
    my ($year,$mon,$mday,$hour,$min,$sec)=@_;
    return Time::Local::timelocal_nocheck($sec,$min,$hour,$mday,$mon,$year);
}
# local_to_sql
# converts a date specified in an integer local time format to the format used
# by the sql database
# parameters : date integer
# return value : date string
# side effects : /
sub local_to_sql($) {
    my $local=shift;
    my ($year,$mon,$mday,$hour,$min,$sec)=local_to_ymdhms($local);
    #return ymdhms_to_sql($year,$mon,$mday,$hour,$min,$sec);
    return $year."-".$mon."-".$mday." $hour:$min:$sec";
}


# local_to_ymdhms
# converts a date specified into an integer local time format to year, month,
# day, minutes, secondes values
# parameters : date integer
# return value : year, month, day, hours, minutes, secondes
# side effects : /
sub local_to_ymdhms($) {
    my $date=shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($date);
    $year += 1900;
    $mon += 1;
    return ($year,$mon,$mday,$hour,$min,$sec);
}


# sql_to_local [copy from Iolib.pm (OAR)]
# converts a date specified in the format used by the sql database to an
# integer local time format
# parameters : date string
# return value : date integer
# side effects : /
sub sql_to_local($) {
    my $date=shift;
    my ($year,$mon,$mday,$hour,$min,$sec)=sql_to_ymdhms($date);
    return ymdhms_to_local($year,$mon,$mday,$hour,$min,$sec);
}


sub colorallocation() {
	#allocate colours, do other things.
	$background = $gd->colorAllocate($abackground[0],$abackground[1],$abackground[2]);
	$gridcolor = $gd->colorAllocate($agridcolor[0],$agridcolor[1],$agridcolor[2]);
	$white = $gd->colorAllocate(255,255,255);
	$red = $gd->colorAllocate(255,0,0);
	$red_light = $gd->colorAllocate(255,50,50);
	$blue = $gd->colorAllocate(0,0,255);
	$gray_dark = $gd->colorAllocate(153,153,153);
	$gray = $gd->colorAllocate(200,200,200);
	$black = $gd->colorAllocate(0,0,0);
	for my $i (0..$#acolor/3) {
		$color[$i] = $gd->colorAllocate($acolor[3*$i],$acolor[3*$i+1],$acolor[3*$i+2]);
	}
	$nb_job_color = ($#acolor + 1) / 3;
}
# 
sub drawboxstring($$$$$){
    my $x = shift;
    my $y = shift;
    my $delta_x = shift;
    my $delta_y = shift;
    my $jobstring = shift;
    
    my $align = GD::Text::Align->new($gd,
				     valign => 'center',
				     halign => 'center',
				     color  => $gridcolor,
				     );
				     
    $align->set_font($font, $font_size);
    $align->set_text($jobstring);
    @bb=$align->bounding_box($x,$y,0);
    if ( (($bb[4]-$bb[0])<=$delta_x) && (($bb[5]-$bb[1])<=$delta_y) ) {
	    $align->draw($x,$y, 0);
    }
}

sub drawstring($$$){
    my $x = shift;
    my $y = shift;
    my $jobstring = shift;
    my $align = GD::Text::Align->new($gd,
				     valign => 'center',
				     halign => 'center',
				     color  => $gridcolor,
				     );
    $align->set_font($font, $font_size);
    $align->set_text($jobstring);
    $align->draw($x,$y, 0);
}


sub drawnowline($$$$){
	my $origin = shift;
	my $range = shift;
	my $nowtime = shift; # x now time
	my $nowcolor = shift;
	
	my $now_x;
	$now_x =  $offsetgridx + ($nowtime-$origin) * ($sizex - 2 * $offsetgridx) / $range_sec{$range};
	if (($now_x > $offsetgridx +1 ) && ($now_x < ($sizex - $offsetgridx +1))) { 
		$gd->line($now_x,$offsetgridy/2 ,$now_x, $sizey - $offsetgridy/2 , $nowcolor);
		$gd->line($now_x+1,$offsetgridy/2 ,$now_x+1, $sizey - $offsetgridy/2 , $nowcolor);
	}
}

sub drawgrid($$$) {
    my $origin = shift;
    my $begin = shift; #3 days, week -> litteral day,  month -> day,  1/6 day, 1/4 day, day -> hour
    my $range = shift; #1/6 day #1/2 day #day #3 days #week #month
    
    if ($range eq 'month') {
	   
	for $i (0..31) {
		
	    $day = strftime "%e", localtime($origin);
	    $origin = $origin + 86400;

	    $x = $offsetgridx + $i * (($sizex - 2 * $offsetgridx) / 31) ;
	    drawstring($x ,$offsetgridy / 2, $day);
	    $gd->line($x,$offsetgridy ,$x, $sizey - $offsetgridy , $gridcolor);
	}
    } elsif ($range eq 'week') {
	for $i (0..14) {
	    $x = $offsetgridx + $i * (($sizex - 2 * $offsetgridx) / 14) ;
	    if ($i & 1) {
		drawstring($x ,$offsetgridy / 2, "12h");
	    } else {
		drawstring($x ,$offsetgridy / 2, $begin);
		$begin = $daysuc{$begin};
	    }
	    $gd->line($x,$offsetgridy ,$x, $sizey - $offsetgridy , $gridcolor);
	}
    } elsif ($range eq '3 days') {
	for $i (0..6) {
	    $x = $offsetgridx + $i * (($sizex - 2 * $offsetgridx) / 6) ;
	    if ($i & 1) {
		drawstring($x ,$offsetgridy / 2, "12h");
	    } else {
		drawstring($x ,$offsetgridy / 2, $begin);
		$begin = $daysuc{$begin};
	    }
	    $gd->line($x,$offsetgridy ,$x, $sizey - $offsetgridy , $gridcolor);
	}
    } elsif  ($range eq '1 day') { #1 day
	for $i (0..24) {
	    $x = $offsetgridx + $i * (($sizex - 2 * $offsetgridx) / 24) ;
	    $hour = ($i + $begin) % 24;
	    drawstring($x ,$offsetgridy / 2, $hour."h");
	    $gd->line($x,$offsetgridy ,$x, $sizey - $offsetgridy , $gridcolor);
	}	
    } elsif ($range eq '1/2 day') { #1/2 day
    	for $i (0..12) {
	    $hour = ($i + $begin) % 24;
	    $x = $offsetgridx + $i * (($sizex - 2 * $offsetgridx) / 12) ;
	    drawstring($x ,$offsetgridy / 2, $hour."h");
	    $gd->line($x,$offsetgridy ,$x, $sizey - $offsetgridy , $gridcolor);
	}	
    } else { #1/6 day
	 for $i (0..8) {
	    $hour = ($i/2 + $begin) % 24;
	    if (($i % 2) == 1)  {$min = "30"; } else {$min = "00";}
	    $x = $offsetgridx + $i * (($sizex - 2 * $offsetgridx) / 8) ;
	    drawstring($x ,$offsetgridy / 2, $hour.":".$min);
	    $gd->line($x,$offsetgridy ,$x, $sizey - $offsetgridy , $gridcolor);   
    	}
    }
    #draw name of nodes
    for $i (1..$nbnodes - 1) {
	$y = $offsetgridy + $i * $deltay;
	drawstring($offsetgridx / 2 , $y - ($deltay / 2) , $sorted_nodes[$i]);
	$gd->line($offsetgridx - 1 ,$y , $sizex - $offsetgridx, $y  ,$gridcolor);
    }
    $gd->line($offsetgridx - 1 , $offsetgridy, 
	      $sizex - $offsetgridx, $offsetgridy, $gridcolor);	
}

sub drawjob ($$$$$$$$$$) {
    my $origin = shift;
    my $range = shift;
    my $idjob = shift;
    my $jobtype = shift; #interactive/passive/reserved/ other ???Fixed/
    my $jobstring = shift;#String which identifies a job (e.g. Id or username)
    my $jobcolor = shift;
    my $begindate = shift;
    my $enddate = shift;
    my $job_node_ref = shift;
    my $job_index = shift;

#    $jobcolor=$red;
#   print STDERR "idjob $idjob color $jobcolor\n";
 #  print "origin $origin\n range $range\n idjob $idjob\n jobtype $jobtype \n \n begindate $begindate \n enddate $enddate \n";
 #   print "color $jobcolor \n";
 #   print "NB node_cpu ---> $#$job_node_ref \n";
 #   for my $i (0 .. $#$job_node_ref) {
 #	    print "node $job_node_cpu[$job_i][$i]\n";
#	    print "$job_node_ref->[$i]\n";
#    }
#    print "\n Exit \n"; exit;
    #normalize and truncate job's time if needed
    
#print STDERR " origin $origin range_sec $range_sec{$range} begindate $begindate   enddate $enddate \n";

    $scale = ($sizex - 2 * $offsetgridx)  / $range_sec{$range} ;
    $begindate = ($begindate - $origin) * $scale;
    if ($begindate < 1) {$begindate = 1;}
    $enddate = ($enddate - $origin) * $scale;
#print "  begindate $begindate   enddate $enddate \n";

    if ($enddate > ($sizex - 2 * $offsetgridx - 1)) {
	$enddate = $sizex - (2*$offsetgridx) - 1;
    }
    
    $begindate =  $begindate + $offsetgridx;
    $enddate = $enddate + $offsetgridx;

#print "Formatted  begindate $begindate   enddate $enddate \n";

    #draw job cell
    $y = $offsetgridy +   ($job_node_ref->[0]-1)* $deltay + $gap / 2;
    $preindex = $job_node_ref->[0];
    for $i (0 .. $#$job_node_ref) {
	if ( $job_node_ref->[$i] > ($preindex + 1) ) {
	    #draw previous rectangle
	    $y1 =  $offsetgridy + $preindex * $deltay - $gap/2;
	    $gd->filledRectangle($begindate,$y,$enddate, $y1, $jobcolor);
	    
	    #update coord_map 
	    $coord_map[$index]="$begindate,$y,$enddate,$y1";
	    $job_index_map[$index] = $job_index;
	    $idjobmap[$index++] = $idjob;
	    
	    
	    #draw jobstring
	    $delta_x = $enddate-$begindate;
	    $delta_y = $y1 -$y;
	    drawboxstring(($begindate + $enddate)/2, ($y+$y1)/2, $delta_x, $delta_y, $jobstring);
	    
	    $y = $offsetgridy + ($job_node_ref->[$i]-1)* $deltay + $gap / 2;
	}
	$preindex = $job_node_ref->[$i]; 
    }

    #draw last rectangle
    $y1 = $offsetgridy + $preindex  * $deltay - $gap / 2;
    $gd->filledRectangle($begindate,$y,$enddate, $y1, $jobcolor);

    #update coord_map 
    $coord_map[$index]="$begindate,$y,$enddate,$y1";
    $job_index_map[$index] = $job_index;
    $idjobmap[$index++] = $idjob; 

    #drawstring !
    $delta_x = $enddate-$begindate;
    $delta_y = $y1 -$y;
    drawboxstring(($begindate + $enddate)/2, ($y+$y1)/2, $delta_x, $delta_y, $jobstring);
}

###############################################################################
#
#        Main
#
###############################################################################

#Get config 
init_conf("DrawGantt.conf");
	     
$sizex = get_conf("sizex");
$sizey = get_conf("sizey");
$offsetx= get_conf("offsetx");10;
$offsetgridy = get_conf("offsetgridy");20;
$offsetgridx = get_conf("offsetgridx");100;
$title = get_conf("title");

#Default setting for BestEffort Job Drawing 
$drawBestEffortbox = get_conf("drawBestEffortbox");
$drawBestEffortDefault = get_conf("drawBestEffortDefault");
#retrieve commands (old up to now and futur plus)

$oarstat = get_conf("oarstatCmd");

# cache directory for image and map files
 $path_cache_directory = get_conf("path_cache_directory");
 $web_cache_directory = get_conf("web_cache_directory");'../tmp/';
 $web_icons_directory = get_conf("web_icons_directory");'../Icons';
 $web_path_js_directory = get_conf("web_path_js_directory");'../js/';

# $path_cache_directory = '/var/www/tmp/';
# $web_cache_directory = '/tmp/';

# number file limit in cache
$nb_file_cache_limit = get_conf("nb_file_cache_limit");

$default_range = get_conf("default_range");
$default_hour = get_conf("default_hour");

$order = get_conf("order");
$regexstring = get_conf("regex");

@abackground = split (',',get_conf("background"));
@agridcolor = split (',',get_conf("gridcolor"));


#
# Image Allocation
#


$gd = GD::Image->new($sizex,$sizey);

#
#color initialize
#

colorallocation();

#get now time
my $now = time;
my @local_now = localtime($now);

#
# CGI parameters
#

if (param('day')) {
    $hour = param('hour');
    $day = param('day');
    $month = param('month');
    $year = param('year');
    $range = param('range');    
} else {
    $day = $local_now[3];
    $month = $litteral_month{$local_now[4]};
    $year = $local_now[5] + 1900;
    #$range = '1 day';
    #$hour = '00:00';
    $range = $default_range;
    $hour = $default_hour;
}

($hour,$min) = split (':',$hour);
#$origin =  ymdhms_to_local($year,$mon{$month},$day,$hour,'0','0');
$origin = Time::Local::timelocal_nocheck(0,0,$hour,$day,$mon{$month},$year);

if (param('zoom_in.x'))  {
	if ($range ne $zoom_in{$range}) {
		$origin = $origin + ($range_sec{$range} - $range_sec{$zoom_in{$range}}) / 2;
		$range = $zoom_in{$range};
		param(-name=>'range',-value=>$range);
	}
}

if (param('zoom_out.x'))  {
	if ($range ne $zoom_out{$range}) {
		$origin = $origin + ($range_sec{$range} - $range_sec{$zoom_out{$range}}) / 2;
		$range = $zoom_out{$range};
		param(-name=>'range',-value=>$range);
	}
}

#print "Local $origin : time @local_origin \n"; exit 1;
#print "year $year,month $mon{$month},day $day, Origin $origin \n";

if (param('left.x') || param('right.x')) {
	if (param('left.x')) {
		$origin = $origin - $range_step{$range};
	} else {
		$origin = $origin + $range_step{$range};
	}
}

#($year,$month,$day,$hour,$min,$sec)=local_to_ymdhms($origin);	
#$year =$year + 1900;
($year,$month,$day,$hour) = split (" ",strftime "%Y %b %e %H", localtime($origin));

#if ($hour<10) {$hour = '0'.$hour;}

param(-name=>'hour',-value=>"$hour:00");
param(-name=>'day',-value=>$day);
#param(-name=>'month',-value=>$litteral_month{$month});
param(-name=>'month',-value=>$month);
param(-name=>'year',-value=>$year);

@local_origin = localtime($origin);

if ( ($range eq '3 days') || ($range eq 'week')) {
	$begin_grid = $wday[$local_origin[6]];
} elsif ( ($range eq '1/2 day') || ($range eq '1/6 day') || ($range eq '1 day'))   {
	$begin_grid = $hour;
} else {#month
    $begin_grid  = $day;
}

#
#file caching 
#
#policy: file (= new image) is generated if not other file have been generate 
#in previous second for the same range and origin greater or equal present 
#time minus range time. 
#The name is coded as gant_day_month_years_range_now.png.
#For older file the name is gant_day_month_years_range.png
#

$file_range = $range;
if ($range eq '1/2 day') {$file_range = '1_2 day';}
if ($range eq '1/6 day') {$file_range = '1_6 day';}

#BestEffort jobs drawing ?
if (param('DrawBestEffort')) { 
	$filterBestEffortfile = '_BE';
	$filterBestEffort = '';
} else {
	$filterBestEffortfile = '';
	$filterBestEffort = ' grep -v besteffort |';
}

my $fileimg =  'gantt_'.$year.'_'.$month.'_'.$day.'_'.$hour.'_'.$file_range.$filterBestEffortfile;
my $filemap =  'map_'.$year.'_'.$month.'_'.$day.'_'.$hour.'_'.$file_range.$filterBestEffortfile;

#test if it's on old file ?
if ($origin + $range_sec{$range} > $now) {
    $fileimg = $fileimg.'_'.$now.'.png';
    $filemap = $filemap.'_'.$now.'.map';
}else {
    $fileimg = $fileimg.'.png';
    $filemap = $filemap.'.map';
}

$path_fileimg = $path_cache_directory.$fileimg;
$path_filemap = $path_cache_directory.$filemap;

unless (-e $path_fileimg) { #files (image and map) must be generate

#
# Cache flushing policie
#

open NBFILE,"ls $path_cache_directory/*png $path_cache_directory/*map >&1 | wc -l |" or print STDERR "Cache Directiory Access Problem";
my $nb_file = <NBFILE>;
chomp $nb_file;
close NBFILE;
if ($nb_file > $nb_file_cache_limit) {
	system "rm $path_cache_directory/*png $path_cache_directory/*map" or print STDERR "Delete File from Cache Error";
}

###############################################################################
#
# generating gantt's image file if required
#
###############################################################################

#
# first retrieve job information from database
#

my @nodesStr;
my $line_nodes;

$begindate = strftime "%F %H:%M:%S", localtime($origin);
$enddate =  strftime "%F %H:%M:%S", localtime($origin + $range_sec{$range});
#$begindate = local_to_sql($origin);	
#$enddate =  local_to_sql($origin + $range_sec{$range});


if (defined $ganschedulerCmd) {
	@aretrieveCmd = ( $oarstat." -h \"$begindate,$enddate\" |".$filterBestEffort, $ganschedulerCmd.$filterBestEffort);
}
else {
	@aretrieveCmd = ( $oarstat." -h \"$begindate,$enddate\" |".$filterBestEffort);
}

my $k=0;
for my $retrieveCmd (@aretrieveCmd) {
#	print "retrieveCmd $retrieveCmd\n";
	open RETRIEVE,$retrieveCmd or die "Retrieving aborted : $retreiveCmd";
	$line_nodes = $line_nodes.<RETRIEVE>;
	chomp $line_nodes;
	$line_nodes = $line_nodes." ";
#	print "line_nodes $line_nodes \n";
	while (<RETRIEVE>) {
		$retrieveStr[$k]=$_;
	@essai = $_;		
		chomp $retrieveStr[$k];
		$k = $k + 1;
#		print "retrieveStr $retrieveStr[$k-1]\n";
	}	
	
	close RETRIEVE;
}

#
# build sorted list of nodes
#

@nodes_tmp = (split /' '/,$line_nodes);
$nodes_tmp[0] =~s/^'//;
$nodes_tmp[$#nodes_tmp]=~s/'//;

my $k = 0 ; # index
# parse nodes
for  $i (0 .. $#nodes_tmp/2) {
#	print "I $i node $nodes_tmp[2*$i] weight $nodes_tmp[2*$i+1]\n";
	if (defined $nodes_tmp[2*$i]) {
		for $j ($i+1 .. $#nodes_tmp/2) {
# eliminate double name			
			if ($nodes_tmp[2*$i] eq $nodes_tmp[2*$j]) {
				$nodes_tmp[2*$j] = undef;

# keep maximum weight			
				if ($nodes_tmp[2*$i + 1] < $nodes_tmp[2*$j + 1]) {
					$nodes_tmp[2*$i + 1] = $nodes_tmp[2*$j + 1];
				}
			}
		}
	$nodes_tmp[$k] = $nodes_tmp[2*$i];
	$nodes_tmp2[$k] = $nodes_tmp[$k];	
	$weight_nodes{$nodes_tmp[$k]}=$nodes_tmp[2*$i+1];
#	print "Single nodes $nodes_tmp[$k] weight $weight_nodes{$nodes_tmp[$k]}\n";
	$k = $k + 1;
	}	
}

#print "not sorted nodes ", @nodes_tmp2,"\n";

if ($regexstring ne '') {
	$regex = qr/$regexstring/;
	foreach $i (0..$#nodes_tmp2) {
		print STDERR " regexname $nodes_tmp2[$i]\n";
		$regexname = $nodes_tmp2[$i];
		if ($regexname =~ $regex) {$regexname = $1 }
		#if ($regexname eq '')  
		else {
			$regexname = $nodes_tmp2[$i];
		}
		$indexregex{$regexname} = $nodes_tmp2[$i];
		push @regexnamenode,$regexname;
	}
#	print STDERR	"regexnamenode @regexnamenode \n";
	if ($order eq "numerical") {
		@sortedindexregex = sort  {$a <=> $b} @regexnamenode;
	} else { 
		#@sorted_nodes_tmp = @regexnamenode;
		@sortedindexregex = sort @regexnamenode;
	}
	foreach $i (0..$#sortedindexregex) {
		$sorted_nodes_tmp[$i]= $indexregex{$sortedindexregex[$i]};
	}
} else {
	@sorted_nodes_tmp = sort @nodes_tmp2;
}
#print STDERR "Sorted nodes ", @sorted_nodes_tmp," \n";
# create flatted list of sorted nodes

my $l=1;
my %rank_node;
for $i (0 .. $k-1) {
	if ($weight_nodes{$sorted_nodes_tmp[$i]} == 1) {
		$sorted_nodes[$l] = $sorted_nodes_tmp[$i];
		$rank_node{$sorted_nodes[$l]} = $l;
#		print "$sorted_nodes[$l] \n";
		$l = $l + 1;
	}
	else {
		for $j (0 .. $weight_nodes{$sorted_nodes_tmp[$i]} - 1) {
#			print "noeud $sorted_nodes_tmp[$i] weight $weight_nodes{$sorted_nodes_tmp[$i]} j $j\n"; 
			$sorted_nodes[$l] = $sorted_nodes_tmp[$i].'_'.$j;
			$rank_node{$sorted_nodes[$l]} = $l;
#			print "$sorted_nodes[$l] \n";
			$l = $l + 1;
		}
	}
}

$nbnodes = $#sorted_nodes + 1;
#print STDERR "Nb Procs $nbnodes \n";

#
# job formating
#


for my $j (0 .. $#retrieveStr) {
	
#	$job_info[$j] = [ split /[ \t]+/,$retrieveStr[$j] ] ;
	$job_info[$j] = [  split /' '/,$retrieveStr[$j] ] ;
	$job_info[$j][0]=~s/'//; 
	$job_info[$j][$#{$job_info[$j]}]=~s/'//; 

	$job_info_map[$j] = 'Start:'.$job_info[$j][$f_begin].'<br>End : '.$job_info[$j][$f_end];
	#translate sql_date_to_local
	$job_info[$j][$f_begin] = sql_to_local($job_info[$j][$f_begin]);
	$job_info[$j][$f_end] = sql_to_local($job_info[$j][$f_end]);

	$hash_jobid_time{$j} = $job_info[$j][$f_begin];
#	print STDERR "$hash_jobid_time{$j} $j\n";
	$hash_jobid_id{$j} = $job_info[$j][$f_jobid];
	
	@part=();

	
	for $i (0 .. ($#{$job_info[$j]} -$f_node)/2) {
#		print "yop\n";
		push @part, $job_info[$j][$f_node + 2*$i];
		$job_weight[$j]{$job_info[$j][$f_node + 2*$i]} = $job_info[$j][$f_node + 2*$i +1];
	}
	$job_nodes[$j]  = [sort (@part)];
	$nb_job_nodes[$j] = $#part;

}

@jobid_time_sorted = sort { $hash_jobid_time{$a} <=> $hash_jobid_time{$b} } keys %hash_jobid_time;
@jobid_id_sorted = sort { $hash_jobid_id{$a} <=> $hash_jobid_id{$b} } keys %hash_jobid_id;

#print STDERR "jobid_time_sorted @jobid_time_sorted\n";
#for $i (0..$#jobid_time_sorted) { print STDERR ":$i:$jobid_time_sorted[$i]:$job_info[$jobid_time_sorted[$i]][$f_jobid] ($job_info[$jobid_time_sorted[$i]][$f_begin]) \n";
#}
#print STDERR "\n";
#
#attribute processors 
#

for $l (0 .. $#retrieveStr) {
	$job_i = $jobid_time_sorted[$l];
#	print STDERR "index:$job_i  jobid $job_info[$job_i][$f_jobid] alloc_node_cpu \n ";
	#for job with jobid !=0, determine previous time overlapped jobs with jobid != 0;
	
	
	if ($job_info[$job_i][$f_jobid]!=0) {
		@overlap_job = ();
		my $begin = $job_info[$job_i][$f_begin]; #begin_date 
		my $end = $job_info[$job_i][$f_end]; #end_date  
		for $j (0 ..$l-1) {
			if ($job_info[$jobid_time_sorted[$j]][$f_jobid]!=0) {
				my $b2 = $job_info[$jobid_time_sorted[$j]][$f_begin]; #begin_date 
				my $e2 = $job_info[$jobid_time_sorted[$j]][$f_end]; #end_date  
				if ((($b2 >= $begin) && ($b2 <= $end)) || (($e2 >= $begin) && ($e2 <= $end)) || (($b2 <= $begin) && ($e2 >= $end))) {
					push @overlap_job, $jobid_time_sorted[$j];
				}
			}
		}
	}
	
#	print STDERR "overlap_job : ";
#	for $i (0..$#overlap_job ) { print STDERR "$overlap_job[$i] ($job_info[$overlap_job[$i]][$f_jobid]) ";}
#	print STDERR "\n";
	
	#list all node_cpu of previous overlapped jobs
	my @o_job_node_cpu = ();
	my @o_job_node_cpu_tmp = ();
	for $job_j (@overlap_job) {
		$aref = $job_node_cpu[$job_j];
		for $j (0 .. $#$aref) {
			push @o_job_node_cpu_tmp, $job_node_cpu[$job_j][$j]
		}
	}
	
	@o_job_node_cpu = sort {$a <=> $b} @o_job_node_cpu_tmp;
	
#	print STDERR "o_job_node_cpu @o_job_node_cpu \n";
	
	
	$k=0;	#index for job_node_cpu[$job_i]
	$aref = $job_nodes[$job_i];
	
	my $o_index = 0; # index for o_job_node_cpu 

	for my $number_node_i (0 .. $#$aref) { # choice cpu(s) by node
		$node_i = $job_nodes[$job_i][$number_node_i];
		$weight = $weight_nodes{$node_i}; # weight of node_i
		if ($weight == 1) {
			$rank = $rank_node{$node_i};
		}
		else {
			$rank = $rank_node{$node_i.'_0'};
		}
		
#		print STDERR "node_ref $node_i rank_ref $rank \n";
		
		my $weight_job = $job_weight[$job_i]{$node_i};
		if ($weight == $weight_job ) {
			# all cpus are occuped 
			for $j (0 .. $weight -1) {
#				print STDERR "$rank \n"; 
				$job_node_cpu[$job_i][$k++]= $rank++;
				
			}
		}
		else {
			while ( ($weight_job != 0) && ($o_index <= $#o_job_node_cpu)) { 
				$o_rank = $o_job_node_cpu[$o_index];
				if ($o_rank == $rank) {
					$rank++;
				}
				elsif ($o_rank > $rank) {
#					print "Yop il y a trou o_rank $o_rank rank $rank \n";
#				print STDERR "$rank \n"; 
					$job_node_cpu[$job_i][$k++]= $rank++;
					$weight_job--;
				} 
				else {
					$o_index++;
				}
			}
#			print "weight_job $weight_job\n";
			if ($weight_job != 0) {	
				for $j (0 .. $weight_job -1) {
#					print STDERR "$rank \n";
					$job_node_cpu[$job_i][$k++]= $rank++;
				}
				
			}
		}	
	}
#	print STDERR "\n";

}

$deltay = (($sizey - 2 * $offsetgridy)/ ($nbnodes-1)  ) ;
$offsety= $offsetgridy + $gap;
$height = $deltay - $gap ;

#
#Draw the Grid
drawgrid($origin, $begin_grid, $range);

##################
#
#Draw Jobs
#
#Note : Jobs with Jobid=0 are drawn first
#
##################

for $l (0 .. $#retrieveStr) {
	$job_i = $jobid_id_sorted[$l];
#	print STDERR "Nu_job $job_i Job_id $job_info[$job_i][$f_jobid]  job_type $job_info[$job_i][$f_jobtype] begin $job_info[$job_i][$f_begin] end $job_info[$job_i][$f_end]\n";
	if ( ($job_info[$job_i][$f_jobid]==0) ) {
		$job_color = $red_light;
		$job_string = $job_info[$job_i][$f_jobtype];
	} 
	else {
		
		$job_color = $color[$job_info[$job_i][$f_jobid] % $nb_job_color];
		$job_string = $job_info[$job_i][$f_jobid];
#		print "jobid $job_info[$job_i][$f_jobid] color $job_color\n";
	}
	
	if ($job_info[$job_i][$f_jobqueue] eq 'besteffort')  {
		$job_color = $gray_dark;
	}
	my $begin = $origin; 
	my $end = $origin + $range_sec{$range};
	my $b2 = $job_info[$job_i][$f_begin];
	my $e2 = $job_info[$job_i][$f_end];
	
	if ( (($begin < $e2) && ($e2 < $end)) || (($begin < $b2) && ($b2 < $end)) || (($b2 <= $begin) && ($e2 >= $end)) ) {
		drawjob($origin,
		$range,
		$job_info[$job_i][$f_jobid], #jobID
		$job_info[$job_i][$f_jobtype], #jobtype
		$job_string, #
		$job_color,
		$job_info[$job_i][$f_begin], #begindate
		$job_info[$job_i][$f_end], #enddate
		$job_node_cpu[$job_i],
		$job_i);
	}
	$aref = $job_node_cpu[$job_i];
	$nb_cpus = $#$aref +1; 
	if ($job_info[$job_i][$f_jobid]==0) {
		$job_info_map[$job_i]="NodeState: ".$job_info[$job_i][$f_jobtype]."<br> NbCpus: ".$nb_cpus."<br>".$job_info_map[$job_i];
	} else {
		$cmd=$job_info[$job_i][$f_jobcmd];
		#$cmd=~s/'/\\'/g;
		$property=$job_info[$job_i][$f_jobproperty];
		#$property=~s/'/\\'/g; 
		$property=~s/"/\ /g;
		$nb_jnodes=$nb_job_nodes[$job_i]+1;
	$job_info_map[$job_i]="JobId: ".$job_info[$job_i][$f_jobid]."<br>User: ".$job_info[$job_i][$f_jobuser]."<br>Type: ".$job_info[$job_i][$f_jobtype].
				"<br>State: ".$job_info[$job_i][$f_jobstate].
#				"<br>Command: ".$job_info[$job_i][$f_jobcmd]."<br>Property: ".$job_info[$job_i][$f_jobproperty].
				"<br>Command: ".$cmd."<br>Property: ".$property.
				"<br>Queue: ".$job_info[$job_i][$f_jobqueue]."<br>Nb nodes: ".
				$nb_jnodes."/".$nb_cpus."<br>Submission: ".$job_info[$job_i][$f_jobsubmission]."<br>".$job_info_map[$job_i];
	}
}

#
# draw now line
#

drawnowline($origin,$range,$now,$red);

#    
#save file image
# 
    open FILE, "> $path_fileimg" ;
    print FILE $gd->png;
    close FILE;

#
# generate map and image link 
#    
    open FILEMAP, "> $path_filemap" ;
    
    print FILEMAP "\n",' <map name="ganttmap">'; 
    for $i (0 .. $#coord_map) {
#	print FILEMAP "\n",'<area shape="rect" coords="',$coord_map[$i],'" href="monika.cgi?job=',$idjobmap[$i],'" title ="', $job_info_map[$job_index_map[$i]], '">';
#	print FILEMAP "\n",'<area shape="rect" coords="',$coord_map[$i],'" href="monika.cgi?job=',$idjobmap[$i],'" title ="', $job_info_map[$job_index_map[$i]],
#	print FILEMAP "\n",'<area shape="rect" coords="',$coord_map[$i],
	print FILEMAP "\n",'<area shape="rect" coords="',$coord_map[$i],'" href="monika.cgi?job=',$idjobmap[$i],
	'" onmouseout="return nd()" onmouseover="return overlib(','\'',$job_info_map[$job_index_map[$i]],'\')" >';	
    }
    
    print FILEMAP "\n",'</map>',"\n",
    "\n",'<div style="text-align: center">',
    "\n",'<img src="',$web_cache_directory,$fileimg,'" border=1 width=',$sizex,
  #  ' height=', $sizey,' usemap="#ganttmap" alt="Gantt Chart">',
   ' height=', $sizey,' usemap="#ganttmap">',
    "\n",'</div>';

    close FILEMAP;

#
#TODO :  flushing stamped files (When ?) to prevent tmp overfull 
#

}

#
#generate HTML
#
print header,              # create the HTTP header
    start_html('GanttChart'),  # start the HTML
    h3($title);         # level 1 header

# Javascript stuff thanks to NCSA TITAN cluster's page    
print '<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>';
print '<script src="',$web_path_js_directory,'overlib.js" language="JavaScript"></script><!-- overLIB (c) Erik Bosrup -->';

#Form for generate a new gantt chart

print start_form ({-align=>CENTER, -method => "get"});
print "<p><em> Origin </em>";
print popup_menu(-name=>'year',
		 -values=>[$local_now[5] + 1899, $local_now[5] + 1900, $local_now[5] + 1901],
		 -default=>$local_now[5] + 1900);
print popup_menu(-name=>'month',
		 -values=>['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct', 'Nov','Dec'],
		 -default=>$litteral_month{$local_now[4]});
print popup_menu(-name=>'day',
		 -values=>['1','2','3','4','5','6','7','8','9',
			   '10','11','12','13','14','15','16','17','18','19',
			   '20','21','22','23','24','25','26','27','28','29',
			   '30','31'],
		 -default=>$local_now[3]);
print popup_menu(-name=>'hour',
		 -values=>['00:00','01:00','02:00','03:00','04:00','05:00','06:00','07:00','08:00','09:00',
			   '10:00','11:00','12:00','13:00','14:00','15:00','16:00','17:00','18:00','19:00',
			   '20:00','21:00','22:00','23:00'],
		 -default=>'00:00');
print "<em> Range </em>";
print popup_menu(-name=>'range',
		-values=>['1/6 day', '1/2 day','1 day','3 days','week','month'],
		-default=>$default_range);

if ($drawBestEffortbox eq 'yes') {
	print checkbox_group(-name=>'DrawBestEffort',
        	             -values=>['BestEffort'],
			     -default=>[$drawBestEffortDefault]);	
}
		
print submit('Action','Draw');
print defaults('Default');

#print image_button('default',"$web_icons_directory/circle-32.png");
#print image_button('draw',"$web_icons_directory/exchange-32.png");
print image_button('left',"$web_icons_directory/gorilla-left.png");
print image_button('zoom_out',"$web_icons_directory/gorilla-minus.png");
print image_button('zoom_in',"$web_icons_directory/gorilla-plus.png");
print image_button('right',"$web_icons_directory/gorilla-right.png");

print endform;

#
# incorporate map and image links
#

open(FILE, "$path_filemap") or die "Can't open $path_filemap: $!";
while (<FILE>) {print $_};
close(FILE);

print "<hr>\n";
print end_html;
