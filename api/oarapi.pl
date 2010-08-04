#!/usr/bin/perl -w
use strict;
use DBI();
use oar_apilib;
use oar_conflib qw(init_conf dump_conf get_conf_list get_conf is_conf set_value);
use oar_iolib;
use oarstat_lib;
use oarnodes_lib;
use oar_Tools;
use oarversion;
use POSIX;
use JSON;
#use Data::Dumper;

my $VERSION="0.3.0";

##############################################################################
# CONFIGURATION
##############################################################################

# Load config
my $oardir;
if (defined($ENV{OARDIR})){
    $oardir = $ENV{OARDIR}."/";
}else{
    die("ERROR: OARDIR env variable must be defined.\n");
}
if (defined($ENV{OARCONFFILE})){
  init_conf($ENV{OARCONFFILE});
}else{
  init_conf("/etc/oar/oar.conf");
}

# CGI handler
my $q=apilib::get_cgi_handler();

# Oar commands
my $OARSUB_CMD  = "oarsub";
my $OARDEL_CMD  = "oardel";
my $OARHOLD_CMD  = "oarhold";
my $OARRESUME_CMD  = "oarresume";
my $OARADMIN_CMD = "oaradmin";
my $OARNODES_CMD = "oarnodes";
my $OARDODO_CMD = "$ENV{OARDIR}/oardodo/oardodo";

# OAR server
my $remote_host = get_conf("SERVER_HOSTNAME");
my $remote_port = get_conf("SERVER_PORT");
my $stageout_dir = get_conf("STAGEOUT_DIR");
my $stagein_dir = get_conf("STAGEIN_DIR");
my $allow_create_node = get_conf("DESKTOP_COMPUTING_ALLOW_CREATE_NODE");
my $expiry = get_conf("DESKTOP_COMPUTING_EXPIRY");

# Enable this if you are ok with a simple pidentd "authentication"
# Not very secure, but useful for testing (no need for login/password)
# or in the case you fully trust the client hosts (with an apropriate
# ip-based access control into apache for example)
my $TRUST_IDENT = 1;
if (is_conf("API_TRUST_IDENT")){ $TRUST_IDENT = get_conf("API_TRUST_IDENT"); }

# Default data structure variant
my $STRUCTURE="simple";
if (is_conf("API_DEFAULT_DATA_STRUCTURE")){ $STRUCTURE = get_conf("API_DEFAULT_DATA_STRUCTURE"); }

# Get the default maximum number of items
my $MAX_ITEMS=500;
if (is_conf("API_DEFAULT_MAX_ITEMS_NUMBER")){ $MAX_ITEMS = get_conf("API_DEFAULT_MAX_ITEMS_NUMBER"); }

# Header for html version
my $apiuri=apilib::get_api_uri_relative_base();
$apiuri =~ s/\/$//;
my $HTML_HEADER="";
my $file;
if (is_conf("API_HTML_HEADER")){ $file=get_conf("API_HTML_HEADER"); }
else { $file="/etc/oar/api_html_header.pl"; }
open(FILE,$file);
my(@lines) = <FILE>;
eval join("\n",@lines);
close(FILE);

##############################################################################
# Authentication
##############################################################################

my $authenticated_user = "";

if ( defined( $ENV{AUTHENTICATE_UID} ) && $ENV{AUTHENTICATE_UID} ne "" ) {
  $authenticated_user = $ENV{AUTHENTICATE_UID};
}
else {
  if ( $TRUST_IDENT
    && defined( $q->http('X_REMOTE_IDENT') )
    && $q->http('X_REMOTE_IDENT') ne ""
    && $q->http('X_REMOTE_IDENT') ne "unknown" 
    && $q->http('X_REMOTE_IDENT') ne "(null)" )
  {
    $authenticated_user = $q->http('X_REMOTE_IDENT');
  }
}

##############################################################################
# Data structure variants
##############################################################################

if (defined $q->param('structure')) {
  $STRUCTURE=$q->param('structure');
}
if ($STRUCTURE ne "oar" && $STRUCTURE ne "simple") {
  apilib::ERROR 406, "Unknown $STRUCTURE format",
        "Unknown $STRUCTURE format for data structure";
  exit 0;
}


##############################################################################
# URI management
##############################################################################

