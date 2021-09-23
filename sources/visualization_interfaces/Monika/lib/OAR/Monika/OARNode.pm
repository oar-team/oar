## Created on November 2007 by Joseph.Emeras@imag.fr

## this package handles a OAR node description

package OAR::Monika::OARNode;

use strict;
use warnings;
use OAR::Monika::monikaCGI;
use OAR::Monika::Conf;
use Data::Dumper;
use Time::Local;
use POSIX qw(strftime);

## class constructor
sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  $self->{Nodename} = shift or die "missing a node name !";
  $self->{Ressources} = shift or die "missing node ressources !";
  bless ($self, $class);
  return $self;
}

## return node full name
sub name {
  my $self = shift;
  return $self->{Nodename};
}

## return node's ressource state
# parameters: node, resource id
# return value: state of the given ressource
sub ressourceState($$){
  my $self = shift;
  my $ressource= shift;
  return $self->{Ressources}->{$ressource}->{infos}->{state};
}

## return node's state
# parameters: node
# return value: hash table containing (ressource, state) couples
sub state($){
  my $self = shift;
  my %hashResult;
  foreach my $key (keys %{$self->{Ressources}}){
    #$hashResult{$key}= $self->{Ressources}->{$key}->{infos}->{state};
    $hashResult{$key}= $self->ressourceState($key);
  }
  return %hashResult;
}

## return this node's ressource cores count
# parameters: node, resource id
# return value: number of cores of the given ressource
#sub ressourceCores($$) {
#  my $self = shift;
#  my $ressource= shift;
#  return $self->{Ressources}->{$ressource}->{infos}->{cpucore};
#}

## return this node cpu/cores resource count: if a cpu is composed of two cores, the return value will be 2...
sub nodeResources {
  my $node = shift;
  my $cpt=0;
  #my %alreadyCounted;
  foreach (keys %{$node->{Ressources}}){
    #unless (defined($alreadyCounted{$node->{Ressources}->{$_}->{infos}->{cpu}})){
        #$cpt+=$node->{Ressources}->{$_}->{infos}->{cpucore};
        #$alreadyCounted{$node->{Ressources}->{$_}->{infos}->{cpu}}= 1;
    #}
    $cpt++;
  }
  return $cpt;
}

## alias cpus --> core
sub cpus {
  my $node = shift;
  my $result= $node->nodeResources;
  return $result;
}

## extract the name to display using a regex from the node real name
sub displayname {
  my $self = shift;
  $self->name() =~ OAR::Monika::Conf::myself()->nodenameRegex();
  my $shortname = $1 or die "Fail to extract node' shortname";
  return $shortname;;
}

## extract the name to display on the page
sub displayHTMLname {
  my $self = shift;
  $self->name() =~ OAR::Monika::Conf::myself()->nodenameRegexDisplay();
  my $shortname = $1 or die "Fail to extract node' shortname";
  return $shortname;
}

## return a hash containing (ressource,\@jobs) couple.
sub jobs {
  my $self = shift;
  my %hashResult;
  foreach my $key (keys %{$self->{Ressources}}){
    $hashResult{$key}= $self->{Ressources}->{$key}->{jobs};
  }
  return %hashResult;
}

## return an array containing ressource's jobs.
sub ressourceJobs {
  my $self = shift;
  my $ressource= shift;
  my $ptResult= $self->{Ressources}->{$ressource}->{jobs};
  return @$ptResult;
}

sub isRessourceWorking{
  my $self = shift;
  my $ressource= shift;
  if (@{$self->{Ressources}->{$ressource}->{jobs}}){
    return 1;
  }else{
    return 0;
  }

}

## return the hash table of properties of this node's ressource
sub ressourceProperties($$) {
  my $self = shift;
  my $ressource= shift;
  return %{$self->{Ressources}->{$ressource}->{infos}};
}

## return the (ressource, \%properties) couple for this node
sub properties {
  my $self = shift;
    my %hashResult;
  foreach my $key (keys %{$self->{Ressources}}){
    #$hashResult{$key}= $self->{Ressources}->{$key}->{infos};
    my %hashtemp= $self->ressourceProperties($key);
    $hashResult{$key}= \%hashtemp;
  }
  return %hashResult;
}

