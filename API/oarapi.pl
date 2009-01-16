#!/usr/bin/perl -w
use strict;
use lib qw(.);
use Data::Dumper;
use oar_iolib;
use oargrid_lib;
use DBI();
use oar_conflib qw(init_conf dump_conf get_conf is_conf);
use CGI qw/:standard/;

##############################################################################
# CUSTOM VARIABLES
##############################################################################

# Oar commands
my $OARSTAT_CMD = "oarstat";
my $OARSUB_CMD  = "oarsub";
my $OARDODO_CMD = "/usr/lib/oar/oardodo/oardodo";

# Debug mode
# This does not increase verbosity, but causes all errors to generate
# the OK/200 status to force the client to output the human readable
# error message.
my $DEBUG_MODE = 1;

# Enable this if you are ok with a simple pidentd "authentication"
# Not very secure, but useful for testing (no need for login/password)
my $TRUST_IDENT = 1;

##############################################################################
# INIT
##############################################################################

# Try to load XML module
my $XMLenabled = 1;
unless ( eval "use XML::Simple qw(XMLout);1" ) {
  $XMLenabled = 0;
}

# Try to load YAML module
my $YAMLenabled = 1;
unless ( eval "use YAML;1" ) {
  $YAMLenabled = 0;
}

# Try to load JSON module
my $JSONenabled = 1;
unless ( eval "use JSON;1" ) {
  $JSONenabled = 0;
}

# Initialize database connection
init_conf( $ENV{OARCONFFILE} );
my $remote_host = get_conf("SERVER_HOSTNAME");
my $remote_port = get_conf("SERVER_PORT");

# CGI handler
my $q = new CGI;

if ( defined( $q->param('debug') ) && $q->param('debug') eq "1" ) {
  $DEBUG_MODE = 1;
}

##############################################################################
# REST Functions
##############################################################################

sub GET($$) {
  ( my $q, my $path ) = @_;
  if   ( $q->request_method eq 'GET' && $q->path_info =~ /$path/ ) { return 1; }
  else                                                             { return 0; }
}

sub POST($$) {
  my ( $q, $path ) = @_;
  if   ( $q->request_method eq 'POST' && $q->path_info =~ $path ) { return 1; }
  else                                                            { return 0; }
}

sub ERROR($$$) {
  ( my $status, my $title, my $message ) = @_;
  if ($DEBUG_MODE) {
    $title  = "ERROR $status\n" . $title;
    $status = "200";
  }
  print $q->header( -status => $status, -type => 'text/html' );
  print $q->title( "ERROR: " . $title );
  print $q->h1($title);
  print $q->p($message);
}

##############################################################################
# Other functions
##############################################################################

# Check if YAML is enabled or exits with an error
sub check_yaml() {
  unless ($YAMLenabled) {
    ERROR 400, 'YAML not enabled', 'YAML perl module not loaded!';
    exit 0;
  }
}

# Check if JSON is enabled or exits with an error
sub check_json() {
  unless ($JSONenabled) {
    ERROR 400, 'JSON not enabled', 'JSON perl module not loaded!';
    exit 0;
  }
}

# Load YAML data into a hashref
sub load_yaml($) {
  my $data         = shift;
  check_yaml();
  # Try to load the data and exit if there's an error
  my $hashref = eval { YAML::Load($data) };
  if ($@) {
    ERROR 400, 'YAML data not understood', $@;
    exit 0;
  }
  return $hashref;
}

# Load JSON data into a hashref
sub load_json($) {
  my $data         = shift;
  check_json();
  # Try to load the data and exit if there's an error
  my $hashref = eval { JSON::decode_json($data) };
  if ($@) {
    ERROR 400, 'JSON data not understood', $@;
    exit 0;
  }
  return $hashref;
}

# Export a hash into YAML
sub export_yaml($) {
  my $hashref = shift;
  check_yaml();
  return YAML::Dump($hashref)
} 
  
# Export a hash into JSON
sub export_json($) {
  my $hashref = shift;
  check_json();
  return JSON::encode_json($hashref)
} 

