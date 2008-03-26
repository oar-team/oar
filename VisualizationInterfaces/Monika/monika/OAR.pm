## Modified on November 2007 by Joseph.Emeras@imag.fr
## added: OAR2 compatibility
##        added methods used for managing OAR2 nodes and display

## This package handles OAR stuff...
## It uses OARNode.pm and OARJob.pm to store nodes and Jobs descriptions

package monika::OAR;

use strict;
use warnings;
use Data::Dumper;
use monika::db_io;
use monika::OARNode;
use monika::OARJob;
use Tie::IxHash;

## Class constructor
sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  $self->{ALLNODES} = {};
  $self->{PROPERTIES} = {};
  $self->{ALLJOBS} = {};
  bless ($self,$class);
  return $self;
}

## return all nodes
sub allnodes {
  my $self = shift;
  return $self->{ALLNODES};
}

sub properties {
  my $self = shift;
  return $self->{PROPERTIES};
}

## acces DataBase and get information about nodes
sub oarnodes {

  my $self = shift;
  my $hostname= monika::Conf::myself->hostname;
  my $port = monika::Conf::myself->dbport;
  my $dbtype= monika::Conf::myself->dbtype;
  my $dbname= monika::Conf::myself->dbname;
  my $username= monika::Conf::myself->username;
  my $pwd= monika::Conf::myself->password;

  my $dbh = monika::db_io::dbConnection($hostname, $port, $dbtype, $dbname, $username, $pwd);
  my @nodeNames= monika::db_io::list_nodes($dbh);
  foreach my $currentNode (@nodeNames){
    my @currentNodeRessources= monika::db_io::get_all_resources_on_node($dbh, $currentNode);
    my %hashInfoCurrentNodeRessources;
    foreach my $currentRessource (@currentNodeRessources){
      my %hashInfosJobs;
      $hashInfosJobs{infos}= monika::db_io::get_resource_info($dbh, $currentRessource);## get_resource_info returns a hash ref
      my @jobs= monika::db_io::get_resource_job($dbh, $currentRessource);## get_resource_job returns an array
      $hashInfosJobs{jobs}= \@jobs;
      $hashInfoCurrentNodeRessources{$currentRessource}= \%hashInfosJobs;
    }
    my $node= new monika::OARNode($currentNode, \%hashInfoCurrentNodeRessources);
    $self->allnodes()->{$node->displayname} = $node;
  }
  monika::db_io::dbDisconnect($dbh);
}

## retrieve a OAR job description.
sub getJobProperties {
  my $myself = shift;
  my $currentJobId = shift;
  my $cgi = shift;
  my $hostname= monika::Conf::myself->hostname;
  my $port = monika::Conf::myself->dbport;
  my $dbtype= monika::Conf::myself->dbtype;
  my $dbname= monika::Conf::myself->dbname;
  my $username= monika::Conf::myself->username;
  my $pwd= monika::Conf::myself->password;

  my $dbh = monika::db_io::dbConnection($hostname, $port, $dbtype, $dbname, $username, $pwd);
  
  my $jobInfos= monika::db_io::get_job_stat_infos($dbh, $currentJobId);
  my $job = monika::OARJob->new($currentJobId);
  foreach my $key (keys %{$jobInfos}){
    my $value= $jobInfos->{$key};
    $job->set($key,$value,$cgi);
  }

  ## let's count the nodes and cpu used.

  my $structure= monika::db_io::get_resources_data_structure_current_job($dbh, $currentJobId);
  my $parrayRessources= $structure->[0]->[0]->[0]->{'resources'};
  my $property= $structure->[0]->[0]->[0]->{'property'};
  my $walltime= $structure->[0]->[1];
  my $string= "-l \"{$property}";
  foreach my $ressourceGroup (@$parrayRessources){
    $string.= "/".$ressourceGroup->{resource}."=".$ressourceGroup->{value};
  }

  my $sec=$walltime%60;
  $walltime/=60;
  my $min=$walltime%60;
  $walltime = int($walltime / 60);
  my $hour=$walltime;
  my $hWallTime= "$hour:$min:$sec";
  $job->set("walltime",$hWallTime,$cgi);
  $string.=",walltime=$hWallTime\"";
  $job->set("wanted_resources",$string,$cgi);

  ## dates formatting
  my $submission_time= $job->get("submission_time");
  #my ($year,$mon,$mday,$hour,$min,$sec)= monika::db_io::local_to_ymdhms($submission_time);
  #$submission_time= "$year-$mon-$mday $hour:$min:$sec";
  $job->set("submission_time",monika::db_io::local_to_sql($submission_time),$cgi);

  my $start_time= $job->get("start_time");
  $job->set("start_time",monika::db_io::local_to_sql($start_time),$cgi);
  monika::db_io::dbDisconnect($dbh);
  return $job;
}

