## Created on November 2007 by Joseph.Emeras@imag.fr

package OAR::Monika::db_io;
use DBI;
use strict;
use Data::Dumper;
use warnings;
use Time::Local;
use POSIX qw(strftime);


my $nodes_synonym;

###########################################################################################
## Methods for Monika exclusively:                                                        #
###########################################################################################

# Creates a connection to the DB and returns it
sub dbConnection($$$$$){
    my $host = shift;
    my $port = shift;
    my $dbname = shift;
    my $user = shift;
    my $pwd = shift;
    
    $nodes_synonym = OAR::Monika::Conf::myself->nodes_synonym;
    my $connection_string;
    if($port eq "" || !($port>1 && $port<65535)){
    	$connection_string = "DBI:Pg:database=$dbname;host=$host";
    }
    else{
    	$connection_string = "DBI:Pg:database=$dbname;host=$host;port=$port";
    }
    my $dbh= DBI->connect($connection_string, $user, $pwd, {AutoCommit => 1, RaiseError => 1});
    return $dbh;
}
sub dbDisconnect($) {
    my $dbh = shift;

    # Disconnect from the database.
    $dbh->disconnect();
}

# get_properties_values
# returns the list of the fields of the job table and their values
# usefull for the 'properties' section in Monika 
# parameters : base, list of excluded fields
# return value : list of fields end values
# side effects : /
sub get_properties_values($$) {
    my $dbh = shift;
    my $excluded = shift;
    my @result;
    my $sth;
    #$sth = $dbh->prepare("SELECT a.attname
    #                         FROM pg_class AS c, pg_attribute AS a 
    #                         WHERE relname = 'resources' AND c.oid = a.attrelid AND a.attnum > 0;");
    $sth = $dbh->prepare("SELECT column_name FROM information_schema.columns WHERE table_name = \'resources\'");
    
    $sth->execute();
    while (my $ref = $sth->fetchrow_hashref()){
      my $current_value;
      $current_value = $ref->{'column_name'};
      unless (defined($excluded->{$current_value})){
        push(@result, $current_value);
      }
    }
    $sth->finish();
    
    my $str = "SELECT DISTINCT ";
    foreach(@result){
      $str = $str.$_.", ";
    }
    $str  = substr $str, 0, length($str) - 2;
    $str = $str." FROM resources;";
    my $sth2 = $dbh->prepare($str);
    $sth2->execute();
    my $ref;
    my $i = 0;
    while (my $current = $sth2->fetchrow_hashref()){
      $i++;
      $ref->{$i} = $current;
    }
    $sth2->finish();

    return $ref;
}

# get_all_resources_on_node
# returns the current resources on node whose hostname is passed in parameter
# parameters : base, hostname
# return value : weight
# side effects : /
my %Resources_on_nodes;
sub get_all_resources_on_node($$) {
    my $dbh = shift;
    my $hostname = shift;

    if (defined($Resources_on_nodes{$hostname})){
        return(@{$Resources_on_nodes{$hostname}});
    }else{
        my $sth = $dbh->prepare("   SELECT resources.resource_id as resource, resources.$nodes_synonym as node
                                    FROM resources
                            ");
        $sth->execute();
        my @result;
        while (my $ref = $sth->fetchrow_hashref()){
            push(@{$Resources_on_nodes{$ref->{node}}}, $ref->{resource});
        }
        $sth->finish();

        return(@{$Resources_on_nodes{$hostname}});
    }
}

# get_queued_jobs
# returns the list of queued jobs: running, waiting...
# parameters : base
# return value : list of jobid
# side effects : /
sub get_queued_jobs($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("   SELECT jobs.job_id
                                FROM (jobs INNER JOIN moldable_job_descriptions ON jobs.job_id = moldable_job_descriptions.moldable_job_id) LEFT JOIN assigned_resources ON assigned_resources.moldable_job_id = moldable_job_descriptions.moldable_job_id
                                WHERE
                                    jobs.state IN (\'Waiting\',\'Hold\',\'toLaunch\',\'toError\',\'toAckReservation\',\'Launching\',\'Running\',\'Suspended\',\'Resuming\')
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'job_id'});
    }
    return @res;
}