SWITCH: for ($q) {
  my $URI;

  #
  # Welcome page (html only)
  #
  $URI = qr{^/index\.html$};
  apilib::GET( $_, $URI ) && do {
    print $q->header( -status => 200, -type => "text/html" );
    print $HTML_HEADER;
    print "Welcome on the oar API\n";
    last;
  };
  $URI = qr{^/desktop/agents(.*)$};
  apilib::POST( $_, $URI ) && do {
    warn "haha";
    my $request = decode_json $q->param('POSTDATA');
    sign_in($request->{hostname});
    print $q->header( -status => 200, -type => "text/html" );
    last;
  };
  $URI = qr{^/jobs/(\d+)/run(.*)$};
  apilib::POST( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    runJob($1);
    last;
  };
  $URI = qr{^/jobs/(\d+)/terminate(.*)$};
  apilib::POST( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    terminateJob($1);
    last;
  };
  $URI = qr{^/resources/nodes/([-\.\w]+)/jobs(.*)$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    print $q->header( -status => 200, -type => "application/json" );
    getJobsToLaunch($1);
    last;

  };
  $URI = qr{^/jobs/(\d+)/stagein(.*)$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    jobStageIn($1);
    last;
  };
  $URI = qr{^/jobs/(\d+)/stageout(.*)$};
  apilib::POST( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    jobStageOut($1);
    last;
  };

  #
  # Version
  #
  $URI = qr{^/version\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$1);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $version={ "oar" => oarversion::get_version(),
                  "apilib" => apilib::get_version(),
                  "api_timestamp" => time(),
                  "api_timezone" => strftime("%Z", localtime()),
                  "api" => $VERSION };
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($version,$ext);
    last;
  };

  #
  # Timezone
  #
  $URI = qr{^/timezone\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$1);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $version={ 
                  "api_timestamp" => time(),
                  "timezone" => strftime("%Z", localtime())
                };
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($version,$ext);
    last;
  };

  #
  # List of current jobs
  #
  $URI = qr{^/jobs(/details|/table)*\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $more_infos=$1;

    # Get the id of the user as more details may be obtained for her jobs
    if ( $authenticated_user =~ /(\w+)/ ) {
      $authenticated_user = $1;
      $ENV{OARDO_USER} = $authenticated_user;
    }

    oarstatlib::open_db_connection or apilib::ERROR(500, 
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                          );

    # default parameters for the parameters
    my $JOBS_URI_DEFAULT_PARAMS = "state=Finishing,Running,Resuming,Suspended,Launching,toLaunch,Waiting,toAckReservation,Hold";
    if (is_conf("API_JOBS_URI_DEFAULT_PARAMS")){ $JOBS_URI_DEFAULT_PARAMS = get_conf("API_JOBS_URI_DEFAULT_PARAMS"); }

    # query string parameters
    my $from = $q->param('from');
    my $to = $q->param('to');
    my $state = $q->param('state');

    if (!defined($q->param('from')) && !defined($q->param('to')) && !defined($q->param('state'))) {
        my $param = qr{.*from=(.*?)(&|$)};
        if ($JOBS_URI_DEFAULT_PARAMS =~ m/$param/) {
        	$from = $1;
        }
    	$param = qr{.*to=(.*?)(&|$)};
    	if ($JOBS_URI_DEFAULT_PARAMS =~ m/$param/) {
        	$to = $1;
        }
    	$param = qr{.*state=(.*?)(&|$)};
    	if ($JOBS_URI_DEFAULT_PARAMS =~ m/$param/) {
        	$state = $1;
        }
    }
    # GET max items from configuration parameter
    if (!defined($q->param('from')) && !defined($q->param('to')) && !defined($q->param('state')) && !defined($q->param('limit'))) {
    	# get limit from defaut url
        my $param = qr{.*limit=(.*?)(&|$)};
        
        if ($JOBS_URI_DEFAULT_PARAMS =~ m/$param/) {
        	$MAX_ITEMS = $1;
        }
    }
    # GET max items from uri parameter
    if (defined($q->param('limit'))) {
        $MAX_ITEMS = $q->param('limit');
    }
    # set offset / GET offset from uri parameter
    my $offset = 0;
    if (defined($q->param('offset'))) {
        $offset = $q->param('offset');
    }
    # requested user jobs
    my $jobs = oarstatlib::get_jobs_for_user_query("",$from,$to,$state,$MAX_ITEMS,$offset);
    my $total_jobs = oarstatlib::count_jobs_for_user_query("",$from,$to,$state);
    
    if ( !defined $jobs || keys %$jobs == 0 ) {
      $jobs = apilib::struct_empty($STRUCTURE);
    }
    else {
    	
    	$jobs = apilib::struct_job_list_hash_to_array($jobs);
      	apilib::add_joblist_uris($jobs,$ext);
      	
      	if (defined($more_infos)) {
        	if ($more_infos eq "/details") {
           	# will be useful for cigri and behaves exactly as a oarstat -D
           	foreach my $j (@$jobs) {
              	$j = oarstatlib::get_job_data($j,undef);
           	}
           	apilib::add_joblist_uris($jobs,$ext);
           	$jobs = apilib::struct_job_list_details($jobs,$STRUCTURE);
        	}
      	}
      	else {
          	$jobs = apilib::struct_job_list($jobs,$STRUCTURE);
      	}
    }
    oarstatlib::close_db_connection();
    
    # add pagination informations
    $jobs = apilib::add_pagination($jobs,$total_jobs,$q->path_info,$q->query_string,$ext,$MAX_ITEMS,$offset,$STRUCTURE);
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($jobs,$ext);
    last;
  };

  #
  # Details of a job
  #
  $URI = qr{^/jobs/(\d+)(\.yaml|\.json|\.html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $jobid = $1;
    my $ext=apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    
    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before looking at jobs" );
      last;
    }
    $authenticated_user = $1;
    $ENV{OARDO_USER} = $authenticated_user;

    oarstatlib::open_db_connection or apilib::ERROR(500, 
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                                 );
    my $job = oarstatlib::get_specific_jobs([$jobid]);
    $job=oarstatlib::get_job_data(@$job[0],1);
    apilib::add_job_uris($job,$ext);
    my $result = apilib::struct_job($job,$STRUCTURE);
    oarstatlib::close_db_connection; 
    print $header;
    if ($ext eq "html") {
       my $hold="holds";
       if ($job->{state} eq "Running") { $hold="rholds";}
       print $HTML_HEADER;
       print "\n<TABLE>\n<TR><TD COLSPAN=4><B>Job $jobid actions:</B>\n";
       print "</TD></TR><TR><TD>\n";
       print "<FORM METHOD=POST action=$apiuri/jobs/$jobid/deletions/new.html>\n";
       print "<INPUT TYPE=Hidden NAME=method VALUE=delete>\n";
       print "<INPUT TYPE=Submit VALUE=DELETE>\n";
       print "</FORM></TD><TD>\n";
       print "<FORM METHOD=POST action=$apiuri/jobs/$jobid/$hold/new.html>\n";
       print "<INPUT TYPE=Hidden NAME=method VALUE=hold>\n";
       print "<INPUT TYPE=Submit VALUE=HOLD>\n";
       print "</FORM></TD><TD>\n";
       print "<FORM METHOD=POST action=$apiuri/jobs/$jobid/resumptions/new.html>\n";
       print "<INPUT TYPE=Hidden NAME=method VALUE=resume>\n";
       print "<INPUT TYPE=Submit VALUE=RESUME>\n";
       print "</FORM></TD><TD>\n";
       print "<FORM METHOD=POST action=$apiuri/jobs/$jobid/checkpoints/new.html>\n";
       print "<INPUT TYPE=Hidden NAME=method VALUE=checkpoint>\n";
       print "<INPUT TYPE=Submit VALUE=CHECKPOINT>\n";
       print "</FORM></TD><TD>\n";
       print "<FORM METHOD=POST action=$apiuri/jobs/$jobid/resubmissions/new.html>\n";
       print "<INPUT TYPE=Hidden NAME=method VALUE=resubmit>\n";
       print "<INPUT TYPE=Submit VALUE=RESUBMIT>\n";
       print "</FORM></TD>\n";
       print "</TR></TABLE>\n";
    }
    print apilib::export($result,$ext);
    last;
  };

  #
  # Resources assigned to a job
  #
  $URI = qr{^/jobs/(\d+)/resources(\.yaml|\.json|\.html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $jobid = $1;
    my $ext=apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    oarstatlib::open_db_connection or apilib::ERROR(500,
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                                 );
    my $job = oarstatlib::get_specific_jobs([$jobid]);
    my $resources=oarstatlib::get_job_resources(@$job[0]);
    $resources->{job_id}=$jobid;
    $resources = apilib::struct_job_resources($resources,$STRUCTURE);
    apilib::add_job_resources_uris($resources,$ext,''); 
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($resources,$ext);
    last;
  };

  #
  # Actions on a job (checkpoint, hold, resume,...)
  #
  $URI = qr{^/jobs/(\d+)/(checkpoints|deletions|holds|rholds|resumptions|resubmissions)+/new(\.yaml|\.json|\.html)*$};
  apilib::POST( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $jobid = $1;
    my $action = $2;
    my $ext=apilib::set_ext($q,$3);
    (my $header, my $type)=apilib::set_output_format($ext);
 
     # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before modifying jobs" );
      last;
    }
    $authenticated_user = $1;
    $ENV{OARDO_BECOME_USER} = $authenticated_user;

    # Delete (alternative way to DELETE request, for html forms)
    my $cmd; my $status;
    if ($action eq "deletions" ) {
      $cmd    = "$OARDODO_CMD '$OARDEL_CMD $jobid'";
      $status = "Delete request registered"; 
    }
    # Checkpoint
    elsif ( $action eq "checkpoints" ) {
      $cmd    = "$OARDODO_CMD '$OARDEL_CMD -c $jobid'";
      $status = "Checkpoint request registered"; 
    }
    # Hold
    elsif ( $action eq "holds" ) {
      $cmd    = "$OARDODO_CMD '$OARHOLD_CMD $jobid'";
      $status = "Hold request registered";
    }
    # Hold a running job
    elsif ( $action eq "rholds" ) {
      $cmd    = "$OARDODO_CMD '$OARHOLD_CMD -r $jobid'";
      $status = "Hold request registered";
    }
    # Resume
    elsif ( $action eq "resumptions" ) {
      $cmd    = "$OARDODO_CMD '$OARRESUME_CMD $jobid'";
      $status = "Resume request registered";
    }
    # Resubmit
    elsif ( $action eq "resubmissions" ) {
      $cmd    = "$OARDODO_CMD '$OARSUB_CMD --resubmit $jobid'";
      $status = "Resubmit request registered";
    }
    # Impossible to get here!
    else {
      apilib::ERROR(400,"Bad query","Could not understand ". $action ." method"); 
      last;
    }

    my $cmdRes = apilib::send_cmd($cmd,"Oar");

    # Resubmit case (it is a oarsub and we have to catch the new job_id)
    if ($action eq "resubmissions" ) {
      if ( $? != 0 ) {
        my $err = $? >> 8;
        apilib::ERROR(
          500,
          "Oar server error",
          "Oarsub command exited with status $err: $cmdRes\nCmd:\n$cmd"
        );
      }
      elsif ( $cmdRes =~ m/.*JOB_ID\s*=\s*(\d+).*/m ) {
        print $q->header( -status => 201, -type => "$type" );
        print $HTML_HEADER if ($ext eq "html");
        print apilib::export( { 'resubmit_id' => "$1",
                        'id' => "$jobid",
                        'resubmit_uri' => apilib::htmlize_uri(apilib::make_uri("/jobs/$1",$ext,0),$ext),
                        'job_uri' => apilib::htmlize_uri(apilib::make_uri("/jobs/$jobid",$ext,0),$ext),
                        'status' => "submitted",
                        'cmd_output' => "$cmdRes",
                        'api_timestamp' => time()
                      } , $ext );
      }else {
        apilib::ERROR( 500, "Parse error",
          "Job submitted but the id could not be parsed.\nCmd:\n$cmd" );
      }

    # Other cases
    }else{
      print $q->header( -status => 202, -type => "$type" );
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export( { 'id' => "$jobid",
                      'status' => "$status",
                      'cmd_output' => "$cmdRes",
                      'api_timestamp' => time(),
                      'job_uri' => apilib::htmlize_uri(apilib::make_uri("/jobs/$jobid",$ext,0),$ext)
                    } , $ext );
    }
    last;
  };

  #
  # Update of a job (delete, checkpoint, ...)
  # Should not be used unless for delete from an http browser
  # (better to use the URI above)
  #
  $URI = qr{^/jobs/(\d+)(\.yaml|\.json|\.html)*$};
  apilib::POST( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $jobid = $1;
    my $ext=apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
 
     # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before modifying jobs" );
      last;
    }
    $authenticated_user = $1;
    $ENV{OARDO_BECOME_USER} = $authenticated_user;

    # Check and get the submitted data
    # From encoded data
    my $job;
    if ($q->param('POSTDATA')) {
      $job = apilib::check_job_update( $q->param('POSTDATA'), $q->content_type );
    }
    # From html form
    else {
      $job = apilib::check_job_update( $q->Vars, $q->content_type );
    }
    
    # Delete (alternative way to DELETE request, for html forms)
    my $cmd; my $status;
    if ( $job->{method} eq "delete" ) {
      $cmd    = "$OARDODO_CMD '$OARDEL_CMD $jobid'";
      $status = "Delete request registered"; 
    }
    # Checkpoint
    elsif ( $job->{method} eq "checkpoint" ) {
      $cmd    = "$OARDODO_CMD '$OARDEL_CMD -c $jobid'";
      $status = "Checkpoint request registered"; 
    }
    # Hold
    elsif ( $job->{method} eq "hold" ) {
      $cmd    = "$OARDODO_CMD '$OARHOLD_CMD $jobid'";
      $status = "Hold request registered";
    }
    # Resume
    elsif ( $job->{method} eq "resume" ) {
      $cmd    = "$OARDODO_CMD '$OARRESUME_CMD $jobid'";
      $status = "Resume request registered";
    }
    else {
      apilib::ERROR(400,"Bad query","Could not understand ". $job->{method} ." method"); 
      last;
    }

    my $cmdRes = apilib::send_cmd($cmd,"Oar");
    print $q->header( -status => 202, -type => "$type" );
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export( { 'id' => "$jobid",
                    'status' => "$status",
                    'cmd_output' => "$cmdRes",
                    'api_timestamp' => time(),
                    'job_uri' => apilib::htmlize_uri(apilib::make_uri("/jobs/$jobid",$ext,0),$ext)
                  } , $ext );
    last;
  };

  #
  # Signal sending
  #
  $URI = qr{^/jobs/(\d+)/signals/(\d+)(\.yaml|\.json|\.html)*$};
  apilib::POST( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $jobid = $1;
    my $signal = $2;
    my $ext=apilib::set_ext($q,$3);
    (my $header, my $type)=apilib::set_output_format($ext);
 
     # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before modifying jobs" );
      last;
    }
    $authenticated_user = $1;
    $ENV{OARDO_BECOME_USER} = $authenticated_user;

    my $cmd    = "$OARDODO_CMD '$OARDEL_CMD -s $signal $jobid'";
    my $status = "Signal sending request registered"; 

    my $cmdRes = apilib::send_cmd($cmd,"Oar");
    print $q->header( -status => 202, -type => "$type" );
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export( { 'id' => "$jobid",
                    'status' => "$status",
                    'cmd_output' => "$cmdRes",
                    'api_timestamp' => time()
                  } , $ext );
    last;
  };

  #
  # List of resources or details of a resource
  #
  $URI = qr{^/resources(/full|/[0-9]+)*\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    
    # GET limit from uri parameter
    if (defined($q->param('limit'))) {
        $MAX_ITEMS = $q->param('limit');
    }
    # set offset / GET offset from uri parameter
    my $offset = 0;
    if (defined($q->param('offset'))) {
        $offset = $q->param('offset');
    }
    
    my $resources;
    oarnodeslib::open_db_connection or apilib::ERROR(500, 
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                                 );
    if (defined($1)) {
    	if ($1 eq "/full") {
    		# get specified intervals of resources
    		$resources = oarnodeslib::get_requested_resources($MAX_ITEMS,$offset);         
    	}
        elsif ($1 =~ /\/([0-9]+)/)  {
        	$resources = [oarnodeslib::get_resource_infos($1)];   
        }
        else {
        	apilib::ERROR(500,"Error 666!","Error 666");           
        }
    }
    else
    {
    	# get specified intervals of resources
    	$resources = oarnodeslib::get_requested_resources($MAX_ITEMS,$offset); 
        $resources = apilib::filter_resource_list($resources); 
    }
    oarnodeslib::close_db_connection;
    apilib::add_resources_uris($resources,$ext,'');
    $resources = apilib::struct_resource_list($resources,$STRUCTURE,1);
    
    # get the total number of resources
    my $total_resources = oarnodeslib::count_all_resources();
    # add pagination informations
    $resources = apilib::add_pagination($resources,$total_resources,$q->path_info,$q->query_string,$ext,$MAX_ITEMS,$offset,$STRUCTURE);
 

    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($resources,$ext);
    last;
  };
 
  #
  # Details of a node
  #
  $URI = qr{^/resources/nodes/([\w\.-]+?)(\.yaml|\.json|\.html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    oarnodeslib::open_db_connection or apilib::ERROR(500, 
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                                 );
    my $resources = oarnodeslib::get_resources_for_host($1);
    $resources = apilib::filter_resource_list($resources);
    oarnodeslib::close_db_connection;
    apilib::add_resources_uris($resources,$ext,'');
    $resources = apilib::struct_resource_list($resources,$STRUCTURE,0);
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($resources,$ext);
    last;
  };

  #
  # Jobs running on a resource
  #
  $URI = qr{^/resources(/all|/[0-9]+)+/jobs(\.yaml|\.json|\.html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    oarnodeslib::open_db_connection or apilib::ERROR(500, 
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                                 );
    my $jobs;
    if ($1 eq "/all") { 
        # Not implemented yet
        # should give an array of all resources plus a job array per resource
        $jobs = [];
    }
    elsif ($1 =~ /\/([0-9]+)/)  { 
        my $job_array=oarnodeslib::get_jobs_running_on_resource($1);
        foreach my $job_id (@$job_array) {
          #push(@$jobs,{id =>$job_id,resource_id=>$1});
          push(@$jobs,{id =>$job_id});
        }
        apilib::add_jobs_on_resource_uris($jobs,$ext); 
    }
    oarnodeslib::close_db_connection;
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($jobs,$ext);
    last;
  }; 

  #
  # A new job (oarsub wrapper)
  #
  $URI = qr{^/jobs\.*(yaml|json|html)*$};
  apilib::POST( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$1);
    (my $header, my $type)=apilib::set_output_format($ext);

    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before posting jobs" );
      last;
    }
    $authenticated_user = $1;
    $ENV{OARDO_BECOME_USER} = $authenticated_user;

    # Check and get the submitted job
    # From encoded data
    my $job;
    if ($q->param('POSTDATA')) {
      $job = apilib::check_job( $q->param('POSTDATA'), $q->content_type );
    }
    # From html form
    else {
      $job = apilib::check_job( $q->Vars, $q->content_type );
    }

    # Make the query (the hash is converted into a list of long options)
    my $oarcmd = "$OARSUB_CMD ";
    my $workdir = "~$authenticated_user";
    my $command = "";
    foreach my $option ( keys( %{$job} ) ) {
    # Note: actualy, now, script_path, script and command are the same thing
      if ($option eq "script_path") {
        $command = " \"$job->{script_path}\"";
      }
      elsif ($option eq "command") {
        $command = " \"$job->{command}\"";
      }
      elsif ($option eq "script") {
        $command = " \"$job->{script}\"";
      }
      elsif ($option eq "workdir") {
        $workdir = $job->{workdir};
      }
      elsif ($option eq "resources") {
        $oarcmd .= " --resource=$job->{resources}";
      }
      elsif (ref($job->{$option}) eq "ARRAY") {
        foreach my $elem (@{$job->{$option}}) {
          $oarcmd .= " --$option";
          $oarcmd .= "=\"$elem\"" if $elem ne "";
         }
      }
      else {
        $oarcmd .= " --$option";
        $oarcmd .= "=\"$job->{$option}\"" if $job->{$option} ne "";
      }
    }
    $oarcmd .= $command;
    $oarcmd =~ s/\"/\\\"/g;

    my $cmd = "$OARDODO_CMD \"cd $workdir && $oarcmd\"";
    my $cmdRes = `$cmd 2>&1`;
    if ( $? != 0 ) {
      my $err = $? >> 8;
      apilib::ERROR(
        500,
        "Oar server error",
        "Oarsub command exited with status $err: $cmdRes\nCmd:\n$oarcmd"
      );
    }
    elsif ( $cmdRes =~ m/.*JOB_ID\s*=\s*(\d+).*/m ) {
      print $q->header( -status => 201, -type => "$type" );
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export( { 'id' => "$1",
                      'uri' => apilib::htmlize_uri(apilib::make_uri("/jobs/$1",$ext,0),$ext),
                      'status' => "submitted",
                      'api_timestamp' => time()
                    } , $ext );
    }
    else {
      apilib::ERROR( 500, "Parse error",
        "Job submitted but the id could not be parsed.\nCmd:\n$oarcmd" );
    }
    last;
  };

  #
  # Delete a job (oardel wrapper)
  #
  $URI = qr{^/jobs/(\d+)(\.yaml|\.json|\.html)*$};
  apilib::DELETE( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $jobid = $1;
    my $ext=apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);

    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
       "A suitable authentication must be done before deleting jobs" );
      last;
    }
    $authenticated_user = $1;
    $ENV{OARDO_BECOME_USER} = $authenticated_user;

    my $cmd    = "$OARDODO_CMD '$OARDEL_CMD $jobid'";
    my $cmdRes = apilib::send_cmd($cmd,"Oardel");
    print $q->header( -status => 202, -type => "$type" );
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export( { 'id' => "$jobid",
                    'status' => "Delete request registered",
                    'oardel_output' => "$cmdRes",
                    'api_timestamp' => time()
                  } , $ext );
    last;
  };

  #
  # Create a new resource
  # 
  $URI = qr{^/resources(\.yaml|\.json|\.html)*$};
  apilib::POST( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$1);
    (my $header)=apilib::set_output_format($ext);

    # Must be administrator (oar user)
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before creating new resources" );
      last;
    }
    if ( not $authenticated_user eq "oar" ) {
      apilib::ERROR( 401, "Permission denied",
        "Only the oar user can create new resources" );
      last;
    }
    $ENV{OARDO_BECOME_USER} = "oar";
  
    # Check and get the submited resource
    # From encoded data
    my $resource;
    if ($q->param('POSTDATA')) {
      $resource = apilib::check_resource( $q->param('POSTDATA'), $q->content_type );
    }
    # From html form
    else {
      $resource = apilib::check_resource( $q->Vars, $q->content_type );
    }

    my $dbh = iolib::connect() or apilib::ERROR(500, 
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                                 );
    my $id=iolib::add_resource($dbh,$resource->{hostname},"Alive");
    my $status="ok";
    my @warnings;
    if ( $id && $id > 0) {
      if ( $resource->{properties} ) {
        foreach my $property ( keys %{$resource->{properties}} ) {
           if (oar_Tools::check_resource_system_property($property) == 1){
             $status = "warning";
             push(@warnings,"Cannot update property $property because it is a system field.");
           }
           my $ret = iolib::set_resource_property($dbh,$id,$property,$resource->{properties}->{$property});
           if($ret != 2 && $ret != 0){
             $status = "warning";
             push(@warnings,"wrong property $property or wrong value");
           }
        }
      }
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export( { 
                      'status' => "$status",
                      'id' => "$id",
                      'warnings' => \@warnings,
                      'api_timestamp' => time(),
                      'uri' => apilib::htmlize_uri(apilib::make_uri("/resources/$id",$ext,0),$ext)
                    } , $ext );
      oar_Tools::notify_tcp_socket($remote_host,$remote_port,"ChState");
      oar_Tools::notify_tcp_socket($remote_host,$remote_port,"Term");
      iolib::disconnect($dbh);
    }
    else {
      apilib::ERROR(
        500,
        "Resource not created",
        "Could not create the new resource or get the new id"
      );
    }
    last;
  }; 

  #
  # Change the state of a resource
  # 
  $URI = qr{^/resources/(\d+)/state(\.yaml|\.json|\.html)*$};
  apilib::POST( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $id=$1;
    my $ext=apilib::set_ext($q,$2);
    (my $header)=apilib::set_output_format($ext);

    # Must be administrator (oar user)
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before creating new resources" );
      last;
    }
    if ( not $authenticated_user eq "oar" ) {
      apilib::ERROR( 401, "Permission denied",
        "Only the oar user can create new resources" );
      last;
    }
    $ENV{OARDO_BECOME_USER} = "oar";
  
    # Check and get the submited resource
    # From encoded data
    my $resource;
    if ($q->param('POSTDATA')) {
      $resource = apilib::check_resource_state( $q->param('POSTDATA'), $q->content_type );
    }
    # From html form
    else {
      $resource = apilib::check_resource_state( $q->Vars, $q->content_type );
    }

    my $dbh = iolib::connect() or apilib::ERROR(500, 
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                                 );
    iolib::set_resource_state($dbh,$id,$resource->{state},"NO");
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export( { 
                      'status' => "Change state request registered",
                      'id' => "$id",
                      'api_timestamp' => time(),
                      'uri' => apilib::htmlize_uri(apilib::make_uri("/resources/$id",$ext,0),$ext)
                    } , $ext );
    oar_Tools::notify_tcp_socket($remote_host,$remote_port,"ChState");
    oar_Tools::notify_tcp_socket($remote_host,$remote_port,"Term");
    iolib::disconnect($dbh);
    last;
  }; 

  #
  # Delete a resource
  #
  $URI = qr{^/resources/([\w\.-]+?)(/\d)*(\.yaml|\.json|\.html)*$};
  apilib::DELETE( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $id;
    my $node;
    my $cpuset;
    if ($2) { $node=$1; $id=0; $cpuset=$2; $cpuset =~ s,^/,, ;}
    else    { $node=""; $id=$1; $cpuset=""; } ;
    my $ext=apilib::set_ext($q,$3);
    (my $header)=apilib::set_output_format($ext);

    # Must be administrator (oar user)
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before deleting new resources" );
      last;
    }
    if ( not $authenticated_user eq "oar" ) {
      apilib::ERROR( 401, "Permission denied",
        "Only the oar user can delete resources" );
      last;
    }
    $ENV{OARDO_BECOME_USER} = "oar";

    my $base = iolib::connect() or apilib::ERROR(500, 
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                                 );
 
    # Check if the resource exists
    my $query;
    my $Resource;
    if ($id == 0) {
      $query="WHERE network_address = \"$node\" AND cpuset = $cpuset";
    }
    else {
      $query="WHERE resource_id=$id";
    }
    my $sth = $base->prepare("SELECT resource_id FROM resources $query");
    $sth->execute();
    my @res = $sth->fetchrow_array();
    if ($res[0]) { $Resource=$res[0];}
    else { 
      apilib::ERROR(404,"Not found","Corresponding resource could not be found ($id,$node,$cpuset)");
      last;
    }

    # Resource deletion
    # !!! This is a dirty cut/paste of oarremoveresource code !!!
    my $resource_ref = iolib::get_resource_info($base,$Resource);
    if (defined($resource_ref->{state}) && ($resource_ref->{state} eq "Dead")){
      my $sth = $base->prepare("  SELECT jobs.job_id, jobs.assigned_moldable_job
                                  FROM assigned_resources, jobs
                                  WHERE
                                      assigned_resources.resource_id = $Resource
                                      AND assigned_resources.moldable_job_id = jobs.assigned_moldable_job
                               ");
      $sth->execute();
      my @jobList;
      while (my @ref = $sth->fetchrow_array()) {
          push(@jobList, [$ref[0], $ref[1]]);
      }
      $sth->finish();
      foreach my $i (@jobList){
        $base->do("DELETE from event_logs         WHERE job_id = $i->[0]");
        $base->do("DELETE from frag_jobs          WHERE frag_id_job = $i->[0]");
        $base->do("DELETE from jobs               WHERE job_id = $i->[0]");
        $base->do("DELETE from assigned_resources WHERE moldable_job_id = $i->[1]");
      }
      $base->do("DELETE from assigned_resources     WHERE resource_id = $Resource");
      $base->do("DELETE from resource_logs          WHERE resource_id = $Resource");
      $base->do("DELETE from resources              WHERE resource_id = $Resource");
      #print("Resource $Resource removed.\n");
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export( { 'status' => "deleted",'api_timestamp' => time() } , $ext );
    }else{
      apilib::ERROR(403,"Forbidden","The resource $Resource must be in the Dead status"); 
      last;
    }
    last;
  };

  #
  # Html form for job posting
  #
  $URI = qr{^/jobs/form.html$};
  apilib::GET( $_, $URI ) && do {
    (my $header, my $type)=apilib::set_output_format("html");
    print $header;
    print $HTML_HEADER;
    my $POSTFORM="";
    my $file;
    if (is_conf("API_HTML_POSTFORM")){ $file=get_conf("API_HTML_POSTFORM"); }
    else { $file="/etc/oar/api_html_postform.pl"; }
    open(FILE,$file);
    my(@lines) = <FILE>;
    eval join("\n",@lines);
    close(FILE);
    print $POSTFORM;
    last;
  };

  #
  # List of all admissions rules
  #
  $URI = qr{^/admission_rules\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
  	$_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$1);
    (my $header, my $type) = apilib::set_output_format($ext);
    
    # GET limit from uri parameter
    if (defined($q->param('limit'))) {
        $MAX_ITEMS = $q->param('limit');
    }
    # set offset / GET offset from uri parameter
    my $offset = 0;
    if (defined($q->param('offset'))) {
        $offset = $q->param('offset');
    }
    oarstatlib::open_db_connection or apilib::ERROR(500, 
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                          );
    # get specified intervals of admission rules
    my $admissions_rules = oarstatlib::get_requested_admission_rules($MAX_ITEMS,$offset);
    
    apilib::add_admission_rules_uris($admissions_rules,$ext);
    $admissions_rules = apilib::struct_admission_rule_list($admissions_rules,$STRUCTURE);
    
    # get the total number of admissions rules
    my $total_rules = oarstatlib::count_all_admission_rules();
    oarstatlib::close_db_connection();
    
    # add pagination informations
    $admissions_rules = apilib::add_pagination($admissions_rules,$total_rules,$q->path_info,$q->query_string,$ext,$MAX_ITEMS,$offset,$STRUCTURE);
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($admissions_rules,$ext);
    last;
  };

  #
  # Details of an admission rule
  #
  $URI = qr{^/admission_rules/(\d+)(\.yaml|\.json|\.html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $rule_id = $1;
    my $ext = apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
 
    oarstatlib::open_db_connection or apilib::ERROR(500, 
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                                 );
    my $admission_rule = oarstatlib::get_specific_admission_rule($rule_id);
    apilib::add_admission_rule_uris($admission_rule,$ext);
    $admission_rule = apilib::struct_admission_rule($admission_rule,$STRUCTURE);

    oarstatlib::close_db_connection; 
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($admission_rule,$ext);
    last;
  };

  #
  # Create a new admission rule
  # 
  $URI = qr{^/admission_rules(\.yaml|\.json|\.html)*$};
  (apilib::POST( $_, $URI ) || apilib::PUT( $_, $URI )) && do {
    $_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$1);
    (my $header) = apilib::set_output_format($ext);

    # Must be administrator (oar user)
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before creating new admission rules" );
      last;
    }
    if ( not $authenticated_user eq "oar" ) {
      apilib::ERROR( 401, "Permission denied",
        "Only the oar user can create new admission rules" );
      last;
    }
    $ENV{OARDO_BECOME_USER} = "oar";
  
    # Check and get the submited admission rule
    # From encoded data
    my $admission_rule;

    if ($q->param('POSTDATA')) {
      $admission_rule = apilib::check_admission_rule( $q->param('POSTDATA'), $q->content_type );
    }
    elsif ($q->param('PUTDATA')) {
      $admission_rule = apilib::check_admission_rule( $q->param('PUTDATA'), $q->content_type );
    }
    # From html form
    else {
      $admission_rule = apilib::check_admission_rule( $q->Vars, $q->content_type );
    }

    oarstatlib::open_db_connection or apilib::ERROR(500, 
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                                 );
    my $id = oarstatlib::add_admission_rule($admission_rule->{rule});
    if ( $id && $id > 0) {
      	print $header;
      	print $HTML_HEADER if ($ext eq "html");
      	print apilib::export( { 
                      'id' => "$id",
                      'rule' => apilib::nl2br($admission_rule->{rule}),
                      'api_timestamp' => time(),
                      'uri' => apilib::htmlize_uri(apilib::make_uri("/admission_rules/$id",$ext,0),$ext)
                    } , $ext );
      	oarstatlib::close_db_connection; 
    }
    else {
      apilib::ERROR(
        500,
        "Admission rule not created",
        "Could not create the new admission rule"
      );
    }
    last;
  };

  #
  # Delete an admission rule
  #
  $URI = qr{^/admission_rules/(\d+)(\.yaml|\.json|\.html)*$};
  apilib::DELETE( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $rule_id = $1;
    my $ext = apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);

    # Must be administrator (oar user)
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before deleting an admission rule" );
      last;
    }
    if ( not $authenticated_user eq "oar" ) {
      apilib::ERROR( 401, "Permission denied",
        "Only the oar user can delete admission rules" );
      last;
    }
    $authenticated_user = $1;
    $ENV{OARDO_BECOME_USER} = $authenticated_user;
    

    oarstatlib::open_db_connection or apilib::ERROR(500, 
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                                 );
    my $admission_rule = oarstatlib::get_specific_admission_rule($rule_id);
    print $header;
    if (defined($admission_rule)) {
    	oarstatlib::delete_specific_admission_rule($rule_id);
    	print $HTML_HEADER if ($ext eq "html");
    	print apilib::export( { 'id' => "$admission_rule->{id}",
    				            'rule' => "$admission_rule->{rule}",
                    			'status' => "Delete request registered",
                    			'api_timestamp' => time()
    						  } , $ext );
        oarstatlib::close_db_connection; 
    }
    else {
    	apilib::ERROR(404,"Not found","Corresponding admission rule could not be found");
    }
    last;
  };

  #
  # Delete an admission rule
  # Should not be used unless for delete from an http browser
  # (better to use the URI above)
  #
  $URI = qr{^/admission_rules/(\d+)(\.yaml|\.json|\.html)*$};
  apilib::POST( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $rule_id = $1;
    my $ext = apilib::set_ext($q,$2);
    (my $header, my $type) = apilib::set_output_format($ext);
 
     # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before deleting an admission rule" );
      last;
    }
    $authenticated_user = $1;
    $ENV{OARDO_BECOME_USER} = $authenticated_user;
    
    oarstatlib::open_db_connection or apilib::ERROR(500, 
                                                "Cannot connect to the database",
                                                "Cannot connect to the database"
                                                 );
    # Check and get the submitted data
    # From encoded data
    my $admission_rule;
    if ($q->param('POSTDATA')) {
      $admission_rule = apilib::check_admission_rule_update( $q->param('POSTDATA'), $q->content_type );
    }
    # From html form
    else {
      $admission_rule = apilib::check_admission_rule_update( $q->Vars, $q->content_type );
    }

    # Delete (alternative way to DELETE request, for html forms)
    print $header;
    if ($admission_rule->{method} eq "delete" ) {
    	oarstatlib::delete_specific_admission_rule($rule_id);
    	print $HTML_HEADER if ($ext eq "html");
    	print apilib::export( { 'id' => "$rule_id",
                    			'status' => "Delete request registered",
                    			'api_timestamp' => time()
    						  } , $ext );
        oarstatlib::close_db_connection;
    }
    else {
      apilib::ERROR(400,"Bad query","Could not understand ". $admission_rule->{method} ." method");
    }
    last;
  };
  
   #
  # Html form for admission rules submission
  #
  $URI = qr{^/admission_rules/form.html$};
  apilib::GET( $_, $URI ) && do {
    (my $header, my $type)=apilib::set_output_format("html");
    print $header;
    print $HTML_HEADER;
    my $POSTFORM="";
    my $file = "/etc/oar/api_html_postform_rule.pl";
    open(FILE,$file);
    my(@lines) = <FILE>;
    eval join("\n",@lines);
    close(FILE);
    print $POSTFORM;
    last;
  };


  #
  # Generate resources (oaradmin wrapping)
  #
  $URI = qr{^/resources/generate(\.yaml|\.json|\.html)*$};
  apilib::POST( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$1);
    (my $header) = apilib::set_output_format($ext);

    # Must be administrator (oar user)
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before generating resources" );
      last;
    }
    if ( not $authenticated_user eq "oar" ) {
      apilib::ERROR( 401, "Permission denied",
        "Only the oar user can generate resources" );
      last;
    }
    $ENV{OARDO_BECOME_USER} = "oar";

    # Check and get the submited resource description
    # From encoded data
    my $description;
    
    # command generation
    my $cmd;    
    # ressources properties
    my $cmd_properties;
    
    if ($q->param('POSTDATA')) {
      $description = apilib::check_resource_description( $q->param('POSTDATA'), $q->content_type );
      # getting properties
      if (defined($description->{properties})) {
    	foreach my $property ( keys %{$description->{properties}} ) {
    		$cmd_properties .= " -p ".$property."=".$description->{properties}->{$property}
        }
      }
    }
    # From html form
    else {
      $description = apilib::check_resource_description( $q->Vars, $q->content_type );
      # getting properties
      if (defined($description->{properties})) {
      	my @properties = split(/,/,$description->{properties});
      	foreach my $property (@properties) {
      		$cmd_properties .= " -p $property";
      	}
      }
    }

    # command with arguments
    $cmd = "$OARADMIN_CMD resources -a ".$description->{resources}.$cmd_properties;
    # add commit option to command
    $cmd .= " -c";
    # execute the command
    my $cmdRes = apilib::send_cmd($cmd,"Oar");
    # Test the status returned by the subprocess command
    if ( $? != 0 ) {
    	# Error
    	my $err = $? >> 8;
        apilib::ERROR(
          500,
          "Oar server error",
          "Oaradmin command exited with status $err: $cmdRes\nCmd:\n$cmd"
        );
     }
     else {
     	# Success
     	my $list_nodes = apilib::get_list_nodes($description->{resources});
     	my $statement = "\"network_address IN (";
     	foreach my $node (@$list_nodes) {
    		$statement .= oarstatlib::set_quote($node);
    		$statement .= ",";
    	}
    	chop($statement);
    	$statement .= ")\"";

    	$cmd = "$OARNODES_CMD -Y --sql $statement";  	
    	$cmdRes = apilib::send_cmd($cmd,"Oar");
    	
    	my $data = apilib::import($cmdRes,"yaml");

    	print $header;
        print $HTML_HEADER if ($ext eq "html");
    	print apilib::export($data,$ext);
     }
    last;
  };
  
  #
  # Html form for resources generation
  #
  $URI = qr{^/resources/form.html$};
  apilib::GET( $_, $URI ) && do {
    (my $header, my $type)=apilib::set_output_format("html");
    print $header;
    print $HTML_HEADER;
    my $POSTFORM="";
    my $file = "/etc/oar/api_html_postform_resources.pl";
    open(FILE,$file);
    my(@lines) = <FILE>;
    eval join("\n",@lines);
    close(FILE);
    print $POSTFORM;
    last;
  };

  #
  # List of all the configured variables
  #
  $URI = qr{^/config\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
  	$_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$1);
    (my $header, my $type) = apilib::set_output_format($ext);
    
    # Must be administrator (oar user)
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before getting configuration parameters" );
      last;
    }
    if ( not $authenticated_user eq "oar" ) {
      apilib::ERROR( 401, "Permission denied",
        "Only the oar user can get configuration parameters" );
      last;
    }
    $ENV{OARDO_BECOME_USER} = "oar";

    # get all configured parameters
    my $list_params = get_conf_list();
    # parameters hash result
    my $parameters;

    if ( !defined $list_params || keys %$list_params == 0 ) {
      $parameters = apilib::struct_empty($STRUCTURE);
    }
    else {
    	foreach my $param (keys %$list_params) {
    		$parameters->{$param}->{value} =  $list_params->{$param};
    	}
    	apilib::add_config_parameters_uris($parameters,$ext);
    	$parameters = apilib::struct_config_parameters_list($parameters,$STRUCTURE);
    }

    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($parameters,$ext);
    last;
  };

  #
  # Get a configuration variable value
  #
  $URI = qr{^/config/(\w+)\.(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
  	$_->path_info =~ m/$URI/;
  	my $variable = $1;
    my $ext = apilib::set_ext($q,$2);
    (my $header, my $type) = apilib::set_output_format($ext);
    
    # Must be administrator (oar user)
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before getting configuration parameters" );
      last;
    }
    if ( not $authenticated_user eq "oar" ) {
      apilib::ERROR( 401, "Permission denied",
        "Only the oar user can get configuration parameters" );
      last;
    }
    $ENV{OARDO_BECOME_USER} = "oar";

    # result parameter
    my $parameter;
    if (is_conf($variable)) {
    	$parameter->{id} = $variable;
    	$parameter->{value} = get_conf($variable);
    	apilib::add_config_parameter_uris($parameter,$ext);
    	$parameter = apilib::struct_config_parameter($parameter,$STRUCTURE);
    }
    else {
    	$parameter->{id} = apilib::struct_empty($STRUCTURE);
    }

    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($parameter,$ext);
    last;
  };
  
  #
  # Change the value of a configuration parameter
  #
  $URI = qr{^/config/(\w+)\.(yaml|json|html)*$};
  apilib::POST( $_, $URI ) && do {
  	$_->path_info =~ m/$URI/;
  	my $variable = $1;
    my $ext = apilib::set_ext($q,$2);
    (my $header, my $type) = apilib::set_output_format($ext);
    
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    
    # Must be administrator (oar user)
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before changing configuration parameters" );
      last;
    }
    if ( not $authenticated_user eq "oar" ) {
      apilib::ERROR( 401, "Permission denied",
        "Only the oar user can make changes on configuration parameters" );
      last;
    }
    $ENV{OARDO_BECOME_USER} = "oar";

    # configuration parameter
    my $parameter;

    if ($q->param('POSTDATA')) {
      $parameter = apilib::check_configuration_variable( $q->param('POSTDATA'), $q->content_type );
    }
    # From html form
    else {
      $parameter = apilib::check_configuration_variable( $q->Vars, $q->content_type );
    }

    my $result;
    if (is_conf($variable)) {
    	set_value($variable, $parameter->{value});
    	$result->{$variable} = $parameter;
    }
    else {
    	$result->{$variable} = apilib::struct_empty($STRUCTURE);
    }

    print apilib::export($result,$ext);
    last;
  };


  #
  # Anything else -> 404
  #
  apilib::ERROR( 404, "Not found", "No way to handle your request " . $q->path_info );
}