## retrieve OAR jobs description and store them in the ALLJOBS hash.
sub qstat {
  my $self = shift;
  my $cgi = shift;
  my $hostname= monika::Conf::myself->hostname;
  my $port = monika::Conf::myself->dbport;
  my $dbtype= monika::Conf::myself->dbtype;
  my $dbname= monika::Conf::myself->dbname;
  my $username= monika::Conf::myself->username;
  my $pwd= monika::Conf::myself->password;

  my $dbh = monika::db_io::dbConnection($hostname, $port, $dbtype, $dbname, $username, $pwd);
  my @jobIds= monika::db_io::get_queued_jobs($dbh);
  foreach my $currentJobId (@jobIds){
    my $jobInfos= monika::db_io::get_job_stat_infos($dbh, $currentJobId);
    my $job = monika::OARJob->new($currentJobId);
    foreach my $key (keys %{$jobInfos}){
      my $value= $jobInfos->{$key};
      $job->set($key,$value,$cgi);
    }

    ## let's count the nodes and cpu used.

    my $structure= monika::db_io::get_resources_data_structure_current_job($dbh, $currentJobId);
    my $parrayRessources= $structure->[0]->[0]->[0]->{'resources'};
    my $property= $structure->[0]->[0]->[0]->{'property'};
    my $walltime= $structure->[0]->[1];
    my $string= "-l \"{$property}";
    foreach my $ressourceGroup (@$parrayRessources){
      $string.= "/".$ressourceGroup->{resource}."=".$ressourceGroup->{value};
    }

    my $sec=$walltime%60;
    $walltime/=60;
    my $min=$walltime%60;
    $walltime = int($walltime / 60);
    my $hour=$walltime;
    my $hWallTime= "$hour:$min:$sec";
    $job->set("walltime",$hWallTime,$cgi);
    $string.=",walltime=$hWallTime\"";
    $job->set("wanted_resources",$string,$cgi);

    ## dates formatting
    my $submission_time= $job->get("submission_time");
    #my ($year,$mon,$mday,$hour,$min,$sec)= monika::db_io::local_to_ymdhms($submission_time);
    #$submission_time= "$year-$mon-$mday $hour:$min:$sec";
    $job->set("submission_time",monika::db_io::local_to_sql($submission_time),$cgi);

    my $start_time= $job->get("start_time");
    if($start_time ne '0'){
      $job->set("start_time",monika::db_io::local_to_sql($start_time),$cgi);
    }
    else{
      $job->set("start_time", "n/a", $cgi);
    }
    my @scheduled_start_array= monika::db_io::get_gantt_job_start_time($dbh, $currentJobId);
    my $scheduled_start= $scheduled_start_array[0];
    if(defined $scheduled_start && $scheduled_start ne '0'){
      $job->set("scheduled_start",monika::db_io::local_to_sql($scheduled_start),$cgi);
    }
    else{
      $job->set("scheduled_start", "no prediction", $cgi);
    }

    $self->alljobs()->{$currentJobId} = $job;
  }
  monika::db_io::dbDisconnect($dbh);
}


