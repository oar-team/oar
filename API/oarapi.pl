#!/usr/bin/perl -w
use strict;
use oar_apilib;

##############################################################################
# CUSTOM VARIABLES
##############################################################################

# Oar commands
my $OARSTAT_CMD = "oarstat";
my $OARSUB_CMD  = "oarsub";
my $OARNODES_CMD  = "oarnodes";
my $OARDEL_CMD  = "oardel";
my $OARDODO_CMD = "$ENV{OARDIR}/oardodo/oardodo";

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

# Force all html uris to start with "https://".
# Useful if the api acts in a non-https server behind an https proxy
my $FORCE_HTTPS = 0;

# CGI handler
my $q=apilib::get_cgi_handler();

# Header for html version
my $apiuri= $q->url(-full => 1);
$apiuri=~s/^http:/https:/ if $FORCE_HTTPS;
my $HTML_HEADER = "
<HTML>
<HEAD>
<TITLE>OAR REST API</TITLE>
</HEAD>
<BODY>
<HR>
<A HREF=$apiuri/resources.html>RESOURCES</A>&nbsp;&nbsp;&nbsp;
<A HREF=$apiuri/jobs.html>JOBS</A>&nbsp;&nbsp;&nbsp;
<HR>
";

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
  $URI = qr{^/jobs\.*(yaml|xml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$1);
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);
    my $cmd    = "$OARSTAT_CMD -Y";
    my $cmdRes = apilib::send_cmd($cmd,"Oarstat");
    my $jobs = apilib::import($cmdRes,"yaml");
    my $result;
    foreach my $job ( keys( %{$jobs} ) ) {
      $result->{$job}->{state}=$jobs->{$job}->{state};
      $result->{$job}->{owner}=$jobs->{$job}->{owner};
      $result->{$job}->{name}=$jobs->{$job}->{name};
      $result->{$job}->{queue}=$jobs->{$job}->{queue};
      $result->{$job}->{submission}=$jobs->{$job}->{submissionTime};
      $result->{$job}->{uri}=apilib::make_uri("/jobs/$job.$ext",0);
      $result->{$job}->{uri}=apilib::htmlize_uri($result->{$job}->{uri},$ext,$FORCE_HTTPS);
    }
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($result,$type);
    last;
  };


  #
  # Details of a job (oarstat wrapper)
  #
  $URI = qr{^/jobs/(\d+)\.*(yaml|xml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $jobid = $1;
    my $ext=apilib::set_ext($q,$2);
    (my $output_opt, my $header)=apilib::set_output_format($ext);
    my $cmd    = "$OARSTAT_CMD -fj $jobid $output_opt";
    my $cmdRes = apilib::send_cmd($cmd,"Oarstat");
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    if ($ext eq "html") { print "<PRE>\n"; }
    print $cmdRes;
    if ($ext eq "html") { print "</PRE>\n"; }
    last;
  };

  #
  # List of resources ("oarnodes -s" wrapper)
  #
  $URI = qr{^/resources\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$1);
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);
    my $cmd    = "$OARNODES_CMD -Y -s";
    my $cmdRes = apilib::send_cmd($cmd,"Oarnodes");
    my $resources = apilib::import($cmdRes,"yaml");
    my $result;
    foreach my $node ( keys( %{$resources} ) ) {
        $result->{$node}->{uri}=apilib::make_uri("/resources/nodes/$node.$ext",0);
        $result->{$node}->{uri}=apilib::htmlize_uri($result->{$node}->{uri},$ext,$FORCE_HTTPS);
      foreach my $id ( keys( %{$resources->{$node}} ) ) {
        $result->{$node}->{$id}->{status}=$resources->{$node}->{$id};
        $result->{$node}->{$id}->{uri}=apilib::make_uri("/resources/$id.$ext",0);
        $result->{$node}->{$id}->{uri}=apilib::htmlize_uri($result->{$node}->{$id}->{uri},$ext,$FORCE_HTTPS);
      }
    }
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    print apilib::export($result,$type);
    last;
  };

  #
  # List all the resources with details (oarnodes wrapper)
  #
  $URI = qr{^/resources/all\.*(yaml|json|html)*$};
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$1);
    (my $output_opt, my $header)=apilib::set_output_format($ext);
    my $cmd    = "$OARNODES_CMD $output_opt";
    my $cmdRes = apilib::send_cmd($cmd,"Oarnodes");
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    if ($ext eq "html") { print "<PRE>\n"; }
    print $cmdRes;
    if ($ext eq "html") { print "</PRE>\n"; }
    last;
  }; 

  #
  # Details of a resource ("oarnodes -r <id>" wrapper)
  #
  $URI = qr{^/resources/(\d+)\.*(yaml|xml|json|html)*$};  
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$2);
    (my $output_opt, my $header)=apilib::set_output_format($ext);
    my $cmd    = "$OARNODES_CMD -r $1 $output_opt";  
    my $cmdRes = apilib::send_cmd($cmd,"Oarnodes");
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    if ($ext eq "html") { print "<PRE>\n"; }
    print $cmdRes;
    if ($ext eq "html") { print "</PRE>\n"; }
    last;
  };
 
  #
  # Details of a node (oarnodes wrapper)
  #
  $URI = qr{^/resources/nodes/([\w\-]+)\.*(yaml|xml|json|html)*$};  
  apilib::GET( $_, $URI ) && do {
    $_->path_info =~ m/$URI/;
    my $ext=apilib::set_ext($q,$2);
    (my $output_opt, my $header)=apilib::set_output_format($ext);
    my $cmd    = "$OARNODES_CMD $1 $output_opt";  
    my $cmdRes = apilib::send_cmd($cmd,"Oarnodes");
    print $header;
    print $HTML_HEADER if ($ext eq "html");
    if ($ext eq "html") { print "<PRE>\n"; }
    print $cmdRes;
    if ($ext eq "html") { print "</PRE>\n"; }
    last;
  }; 

  #
  # A new job (oarsub wrapper)
  #
  $URI = qr{^/jobs\.*(yaml|xml|json|html)*$};
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

    # Check the submited job
    my $job = apilib::check_job( $q->param('POSTDATA'), $q->content_type );

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
        400,
        "Oar server error",
        "Oarsub command exited with status $err: $cmdRes\nCmd:\n$oarcmd"
      );
    }
    elsif ( $cmdRes =~ m/.*JOB_ID\s*=\s*(\d+).*/m ) {
      print $header;
      print $HTML_HEADER if ($ext eq "html");
      print apilib::export( { 'job_id' => "$1",
                      'uri' => apilib::htmlize_uri(apilib::make_uri("/jobs/$1.". $ext,0),$ext,$FORCE_HTTPS)
                    } , $type );
    }
    else {
      apilib::ERROR( 400, "Parse error",
        "Job submited but the id could not be parsed" );
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
    (my $output_opt, my $header, my $type)=apilib::set_output_format($ext);

    # Must be authenticated
    if ( not $authenticated_user =~ /(\w+)/ ) {
      apilib::ERROR( 403, "Forbidden",
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
                    'uri' => apilib::htmlize_uri(apilib::make_uri("/jobs/$jobid.$ext",0),$ext,$FORCE_HTTPS)
                  } , $type );
    last;
  };


  #
  # Anything else -> 404
  #
  apilib::ERROR( 404, "Not found", "No way to handle your request " . $q->path_info );
}
