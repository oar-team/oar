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

# Check a possible extension
sub set_ext($$); # defined later
my $extension;
if ( $q->path_info =~ /.*\.(yaml|json|html)$/ ) { $extension = $1; };
$extension=set_ext($q,$extension);

# Declared later with REST functions
sub ERROR($$$);

##############################################################################
# Data conversion functions
##############################################################################

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

# Load Dumper data into a hashref
sub import_dumper($) {
  my $data         = shift;
  my $hash = eval($data);
  if ($@) {
    ERROR 400, 'Dumper data not understood', $@;
    exit 0;
  }
  return $hash;
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
  elsif ($format eq "dumper") { import_dumper($data); }
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
  }elsif ( $content_type eq 'application/json' ) {
    export_json($data);
  }elsif ( $content_type eq 'text/html' ) {
    export_html($data);
  }else {
    ERROR 406, "Unknown $content_type format",
      "The $content_type format is not known.";
    exit 0;
  }
}

# Shape a oar job into the given structure
sub struct_job($$) {
  my $job = shift;
  my $structure = shift;
  my $result;
  if    ($structure eq 'oar')    { return $job; }
  elsif ($structure eq 'simple') { return $job->{(keys(%{$job}))[0]}; }
}

# Shape a oar jobs hash into the given structure
sub struct_job_list($$) {
  my $jobs = shift;
  my $structure = shift;
  my $result;
  foreach my $job ( keys( %{$jobs} ) ) {
    my $hashref = {
                  state => $jobs->{$job}->{state},
                  owner => $jobs->{$job}->{owner},
                  name => $jobs->{$job}->{name},
                  queue => $jobs->{$job}->{queue},
                  submission => $jobs->{$job}->{submissionTime},
                  uri => $jobs->{$job}->{uri}
    };
    if ($structure eq 'oar') {
      $result->{$job} = $hashref;
    }
    elsif ($structure eq 'simple') {
      $hashref->{id}=$job;
      push (@$result,$hashref);
    } 
  }
  return $result;
}

# Add uris to a oar job list
sub add_joblist_uris($$$) {
  my $jobs = shift;
  my $ext = shift;
  my $FORCE_HTTPS = shift;
    foreach my $job ( keys( %{$jobs} ) ) {
      $jobs->{$job}->{uri}=apilib::make_uri("/jobs/$job",$ext,0);
      $jobs->{$job}->{uri}=apilib::htmlize_uri($jobs->{$job}->{uri},$ext,$FORCE_HTTPS);
  }
}

# Shape a resources hash into the given structure
sub struct_resource_list($$) {
  my $resources = shift;
  my $structure = shift;
  my $result;
  if ($structure eq 'oar') {
    return $resources ;
  }
  elsif ($structure eq 'simple') {
    foreach my $node ( keys( %{$resources} ) ) {
      foreach my $id ( keys( %{$resources->{$node}} ) ) {
        if ($id ne "uri") {
          $resources->{$node}->{$id}->{id}=$id;
          $resources->{$node}->{$id}->{node}=$node;
          $resources->{$node}->{$id}->{node_uri}=$resources->{$node}->{uri};
          push(@$result,$resources->{$node}->{$id});
        }
      }
    }
    return $result; 
  }
}

# Add uris to a resources list
sub add_resources_uris($$$) {
  my $resources = shift;
  my $ext = shift;
  my $FORCE_HTTPS = shift;
  foreach my $node ( keys( %{$resources} ) ) {
    foreach my $id ( keys( %{$resources->{$node}} ) ) {
      # This test should make this function work for "oarstat -s"
      if (ref($resources->{$node}->{$id}) ne "HASH") {
        my $state = $resources->{$node}->{$id};
        $resources->{$node}->{$id}={};
        $resources->{$node}->{$id}->{state}=$state;
      }
      $resources->{$node}->{$id}->{uri}=apilib::make_uri("/resources/$id",$ext,0);
      $resources->{$node}->{$id}->{uri}=apilib::htmlize_uri($resources->{$node}->{$id}->{uri},$ext,$FORCE_HTTPS);
    }
    $resources->{$node}->{uri}=apilib::make_uri("/resources/nodes/$node",$ext,0);
    $resources->{$node}->{uri}=apilib::htmlize_uri($resources->{$node}->{uri},$ext,$FORCE_HTTPS);
  }
}