## return nodes verifying a property
sub nodelistByProperty {
  my $self = shift;
  my $property = shift;
  my @nodes = values %{$self->allnodes};
  my %alreadyCounted;
  my @nodesSelected;
  foreach my $node(@nodes){
    my %hashRessProp= $node->properties();
    foreach my $ress (keys %hashRessProp){
          my %hashProp= %{$hashRessProp{$ress}};
          foreach my $p (keys %hashProp) {
                  my $hidden = undef;
                  my $prop= $p."=".$hashProp{$p};
                  if($prop eq $property){
                    unless (defined($alreadyCounted{$node})){
                      $alreadyCounted{$node}= 1;
                      #push @nodesSelected, $node->name;
                      push @nodesSelected, $node->displayHTMLname;
                    }
                  }
          }
    }
  }
  #print STDOUT Dumper(@nodesSelected);
  return \@nodesSelected;
}

## return all jobs
sub alljobs {
  my $self = shift;
  return $self->{ALLJOBS};
}

## print a HTML summary table of the current usage of the nodes.
sub htmlSummaryTable {
  my $self = shift;
  my $cgi = shift;
  my $output = "";
  my $summary_display = monika::Conf::myself->summary_display;
  my $nodes_synonym = monika::Conf::myself->nodes_synonym;
  $summary_display = $summary_display.";";  ## add a ., to the end for parsing the string
  my %hash_display;
  tie %hash_display, "Tie::IxHash"; ## for hash insertion order
  while($summary_display ne ""){
    $summary_display =~ s/(.*?);//;
    my $tmp=$1;
    my $key;
    if($tmp =~ m/(.*?):/){
      $tmp = $tmp.",";
      $tmp =~ s/(.*?)://;
      $key = ($1);
      my @array_values;
      while($tmp ne ""){
        $tmp =~ s/(.*?),//;
        my $value = $1;
        if($value eq 'nodes_synonym'){
          $value = $nodes_synonym;
        }        
        push @array_values, $value;
      }
      $hash_display{$key} = \@array_values;
    }
    else{
      $key = $tmp;
      my @array_values;
      push @array_values, "resource_id";
      $hash_display{"$key"} = \@array_values;
    }
  }
  $output .= $cgi->start_table({-border=>"1",
		     -align =>"center"
		    });
	$output .= $cgi->start_Tr({-align => "center"});
  my $pt_resources = $self->getResources();
  foreach my $type_res (keys %hash_display){
  	$output .= $cgi->td();
    $output .= $cgi->start_table({-border=>"1",-align =>"center"});
		$output .= $cgi->start_Tr({-align => "center"});
	  $output .= $cgi->td($cgi->i($cgi->u($type_res." summary")));
	  $output .= $cgi->end_Tr();
    $output .= $cgi->start_Tr({-align=>"center"});
    $output .= $cgi->td($cgi->i(""));
    $output .= $cgi->td($cgi->b("Free"));
    $output .= $cgi->td($cgi->b("Busy"));
    $output .= $cgi->td($cgi->b("Total"));
    $output .= $cgi->end_Tr();
    if($type_res eq 'default'){
      foreach my $val (@{$hash_display{$type_res}}){
        $output .= $cgi->td($cgi->b($val));
        my ($free, $busy, $total) = $self->resourceCount($type_res, $val, $pt_resources);
        $output .= $cgi->td([$free, $busy, $total]);
        $output .= $cgi->end_Tr();
      }
    }
    else{
      foreach my $val (@{$hash_display{$type_res}}){
        my ($free, $busy, $total) = $self->resourceCount($type_res, $val, $pt_resources);
        $output .= $cgi->td($cgi->b($val));
        $output .= $cgi->td([$free, $busy, $total]);
        $output .= $cgi->end_Tr();
      }
    }  
    $output .= $cgi->end_table();
  }
  $output .= $cgi->end_Tr();
  $output .= $cgi->end_table();
  return $output;
}
sub getResources{
  my $self = shift;
  my %resources;
  foreach my $resource_name (keys %{$self->{'ALLNODES'}}){
    foreach my $resource_id (keys %{$self->{'ALLNODES'}->{$resource_name}->{'Ressources'}}){
      $resources{$resource_id} = $self->{'ALLNODES'}->{$resource_name}->{'Ressources'}->{$resource_id};
    }
  }
  return \%resources;
}

