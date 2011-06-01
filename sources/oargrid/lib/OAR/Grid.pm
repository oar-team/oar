package oargrid_lib;

use DBI;
use Data::Dumper;
use strict;
use warnings;
use IPC::Open3;
use oargrid_mailer;
use oargrid_conflib;


my $commandTimeout = 60;
my $configFileName = "oargrid.conf";
my $Version = "2.2.4";

sub get_config_file_name(){
    return($configFileName);
}

sub get_version(){
    return($Version);
}

sub get_command_timeout(){
    OAR::Grid::Conf::init_conf(get_config_file_name());
    if (OAR::Grid::Conf::is_conf("SSH_TIMEOUT")){
        $commandTimeout = OAR::Grid::Conf::get_conf("SSH_TIMEOUT");
    }
    
    return($commandTimeout);
}


# Connect to the mysql database and give the ref of this connection
# arg1 : hostname of the database
# arg2 : name of the database
# arg3 : username to connect to the database
# arg4 : password for this user
# return : ref of the connection 
sub connect($$$$) {
    # Connect to the database.
    my $host = shift;
    my $dbName = shift;
    my $user = shift;
    my $pwd = shift;

    my $dbh = DBI->connect("DBI:mysql:database=$dbName;host=$host", $user, $pwd,
                            {'RaiseError' => 1,'InactiveDestroy' => 1}
                          ) or die("Can not connet to the database $dbName on the host $host with login $user\n");
    return $dbh;
}


# Disconnect from a database
# arg1 : ref of the database
sub disconnect($) {
    my $dbh = shift;

    $dbh->disconnect();
}



#Get current MySQL date
sub get_date($){
    my $dbh = shift;
    
    my $sth = $dbh->prepare("SELECT NOW()");
    $sth->execute();
    my @ref = $sth->fetchrow_array();
    $sth->finish();
    
    return($ref[0]);
}



# Add a new grid reservation in the database with associated cluster batch id.
# arg1 : base ref
# arg2 : user name
# arg3 : command string
# arg4 : ref of hash table with all cluster names with their batch id
sub add_new_grid_reservation($$$$$$$$){
    my $dbh = shift;
    my $user = shift;
    my $directory = shift;
    my $startDate = shift;
    my $walltime = shift;
    my $program = shift;
    my $cmdString = shift;
    my $clusterBatchIdRef = shift;
    
    $dbh->do("LOCK TABLE reservations WRITE");
    
    my $rw = $dbh->do("INSERT INTO reservations (reservationId,reservationUser,reservationDirectory,reservationStartDate,reservationWallTime,reservationProgram,reservationCommandLine,reservationSubmissionDate)
                       VALUES (NULL,\"$user\",\"$directory\",\"$startDate\",\"$walltime\",\"$program\",\"$cmdString\",NOW())
                      ");
    if ($rw != 1) {
        return(-1);
    }
    my $sth = $dbh->prepare("SELECT LAST_INSERT_ID()");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my @tmp = values(%$ref);
    my $id = $tmp[0];
    $sth->finish();

    $dbh->do("UNLOCK TABLES");
    
    foreach my $i (keys(%{$clusterBatchIdRef})){
        foreach my $j (@{$clusterBatchIdRef->{$i}}){
            $dbh->do("INSERT INTO clusterJobs (clusterJobsReservationId,clusterJobsClusterName,clusterJobsBatchId,clusterJobsNbNodes,clusterJobsWeight,clusterJobsProperties,clusterJobsQueue,clusterJobsEnvironment,clusterJobsPartition,clusterJobsName,clusterJobsResources)
                      VALUES ($id,\"$i\",$j->{batchId},$j->{nbNodes},$j->{weight},\"$j->{properties}\",\"$j->{queue}\",\"$j->{env}\",\"$j->{part}\",\"$j->{name}\",\"$j->{rdef}\")
                     ");
        }
    }

    return($id);
}


# get the list of known cluster names
# arg1 : base ref
# return : an hash table of cluster names
sub get_cluster_names($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT * FROM clusters order by parent,clusterName");
    $sth->execute();
    my %res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        $res{$ref->{clusterName}} = {
            "hostname" => $ref->{clusterHostname},
            "dbHostname" => $ref->{clusterDBHostname},
            "dbUser" => $ref->{clusterDBUser},
            "dbPassword" => $ref->{clusterDBPassword},
            "dbName" => $ref->{clusterOARDBName},
            "properties" => $ref->{clusterProperties},
            "parent" => $ref->{parent},
            "deprecated" => $ref->{deprecated}
        };
    }
    return(%res);
}

# get the list of known cluster names, but only those
# who are not parents (only aliases)
# arg1 : base ref
# return : an hash table of cluster names
sub get_cluster_aliases($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT * FROM clusters where parent is not null and deprecated is not true order by parent,clusterHostname");
    $sth->execute();
    my %res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        $res{$ref->{clusterName}} = {
            "hostname" => $ref->{clusterHostname},
            "dbHostname" => $ref->{clusterDBHostname},
            "dbUser" => $ref->{clusterDBUser},
            "dbPassword" => $ref->{clusterDBPassword},
            "dbName" => $ref->{clusterOARDBName},
            "properties" => $ref->{clusterProperties},
            "parent" => $ref->{parent},
            "deprecated" => $ref->{deprecated}
        };
    }
    return(%res);
}

# get the list of known cluster names (aliases) 
# arg1 : base ref
# return : an hash table of cluster names with ateway, properties and parent data

sub get_all_cluster_aliases($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT * FROM clusters");
    $sth->execute();
    my %res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        $res{$ref->{clusterName}} = {
            "gateway" => $ref->{clusterHostname},
            "properties" => $ref->{clusterProperties},
            "parent" => $ref->{parent},
        };
    }
    return(%res);
}

# get the properties of the given cluster alias
# arg1 : base ref
# arg2 : cluster alias
sub get_cluster_alias_properties($$){
  my $dbh = shift;
  my $alias = shift;
  my $sth = $dbh->prepare("SELECT clusterProperties FROM clusters where clusterName=\"$alias\"");
  $sth->execute();
  my $ref = $sth->fetchrow_hashref();
  my @tmp = values(%$ref);
  return $tmp[0];
}


# get the list of cluster properties
# arg1 : base ref
# return : an hash table of cluster properties
sub get_cluster_properties($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT clusterProperties.clusterName,site,architecture,resourceUnit,clusterHostname
                              FROM clusterProperties,clusters
                              WHERE clusterProperties.clusterName=clusters.clusterName order by parent,clusterProperties.clusterName;");
    $sth->execute();
    my %res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        foreach my $p (keys(%{$ref})){
            if ($p ne "clusterName"){
                $res{$ref->{clusterName}}{$p} = $ref->{$p};
            }
        }
    }
    return(%res);
}