##############################################################################
# Content type functions
##############################################################################

# Get a suitable extension depending on the content-type
sub get_ext($) {
  my $content_type = shift;
  if    ($content_type eq "text/yaml")  { return "yaml"; }
  elsif ($content_type eq "text/html")  { return "html"; }
  elsif ($content_type eq "application/json")  { return "json"; }
  else                                  { return "UNKNOWN_TYPE"; }
}

# Get a suitable content-type depending on the extension
sub get_content_type($) {
  my $format = shift;
  if    ( $format eq "yaml" ) { return "text/yaml"; } 
  elsif ( $format eq "html" ) { return "text/html"; } 
  elsif ( $format eq "json" ) { return "application/json"; } 
  else                        { return "UNKNOWN_TYPE"; }
}

# Set oar output option and header depending on the format given
sub set_output_format($) {
  my $format=shift;
  my $output_opt;
  my $header;
  my $type = get_content_type($format);
  if ( $format eq "yaml" ) { 
    $output_opt = "-Y";
  }
  elsif ( $format eq "html" ) { 
    $output_opt = "";
  }
  else { 
    $output_opt = "-J";
  }
  $header=$q->header( -status => 200, -type => "$type" );
  return ($output_opt,$header,$type);
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
    $title  = "ERROR $status - " . $title;
    $status = "200";
  }
  print $q->header( -status => $status, -type => get_content_type($extension) );
  if ($extension eq "html") {
    print $q->title($title) ."\n";
    print $q->h1($title) ."\n";
    print $q->p("<PRE>\n". $message ."\n</PRE>");
  }
  else {
    my $error = { code => $status,
                  message => $message,
                  title => $title
                };
    print export($error,get_content_type($extension));
  }
}

##############################################################################
# Other functions
##############################################################################

# Return the cgi handler
sub get_cgi_handler() {
  return $q;
}

# Return the url (absolute if the third argument is 1). The .html
# extension is added if the second argument is equal to "html".
sub make_uri($$$) {
  my $path = shift;
  my $ext = shift;
  my $absolute = shift;
  if ($ext eq "html") { $path.=".html"; }
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

# Clean a hash from a key having an empty value (for options with parameter)
sub parameter_option($$) {
  my $hash = shift;
  my $key = shift;
  if ( defined($hash->{"$key"}) && $hash->{"$key"} eq "" ) {
    delete($hash->{"$key"})
  }
}

# Remove a toggle option if value is 0
sub toggle_option($$) {
  my $job = shift;
  my $option = shift;
  if (defined($job->{$option})) {
    if ($job->{$option} eq "0" ) {
      delete($job->{$option});
    }
    else { $job->{$option}="" ; };
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
  elsif ( $content_type eq 'application/json' ) {
    $job=import_json($data);
  }

  # If the data comes from an html form
  elsif ( $content_type eq 'application/x-www-form-urlencoded' ) {
    $job=import_html_form($data);
  }

  # We expect the data to be in YAML or JSON format
  else {
    ERROR 406, 'Job description must be in YAML or JSON',
      "The correct format for a job request is text/yaml or application/json. "
      . $content_type;
    exit 0;
  }

  # Job must have a "script" or script_path field
  unless ( $job->{script} or $job->{script_path} ) {
    ERROR 400, 'Missing Required Field',
      'A job must have a script or a script_path!';
    exit 0;
  }

  # Clean options with an empty parameter that is normaly required
  foreach my $option ("resources",   "name",
                      "property",    "script",
                      "script_path", "type",
                      "reservation", "directory"
                     ) { parameter_option($job,$option) }
    

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
  elsif ( $content_type eq 'application/json' ) {
    $job=import_json($data);
  }

  # If the data comes from an html form
  elsif ( $content_type eq 'application/x-www-form-urlencoded' ) {
    $job=import_html_form($data);
  }

  # We expect the data to be in YAML or JSON format
  else {
    ERROR 406, 'Job description must be in YAML or JSON',
      "The correct format for a job request is text/yaml or application/json. "
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
  parameter_option($job,"walltime");
  parameter_option($job,"program");
  parameter_option($job,"program");
  parameter_option($job,"type");
  parameter_option($job,"start_date");
  parameter_option($job,"directory");

  # Manage toggle options (no parameter)
  toggle_option($job,"FORCE");
  toggle_option($job,"verbose");

  return $job;
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

