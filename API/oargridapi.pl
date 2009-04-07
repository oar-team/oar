#!/usr/bin/perl -w
use strict;
use oargrid_lib;
use oargrid_conflib;
use oar_apilib;
use oar_conflib qw(init_conf dump_conf get_conf is_conf);

my $VERSION="0.1.6";

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

# The ssh command to use to contact the frontends
my $SSH_CMD = "/usr/bin/ssh";

# Enable this if you are ok with a simple pidentd "authentication"
# Not very secure, but useful for testing (no need for login/password)
# or in the case you fully trust the client hosts (with an apropriate
# ip-based access control into apache for example)
my $TRUST_IDENT = 1;
if (is_conf("API_TRUST_IDENT")){ $TRUST_IDENT = get_conf("API_TRUST_IDENT"); }

# Default data structure variant
my $STRUCTURE="simple";
if (is_conf("API_DEFAULT_DATA_STRUCTURE")){ $STRUCTURE = get_conf("API_DEFAULT_DATA_STRUCTURE"); }

# Oar commands
my $OARDODO_CMD = "$ENV{OARDIR}/oardodo/oardodo";
my $OARGRIDSUB_CMD = "oargridsub";

# CGI handler
my $q = apilib::get_cgi_handler();

# Header for html version
my $apiuri=apilib::get_api_uri_relative_base();
$apiuri =~ s/\/$//;
my $HTML_HEADER="";
my $file;
if (is_conf("GRIDAPI_HTML_HEADER")){ $file=get_conf("GRIDAPI_HTML_HEADER"); }
else { $file="/etc/oar/gridapi_html_header.pl"; }
open(FILE,$file);
my(@lines) = <FILE>;
eval join("\n",@lines);
close(FILE);

##############################################################################
# INIT
##############################################################################

# Initialize database connection
oargrid_conflib::init_conf( oargrid_lib::get_config_file_name() );
my $DB_SERVER      = oargrid_conflib::get_conf("DB_HOSTNAME");
my $DB_BASE_NAME   = oargrid_conflib::get_conf("DB_BASE_NAME");
my $DB_BASE_LOGIN  = oargrid_conflib::get_conf("DB_BASE_LOGIN");
my $DB_BASE_PASSWD = oargrid_conflib::get_conf("DB_BASE_PASSWD");

my $dbh = oargrid_lib::connect( $DB_SERVER, $DB_BASE_NAME, $DB_BASE_LOGIN,
  $DB_BASE_PASSWD );


# In this script, oar becomes oargrid
$ENV{OARDO_BECOME_USER} = "oargrid";

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
# URI management
##############################################################################