# get_job_stat_infos
# returns the information about the given job
# parameters : base, job_id
# return value : list of information
# side effects : /
my %Job_stat_infos;
sub get_job_stat_infos($$) {
    my $dbh = shift;
    my $job= shift;

    if (defined($Job_stat_infos{$job})){
        return($Job_stat_infos{$job});
    }else{
        my $sth = $dbh->prepare("   SELECT *
                                    FROM jobs
                                    WHERE
                                        jobs.job_id = $job
                                ");
        $sth->execute();
        my $ref = $sth->fetchrow_hashref();
        $sth->finish();
        $Job_stat_infos{$job} = $ref;

        return $ref;
    }
}

# get_job_cores
# returns the list of cores used by the given job
# parameters : base, job
# return value : list of cores ressources
# side effects : /
#sub get_job_cores($$) {
#    my $dbh = shift;
#    my $job = shift;
#    my $sth = $dbh->prepare("   SELECT resources.resource_id
#                                FROM ((jobs INNER JOIN moldable_job_descriptions ON moldable_job_descriptions.moldable_job_id = jobs.job_id) LEFT JOIN assigned_resources ON assigned_resources.moldable_job_id = moldable_job_descriptions.moldable_id) INNER JOIN resources ON assigned_resources.resource_id = resources.resource_id
#                                WHERE
#                                    assigned_resources.assigned_resource_index = \'CURRENT\'
#                                    AND moldable_job_descriptions.moldable_index = \'CURRENT\'
#                                    AND jobs.job_id = $job
#                                    AND jobs.state != \'Terminated\'
#                                    AND jobs.state != \'Error\'
#                            ");
#    $sth->execute();
#    my @res = ();
#    while (my $ref = $sth->fetchrow_hashref()) {
#        push(@res, $ref->{'resource_id'});
#    }
#    return @res;
#}

###########################################################################################
## Methods from the OAR IOLIB:                                                            #
###########################################################################################

# get_resource_job
# returns the list of jobs associated to the resource passed in parameter
# parameters : base, resource
# return value : list of jobid
# side effects : /
my %Resource_job;
my $Resource_job_init = 0;
sub get_resource_job($$) {
    my $dbh = shift;
    my $resource = shift;

    if ($Resource_job_init > 0){
        if (defined($Resource_job{$resource})){
            return(@{$Resource_job{$resource}});
        }else{
            return(());
        }
    }else{
        my $sth = $dbh->prepare("   SELECT assigned_resources.resource_id, jobs.job_id
                                    FROM assigned_resources, moldable_job_descriptions, jobs
                                    WHERE
                                        assigned_resources.assigned_resource_index = \'CURRENT\'
                                        AND moldable_job_descriptions.moldable_index = \'CURRENT\'
                                        AND assigned_resources.moldable_job_id = moldable_job_descriptions.moldable_id
                                        AND moldable_job_descriptions.moldable_job_id = jobs.job_id
                                        AND jobs.state != \'Terminated\'
                                        AND jobs.state != \'Error\'
                            ");
        $sth->execute();
        my @res = ();
        $Resource_job_init++;
        while (my $ref = $sth->fetchrow_hashref()) {
            push(@{$Resource_job{$ref->{'resource_id'}}}, $ref->{'job_id'});
        }
        if (defined($Resource_job{$resource})){
            return(@{$Resource_job{$resource}});
        }else{
            return(());
        }
    }
}

# list_nodes
# gets the list of all nodes.
# parameters : base
# return value : list of hostnames
# side effects : /
sub list_nodes($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("   SELECT distinct($nodes_synonym)
                                FROM resources
                                ORDER BY $nodes_synonym ASC
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{$nodes_synonym});
    }
    $sth->finish();
    return(@res);
}

# get_resource_info
# returns a ref to some hash containing data for the nodes of the resource passed in parameter
# parameters : base, resource id
# return value : ref
# side effects : /
my %Resource_info;
sub get_resource_info($$) {
    my $dbh = shift;
    my $resource = shift;

    if (defined($Resource_info{$resource})){
        return($Resource_info{$resource});
    }else{
        my $sth = $dbh->prepare("   SELECT *
                                    FROM resources
                            ");
        $sth->execute();
        while (my $ref = $sth->fetchrow_hashref()) {
            $Resource_info{$ref->{resource_id}} = $ref;
        }
        $sth->finish();
        return($Resource_info{$resource});
    }
}

# Get start_time for a given job
# args : base, job id
my %Gantt_job_start_time;
my $Gantt_job_start_time_init = 0;
sub get_gantt_job_start_time($$){
    my $dbh = shift;
    my $job = shift;

    if ($Gantt_job_start_time_init > 0){
        if (defined($Gantt_job_start_time{$job})){
            return($Gantt_job_start_time{$job},$job);
        }else{
            return(undef);
        }
    }else{
        $Gantt_job_start_time_init = 1;
        my $sth = $dbh->prepare("SELECT gantt_jobs_predictions_visu.start_time, moldable_job_descriptions.moldable_job_id
                                 FROM gantt_jobs_predictions_visu,moldable_job_descriptions
                                 WHERE
                                     moldable_job_descriptions.moldable_index = \'CURRENT\'
                                     AND moldable_job_descriptions.moldable_id = gantt_jobs_predictions_visu.moldable_job_id
                                 GROUP BY gantt_jobs_predictions_visu.start_time, moldable_job_descriptions.moldable_job_id
                                ");
        $sth->execute();
        while (my @res = $sth->fetchrow_array()){
            $Gantt_job_start_time{$res[1]} = $res[0];
        }
        $sth->finish();
    
        if (defined($Gantt_job_start_time{$job})){
            return($Gantt_job_start_time{$job},$job);
        }else{
            return(undef);
        }
    }
}

# local_to_sql
# converts a date specified in an integer local time format to the format used
# by the sql database
# parameters : date integer
# return value : date string
# side effects : /
sub local_to_sql($) {
    my $local=shift;
    #my ($year,$mon,$mday,$hour,$min,$sec)=local_to_ymdhms($local);
    #return ymdhms_to_sql($year,$mon,$mday,$hour,$min,$sec);
    #return $year."-".$mon."-".$mday." $hour:$min:$sec";
    return(strftime("%F %T",localtime($local)));
}

# Return a data structure with the resource description of the given job
# arg : database ref, job id
# return a data structure (an array of moldable jobs):
# example for the first moldable job of the list:
# $result = [
#               [
#                   {
#                       property  => SQL property
#                       resources => [
#                                       {
#                                           resource => resource name
#                                           value    => number of this wanted resource
#                                       }
#                                    ]
#                   }
#               ],
#               walltime,
#               moldable_id
#           ]
my %Resources_data_structure_current_job;
sub get_resources_data_structure_current_job($$){
    my $dbh = shift;
    my $job_id = shift;

#    my $sth = $dbh->prepare("   SELECT moldable_job_descriptions.moldable_id, job_resource_groups.res_group_id, moldable_job_descriptions.moldable_walltime, job_resource_groups.res_group_property, job_resource_descriptions.res_job_resource_type, job_resource_descriptions.res_job_value
#                                FROM moldable_job_descriptions, job_resource_groups, job_resource_descriptions, jobs
#                                WHERE
#                                    moldable_job_descriptions.moldable_index = \'CURRENT\'
#                                    AND job_resource_groups.res_group_index = \'CURRENT\'
#                                    AND job_resource_descriptions.res_job_index = \'CURRENT\'
#                                    AND jobs.job_id = $job_id
#                                    AND jobs.job_id = moldable_job_descriptions.moldable_job_id
#                                    AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id
#                                    AND job_resource_descriptions.res_job_group_id = job_resource_groups.res_group_id
#                                ORDER BY moldable_job_descriptions.moldable_id, job_resource_groups.res_group_id, job_resource_descriptions.res_job_order ASC
#                            ");

    if (defined($Resources_data_structure_current_job{$job_id})){
        return($Resources_data_structure_current_job{$job_id});
    }else{
        my $sth = $dbh->prepare("   SELECT moldable_job_descriptions.moldable_id, job_resource_groups.res_group_id, moldable_job_descriptions.moldable_walltime, job_resource_groups.res_group_property, job_resource_descriptions.res_job_resource_type, job_resource_descriptions.res_job_value
                                    FROM moldable_job_descriptions, job_resource_groups, job_resource_descriptions, jobs
                                    WHERE
                                        jobs.job_id = $job_id
                                        AND jobs.job_id = moldable_job_descriptions.moldable_job_id
                                        AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id
                                        AND job_resource_descriptions.res_job_group_id = job_resource_groups.res_group_id
                                    ORDER BY moldable_job_descriptions.moldable_id, job_resource_groups.res_group_id, job_resource_descriptions.res_job_order ASC
                                ");
        $sth->execute();
        my $result;
        my $group_index = -1;
        my $moldable_index = -1;
        my $previous_group = 0;
        my $previous_moldable = 0;
        while (my @ref = $sth->fetchrow_array()){
            if ($previous_moldable != $ref[0]){
                $moldable_index++;
                $previous_moldable = $ref[0];
                $group_index = 0;
                $previous_group = $ref[1];
            }elsif ($previous_group != $ref[1]){
                $group_index++;
                $previous_group = $ref[1];
            }
            # Store walltime
            $result->[$moldable_index]->[1] = $ref[2];
            $result->[$moldable_index]->[2] = $ref[0];
            #Store properties group
            $result->[$moldable_index]->[0]->[$group_index]->{property} = $ref[3];
            my %tmp_hash =  (
                    resource    => $ref[4],
                    value       => $ref[5]
                            );
            push(@{$result->[$moldable_index]->[0]->[$group_index]->{resources}}, \%tmp_hash);
    
        }
        $sth->finish();
        $Resources_data_structure_current_job{$job_id} = $result;
    
        return($result);
    }
}

return 1;
