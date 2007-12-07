## Created on November 2007 by Joseph.Emeras@imag.fr

package monika::db_io;
use DBI;
use strict;
use Data::Dumper;
use warnings;
use Time::Local;
use POSIX qw(strftime);

###########################################################################################
## Methods for Monika exclusively:                                                        #
###########################################################################################

# Creates a connection to the DB and returns it
sub dbConnection($$$$$){
    #my $this= shift;
    my $host = shift;
    my $dbtype = shift;
    my $dbname = shift;
    my $user = shift;
    my $pwd = shift;
    my $dbh= DBI->connect("DBI:$dbtype:database=$dbname;host=$host", $user, $pwd, {AutoCommit => 1, RaiseError => 1});
    return $dbh;
}


# get_all_resources_on_node
# returns the current resources on node whose hostname is passed in parameter
# parameters : base, hostname
# return value : weight
# side effects : /
sub get_all_resources_on_node($$) {
    my $dbh = shift;
    my $hostname = shift;

    #my $sth = $dbh->prepare("   SELECT resources.resource_id as resource
    #                            FROM assigned_resources, resources
    #                            WHERE
    #                                assigned_resources.assigned_resource_index = \'CURRENT\'
    #                                AND resources.network_address = \'$hostname\'
    #                                AND resources.resource_id = assigned_resources.resource_id
    #                        ");

    my $sth = $dbh->prepare("   SELECT resources.resource_id as resource
                                FROM resources
                                WHERE
                                    resources.network_address = \'$hostname\'
                            ");
    $sth->execute();
    my @result;
    while (my $ref = $sth->fetchrow_hashref()){
        push(@result, $ref->{resource});
    }
    $sth->finish();

    return @result;
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
                                    jobs.state != \'Terminated\'
                                    AND jobs.state != \'Error\'
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
sub get_job_stat_infos($$) {
    my $dbh = shift;
    my $job= shift;
    my $sth = $dbh->prepare("   SELECT *
                                FROM jobs
                                WHERE
                                    jobs.job_id = $job
                            ");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    return $ref;
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
sub get_resource_job($$) {
    my $dbh = shift;
    my $resource = shift;
    my $sth = $dbh->prepare("   SELECT jobs.job_id
                                FROM assigned_resources, moldable_job_descriptions, jobs
                                WHERE
                                    assigned_resources.assigned_resource_index = \'CURRENT\'
                                    AND moldable_job_descriptions.moldable_index = \'CURRENT\'
                                    AND assigned_resources.resource_id = $resource
                                    AND assigned_resources.moldable_job_id = moldable_job_descriptions.moldable_id
                                    AND moldable_job_descriptions.moldable_job_id = jobs.job_id
                                    AND jobs.state != \'Terminated\'
                                    AND jobs.state != \'Error\'
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'job_id'});
    }
    return @res;
}

# list_nodes
# gets the list of all nodes.
# parameters : base
# return value : list of hostnames
# side effects : /
sub list_nodes($) {
    my $dbh = shift;

    #my $sth = $dbh->prepare("   SELECT distinct(network_address), resource_id
    #                            FROM resources
    #                            ORDER BY resource_id ASC");
    my $sth = $dbh->prepare("   SELECT distinct(network_address)
                                FROM resources
                                ORDER BY network_address ASC
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'network_address'});
    }
    $sth->finish();
    return(@res);
}

# get_resource_info
# returns a ref to some hash containing data for the nodes of the resource passed in parameter
# parameters : base, resource id
# return value : ref
# side effects : /
sub get_resource_info($$) {
    my $dbh = shift;
    my $resource = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM resources
                                WHERE
                                    resource_id = $resource
                            ");
    $sth->execute();

    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    return $ref;
}

# Get start_time for a given job
# args : base, job id
sub get_gantt_job_start_time($$){
    my $dbh = shift;
    my $job = shift;

    my $sth = $dbh->prepare("SELECT gantt_jobs_predictions.start_time, gantt_jobs_predictions.moldable_job_id
                             FROM gantt_jobs_predictions,moldable_job_descriptions
                             WHERE
                                moldable_job_descriptions.moldable_job_id = $job
                                AND gantt_jobs_predictions.moldable_job_id = moldable_job_descriptions.moldable_id
                            ");
    $sth->execute();
    my @res = $sth->fetchrow_array();
    $sth->finish();
    
    if (defined($res[0])){
        return($res[0],$res[1]);
    }else{
        return(undef);
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

    return($result);
}

return 1;