sub message($) {
    my $msg = shift;
    warn $msg;
}

sub getJobsToLaunch($) {
    #TODO: get from the oar conf file
    my $allow_create_node = "0";
    my $quit=undef;
    #TODO hardcoded
    my $hostname=shift;
    my $base = iolib::connect() or die "cannot connect to the data base\n";
    my $is_desktop_computing = iolib::is_node_desktop_computing($base,$hostname);

    my $dbJobs = iolib::get_desktop_computing_host_jobs($base,$hostname);
    my $toLaunchJobs = undef;
    my $toKillJobs = undef;
    iolib::disconnect($base);
    foreach my $jobid (keys %$dbJobs) {
        unless ($$dbJobs{$jobid}{'state'} eq 'toLaunch') {
            delete($$dbJobs{$jobid});
        }
    }
    print apilib::export($dbJobs,'json');
}
sub jobStageIn($) {
    my $jobid = shift;
    my $base = iolib::connect() or die "cannot connect to the data base\n";
    my $stagein = iolib::get_job_stagein($base,$jobid);
    iolib::disconnect($base);
    if ($stagein->{'method'} eq "FILE") {
        open F,"< ".$stagein->{'location'} or die "Can't open stagein ".$stagein->{'location'}.": $!";
        print <F>;
        close F;
    } else {
        die "Stagein method ".$stagein->{'method'}." not yet implemented.\n";
    } 
}