## compute a summary of the usage of OAR nodes
sub resourceCount($$$$) {
  my $self = shift;
  my $type_resource = shift;
  my $att_name = shift;
  my $all_resources = shift;
  my ($free, $busy, $total) = (0,0,0);
  my %hashtotal;
  my %hashfree;
  my %alreadyCounted;
  my @associated_resources;
  foreach my $resource_id (keys %{$all_resources}){
    foreach my $att (keys %{$all_resources->{$resource_id}->{'infos'}}){   
      my $value= $all_resources->{$resource_id}->{'infos'}->{$att};
      if($att eq $att_name && $type_resource eq $all_resources->{$resource_id}->{'infos'}->{'type'}){
        push @associated_resources, $resource_id;
        unless(exists $alreadyCounted{$value}){
          $total++;
          if(!(@{$all_resources->{$resource_id}->{'jobs'}} > 0)){
            if($all_resources->{$resource_id}->{'infos'}->{'state'} eq 'Alive'){
              $hashfree{"$value:$att:$type_resource"}++;
            }
          }
          $alreadyCounted{$value} = "$att:$type_resource";
          $hashtotal{"$value:$att:$type_resource"} = 1;
        }
        else{
          $hashtotal{"$value:$att:$type_resource"}++;
          unless(@{$all_resources->{$resource_id}->{'jobs'}} > 0){
            $hashfree{"$value:$att:$type_resource"}++;
          }
        }
      }
    }
  }
  my %cpt_att;
  foreach (@associated_resources){
    if(@{$all_resources->{$_}->{'jobs'}} > 0){
      my $value= $all_resources->{$_}->{'infos'}->{$att_name};
      $cpt_att{$value} = '';
    }  
  }
  foreach (keys %cpt_att){
    $busy++;
  }
  foreach (keys %hashfree){
    if($hashfree{$_} eq $hashtotal{$_}){
      $free++;
    }
  }
  return ($free, $busy, $total);
}

## print a HTML tables describing current OAR jobs.
sub htmlJobTable {
  my $self = shift;
  my $cgi = shift;
  my $output = "";
#  $output .= $cgi->start_form();
  $output .= $cgi->start_table({-border=>"1", -align => "center"});
  my $alljobs = $self->alljobs();
  my @keys = keys %$alljobs;
  if ($#keys < 0) {
    $output .= $cgi->Tr($cgi->td("No job currently in queues"));
  } else {

        $output .= $cgi->start_Tr();
        $output .= $cgi->td({-align => "center"},"Id");
        $output .= $cgi->td({-align => "center"},"User");
        $output .= $cgi->td({-align => "center"},"State");
        $output .= $cgi->td({-align => "center"},"Queue");
        #$output .= $cgi->td({-align => "center"},"NbNodes");
        #$output .= $cgi->td({-align => "center"},"NbCores");
        $output .= $cgi->td({-align => "center"},"wanted_resources");
        $output .= $cgi->td({-align => "center"},"Type");
        $output .= $cgi->td({-align => "center"},"Properties");
        $output .= $cgi->td({-align => "center"},"Reservation");
        $output .= $cgi->td({-align => "center"},"Walltime");
        $output .= $cgi->td({-align => "center"},"Submission Time");
        $output .= $cgi->td({-align => "center"},"Start Time");
#        $output .= $cgi->td({-align => "center"},"Comment");
        $output .= $cgi->td({-align => "center"},"Scheduled Start");
        $output .= $cgi->end_Tr();

    @keys = sort {$a <=> $b} @keys;
    foreach my $key (@keys) {
      $output .= $alljobs->{$key}->htmlTableRow($cgi);
    }
  }
  $output .= $cgi->end_table();
  return $output;
}

