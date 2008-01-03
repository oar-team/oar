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

## as oarnodes method for oargrid context 
## convert allinfo nodes description and store them in the ALLNODES hash.
sub initnodes {
    my $self = shift;
    my $allinfoNodes = shift;
    my $nodejob = shift;
    my $value;
    my $state;

    foreach my $name (keys( %$allinfoNodes)) {
        my $node = new monika::OARNode($name);
        foreach my $key (keys( %{$$allinfoNodes{$name}})) {
             $value = $$allinfoNodes{$name}{$key};
            if ($key =~ /state/) {
                $state = $value;
            } else {
                $node->set($key,$value);
            }
        }
        if ($node->get("maxWeight") == 0) {
            $state = "Absent";
        }
        $node->set('state',$state);
        
        if ( $$nodejob{$name}) {
            $node->set("jobs",\@{$$nodejob{$name}});
        }
       #  $self->allnodes()->{$node->displayname} = $node;
       
       $self->allnodes()->{$name} = $node;
    }
}


## acces DataBase and get information about nodes
sub oarnodes {

  my $self = shift;
  my $hostname= monika::Conf::myself->hostname;
  my $dbtype= monika::Conf::myself->dbtype;
  my $dbname= monika::Conf::myself->dbname;
  my $username= monika::Conf::myself->username;
  my $pwd= monika::Conf::myself->password;

  my $dbh = monika::db_io::dbConnection($hostname, $dbtype, $dbname, $username, $pwd);
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
}


sub initjobs {
    my $self = shift;
    my $allinfoJobs = shift;
    my $cgi = shift;
    my $jobId;
    my $value;

    foreach $jobId (keys( %$allinfoJobs)) {
       my $job = monika::OARJob->new($jobId);
         foreach my $key (keys( %{$$allinfoJobs{$jobId}})) {
             if ($key =~ /hostnames/) {
                 $job->set($key,@{$$allinfoJobs{$jobId}{$key}},$cgi);
             } else {
                 if($$allinfoJobs{$jobId}{$key}) {
                     $value = $$allinfoJobs{$jobId}{$key};
                     $job->set($key,$value,$cgi);
                }
             }
         }
        $self->alljobs()->{$job->jobId} = $job;
    }
}

## retrieve OAR jobs description and store them in the ALLJOBS hash.
sub qstat {
  my $self = shift;
  my $cgi = shift;
  my $hostname= monika::Conf::myself->hostname;
  my $dbtype= monika::Conf::myself->dbtype;
  my $dbname= monika::Conf::myself->dbname;
  my $username= monika::Conf::myself->username;
  my $pwd= monika::Conf::myself->password;

  my $dbh = monika::db_io::dbConnection($hostname, $dbtype, $dbname, $username, $pwd);
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
    $job->set("start_time",monika::db_io::local_to_sql($start_time),$cgi);

    my @scheduled_start_array= monika::db_io::get_gantt_job_start_time($dbh, $currentJobId);
    my $scheduled_start= $scheduled_start_array[0];
    $job->set("scheduled_start",monika::db_io::local_to_sql($scheduled_start),$cgi);

    $self->alljobs()->{$currentJobId} = $job;
  }
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
  $summary_display = $summary_display.";";  ## add a ., to the end for parsing the string
  my %hash_display;
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
        ##hack for simplification of the user admin
        if($key eq 'default'){
          if($value eq 'nodes' || $value eq 'node'){
            $value = 'network_address';
          }
          elsif($value eq 'cores' || $value eq 'core'){
            $value = 'cpu';
          }
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
  $output .= $cgi->start_Tr({-valign=>"middle",
		  -align=>"center"
	         });
  $output .= $cgi->td($cgi->i("Resources status"));
  $output .= $cgi->td($cgi->b("Free"));
  $output .= $cgi->td($cgi->b("Busy"));
  $output .= $cgi->td($cgi->b("Total"));
  $output .= $cgi->end_Tr();
  
  foreach (keys %hash_display){
    my $type_res = $_;
    if($type_res eq 'default'){
      foreach my $val (@{$hash_display{$type_res}}){
        if($val eq 'network_address'){
          $output .= $cgi->td($cgi->b("nodes"));
        }
        elsif($val eq 'cpu'){
          $output .= $cgi->td($cgi->b("cores"));
        }
        else{
          $output .= $cgi->td($cgi->b("default"));
        }
        my ($free, $busy, $total) = $self->resourceCount($type_res, $val);
        $output .= $cgi->td([$free, $busy, $total]);
        $output .= $cgi->end_Tr();
      }
    }
    else{
      foreach my $val (@{$hash_display{$type_res}}){
        my ($free, $busy, $total) = $self->resourceCount($type_res, $val);
        $output .= $cgi->td($cgi->b($type_res));
        $output .= $cgi->td([$free, $busy, $total]);
        $output .= $cgi->end_Tr();
      }
    }

  }
  $output .= $cgi->end_table();
  return $output;
}