SWITCH: for ($q) {
  my $URI;

  #
  # Welcome page
  #
  $URI = qr{^/index\.html$};
  apilib::GET( $_, $URI ) && do {
    print $q->header( -status => 200, -type => "text/html" );
    print $HTML_HEADER;
    print "Welcome on the oargrid API\n";
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
    my $version={ "oargrid" => oargrid_lib::get_version(),
                  "apilib" => apilib::get_version(),
                  "api" => $VERSION };
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($version,$ext);
    last;
  };

  #
  # The sites list
  #
  $URI = qr{^/sites\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$1);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $sites = apilib::get_sites($dbh);
    apilib::add_sites_uris($sites,$ext);
    $sites = apilib::struct_sites_list($sites,$STRUCTURE);
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($sites,$ext);
    last;
  };

  #
  # Site details
  #
  $URI = qr{^/sites/([a-z,0-9,-]+)\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $sites = apilib::get_sites($dbh);
    if ( defined( $sites->{$1} ) ) {
      $sites={ $1 =>  $sites->{$1} };
      apilib::add_sites_uris($sites,$ext);
      $sites = apilib::struct_site($sites,$STRUCTURE);
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export($sites,$ext);
    }
    else {
      apilib::ERROR( 404, "Not found", "Site not found" );
    }
    last;
  };

  #
  # Site resources (oarnodes wrapper)
  #  
  $URI = qr{^/sites/([a-z,0-9,-]+)/resources(/all|/[0-9]+)*\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $site  = $1;
    my $ext=apilib::set_ext($q,$3);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $clusters = {};
    $clusters = apilib::get_clusters($dbh);
    if ( not defined( $clusters->{$site} ) ) {
      apilib::ERROR( 404, "Not found", "Site or cluster resource not found" );
    }
    else {
      my $frontend = $clusters->{$site}->{hostname};
      my $cmd;
      if (defined($2)) {
        if    ($2 eq "/all")        { $cmd = "$OARDODO_CMD $SSH_CMD $frontend \"oarnodes -D\""; }
        elsif ($2 =~ /\/([0-9]+)/)  { $cmd = "$OARDODO_CMD $SSH_CMD $frontend \"oarnodes -D -r $1\""; }
        else                        { $cmd = "$OARDODO_CMD $SSH_CMD $frontend \"oarnodes -D -s\""; }
      }
      else                          { $cmd = "$OARDODO_CMD $SSH_CMD $frontend \"oarnodes -D -s\""; }
      my $cmdRes = apilib::send_cmd($cmd,"Oarnodes on $frontend");
      my $resources = apilib::import($cmdRes,"dumper");
      if (defined($2) && $2 =~ /\/([0-9]+)/) {
        $resources = { @$resources[0]->{properties}->{network_address}
           => { @$resources[0]->{resource_id} => @$resources[0] }}
        }
      if ( !defined %{$resources} || !defined(keys(%{$resources})) ) {
        $resources = apilib::struct_empty($STRUCTURE);
      }
      else {
        apilib::add_resources_uris($resources,$ext,"/sites/$1");
        $resources = apilib::struct_resource_list($resources,$STRUCTURE);
      }
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export($resources,$ext);
    }
    last;
  };

  #
  # Node resources (oarnodes wrapper)
  #  
  $URI = qr{^/sites/([a-z,0-9,-]+)/resources/nodes/([\w\.-]+?)(\.yaml|\.json|\.html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $site  = $1;
    my $ext=apilib::set_ext($q,$3);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $clusters = {};
    $clusters = apilib::get_clusters($dbh);
    if ( not defined( $clusters->{$site} ) ) {
      apilib::ERROR( 404, "Not found", "Site or cluster resource not found" );
    }
    else {
      my $frontend = $clusters->{$site}->{hostname};
      my $cmd    = "$OARDODO_CMD $SSH_CMD $frontend \"oarnodes $2 -D\"";
      my $cmdRes = apilib::send_cmd($cmd,"Oarnodes on $frontend");
      my $resources = apilib::import($cmdRes,"dumper");
      if ( !defined %{$resources} || !defined(keys(%{$resources})) ) {
        $resources = apilib::struct_empty($STRUCTURE);
      }
      else {
        apilib::add_resources_uris($resources,$ext,"/sites/$1");
        $resources = apilib::struct_resource_list($resources,$STRUCTURE);
      }
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export($resources,$ext);
    }
    last;
  };




  #
  # List of current jobs on a site or a cluster (oarstat wrapper)
  #
  $URI = qr{^/sites/([a-z,0-9,-]+)/jobs\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $site  = $1;
    my $ext=apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $clusters = {};
    $clusters = apilib::get_clusters($dbh);
    if ( not defined( $clusters->{$site} ) ) {
      apilib::ERROR( 404, "Not found", "Site or cluster resource not found" );
    }
    else {
      my $frontend = $clusters->{$site}->{hostname};
      my $cmd    = "$OARDODO_CMD $SSH_CMD $frontend \"oarstat -D\"";
      my $cmdRes = apilib::send_cmd($cmd,"Oarstat on $frontend");
      my $jobs = apilib::import($cmdRes,"dumper");
      if ( !defined %{$jobs} || !defined(keys(%{$jobs})) ) {
        $jobs = apilib::struct_empty($STRUCTURE);
      }
      else {
        apilib::add_joblist_griduris($jobs,$ext,$1);
        $jobs = apilib::struct_job_list($jobs,$STRUCTURE);
      }
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export($jobs,$ext);
    }
    last;
  };

  #
  # Details of a job running on a site or a cluster (oarstat wrapper)
  #
  $URI = qr{^/sites/([a-z,0-9,-]+)/jobs/(\d+)\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
 
    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before looking at jobs" );
      last;
    }
    $authenticated_user = $1;

   $_->path_info =~ m/$URI/;
    my $site  = $1;
    my $jobid = $2;
    my $ext = apilib::set_ext($q,$3);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $clusters = {};
    $clusters = apilib::get_clusters($dbh);
    if ( not defined( $clusters->{$site} ) ) {
      apilib::ERROR( 404, "Not found", "Site or cluster resource not found" );
    }
    else {
      my $frontend = $clusters->{$site}->{hostname};
      my $cmd = "$OARDODO_CMD '$SSH_CMD $frontend \"oarstat -fj $jobid -D\"'";
      my $cmdRes = apilib::send_cmd($cmd,"Oarstat on $frontend");
      my $job = apilib::import($cmdRes,"dumper");
      if ( !defined %{$job} || !defined(keys(%{$job})) ) {
        apilib::ERROR( 404, "Not found", "Job not found on $frontend" );
        exit 0;
      }
      my $result = apilib::struct_job($job,$STRUCTURE); 
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export($result,$ext);
    }
    last;
  };

  #
  # Delete of a job running on a site or a cluster (oardel wrapper)
  #
  $URI = qr{^/sites/([a-z,0-9,-]+)/jobs/(\d+)\.*(yaml|json|html)*$};
  apilib::DELETE( $_, $URI ) && do {
 
    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before deleting jobs" );
      last;
    }
    $authenticated_user = $1;

   $_->path_info =~ m/$URI/;
    my $site  = $1;
    my $jobid = $2;
    my $ext = apilib::set_ext($q,$3);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $clusters = {};
    $clusters = apilib::get_clusters($dbh);
    if ( not defined( $clusters->{$site} ) ) {
      apilib::ERROR( 404, "Not found", "Site or cluster resource not found" );
    }
    else {
      my $frontend = $clusters->{$site}->{hostname};
      my $cmd = "$OARDODO_CMD '$SSH_CMD $frontend sudo -u $authenticated_user \"oardel $jobid\"'";
      my $cmdRes = apilib::send_cmd($cmd,"Oardel on $frontend");
      print $q->header( -status => 202, -type => "$type" );
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export( { 'id' => "$jobid",
                      'status' => "Delete request registered",
                      'oardel_output' => "$cmdRes"
                    } , $ext );
    }
    last;
  };


  #
  # List of grid jobs
  #
  $URI = qr{^/grid/jobs\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {

    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before looking at jobs" );
      last;
    }
    $authenticated_user = $1;

    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$1);
    (my $header, my $type)=apilib::set_output_format($ext);
    my %jobs = oargrid_lib::get_user_informations($dbh,$authenticated_user);
    my $jobs;
    if ( !%jobs || !defined(keys(%jobs)) ) {
      $jobs=apilib::struct_empty($STRUCTURE);
    }
    else {
      $jobs = \%jobs;
      apilib::add_gridjobs_uris($jobs,$ext);
      $jobs = apilib::struct_gridjobs_list($jobs,$STRUCTURE);
    }
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($jobs,$ext);
    last;
  };

  #
  # List of resources inside a grid job
  #
  $URI = qr{^/grid/jobs/(\d+)/resources(/nodes)*\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $gridjob=$1;
    my $ext=apilib::set_ext($q,$3);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $cmd    = "OARDO_BECOME_USER=$authenticated_user $OARDODO_CMD oargridstat -l $gridjob -D";
    my $cmdRes = apilib::send_cmd($cmd,"Oargridstat");
    my $resources = apilib::import($cmdRes,"dumper");
    if (defined($2)) { 
      $resources = apilib::struct_gridjob_nodes($resources,$STRUCTURE);
    }
    else {
      $resources = apilib::struct_gridjob_resources($resources,$STRUCTURE);
    }
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($resources,$ext);
    last;
  };
   
  #
  # Details of a grid job
  #
  $URI = qr{^/grid/jobs/(\d+)\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $gridjob=$1;
    my $ext=apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    my %job=oargrid_lib::get_reservation_informations($dbh,$gridjob);
    my $job=\%job;
    $job->{id}=$gridjob;
    apilib::add_gridjob_uris($job,$ext);
    $job = apilib::struct_gridjob($job,$STRUCTURE);
    print $header;
    if ($ext eq "html") {
      print $HTML_HEADER;
      print "\n<TABLE>\n<TR><TD COLSPAN=4><B>Job $gridjob actions:</B>\n";
      print "</TD></TR><TR><TD>\n";
      print "<FORM METHOD=POST method=$apiuri/jobs/$gridjob.html>\n";
      print "<INPUT TYPE=Hidden NAME=method VALUE=delete>\n";
      print "<INPUT TYPE=Submit VALUE=DELETE>\n";
      print "</FORM></TD><TD>\n";
      print "</TR></TABLE>\n";
    }
    print apilib::export($job,$ext);
    last;
  };


  #
  # Keys of a grid job
  #
  $URI = qr{^/grid/jobs/(\d+)/keys(\/private|\/public)*(\.yaml|\.json|\.html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $gridjob=$1;
    my $key_type="";
    if (defined($2)) { $key_type=$2; }
    my $ext=apilib::set_ext($q,$3);
    (my $header, my $type)=apilib::set_output_format($ext);

    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before getting keys" );
      last;
    }
    $authenticated_user = $1;
    $ENV{OARDO_BECOME_USER} = $authenticated_user;

    my $keys={};
    if ($key_type ne "") {
       $key_type =~ s,^/,, ;
       my $file= "/tmp/oargrid/oargrid_ssh_key_".$authenticated_user."_".$gridjob;
       $keys={ $key_type."_key" => apilib::get_key($file,$key_type,$OARDODO_CMD) };
    }
    else {
       my $file= "/tmp/oargrid/oargrid_ssh_key_".$authenticated_user."_".$gridjob;
       $keys={ 
               "public_key" => apilib::get_key($file,"public",$OARDODO_CMD) ,
               "private_key" => apilib::get_key($file,"private",$OARDODO_CMD) 
            };
    }
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($keys,$ext);
    last;
  };

 
  #   
  # A new job on a cluster (oarsub wrapper)
  #
  $URI = qr{^/sites/([a-z,0-9,-]+)/jobs\.*(yaml|json|html)*$};
  apilib::POST( $_, $URI ) && do {

    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
        "A suitable authentication must be done before posting jobs" );
      last;
    }
    $authenticated_user = $1;

    # Check the site resource
    $_->path_info =~ m/$URI/;
    my $site  = $1;
    my $ext = apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $sites = apilib::get_sites($dbh);
    if ( not defined( $sites->{$site} ) ) {
      apilib::ERROR( 404, "Not found", "Site resource not found" );
      last;
    }
    my $frontend = $sites->{$site}->{frontend};

    # Check the submitted job
    my $job = apilib::check_job( $q->param('POSTDATA'), $q->content_type );

    # Make the query (the hash is converted into a list of long options)
    my $oarcmd = "oarsub ";
    my $script = "";
    my $workdir = "~$authenticated_user";
    foreach my $option ( keys( %{$job} ) ) {
      if ($option eq "script_path") {
        $oarcmd .= " $job->{script_path}";
      }
      elsif ($option eq "script") {
        $script = $job->{script};
      }
      elsif ($option eq "workdir") {
        $workdir = $job->{workdir};
      }
      else {
        $oarcmd .= " --$option";
        $oarcmd .= "=\"$job->{$option}\"" if $job->{$option} ne "";
      }
    }
    if ($script ne "") {
      $script =~ s/\"/\\\"/g;
      $oarcmd .= " \"$script\"";
    }

    # Submit the query
    my $cmd = "$OARDODO_CMD $SSH_CMD $frontend 'cd ~$authenticated_user && sudo -u $authenticated_user $oarcmd'";
    my $cmdRes = apilib::send_cmd($cmd,"Oar cmd");
    if ($cmdRes =~ m/.*JOB_ID\s*=\s*(\d+).*/m ) {
      print $q->header( -status => 201, -type => "$type" );
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export( 
            { 
               'state' => "submitted",
               'id' => "$1",
               'uri' => apilib::htmlize_uri(apilib::make_uri("/sites/$site/jobs/$1",$ext,0),$ext)
            } , $ext );
    }
    else {
      apilib::ERROR( 400, "Parse error",
        "Job submitted but the id could not be parsed" );
    }
    last;
  };

  #
  # A new grid job
  #
  $URI = qr{^/grid/jobs\.*(yaml|xml|json|html)*$};
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
      $job = apilib::check_grid_job( $q->param('POSTDATA'), $q->content_type );
    }
    # From html form
    else {
      $job = apilib::check_grid_job( $q->Vars, $q->content_type );
    }
   
    # Make the query (the hash is converted into a list of long options)
    my $oargridcmd = "$OARGRIDSUB_CMD ";
    my $workdir = "~$authenticated_user";
    my $resources;
    foreach my $option ( keys( %{$job} ) ) {
      if ($option eq "resources") {
        $resources = $job->{resources};
        #$resources =~ s/\"/\\\"/g ;
      }
      elsif ($option eq "workdir") {
        $workdir = $job->{workdir};
      }
      else {
        $oargridcmd .= " --$option";
        $oargridcmd .= "=\"$job->{$option}\"" if $job->{$option} ne "";
      }
    }
    if ($resources ne "") { $oargridcmd .= " $resources"; }

    my $cmd = "cd $workdir && $OARDODO_CMD $oargridcmd"; 
    my $cmdRes = `$cmd 2>&1`;
    my $err = $? >> 8;
    if ( "$err" eq "3" ) {
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export( { 'state' => "rejected",
                              'output' => $cmdRes,
                              'command' => $oargridcmd
                            } , $ext );
      last;
    }
    elsif ( $err != 0 ) {
      apilib::ERROR(
        400,
        "Oargrid server error",
        "Oargridsub command exited with status $err: $cmdRes\nCmd:\n$oargridcmd\n"
      );
    }
    elsif ( $cmdRes =~ m/.*Grid reservation id\s*=\s*(\d+).*/m ) {
      # Get the id of the submitted job
      my $id=$1;
      my $ssh_key;
      if ( $cmdRes =~ m/.* SSH KEY : (.*)/m ) {
        $ssh_key=$1;
      }
      else { $ssh_key="ERROR GETTING SSH KEY!"; }
      # Get the list of batch_ids
      my %infos=oargrid_lib::get_reservation_informations($dbh,$id);
      my @cluster_jobs;
      foreach my $cluster (keys(%{$infos{clusterJobs}})) {
        foreach my $job (values(%{$infos{clusterJobs}->{$cluster}})){
          my $uri=apilib::htmlize_uri(apilib::make_uri("/sites/$cluster/jobs/".$job->{batchId},$ext,0),$ext);
          push (@cluster_jobs, { 'cluster' => $cluster,
                                 'id' => $job->{batchId},
                                 'uri' => $uri
                               });
        }
      }
      # Output infos
      print $q->header( -status => 201, -type => "$type" );
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export(
            {
               'state' => "submitted",
               'id' => "$id",
               'ssh_key_path' => $ssh_key,
               'ssh_private_key_uri' => apilib::htmlize_uri(apilib::make_uri("/grid/jobs/$id/keys/private",$ext,0),$ext),
               'ssh_public_key_uri' => apilib::htmlize_uri(apilib::make_uri("/grid/jobs/$id/keys/public",$ext,0),$ext),
               'uri' => apilib::htmlize_uri(apilib::make_uri("/grid/jobs/$id",$ext,0),$ext),
               'resources_uri' => apilib::htmlize_uri(apilib::make_uri("/grid/jobs/$id/resources",$ext,0),$ext),
               'nodes_uri' => apilib::htmlize_uri(apilib::make_uri("/grid/jobs/$id/resources/nodes",$ext,0),$ext),
               'cluster_jobs' => \@cluster_jobs,
               'command' => $oargridcmd
                    } , $ext );
    }
    else {
      apilib::ERROR( 400, "Parse error",
        "Job submitted but the id could not be parsed.\n\nCmd output:\n$cmdRes" );
    }

    last;
  };

  #
  # Delete of a grid job
  #

  $URI = qr{^/grid/jobs/(\d+)(\.yaml|\.json|\.html)*$};
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

    my $cmd    = "OARDO_BECOME_USER=$authenticated_user $OARDODO_CMD oargriddel $jobid";
    my $cmdRes = apilib::send_cmd($cmd,"Oargriddel");
    print $q->header( -status => 202, -type => "$type" );
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export( { 'id' => "$jobid",
                    'status' => "Delete request registered",
                    'oardel_output' => "$cmdRes",
                    'uri' => apilib::htmlize_uri(apilib::make_uri("/grid/jobs/$jobid",$ext,0),$ext)
                  } , $ext );
    last;
  };

  #
  # Delete of a grid job (alternative way, with POST)
  #

  $URI = qr{^/grid/jobs/(\d+)(\.yaml|\.json|\.html)*$};
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

    my $cmd; my $status;
    if ( $job->{method} eq "delete" ) {
      $cmd    = "OARDO_BECOME_USER=$authenticated_user $OARDODO_CMD oargriddel $jobid";
      $status = "Delete request registered";
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
                    'uri' => apilib::htmlize_uri(apilib::make_uri("/grid/jobs/$jobid",$ext,0),$ext)
                  } , $ext );
    last;
  };


  #
  # Html form for job posting
  # 
  $URI = qr{^/grid/jobs/form.html$};
  apilib::GET( $_, $URI ) && do {
    (my $header, my $type)=apilib::set_output_format("html");
    print $header;
    print $HTML_HEADER;
    my $POSTFORM="";
    my $file;
    if (is_conf("GRIDAPI_HTML_POSTFORM")){ $file=get_conf("GRIDAPI_HTML_POSTFORM"); }
    else { $file="/etc/oar/gridapi_html_postform.pl"; }
    open(FILE,$file);
    my(@lines) = <FILE>;
    eval join("\n",@lines);
    close(FILE);
    print $POSTFORM;
    last;
  };

  #
  # Anything else -> 404
  #
  apilib::ERROR( 404, "Not found", "No way to handle your request " . $q->path_info );
}
