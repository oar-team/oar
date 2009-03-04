#!/usr/bin/perl -w
use strict;
use oargrid_lib;
use oargrid_conflib;
use oar_apilib;
use oar_conflib qw(init_conf dump_conf get_conf is_conf);

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

# Force all html uris to start with "https://".
# Useful if the api acts in a non-https server behind an https proxy
my $FORCE_HTTPS = 0;
if (is_conf("API_FORCE_HTTPS")){ $FORCE_HTTPS = get_conf("API_FORCE_HTTPS"); }

# Default data structure variant
my $STRUCTURE="simple";
if (is_conf("API_DEFAULT_DATA_STRUCTURE")){ $STRUCTURE = get_conf("API_DEFAULT_DATA_STRUCTURE"); }

# Oar commands
my $OARDODO_CMD = "$ENV{OARDIR}/oardodo/oardodo";
my $OARGRIDSUB_CMD = "oargridsub";

# CGI handler
my $q = apilib::get_cgi_handler();

# Header for html version
my $apiuri= $q->url(-full => 1);
$apiuri=~s/^http:/https:/ if $FORCE_HTTPS;
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
# Functions
##############################################################################

# Get infos of clusters, by site hierarchy
sub get_sites($) {
  my $dbh      = shift;
  my %clusters = oargrid_lib::get_cluster_names($dbh);
  my %sites;
  foreach my $i ( keys(%clusters) ) {
    if ( defined( $clusters{$i}{parent} ) ) {
      push @{ $sites{sites}{ $clusters{$i}{parent} }{clusters} }, $i;
      $sites{sites}{ $clusters{$i}{parent} }{frontend} =
        $clusters{$i}{hostname};
    }
  }
  return %sites;
}