## compute a summary of the usage of OAR nodes
sub resourceCount {
  my $self = shift;
  my $type_resource = shift;
  my $att_name = shift;
  my ($free, $busy, $total) = (0,0,0);
  my %alreadySeen;
  foreach my $resource_name (keys %{$self->{'ALLNODES'}}){
    foreach my $resource_id (keys %{$self->{'ALLNODES'}->{$resource_name}->{'Ressources'}}){
      foreach my $att (keys %{$self->{'ALLNODES'}->{$resource_name}->{'Ressources'}->{$resource_id}->{'infos'}}){
        if($att eq $att_name && $type_resource eq $self->{'ALLNODES'}->{$resource_name}->{'Ressources'}->{$resource_id}->{'infos'}->{'type'}){       
          if($att_name eq 'network_address'){ ## it's a node
            unless(exists($alreadySeen{$self->{'ALLNODES'}->{$resource_name}->{'Ressources'}->{$resource_id}->{'infos'}->{'network_address'}})){
              if(defined ($self->{'ALLNODES'}->{$resource_name}->{'Ressources'}->{$resource_id}->{'jobs'}) && @{$self->{'ALLNODES'}->{$resource_name}->{'Ressources'}->{$resource_id}->{'jobs'}} > 0){ ## if a job is running on this resource
                $busy++;
                $total++;
              }
              else{
                $total++;
                if($self->{'ALLNODES'}->{$resource_name}->{'Ressources'}->{$resource_id}->{'infos'}->{'state'} eq 'Alive'){
                  $free++;
                }
              }
              $alreadySeen{$self->{'ALLNODES'}->{$resource_name}->{'Ressources'}->{$resource_id}->{'infos'}->{'network_address'}} = 'true';
            }
          }
          else{
            if(defined ($self->{'ALLNODES'}->{$resource_name}->{'Ressources'}->{$resource_id}->{'jobs'}) && @{$self->{'ALLNODES'}->{$resource_name}->{'Ressources'}->{$resource_id}->{'jobs'}} > 0){ ## if a job is running on this resource
                $busy++;
                $total++;
              }
            else{
              $total++;
              if($self->{'ALLNODES'}->{$resource_name}->{'Ressources'}->{$resource_id}->{'infos'}->{'state'} eq 'Alive'){
                $free++;
              }
            }
          }
        }
      }
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
#  $output .= $cgi->endform();

  return $output;
}

## print a HTML summary table of the current usage of the nodes.
sub htmlGridSummaryTable {
  my $self = shift;
  my $cgi = shift;
  my $allInfo = shift;
  my $load_img_path = shift;
  my @clusterSet = @_;
  my $output = "";
  my $allfree = 0;
  my $allbusy = 0;
  my $all = 0;
	my $src_img;

  $output .= $cgi->start_table({-border=>"1",
			   -align =>"center"
			  });
              
  $output .= $cgi->start_Tr({-valign=>"middle", -align=>"center"});
  $output .= $cgi->td($cgi->i("Cluster Name")); 
  foreach my $cluster (@clusterSet){
      $output .= $cgi->td({-class=> "lgray"},$cgi->b($cluster));
  }
  $output .= $cgi->td($cgi->b("all"));
  $output .= $cgi->end_Tr();


  #Load
  $output .= $cgi->start_Tr({-valign=>"middle", -align=>"center"});
  $output .= $cgi->td({-class=> "load"},$cgi->i("Load"));
  foreach my $cluster (@clusterSet){
			$src_img = '<img src="'.$load_img_path.'pie_'.$cluster.'.png" alt="pie_load">';
      $output .= $cgi->td({-class=> "load"},$src_img);
	}
	$src_img = '<img src="'.$load_img_path.'pie_all.png" alt="pie_load">';
  $output .= $cgi->td({-class=> "load"},$src_img);
  $output .= $cgi->end_Tr();

  #Site
  $output .= $cgi->start_Tr({-valign=>"middle", -align=>"center"});
  $output .= $cgi->td({-class=> "lblue"},$cgi->i("Site")); 
  foreach my $cluster (@clusterSet){
      $output .= $cgi->td({-class=> "lblue"},$$allInfo{$cluster}{info}{site});
    
  }
  $output .= $cgi->td("");
  $output .= $cgi->end_Tr();

  #Architecture Proc
  $output .= $cgi->start_Tr({ -valign=>"middle", -align=>"center"});
  $output .= $cgi->td({-class=> "lgray"},$cgi->i("Type")); 
  foreach my $cluster (@clusterSet){
      $output .= $cgi->td({-class=> "lgray"},$$allInfo{$cluster}{info}{architecture});
  }
  $output .= $cgi->td("");
  $output .= $cgi->end_Tr();

  #Resource unit
  $output .= $cgi->start_Tr({ -valign=>"middle", -align=>"center"});
  $output .= $cgi->td({-class=> "lgray"},$cgi->i("Resource unit"));
  foreach my $cluster (@clusterSet){
      $output .= $cgi->td({-class=> "lgray"},$$allInfo{$cluster}{info}{resourceUnit});
  }
  $output .= $cgi->td("");
  $output .= $cgi->end_Tr();
  
  $output .= $cgi->start_Tr({-valign=>"middle", -align=>"center"});
  $output .= $cgi->td({-class=> "lblue"},$cgi->i("Free Resources")); 
  foreach my $cluster (@clusterSet){
      $output .= $cgi->td({-class=> "lblue"},$$allInfo{$cluster}{stats}{freeNodes});
      $allfree += $$allInfo{$cluster}{stats}{freeNodes}
  }
  $output .= $cgi->td({-class=> "lblue"},$cgi->b($allfree));
  $output .= $cgi->end_Tr();
  
  $output .= $cgi->start_Tr({ -valign=>"middle", -align=>"center"});
  $output .= $cgi->td({-class=> "lgray"},$cgi->i("Busy Resources")); 
  foreach my $cluster (@clusterSet){
      $output .= $cgi->td({-class=> "lgray"},$$allInfo{$cluster}{stats}{busyNodes});
      $allbusy += $$allInfo{$cluster}{stats}{busyNodes};
  }
  $output .= $cgi->td({-class=> "lgray"},$cgi->b($allbusy));
  $output .= $cgi->end_Tr();
  
  $output .= $cgi->start_Tr({-valign=>"middle", -align=>"center"});
  $output .= $cgi->td({-class=> "lblue"},$cgi->i("All Resources")); 
  foreach my $cluster (@clusterSet){
      $output .= $cgi->td({-class=> "lblue"},$$allInfo{$cluster}{stats}{allNodes});
      $all += $$allInfo{$cluster}{stats}{allNodes};
  }
  $output .= $cgi->td({-class=> "lblue"},$cgi->b($all));
  $output .= $cgi->end_Tr();
  
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
  my %alreadyCounted;
  foreach my $node(@nodes){
    my %hashRessProp= $node->properties();
    foreach my $ress (keys %hashRessProp){
          my %hashProp= %{$hashRessProp{$ress}};
          foreach my $p (keys %hashProp) {
                  my $hidden = undef;
                  my $prop= $p."=".$hashProp{$p};
                  foreach my $h (@hiddenProperties) {
                          $prop =~ /^$h=/ and $hidden = 1;
                  }
                  unless (defined($alreadyCounted{$prop})){
                    defined $hidden or push @checkboxes, $prop;
                    $alreadyCounted{$prop}= 1;
                  }
          }
    }
  
  }
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