sub htmlPropertyChooser {
  my $self = shift;
  my $cgi = shift;
  my $output = "";
	# do not show hidden properties...
	my @checkboxes = ();
  my @hiddenProperties = monika::Conf::myself()->hiddenProperties();
  my @nodes = values %{$self->allnodes};
  #my %alreadyCounted;  
  my %hiddenHash;
  foreach(@hiddenProperties){
    $hiddenHash{$_} = '';
  }
  my $hostname= monika::Conf::myself->hostname;
  my $port = monika::Conf::myself->dbport;
  my $dbtype= monika::Conf::myself->dbtype;
  my $dbname= monika::Conf::myself->dbname;
  my $username= monika::Conf::myself->username;
  my $pwd= monika::Conf::myself->password;
  my $dbh = monika::db_io::dbConnection($hostname, $port, $dbtype, $dbname, $username, $pwd);
  my $result = monika::db_io::get_properties_values($dbh, \%hiddenHash);
  monika::db_io::dbDisconnect($dbh);
  my %hashcheckboxes;
  foreach(keys %{$result}){
    foreach my $prop (keys %{$result->{$_}}){
      my $str = $prop."=".$result->{$_}->{$prop};
      $hashcheckboxes{$str} = '';
    }
  }
  foreach(keys %hashcheckboxes){
    push @checkboxes, $_;
  }
  # old one, very slow...
  #foreach my $node(@nodes){
  #  my %hashRessProp= $node->properties();
  #  foreach my $ress (keys %hashRessProp){
  #        my %hashProp= %{$hashRessProp{$ress}};
  #        foreach my $p (keys %hashProp) {
  #                my $hidden = undef;
  #                my $prop= $p."=".$hashProp{$p};
  #                foreach my $h (@hiddenProperties) {
  #                        $prop =~ /^$h=/ and $hidden = 1;
  #                }
  #                unless (defined($alreadyCounted{$prop})){
  #                  defined $hidden or push @checkboxes, $prop;
  #                  $alreadyCounted{$prop}= 1;
  #                }
  #        }
  #  }
  #}
  if ($#checkboxes >= 0) {
    my @sortedCheckboxes= sort { $a cmp $b } @checkboxes;
    $output .= $cgi->start_div({ -align => "center" });
    $output .= $cgi->start_form({ -method => "get" });
    $output .= $cgi->b("OAR properties:");
    $output .= $cgi->checkbox_group({
				    -name=> 'props',
				    -values=> \@sortedCheckboxes,
				    -columns => 5,
				     -title => "click to select property"
				    });
    $output .= $cgi->submit("Action","Display nodes for these properties");
    $output .= $cgi->end_div();
    $output .= $cgi->endform();
  }
  return $output;
}

sub htmlNodeByProperty {
  my $self = shift;
  my $cgi = shift;
  my $output = "";
  my @selected = sort $cgi->param('props');
  #my @nodesList;
  foreach my $prop (@selected) {
    if (defined($self->nodelistByProperty($prop))){
        $output .= $cgi->h3({-align => "center"}, "Reservations for property $prop:");
        #push @nodesList, @{$self->nodelistByProperty($prop)};
        $output .= $cgi->nodeReservationTable($self->allnodes(),$self->nodelistByProperty($prop));
    }
  }
  #$output .= $cgi->nodeReservationTable($self->allnodes(),\@nodesList);
  return $output;
}

## that's all.
return 1;