# Get a hashtable with several reservation informations
# arg1 : base ref
# arg2 : reservation number
sub get_reservation_informations($$){
    my $dbh = shift;
    my $resa = shift;
    my $sth = $dbh->prepare("SELECT * FROM reservations, clusterJobs
                             WHERE  reservationId = $resa
                                AND clusterJobsReservationId = $resa");
    $sth->execute();
    my %res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        $res{reservationCommandLine}= $ref->{reservationCommandLine} ;
        $res{reservationUser}= $ref->{reservationUser} ;
        $res{reservationWallTime}= $ref->{reservationWallTime} ;
        $res{reservationStartDate}= $ref->{reservationStartDate} ;
        $res{reservationProgram}= $ref->{reservationProgram} ;
        $res{reservationDirectory}= $ref->{reservationDirectory} ;
        $res{reservationSubmissionDate}= $ref->{reservationSubmissionDate} ;
        if (! defined($res{clusterJobs})){
            my %clust = ();
            $res{clusterJobs} = \%clust;
        }
        #push(@{$res{clusterJobs}->{$ref->{clusterJobsClusterName}}}, { 
        #                                                               "batchId" => $ref->{clusterJobsBatchId},
        #                                                               "nodes" => $ref->{clusterJobsNbNodes},
        #                                                               "weight" => $ref->{clusterJobsWeight},
        #                                                               "properties" => $ref->{clusterJobsProperties},
        #                                                               "queue" => $ref->{clusterJobsQueue},
        #                                                               "name" => $ref->{clusterJobsName},
        #                                                               "env" => $ref->{clusterJobsEnvironment},
        #                                                               "part" => $ref->{clusterJobsPartition}
        #                                                             });
        if (! defined($ref->{clusterJobsResources})) {$ref->{clusterJobsResources}=""};
        $res{clusterJobs}->{$ref->{clusterJobsClusterName}}->{$ref->{clusterJobsBatchId}} = { 
                                                                       "batchId" => $ref->{clusterJobsBatchId},
                                                                       "rdef" => $ref->{clusterJobsResources},
                                                                       "nodes" => $ref->{clusterJobsNbNodes},
                                                                       "weight" => $ref->{clusterJobsWeight},
                                                                       "properties" => $ref->{clusterJobsProperties},
                                                                       "queue" => $ref->{clusterJobsQueue},
                                                                       "name" => $ref->{clusterJobsName},
                                                                       "env" => $ref->{clusterJobsEnvironment},
                                                                       "part" => $ref->{clusterJobsPartition}
                                                                     };
    }
    return(%res);
}


