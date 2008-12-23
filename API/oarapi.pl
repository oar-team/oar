#!/usr/bin/perl -w
use strict;
use lib qw(.);
use Data::Dumper;
use oar_iolib;
use oargrid_lib;
use DBI();
use oar_conflib qw(init_conf dump_conf get_conf is_conf);
use CGI qw/:standard/;

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

# The effective user. Note that the script must be SUID to this user
my $USER = "oar";

# The ssh command to use to contact the frontends
my $SSH_CMD = "/usr/bin/ssh";

# Debug mode
# This does not increase verbosity, but causes all errors to generate
# the OK/200 status to force the client to output the human readable
# error message.
my $DEBUG_MODE = 1;

# Enable this if you are ok with a simple pidentd "authentication"
# Not very secure, but useful for testing (no need for login/password)
my $TRUST_IDENT = 1;

# Initialize database connection
init_conf($ENV{OARCONFFILE});
my $remote_host = get_conf("SERVER_HOSTNAME");
my $remote_port = get_conf("SERVER_PORT");

# Tainted mode, we must clear the path
$ENV{PATH} = "";

### Only used whithout oardo:
# Set the effective uid (or ssh will not use the suid)
#my $uid = getpwnam("$USER");
#$> = $uid;
#$< = $uid;

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

# Check the consistency of a posted job
sub check_job($) {
  my $data = shift;

  # Exit if we don't know about YAML
  unless ($YAMLenabled) {
    ERROR 400, 'YAML not enabled', 'YAML perl module not loaded!';
    exit 0;
  }

  # We expect the data to be in YAML format
  unless ( $q->content_type eq 'text/yaml' ) {
    ERROR 415, 'Job description must be in YAML',
      "The correct format for a job request is text/yaml" . $q->content_type;
    exit 0;
  }

  # Try to load it and exit if there's an error
  my $job = eval { YAML::Load($data) };
  if ($@) {
    ERROR 400, 'Data not understood', $@;
    exit 0;
  }

  # Job must have a "resource" field
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

#
# Switch on debug mode if the URI starts with /debug
#

SWITCH: for ($q) {
  my $URI;

  #
  # Details of a job
  #
  $URI = qr{^/jobs/(\d+)\.(yaml|xml)$};
  GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $jobid = $1;
    my $ext   = $2;
    my $output_opt;
    if   ( $ext eq "yaml" ) { $output_opt = "-Y" }
    else                    { $output_opt = "-X" }
    my $cmd = "oarstat -fj $jobid $output_opt";
    my $cmdRes = `$cmd 2>&1`;
    my $err=$?;
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
  $URI = qr{^/newjob$};
  POST( $_, $URI ) && do {

    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      ERROR( 403, "Forbidden",
        "A suitable authentication must be done before posting jobs" );
      last;
    }
    $authenticated_user = $1;

    # Check the submited job
    my $job = check_job( $q->param('POSTDATA') );

    # Make the query (the hash is converted into a list of long options)
    my $oarcmd = "oarsub ";
    foreach my $option ( keys( %{$job} ) ) {
      if ( $option ne "script_path" && $option ne "script" ) {
        $oarcmd .= " --$option";
        $oarcmd .= "=\\\"$job->{$option}\\\"" if $job->{$option} ne "";
      }
    }
    $oarcmd .= " $job->{script_path}" if defined( $job->{script_path} );
    my $cmd ="cd ~$authenticated_user && sudo -u $authenticated_user $oarcmd";
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
      print $1;
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
