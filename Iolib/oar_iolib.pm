# This is the iolib, which manages the layer between the modules and the
# database. This is the only base-dependent layer.
# When adding a new function, the following comments are required before the code of the function:
# - the name of the function
# - a short description of the function
# - the list of the parameters it expect
# - the list of the return values
# - the list of the side effects

# $Id: oar_iolib.pm,v 1.93 2005/10/26 12:32:21 capitn Exp $
package iolib;
require Exporter;

use DBI;
use oar_conflib qw(init_conf get_conf is_conf);
use Data::Dumper;
use Time::Local;
use oar_Judas qw(oar_debug oar_warn oar_error);
use strict;
use oar_resource_tree;

# PROTOTYPES

# CONNECTION
sub connect();
sub connect_ro();
sub disconnect($);

# JOBS MANAGEMENT
sub get_job_bpid($$);
sub get_job_challenge($$);
sub set_job_bpid($$$);
sub get_jobs_in_state($$);
sub is_job_desktopComputing($$);
sub get_job_current_hostnames($$);
sub get_job_current_resources($$);
sub get_job_host_log($$);
sub get_tokill_job($);
sub is_tokill_job($$);
sub get_timered_job($);
sub get_toexterminate_job($);
sub get_frag_date($$);
sub set_running_date($$);
sub set_running_date_arbitrary($$$);
sub set_assigned_moldable_job($$$);
sub set_finish_date($$);
sub form_job_properties($$);
sub get_possible_wanted_resources($$$$$);
sub add_micheline_job($$$$$$$$$$$$$$$$);
sub get_oldest_waiting_idjob($);
sub get_oldest_waiting_idjob_by_queue($$);
sub get_job($$);
sub get_current_moldable_job($$);
sub set_job_state($$$);
sub set_job_resa_state($$$);
sub set_job_message($$$);
sub set_job_autoCheckpointed($$);
sub frag_job($$);
sub ask_checkpoint_job($$);
sub hold_job($$);
sub resume_job($$);
sub job_fragged($$);
sub job_arm_leon_timer($$);
sub job_refrag($$);
sub job_leon_exterminate($$);
sub list_current_jobs($);
sub get_waiting_reservation_jobs($);
sub get_waiting_reservation_jobs_specific_queue($$);
sub get_waiting_toSchedule_reservation_jobs_specific_queue($$);
sub get_waiting_jobs_specific_queue($$);
sub get_jobs_range_dates($$$);
sub get_jobs_gantt_scheduled($$$);
sub get_desktop_computing_host_jobs($$);
sub get_stagein_id($$);
sub set_stagein($$$$$$);
sub get_job_stagein($$);
sub is_stagein_deprecated($$$);
sub del_stagein($$);
sub get_jobs_to_schedule($$);
sub get_current_job_types($$);

# PROCESSJOBS MANAGEMENT (Resource assignment to jobs)
sub remove_current_assigned_resources($$);
sub get_resource_job($$);
sub get_node_job($$);
sub get_resources_in_state($$);
sub get_running_host($);
sub add_resource_job_pair($$$);
sub remove_node_job_pair($$$);

# RESOURCES MANAGEMENT
sub add_resource($$$);
sub get_maxweight_node($);
sub get_free_nodes_job($$$);
sub get_free_nodes_job_killer($$$$);
sub get_free_shareable_nodes($);
sub get_free_shareable_nodes_job($$$);
sub get_free_exclusive_nodes($);
sub get_free_exclusive_nodes_job($$$);
sub get_free_exclusive_nodes_job_nbmin($$$$);
sub get_alive_node_job($$$);
sub get_really_alive_node_job($$$);
sub get_number_Alive_state_nodes($);
sub get_alive_node($);
sub get_really_alive_node($);
sub get_suspected_node($);
sub list_nodes($);
sub get_resource_info($$);
sub is_node_exists($$);
sub get_resources_on_node($$);
sub set_weight_node($$$);
sub decrease_weight($$);
sub set_node_state($$$$);
sub update_resource_nextFinaudDecision($$$);
sub get_all_node_properties($$);
sub get_all_nodes_properties($);
sub get_resources_change_state($);
sub set_resource_nextState($$$);
sub set_node_nextState($$$);
sub set_node_expiryDate($$$);
sub set_node_property($$$$);
sub set_resource_property($$$$);
sub get_maxweight_one_node($$);
sub get_node_dead_range_date($$$);
sub get_expired_nodes($);
sub is_node_desktop_computing($$);
sub get_node_stats($);
sub order_property_node($$$);
sub get_resources_data_structure_current_job($$);

# QUEUES MANAGEMENT
sub get_active_queues($);
sub get_all_queue_informations($);

# GANTT MANAGEMENT
sub get_gantt_scheduled_jobs($);
sub get_gantt_visu_scheduled_jobs($);
sub add_gantt_scheduled_jobs($$$$);
sub gantt_flush_tables($);
sub set_gantt_date($$);
sub get_gantt_date($);
sub get_gantt_visu_date($);
sub get_gantt_jobs_to_launch($$);
sub get_gantt_resources_for_jobs_to_launch($$);
sub get_gantt_resources_for_job($$);
sub set_gantt_job_startTime($$$);
sub update_gantt_visualization($);

# TIME CONVERSION
sub ymdhms_to_sql($$$$$$);
sub sql_to_ymdhms($);
sub ymdhms_to_local($$$$$$);
sub local_to_ymdhms($);
sub sql_to_local($);
sub local_to_sql($);
sub sql_to_hms($);
sub hms_to_duration($$$);
sub hms_to_sql($$$);
sub duration_to_hms($);
sub duration_to_sql($);
sub sql_to_duration($);
sub get_date($);
sub get_unix_timestamp($);

#EVENTS LOG MANAGEMENT
sub add_new_event($$$$);
sub add_new_event_with_host($$$$$);
sub check_event($$$);
sub get_to_check_events($);
sub get_hostname_event($$);
sub get_job_events($$);

# ACCOUNTING
sub check_accounting_update($$);
sub update_accounting($$$$$$$$$);

# LOCK FUNCTIONS:

sub get_lock($$$);
sub release_lock($$);

# END OF PROTOTYPES

my $besteffortQueueName = "besteffort";



# CONNECTION

# connect_db
# Connects to database and returns the base identifier
# return value : base
sub connect_db($$$$) {
    my $host = shift;
    my $name = shift;
    my $user = shift;
    my $pwd = shift;

    my $maxConnectTries = 5;
    my $nbConnectTry = 0;
    my $dbh = undef;
    while ((!defined($dbh)) && ($nbConnectTry < $maxConnectTries)){
        $dbh = DBI->connect("DBI:mysql:database=$name;host=$host", $user, $pwd, {'InactiveDestroy' => 1});
        
        if (!defined($dbh)){
            oar_error("[IOlib] Can not connect to database (host=$host, user=$user, database=$name) : $DBI::errstr\n");
            $nbConnectTry++;
            if ($nbConnectTry < $maxConnectTries){
                oar_warn("[IOlib] I will retry to connect to the database in ".2*$nbConnectTry."s\n");
                sleep(2*$nbConnectTry);
            }
        }
    }
    
    if (!defined($dbh)){
        oar_error("[IOlib] Max connection tries reached ($maxConnectTries).\n");
        exit(50);
    }else{
        return $dbh;
    }
}


# connect
# Connects to database and returns the base identifier
# parameters : /
# return value : base
# side effects : opens a connection to the base specified in ConfLib
sub connect() {
    # Connect to the database.
    init_conf("oar.conf");

    my $host = get_conf("DB_HOSTNAME");
    my $name = get_conf("DB_BASE_NAME");
    my $user = get_conf("DB_BASE_LOGIN");
    my $pwd = get_conf("DB_BASE_PASSWD");

    return(connect_db($host,$name,$user,$pwd));
}


# connect_ro
# Connects to database and returns the base identifier
# parameters : /
# return value : base
# side effects : opens a connection to the base specified in ConfLib
sub connect_ro() {
    # Connect to the database.
    init_conf("oar.conf");

    my $host = get_conf("DB_HOSTNAME");
    my $name = get_conf("DB_BASE_NAME");
    my $user = get_conf("DB_BASE_LOGIN_RO");
    $user = get_conf("DB_BASE_LOGIN") if (!defined($user));
    my $pwd = get_conf("DB_BASE_PASSWD_RO");
    $pwd = get_conf("DB_BASE_PASSWD") if (!defined($pwd));

    return(connect_db($host,$name,$user,$pwd));
}


# disconnect
# Disconnect from database
# parameters : base
# return value : /
# side effects : closes a previously opened connection to the specified base
sub disconnect($) {
    my $dbh = shift;

    # Disconnect from the database.
    $dbh->disconnect();
}



# JOBS MANAGEMENT

# get_job_bpid
# gets the bipbip pid of a OAR Job
# parameters : base, jobid
# return value : pid
# side effects : /
sub get_job_bpid($$){
    my $dbh = shift;
    my $jobid= shift;
    my $sth = $dbh->prepare("   SELECT bpid
                                FROM jobs
                                WHERE
                                    idJob = $jobid
                            ");
    $sth->execute();

    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    return($$ref{'bpid'});
}


# get_job_challenge
# gets the challenge string of a OAR Job
# parameters : base, jobid
# return value : challenge
# side effects : /
sub get_job_challenge($$){
    my $dbh = shift;
    my $jobid = shift;
    
    my $sth = $dbh->prepare("SELECT challenge
                             FROM challenges
                             WHERE
                                jobId = $jobid
                            ");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    return($$ref{challenge});
}


# set_job_bpid
# sets the bipbip pid of a OAR Job
# parameters : base, jobid, pid
# return value : /
# side effects : changes the bpid of the job in the base
sub set_job_bpid($$$){
    my $dbh = shift;
    my $idJob = shift;
    my $bipbippid= shift;

    $dbh->do("   UPDATE jobs
                 SET bpid = \"$bipbippid\"
                 WHERE
                     idJob =\"$idJob\"
             ");
}


# get_jobs_in_state
# returns the list of ids of jobs in the specified state
# parameters : base, job state
# return value : flatened list of (idJob, jobType, infoType) triples
# side effects : /
sub get_jobs_in_state($$) {
    my $dbh = shift;
    my $state = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM jobs
                                WHERE
                                    state=\"$state\"
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    return(@res);
}


# is_job_desktopComputing
# return true if the job will run on desktopComputing nodes
# parameters: base, jobid
# return value: boolean
# side effects: /
sub is_job_desktopComputing($$) {
    my $dbh = shift;
    my $jobid = shift;
    my $sth = $dbh->prepare("SELECT COUNT(desktopComputing) FROM processJobs, nodeProperties WHERE processJobs.idJob=$jobid AND nodeProperties.hostname=processJobs.hostname AND desktopComputing=\"YES\"");
    $sth->execute();
    my ($count) = $sth->fetchrow_array();
		return ($count > 0);
}

# get_job_current_hostnames
# returns the list of hosts associated to the job passed in parameter
# parameters : base, jobid
# return value : list of distinct hostnames
# side effects : /
sub get_job_current_hostnames($$) {
    my $dbh = shift;
    my $jobid= shift;

    my $sth = $dbh->prepare("SELECT resources.networkAddress hostname
                             FROM assignedResources, resources, moldableJobs_description
                             WHERE 
                                assignedResources.assignedResourceIndex = \"CURRENT\"
                                AND moldableJobs_description.moldableIndex = \"CURRENT\"
                                AND assignedResources.idResource = resources.resourceId
                                AND moldableJobs_description.moldableId = assignedResources.idMoldableJob
                                AND moldableJobs_description.moldableJobId = $jobid
                             ORDER BY resources.resourceId ASC");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{hostname});
    }
    return @res;
}


# get_job_current_resources
# returns the list of resources associated to the job passed in parameter
# parameters : base, jobid
# return value : list of resources
# side effects : /
sub get_job_current_resources($$) {
    my $dbh = shift;
    my $jobid= shift;

    my $sth = $dbh->prepare("SELECT idResource resource
                             FROM assignedResources
                             WHERE 
                                assignedResourceIndex = \"CURRENT\"
                                AND idMoldableJob = $jobid
                             ORDER BY idResource ASC");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{resource});
    }
    return @res;
}


# get_job_host_log
# returns the list of hosts associated to the moldable job passed in parameter
# parameters : base, moldablejobid
# return value : list of distinct hostnames
# side effects : /
sub get_job_host_log($$) {
    my $dbh = shift;
    my $moldablejobid = shift;
    
    my $sth = $dbh->prepare("   SELECT b.networkAddress
                                FROM assignedResources a, resources b
                                WHERE
                                    a.idMoldableJob = $moldablejobid
                                ORDER BY b.resourceId ASC
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{networkAddress});
    }
    return @res;
}


# is_tokill_job
# returns true if the job has its frag state to LEON
# parameters : base, jobid
# return value : boolean
# side effects : /
sub is_tokill_job($$) {
    my $dbh = shift;
    my $jobid = shift;
    my $sth = $dbh->prepare("SELECT fragIdJob FROM fragJobs
                             WHERE fragState = \"LEON\" AND fragIdJob = \"$jobid\"");
    $sth->execute();
    my @res = $sth->fetchrow_array();
		$sth->finish();
		return ($#res >= 0)
}

# get_tokill_job
# returns the list of jobs that have their frag state to LEON
# parameters : base
# return value : list of jobid
# side effects : /
sub get_tokill_job($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT fragIdJob
                             FROM fragJobs
                             WHERE
                                fragState = \"LEON\"
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'fragIdJob'});
    }
    return @res;
}