# Get a hashtable with several user informations
# arg1 : base ref
# arg2 : user name
sub get_user_informations($$){
    my $dbh = shift;
    my $user = shift;

    my $sth = $dbh->prepare("SELECT * FROM reservations, clusterJobs
                             WHERE
                                reservationUser = \"$user\"
                                AND clusterJobsReservationId = reservationId
                                AND UNIX_TIMESTAMP(reservationStartDate) + TIME_TO_SEC(reservationWallTime) >= UNIX_TIMESTAMP()
				AND (clusterJobsStatus != 'TERMINATED' OR clusterJobsStatus is null)
                             ORDER BY reservationID");
    $sth->execute();
    my %res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        my $resId = $ref->{reservationId};
        if (! defined($res{$resId})){
            my %clust = ();
            $res{$resId} = \%clust;
        }
        
        $res{$resId}->{reservationCommandLine}= $ref->{reservationCommandLine} ;
        $res{$resId}->{reservationUser}= $ref->{reservationUser} ;
        $res{$resId}->{reservationWallTime}= $ref->{reservationWallTime} ;
        $res{$resId}->{reservationStartDate}= $ref->{reservationStartDate} ;
        $res{$resId}->{reservationProgram}= $ref->{reservationProgram} ;
        $res{$resId}->{reservationDirectory}= $ref->{reservationDirectory} ;
        $res{$resId}->{reservationSubmissionDate}= $ref->{reservationSubmissionDate} ;
        if (! defined($res{$resId}->{clusterJobs})){
            my %clust = ();
            $res{$resId}->{clusterJobs} = \%clust;
        }
        #push(@{$res{$resId}->{clusterJobs}->{$ref->{clusterJobsClusterName}}}, { 
        #                                                                        "batchId" => $ref->{clusterJobsBatchId},
        #                                                                        "nodes" => $ref->{clusterJobsNbNodes},
        #                                                                        "weight" => $ref->{clusterJobsWeight},
        #                                                                        "properties" => $ref->{clusterJobsProperties},
        #                                                                        "queue" => $ref->{clusterJobsQueue},
        #                                                                        "name" => $ref->{clusterJobsName},
        #                                                                        "env" => $ref->{clusterJobsEnvironment},
        #                                                                        "part" => $ref->{clusterJobsPartition}
        #                                                                       });
        if (! defined($ref->{clusterJobsStatus})) {$ref->{clusterJobsStatus}=""};
        if (! defined($ref->{clusterJobsResources})) {$ref->{clusterJobsResources}=""};
        $res{$resId}->{clusterJobs}->{$ref->{clusterJobsClusterName}}->{$ref->{clusterJobsBatchId}} = { 
                                                                                "batchId" => $ref->{clusterJobsBatchId},
                                                                                "rdef" => $ref->{clusterJobsResources},
                                                                                "nodes" => $ref->{clusterJobsNbNodes},
                                                                                "weight" => $ref->{clusterJobsWeight},
                                                                                "properties" => $ref->{clusterJobsProperties},
                                                                                "queue" => $ref->{clusterJobsQueue},
                                                                                "name" => $ref->{clusterJobsName},
                                                                                "env" => $ref->{clusterJobsEnvironment},
                                                                                "part" => $ref->{clusterJobsPartition},
                                                                                "status" => $ref->{clusterJobsStatus}
                                                                               };
    }
    return(%res);
}


