#!/usr/bin/perl -w
use strict;
use DBI();
use oar_apilib;
use oar_conflib qw(init_conf dump_conf get_conf is_conf);
use oar_iolib;
use oar_Tools;

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
my $OARSTAT_CMD = "oarstat";
my $OARSUB_CMD  = "oarsub";
my $OARNODES_CMD  = "oarnodes";
my $OARDEL_CMD  = "oardel";
my $OARDODO_CMD = "$ENV{OARDIR}/oardodo/oardodo";

# OAR server
my $remote_host = get_conf("SERVER_HOSTNAME");
my $remote_port = get_conf("SERVER_PORT");

# Enable this if you are ok with a simple pidentd "authentication"
# Not very secure, but useful for testing (no need for login/password)
# or in the case you fully trust the client hosts (with an apropriate
# ip-based access control into apache for example)
my $TRUST_IDENT = 1;
if (is_conf("API_TRUST_IDENT")){ $TRUST_IDENT = get_conf("API_TRUST_IDENT"); }

# Force all html uris to start with "https://".
# Useful if the api acts in a non-https server behind an https proxy
my $FORCE_HTTPS = 0;
if (is_conf("API_FORCE_HTTPS")){ $FORCE_HTTPS = get_conf("API_FORCE_HTTPS"); }

# Default data structure variant
my $STRUCTURE="simple";
if (is_conf("API_DEFAULT_DATA_STRUCTURE")){ $STRUCTURE = get_conf("API_DEFAULT_DATA_STRUCTURE"); }

# Header for html version
my $apiuri= $q->url(-full => 1);
$apiuri=~s/^http:/https:/ if $FORCE_HTTPS;
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
    && defined( $ENV{REMOTE_IDENT} )
    && $ENV{REMOTE_IDENT} ne ""
    && $ENV{REMOTE_IDENT} ne "unknown" )
  {
    $authenticated_user = $ENV{REMOTE_IDENT};
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
  $URI = qr{^$};
  apilib::GET( $_, $URI ) && do {
    print $q->header( -status => 200, -type => "text/html" );
    print $HTML_HEADER;
    print "Welcome on the oar API\n";
    last;
  };

  #
  # List of current jobs (oarstat wrapper)
  #
  $URI = qr{^/jobs\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$1);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $cmd    = "$OARSTAT_CMD -D";
    my $cmdRes = apilib::send_cmd($cmd,"Oarstat");
    my $jobs = apilib::import($cmdRes,"dumper");
    apilib::add_joblist_uris($jobs,$ext,$FORCE_HTTPS);
    my $result = apilib::struct_job_list($jobs,$STRUCTURE);
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($result,$ext);
    last;
  };


  #
  # Details of a job (oarstat wrapper)
  #
  $URI = qr{^/jobs/(\d+)\.*(yaml|json|html)*$};
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
    $ENV{OARDO_BECOME_USER} = $authenticated_user;

    my $cmd    = "$OARDODO_CMD $OARSTAT_CMD -fj $jobid -D";
    my $cmdRes = apilib::send_cmd($cmd,"Oarstat");
    my $job = apilib::import($cmdRes,"dumper");
    my $result = apilib::struct_job($job,$STRUCTURE);
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($result,$ext);
    last;
  };

  #
  # List of resources or details of a resource (oarnodes wrapper)
  #
  $URI = qr{^/resources(/all|/[0-9]+)*\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $cmd;
    if (defined($1)) {
      if    ($1 eq "/all")        { $cmd = "$OARNODES_CMD -D"; }
      elsif ($1 =~ /\/([0-9]+)/)  { $cmd = "$OARNODES_CMD -D -r $1"; }
      else                        { $cmd = "$OARNODES_CMD -D -s"; }
    }
    else                          { $cmd = "$OARNODES_CMD -D -s"; }
    my $cmdRes = apilib::send_cmd($cmd,"Oarnodes");
    my $resources = apilib::import($cmdRes,"dumper");
    if (defined($1) && $1 =~ /\/([0-9]+)/) { 
                       $resources = { @$resources[0]->{properties}->{network_address} 
                           => { @$resources[0]->{resource_id} => @$resources[0] }} 
                       }
    apilib::add_resources_uris($resources,$ext,$FORCE_HTTPS);
    my $result = apilib::struct_resource_list($resources,$STRUCTURE);
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($result,$ext);
    last;
  };
 
  #
  # Details of a node (oarnodes wrapper)
  #
  $URI = qr{^/resources/nodes/([\w\.-]+?)(\.yaml|\.json|\.html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);
    my $cmd    = "$OARNODES_CMD $1 -D";  
    my $cmdRes = apilib::send_cmd($cmd,"Oarnodes");
    my $resources = apilib::import($cmdRes,"dumper");
    apilib::add_resources_uris($resources,$ext,$FORCE_HTTPS);
    my $result = apilib::struct_resource_list($resources,$STRUCTURE);
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($result,$ext);
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

    my $cmd = "cd $workdir && $OARDODO_CMD 'cd $workdir && $oarcmd'";
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
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export( { 'job_id' => "$1",
                      'uri' => apilib::htmlize_uri(apilib::make_uri("/jobs/$1",$ext,0),$ext,$FORCE_HTTPS),
                      'status' => "submitted"
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
  $URI = qr{^/jobs/(\d+)\.*(yaml|json|html)*$};
  apilib::DELETE( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $jobid = $1;
    my $ext=apilib::set_ext($q,$2);
    (my $header, my $type)=apilib::set_output_format($ext);

    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 401, "Permission denied",
       "A suitable authentication must be done before posting jobs" );
      last;
    }
    $authenticated_user = $1;
    $ENV{OARDO_BECOME_USER} = $authenticated_user;

    my $cmd    = "$OARDODO_CMD '$OARDEL_CMD $jobid'";
    my $cmdRes = apilib::send_cmd($cmd,"Oardel");
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export( { 'job_id' => "$jobid",
                    'message' => "Delete request registered",
                    'oardel_output' => "$cmdRes",
                    'uri' => apilib::htmlize_uri(apilib::make_uri("/jobs/$jobid",$ext,0),$ext,$FORCE_HTTPS)
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
                      'uri' => apilib::htmlize_uri(apilib::make_uri("/resources/$id",$ext,0),$ext,$FORCE_HTTPS)
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
        print("\tRemove the job $i->[0], it was run on the resource $Resource\n");
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
      print apilib::export( { 'status' => "deleted" } , $ext );
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
  # Anything else -> 404
  #
  apilib::ERROR( 404, "Not found", "No way to handle your request " . $q->path_info );
}