# get_timered_job
# returns the list of jobs that have their frag state to TIMER_ARMED
# parameters : base
# return value : list of jobid
# side effects : /
sub get_timered_job($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT fragIdJob FROM fragJobs
                             WHERE fragState = \"TIMER_ARMED\"");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'fragIdJob'});
    }
    return @res;
}


# get_toexterminate_job
# returns the list of jobs that have their frag state to LEON_EXTERMINATE
# parameters : base
# return value : list of jobid
# side effects : /
sub get_toexterminate_job($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("   SELECT fragIdJob
                                FROM fragJobs
                                WHERE
                                    fragState = \"LEON_EXTERMINATE\"
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'fragIdJob'});
    }
    return @res;
}


# set_assigned_moldable_job
# sets the assignedMoldableJob field to the given value
# parameters : base, jobid, moldable id
# return value : /
sub set_assigned_moldable_job($$$) {
    my $dbh = shift;
    my $idJob = shift;
    my $moldable = shift;
    
    $dbh->do("  UPDATE jobs
                SET assignedMoldableJob = $moldable
                WHERE
                    idJob = $idJob
            ");
}



# set_running_date
# sets the starting time of the job passed in parameter to the current time
# parameters : base, jobid
# return value : /
# side effects : changes the field startTime of the job in the table Jobs
sub set_running_date($$) {
    my $dbh = shift;
    my $idJob = shift;
    
    my $runningDate;
    my $date = get_date($dbh);
    my $minDate = get_gantt_date($dbh);
    if (sql_to_local($date) < sql_to_local($minDate)){
        $runningDate = $minDate;
    }else{
        $runningDate = $date;
    }
    
    my $sth = $dbh->prepare("   UPDATE jobs
                                SET startTime = \"$runningDate\"
                                WHERE
                                    idJob =\"$idJob\"
                            ");
    $sth->execute();
    $sth->finish();
}



# set_running_date_arbitrary
# sets the starting time of the job passed in parameter to arbitrary time
# parameters : base, jobid
# return value : /
# side effects : changes the field startTime of the job in the table Jobs
sub set_running_date_arbitrary($$$) {
    my $dbh = shift;
    my $idJob = shift;
    my $date = shift;

    $dbh->do("UPDATE jobs SET startTime = \"$date\"
              WHERE idJob =\"$idJob\"
             ");
}



# set_finish_date
# sets the maximal stoping time of the job passed in parameter to the current
# time
# parameters : base, jobid
# return value : /
# side effects : changes the field stopTime of the job in the table Jobs
sub set_finish_date($$) {
    my $dbh = shift;
    my $idJob = shift;
    
    my $finishDate;
    my $date = get_date($dbh);
    my $jobInfo = get_job($dbh,$idJob);
    my $minDate = $jobInfo->{'startTime'};
    if (sql_to_local($date) < sql_to_local($minDate)){
        $finishDate = $minDate;
    }else{
        $finishDate = $date;
    }
    my $sth = $dbh->prepare("   UPDATE jobs
                                SET stopTime = \"$finishDate\"
                                WHERE
                                    idJob =\"$idJob\"
                            ");
    $sth->execute();
    $sth->finish();
}


# get_all_possible_resources_with_childhood
# returns the number of resources with the same property
# parameters : base, property name, where restrictions
# return value : hash table (property_value --> number)
sub get_all_possible_resources_with_childhood($$$$) {
    my $dbh = shift;
    my $tree_node_list = shift;
    my $wanted_property_name = shift;
    my $where_clause = shift;
    
    my $sql = "TRUE";
    if (defined($tree_node_list)){
        foreach my $n (oar_resource_tree::get_parents($tree_node_list)){
            $sql .= " AND ".oar_resource_tree::get_current_resource_name($n)." = \"".oar_resource_tree::get_current_resource_value($n)."\"";
        }
    }
    if (defined($where_clause)){
        $sql .= " AND $where_clause";
    }
    print("$sql\n");
    my $sth = $dbh->prepare("   SELECT count(DISTINCT($wanted_property_name))
                                FROM resourceProperties
                                WHERE
                                    $sql
                            ");
    $sth->execute();
    my @tmp = $sth->fetchrow_array();
    $sth->finish();
    
    return($tmp[0]);
}


# get_possible_wanted_resources
# return a tree ref : a data structure with corresponding resources with what is asked
sub get_possible_wanted_resources($$$$$){
    my $dbh = shift;
    my $possible_resources = shift;
    my $impossible_resources = shift;
    my $properties = shift;
    my $wanted_resources_ref = shift;

    my @wanted_resources = @{$wanted_resources_ref};
    push(@wanted_resources, {
                                resource => "resourceId",
                                value    => -1,
                            });
    
    my $sql_where_string ;
    if (defined($possible_resources->[0])){
        $sql_where_string = "resourceId IN(";
        foreach my $i (@{$possible_resources}){
            $sql_where_string .= "$i,";
        }
        chop($sql_where_string);
        $sql_where_string .= ") ";
    }else{
        $sql_where_string = "TRUE ";
    }

    if (defined($impossible_resources->[0])){
        $sql_where_string .= "AND resourceId NOT IN (" ;
        foreach my $i (@{$impossible_resources}){
            $sql_where_string .= "$i,";
        }
        chop($sql_where_string);
        $sql_where_string .= ") ";
    }
    
    if ($properties =~ m/\w+/m){
        $sql_where_string .= "AND ( $properties )";
    }
    
    #Get only wanted resources
    my $resource_string;
    foreach my $r (@wanted_resources){
        $resource_string .= " $r->{resource},";
    }
    chop($resource_string);

    #print("$sql_where_string\n");
    my $sth = $dbh->prepare("SELECT $resource_string
                             FROM resourceProperties
                             WHERE
                                $sql_where_string
                            ");
    if (!$sth->execute()){
        return(undef);
    }
    
    # Initialize root
    my $result ;
    $result = oar_resource_tree::new();
    my $wanted_children_number = $wanted_resources[0]->{value};
#    if ($wanted_children_number < 0){
#        $wanted_children_number = get_all_possible_resources_with_childhood($dbh,undef,$wanted_resources[0]->{resource},$sql_where_string);
#    }
    oar_resource_tree::set_needed_children_number($result,$wanted_children_number);

    while (my @sql = $sth->fetchrow_array()){
        my $father_ref = $result;
        foreach (my $i = 0; $i <= $#wanted_resources; $i++){
            # Feed the tree for all resources
            $father_ref = oar_resource_tree::add_child($father_ref, $wanted_resources[$i]->{resource}, $sql[$i]);

            if ($i < $#wanted_resources){
                $wanted_children_number = $wanted_resources[$i+1]->{value};
#                if ($wanted_children_number < 0){
#                    $wanted_children_number = get_all_possible_resources_with_childhood($dbh,$father_ref,$wanted_resources[$i+1]->{resource} , $sql_where_string);
#                }
            }else{
                $wanted_children_number = 0;
            }
            oar_resource_tree::set_needed_children_number($father_ref,$wanted_children_number);
        }
    }
    
    $sth->finish();
#print(Dumper($result));
    $result = oar_resource_tree::delete_tree_nodes_with_not_enough_resources($result);

    return($result);
}


# add_micheline_job
# adds a new job to the table Jobs applying the admission rules from the base
# parameters : base, jobtype, nbnodes, weight, command, infotype, maxtime,
#              queuename, jobproperties, startTimeReservation
# return value : jobid
# side effects : adds an entry to the table Jobs
#                the jobid is found taking the maximal jobid from jobs in the
#                table plus 1
#                the rules in the base are pieces of perl code directly
#                evaluated here, so in theory any side effect is possible
#                in normal use, the unique effect of an admission rule should
#                be to change parameters
sub add_micheline_job($$$$$$$$$$$$$$$$) {
    my ($dbh, $dbh_ro, $jobType, $ref_resource_list, $command, $infoType, $queueName, $jobproperties, $startTimeReservation, $idFile, $checkpoint, $mail, $job_name,$type_list,$launching_directory,$anterior_ref) = @_;

    my $default_walltime = "1:00:00";
    my $startTimeJob = "0000-00-00 00:00:00";
    my $reservationField = "None";
    my $setCommandReservation = 0;
    #Test if this job is a reservation
    if ($startTimeReservation =~ m/^\s*(\d{4}\-\d{1,2}\-\d{1,2})\s+(\d{1,2}:\d{1,2}:\d{1,2})\s*$/m){
        $reservationField = "toSchedule";
        $startTimeJob = "$1 $2";
        $setCommandReservation = 1;
        $jobType = "PASSIVE";
    }elsif($startTimeReservation ne "0"){
        print("Syntax error near -r or --reservation option. Reservation date exemple : \"2004-03-25 17:32:12\"\n");
        return(-3);
    }

    my $rules;
    my $user= getpwuid($ENV{SUDO_UID});

    # Verify the content of user command
    #if ( "$command" !~ m/^[\w\s\/\.\-]*$/m ){
    #    print("ERROR : The command to launch contains bad characters\n");
    #    return(-4);
    #}
    
    #Retrieve Micheline's rules from the table
    my $sth = $dbh->prepare("SELECT rule FROM admissionRules");
    $sth->execute();
    while (my $ref = $sth->fetchrow_hashref()) {
        $rules = $rules.$ref->{'rule'};
    }
    $sth->finish();
    #Apply rules
    #print "Admission rules => $rules \n";
    eval $rules;
    if ($@) {
        print("Admission Rule ERROR : $@ \n");
        return(-2);
    }

    if (($setCommandReservation == 1) && ($command eq "")){
        # For reservations we take the first moldable job
        $command = "/bin/sleep ".sql_to_duration($ref_resource_list->[0]->[1]);
    }

    # Test if properties and resources are coherent
    my $wanted_resources;
    foreach my $moldable_resource (@{$ref_resource_list}){
        if (!defined($moldable_resource->[1])){
            $moldable_resource->[1] = $default_walltime;
        }
        my @resource_id_list;
        foreach my $r (@{$moldable_resource->[0]}){
            # SECURITY : we must use read only database access for this request
            my $tmp_properties = $r->{property};
            if ($jobproperties ne ""){
                if (!defined($tmp_properties)){
                    $tmp_properties = $jobproperties;
                }else{
                    $tmp_properties = "($tmp_properties) AND ($jobproperties)"
                }
            }
            print(Dumper($r->{resources}));
            my $tree = get_possible_wanted_resources($dbh_ro, undef, \@resource_id_list, $tmp_properties, $r->{resources});
            if (!defined($tree)){
                # Resource description does not match with the content of the database
                print("There are not enough resources for your request\n");
                return(-5);
            }else{
                my @leafs = oar_resource_tree::get_tree_leafs($tree);
                foreach my $l (@leafs){
                    push(@resource_id_list, oar_resource_tree::get_current_resource_value($l));
                }
            }
        }
    }

    #Insert job
    my $date = get_date($dbh);
    $dbh->do("INSERT INTO jobs
              (idJob,jobType,infoType,state,user,command,submissionTime,queueName,properties,launchingDirectory,reservation,startTime,idFile,checkpoint,jobName,mail)
              VALUES (\"NULL\",\"$jobType\",\"$infoType\",\"Waiting\",\"$user\",\"$command\",\"$date\",\"$queueName\",\'$jobproperties\',\"$launching_directory\",\"$reservationField\",\"$startTimeJob\",$idFile,$checkpoint,\"$job_name\",\"$mail\")
             ");

    $sth = $dbh->prepare("SELECT LAST_INSERT_ID()");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my @tmp_array = values(%$ref);
    my $job_id = $tmp_array[0];
    $sth->finish();
 
    $dbh->do("INSERT INTO jobStates_log (jobId,jobState,dateStart)
              VALUES ($job_id,\"Waiting\",\"$date\")
             ");

    foreach my $moldable_resource (@{$ref_resource_list}){
        $dbh->do("  INSERT INTO moldableJobs_description (moldableId,moldableJobId,moldableWalltime)
                    VALUES (\"NULL\",$job_id,\"$moldable_resource->[1]\")
                 ");
        my $sth = $dbh->prepare("SELECT LAST_INSERT_ID()");
        $sth->execute();
        my $ref = $sth->fetchrow_hashref();
        my @tmp_array = values(%$ref);
        my $moldable_id = $tmp_array[0];
        $sth->finish();
        foreach my $r (@{$moldable_resource->[0]}){
            $dbh->do("  INSERT INTO jobResources_group (resGroupId,resGroupMoldableId,resGroupProperty)
                        VALUES (\"NULL\",$moldable_id,\'$r->{property}\')
                     ");
            my $order = 0;
            foreach my $l (@{$r->{resources}}){
                $dbh->do("  INSERT INTO jobResources_description (resJobGroupId,resJobResourceType,resJobValue,resJobOrder)
                            VALUES (LAST_INSERT_ID(),\"$l->{resource}\",\"$l->{value}\",$order)
                         ");
                $order ++;
            }
        }
    }

    foreach my $t (@{$type_list}){
        $dbh->do("  INSERT INTO job_types (jobId,type)
                    VALUES ($job_id,\"$t\")
                 ");
    }

    foreach my $a (@{$anterior_ref}){
        $dbh->do("  INSERT INTO jobDependencies (idJob,idJobRequired)
                    VALUES ($job_id,$a)
                 ");
    }

    my $random_number = int(rand(1000000000000));
    $dbh->do("INSERT INTO challenges (jobId,challenge)
              VALUES ($job_id,\"$random_number\")
             ");
    #$dbh->do("UNLOCK TABLES");

    return($job_id);
}



# get_oldest_waiting_idjob
# returns the jobid of the oldest job in state "Waiting" (the oldest is found
# by taking the one of minimal id, using the fact that ids are given in non
# decreasing order)
# parameters : base
# return value : jobid
# side effects : /
sub get_oldest_waiting_idjob($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT MIN(idJob) FROM jobs j WHERE j.state=\"Waiting\"");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my @tmp = values %$ref;
    my $id = $tmp[0];
    $sth->finish();

    if (! defined $id){
        return -1;
    }

    return $id;
}



# get_oldest_waiting_idjob_by_queue
# returns the jobid of the oldest job in state "Waiting" and belonging to the
# execution queue passed in parameter (the oldest is found by taking the one
# of minimal id, using the fact that ids are given in non decreasing order)
# parameters : base, queuename
# return value : jobid
# side effects : /
sub get_oldest_waiting_idjob_by_queue($$) {
    my $dbh = shift;
    my $queue = shift;

    my $sth = $dbh->prepare("SELECT MIN(idJob)
                             FROM jobs j
                             WHERE j.state=\"Waiting\"
                             AND j.queueName=\"$queue\"");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my @tmp = values %$ref;
    my $id = $tmp[0];
    $sth->finish();

    if (! defined $id){
        return -1;
    }
    return $id;
}


# get_job
# returns a ref to some hash containing data for the job of id passed in
# parameter
# parameters : base, jobid
# return value : ref
# side effects : /
sub get_job($$) {
    my $dbh = shift;
    my $idJob = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM jobs
                                WHERE
                                    idJob = $idJob
                            ");
    $sth->execute();

    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    return $ref;
}


# get_current_moldable_job
# returns a ref to some hash containing data for the moldable job of id passed in
# parameter
# parameters : base, moldable job id
# return value : ref
# side effects : /
sub get_current_moldable_job($$) {
    my $dbh = shift;
    my $moldableJobId = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM moldableJobs_description
                                WHERE
                                    moldableIndex = \"CURRENT\"
                                    AND moldableId = $moldableJobId
                            ");
    $sth->execute();

    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    return $ref;
}


# set_job_state
# sets the state field of the job of id passed in parameter
# parameters : base, jobid, state
# return value : /
# side effects : changes the field reservation of the job in the table Jobs
sub set_job_state($$$) {
    my $dbh = shift;
    my $idJob = shift;
    my $state = shift;
    
    $dbh->do("  UPDATE jobs
                SET state = \"$state\"
                WHERE
                    idJob =\"$idJob\"
             ");
    
    my $date = get_date($dbh);
    $dbh->do("  UPDATE jobStates_log
                SET dateStop = \"$date\"
                WHERE
                    dateStop IS NULL
                    AND jobId = $idJob
             ");
    $dbh->do("  INSERT INTO jobStates_log (jobId,jobState,dateStart)
                VALUES ($idJob,\"$state\",\"$date\")
             ");

    if (($state eq "Terminated") or ($state eq "Error")){
        $dbh->do("  DELETE FROM challenges
                    WHERE jobId = $idJob
                 ");
        $dbh->do("  UPDATE moldableJobs_description, jobResources_group, jobResources_description
                    SET jobResources_group.resGroupIndex = \"LOG\",
                        jobResources_description.resJobIndex = \"LOG\",
                        moldableJobs_description.moldableIndex = \"LOG\"
                    WHERE
                        moldableJobs_description.moldableIndex = \"CURRENT\"
                        AND moldableJobs_description.moldableIndex = \"CURRENT\"
                        AND jobResources_group.resGroupIndex = \"CURRENT\"
                        AND jobResources_description.resJobIndex = \"CURRENT\"
                        AND moldableJobs_description.moldableJobId = $idJob
                        AND jobResources_group.resGroupMoldableId = moldableJobs_description.moldableId
                        AND jobResources_description.resJobGroupId = jobResources_group.resGroupId
                 ");

        $dbh->do("  UPDATE job_types
                    SET job_types.typesIndex = \"LOG\"
                    WHERE
                        job_types.typesIndex = \"CURRENT\"
                        AND job_types.jobId = $idJob
                 ");
        
        $dbh->do("  UPDATE jobDependencies
                    SET jobDependencies.jobDependencyIndex = \"LOG\"
                    WHERE
                        jobDependencies.jobDependencyIndex = \"CURRENT\"
                        AND jobDependencies.idJob = $idJob
                 ");
    }
}



# set_job_resa_state
# sets the reservation field of the job of id passed in parameter
# parameters : base, jobid, state
# return value : /
# side effects : changes the field state of the job in the table Jobs
sub set_job_resa_state($$$){
    my $dbh = shift;
    my $idJob = shift;
    my $state = shift;
    my $sth = $dbh->prepare("UPDATE jobs SET reservation = \"$state\"
                             WHERE idJob =\"$idJob\"");
    $sth->execute();
    $sth->finish();
}



# set_job_message
# sets the message field of the job of id passed in parameter
# parameters : base, jobid, message
# return value : /
# side effects : changes the field message of the job in the table Jobs
sub set_job_message($$$) {
    my $dbh = shift;
    my $idJob = shift;
    my $message = shift;
    $dbh->do("  UPDATE jobs
                SET message = \"$message\"
                WHERE
                    idJob = $idJob
             ");
}

# set_job_autoCheckpointed
# sets the autoCheckpointed field into YES of the job of id passed in parameter
# parameters : base, jobid
# return value : /
sub set_job_autoCheckpointed($$) {
    my $dbh = shift;
    my $idJob = shift;
    $dbh->do("UPDATE jobs
                SET autoCheckpointed = \"YES\"
                WHERE idJob = $idJob");
}


# frag_job
# sets the flag 'ToFrag' of a job to 'Yes'
# parameters : base, jobid
# return value : 0 on success, -1 on error (if the user calling this method
#                is not the user running the job or oar)
# side effects : changes the field ToFrag of the job in the table Jobs
sub frag_job($$) {
    my $dbh = shift;
    my $idJob = shift;

    #my $lusr= getpwuid($<);
    my $lusr= getpwuid($ENV{SUDO_UID});

    my $job = get_job($dbh, $idJob);

    if((defined($job)) && (($lusr eq $job->{'user'}) or ($lusr eq "oar") or ($lusr eq "root"))) {
        $dbh->do("LOCK TABLE fragJobs WRITE, events_log WRITE");
        my $nbRes = $dbh->do("SELECT *
                              FROM fragJobs
                              WHERE
                                fragIdJob = $idJob
                             ");

        if ( $nbRes < 1 ){
            my $date = get_date($dbh);
            $dbh->do("INSERT INTO fragJobs (fragIdJob,fragDate)
                      VALUES ($idJob,\"$date\")
                     ");
            add_new_event($dbh,"FRAG_JOB_REQUEST",$idJob,"User $lusr requested to frag the job $idJob");
        }
        $dbh->do("UNLOCK TABLES");
        return 0;
    }else{
        return -1;
    }
}


# ask_checkpoint_job
# Verify if the user is able to checkpoint the job
# args : database ref, job id
# returns : 0 if all is good, 1 if the user cannot do this, 2 if the job is not running
sub ask_checkpoint_job($$){
    my $dbh = shift;
    my $idJob = shift;

    my $lusr= getpwuid($ENV{SUDO_UID});

    my $job = get_job($dbh, $idJob);

    if((defined($job)) && (($lusr eq $job->{'user'}) or ($lusr eq "oar") or ($lusr eq "root"))) {
        if ($job->{state} eq "Running"){
            #$dbh->do("LOCK TABLE event_log WRITE");
            add_new_event($dbh,"CHECKPOINT",$idJob,"User $lusr requested a checkpoint on the job $idJob");
            #$dbh->do("UNLOCK TABLES");
            return 0;
        }else{
            return 2;
        }
    }else{
        return 1;
    }   
}


# hold_job
# sets the state field of a job to 'Hold'
# equivalent to set_job_state(base,jobid,"Hold") except for permissions on user
# parameters : base, jobid
# return value : 0 on success, -1 on error (if the user calling this method
#                is not the user running the job)
# side effects : changes the field state of the job to 'Hold' in the table Jobs
sub hold_job($$) {
    my $dbh = shift;
    my $idJob = shift;

    #my $lusr= getpwuid($<);
    my $lusr = getpwuid($ENV{SUDO_UID});

    my $job = get_job($dbh, $idJob);

    if ((defined($job)) && ((($lusr eq $job->{'user'}) || ($lusr eq "oar") || ($lusr eq "root")) && ($job->{'state'} eq "Waiting"))) {
        my $sth = $dbh->prepare("   UPDATE jobs
                                    SET state = \"Hold\"
                                    WHERE
                                        idJob =\"$idJob\"
                                ");
        $sth->execute();
        $sth->finish();
        return 0;
    } else {
        return -1;
    }
}



# resume_job
# returns the state of the job from 'Hold' to 'Waiting'
# equivalent to set_job_state(base,jobid,"Waiting") except for permissions on
# user and the fact the job must already be in 'Hold' state
# parameters : base, jobid
# return value : 0 on success, -1 on error (if the user calling this method
#                is not the user running the job)
# side effects : changes the field state of the job to 'Waiting' in the table
#                Jobs
sub resume_job($$) {
    my $dbh = shift;
    my $idJob = shift;

    #my $lusr= getpwuid($<);
    my $lusr = getpwuid($ENV{SUDO_UID});

    my $job = get_job($dbh, $idJob);

    if ((defined($job)) && ((($lusr eq $job->{'user'}) || ($lusr eq "oar") || ($lusr eq "root"))  && ($job->{'state'} eq "Hold"))) {
        my $sth = $dbh->prepare("   UPDATE jobs
                                    SET state = \"Waiting\"
                                    WHERE
                                        idJob =\"$idJob\"
                                ");
        $sth->execute();
        $sth->finish();
        return 0;
    } else {
        return -1;
    }
}



# job_fragged
# sets the flag 'ToFrag' of a job to 'No'
# parameters : base, jobid
# return value : /
# side effects : changes the field ToFrag of the job in the table Jobs
sub job_fragged($$) {
    my $dbh = shift;
    my $idJob = shift;

    $dbh->do("UPDATE fragJobs
              SET fragState = \"FRAGGED\"
              WHERE fragIdJob = $idJob
             ");
}



# job_arm_leon_timer
# sets the state to TIMER_ARMED of job
# parameters : base, jobid
# return value : /
sub job_arm_leon_timer($$) {
    my $dbh = shift;
    my $idJob = shift;

    $dbh->do("  UPDATE fragJobs
                SET fragState = \"TIMER_ARMED\"
                WHERE
                    fragIdJob = $idJob
             ");
}


# job_refrag
# sets the state to LEON of job
# parameters : base, jobid
# return value : /
sub job_refrag($$) {
    my $dbh = shift;
    my $idJob = shift;

    $dbh->do("UPDATE fragJobs SET fragState = \"LEON\"
              WHERE fragIdJob = $idJob
             ");
}



# job_leon_exterminate
# sets the state LEON_EXTERMINATE of job
# parameters : base, jobid
# return value : /
sub job_leon_exterminate($$) {
    my $dbh = shift;
    my $idJob = shift;

    $dbh->do("UPDATE fragJobs SET fragState = \"LEON_EXTERMINATE\"
              WHERE fragIdJob = $idJob
             ");
}



# get_frag_date
# gets the date of the frag of a job
# parameters : base, jobid
# return value : date
sub get_frag_date($$) {
    my $dbh = shift;
    my $idJob = shift;

    my $sth = $dbh->prepare("SELECT fragDate
                             FROM fragJobs
                             WHERE fragIdJob = $idJob
                            ");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    $sth->finish();
    return($ref->{'fragDate'});
}



# list_current_jobs
# returns a list of jobid for jobs that are in one of the states
# Waiting, toLaunch, Running, Launching, Hold or toKill.
# parameters : base
# return value : list of jobid
# side effects : /
sub list_current_jobs($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT * FROM jobs j
                             WHERE j.state=\"Waiting\"
                             OR    j.state=\"toLaunch\"
                             OR    j.state=\"Running\"
                             OR    j.state=\"Launching\"
                             OR    j.state=\"Hold\"
                             OR    j.state=\"toError\"
                             OR    j.state=\"toAckReservation\"
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'idJob'});
    }
    $sth->finish();
    return @res;
}

# Get all waiting reservation jobs
# parameter : database ref
# return an array of job informations
sub get_waiting_reservation_jobs($){
    my $dbh = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM jobs j
                                WHERE
                                    (j.state = \"Waiting\"
                                        OR j.state = \"toAckReservation\")
                                    AND j.reservation = \"Scheduled\"
                                ORDER BY j.idJob
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    $sth->finish();
    return @res;
}


# Get all waiting reservation jobs in the specified queue
# parameter : database ref, queuename
# return an array of job informations
sub get_waiting_reservation_jobs_specific_queue($$){
    my $dbh = shift;
    my $queue = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM jobs j
                                WHERE
                                    j.state=\"Waiting\"
                                    AND j.reservation = \"Scheduled\"
                                    AND j.queueName = \"$queue\"
                                ORDER BY j.idJob
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    $sth->finish();
    return @res;
}


# Get if it exists waiting jobs in the specified queue or not
# parameter : database ref, queuename
# return 0 --> no
#        1 --> yes
sub is_waiting_job_specific_queue_present($$){
    my $dbh = shift;
    my $queue = shift;

    my $sth = $dbh->prepare("   SELECT count(*)
                                FROM jobs
                                WHERE
                                    state=\"Waiting\"
                                    AND queueName = \"$queue\"
                                LIMIT 1
                            ");
    $sth->execute();
    my ($res) = $sth->fetchrow_array();
    $sth->finish();
    return ($res > 0);
}


# get_jobs_to_schedule
# args : base ref, queue name
sub get_jobs_to_schedule($$){
    my $dbh = shift;
    my $queue = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM jobs
                                WHERE
                                    state = \"Waiting\"
                                    AND reservation = \"None\"
                                    AND queueName = \"$queue\"
                                ORDER BY idJob
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    $sth->finish();
    return @res;
}


# get_current_job_types
# return a hash table with all types for the given job ID
sub get_current_job_types($$){
    my $dbh = shift;
    my $jobId = shift;

    my $sth = $dbh->prepare("   SELECT type
                                FROM job_types
                                WHERE
                                    typesIndex = \"CURRENT\"
                                    AND jobId = $jobId
                            ");
    $sth->execute();
    my %res;
    while (my $ref = $sth->fetchrow_hashref()) {
        $res{$ref->{type}} = 1;
    }
    $sth->finish();

    return(\%res);
}


# get_current_job_dependencies
# return an array table with all dependencies for the given job ID
sub get_current_job_dependencies($$){
    my $dbh = shift;
    my $jobId = shift;

    my $sth = $dbh->prepare("   SELECT idJobRequired
                                FROM jobDependencies
                                WHERE
                                    jobDependencyIndex = \"CURRENT\"
                                    AND idJob = $jobId
                            ");
    $sth->execute();
    my @res;
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{idJobRequired});
    }
    $sth->finish();

    return(@res);
}


# Get all waiting toSchedule reservation jobs in the specified queue
# parameter : database ref, queuename
# return an array of job informations
sub get_waiting_toSchedule_reservation_jobs_specific_queue($$){
    my $dbh = shift;
    my $queue = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM jobs j
                                WHERE
                                    j.state=\"Waiting\"
                                    AND j.reservation = \"toSchedule\"
                                    AND j.queueName = \"$queue\"
                                ORDER BY j.idJob
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    $sth->finish();
    return @res;
}



# PROCESSJOBS MANAGEMENT (Host assignment to jobs)

# remove_current_assigned_resources
# chenge assignedResourceIndex into "LOG" for the given moldable job
# parameters : base, moldableJobId
# return value : /
sub remove_current_assigned_resources($$){
    my $dbh = shift;
    my $moldableJobId= shift;

    $dbh->do("  UPDATE assignedResources
                SET assignedResourceIndex = \"LOG\"
                WHERE
                    assignedResourceIndex = \"CURRENT\"
                    AND idMoldableJob = $moldableJobId
            ");
}


# get_resource_job
# returns the list of jobs associated to the resource passed in parameter
# parameters : base, resource
# return value : list of jobid
# side effects : /
sub get_resource_job($$) {
    my $dbh = shift;
    my $resource = shift;
    my $sth = $dbh->prepare("   SELECT c.idJob
                                FROM assignedResources a, moldableJobs_description b, jobs c
                                WHERE
                                    a.assignedResourceIndex = \"CURRENT\"
                                    AND b.moldableIndex = \"CURRENT\"
                                    AND a.idResource = $resource
                                    AND a.idMoldableJob = b.moldableId
                                    AND b.moldableJobId = c.idJob
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'idJob'});
    }
    return @res;
}


# get_node_job
# returns the list of jobs associated to the hostname passed in parameter
# parameters : base, hostname
# return value : list of jobid
# side effects : /
sub get_node_job($$) {
    my $dbh = shift;
    my $hostname = shift;
    my $sth = $dbh->prepare("   SELECT c.idJob
                                FROM assignedResources a, moldableJobs_description b, jobs c, resources d
                                WHERE
                                    a.assignedResourceIndex = \"CURRENT\"
                                    AND b.moldableIndex = \"CURRENT\"
                                    AND d.networkAddress = \"$hostname\"
                                    AND a.idResource = d.resourceId
                                    AND a.idMoldableJob = b.moldableId
                                    AND b.moldableJobId = c.idJob
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'idJob'});
    }
    return @res;
}


# get_resources_in_state
# returns the list of resources in the state specified
# parameters : base, state
# return value : list of resource ref
sub get_resources_in_state($$) {
    my $dbh = shift;
    my $state = shift;
    
    my $sth = $dbh->prepare("   SELECT *
                                FROM resources
                                WHERE
                                    state = \"$state\"
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    return @res;
}


# get_running_host
# returns the list of hosts on which some jobs in the 'Running' state exist
# parameters : base
# return value : list of hostnames
# side effects : /
sub get_running_host($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT distinct p.hostname FROM jobs j,processJobs p
                             WHERE j.state=\"Running\"
                             AND j.idJob = p.idJob");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
    }
    return @res;
}



# add_resource_job_pair
# adds a new pair (jobid, resource) to the table assignedResources
# parameters : base, jobid, resource id
# return value : /
sub add_resource_job_pair($$$) {
    my $dbh = shift;
    my $moldable = shift;
    my $resource = shift;
    $dbh->do("INSERT INTO assignedResources (idMoldableJob,idResource,assignedResourceIndex)
              VALUES ($moldable,$resource,\"CURRENT\")");
}

# remove_node_job_pair
# removes a pair (jobid, hostname) to the table processjobs.
# This should match the execution of some process for the job of given id
# and on the given host.
# parameters : base, jobid, hostname
# return value : /
# side effects : adds a new entry to the table processjobs_log and remove one in processjobs.
sub remove_node_job_pair($$$) {
    my $dbh = shift;
    my $idJob = shift;
    my $hostname = shift;

    #$dbh->do("INSERT INTO processJobs_log (idJob,hostname)
    #          VALUES ($idJob,\"$hostname\")");

    $dbh->do("DELETE FROM processJobs
              WHERE idJob = $idJob
              AND hostname = \"$hostname\"");
#    $dbh->do("OPTIMIZE TABLE processJobs");
}



# get all jobs in a range of date
# args : base, start range, end range
sub get_jobs_range_dates($$$){
    my $dbh = shift;
    my $dateStart = shift;
    my $dateEnd = shift;

    my $sth = $dbh->prepare("SELECT j.idJob,j.jobType,j.state,j.user,j.weight,j.command,j.queueName,j.maxTime,
                                    j.properties,j.launchingDirectory,j.submissionTime,j.startTime,j.stopTime,p.hostname,
                                    (DATE_ADD(j.startTime, INTERVAL j.maxTime HOUR_SECOND))
                             FROM jobs j, processJobs_log p
                             WHERE ( j.stopTime >= \"$dateStart\"
                                     OR (j.stopTime = \"0000-00-00 00:00:00\"
                                         AND j.state = \"Running\"
                                        )
                                   )
                                   AND j.startTime < \"$dateEnd\"
                                   AND j.idJob = p.idJob
                             ORDER BY j.idJob
                            ");
    $sth->execute();

    my %results;
    while (my @ref = $sth->fetchrow_array()) {
        if (!defined($results{$ref[0]})){
            $results{$ref[0]} = {
                                  'jobType' => $ref[1],
                                  'state' => $ref[2],
                                  'user' => $ref[3],
                                  'weight' => $ref[4],
                                  'command' => $ref[5],
                                  'queueName' => $ref[6],
                                  'maxtime' => $ref[7],
                                  'properties' => $ref[8],
                                  'launchingDirectory' => $ref[9],
                                  'submissionTime' => $ref[10],
                                  'startTime' => $ref[11],
                                  'stopTime' => $ref[12],
                                  'limitStopTime' => $ref[14],
                                  'nodes' => [ $ref[13] ]
                                 }
        }else{
            push(@{$results{$ref[0]}->{nodes}}, $ref[13]);
        }
    }
    $sth->finish();

    return %results;
}



# get all jobs in a range of date in the gantt
# args : base, start range, end range
sub get_jobs_gantt_scheduled($$$){
    my $dbh = shift;
    my $dateStart = shift;
    my $dateEnd = shift;

    my $sth = $dbh->prepare("SELECT j.idJob,j.jobType,j.state,j.user,j.weight,j.command,j.queueName,j.maxTime,
                                    j.properties,j.launchingDirectory,j.submissionTime,g2.startTime,(DATE_ADD(g2.startTime, INTERVAL j.maxTime HOUR_SECOND)),g1.hostname
                             FROM jobs j, ganttJobsNodes_visu g1, ganttJobsPrediction_visu g2
                             WHERE  g2.idJob = g1.idJob
                                AND g2.idJob = j.idJob
                                AND g2.startTime < \"$dateEnd\"
                                AND (DATE_ADD(g2.startTime, INTERVAL j.maxTime HOUR_SECOND)) >= \"$dateStart\"
                             ORDER BY j.idJob
                            ");
    $sth->execute();

    my %results;
    while (my @ref = $sth->fetchrow_array()) {
        if (!defined($results{$ref[0]})){
            $results{$ref[0]} = {
                                  'jobType' => $ref[1],
                                  'state' => $ref[2],
                                  'user' => $ref[3],
                                  'weight' => $ref[4],
                                  'command' => $ref[5],
                                  'queueName' => $ref[6],
                                  'maxtime' => $ref[7],
                                  'properties' => $ref[8],
                                  'launchingDirectory' => $ref[9],
                                  'submissionTime' => $ref[10],
                                  'startTime' => $ref[11],
                                  'stopTime' => $ref[12],
                                  'nodes' => [ $ref[13] ]
                                 }
        }else{
            push(@{$results{$ref[0]}->{nodes}}, $ref[13]);
        }
    }
    $sth->finish();

    return %results;
}

# get_desktop_computing_host_jobs($$);
# get the list of jobs and attributs affected to a desktop computing node
# parameters: base, nodename
# return value: jobs hash
# side effects: none
sub get_desktop_computing_host_jobs($$) {
		my $dbh = shift;
		my $hostname = shift;
		my $sth = $dbh->prepare(<<EOF
SELECT
	j.idJob, j.state, j.weight, j.command, j.launchingDirectory
FROM
	jobs j,
	processJobs pj,
	nodeProperties np
WHERE	
	np.hostname=\"$hostname\"
	AND 
	np.desktopComputing=\"YES\"
	AND
	pj.hostname=np.hostname
	AND
	pj.idJob=j.idJob
EOF
);
		$sth->execute;
		my $results;
		while (my @array = $sth->fetchrow_array()) {
				$results->{$array[0]} = {
						'state' => $array[1],
						'weight' => $array[2],
						'command' => $array[3],
						'directory' => $array[4]
				};
    }
		return $results;
}

# get_stagein_id($$);
# retrieve stagein idFile form its md5sum
# parameters: base, md5sum
# return value: idFile or undef if md5sum is not found
# side effects: none
sub get_stagein_id($$) {
		my $dbh = shift;
		my $md5sum = shift;
		my $sth = $dbh->prepare(<<EOF
SELECT
	idFile
FROM
	files
WHERE	
	md5sum=\"$md5sum\"
EOF
);
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    $sth->finish();
    return $ref->{'idFile'};
}

# set_stagein($$$$$$);
# set a stagein information
# parameters: base, md5sum, location, method, compression, size
# return value: the idFile of the new stagein.
# side effects: none
sub set_stagein($$$$$$) {
    my $dbh = shift;
    my $md5sum = shift;
    my $location = shift;
    my $method = shift;
    my $compression = shift;
    my $size = shift;
    my $idFile;
    $dbh->do("LOCK TABLE files WRITE");
    $dbh->do("INSERT INTO files (md5sum,location,method,compression,size)
              VALUES (\"$md5sum\",\"$location\",\"$method\",\"$compression\",$size)");
    my $sth = $dbh->prepare("SELECT LAST_INSERT_ID()");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    ($idFile) = values(%$ref);
    $sth->finish();
    $dbh->do("UNLOCK TABLE");
    return $idFile;
}

# del_stagein($$);
# remove a stagein from database
# parameters: base, md5sum
# return value: none
# side effects: none
sub del_stagein($$) {
    my $dbh = shift;
    my $md5sum = shift;
    $dbh->do("LOCK TABLE files WRITE");
    $dbh->do("DELETE FROM files WHERE md5sum = \"$md5sum\"");
    $dbh->do("UNLOCK TABLE");
    return;
}

# is_stagein_deprecated($$$);
# check if a stagein file is to old to be kept in cache
# parameters: base, md5sum, expiry
# return value: boolean, true if deprecated
# side effects: none
sub is_stagein_deprecated($$$) {
    my $dbh = shift;
    my $md5sum = shift;
		my $expiry_delay = shift;
    my $sth = $dbh->prepare("SELECT (max(jobs.startTime) + INTERVAL $expiry_delay MINUTE) > NOW() FROM jobs, files WHERE jobs.idFile = files.idFile AND files.md5sum = \"$md5sum\"");
    $sth->execute();
    my ($res) = $sth->fetchrow_array();
    return ($res eq "NULL" or $res eq "0");
}

# get_job_stagein($$);
# get a job stagein information: pathname and md5sum
# parameters: base, jobid
# return value: a hash with 2 keys: pathname and md5sum
# side effects: none
sub get_job_stagein($$) {
		my $dbh = shift;
		my $jobid = shift;
		my $sth = $dbh->prepare(<<EOF
SELECT
	files.md5sum,files.location,files.method,files.compression,files.size
FROM
	jobs,
	files
WHERE	
	jobs.idJob=\"$jobid\"
	AND
	jobs.idFile=files.idFile
EOF
);
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    $sth->finish();
    return($ref);
}

# NODES MANAGEMENT

# add_resource
# adds a new resource in the table resources and resourceProperties
# parameters : base, name, state
# return value : new resource id
sub add_resource($$$) {
    my $dbh = shift;
    my $name = shift;
    my $state = shift;

    $dbh->do("  INSERT INTO resources (networkAddress,state)
                VALUES (\"$name\",\"$state\")
             ");
    $dbh->do("  INSERT INTO resourceProperties (resourceId)
                VALUES (LAST_INSERT_ID())
             ");
    my $date = get_date($dbh);
    $dbh->do("  INSERT INTO resourceStates_log (resourceId,changeState,dateStart)
                VALUES (LAST_INSERT_ID(),\"$state\",\"$date\")
             ");
    my $sth = $dbh->prepare("SELECT LAST_INSERT_ID()");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my @tmp = values(%$ref);
    my $id = $tmp[0];
    $sth->finish();

    return($id);
}


# get_free_exclusive_nodes
# gets the list of nodes on which a new job can be added with exclusive access.
# parameters : base
# return value : list of hostnames
# side effects : /
sub get_free_exclusive_nodes($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT p.hostname FROM nodes p
                             WHERE p.state=\"Alive\"
                             AND p.weight = 0");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
    }
    $sth->finish();
    return @res;
}


# get_alive_resources
# gets the list of resources in the Alive state.
# parameters : base
# return value : list of resource refs
# side effects : /
sub get_alive_resources($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM resources
                                WHERE
                                    state = \"Alive\"
                                    OR state = \"Suspected\"
                                    OR state = \"Absent\"
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    $sth->finish();
    return @res;
}


# get_number_Alive_state_nodes
# return the number of nodes in Alive state
# arg: database ref
sub get_number_Alive_state_nodes($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT COUNT(n.hostname) FROM nodes n
                             WHERE n.state = \"Alive\"
                             ");
    $sth->execute();
    my @ref = $sth->fetchrow_array();
    my $res = $ref[0];

    $sth->finish();
    return $res;
}

# get_really_alive_node
# gets the list of really alive nodes.
# parameters : base
# return value : list of hostnames
# side effects : /
sub get_really_alive_node($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT n.hostname FROM nodes n, nodeProperties p
                             WHERE  n.state = \"Alive\"
                                AND n.weight = 0
                                AND n.hostname = p.hostname
                                AND p.desktopComputing = \"NO\"
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
    }
    $sth->finish();
    return @res;
}



# get_suspected_node
# gets the list of suspected nodes.
# parameters : base
# return value : list of hostnames
# side effects : /
sub get_suspected_node($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT n.hostname
                             FROM nodes n, nodeProperties p
                             WHERE n.state = \"Suspected\"
                                AND n.finaudDecision = \"YES\"
                                AND n.hostname = p.hostname
                                AND p.desktopComputing = \"NO\"
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
    }
    $sth->finish();
    return(@res);
}


# list_resources
# gets the list of all resources
# parameters : base
# return value : list of resources
# side effects : /
sub list_resources($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM resources
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    $sth->finish();
    return(@res);
}


# list_nodes
# gets the list of all nodes.
# parameters : base
# return value : list of hostnames
# side effects : /
sub list_nodes($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("   SELECT distinct(networkAddress)
                                FROM resources
                                ORDER BY resourceId ASC");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'networkAddress'});
    }
    $sth->finish();
    return @res;
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
                                    resourceId = $resource
                            ");
    $sth->execute();

    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    return $ref;
}


# get_node_info
# returns a ref to some hash containing data for the node passed in parameter
# parameters : base, hostname
# return value : ref
sub get_node_info($$) {
    my $dbh = shift;
    my $hostname = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM resources
                                WHERE
                                    networkAddress = \"$hostname\"
                                ORDER BY resourceId ASC
                            ");
    $sth->execute();

    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    $sth->finish();

    return(@res);
}


# is_node_exists
# returns 1 if the given hostname exists in the database otherwise 0.
# parameters : base, hostname
# return value : ref
# side effects : /
sub is_node_exists($$) {
    my $dbh = shift;
    my $hostname = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM resources
                                WHERE
                                    networkAddress=\"$hostname\"
                            ");
    $sth->execute();

    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    if (defined($ref)){
        return(1);
    }else{
        return(0);
    }
}


# get_current_assigned_resources
# returns the current resources
# parameters : base
sub get_current_assigned_resources($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("   SELECT idResource
                                FROM assignedResources
                                WHERE
                                    assignedResourceIndex = \"CURRENT\"
                            ");
    $sth->execute();
    my @result;
    while (my $ref = $sth->fetchrow_hashref()){
        push(@result, $ref->{idResource});
    }
    $sth->finish();

    return @result;
}

# get_current_free_resources_of_node
# return an array of free resources for the specified networkAddress
sub get_current_free_resources_of_node($$){
    my $dbh = shift;
    my $host = shift;

    my @busy_resources = get_current_assigned_resources($dbh);
    my $where_str;
    if ($#busy_resources >= 0){
        $where_str = "resourceId NOT IN (";
        foreach my $r (@busy_resources){
            $where_str .= "$r,";
        }
        chop($where_str);
        $where_str .= ")";
    }else{
        $where_str = "TRUE";
    }
    
    my $sth = $dbh->prepare("   SELECT resourceId
                                FROM resources
                                WHERE
                                    networkAddress = \"$host\"
                                    AND $where_str
                            ");
    $sth->execute();
    my @result;
    while (my $ref = $sth->fetchrow_hashref()){
        push(@result, $ref->{resourceId});
    }
    $sth->finish();

    return @result;
}


# get_resources_on_node
# returns the current resources on node whose hostname is passed in parameter
# parameters : base, hostname
# return value : weight
# side effects : /
sub get_resources_on_node($$) {
    my $dbh = shift;
    my $hostname = shift;

    my $sth = $dbh->prepare("   SELECT b.resourceId resource
                                FROM assignedResources a, resources b
                                WHERE
                                    a.assignedResourceIndex = \"CURRENT\"
                                    AND b.networkAddress = \"$hostname\"
                                    AND b.resourceId = a.idResource
                            ");
    $sth->execute();
    my @result;
    while (my $ref = $sth->fetchrow_hashref()){
        push(@result, $ref->{resource});
    }
    $sth->finish();

    return @result;
}


# set_node_state
# sets the state field of some node identified by its hostname in the base.
# parameters : base, hostname, state, finaudDecision
# return value : /
# side effects : changes the state value in some field of the nodes table
sub set_node_state($$$$) {
    my $dbh = shift;
    my $hostname = shift;
    my $state = shift;
    my $finaud = shift;

    $dbh->do("  UPDATE resources
                SET state = \"$state\", finaudDecision = \"$finaud\"
                WHERE
                    networkAddress = \"$hostname\"
             ");

    my $date = get_date($dbh);
    $dbh->do("  UPDATE resourceStates_log a, resources b
                SET a.dateStop = \"$date\"
                WHERE
                    a.dateStop IS NULL
                    AND b.networkAddress = \"$hostname\"
                    AND a.resourceId = b.resourceId
             ");
    $dbh->do("INSERT INTO resourceStates_log (resourceId,changeState,dateStart,finaudDecision)
                SELECT a.resourceId,\"$state\",\"$date\",\"$finaud\"
                FROM resources a
                WHERE
                    a.networkAddress = \"$hostname\"
             ");
}

# set_resource_nextState
# sets the nextState field of a resource identified by its resourceId
# parameters : base, resource id, nextState
# return value : /
sub set_resource_nextState($$$) {
    my $dbh = shift;
    my $resource = shift;
    my $nextState = shift;

    my $result = $dbh->do(" UPDATE resources
                            SET nextState = \"$nextState\", nextFinaudDecision = \"NO\"
                            WHERE resourceId = $resource
                          ");
    return($result);
}


# set_resource_state
# sets the state field of a resource
# parameters : base, resource id, state, finaudDecision
sub set_resource_state($$$$) {
    my $dbh = shift;
    my $resource_id = shift;
    my $state = shift;
    my $finaud = shift;

    $dbh->do("  UPDATE resources
                SET state = \"$state\", finaudDecision = \"$finaud\"
                WHERE
                    resourceId = $resource_id
             ");

    my $date = get_date($dbh);
    $dbh->do("  UPDATE resourceStates_log
                SET dateStop = \"$date\"
                WHERE
                    dateStop IS NULL
                    AND resourceId = $resource_id
             ");
    $dbh->do("INSERT INTO resourceStates_log (resourceId,changeState,dateStart,finaudDecision)
              VALUES ($resource_id, \"$state\",\"$date\",\"$finaud\")
             ");
}


# set_node_nextState
# sets the nextState field of a node identified by its networkAddress
# parameters : base, networkAddress, nextState
# return value : /
sub set_node_nextState($$$) {
    my $dbh = shift;
    my $hostname = shift;
    my $nextState = shift;

    my $result = $dbh->do(" UPDATE resources
                            SET nextState = \"$nextState\", nextFinaudDecision = \"NO\"
                            WHERE networkAddress = \"$hostname\"
                          ");
    return($result);
}


# update_resource_nextFinaudDecision
# update nextFinaudDecision field
# parameters : base, resourceId, "YES" or "NO"
sub update_resource_nextFinaudDecision($$$){
    my $dbh = shift;
    my $resourceId = shift;
    my $finaud = shift;

    $dbh->do("  UPDATE resources
                SET nextFinaudDecision = \"$finaud\"
                WHERE
                    resourceId = $resourceId
             ");
}


# set_node_expiryDate
# sets the expiryDate field of some node identified by its hostname in the base.
# parameters : base, hostname, expiryDate
# return value : /
# side effects : changes the expiryDate value in some field of the nodeProperties table
sub set_node_expiryDate($$$) {
    my $dbh = shift;
    my $hostname = shift;
    my $expiryDate = shift;

		# FIX ME: check first that the expiryDate is actually in the future, return error else
    $dbh->do("UPDATE nodeProperties SET expiryDate = $expiryDate
              WHERE hostname =\"$hostname\"");
}


# set a node property
# change resourceProperties table value for resources with the specified networkAddress
# parameters : base, hostname, property name, value
# return : 0 if all is good, otherwise 1 if the property does not exist or the value is incorrect
sub set_node_property($$$$){
    my $dbh = shift;
    my $hostname = shift;
    my $property = shift;
    my $value = shift;

    # Test if we must change the property
    my $nbRowsAffected;
    eval{
        $nbRowsAffected = $dbh->do("UPDATE resources a, resourceProperties b
                                    SET b.$property = \"$value\"
                                    WHERE 
                                        a.networkAddress =\"$hostname\"
                                        AND a.resourceId = b.resourceId
                                    ");
    };
    if ($nbRowsAffected < 1){
        return(1);
    }else{
        #Update LOG table
        my $date = get_date($dbh);
        $dbh->do("  UPDATE resources a, resourceProperties_log b
                    SET b.dateStop = \"$date\"
                    WHERE
                        b.dateStop IS NULL
                        AND a.networkAddress = \"$hostname\"
                        AND b.attribute = \"$property\"
                 ");
        $dbh->do("  INSERT INTO resourceProperties_log (resourceId,attribute,value,dateStart)
                        SELECT a.resourceId, \"$property\", \"$value\", \"$date\"
                        FROM resources a
                        WHERE
                            a.networkAddress = \"$hostname\"
                  ");
        return(0);
    }
}


# set a resource property
# change resourceProperties table value for resource specified
# parameters : base, resource, property name, value
# return : 0 if all is good, otherwise 1 if the property does not exist or the value is incorrect
sub set_resource_property($$$$){
    my $dbh = shift;
    my $resource = shift;
    my $property = shift;
    my $value = shift;

    # Test if we must change the property
    my $nbRowsAffected;
    eval{
        $nbRowsAffected = $dbh->do("UPDATE resourceProperties a
                                    SET a.$property = \"$value\"
                                    WHERE 
                                        a.resourceId = \"$resource\"
                                   ");
    };
    if ($nbRowsAffected < 1){
        return(1);
    }else{
        #Update LOG table
        my $date = get_date($dbh);
        $dbh->do("  UPDATE resourceProperties_log a
                    SET a.dateStop = \"$date\"
                    WHERE
                        a.dateStop IS NULL
                        AND a.resourceId = \"$resource\"
                        AND a.attribute = \"$property\"
                 ");
        $dbh->do("  INSERT INTO resourceProperties_log (resourceId,attribute,value,dateStart)
                    VALUES ($resource, \"$property\", \"$value\", \"$date\")
                 ");
        return(0);
    }
}


# return all properties for a specific resource
# parameters : base, resource
sub get_resource_properties($$){
    my $dbh = shift;
    my $resource = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM resourceProperties
                                WHERE
                                    resourceId = $resource");
    $sth->execute();
    my %results = %{$sth->fetchrow_hashref()};
    $sth->finish();

    return(%results);
}


# return all properties for all nodes
# parameters : base, hostname
sub get_all_nodes_properties($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT * FROM nodeProperties");
    $sth->execute();
    
    my %res ;
    while (my $ref = $sth->fetchrow_hashref()) {
        #push(@res, $ref->{'idJob'}, $ref->{'jobType'}, $ref->{'infoType'});
        #push(@res, $ref);
        $res{$ref->{hostname}} = $ref;
    }
    $sth->finish();

    return(%res);
}


# get resource names that will change their state
# parameters : base
sub get_resources_change_state($){
    my $dbh = shift;

    my $sth = $dbh->prepare("   SELECT resourceId, nextState
                                FROM resources
                                WHERE
                                    nextState != \"UnChanged\"");
    $sth->execute();

    my %results;
    while (my @ref = $sth->fetchrow_array()) {
        $results{$ref[0]} = $ref[1];
    }
    $sth->finish();

    return %results;
}



#get the range when nodes are dead between two dates
# arg : base, start date, end date
sub get_node_dead_range_date($$$){
    my $dbh = shift;
    my $dateStart = shift;
    my $dateEnd = shift;

    # get dead node between two dates
    my $sth = $dbh->prepare("SELECT hostname,dateStart,dateStop,changeState
                             FROM nodeState_log
                             WHERE
                                   (changeState = \"Absent\"
                                    OR changeState = \"Dead\"
                                    OR changeState = \"Suspected\"
                                   )
                                   AND dateStart <= \"$dateEnd\"
                                   AND (dateStop IS NULL OR dateStop >= \"$dateStart\")
                            ");
    $sth->execute();

    my %results;
    while (my @ref = $sth->fetchrow_array()) {
        my $interval_stopDate = $ref[2];
        if (!defined($interval_stopDate)){
            $interval_stopDate = $dateEnd;
        }
        push(@{$results{$ref[0]}}, [$ref[1],$interval_stopDate,$ref[3]]);
    }
    $sth->finish();

    return %results;
}

# get_expired_nodes
# get the list of node whose expiryDate is in the past and which are not dead yet.
# 0000-00-00 00:00:00 is always considered as in the future
# parameters: base
# return value: list of nodes hostnames
# side effects: /
sub get_expired_nodes($){
	  my $dbh = shift;
    # get expired nodes
    my $sth = $dbh->prepare("SELECT n.hostname
                             FROM nodes n, nodeProperties np
                             WHERE n.hostname = np.hostname
														 AND n.state = \"Alive\"
                             AND np.expiryDate != \"0000-00-00 00:00:00\"
                             AND np.expiryDate < NOW()");
    $sth->execute();
    my @results = $sth->fetchrow_array();
    $sth->finish();
    return @results;
}

# is_node_desktop_computing
# tell if a node is for desktop computing.
# parameters: base, hostname
# return value: boolean
# side effects: /
sub is_node_desktop_computing($$){
    my $dbh = shift;
    my $hostname = shift;
    my $sth = $dbh->prepare("SELECT desktopComputing FROM nodeProperties WHERE hostname=\"$hostname\"");
    $sth->execute();
    my ($res) = $sth->fetchrow_array();
		return $res;
}


#Give some stats on nodes
#parameters : base
sub get_node_stats($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT count(*) FROM nodes WHERE state = \"Suspected\"");
    $sth->execute();
    my ($suspects) = $sth->fetchrow_array();
    $sth->finish();

    $sth = $dbh->prepare("SELECT count(*) FROM nodes WHERE state = \"Alive\" AND weight = 0");
    $sth->execute();
    my ($alives) = $sth->fetchrow_array();
    $sth->finish();

    $sth = $dbh->prepare("SELECT count(*) FROM nodes WHERE state = \"Dead\"");
    $sth->execute();
    my ($deads) = $sth->fetchrow_array();
    $sth->finish();

    return ($alives,$suspects,$deads);
}


# Return a data structure with the resource description of the given job
# arg : database ref, job id
# return a data structure (an array of moldable jobs):
# example for the first moldable job of the list:
# $result->[0] = [
#                   [
#                       {
#                           property  => SQL property
#                           resources => [
#                                           {
#                                               resource => resource name
#                                               value    => number of this wanted resource
#                                           }
#                                       ]
#                       }
#                   ],
#                   walltime,
#                   moldable_job_id
#                ]
sub get_resources_data_structure_current_job($$){
    my $dbh = shift;
    my $job_id = shift;

    my $sth = $dbh->prepare("   SELECT a.moldableId, b.resGroupId, a.moldableWalltime, b.resGroupProperty, c.resJobResourceType, c.resJobValue
                                FROM moldableJobs_description a, jobResources_group b, jobResources_description c, jobs d
                                WHERE
                                    a.moldableIndex = \"CURRENT\"
                                    AND b.resGroupIndex = \"CURRENT\"
                                    AND c.resJobIndex = \"CURRENT\"
                                    AND d.idJob = $job_id
                                    AND d.idJob = a.moldableJobId
                                    AND b.resGroupMoldableId = a.moldableId
                                    AND c.resJobGroupId = b.resGroupId
                                ORDER BY a.moldableId, b.resGroupId, c.resJobOrder ASC
                            ");
    $sth->execute();
    my $result;
    my $group_index = -1;
    my $moldable_index = -1;
    my $previous_group = 0;
    my $previous_moldable = 0;
    while (my @ref = $sth->fetchrow_array()){
        if ($previous_group != $ref[1]){
            $group_index++;
            $previous_group = $ref[1];
        }
        if ($previous_moldable != $ref[0]){
            $moldable_index++;
            $previous_moldable = $ref[0];
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


# Order the node list with specified argument
# parameters : base, node list array pointer, order spec
sub order_property_node($$$){
    my $dbh = shift;
    my $nodeList = shift;
    my $orderClause = shift;

    my @result;
    if (scalar(@{$nodeList}) > 0){
        # construct WHERE clause
        my $whereClause;
        foreach my $n (@{$nodeList}){
            if (!defined($whereClause)){
                $whereClause = "n.hostname = \"$n\"";
            }else{
                $whereClause .= " OR n.hostname = \"$n\""
            }
        }
        my $sth = $dbh->prepare("SELECT n.hostname
                                 FROM nodes n, nodeProperties p
                                 WHERE n.hostname = p.hostname
                                    AND ($whereClause)                     
                                 ORDER BY $orderClause");
        $sth->execute();
        while (my @ref = $sth->fetchrow_array()) {
            push(@result, $ref[0]);
        }
        $sth->finish();
    }

    return(@result);
}


# QUEUES MANAGEMENT

# get_queues
# create the list of queues sorted by descending priority
# only return the Active queues.
# return value : list of queues
# side effects : /
sub get_active_queues($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("   SELECT queueName,schedulerPolicy
                                FROM queues
                                WHERE
                                    state = \"Active\"
                                ORDER BY priority DESC
                            ");
    $sth->execute();
    my @res ;
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, [ $ref->{'queueName'}, $ref->{'schedulerPolicy'} ]);
    }
    $sth->finish();
    return @res;
}


# get_all_queue_informations
# return a hashtable with all queues and their properties
sub get_all_queue_informations($){
    my $dbh = shift;
    
    my $sth = $dbh->prepare("SELECT *
                             FROM queues");
    $sth->execute();
    my %res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        $res{$ref->{queueName}} = $ref ;
    }
    $sth->finish();
   
    return %res;
}



# GANTT MANAGEMENT

#get previous scheduler decisions
#args : base
#return a hashtable : idJob --> [startTime,walltime,queueName,\@resources,state]
sub get_gantt_scheduled_jobs($){
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT j.idJob, g2.startTime, m.moldableWalltime, g1.idResource, j.queueName, j.state
                             FROM ganttJobsResources g1, ganttJobsPredictions g2, moldableJobs_description m, jobs j
                             WHERE
                                m.moldableIndex = \"CURRENT\"
                                AND g1.idMoldableJob = g2.idMoldableJob
                                AND m.moldableId = g2.idMoldableJob
                                AND j.idJob = m.moldableJobId
                            ");
    $sth->execute();
    my %res ;
    while (my @ref = $sth->fetchrow_array()) {
        if (!defined($res{$ref[0]})){
            $res{$ref[0]}->[0] = $ref[1];
            $res{$ref[0]}->[1] = $ref[2];
            $res{$ref[0]}->[2] = $ref[4];
#            $res{$ref[0]}->[3] = $ref[3];
            $res{$ref[0]}->[4] = $ref[5];
        }
        push(@{$res{$ref[0]}->[3]}, $ref[3]);
    }
    $sth->finish();

    return %res;
}


#get previous scheduler decisions for visu
#args : base
#return a hashtable : idJob --> [startTime,weight,walltime,queueName,\@nodes]
sub get_gantt_visu_scheduled_jobs($){
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT g2.idJob, g2.startTime, j.weight, j.maxTime, g1.hostname, j.queueName, j.state
                             FROM ganttJobsNodes_visu g1, ganttJobsPrediction_visu g2, jobs j
                             WHERE g1.idJob = g2.idJob
                                AND j.idJob = g1.idJob
                            ");
    $sth->execute();
    my %res ;
    while (my @ref = $sth->fetchrow_array()) {
        if (!defined($res{$ref[0]})){
            $res{$ref[0]}->[0] = $ref[1];
            $res{$ref[0]}->[1] = $ref[2];
            $res{$ref[0]}->[2] = $ref[3];
            $res{$ref[0]}->[3] = $ref[5];
            $res{$ref[0]}->[5] = $ref[6];
        }
        push(@{$res{$ref[0]}->[4]}, $ref[4]);
    }
    $sth->finish();

    return %res;
}


#add scheduler decisions
#args : base,idMoldableJob,startTime,\@resources
#return nothing
sub add_gantt_scheduled_jobs($$$$){
    my $dbh = shift;
    my $id_moldable_job = shift;
    my $start_time = shift;
    my $resource_list = shift;

    $dbh->do("INSERT INTO ganttJobsPredictions (idMoldableJob,startTime)
              VALUES ($id_moldable_job,\"$start_time\")
             ");

    foreach my $i (@{$resource_list}){
        $dbh->do("INSERT INTO ganttJobsResources (idMoldableJob,idResource)
                  VALUES ($id_moldable_job,$i)
                 ");
    }
}


# Remove an entry in the gantt
# params: base, idJob, resource
sub remove_gantt_resource_job($$$){
    my $dbh = shift;
    my $job = shift;
    my $resource = shift;

    $dbh->do("DELETE FROM ganttJobsResources WHERE idMoldableJob = $job AND idResource = $resource");
}



# Add gantt date (now) in database
# args : base, date
sub set_gantt_date($$){
    my $dbh = shift;
    my $date = shift;

    $dbh->do("INSERT INTO ganttJobsPredictions (idMoldableJob,startTime)
              VALUES (0,\"$date\")
             ");
}


# Update startTime in gantt for a specified job
# args : base, job id, date
sub set_gantt_job_startTime($$$){
    my $dbh = shift;
    my $job = shift;
    my $date = shift;

    $dbh->do("UPDATE ganttJobsPredictions
              SET startTime = \"$date\"
              WHERE idMoldableJob = $job
             ");
}


# Get startTime for a given job
# args : base, job id
sub get_gantt_job_startTime($$){
    my $dbh = shift;
    my $job = shift;

    my $sth = $dbh->prepare("SELECT ganttJobsPredictions.startTime, ganttJobsPredictions.idMoldableJob
                             FROM ganttJobsPredictions,moldableJobs_description
                             WHERE
                                moldableJobs_description.moldableJobId = $job
                                AND ganttJobsPredictions.idMoldableJob = moldableJobs_description.moldableId
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


# Update ganttJobsPrediction_visu and ganttJobsNodes_visu with values in ganttJobsPrediction and in ganttJobsNodes
# arg: database ref
sub update_gantt_visualization($){
    my $dbh = shift;

    $dbh->do("LOCK TABLE ganttJobsPredictions_visu WRITE, ganttJobsResources_visu WRITE, ganttJobsPredictions WRITE, ganttJobsResources WRITE");

    $dbh->do("DELETE FROM ganttJobsPredictions_visu");
    $dbh->do("DELETE FROM ganttJobsResources_visu");
#    $dbh->do("OPTIMIZE TABLE ganttJobsResources_visu, ganttJobsPredictions_visu");

    $dbh->do("INSERT INTO ganttJobsPredictions_visu
              SELECT *
              FROM ganttJobsPredictions
             ");
    
    $dbh->do("INSERT INTO ganttJobsResources_visu
              SELECT *
              FROM ganttJobsResources
             ");

    $dbh->do("UNLOCK TABLES");
}



# Return date of the gantt
sub get_gantt_date($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT startTime
                             FROM ganttJobsPredictions
                             WHERE
                                idMoldableJob = 0
                            ");
    $sth->execute();
    my @res = $sth->fetchrow_array();
    $sth->finish();

    return $res[0];
}


# Return date of the gantt for visu
sub get_gantt_visu_date($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT startTime
                             FROM ganttJobsPredictions_visu
                             WHERE
                                idMoldableJob = 0
                            ");
    $sth->execute();
    my @res = $sth->fetchrow_array();
    $sth->finish();

    return $res[0];
}


#Flush gantt tables
sub gantt_flush_tables($){
    my $dbh = shift;

    #$dbh->do("TRUNCATE TABLE ganttJobsPrediction");
    $dbh->do("DELETE FROM ganttJobsPredictions");
    #$dbh->do("TRUNCATE TABLE ganttJobsNodes");
    $dbh->do("DELETE FROM ganttJobsResources");
    
#    $dbh->do("OPTIMIZE TABLE ganttJobs, ganttJobsPrediction");
}



#Get jobs to launch at a given date
#args : base, date in sql format
sub get_gantt_jobs_to_launch($$){
    my $dbh = shift;
    my $date = shift;

    my $sth = $dbh->prepare("SELECT g2.idMoldableJob, g1.idResource, j.idJob
                             FROM ganttJobsResources g1, ganttJobsPredictions g2, jobs j, moldableJobs_description m
                             WHERE
                                m.moldableIndex = \"CURRENT\"
                                AND g1.idMoldableJob= g2.idMoldableJob
                                AND m.moldableId = g1.idMoldableJob
                                AND j.idJob = m.moldableJobId
                                AND g2.startTime <= \"$date\"
                                AND j.state = \"Waiting\"
                            ");
    $sth->execute();
    my %res ;
    while (my @ref = $sth->fetchrow_array()) {
        $res{$ref[2]}->[0] = $ref[0];
        push(@{$res{$ref[2]}->[1]}, $ref[1]);
    }
    $sth->finish();

    return %res;
}



#Get informations about resources for jobs to launch at a given date
#args : base, date in sql format
sub get_gantt_resources_for_jobs_to_launch($$){
    my $dbh = shift;
    my $date = shift;

    my $sth = $dbh->prepare("SELECT g1.idResource
                             FROM ganttJobsResources g1, ganttJobsPredictions g2, jobs j, moldableJobs_description m
                             WHERE
                                m.moldableIndex = \"CURRENT\"
                                AND g1.idMoldableJob = m.moldableId
                                AND m.moldableJobId = j.idJob
                                AND g1.idMoldableJob = g2.idMoldableJob
                                AND g2.startTime <= \"$date\"
                                AND j.state = \"Waiting\"
                             GROUP BY g1.idResource
                            ");
    $sth->execute();
    my %res ;
    while (my @ref = $sth->fetchrow_array()) {
        $res{$ref[0]} = 1; 
    }
    $sth->finish();

    return %res;
}


#Get resources for job in the gantt diagram
#args : base, job id
sub get_gantt_resources_for_job($$){
    my $dbh = shift;
    my $job = shift;

    my $sth = $dbh->prepare("SELECT g.idResource
                             FROM ganttJobsResources g
                             WHERE
                                g.idMoldableJob = $job 
                            ");
    $sth->execute();
    my @res ;
    while (my @ref = $sth->fetchrow_array()) {
        push( @res, $ref[0]); 
    }
    $sth->finish();

    return @res;
}


#Get Alive resources for a job
#args : base, job id
sub get_gantt_Alive_resources_for_job($$){
    my $dbh = shift;
    my $job = shift;

    my $sth = $dbh->prepare("SELECT g.idResource
                             FROM ganttJobsResources g, resources r
                             WHERE
                                g.idMoldableJob = $job 
                                AND r.resourceId = g.idResource
                                AND r.state = \"Alive\"
                            ");
    $sth->execute();
    my @res ;
    while (my @ref = $sth->fetchrow_array()) {
        push( @res, $ref[0]); 
    }
    $sth->finish();

    return(@res);
}


# TIME CONVERSION

# ymdhms_to_sql
# converts a date specified as year, month, day, minutes, secondes to a string
# in the format used by the sql database
# parameters : year, month, day, hours, minutes, secondes
# return value : date string
# side effects : /
sub ymdhms_to_sql($$$$$$) {
    my ($year,$mon,$mday,$hour,$min,$sec)=@_;
    return ($year+1900)."-".($mon+1)."-".$mday." $hour:$min:$sec";
}



# sql_to_ymdhms
# converts a date specified in the format used by the sql database to year,
# month, day, minutes, secondes values
# parameters : date string
# return value : year, month, day, hours, minutes, secondes
# side effects : /
sub sql_to_ymdhms($) {
    my $date=shift;
    $date =~ tr/-:/  /;
    my ($year,$mon,$mday,$hour,$min,$sec) = split / /,$date;
    # adjustment for localtime (since 1st january 1900, month from 0 to 11)
    $year-=1900;
    $mon-=1;
    return ($year,$mon,$mday,$hour,$min,$sec);
}



# ymdhms_to_local
# converts a date specified as year, month, day, minutes, secondes into an
# integer local time format
# parameters : year, month, day, hours, minutes, secondes
# return value : date integer
# side effects : /
sub ymdhms_to_local($$$$$$) {
    my ($year,$mon,$mday,$hour,$min,$sec)=@_;
    return Time::Local::timelocal_nocheck($sec,$min,$hour,$mday,$mon,$year);
}



# local_to_ymdhms
# converts a date specified into an integer local time format to year, month,
# day, minutes, secondes values
# parameters : date integer
# return value : year, month, day, hours, minutes, secondes
# side effects : /
sub local_to_ymdhms($) {
    my $date=shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($date);
    $year += 1900;
    $mon += 1;
    return ($year,$mon,$mday,$hour,$min,$sec);
}



# sql_to_local
# converts a date specified in the format used by the sql database to an
# integer local time format
# parameters : date string
# return value : date integer
# side effects : /
sub sql_to_local($) {
    my $date=shift;
    my ($year,$mon,$mday,$hour,$min,$sec)=sql_to_ymdhms($date);
    #if ($year <= 1971){
    #    return(0);
    #}else{
        return ymdhms_to_local($year,$mon,$mday,$hour,$min,$sec);
    #}
}



# local_to_sql
# converts a date specified in an integer local time format to the format used
# by the sql database
# parameters : date integer
# return value : date string
# side effects : /
sub local_to_sql($) {
    my $local=shift;
    my ($year,$mon,$mday,$hour,$min,$sec)=local_to_ymdhms($local);
    #return ymdhms_to_sql($year,$mon,$mday,$hour,$min,$sec);
    return $year."-".$mon."-".$mday." $hour:$min:$sec";
}



# sql_to_hms
# converts a date specified in the format used by the sql database to hours,
# minutes, secondes values
# parameters : date string
# return value : hours, minutes, secondes
# side effects : /
sub sql_to_hms($) {
    my $date=shift;
    my ($hour,$min,$sec) = split /:/,$date;
    return ($hour,$min,$sec);
}



# hms_to_duration
# converts a date specified in hours, minutes, secondes values to a duration
# in seconds
# parameters : hours, minutes, secondes
# return value : duration
# side effects : /
sub hms_to_duration($$$) {
    my ($hour,$min,$sec) = @_;
    return $hour*3600 +$min*60 +$sec;
}



# hms_to_sql
# converts a date specified in hours, minutes, secondes values to the format
# used by the sql database
# parameters : hours, minutes, secondes
# return value : date string
# side effects : /
sub hms_to_sql($$$) {
    my ($hour,$min,$sec) = @_;
    return "$hour:$min:$sec";
}



# duration_to_hms
# converts a date specified as a duration in seconds to hours, minutes,
# secondes values
# parameters : duration
# return value : hours, minutes, secondes
# side effects : /
sub duration_to_hms($) {
    my $date=shift;
    my $sec=$date%60;
    $date/=60;
    my $min=$date%60;
    $date/=60;
    my $hour=$date;
    return ($hour,$min,$sec);
}



# duration_to_sql
# converts a date specified as a duration in seconds to the format used by the
# sql database
# parameters : duration
# return value : date string
# side effects : /
sub duration_to_sql($) {
    my $duration=shift;
    my ($hour,$min,$sec)=duration_to_hms($duration);
    return hms_to_sql($hour,$min,$sec);
}



# sql_to_duration
# converts a date specified in the format used by the sql database to a
# duration in seconds
# parameters : date string
# return value : duration
# side effects : /
sub sql_to_duration($) {
    my $date=shift;
    my ($hour,$min,$sec)=sql_to_hms($date);
    return hms_to_duration($hour,$min,$sec);
}



# get_date
# returns the current time in the format used by the sql database
# parameters : database
# return value : date string
# side effects : /
sub get_date($) {
    #my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    #return ymdhms_to_sql($year,$mon,$mday,$hour,$min,$sec);

    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT NOW()");
    $sth->execute();
    my @ref = $sth->fetchrow_array();
    $sth->finish();

    return($ref[0]);
}


# get_unix_timestamp
# returns seconds since epoch 00:00:00 01-01-1970
# parameters : database
# return value : int
# side effects : /
sub get_unix_timestamp($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT UNIX_TIMESTAMP()");
    $sth->execute();
    my ($timestamp) = $sth->fetchrow_array();
    $sth->finish();

    return($timestamp);
}


# ACCOUNTING

# check jobs that are not treated in accounting table
# params : base, window size
sub check_accounting_update($$){
    my $dbh = shift;
    my $windowSize = shift;

    my $sth = $dbh->prepare("SELECT *
                             FROM jobs
                             WHERE accounted = \"NO\"
                                AND (state = \"Terminated\" OR state = \"Error\")
                                AND stopTime >= startTime
                                AND startTime > \"0000-00-00 00:00:00\"
                                AND maxTime > 0
                                ");
    $sth->execute();

    while (my $ref = $sth->fetchrow_hashref()) {
        my $start = sql_to_local($ref->{startTime});
        my $stop = sql_to_local($ref->{stopTime});
        my $theoricalStopTime = sql_to_duration($ref->{maxTime}) + $start;
        oar_debug("[ACCOUNTING] Treate job $ref->{idJob}\n");
        update_accounting($dbh,$start,$stop,$windowSize,$ref->{user},$ref->{queueName},"USED",$ref->{nbNodes},$ref->{weight});
        update_accounting($dbh,$start,$theoricalStopTime,$windowSize,$ref->{user},$ref->{queueName},"ASKED",$ref->{nbNodes},$ref->{weight});
        $dbh->do("UPDATE jobs SET accounted = \"YES\" WHERE idJob = $ref->{idJob}");
    }
}

# insert accounting data in table accounting
# params : base, start date in second, stop date in second, window size, user, queue, type(ASKED or USED)
sub update_accounting($$$$$$$$$){
    my $dbh = shift;
    my $start = shift;
    my $stop = shift;
    my $windowSize = shift;
    my $user = shift;
    my $queue = shift;
    my $type = shift;
    my $nbNodes = shift;
    my $weight = shift;

    use integer;

    my $nbWindows = $start / $windowSize;
    my $windowStart = $nbWindows * $windowSize;
    my $windowStop = $windowStart + $windowSize - 1;
   
    my $conso;
    # Accounting algo
    while ($stop > $start){
        if ($stop <= $windowStop){
            $conso = $stop - $start;
        }else{
            $conso = $windowStop - $start + 1;
        }
        $conso = $conso * $nbNodes * $weight;
        add_accounting_row($dbh,local_to_sql($windowStart),local_to_sql($windowStop),$user,$queue,$type,$conso);
        $windowStart = $windowStop + 1;
        $start = $windowStart;
        $windowStop += $windowSize;
    }
}

# start and stop in SQL syntax
sub add_accounting_row($$$$$$$){
    my $dbh = shift;
    my $start = shift;
    my $stop = shift;
    my $user = shift;
    my $queue = shift;
    my $type = shift;
    my $conso = shift;

    # Test if the window exists
    my $sth = $dbh->prepare("   SELECT * 
                                FROM accounting
                                WHERE   user = \"$user\"
                                    AND consumption_type = \"$type\"
                                    AND queue_name = \"$queue\"
                                    AND window_start = \"$start\"
                                    AND window_stop = \"$stop\"
                            ");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    if (defined($ref->{consumption})){
        # Update the existing window
        $conso += $ref->{consumption};
        oar_debug("[ACCOUNTING] Update the existing window $start --> $stop , user $user, queue $queue, type $type with conso = $conso\n");
        $dbh->do("  UPDATE accounting
                    SET consumption = $conso
                    WHERE   user = \"$user\"
                        AND consumption_type = \"$type\"
                        AND queue_name = \"$queue\"
                        AND window_start = \"$start\"
                        AND window_stop = \"$stop\"
                ");
    }else{
        # Create the window
        oar_debug("[ACCOUNTING] Create new window $start --> $stop , user $user, queue $queue, type $type with conso = $conso\n");
        $dbh->do("  INSERT INTO accounting (user,consumption_type,queue_name,window_start,window_stop,consumption)
                    VALUES (\"$user\",\"$type\",\"$queue\",\"$start\",\"$stop\",$conso)
                 ");
    }
}


#EVENTS LOG MANAGEMENT

#add a new entry in event_log table
#args : database ref, event type, idJob , description
sub add_new_event($$$$){
    my $dbh = shift;
    my $type = shift;
    my $idJob = shift;
    my $description = shift;

    my $date = get_date($dbh);
    $dbh->do("INSERT INTO events_log (type,idJob,date,description) VALUES (\"$type\",$idJob,\"$date\",\"$description\")");
    my $sth = $dbh->prepare("SELECT LAST_INSERT_ID()");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my ($idFile) = values(%$ref);
    $sth->finish();
}

#add a new entry in event_log_hosts table
#args : database ref, type, job id, description, ref of an array of resource ids
sub add_new_event_with_host($$$$$){
    my $dbh = shift;
    my $type = shift;
    my $idJob = shift;
    my $description = shift;
    my $hostnames = shift;
    
    my $date = get_date($dbh);
    #$dbh->do("LOCK TABLE event_log WRITE, event_log_hosts WRITE");
    $dbh->do("  INSERT INTO events_log (type,idJob,date,description)
                VALUES (\"$type\",$idJob,\"$date\",\"$description\")
             ");
    my $sth = $dbh->prepare("SELECT LAST_INSERT_ID()");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my ($idEvent) = values(%$ref);
    $sth->finish();
    
    foreach my $n (@{$hostnames}){
        $dbh->do("  INSERT INTO events_log_hostnames (idEvent,hostname)
                    VALUES ($idEvent,\"$n\")
                 ");
    }
    #$dbh->do("UNLOCK TABLES");
}


# Turn the field toCheck into NO
#args : database ref, event type, idJob
sub check_event($$$){
    my $dbh = shift;
    my $type = shift;
    my $idJob = shift;

    $dbh->do("  UPDATE events_log
                SET toCheck = \"NO\"
                WHERE
                    toCheck = \"YES\"
                    AND type = \"$type\"
                    AND idJob = $idJob
             ");
}


# Get all events with toCheck field on YES
# args: database ref
sub get_to_check_events($){
    my $dbh = shift;
    my $sth = $dbh->prepare("   SELECT type, idJob, idEvent 
                                FROM events_log
                                WHERE
                                    toCheck = \"YES\"
                            ");
    $sth->execute();

    my @results;
    while (my $ref = $sth->fetchrow_hashref()) {
        my %tmp = ( 'type' => $ref->{type},
                    'idJob' => $ref->{idJob},
                    'idEvent' => $ref->{idEvent}
                  );
        push(@results, \%tmp);
    }
    $sth->finish();
    
    return(@results);
}

# Get hostnames corresponding to an event Id
# args: database ref, event id
sub get_hostname_event($$){
    my $dbh = shift;
    my $eventId = shift;

    my $sth = $dbh->prepare("   SELECT hostname
                                FROM events_log_hostnames
                                WHERE
                                    idEvent = $eventId
                            ");
    $sth->execute();

    my @results;
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@results, $ref->{hostname});
    }
    $sth->finish();

    return(@results);
}


# Get events for the specified job
# args: database ref, job id
sub get_job_events($$){
    my $dbh =shift;
    my $jobId = shift;

    my $sth = $dbh->prepare("SELECT * FROM event_log WHERE idJob = $jobId");
    $sth->execute();

    my @results;
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@results, $ref);
    }
    $sth->finish();

    return(@results);
}

# LOCK FUNCTIONS:

# get_lock
# lock a mysql mutex variable
# parameters : base, mutex, timeout
# return value : 1 if the lock was obtained successfully, 0 if the attempt timed out or undef if an error occurred  
# side effects : a second get_lock of the same mutex will be blocked until release_lock is called on the mutex
sub get_lock($$$) {
    my $dbh = shift;
    my $mutex = shift;
    my $timeout = shift;

    my $sth = $dbh->prepare("SELECT GET_LOCK(\"$mutex\",$timeout)");
    $sth->execute();
    my ($res) = $sth->fetchrow_array();
    $sth->finish();
		if ($res eq "0") {
        return 0;
    } elsif ($res eq "1") {
        return 1;
    }
    return undef;
}

# release_lock
# unlock a mysql mutex variable
# parameters : base, mutex
# return value : 1 if the lock was released, 0 if the lock wasn't locked by this thread , and NULL if the named lock didn't exist
# side effects : unlock the mutex, a blocked get_lock may be unblocked
sub release_lock($$) {
    my $dbh = shift;
    my $mutex = shift;

    my $sth = $dbh->prepare("SELECT RELEASE_LOCK(\"$mutex\")");
    $sth->execute();
    my ($res) = $sth->fetchrow_array();
    $sth->finish();
		if ($res eq "0") {
        return 0;
    } elsif ($res eq "1") {
        return 1;
    }
    return undef;
}


# END OF THE MODULE
return 1;