# Get all the infos about the clusters (oargridlib)
sub get_clusters($) {
  my $dbh = shift;
  return oargrid_lib::get_cluster_names($dbh);
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
    && defined( $ENV{REMOTE_IDENT} )
    && $ENV{REMOTE_IDENT} ne ""
    && $ENV{REMOTE_IDENT} ne "unknown" )
  {
    $authenticated_user = $ENV{REMOTE_IDENT};
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
  $URI = qr{^$};
  apilib::GET( $_, $URI ) && do {
    print $q->header( -status => 200, -type => "text/html" );
    print $HTML_HEADER;
    print "Welcome on the oargrid API\n";
    last;
  };

  #
  # The sites list
  #
  $URI = qr{^/sites\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$1);
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);
    my %sites = get_sites($dbh);
    my $compact_sites;
    foreach my $s ( keys( %{ $sites{sites} } ) ) {
      $compact_sites->{$s}->{uri} = apilib::htmlize_uri(
                              apilib::make_uri("/sites/$s",$ext,0),
                              $ext,$FORCE_HTTPS);
    }
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($compact_sites,$type);
    last;
  };

  #
  # Site details
  #
  $URI = qr{^/sites/([a-z,0-9,-]+)\.*(yaml|xml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = apilib::set_ext($q,$2);
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);
    my %sites = get_sites($dbh);
    if ( defined( $sites{sites}{$1} ) ) {
      my %s;
      $s{$1} = $sites{sites}{$1};
      $s{$1}{jobs} = apilib::htmlize_uri(
                              apilib::make_uri("/sites/$1/jobs",$ext,0),
                              $ext,$FORCE_HTTPS);
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export(\%s,$type);
    }
    else {
      apilib::ERROR( 404, "Not found", "Resource not found" );
    }
    last;
  };

  #
  # List of current jobs on a site (oarstat wrapper)
  #
  $URI = qr{^/sites/([a-z,0-9,-]+)/jobs\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $site  = $1;
    my $ext=apilib::set_ext($q,$2);
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);
    my %sites = get_sites($dbh);
    if ( not defined( $sites{sites}{$site} ) ) {
      apilib::ERROR( 404, "Not found", "Site resource not found" );
    }
    else {
      my $frontend = $sites{sites}{$site}{frontend};
      my $cmd    = "$OARDODO_CMD $SSH_CMD $frontend \"oarstat -Y\"";

`echo '$cmd' > /tmp/cmd`;
      my $cmdRes = apilib::send_cmd($cmd,"Oarstat");
      my $jobs = apilib::import($cmdRes,"yaml");
      my $result;
      foreach my $job ( keys( %{$jobs} ) ) {
        $result->{$job}->{state}=$jobs->{$job}->{state};
        $result->{$job}->{owner}=$jobs->{$job}->{owner};
        $result->{$job}->{name}=$jobs->{$job}->{name};
        $result->{$job}->{queue}=$jobs->{$job}->{queue};
        $result->{$job}->{submission}=$jobs->{$job}->{submissionTime};
        $result->{$job}->{uri}=apilib::make_uri("/sites/$site/jobs/$job",$ext,0);
        $result->{$job}->{uri}=apilib::htmlize_uri($result->{$job}->{uri},$ext,$FORCE_HTTPS);
      }
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export($result,$type);
    }
    last;
  };

  #
  # Details of a job running on a site (oarstat wrapper)
  #
  $URI = qr{^/sites/([a-z,0-9,-]+)/jobs/(\d+)\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $site  = $1;
    my $jobid = $2;
    my $ext = apilib::set_ext($q,$3);
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);
    my %sites = get_sites($dbh);
    if ( not defined( $sites{sites}{$site} ) ) {
      apilib::ERROR( 404, "Not found", "Site resource not found" );
    }
    else {
      my $frontend = $sites{sites}{$site}{frontend};
      my $cmd = "$OARDODO_CMD '$SSH_CMD $frontend \"oarstat -fj $jobid $output_opt\"'";
      my $cmdRes = apilib::send_cmd($cmd,"Oarstat on $frontend");
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      if ($ext eq "html") { print "<PRE>\n"; }
      print $cmdRes;
      if ($ext eq "html") { print "</PRE>\n"; }
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
      apilib::ERROR( 403, "Forbidden",
        "A suitable authentication must be done before posting jobs" );
      last;
    }
    $authenticated_user = $1;

    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$1);
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);
    my $cmd    = "OARDO_BECOME_USER=$authenticated_user $OARDODO_CMD oargridstat -Y";
    my $cmdRes = apilib::send_cmd($cmd,"Oargridstat");
    my $jobs = apilib::import($cmdRes,"yaml");
    my $result;
    foreach my $job ( keys( %{$jobs} ) ) {
      $result->{$job}->{uri}=apilib::make_uri("/grid/jobs/$job",$ext,0);
      $result->{$job}->{uri}=apilib::htmlize_uri($result->{$job}->{uri},$ext,$FORCE_HTTPS);
      $result->{$job}->{resources}=apilib::make_uri("/grid/jobs/$job/resources",$ext,0);
      $result->{$job}->{resources}=apilib::htmlize_uri($result->{$job}->{resources},$ext,$FORCE_HTTPS);
    }
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($result,$type);
    last;
  };

  #
  # List of resources inside a grid job
  #
  $URI = qr{^/grid/jobs/(\d+)/resources\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $gridjob=$1;
    my $ext=apilib::set_ext($q,$2);
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);
    my $cmd    = "OARDO_BECOME_USER=$authenticated_user $OARDODO_CMD oargridstat -l $gridjob -Y";
    my $cmdRes = apilib::send_cmd($cmd,"Oargridstat");
    my $resources = apilib::import($cmdRes,"yaml");
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($resources,$type);
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
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);
    my $cmd    = "OARDO_BECOME_USER=$authenticated_user $OARDODO_CMD oargridstat $gridjob -Y";
    my $cmdRes = apilib::send_cmd($cmd,"Oargridstat");
    my $job = apilib::import($cmdRes,"yaml");
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($job,$type);
    last;
  };
 
  #   
  # A new job on a cluster (oarsub wrapper)
  #
  $URI = qr{^/sites/([a-z,0-9,-]+)/jobs\.*(yaml|json|html)*$};
  apilib::POST( $_, $URI ) && do {

    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 403, "Forbidden",
        "A suitable authentication must be done before posting jobs" );
      last;
    }
    $authenticated_user = $1;

    # Check the site resource
    $_->path_info =~ m/$URI/;
    my $site  = $1;
    my $ext = apilib::set_ext($q,$2);
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);
    my %sites = get_sites($dbh);
    if ( not defined( $sites{sites}{$site} ) ) {
      apilib::ERROR( 404, "Not found", "Site resource not found" );
      last;
    }
    my $frontend = $sites{sites}{$site}{frontend};

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
    my $cmdRes = apilib::send_cmd($cmd,"Oardel");
    if ($cmdRes =~ m/.*JOB_ID\s*=\s*(\d+).*/m ) {
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export( 
            { 
               'state' => "submitted",
               'job_id' => "$1",
               'uri' => apilib::htmlize_uri(apilib::make_uri("/sites/$site/jobs/$1",$ext,0),$ext,$FORCE_HTTPS)
            } , $type );
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
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);
    
    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 403, "Forbidden",
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

    my $cmd = "cd $workdir && $OARDODO_CMD 'cd $workdir && $oargridcmd'"; 
    my $cmdRes = `$cmd 2>&1`;
    my $err = $? >> 8;
    if ( "$err" eq "3" ) {
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export( { 'state' => "rejected",
                              'output' => $cmdRes,
                              'command' => $oargridcmd
                            } , $type );
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
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export(
            {
               'state' => "submitted",
               'job_id' => "$1",
               'key' => "<not yet implemented>",
               'uri' => apilib::htmlize_uri(apilib::make_uri("/grid/jobs/$1.",$ext,0),$ext,$FORCE_HTTPS),
               'resources' => apilib::htmlize_uri(apilib::make_uri("/grid/jobs/$1/resources.",$ext,0),$ext,$FORCE_HTTPS),
               'command' => $oargridcmd
                    } , $type );
    }
    else {
      apilib::ERROR( 400, "Parse error",
        "Job submitted but the id could not be parsed.\n\nCmd output:\n$cmdRes" );
    }

    last;
  };


  #
  # Html form for job posting
  # 
  $URI = qr{^/grid/jobs/form.html$};
  apilib::GET( $_, $URI ) && do {
    (my $output_opt, my $header, my $type)=apilib::set_output_format("html");
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