sub terminateJob($) {
    my $jobid = shift;
    my $base = iolib::connect() or die "cannot connect to the data base\n";
    iolib::lock_table($base,["jobs","job_state_logs","resources","assigned_resources","event_logs","challenges","moldable_job_descriptions","job_types","job_dependencies","job_resource_groups","job_resource_descriptions"]);
    iolib::set_job_state($base,$jobid,"Terminated");
    
    iolib::set_finish_date($base,$jobid);
    iolib::set_job_message($base,$jobid,"ALL is GOOD");
    iolib::unlock_table($base);
    iolib::disconnect($base);
}

sub runJob($) {
    my $jobid = shift;
    my $base = iolib::connect() or die "cannot connect to the data base\n";
    iolib::lock_table($base,["jobs","job_state_logs","resources","assigned_resources","event_logs","challenges","moldable_job_descriptions","job_types","job_dependencies","job_resource_groups","job_resource_descriptions"]);
    iolib::set_running_date($base,$jobid);
    iolib::set_job_state($base,$jobid,"Running");
    iolib::unlock_table($base);
    iolib::disconnect($base);
}
sub errorJob() {
}

sub sign_in($) {
    my $hostname = shift;
    my $do_notify;
    my $base = iolib::connect() or die "cannot connect to the data base\n";
    my $is_desktop_computing = iolib::is_node_desktop_computing($base,$hostname);
    if (defined $is_desktop_computing and $is_desktop_computing eq 'YES'){
	    iolib::lock_table($base,["resources"]);
	    if (iolib::set_node_nextState_if_necessary($base,$hostname,"Alive") > 0){
		$do_notify=1;
	    }
	    iolib::set_node_expiryDate($base,$hostname, iolib::get_date($base) + $expiry);
	    iolib::unlock_table($base);
    }
    elsif ($allow_create_node) {
        my $resource = iolib::add_resource($base, $hostname, "Alive");
        iolib::set_resource_property($base,$resource,"desktop_computing","YES");
        iolib::set_resource_nextState($base,$resource,"Alive");
        iolib::set_node_expiryDate($base,$hostname, iolib::get_date($base) + $expiry);
        $do_notify=1;        
    } 
    if ($do_notify) {
	oar_Tools::notify_tcp_socket($remote_host,$remote_port,"ChState");
    }

    iolib::disconnect($base);
}