## print this node status HTML table
sub htmlTable {
  my $self = shift;
  my $cgi = shift;
  my $output = "";

  $output .= $cgi->start_table({-border => "1",
                -cellspacing => "0",
                -cellpadding => "0",
                -width => "100%"
                   });
  $output .= $cgi->start_Tr({-align => "center"});

  my $cgiName = File::Basename::basename($cgi->self_url(-query=>0));
  my $max_cores_per_line = OAR::Monika::Conf::myself()->max_cores_per_line();
  my $nb_cells = 0;
  foreach my $currentRessource (sort keys %{$self->{Ressources}}){
    if (($nb_cells++ % $max_cores_per_line) == 0){
        $output .= $cgi->end_Tr();
        $output .= $cgi->start_Tr({-align => "center"});
    }
    #my $ressourceState= $self->{Ressources}->{$currentRessource}->{infos}->{state};
    my $ressourceState= $self->ressourceState($currentRessource);

    if ($ressourceState eq "Alive" && $self->isRessourceWorking($currentRessource) eq '1') {
      my @jobs = @{$self->{Ressources}->{$currentRessource}->{jobs}};

      $output .= $cgi->start_td();
      $output .= $cgi->start_table({-border => "1", -cellspacing => "0", -cellpadding => "0", -width => "100%"});
      foreach my $curr_job (@jobs){
        $output .= $cgi->start_Tr({-align => "center"});
        $output .= $cgi->colorTd($curr_job, 100/$self->cpus."%",$cgiName."?job=$curr_job");
        $output .= $cgi->end_Tr();
      }
      $output .= $cgi->end_table();
      $output .= $cgi->end_td();
    }
    elsif ($ressourceState eq "Alive" && $self->isRessourceWorking($currentRessource) eq '0'){
      my $drain = $self->{Ressources}->{$currentRessource}->{infos}->{drain};
      if (!defined($drain) or ($drain ne "YES")) {
        $output .= $cgi->colorTd("Free",100/$self->cpus."%");
      } else {
        $output .= $cgi->colorTd("Drain",100/$self->cpus."%");
      }
    }

    elsif ($ressourceState eq "Down") {
      $output .= $cgi->colorTd("Down",100/$self->cpus."%");
    }
    elsif ($ressourceState eq "Absent") {

      my $available_upto = $self->{Ressources}->{$currentRessource}->{infos}->{available_upto};
      if(defined($available_upto) && $available_upto ne '0'){
        #my $now= `date +%s`;
        my $now= time();
        if($now < $available_upto && $available_upto ne '2147483647'){
          $output .= $cgi->colorTd("StandBy",100/$self->cpus."%");
        }else{
          $output .= $cgi->colorTd("Absent",100/$self->cpus."%");
        }
      }
      else{
        $output .= $cgi->colorTd("Absent",100/$self->cpus."%");
      }
    }
    elsif ($ressourceState eq "Suspected") {
      # if the resource is suspected and running a job, we must display it
      # differently
      if($self->isRessourceWorking($currentRessource) eq '1'){
        my @jobs = @{$self->{Ressources}->{$currentRessource}->{jobs}};
        $output .= $cgi->colorTd($jobs[0].'*',100/$self->cpus."%");
        #$output .= $cgi->colorTd($cgi->i("Suspected"),100/$self->cpus."%");
      }
      else{
        $output .= $cgi->colorTd("Suspected",100/$self->cpus."%");
      }
    }
    else {
      $output .= $cgi->colorTd("Down",100/$self->cpus."%");
    }
  }
  $output .= $cgi->end_Tr();
  $output .= $cgi->end_table();
  return $output;
}

sub getRessourceInfos {
  my $self = shift;
  my $ressource = shift;
  defined $ressource or die "which ressource ?";
  exists $self->{Ressources}->{$ressource}->{infos} or die "Unknown ressource: ".$ressource;
  my %return = %{$self->{Ressources}->{$ressource}->{infos}};
  return %return;
}

sub htmlStatusTable {
  my $self = shift;
  my $cgi = shift;
  my $output = "";
  my $nodes_synonym = OAR::Monika::Conf::myself->nodes_synonym;
  $output .= $cgi->start_table({-border=>"1", -align => "center"});
  $output .= $cgi->start_Tr();
  $output .= $cgi->th({-align => "left", bgcolor => "^c0c0c0"}, $cgi->i("Nodename"));
  $output .= $cgi->th({-align => "left"}, $self->name());
  $output .= $cgi->end_Tr();
  $output .= $cgi->end_table();
  $output .= $cgi->br();
  $output .= $cgi->start_table({-border=>"1", -align => "center"});
  my @keylist = keys %{$self->{Ressources}};
  my @properties= keys %{$self->{Ressources}->{$keylist[0]}->{infos}};
  $output .= $cgi->start_Tr();
  $output .= $cgi->th({-align => "left", bgcolor => "^c0c0c0"}, $cgi->i("Ressource no."));
  foreach my $key (sort @keylist) {
    $output .= $cgi->th({-align => "left", bgcolor => "^c0c0c0"}, $cgi->i($key));
  }
  $output .= $cgi->end_Tr();

  foreach my $prop (@properties) {
    $output .= $cgi->start_Tr();
    $output .= $cgi->th({-align => "left", bgcolor => "^c0c0c0"}, $cgi->i($prop));
    foreach my $key (sort @keylist) {
      my $value= $self->{Ressources}->{$key}->{infos}->{$prop};
      if($prop eq $nodes_synonym){
        $value= $self->displayHTMLname();
      }
      if($prop eq 'available_upto'){
        $value= strftime("%F %T",localtime($value));
      }
      $output .= $cgi->td({-valign => "top", bgcolor => "^c0c0c0"}, $cgi->i($value));
    }
    $output .= $cgi->end_Tr();
  }
  $output .= $cgi->end_table();
  return $output;
}


## that's all.
return 1;
