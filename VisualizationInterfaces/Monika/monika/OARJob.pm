## Created on November 2007 by Joseph.Emeras@imag.fr

## this package handles a OAR job description

package monika::OARJob;

use strict;
#use warnings;
use monika::monikaCGI;
use File::Basename;
use Data::Dumper;

my $bestEffortColor = "#dddddd";

## class constructor
sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  my $jobId = shift;
  defined $jobId or die "missing jobId !";
  $self->{job_id} = $jobId;
  bless ($self,$class);
  return $self;
}

sub jobId {
  my $self = shift;
  return $self->{job_id};
}

sub owner {
  my $self = shift;
  my $owner = $self->get("job_user");
  $owner =~ s/@.+//;
  return $owner;
}

sub set {
  my $self = shift;
  my $key = shift;
  defined $key or die "which key ?";
  my $value = shift;
  # for best effort jobs
  my $cgi = shift;
  # for best effort jobs
  #defined $value or die "which value for $key ?";
  #unless (exists $self->{$key}) {
    #$self->{$key} = [];
    $self->{$key} = $value;
  #}
  #push @{$self->{$key}},$value;

  # for best effort jobs
  if ($self->get("queue_name") eq "besteffort"){
    $cgi->setColor($self->jobId(),$bestEffortColor);
  }
  # for best effort jobs

  return 1;
}

sub get {
  my $self = shift;
  my $key = shift;
  defined $key or die "which key ?";
  if (exists $self->{$key}) {
    #return $self->{$key}->[0];
    return $self->{$key};
  } else {
    return undef;
  }
}

sub getList {
  my $self = shift;
  my $key = shift;
  defined $key or die "which key ?";
  exists $self->{$key} or die "Unknown key: ".$key;
  return $self->{$key};
}

sub htmlTableRow {
  my $self = shift;
  my $cgi = shift;

  my $output = "";
  $output .= $cgi->start_Tr();
  my $cgiName = File::Basename::basename($cgi->self_url(-query=>0));
  $output .= $cgi->colorTd($self->jobId(),undef,$cgiName."?job=".$self->jobId(), "click to see job details");
  if (monika::Conf::myself()->server_do_mail()) {
    $output .= $cgi->td({-align => "center"},
			$cgi->a({
				 -href => "mailto:".$self->get("job_user"),
				 -title => "click to send mail"
				}, $self->owner()));
  } elsif (monika::Conf::myself()->user_infos() ne "") {
    $output .= $cgi->td({-align => "center"},
                        $cgi->a({
                                 -href => monika::Conf::myself()->user_infos().$self->get("job_user"),
                                 -title => "click for more informations"
                                }, $self->owner()));
  } else {
    $output .= $cgi->td({-align => "center"},$self->owner());
  }
  #Until now, we've displayed jobId and User...

  my $wanted_resources=$self->get("wanted_resources");
  my $walltime=$self->get("walltime");
  my $state= $self->get("state");
  my $queue= $self->get("queue_name");
  my $type= $self->get("job_type");
  my $properties= $self->get("properties");
  my $reservation= $self->get("reservation");
  my $submission_time = $self->get("submission_time");
  my $start_time = $self->get("start_time");
  my $scheduled_start = $self->get("scheduled_start");
  my $initial_request = $self->get("initial_request");
  if($initial_request =~ /-t container/){
  	$type.=" - container";
  }
  elsif($initial_request =~ /-t inner=(\d+)/){
  	$type.=" - inner job (container=$1)";
  }

  $output .= $cgi->td({-align => "center"},$state);
  $output .= $cgi->td({-align => "center"},$queue);
  $output .= $cgi->td({-align => "center"},$wanted_resources);
  $output .= $cgi->td({-align => "center"},$type);
  $output .= $cgi->td({-align => "center"},$properties);
  $output .= $cgi->td({-align => "center"},$reservation);
  $output .= $cgi->td({-align => "center"},$walltime);
  $output .= $cgi->td({-align => "center"},$submission_time);
  $output .= $cgi->td({-align => "center"},$start_time);
  $output .= $cgi->td({-align => "center"},$scheduled_start);
  $output .= $cgi->end_Tr();
  return $output;
}

sub htmlStatusTable {
  my $self = shift;
  my $cgi = shift;
  my $output = "";
  $output .= $cgi->start_table({-border=>"1",
				 -align => "center"
				});
  $output .= $cgi->start_Tr();
  $output .= $cgi->th({-align => "left", bgcolor => "#c0c0c0"}, $cgi->i("Job Id"));
  $output .= $cgi->th({-align => "left"}, $self->jobId());
  $output .= $cgi->end_Tr();
  my @keylist = keys %{$self};
  foreach my $key (sort @keylist) {
    if($key eq "job_id"){
      next;
    }
    $output .= $cgi->start_Tr();
    $output .= $cgi->td({-valign => "top", bgcolor=> "#c0c0c0"}, $cgi->i($key));
    my $list = $self->getList($key);
    my $val = join $cgi->br(),$list;
    #$val =~ s/([+,]\s*)/\1<BR>/g;
    $output .= $cgi->td($val);
    $output .= $cgi->end_Tr();
  }
  $output .= $cgi->end_table();
  return $output;
}

## that's all.
return 1;