# Get an unique cpuset id
# arg1 : base ref
sub get_unique_cpuset_id($){
    my $dbh = shift;

    $dbh->do("LOCK TABLE cpusetPool WRITE");
    my $sth = $dbh->prepare("   SELECT name
                                FROM cpusetPool
                                LIMIT 1
                            ");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    $sth->finish();
    my $res = $ref->{name};
    $res = $res + 1;
    $dbh->do("UPDATE cpusetPool SET name = $res");
    $dbh->do("UNLOCK TABLES");
    return($res);
}


# launch a command and keep stdout and stderr in memory
# arg1 : cmd string
# arg2 : timeout of the command
# return : a hash table with stdout, stderr and status of the command 
# for status : 
#   exit_value  = $status >> 8;
#   signal_num  = $status & 127;
#   dumped_core = $status & 128;
#
#   if status is undefined then the command timed out
sub launch_command_with_timeout($$){
    my $cmd = shift;
    my $timeout = shift;

    my $stdoutStr = "";
    my $stderrStr = "";
    my $endCode;

    eval {
        $SIG{ALRM} = sub { die "alarm\n" };
        alarm($timeout);
        
        my $pid = open3(\*WRITER, \*READER, \*ERROR, $cmd); 
        my $r;
        my $e;
        while (defined($r = <READER>) || defined($e = <ERROR>)){
            if ($r){
                $stdoutStr .= $r;
            }elsif ($e){
                $stderrStr .= $e;
            }else{
                print("[oargrid_lib] Programmation error in launch_command_with_timeout : contact the developer\n");
            }
        }
        close(WRITER);
        close(READER);
        close(ERROR);
    
        waitpid($pid,0);
        $endCode = $?;
        
        alarm(0);
    };

    if ($@){
        undef($endCode);
    }
    
    my %result = ( "stdout" => $stdoutStr,
                   "stderr" => $stderrStr,
                   "status" => $endCode
                  );
    
    return(%result);
}

# Give the command line to delete a job
# arg1 : cluster name
# arg2 : user
# arg3 : job batch id
sub get_oardel_command($$$){
    my $cluster = shift;
    my $user = shift;
    my $jobId = shift;

    return("ssh $cluster \"/bin/bash -c \\\"sudo -u $user oardel $jobId\\\"\"");
}


# Get mail parameters and send one if all is ok
# arg1 : object
# arg2 : core message
sub mail_notify($$){
    my $object = shift;
    my $message = shift;

    OAR::Grid::Conf::init_conf(get_config_file_name());
    if (OAR::Grid::Conf::is_conf("MAIL_SMTP_SERVER") && OAR::Grid::Conf::is_conf("MAIL_RECIPIENT") && OAR::Grid::Conf::is_conf("MAIL_SENDER")){
        mailer::sendMail(OAR::Grid::Conf::get_conf("MAIL_SMTP_SERVER"),OAR::Grid::Conf::get_conf("MAIL_SENDER"),OAR::Grid::Conf::get_conf("MAIL_RECIPIENT"),$object,$message);
   }
}

# Mark a job as terminated
# arg1 : base ref
# arg2 : cluster
# arg3 : batchid
sub mark_job_as_terminated($$$){
    my $dbh = shift;
    my $clusterJobsClusterName=shift;
    my $clusterJobsBatchId=shift;

    $dbh->do("LOCK TABLE clusterJobs WRITE");
    $dbh->do("UPDATE clusterJobs SET clusterJobsStatus = 'TERMINATED' 
                WHERE clusterJobsClusterName='$clusterJobsClusterName'
                AND clusterJobsBatchId='$clusterJobsBatchId'");
    $dbh->do("UNLOCK TABLES");
}

# Print the aliases hierarchy
sub print_aliases_hierarchy($) {
    my $dbh = shift;
    my %clusters = get_cluster_names($dbh);
    my %aliases;
    my @roots;
    foreach my $i (keys(%clusters)){
        if (defined($clusters{$i}{parent})) {
            push(@{$aliases{$clusters{$i}{parent}}},$i);
        }else {
            push(@roots,$i);
        }
        #print("\t$i --> $clusters{$i}{hostname}\n");
    }
    foreach my $root (sort(@roots)) {
        print("\t$root --> $clusters{$root}{hostname}");
        print " *DEPRECATED*" if (defined($clusters{$root}{deprecated}));
        print "\n";
        foreach my $alias (@{$aliases{$root}}) {
            print "\t   $alias ";
            print "($clusters{$alias}{properties})" if (defined($clusters{$alias}{properties}));
            print " *DEPRECATED*" if (defined($clusters{$alias}{deprecated}));
            print "\n";
        }
    }
}


return 1;
