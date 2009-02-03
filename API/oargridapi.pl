#!/usr/bin/perl -w
use strict;
use oargrid_lib;
use oargrid_conflib;
use oar_apilib;

##############################################################################
# CUSTOM VARIABLES
##############################################################################

# The ssh command to use to contact the frontends
my $SSH_CMD = "/usr/bin/ssh";

# Debug mode
# This does not increase verbosity, but causes all errors to generate
# the OK/200 status to force the client to output the human readable
# error message.
# Uncomment to bypass the setting of this variable by the apilib
# (set to 1 if the name of the cgi script contains "debug")
# $DEBUG_MODE = 0;

# Enable this if you are ok with a simple pidentd "authentication"
# Not very secure, but useful for testing (no need for login/password)
# or in the case you fully trust the client hosts (with an apropriate
# ip-based access control into apache for example)
my $TRUST_IDENT = 1;

# Oar commands
my $OARDODO_CMD = "$ENV{OARDIR}/oardodo/oardodo";


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

# CGI handler
my $q = apilib::get_cgi_handler();

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

#
# Switch on debug mode if the URI starts with /debug
#

SWITCH: for ($q) {
  my $URI;

  #
  # The sites list
  #
  $URI = qr{^/sites\.(yaml|xml|json)$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = $1;
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);
    my %sites = get_sites($dbh);
    my $compact_sites;
    foreach my $s ( keys( %{ $sites{sites} } ) ) {
      $compact_sites->{$s}->{uri} = apilib::make_uri("/sites/$s.$ext",0);
    }
    print $header;
    print apilib::export($compact_sites,$type);
    last;
  };

  #
  # Site details
  #
  $URI = qr{^/sites/([a-z,0-9,-]+)\.(yaml|xml|json)$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext = $2;
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);
    my %sites = get_sites($dbh);
    if ( defined( $sites{sites}{$1} ) ) {
      my %s;
      $s{$1} = $sites{sites}{$1};
      print $header;
      print apilib::export(\%s,$type);
    }
    else {
      apilib::ERROR( 404, "Not found", "Resource not found" );
    }
    last;
  };

  #
  # Details of a job running on a site (oarstat wrapper)
  #
  $URI = qr{^/sites/([a-z,0-9,-]+)/jobs/(\d+)\.(yaml|json)$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $site  = $1;
    my $jobid = $2;
    my $ext   = $3;
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
      print $cmdRes;
    }
    last;
  };

  #
  # A new job on a cluster (oarsub wrapper)
  #
  $URI = qr{^/sites/([a-z,0-9,-]+)/jobs$};
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
    my %sites = get_sites($dbh);
    if ( not defined( $sites{sites}{$site} ) ) {
      apilib::ERROR( 404, "Not found", "Site resource not found" );
      last;
    }
    my $frontend = $sites{sites}{$site}{frontend};

    # Check the submited job
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

    my $cmd = "$OARDODO_CMD $SSH_CMD $frontend 'cd ~$authenticated_user && sudo -u $authenticated_user $oarcmd'";
    my $cmdRes = `$cmd 2>&1`;
    if ( $? != 0 ) {
      my $err = $? >> 8;
      apilib::ERROR(
        400,
        "Oar server error",
        "Oarsub command exited with status $err: $cmdRes\nCmd:\n$oarcmd"
      );
    }
    elsif ( $cmdRes =~ m/.*JOB_ID\s*=\s*(\d+).*/m ) {
      print $q->header( -status => 201, -type => $q->content_type );
      print apilib::export( { 'job_id' => "$1",
                      'uri' => apilib::make_uri("/sites/$site/jobs/$1.". apilib::get_ext($q->content_type),0)
                    } , $q->content_type );
    }
    else {
      apilib::ERROR( 400, "Parse error",
        "Job submited but the id could not be parsed" );
    }
    last;
  };

  #
  # A new grid job
  #
  $URI = qr{^/grid/job$};
  apilib::POST( $_, $URI ) && do {
    ############### TODO ############### 
    print $q->header;
    print "New gridjob status goes here...\n";
    last;
  };

  #
  # Anything else -> 404
  #
  apilib::ERROR( 404, "Not found", "No way to handle your request " . $q->path_info );
}
