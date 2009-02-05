#!/usr/bin/perl -w
package apilib;
require Exporter;

use strict;
#use oar_conflib qw(init_conf dump_conf get_conf is_conf);
use CGI qw/:standard/;

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

# CGI handler
my $q = new CGI;

# Activate debug mode when the script name contains "debug" or when a
# debug parameter is found.
my $DEBUG_MODE=0;
if ( $q->url(-relative=>1) =~ /.*debug.*/ ) { $DEBUG_MODE = 1; };
if ( defined( $q->param('debug') ) && $q->param('debug') eq "1" ) {
  $DEBUG_MODE = 1;
}

##############################################################################
# REST Functions
##############################################################################

sub GET($$);
sub POST($$);
sub DELETE($$);
sub PUT($$);
sub ERROR($$$);

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

sub DELETE($$) {
  my ( $q, $path ) = @_;
  if   ( $q->request_method eq 'DELETE' && $q->path_info =~ $path ) { return 1; }
  else                                                              { return 0; }
}

sub PUT($$) {
  my ( $q, $path ) = @_;
  if   ( $q->request_method eq 'PUT' && $q->path_info =~ $path ) { return 1; }
  else                                                           { return 0; }
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
  print $q->p("<PRE>\n". $message ."\n</PRE>");
}

##############################################################################
# Other functions
##############################################################################

# Return the cgi handler
sub get_cgi_handler() {
  return $q;
}

# Return the url (absolute if second argument is 1)
sub make_uri($$) {
  my $path = shift;
  my $absolute = shift;
  if ($absolute == 1) {
    return $q->url(-full => 1). $path;
  }
  else {
    return $path;
  }
}

# Return an html href of an uri if the type is "html"
sub htmlize_uri($$$) {
  my $uri=shift;
  my $type=shift;
  my $force_https=shift;
  if ($type eq "html") {
    my $base_uri=$q->url(-full => 1);
    $base_uri=~s/^http:/https:/ if $force_https;
    return "<A HREF=".$base_uri."$uri>$uri</A>";
  }
  else { return $uri; }
}

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
sub import_yaml($) {
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
sub import_json($) {
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

# Load HTML data into a hashref
sub import_html_form($) {
  my $data         = shift;
  return $data;
}

# Load data into a hashref
sub import($$) {
  (my $data, my $format) = @_;
  if ($format eq "yaml") { import_yaml($data); }
  elsif ($format eq "json") { import_json($data); }
  else {
    ERROR 400, "Unknown $format format", $@;
    exit 0;
  }
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
  return JSON->new->pretty(1)->encode($hashref);
}

# Export a hash into HTML (YAML in fact, as it is human readable)
sub export_html($) {
  my $hashref = shift;
  check_yaml();
  return "<PRE>\n". YAML::Dump($hashref) ."\n</PRE>";
}

# Export data to the specified content_type
sub export($$) {
  my $data         = shift;
  my $content_type = shift;
  if ( $content_type eq 'text/yaml' ) {
    export_yaml($data);
  }elsif ( $content_type eq 'text/json' ) {
    export_json($data);
  }elsif ( $content_type eq 'text/html' ) {
    export_html($data);
  }else {
    ERROR 415, "Unknown $content_type format",
      "The $content_type format is not known.";
    exit 0;
  }
}

# Clean a hash from a key having an empty value
sub clean_hash($$) {
  my $hash = shift;
  my $key = shift;
  if ( defined($hash->{"$key"}) && $hash->{"$key"} eq "" ) {
    delete($hash->{"$key"})
  }
}

# Check the consistency of a posted job and load it into a hashref
sub check_job($$) {
  my $data         = shift;
  my $content_type = shift;
  my $job;

  # If the data comes in the YAML format
  if ( $content_type eq 'text/yaml' ) {
    $job=import_yaml($data);
  }

  # If the data comes in the JSON format
  elsif ( $content_type eq 'text/json' ) {
    $job=import_json($data);
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

# Check the consistency of a posted grid job and load it into a hashref
sub check_grid_job($$) {
  my $data         = shift;
  my $content_type = shift;
  my $job;

  # If the data comes in the YAML format
  if ( $content_type eq 'text/yaml' ) {
    $job=import_yaml($data);
  }

  # If the data comes in the JSON format
  elsif ( $content_type eq 'text/json' ) {
    $job=import_json($data);
  }

  # If the data comes from an html form
  elsif ( $content_type eq 'application/x-www-form-urlencoded' ) {
    $job=import_html_form($data);
  }

  # We expect the data to be in YAML or JSON format
  else {
    ERROR 415, 'Job description must be in YAML or JSON',
      "The correct format for a job request is text/yaml or text/json. "
      . $content_type;
    exit 0;
  }

  # Job must have a "resources" or "file" field
  unless ( $job->{resources} or $job->{file} ) {
    ERROR 400, 'Missing Required Field',
      'A grid job must have a resources or file field!';
    exit 0;
  }

  # Clean options with an empty parameter that is normaly required
  clean_hash($job,"walltime");
  clean_hash($job,"program");
  clean_hash($job,"program");

  # Empty options that have no parameter
  if (defined($job->{"FORCE"}) && $job->{"FORCE"} eq "0" ) {
    delete($job->{"FORCE"});
  }
  else { $job->{"FORCE"}="" ; }

  return $job;
}

# Set oar output option and header depending on the format given
sub set_output_format($) {
  my $format=shift;
  my $output_opt;
  my $header;
  my $type;
  if( $format eq "yaml" ) { 
    $output_opt = "-Y";
    $type="text/yaml";
  }
  elsif ( $format eq "xml" ) { 
    $output_opt = "-X";
    $type="text/xml";
  }
  elsif ( $format eq "html" ) { 
    $output_opt = "";
    $type="text/html";
  }
  else { 
    $output_opt = "-J";
    $type="text/json";
  }
  $header=$q->header( -status => 200, -type => "$type" );
  return ($output_opt,$header,$type);
}

# Get a suitable extension depending on the content-type
sub get_ext($) {
  my $content_type = shift;
  if    ($content_type eq "text/yaml")  { return "yaml"; }
  elsif ($content_type eq "text/xml")   { return "xml"; }
  elsif ($content_type eq "text/html")  { return "html"; }
  elsif ($content_type eq "text/json")  { return "json"; }
  else                                  { return "UNKNOWN_TYPE"; }
}

# Return the extension (second parameter) if defined, or the
# corresponding one if the content_type if set. "json" is the default.
sub set_ext($$) {
  my $q=shift;
  my $ext=shift;
  if (defined($ext) && $ext ne "") { return $ext; }
  else {
    if (defined($q->content_type) 
          && get_ext($q->content_type) ne "UNKNOWN_TYPE") { 
      return get_ext($q->content_type); 
    }
    else { return "json"; }
  }
}

# Send a command and returns the output or exit with an error
sub send_cmd($$) {
  my $cmd=shift;
  my $error_name=shift;
  my $cmdRes = `$cmd 2>&1`;
  my $err    = $?;
  if ( $err != 0 ) {
    #$err = $err >> 8;
    ERROR(
      400,
      "$error_name error",
      "$error_name command exited with status $err: $cmdRes"
    );
    exit 0;
  }
  else { return $cmdRes; }
}

return 1;