# Export data to the specified content_type
sub export($$) {
  my $data         = shift;
  my $content_type = shift;
  if ( $content_type eq 'text/yaml' ) {
    export_yaml($data);
  }elsif ( $content_type eq 'text/json' ) {
    export_json($data);
  }else {
    ERROR 415, "Unknown $content_type format",
      "The $content_type format is not known.";
    exit 0;
  }
}

# Check the consistency of a posted job and load it into a hashref
sub check_job($$) {
  my $data         = shift;
  my $content_type = shift;
  my $job;

  # If the data comes in the YAML format
  if ( $content_type eq 'text/yaml' ) {
    $job=load_yaml($data);
  }

  # If the data comes in the JSON format
  elsif ( $content_type eq 'text/json' ) {
    $job=load_json($data);
  }

  # We expect the data to be in YAML or JSON format
  else {
    ERROR 415, 'Job description must be in YAML or JSON',
      "The correct format for a job request is text/yaml or text/json. "
      . $content_type;
    exit 0;
  }

  # Job must have a "script" or script_path field
  unless ( $job->{script} or $job->{script_path} ) {
    ERROR 400, 'Missing Required Field',
      'A job must have a script or a script_path!';
    exit 0;
  }

  return $job;
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
  # Details of a job (oarstat wrapper)
  #
  $URI = qr{^/jobs/(\d+)\.(yaml|xml)$};
  GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $jobid = $1;
    my $ext   = $2;
    my $output_opt;
    if   ( $ext eq "yaml" ) { $output_opt = "-Y" }
    else                    { $output_opt = "-X" }
    my $cmd    = "$OARSTAT_CMD -fj $jobid $output_opt";
    my $cmdRes = `$cmd 2>&1`;
    my $err    = $?;

    if ( $err != 0 ) {

      #$err = $err >> 8;
      ERROR(
        400,
        "Oarstat error",
        "Oarstat command exited with status $err: $cmdRes"
      );
    }
    else {
      if ( $ext eq "yaml" ) {
        print $q->header( -status => 200, -type => 'text/yaml' );
      }
      else {
        print $q->header( -status => 200, -type => 'text/xml' );
      }
      print $cmdRes;
    }

    last;
  };

  #
  # A new job (oarsub wrapper)
  #
  $URI = qr{^/jobs$};
  POST( $_, $URI ) && do {

    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      ERROR( 403, "Forbidden",
        "A suitable authentication must be done before posting jobs" );
      last;
    }
    $authenticated_user = $1;

    # Check the submited job
    my $job = check_job( $q->param('POSTDATA'), $q->content_type );

    # Make the query (the hash is converted into a list of long options)
    my $oarcmd = "$OARSUB_CMD ";
    foreach my $option ( keys( %{$job} ) ) {
      if ( $option ne "script_path" && $option ne "script" ) {
        $oarcmd .= " --$option";
        $oarcmd .= "=\"$job->{$option}\"" if $job->{$option} ne "";
      }
    }
    $oarcmd .= " $job->{script_path}" if defined( $job->{script_path} );
    my $cmd =
"cd ~$authenticated_user && $OARDODO_CMD su - $authenticated_user -c '$oarcmd'";
    my $cmdRes = `$cmd 2>&1`;
    if ( $? != 0 ) {
      my $err = $? >> 8;
      ERROR(
        400,
        "Oar server error",
        "Oarsub command exited with status $err: $cmdRes"
      );
    }
    elsif ( $cmdRes =~ m/.*JOB_ID\s*=\s*(\d+).*/m ) {
      print $q->header( -status => 202, -type => 'text/ascii' );
      print export( {'job_id' => "$1"} , $q->content_type );
    }
    else {
      ERROR( 400, "Parse error",
        "Job submited but the id could not be parsed" );
    }
    last;
  };

  #
  # Anything else -> 404
  #
  ERROR( 404, "Not found", "No way to handle your request " . $q->path_info );
}
