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
use oar_Tools;

# PROTOTYPES

# CONNECTION
sub connect();
sub connect_ro();
sub disconnect($);

# JOBS MANAGEMENT
sub get_job_challenge($$);
sub get_jobs_in_state($$);
sub is_job_desktopComputing($$);
sub get_job_current_hostnames($$);
sub get_job_current_resources($$);
sub get_job_host_log($$);
sub get_to_kill_jobs($);
sub is_tokill_job($$);
sub get_timered_job($);
sub get_to_exterminate_jobs($);
sub get_frag_date($$);
sub set_running_date($$);
sub set_running_date_arbitrary($$$);
sub set_assigned_moldable_job($$$);
sub set_finish_date($$);
sub get_possible_wanted_resources($$$$$);
sub add_micheline_job($$$$$$$$$$$$$$$$$$$);
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
sub get_waiting_reservation_jobs($);
sub get_waiting_reservation_jobs_specific_queue($$);
sub get_waiting_toSchedule_reservation_jobs_specific_queue($$);
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
sub get_resource_job($$);
sub get_node_job($$);
sub get_resources_in_state($$);
sub add_resource_job_pair($$$);

# RESOURCES MANAGEMENT
sub add_resource($$$);
sub list_nodes($);
sub get_resource_info($$);
sub is_node_exists($$);
sub get_resources_on_node($$);
sub set_node_state($$$$);
sub update_resource_nextFinaudDecision($$$);
sub get_resources_change_state($);
sub set_resource_nextState($$$);
sub set_node_nextState($$$);
sub set_node_expiryDate($$$);
sub set_node_property($$$$);
sub set_resource_property($$$$);
sub get_node_dead_range_date($$$);
sub get_expired_nodes($);
sub is_node_desktop_computing($$);
sub get_node_stats($);
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

my $Db_type = "mysql";

# CONNECTION

# connect_db
# Connects to database and returns the base identifier
# return value : base
sub connect_db($$$$) {
    my $host = shift;
    my $name = shift;
    my $user = shift;
    my $pwd = shift;

    my $type;
    if ($Db_type eq "Pg"){
        $type = "Pg";
    }elsif ($Db_type eq "mysql"){
        $type = "mysql";
    }else{
        oar_Judas::oar_error("[IOlib] Cannot recognize DB_TYPE tag \"$Db_type\". So we are using \"mysql\" type.\n");
        $type = "mysql";
        $Db_type = "mysql";
    }

    my $maxConnectTries = 5;
    my $nbConnectTry = 0;
    my $dbh = undef;
    while ((!defined($dbh)) && ($nbConnectTry < $maxConnectTries)){
        $dbh = DBI->connect("DBI:$type:database=$name;host=$host", $user, $pwd, {'InactiveDestroy' => 1});
        
        if (!defined($dbh)){
            oar_Judas::oar_error("[IOlib] Cannot connect to database (type=$Db_type, host=$host, user=$user, database=$name) : $DBI::errstr\n");
            $nbConnectTry++;
            if ($nbConnectTry < $maxConnectTries){
                oar_Judas::oar_warn("[IOlib] I will retry to connect to the database in ".2*$nbConnectTry."s\n");
                sleep(2*$nbConnectTry);
            }
        }
    }
    
    if (!defined($dbh)){
        oar_Judas::oar_error("[IOlib] Max connection tries reached ($maxConnectTries).\n");
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
    $Db_type = get_conf("DB_TYPE");

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
    $Db_type = get_conf("DB_TYPE");

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


sub get_last_insert_id($$){
    my $dbh = shift;
    my $seq = shift;
    
    my $id;
    my $sth;
    if ($Db_type eq "Pg"){
        $sth = $dbh->prepare("SELECT CURRVAL('$seq')");
        $sth->execute();
        my $ref = $sth->fetchrow_hashref();
        my @tmp_array = values(%$ref);
        $id = $tmp_array[0];
        $sth->finish();
    }else{
        $sth = $dbh->prepare("SELECT LAST_INSERT_ID()");
        $sth->execute();
        my $ref = $sth->fetchrow_hashref();
        my @tmp_array = values(%$ref);
        $id = $tmp_array[0];
        $sth->finish();
    }

    return($id);
}


# JOBS MANAGEMENT

# get_job_challenge
# gets the challenge string of a OAR Job
# parameters : base, jobid
# return value : challenge
# side effects : /
sub get_job_challenge($$){
    my $dbh = shift;
    my $job_id = shift;
    
    my $sth = $dbh->prepare("SELECT challenge
                             FROM challenges
                             WHERE
                                job_id = $job_id
                            ");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    return($$ref{challenge});
}


# get_jobs_in_state
# returns the list of ids of jobs in the specified state
# parameters : base, job state
# return value : flatened list of (idJob, jobType, infoType) triples
# side effects : /
sub get_jobs_in_state($$) {
    my $dbh = shift;
    my $state = $dbh->quote(shift);

    my $sth = $dbh->prepare("   SELECT *
                                FROM jobs
                                WHERE
                                    state = $state
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

    my $sth = $dbh->prepare("SELECT distinct(resources.network_address) as hostname, resources.resource_id
                             FROM assigned_resources, resources, moldable_job_descriptions
                             WHERE 
                                assigned_resources.assigned_resource_index = \'CURRENT\'
                                AND moldable_job_descriptions.moldable_index = \'CURRENT\'
                                AND assigned_resources.resource_id = resources.resource_id
                                AND moldable_job_descriptions.moldable_id = assigned_resources.moldable_job_id
                                AND moldable_job_descriptions.moldable_job_id = $jobid
                             ORDER BY resources.resource_id ASC");
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

    my $sth = $dbh->prepare("SELECT resource_id as resource
                             FROM assigned_resources
                             WHERE 
                                assigned_resource_index = \'CURRENT\'
                                AND moldable_job_id = $jobid
                             ORDER BY resource_id ASC");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{resource});
    }
    return @res;
}


# get_job_resources
# returns the list of resources associated to the job passed in parameter
# parameters : base, jobid
# return value : list of resources
# side effects : /
sub get_job_resources($$) {
    my $dbh = shift;
    my $jobid= shift;

    my $sth = $dbh->prepare("SELECT resource_id as resource
                             FROM assigned_resources
                             WHERE 
                                moldable_job_id = $jobid
                             ORDER BY resource_id ASC");
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
    
    my $sth = $dbh->prepare("   SELECT resources.network_address, resources.resource_id
                                FROM assigned_resources, resources
                                WHERE
                                    assigned_resources.moldable_job_id = $moldablejobid
                                ORDER BY resources.resource_id ASC
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{network_address});
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
    my $sth = $dbh->prepare("   SELECT frag_id_job
                                FROM frag_jobs
                                WHERE
                                    frag_state = \'LEON\'
                                    AND frag_id_job = $jobid");
    $sth->execute();
    my @res = $sth->fetchrow_array();
    $sth->finish();
    return ($#res >= 0)
}

# get_to_kill_jobs
# returns the list of jobs that have their frag state to LEON
# parameters : base
# return value : list of jobid
# side effects : /
sub get_to_kill_jobs($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT jobs.*
                             FROM frag_jobs, jobs
                             WHERE
                                frag_state = \'LEON\'
                                AND jobs.job_id = frag_jobs.frag_id_job
                                AND jobs.state != \'Error\'
                                AND jobs.state != \'Terminated\'
                                AND jobs.state != \'Finishing\'
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    return(@res);
}



# get_timered_job
# returns the list of jobs that have their frag state to TIMER_ARMED
# parameters : base
# return value : list of jobid
# side effects : /
sub get_timered_job($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("   SELECT jobs.*
                                FROM frag_jobs, jobs
                                WHERE
                                    frag_jobs.frag_state = \'TIMER_ARMED\'
                                    AND frag_jobs.frag_id_job = jobs.job_id
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    return(@res);
}


# get_toexterminate_job
# returns the list of jobs that have their frag state to LEON_EXTERMINATE
# parameters : base
# return value : list of jobid
# side effects : /
sub get_to_exterminate_jobs($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("   SELECT jobs.*
                                FROM frag_jobs, jobs
                                WHERE
                                    frag_state = \'LEON_EXTERMINATE\'
                                    AND frag_jobs.frag_id_job = jobs.job_id
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    return(@res);
}


# set_assigned_moldable_job
# sets the assigned_moldable_job field to the given value
# parameters : base, jobid, moldable id
# return value : /
sub set_assigned_moldable_job($$$) {
    my $dbh = shift;
    my $idJob = shift;
    my $moldable = shift;
    
    $dbh->do("  UPDATE jobs
                SET assigned_moldable_job = $moldable
                WHERE
                    job_id = $idJob
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
                                SET start_time = \'$runningDate\'
                                WHERE
                                    job_id = $idJob
                            ");
    $sth->execute();
    $sth->finish();
}



# set_running_date_arbitrary
# sets the starting time of the job passed in parameter to arbitrary time
# parameters : base, jobid
# return value : /
# side effects : changes the field start_time of the job in the table Jobs
sub set_running_date_arbitrary($$$) {
    my $dbh = shift;
    my $idJob = shift;
    my $date = shift;

    $dbh->do("UPDATE jobs SET start_time = \'$date\'
              WHERE job_id = $idJob
             ");
}



# set_finish_date
# sets the maximal stoping time of the job passed in parameter to the current
# time
# parameters : base, jobid
# return value : /
# side effects : changes the field stop_time of the job in the table Jobs
sub set_finish_date($$) {
    my $dbh = shift;
    my $idJob = shift;
    
    my $finishDate;
    my $date = get_date($dbh);
    my $jobInfo = get_job($dbh,$idJob);
    my $minDate = $jobInfo->{'start_time'};
    if (sql_to_local($date) < sql_to_local($minDate)){
        $finishDate = $minDate;
    }else{
        $finishDate = $date;
    }
    my $sth = $dbh->prepare("   UPDATE jobs
                                SET stop_time = \'$finishDate\'
                                WHERE
                                    job_id = $idJob
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
            $sql .= " AND ".oar_resource_tree::get_current_resource_name($n)." = \'".oar_resource_tree::get_current_resource_value($n)."\'";
        }
    }
    if (defined($where_clause)){
        $sql .= " AND $where_clause";
    }
    #print("$sql\n");
    my $sth = $dbh->prepare("   SELECT count(DISTINCT($wanted_property_name))
                                FROM resource_properties
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
    my $possible_resources_vector = shift;
    my $impossible_resources_vector = shift;
    my $properties = shift;
    my $wanted_resources_ref = shift;

    my @wanted_resources = @{$wanted_resources_ref};
    push(@wanted_resources, {
                                resource => "resource_id",
                                value    => -1,
                            });
    
    #print(Dumper(@wanted_resources));
    my $sql_where_string = "TRUE";
    #if (defined($possible_resources->[0])){
    #    $sql_where_string = "resource_id IN(";
    #    foreach my $i (@{$possible_resources}){
    #        $sql_where_string .= "$i,";
    #    }
    #    chop($sql_where_string);
    #    $sql_where_string .= ") ";
    #}else{
    #    $sql_where_string = "TRUE ";
    #}

    #if (defined($impossible_resources->[0])){
    #    $sql_where_string .= "AND resource_id NOT IN (" ;
    #    foreach my $i (@{$impossible_resources}){
    #        $sql_where_string .= "$i,";
    #    }
    #    chop($sql_where_string);
    #    $sql_where_string .= ") ";
    #}
    
    #if ((defined($properties)) and ($properties =~ m/\w+/m)){
    if ((defined($properties)) and ($properties ne "")){
        $sql_where_string .= " AND ( $properties )";
    }
    
    #Get only wanted resources
    my $resource_string;
    foreach my $r (@wanted_resources){
        $resource_string .= " $r->{resource},";
    }
    chop($resource_string);

    #print("$sql_where_string\n");
    my $sth = $dbh->prepare("SELECT $resource_string
                             FROM resource_properties
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
    oar_resource_tree::set_needed_children_number($result,$wanted_children_number);

    while (my @sql = $sth->fetchrow_array()){
        my $father_ref = $result;
        foreach (my $i = 0; $i <= $#wanted_resources; $i++){
            # Feed the tree for all resources
            $father_ref = oar_resource_tree::add_child($father_ref, $wanted_resources[$i]->{resource}, $sql[$i]);

            if ($i < $#wanted_resources){
                $wanted_children_number = $wanted_resources[$i+1]->{value};
            }else{
                $wanted_children_number = 0;
            }
            oar_resource_tree::set_needed_children_number($father_ref,$wanted_children_number);
            # Verify if we must keep this child if this is resource_id resource name
            if ($wanted_resources[$i]->{resource} eq "resource_id"){
                if ((defined($impossible_resources_vector)) and (vec($impossible_resources_vector, $sql[$i], 1))){
                    oar_resource_tree::delete_subtree($father_ref);
                    $i = $#wanted_resources + 1;
                }elsif ((defined($possible_resources_vector)) and (!vec($possible_resources_vector, $sql[$i], 1))){
                    oar_resource_tree::delete_subtree($father_ref);
                    $i = $#wanted_resources + 1;
                }
            }
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
sub add_micheline_job($$$$$$$$$$$$$$$$$$$) {
    my ($dbh, $dbh_ro, $jobType, $ref_resource_list, $command, $infoType, $queue_name, $jobproperties, $startTimeReservation, $idFile, $checkpoint, $checkpoint_signal, $notify, $job_name,$type_list,$launching_directory,$anterior_ref,$stdout,$stderr) = @_;

    my $default_walltime = "1:00:00";
    my $startTimeJob = "0000-00-00 00:00:00";
    my $reservationField = "None";
    #my $setCommandReservation = 0;
    #Test if this job is a reservation
    if ($startTimeReservation =~ m/^\s*(\d{4}\-\d{1,2}\-\d{1,2})\s+(\d{1,2}:\d{1,2}:\d{1,2})\s*$/m){
        $reservationField = "toSchedule";
        $startTimeJob = "$1 $2";
        #$setCommandReservation = 1;
        #$jobType = "PASSIVE";
    }elsif($startTimeReservation ne "0"){
        warn("Syntax error near -r or --reservation option. Reservation date exemple : \"2004-03-25 17:32:12\"\n");
        return(-3);
    }

    my $rules;
    my $user= getpwuid($ENV{SUDO_UID});

    # Verify notify syntax
    if ((defined($notify)) and ($notify !~ m/^\s*(mail:|exec:).+$/m)){
        warn("/!\\Bad syntax for the notify option\n");
        return(-6);
    }
    
    
    # Verify job name
    if ($job_name !~ m/^\w*$/m){
        warn("ERROR : The job name must contain only alphanumeric characters plus '_'\n");
        return(-7);
    }

    # Verify the content of user command
    if ( "$command" !~ m/^[\w\s\/\.\-]*$/m ){
        warn("ERROR : The command to launch contains bad characters\n");
        return(-4);
    }
    
    #Retrieve Micheline's rules from the table
    my $sth = $dbh->prepare("SELECT rule FROM admission_rules ORDER BY id");
    $sth->execute();
    while (my $ref = $sth->fetchrow_hashref()) {
        $rules = $rules.$ref->{'rule'};
    }
    $sth->finish();
    #Apply rules
    #print "Admission rules => $rules \n";
    eval $rules;
    if ($@) {
        warn("Admission Rule ERROR : $@ \n");
        return(-2);
    }

    #if (($setCommandReservation == 1) && ($command eq "")){
    #    # For reservations we take the first moldable job
    #    $command = "/bin/sleep ".sql_to_duration($ref_resource_list->[0]->[1]);
    #}

    # Test if properties and resources are coherent
    my $wanted_resources;
    foreach my $moldable_resource (@{$ref_resource_list}){
        if (!defined($moldable_resource->[1])){
            $moldable_resource->[1] = $default_walltime;
        }
        my $resource_id_list_vector = '';
        foreach my $r (@{$moldable_resource->[0]}){
            # SECURITY : we must use read only database access for this request
            my $tmp_properties = $r->{property};
            if ((defined($jobproperties)) and ($jobproperties ne "")){
                if (!defined($tmp_properties)){
                    $tmp_properties = $jobproperties;
                }else{
                    $tmp_properties = "($tmp_properties) AND ($jobproperties)"
                }
            }
            print(Dumper($r->{resources}));
            my $tree = get_possible_wanted_resources($dbh_ro, undef, $resource_id_list_vector, $tmp_properties, $r->{resources});
            if (!defined($tree)){
                # Resource description does not match with the content of the database
                warn("There are not enough resources for your request\n");
                return(-5);
            }else{
                my @leafs = oar_resource_tree::get_tree_leafs($tree);
                foreach my $l (@leafs){
                    vec($resource_id_list_vector, oar_resource_tree::get_current_resource_value($l), 1) = 1;
                }
            }
        }
    }

    #Insert job
    my $date = get_date($dbh);
    #lock_table($dbh,["jobs"]);
    $job_name = $dbh->quote($job_name);
    $notify = $dbh->quote($notify);
    $command = $dbh->quote($command);
    $jobproperties = $dbh->quote($jobproperties);
    $launching_directory = $dbh->quote($launching_directory);
    $dbh->do("INSERT INTO jobs
              (job_type,info_type,state,job_user,command,submission_time,queue_name,properties,launching_directory,reservation,start_time,file_id,checkpoint,job_name,notify,checkpoint_signal)
              VALUES (\'$jobType\',\'$infoType\',\'Hold\',\'$user\',$command,\'$date\',\'$queue_name\',$jobproperties,$launching_directory,\'$reservationField\',\'$startTimeJob\',$idFile,$checkpoint,$job_name,$notify,\'$checkpoint_signal\')
             ");

    my $job_id = get_last_insert_id($dbh,"jobs_job_id_seq");
    #unlock_table($dbh);

    if (!defined($stdout) or ($stdout eq "")){
        $stdout = "OAR";
        $stdout .= ".$job_name" if ($job_name ne "NULL");
        $stdout .= ".$job_id.stdout";
    }
    if (!defined($stderr) or ($stderr eq "")){
        $stderr = "OAR";
        $stderr .= ".$job_name" if ($job_name ne "NULL");
        $stderr .= ".$job_id.stderr";
    }
    $stdout = $dbh->quote($stdout);
    $stderr = $dbh->quote($stderr);
    $dbh->do("UPDATE jobs
              SET
                  stdout_file = $stdout,
                  stderr_file = $stderr
              WHERE
                  state = \'Hold\'
                  AND job_id = $job_id
    ");

    foreach my $moldable_resource (@{$ref_resource_list}){
        #lock_table($dbh,["moldable_job_descriptions"]);
        $dbh->do("  INSERT INTO moldable_job_descriptions (moldable_job_id,moldable_walltime)
                    VALUES ($job_id,\'$moldable_resource->[1]\')
                 ");
        my $moldable_id = get_last_insert_id($dbh,"moldable_job_descriptions_moldable_id_seq");
        #unlock_table($dbh);

        foreach my $r (@{$moldable_resource->[0]}){
            #lock_table($dbh,["job_resource_groups"]);
            my $property = $r->{property};
            $property = $dbh->quote($property);
            $dbh->do("  INSERT INTO job_resource_groups (res_group_moldable_id,res_group_property)
                        VALUES ($moldable_id,$property)
                     ");
            my $res_group_id = get_last_insert_id($dbh,"job_resource_groups_res_group_id_seq");
            #unlock_table($dbh);

            my $order = 0;
            foreach my $l (@{$r->{resources}}){
                $dbh->do("  INSERT INTO job_resource_descriptions (res_job_group_id,res_job_resource_type,res_job_value,res_job_order)
                            VALUES ($res_group_id,\'$l->{resource}\',\'$l->{value}\',$order)
                         ");
                $order ++;
            }
        }
    }

    foreach my $t (@{$type_list}){
        $t = $dbh->quote($t);
        $dbh->do("  INSERT INTO job_types (job_id,type)
                    VALUES ($job_id,$t)
                 ");
    }

    foreach my $a (@{$anterior_ref}){
        $dbh->do("  INSERT INTO job_dependencies (job_id,job_id_required)
                    VALUES ($job_id,$a)
                 ");
    }

    my $random_number = int(rand(1000000000000));
    $dbh->do("INSERT INTO challenges (job_id,challenge)
              VALUES ($job_id,\'$random_number\')
             ");

    $dbh->do("INSERT INTO job_state_logs (job_id,job_state,date_start)
              VALUES ($job_id,\'Waiting\',\'$date\')
             ");
    
    $dbh->do("  UPDATE jobs
                SET state = \'Waiting\'
                WHERE
                    job_id = $job_id
             ");
    #$dbh->do("UNLOCK TABLES");

    return($job_id);
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
                                    job_id = $idJob
                            ");
    $sth->execute();

    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    return($ref);
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
                                FROM moldable_job_descriptions
                                WHERE
                                    moldable_index = \'CURRENT\'
                                    AND moldable_id = $moldableJobId
                            ");
    $sth->execute();

    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    return $ref;
}


# get_moldable_job
# returns a ref to some hash containing data for the moldable job of id passed in
# parameter
# parameters : base, moldable job id
# return value : ref
# side effects : /
sub get_moldable_job($$) {
    my $dbh = shift;
    my $moldableJobId = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM moldable_job_descriptions
                                WHERE
                                    moldable_id = $moldableJobId
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
    my $job_id = shift;
    my $state = shift;
    
    $dbh->do("  UPDATE jobs
                SET
                    state = \'$state\'
                WHERE
                    job_id = $job_id
             ");
    
    my $date = get_date($dbh);
    $dbh->do("  UPDATE job_state_logs
                SET
                    date_stop = \'$date\'
                WHERE
                    date_stop IS NULL
                    AND job_id = $job_id
             ");
    $dbh->do("  INSERT INTO job_state_logs (job_id,job_state,date_start)
                VALUES ($job_id,\'$state\',\'$date\')
             ");

    if (($state eq "Terminated") or ($state eq "Error")){
        $dbh->do("  DELETE FROM challenges
                    WHERE job_id = $job_id
                 ");
        
        if ($Db_type eq "Pg"){
            $dbh->do("  UPDATE moldable_job_descriptions
                        SET
                            moldable_index = \'LOG\'
                        WHERE
                            moldable_job_descriptions.moldable_index = \'CURRENT\'
                            AND moldable_job_descriptions.moldable_job_id = $job_id
                     ");

            $dbh->do("  UPDATE job_resource_descriptions
                        SET
                            res_job_index = \'LOG\'
                        FROM moldable_job_descriptions, job_resource_groups
                        WHERE
                            job_resource_groups.res_group_index = \'CURRENT\'
                            AND moldable_job_descriptions.moldable_index = \'LOG\'
                            AND job_resource_descriptions.res_job_index = \'CURRENT\'
                            AND moldable_job_descriptions.moldable_job_id = $job_id
                            AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id
                            AND job_resource_descriptions.res_job_group_id = job_resource_groups.res_group_id
                 ");
            
            $dbh->do("  UPDATE job_resource_groups
                        SET
                            res_group_index = \'LOG\'
                        FROM moldable_job_descriptions
                        WHERE
                            job_resource_groups.res_group_index = \'CURRENT\'
                            AND moldable_job_descriptions.moldable_index = \'LOG\'
                            AND moldable_job_descriptions.moldable_job_id = $job_id
                            AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id
                 ");
        }else{
            $dbh->do("  UPDATE moldable_job_descriptions, job_resource_groups, job_resource_descriptions
                        SET job_resource_groups.res_group_index = \'LOG\',
                            job_resource_descriptions.res_job_index = \'LOG\',
                            moldable_job_descriptions.moldable_index = \'LOG\'
                        WHERE
                            moldable_job_descriptions.moldable_index = \'CURRENT\'
                            AND job_resource_groups.res_group_index = \'CURRENT\'
                            AND job_resource_descriptions.res_job_index = \'CURRENT\'
                            AND moldable_job_descriptions.moldable_job_id = $job_id
                            AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id
                            AND job_resource_descriptions.res_job_group_id = job_resource_groups.res_group_id
                    ");
        }

        $dbh->do("  UPDATE job_types
                    SET types_index = \'LOG\'
                    WHERE
                        job_types.types_index = \'CURRENT\'
                        AND job_types.job_id = $job_id
                 ");
        
        $dbh->do("  UPDATE job_dependencies
                    SET job_dependency_index = \'LOG\'
                    WHERE
                        job_dependencies.job_dependency_index = \'CURRENT\'
                        AND job_dependencies.job_id = $job_id
                 ");

        my $job = get_job($dbh,$job_id);
        if (defined($job->{assigned_moldable_job}) and ($job->{assigned_moldable_job} ne "")){
            $dbh->do("  UPDATE assigned_resources
                        SET assigned_resource_index = \'LOG\'
                        WHERE
                            assigned_resource_index = \'CURRENT\'
                            AND moldable_job_id = $job->{assigned_moldable_job}
                    ");
        }

        my ($addr,$port) = split(/:/,$job->{info_type});
        if ($state eq "Terminated"){
            oar_Judas::notify_user($dbh,$job->{notify},$addr,$job->{job_user},$job->{job_id},$job->{job_name},"END","Job stopped normally.");
        }else{
            oar_Judas::notify_user($dbh,$job->{notify},$addr,$job->{job_user},$job->{job_id},$job->{job_name},"ERROR","Job stopped normally.");
        }
    }
}


# Resubmit a job and give the new job_id
# args : database, job id
sub resubmit_job($$){
    my $dbh = shift;
    my $job_id = shift;

    my $lusr= getpwuid($ENV{SUDO_UID});
    
    my $job = get_job($dbh, $job_id);
    return(0) if (!defined($job->{job_id}));
    return(-1) if ($job->{reservation} ne "None");
    return(-2) if ($job->{job_type} ne "PASSIVE");
    return(-3) if (($job->{state} ne "Error") and ($job->{state} ne "Terminated") and ($job->{state} ne "Finishing"));
    return(-4) if (($lusr ne $job->{job_user}) and ($lusr ne "oar") and ($lusr ne "root"));
    
    my $command = $dbh->quote($job->{command});
    my $jobproperties = $dbh->quote($job->{properties});
    my $launching_directory = $dbh->quote($job->{launching_directory});
    my $file_id = $dbh->quote($job->{file_id});
    my $date = get_date($dbh);
    #lock_table($dbh,["jobs"]);
    $dbh->do("INSERT INTO jobs
              (job_type,info_type,state,job_user,command,submission_time,queue_name,properties,launching_directory,file_id,checkpoint,job_name,notify,checkpoint_signal,reservation,resubmit_job_id)
              VALUES (\'$job->{job_type}\',\'$job->{info_type}\',\'Hold\',\'$job->{job_user}\',$command,\'$date\',\'$job->{queue_name}\',$jobproperties,$launching_directory,$file_id,$job->{checkpoint},\'$job->{job_name}\',\'$job->{notify}\',\'$job->{checkpoint_signal}\',\'None\',$job_id)
             ");
    my $new_job_id = get_last_insert_id($dbh,"jobs_job_id_seq");
    #unlock_table($dbh);
    
    $job->{stdout_file} =~ m/^(.+)\.$job_id\.stdout$/m;
    my $stdout_file = $dbh->quote("$1.$new_job_id.stdout");
    $job->{stderr_file} =~ m/^(.+)\.$job_id\.stderr$/m;
    my $stderr_file = $dbh->quote("$1.$new_job_id.stderr");

    $dbh->do("UPDATE jobs
              SET
                  stdout_file = $stdout_file,
                  stderr_file = $stderr_file
              WHERE
                  state = \'Hold\'
                  AND job_id = $new_job_id
    ");

    my $sth = $dbh->prepare("   SELECT moldable_id
                                FROM moldable_job_descriptions
                                WHERE
                                    moldable_job_id = $job_id
                            ");
    $sth->execute();
    my @moldable_ids = ();
    while (my @ref = $sth->fetchrow_array()) {
        push(@moldable_ids, $ref[0]);
    }

    foreach my $moldable_resource (@moldable_ids){
        #lock_table($dbh,["moldable_job_descriptions"]);
        $dbh->do("  INSERT INTO moldable_job_descriptions (moldable_job_id,moldable_walltime)
                        SELECT $new_job_id, moldable_walltime
                        FROM moldable_job_descriptions
                        WHERE
                            moldable_id = $moldable_resource
                 ");
        my $moldable_id = get_last_insert_id($dbh,"moldable_job_descriptions_moldable_id_seq");
        #unlock_table($dbh);
    
        $sth = $dbh->prepare("  SELECT res_group_id 
                                FROM job_resource_groups
                                WHERE
                                    res_group_moldable_id = $moldable_resource
                             ");
        $sth->execute();
        my @groups = ();
        while (my @ref = $sth->fetchrow_array()) {
            push(@groups, $ref[0]);
        }

        foreach my $r (@groups){
            #lock_table($dbh,["job_resource_groups"]);
            $dbh->do("  INSERT INTO job_resource_groups (res_group_moldable_id,res_group_property)
                            SELECT $moldable_id, res_group_property
                            FROM job_resource_groups
                            WHERE
                                res_group_id = $r
                     ");
            my $res_group_id = get_last_insert_id($dbh,"job_resource_groups_res_group_id_seq");
            #unlock_table($dbh);

            
            $dbh->do("  INSERT INTO job_resource_descriptions (res_job_group_id,res_job_resource_type,res_job_value,res_job_order)
                            SELECT $res_group_id, res_job_resource_type,res_job_value,res_job_order
                            FROM job_resource_descriptions
                            WHERE
                                res_job_group_id = $r
                     ");
        }
    }

    $dbh->do("  INSERT INTO job_types (job_id,type)
                    SELECT $new_job_id, type
                    FROM job_types
                    WHERE
                        job_id = $job_id
            ");

    $dbh->do("  INSERT INTO job_dependencies (job_id,job_id_required)
                    SELECT $new_job_id, job_id_required
                    FROM job_dependencies
                    WHERE
                        job_id = $job_id
             ");

    my $random_number = int(rand(1000000000000));
    $dbh->do("INSERT INTO challenges (job_id,challenge)
              VALUES ($new_job_id,\'$random_number\')
             ");
    
    $dbh->do("INSERT INTO job_state_logs (job_id,job_state,date_start)
              VALUES ($new_job_id,\'Waiting\',\'$date\')
             ");
    
    $dbh->do("  UPDATE jobs
                SET state = \'Waiting\'
                WHERE
                    job_id = $new_job_id
             ");

    return($new_job_id);

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
    my $sth = $dbh->prepare("UPDATE jobs SET reservation = \'$state\'
                             WHERE job_id = $idJob");
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

    $message = $dbh->quote($message);
    $dbh->do("  UPDATE jobs
                SET message = $message
                WHERE
                    job_id = $idJob
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
                SET autoCheckpointed = \'YES\'
                WHERE job_id = $idJob");
}


# frag_job
# sets the flag 'ToFrag' of a job to 'Yes'
# parameters : base, jobid
# return value : 0 on success, -1 on error (if the user calling this method
#                is not the user running the job or oar), -2 if the job was
#                already killed
# side effects : changes the field ToFrag of the job in the table Jobs
sub frag_job($$) {
    my $dbh = shift;
    my $idJob = shift;

    #my $lusr= getpwuid($<);
    my $lusr= getpwuid($ENV{SUDO_UID});

    my $job = get_job($dbh, $idJob);

    if((defined($job)) && (($lusr eq $job->{job_user}) or ($lusr eq "oar") or ($lusr eq "root"))) {
        my $nbRes = $dbh->do("SELECT *
                              FROM frag_jobs
                              WHERE
                                frag_id_job = $idJob
                             ");
        if ( $nbRes < 1 ){
            my $date = get_date($dbh);
            $dbh->do("INSERT INTO frag_jobs (frag_id_job,frag_date)
                      VALUES ($idJob,\'$date\')
                     ");
            add_new_event($dbh,"FRAG_JOB_REQUEST",$idJob,"User $lusr requested to frag the job $idJob");
            return(0);
        }else{
            # Job already killed
            return(-2);
        }
    }else{
        return(-1);
    }
}


# ask_checkpoint_job
# Verify if the user is able to checkpoint the job
# args : database ref, job id
# returns : 0 if all is good, 1 if the user cannot do this, 2 if the job is not running, 3 if the job is Interactive
sub ask_checkpoint_job($$){
    my $dbh = shift;
    my $idJob = shift;

    my $lusr= getpwuid($ENV{SUDO_UID});

    my $job = get_job($dbh, $idJob);

    return(3) if ((defined($job)) and ($job->{job_type} eq "INTERACTIVE"));
    if((defined($job)) && (($lusr eq $job->{job_user}) or ($lusr eq "oar") or ($lusr eq "root"))) {
        if ($job->{state} eq "Running"){
            #$dbh->do("LOCK TABLE event_log WRITE");
            add_new_event($dbh,"CHECKPOINT",$idJob,"User $lusr requested a checkpoint on the job $idJob");
            #$dbh->do("UNLOCK TABLES");
            return(0);
        }else{
            return(2);
        }
    }else{
        return(1);
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

    if ((defined($job)) && ((($lusr eq $job->{job_user}) || ($lusr eq "oar") || ($lusr eq "root")) && ($job->{'state'} eq "Waiting"))) {
        my $sth = $dbh->prepare("   UPDATE jobs
                                    SET state = \'Hold\'
                                    WHERE
                                        job_id = $idJob
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

    if ((defined($job)) && ((($lusr eq $job->{job_user}) || ($lusr eq "oar") || ($lusr eq "root"))  && ($job->{'state'} eq "Hold"))) {
        my $sth = $dbh->prepare("   UPDATE jobs
                                    SET state = \'Waiting\'
                                    WHERE
                                        job_id = $idJob
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

    $dbh->do("UPDATE frag_jobs
              SET frag_state = \'FRAGGED\'
              WHERE frag_id_job = $idJob
             ");
}



# job_arm_leon_timer
# sets the state to TIMER_ARMED of job
# parameters : base, jobid
# return value : /
sub job_arm_leon_timer($$) {
    my $dbh = shift;
    my $idJob = shift;

    $dbh->do("  UPDATE frag_jobs
                SET frag_state = \'TIMER_ARMED\'
                WHERE
                    frag_id_job = $idJob
             ");
}


# job_refrag
# sets the state to LEON of job
# parameters : base, jobid
# return value : /
sub job_refrag($$) {
    my $dbh = shift;
    my $idJob = shift;

    $dbh->do("UPDATE frag_jobs SET frag_state = \'LEON\'
              WHERE frag_id_job = $idJob
             ");
}



# job_leon_exterminate
# sets the state LEON_EXTERMINATE of job
# parameters : base, jobid
# return value : /
sub job_leon_exterminate($$) {
    my $dbh = shift;
    my $idJob = shift;

    $dbh->do("UPDATE frag_jobs SET frag_state = \'LEON_EXTERMINATE\'
              WHERE frag_id_job = $idJob
             ");
}



# get_frag_date
# gets the date of the frag of a job
# parameters : base, jobid
# return value : date
sub get_frag_date($$) {
    my $dbh = shift;
    my $idJob = shift;

    my $sth = $dbh->prepare("SELECT frag_date
                             FROM frag_jobs
                             WHERE frag_id_job = $idJob
                            ");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    $sth->finish();
    return($ref->{'frag_date'});
}


# Get all waiting reservation jobs
# parameter : database ref
# return an array of job informations
sub get_waiting_reservation_jobs($){
    my $dbh = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM jobs j
                                WHERE
                                    (j.state = \'Waiting\'
                                        OR j.state = \'toAckReservation\')
                                    AND j.reservation = \'Scheduled\'
                                ORDER BY j.job_id
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
                                    j.state=\'Waiting\'
                                    AND j.reservation = \'Scheduled\'
                                    AND j.queue_name = \'$queue\'
                                ORDER BY j.job_id
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
                                    state=\'Waiting\'
                                    AND queue_name = \'$queue\'
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
                                    state = \'Waiting\'
                                    AND reservation = \'None\'
                                    AND queue_name = \'$queue\'
                                ORDER BY job_id
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
                                    types_index = \'CURRENT\'
                                    AND job_id = $jobId
                            ");
    $sth->execute();
    my %res;
    while (my $ref = $sth->fetchrow_hashref()) {
        if ($ref->{type} =~ m/^\s*(\w+)\s*=\s*(.+)$/m){
            $res{$1} = $2;
        }else{
            $res{$ref->{type}} = "true";
        }
    }
    $sth->finish();

    return(\%res);
}


# get_current_job_dependencies
# return an array table with all dependencies for the given job ID
sub get_current_job_dependencies($$){
    my $dbh = shift;
    my $jobId = shift;

    my $sth = $dbh->prepare("   SELECT job_id_required
                                FROM job_dependencies
                                WHERE
                                    job_dependency_index = \'CURRENT\'
                                    AND job_id = $jobId
                            ");
    $sth->execute();
    my @res;
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{job_id_required});
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

    my $sth = $dbh->prepare("   SELECT j.*
                                FROM jobs j
                                WHERE
                                    j.state=\'Waiting\'
                                    AND j.reservation = \'toSchedule\'
                                    AND j.queue_name = \'$queue\'
                                ORDER BY j.job_id
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
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'job_id'});
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
    my $sth = $dbh->prepare("   SELECT jobs.job_id
                                FROM assigned_resources, moldable_job_descriptions, jobs, resources
                                WHERE
                                    assigned_resources.assigned_resource_index = \'CURRENT\'
                                    AND moldable_job_descriptions.moldable_index = \'CURRENT\'
                                    AND resources.network_address = \'$hostname\'
                                    AND assigned_resources.resource_id = resources.resource_id
                                    AND assigned_resources.moldable_job_id = moldable_job_descriptions.moldable_id
                                    AND moldable_job_descriptions.moldable_job_id = jobs.job_id
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'job_id'});
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
                                    state = \'$state\'
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    return @res;
}


# add_resource_job_pair
# adds a new pair (jobid, resource) to the table assigned_resources
# parameters : base, jobid, resource id
# return value : /
sub add_resource_job_pair($$$) {
    my $dbh = shift;
    my $moldable = shift;
    my $resource = shift;
    $dbh->do("INSERT INTO assigned_resources (moldable_job_id,resource_id,assigned_resource_index)
              VALUES ($moldable,$resource,\'CURRENT\')");
}


# get all jobs in a range of date
# args : base, start range, end range
sub get_jobs_range_dates($$$){
    my $dbh = shift;
    my $dateStart = shift;
    my $dateEnd = shift;

    my $sth = $dbh->prepare("SELECT j.job_id,j.job_type,j.state,j.user,j.weight,j.command,j.queue_name,j.maxTime,
                                    j.properties,j.launchingDirectory,j.submissionTime,j.start_time,j.stop_time,p.hostname,
                                    (DATE_ADD(j.start_time, INTERVAL j.maxTime HOUR_SECOND))
                             FROM jobs j, processJobs_log p
                             WHERE ( j.stop_time >= \"$dateStart\"
                                     OR (j.stop_time = \"0000-00-00 00:00:00\"
                                         AND j.state = \"Running\"
                                        )
                                   )
                                   AND j.start_time < \"$dateEnd\"
                                   AND j.job_id = p.job_id
                             ORDER BY j.job_id
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

    my $sth = $dbh->prepare("SELECT j.job_id,j.jobType,j.state,j.user,j.weight,j.command,j.queue_name,j.maxTime,
                                    j.properties,j.launchingDirectory,j.submissionTime,g2.start_time,(DATE_ADD(g2.start_time, INTERVAL j.maxTime HOUR_SECOND)),g1.hostname
                             FROM jobs j, ganttJobsNodes_visu g1, ganttJobsPrediction_visu g2
                             WHERE  g2.job_id = g1.job_id
                                AND g2.job_id = j.job_id
                                AND g2.start_time < \"$dateEnd\"
                                AND (DATE_ADD(g2.start_time, INTERVAL j.maxTime HOUR_SECOND)) >= \"$dateStart\"
                             ORDER BY j.job_id
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
	j.job_id, j.state, j.weight, j.command, j.launchingDirectory
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
	pj.job_id=j.job_id
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
    my $sth = $dbh->prepare("SELECT (max(jobs.start_time) + INTERVAL $expiry_delay MINUTE) > NOW() FROM jobs, files WHERE jobs.idFile = files.idFile AND files.md5sum = \"$md5sum\"");
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
	jobs.job_id=\"$jobid\"
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
# adds a new resource in the table resources and resource_properties
# parameters : base, name, state
# return value : new resource id
sub add_resource($$$) {
    my $dbh = shift;
    my $name = shift;
    my $state = shift;

    #lock_table($dbh,["resources"]);
    $dbh->do("  INSERT INTO resources (network_address,state)
                VALUES (\'$name\',\'$state\')
             ");
    my $id = get_last_insert_id($dbh,"resources_resource_id_seq");
    #unlock_table($dbh);
    $dbh->do("  INSERT INTO resource_properties (resource_id)
                VALUES ($id)
             ");
    my $date = get_date($dbh);
    $dbh->do("  INSERT INTO resource_state_logs (resource_id,change_state,date_start)
                VALUES ($id,\'$state\',\'$date\')
             ");

    return($id);
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
                                    state = \'Alive\'
                                    OR state = \'Suspected\'
                                    OR state = \'Absent\'
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    $sth->finish();
    return @res;
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

    my $sth = $dbh->prepare("   SELECT distinct(network_address), resource_id
                                FROM resources
                                ORDER BY resource_id ASC");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'network_address'});
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
                                    resource_id = $resource
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
                                    network_address = \'$hostname\'
                                ORDER BY resource_id ASC
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
                                    network_address = \'$hostname\'
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

    my $sth = $dbh->prepare("   SELECT resource_id
                                FROM assigned_resources
                                WHERE
                                    assigned_resource_index = \'CURRENT\'
                            ");
    $sth->execute();
    my @result;
    while (my $ref = $sth->fetchrow_hashref()){
        push(@result, $ref->{resource_id});
    }
    $sth->finish();

    return(@result);
}


# get_current_assigned_job_resources
# returns the current resources ref for a job
# parameters : base, moldable id
sub get_current_assigned_job_resources($$){
    my $dbh = shift;
    my $mold_id = shift;

    my $sth = $dbh->prepare("   SELECT resources.*
                                FROM assigned_resources, resources
                                WHERE
                                    assigned_resource_index = \'CURRENT\'
                                    AND assigned_resources.moldable_job_id = $mold_id
                                    AND resources.resource_id = assigned_resources.resource_id
                            ");
    $sth->execute();
    my @result;
    while (my $ref = $sth->fetchrow_hashref()){
        push(@result, $ref);
    }
    $sth->finish();

    return(@result);
}


# get_current_free_resources_of_node
# return an array of free resources for the specified network_address
sub get_current_free_resources_of_node($$){
    my $dbh = shift;
    my $host = shift;

    my @busy_resources = get_current_assigned_resources($dbh);
    my $where_str;
    if ($#busy_resources >= 0){
        $where_str = "resource_id NOT IN (";
        foreach my $r (@busy_resources){
            $where_str .= "$r,";
        }
        chop($where_str);
        $where_str .= ")";
    }else{
        $where_str = "TRUE";
    }
    
    my $sth = $dbh->prepare("   SELECT resource_id
                                FROM resources
                                WHERE
                                    network_address = \'$host\'
                                    AND $where_str
                            ");
    $sth->execute();
    my @result;
    while (my $ref = $sth->fetchrow_hashref()){
        push(@result, $ref->{resource_id});
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

    my $sth = $dbh->prepare("   SELECT resources.resource_id as resource
                                FROM assigned_resources, resources
                                WHERE
                                    assigned_resources.assigned_resource_index = \'CURRENT\'
                                    AND resources.network_address = \'$hostname\'
                                    AND resources.resource_id = assigned_resources.resource_id
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
                SET state = \'$state\', finaud_decision = \'$finaud\'
                WHERE
                    network_address = \'$hostname\'
             ");

    my $date = get_date($dbh);
    if ($Db_type eq "Pg"){
        $dbh->do("  UPDATE resource_state_logs
                    SET date_stop = \'$date\'
                    FROM resources
                    WHERE
                        resource_state_logs.date_stop IS NULL
                        AND resources.network_address = \'$hostname\'
                        AND resource_state_logs.resource_id = resources.resource_id
                 ");
    }else{
        $dbh->do("  UPDATE resource_state_logs, resources
                    SET resource_state_logs.date_stop = \'$date\'
                    WHERE
                        resource_state_logs.date_stop IS NULL
                        AND resources.network_address = \'$hostname\'
                        AND resource_state_logs.resource_id = resources.resource_id
                 ");
    }

    $dbh->do("INSERT INTO resource_state_logs (resource_id,change_state,date_start,finaud_decision)
                SELECT resources.resource_id,\'$state\',\'$date\',\'$finaud\'
                FROM resources
                WHERE
                    resources.network_address = \'$hostname\'
             ");
}

# set_resource_nextState
# sets the nextState field of a resource identified by its resource_id
# parameters : base, resource id, nextState
# return value : /
sub set_resource_nextState($$$) {
    my $dbh = shift;
    my $resource = shift;
    my $nextState = shift;

    my $result = $dbh->do(" UPDATE resources
                            SET next_state = \'$nextState\', next_finaud_decision = \'NO\'
                            WHERE resource_id = $resource
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
                SET state = \'$state\', finaud_decision = \'$finaud\'
                WHERE
                    resource_id = $resource_id
             ");

    my $date = get_date($dbh);
    $dbh->do("  UPDATE resource_state_logs
                SET date_stop = \'$date\'
                WHERE
                    date_stop IS NULL
                    AND resource_id = $resource_id
             ");
    $dbh->do("INSERT INTO resource_state_logs (resource_id,change_state,date_start,finaud_decision)
              VALUES ($resource_id, \'$state\',\'$date\',\'$finaud\')
             ");
}


# set_node_nextState
# sets the nextState field of a node identified by its network_address
# parameters : base, network_address, nextState
# return value : /
sub set_node_nextState($$$) {
    my $dbh = shift;
    my $hostname = shift;
    my $nextState = shift;

    my $result = $dbh->do(" UPDATE resources
                            SET next_state = \'$nextState\', next_finaud_decision = \'NO\'
                            WHERE network_address = \'$hostname\'
                          ");
    return($result);
}


# update_resource_nextFinaudDecision
# update nextFinaudDecision field
# parameters : base, resource_id, "YES" or "NO"
sub update_resource_nextFinaudDecision($$$){
    my $dbh = shift;
    my $resourceId = shift;
    my $finaud = shift;

    $dbh->do("  UPDATE resources
                SET next_finaud_decision = \'$finaud\'
                WHERE
                    resource_id = $resourceId
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
# change resource_properties table value for resources with the specified network_address
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
        if ($Db_type eq "Pg"){
            $nbRowsAffected = $dbh->do("UPDATE resource_properties
                                        SET $property = \'$value\'
                                        FROM resources
                                        WHERE 
                                            resources.network_address = \'$hostname\'
                                            AND resources.resource_id = resource_properties.resource_id
                                        ");
        }else{
            $nbRowsAffected = $dbh->do("UPDATE resources, resource_properties
                                        SET resource_properties.$property = \'$value\'
                                        WHERE 
                                            resources.network_address =\'$hostname\'
                                            AND resources.resource_id = resource_properties.resource_id
                                        ");
        }
    };
    if ($nbRowsAffected < 1){
        return(1);
    }else{
        #Update LOG table
        my $date = get_date($dbh);
        if ($Db_type eq "Pg"){
            $dbh->do("  UPDATE resource_property_logs
                        SET date_stop = \'$date\'
                        FROM resources
                        WHERE
                            resource_property_logs.date_stop IS NULL
                            AND resources.network_address = \'$hostname\'
                            AND resource_property_logs.attribute = \'$property\'
                     ");
        }else{
            $dbh->do("  UPDATE resources, resource_property_logs
                        SET resource_property_logs.date_stop = \'$date\'
                        WHERE
                            resource_property_logs.date_stop IS NULL
                            AND resources.network_address = \'$hostname\'
                            AND resource_property_logs.attribute = \'$property\'
                     ");
        }

        $dbh->do("  INSERT INTO resource_property_logs (resource_id,attribute,value,date_start)
                        SELECT resources.resource_id, \'$property\', \'$value\', \'$date\'
                        FROM resources
                        WHERE
                            resources.network_address = \'$hostname\'
                  ");
        return(0);
    }
}


# set a resource property
# change resource_properties table value for resource specified
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
        $nbRowsAffected = $dbh->do("UPDATE resource_properties
                                    SET $property = \'$value\'
                                    WHERE 
                                        resource_id = \'$resource\'
                                   ");
    };
    if ($nbRowsAffected < 1){
        return(1);
    }else{
        #Update LOG table
        my $date = get_date($dbh);
        $dbh->do("  UPDATE resource_property_logs
                    SET date_stop = \'$date\'
                    WHERE
                        date_stop IS NULL
                        AND resource_id = \'$resource\'
                        AND attribute = \'$property\'
                 ");
        $dbh->do("  INSERT INTO resource_property_logs (resource_id,attribute,value,date_start)
                    VALUES ($resource, \'$property\', \'$value\', \'$date\')
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
                                FROM resource_properties
                                WHERE
                                    resource_id = $resource");
    $sth->execute();
    my %results = %{$sth->fetchrow_hashref()};
    $sth->finish();

    return(%results);
}

# get resource names that will change their state
# parameters : base
sub get_resources_change_state($){
    my $dbh = shift;

    my $sth = $dbh->prepare("   SELECT resource_id, next_state
                                FROM resources
                                WHERE
                                    next_state != \'UnChanged\'");
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
    my $sth = $dbh->prepare("SELECT hostname,date_start,date_stop,change_state
                             FROM node_state_log
                             WHERE
                                   (changeState = \"Absent\"
                                    OR change_state = \"Dead\"
                                    OR change_state = \"Suspected\"
                                   )
                                   AND date_start <= \"$dateEnd\"
                                   AND (date_stop IS NULL OR dateStop >= \"$dateStart\")
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

    my $sth = $dbh->prepare("   SELECT moldable_job_descriptions.moldable_id, job_resource_groups.res_group_id, moldable_job_descriptions.moldable_walltime, job_resource_groups.res_group_property, job_resource_descriptions.res_job_resource_type, job_resource_descriptions.res_job_value
                                FROM moldable_job_descriptions, job_resource_groups, job_resource_descriptions, jobs
                                WHERE
                                    moldable_job_descriptions.moldable_index = \'CURRENT\'
                                    AND job_resource_groups.res_group_index = \'CURRENT\'
                                    AND job_resource_descriptions.res_job_index = \'CURRENT\'
                                    AND jobs.job_id = $job_id
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


# get_absent_suspected_resources_for_a_timeout
# args : base ref, timeout in seconds
sub get_absent_suspected_resources_for_a_timeout($$){
    my $dbh = shift;
    my $timeout = shift;

    my $date = sql_to_local(get_date($dbh));
    my $req; 
    if ($Db_type eq "Pg"){
        $req = "SELECT resource_id
                FROM resource_state_logs
                WHERE
                    date_stop IS NULL
                    AND EXTRACT(EPOCH FROM TO_TIMESTAMP(date_start,'YYYY-MM-DD HH24:MI:SS')) + $timeout < $date";
    }else{
        $req = "SELECT resource_id
                FROM resource_state_logs
                WHERE
                    date_stop IS NULL
                    AND UNIX_TIMESTAMP(date_start) + $timeout < $date";
    }
    my $sth = $dbh->prepare($req);
    $sth->execute();

    my @results;
    while (my @ref = $sth->fetchrow_array()) {
        push(@results, $ref[0]);
    }
    $sth->finish();

    return(@results);

}


# QUEUES MANAGEMENT

# get_queues
# create the list of queues sorted by descending priority
# only return the Active queues.
# return value : list of queues
# side effects : /
sub get_active_queues($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("   SELECT queue_name,scheduler_policy
                                FROM queues
                                WHERE
                                    state = \'Active\'
                                ORDER BY priority DESC
                            ");
    $sth->execute();
    my @res ;
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, [ $ref->{'queue_name'}, $ref->{'scheduler_policy'} ]);
    }
    $sth->finish();
    return @res;
}


# get_all_queue_informations
# return a hashtable with all queues and their properties
sub get_all_queue_informations($){
    my $dbh = shift;
    
    my $sth = $dbh->prepare(" SELECT *
                              FROM queues
                            ");
    $sth->execute();
    my %res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        $res{$ref->{queue_name}} = $ref ;
    }
    $sth->finish();
   
    return %res;
}


# stop_all_queues
sub stop_all_queues($){
    my $dbh = shift;
    
    $dbh->do("  UPDATE queues
                SET state = \'notActive\'
             ");
}


# GANTT MANAGEMENT

#get previous scheduler decisions
#args : base
#return a hashtable : job_id --> [start_time,walltime,queue_name,\@resources,state]
sub get_gantt_scheduled_jobs($){
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT j.job_id, g2.start_time, m.moldable_walltime, g1.resource_id, j.queue_name, j.state, j.job_user, j.job_name
                             FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, moldable_job_descriptions m, jobs j
                             WHERE
                                m.moldable_index = \'CURRENT\'
                                AND g1.moldable_job_id = g2.moldable_job_id
                                AND m.moldable_id = g2.moldable_job_id
                                AND j.job_id = m.moldable_job_id
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
            $res{$ref[0]}->[5] = $ref[6];
            $res{$ref[0]}->[6] = $ref[7];
        }
        push(@{$res{$ref[0]}->[3]}, $ref[3]);
    }
    $sth->finish();

    return %res;
}


#get previous scheduler decisions for visu
#args : base
#return a hashtable : job_id --> [start_time,weight,walltime,queue_name,\@nodes]
sub get_gantt_visu_scheduled_jobs($){
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT g2.job_id, g2.start_time, j.weight, j.maxTime, g1.hostname, j.queue_name, j.state
                             FROM ganttJobsNodes_visu g1, ganttJobsPrediction_visu g2, jobs j
                             WHERE g1.job_id = g2.job_id
                                AND j.job_id = g1.job_id
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
#args : base,moldable_job_id,start_time,\@resources
#return nothing
sub add_gantt_scheduled_jobs($$$$){
    my $dbh = shift;
    my $id_moldable_job = shift;
    my $start_time = shift;
    my $resource_list = shift;

    $dbh->do("INSERT INTO gantt_jobs_predictions (moldable_job_id,start_time)
              VALUES ($id_moldable_job,\'$start_time\')
             ");

    foreach my $i (@{$resource_list}){
        $dbh->do("INSERT INTO gantt_jobs_resources (moldable_job_id,resource_id)
                  VALUES ($id_moldable_job,$i)
                 ");
    }
}


# Remove an entry in the gantt
# params: base, job_id, resource
sub remove_gantt_resource_job($$$){
    my $dbh = shift;
    my $job = shift;
    my $resource = shift;

    $dbh->do("DELETE FROM gantt_jobs_resources WHERE moldable_job_id = $job AND resource_id = $resource");
}



# Add gantt date (now) in database
# args : base, date
sub set_gantt_date($$){
    my $dbh = shift;
    my $date = shift;

    $dbh->do("INSERT INTO gantt_jobs_predictions (moldable_job_id,start_time)
              VALUES (0,\'$date\')
             ");
}


# Update start_time in gantt for a specified job
# args : base, job id, date
sub set_gantt_job_startTime($$$){
    my $dbh = shift;
    my $job = shift;
    my $date = shift;

    $dbh->do("UPDATE gantt_jobs_predictions
              SET start_time = \'$date\'
              WHERE moldable_job_id = $job
             ");
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


# Get start_time for a given job
# args : base, job id
sub get_gantt_job_start_time_visu($$){
    my $dbh = shift;
    my $job = shift;

    my $sth = $dbh->prepare("SELECT gantt_jobs_predictions_visu.start_time, gantt_jobs_predictions_visu.moldable_job_id
                             FROM gantt_jobs_predictions_visu,moldable_job_descriptions
                             WHERE
                                moldable_job_descriptions.moldable_job_id = $job
                                AND gantt_jobs_predictions_visu.moldable_job_id = moldable_job_descriptions.moldable_id
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

    lock_table($dbh, ["gantt_jobs_predictions_visu","gantt_jobs_resources_visu","gantt_jobs_predictions","gantt_jobs_resources"]);

    $dbh->do("DELETE FROM gantt_jobs_predictions_visu");
    $dbh->do("DELETE FROM gantt_jobs_resources_visu");
#    $dbh->do("OPTIMIZE TABLE ganttJobsResources_visu, ganttJobsPredictions_visu");

    $dbh->do("INSERT INTO gantt_jobs_predictions_visu
              SELECT *
              FROM gantt_jobs_predictions
             ");
    
    $dbh->do("INSERT INTO gantt_jobs_resources_visu
              SELECT *
              FROM gantt_jobs_resources
             ");

    unlock_table($dbh);
}



# Return date of the gantt
sub get_gantt_date($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT start_time
                             FROM gantt_jobs_predictions
                             WHERE
                                moldable_job_id = 0
                            ");
    $sth->execute();
    my @res = $sth->fetchrow_array();
    $sth->finish();

    return $res[0];
}


# Return date of the gantt for visu
sub get_gantt_visu_date($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT start_time
                             FROM gantt_jobs_predictions_visu
                             WHERE
                                moldable_job_id = 0
                            ");
    $sth->execute();
    my @res = $sth->fetchrow_array();
    $sth->finish();

    return $res[0];
}


#Flush gantt tables
sub gantt_flush_tables($){
    my $dbh = shift;

    #$dbh->do("TRUNCATE TABLE gantt_jobs_predictions");
    $dbh->do("DELETE FROM gantt_jobs_predictions");
    #$dbh->do("TRUNCATE TABLE gantt_jobs_resources");
    $dbh->do("DELETE FROM gantt_jobs_resources");
    
#   $dbh->do("OPTIMIZE TABLE ganttJobs, ganttJobsPrediction");
}



#Get jobs to launch at a given date
#args : base, date in sql format
sub get_gantt_jobs_to_launch($$){
    my $dbh = shift;
    my $date = shift;

    my $sth = $dbh->prepare("SELECT g2.moldable_job_id, g1.resource_id, j.job_id
                             FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, jobs j, moldable_job_descriptions m
                             WHERE
                                m.moldable_index = \'CURRENT\'
                                AND g1.moldable_job_id= g2.moldable_job_id
                                AND m.moldable_id = g1.moldable_job_id
                                AND j.job_id = m.moldable_job_id
                                AND g2.start_time <= \'$date\'
                                AND j.state = \'Waiting\'
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

    my $sth = $dbh->prepare("SELECT g1.resource_id
                             FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, jobs j, moldable_job_descriptions m
                             WHERE
                                m.moldable_index = \'CURRENT\'
                                AND g1.moldable_job_id = m.moldable_id
                                AND m.moldable_job_id = j.job_id
                                AND g1.moldable_job_id = g2.moldable_job_id
                                AND g2.start_time <= \'$date\'
                                AND j.state = \'Waiting\'
                             GROUP BY g1.resource_id
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

    my $sth = $dbh->prepare("SELECT g.resource_id
                             FROM gantt_jobs_resources g
                             WHERE
                                g.moldable_job_id = $job 
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

    my $sth = $dbh->prepare("SELECT g.resource_id
                             FROM gantt_jobs_resources g, resources r
                             WHERE
                                g.moldable_job_id = $job 
                                AND r.resource_id = g.resource_id
                                AND r.state = \'Alive\'
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

    my $req;
    if ($Db_type eq "Pg"){
        $req = "select to_char(current_timestamp,'YYYY-MM-DD HH24:MI:SS')";
    }else{
        $req = "SELECT DATE_FORMAT(NOW(),'%Y-%m-%d %H:%i:%s')";
    }
    my $sth = $dbh->prepare($req);
    $sth->execute();
    my @ref = $sth->fetchrow_array();
    $sth->finish();

    return($ref[0]);
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
                                AND stop_time >= start_time
                                AND start_time > \"0000-00-00 00:00:00\"
                                AND maxTime > 0
                                ");
    $sth->execute();

    while (my $ref = $sth->fetchrow_hashref()) {
        my $start = sql_to_local($ref->{start_time});
        my $stop = sql_to_local($ref->{stop_time});
        my $theoricalStopTime = sql_to_duration($ref->{maxTime}) + $start;
        oar_Judas::oar_debug("[ACCOUNTING] Treate job $ref->{job_id}\n");
        update_accounting($dbh,$start,$stop,$windowSize,$ref->{job_user},$ref->{queue_name},"USED",$ref->{nbNodes},$ref->{weight});
        update_accounting($dbh,$start,$theoricalStopTime,$windowSize,$ref->{job_user},$ref->{queue_name},"ASKED",$ref->{nbNodes},$ref->{weight});
        $dbh->do("UPDATE jobs SET accounted = \"YES\" WHERE job_id = $ref->{job_id}");
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
                                WHERE   accounting_user = \"$user\"
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
        oar_Judas::oar_debug("[ACCOUNTING] Update the existing window $start --> $stop , user $user, queue $queue, type $type with conso = $conso\n");
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
        oar_Judas::oar_debug("[ACCOUNTING] Create new window $start --> $stop , user $user, queue $queue, type $type with conso = $conso\n");
        $dbh->do("  INSERT INTO accounting (user,consumption_type,queue_name,window_start,window_stop,consumption)
                    VALUES (\"$user\",\"$type\",\"$queue\",\"$start\",\"$stop\",$conso)
                 ");
    }
}


#EVENTS LOG MANAGEMENT

#add a new entry in event_log table
#args : database ref, event type, job_id , description
sub add_new_event($$$$){
    my $dbh = shift;
    my $type = shift;
    my $job_id = shift;
    my $description = substr(shift,0,254);

    my $description = $dbh->quote($description);
    my $date = get_date($dbh);
    $dbh->do("INSERT INTO event_logs (type,job_id,date,description) VALUES (\'$type\',$job_id,\'$date\',$description)");
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
    #lock_table($dbh,["event_logs"]);
    $dbh->do("  INSERT INTO event_logs (type,job_id,date,description)
                VALUES (\'$type\',$idJob,\'$date\',\'$description\')
             ");
    my $event_id = get_last_insert_id($dbh,"event_logs_event_id_seq");
    #unlock_table($dbh);

    foreach my $n (@{$hostnames}){
        $dbh->do("  INSERT INTO event_log_hostnames (event_id,hostname)
                    VALUES ($event_id,\'$n\')
                 ");
    }
}


# Turn the field toCheck into NO
#args : database ref, event type, job_id
sub check_event($$$){
    my $dbh = shift;
    my $type = shift;
    my $idJob = shift;

    $dbh->do("  UPDATE event_logs
                SET to_check = \'NO\'
                WHERE
                    to_check = \'YES\'
                    AND type = \'$type\'
                    AND job_id = $idJob
             ");
}


# Get all events with toCheck field on YES
# args: database ref
sub get_to_check_events($){
    my $dbh = shift;
    my $sth = $dbh->prepare("   SELECT type, job_id, event_id
                                FROM event_logs
                                WHERE
                                    to_check = \'YES\'
                            ");
    $sth->execute();

    my @results;
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@results, $ref);
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
                                FROM event_log_hostnames
                                WHERE
                                    event_id = $eventId
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

    my $sth = $dbh->prepare("   SELECT *
                                FROM event_logs
                                WHERE
                                    job_id = $jobId
                            ");
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


sub lock_table($$){
    my $dbh = shift;
    my $tables= shift;

    my $str = "LOCK TABLE ";
    foreach my $t (@{$tables}){
        if ($Db_type eq "Pg"){
            $str .= "$t,";
        }else{
            $str .= "$t WRITE,";
        }
    }
    chop($str);
    if ($Db_type eq "Pg"){
        $dbh->begin_work();
    }

    $dbh->do($str);
}


sub unlock_table($){
    my $dbh = shift;

    if ($Db_type eq "Pg"){
        $dbh->commit();
    }else{
        $dbh->do("UNLOCK TABLE");
    }
}


# check_end_job($$$){
sub check_end_of_job($$$$$$$$$){
    my $base = shift;
    my $Jid = shift;
    my $error = shift;
    my $hosts = shift;
    my $remote_host = shift;
    my $remote_port = shift;
    my $user = shift;
    my $launchingDirectory = shift;
    my $server_epilogue_script = shift;

    #lock_table($base,["jobs","job_state_logs","resources","assigned_resources","resource_state_logs","event_logs","challenges","moldable_job_descriptions","job_types","job_dependencies","job_resource_groups","job_resource_descriptions"]);
    lock_table($base,["jobs","job_state_logs"]);
    my $refJob = get_job($base,$Jid);
    if (($refJob->{'state'} eq "Running") or ($refJob->{'state'} eq "Launching")){
        oar_Judas::oar_debug("[bipbip $Jid] Job $Jid is ended\n");
        set_finish_date($base,$Jid);
        set_job_state($base,$Jid,"Finishing");
        unlock_table($base);
        if($error == 0){
            oar_Judas::oar_debug("[bipbip $Jid] User Launch completed OK\n");
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,"Terminated",undef,undef);
            oar_Tools::notify_tcp_socket($remote_host,$remote_port,"Term");
        }elsif ($error == 1){
            #Prologue error
            my $strWARN = "[bipbip $Jid] error of oarexec prologue; the job $Jid is in Error and the node $hosts->[0] is Suspected";
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"PROLOGUE_ERROR",$strWARN);
        }elsif ($error == 2){
            #Epilogue error
            my $strWARN = "[bipbip $Jid] error of oarexec epilogue; the node $hosts->[0] is Suspected; (jobId = $Jid)";
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"EPILOGUE_ERROR",$strWARN);
        }elsif ($error == 3){
            #Oarexec is killed by Leon normaly
            my $strWARN = "[bipbip $Jid] oarexec of the job $Jid was killed by Leon";
            oar_Judas::oar_debug("$strWARN\n");
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,"Error",undef,undef);
        }elsif ($error == 4){
            #Oarexec was killed by Leon and epilogue of oarexec is in error
            my $strWARN = "[bipbip $Jid] The job $Jid was killing by Leon and oarexec epilogue was in error";
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"EPILOGUE_ERROR",$strWARN);
        }elsif ($error == 5){
            #Oarexec is not able write in the node file
            my $strWARN = "[bipbip $Jid] oarexec cannot create the node file";
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"CANNOT_WRITE_NODE_FILE",$strWARN);
        }elsif ($error == 6){
            #Oarexec can not write its pid file
            my $strWARN = "[bipbip $Jid] oarexec cannot write its pid file";
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"CANNOT_WRITE_PID_FILE",$strWARN);
        }elsif ($error == 7){
            #Can t get shell of user
            my $strWARN = "[bipbip $Jid] Cannot get shell of user $user, so I suspect node $hosts->[0]";
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"USER_SHELL",$strWARN);
        }elsif ($error == 8){
            #Oarexec can not create tmp directory
            my $strWARN = "[bipbip $Jid] oarexec cannot create tmp directory on $hosts->[0] : ".oar_Tools::get_default_oarexec_directory();
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"CANNOT_CREATE_TMP_DIRECTORY",$strWARN);
        }elsif ($error == 10){
            #oarexecuser.sh can not go into working directory
            my $strWARN = "[bipbip $Jid] Cannot go into the working directory $launchingDirectory of the job on node $hosts->[0]";
            add_new_event($base,"WORKING_DIRECTORY",$Jid,"$strWARN");
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,"Error",undef,undef);
        }elsif ($error == 20){
            #oarexecuser.sh can not write stdout and stderr files
            my $strWARN = "[bipbip $Jid] Cannot create .stdout and .stderr files in $launchingDirectory on the node $hosts->[0]";
            add_new_event($base,"OUTPUT_FILES",$Jid,"$strWARN");
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,"Error",undef,undef);
        }elsif ($error == 12){
            #oarexecuser.sh can not go into working directory and epilogue is in error
            my $strWARN = "[bipbip $Jid] Cannot go into the working directory $launchingDirectory of the job on node $hosts->[0] AND epilogue is in error";
            oar_Judas::oar_warn("$strWARN\n");
            add_new_event($base,"WORKING_DIRECTORY",$Jid,"$strWARN");
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"EPILOGUE_ERROR",$strWARN);
        }elsif ($error == 22){
            #oarexecuser.sh can not write stdout and stderr files and epilogue is in error
            my $strWARN = "[bipbip $Jid] Cannot get shell of user $user, so I suspect node $hosts->[0] AND epilogue is in error";
            oar_Judas::oar_warn("$strWARN\n");
            add_new_event($base,"OUTPUT_FILES",$Jid,"$strWARN");
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"EPILOGUE_ERROR",$strWARN);
        }elsif ($error == 30){
            #oarexec timeout on bipbip hashtable transfer via SSH
            my $strWARN = "[bipbip $Jid] Timeout SSH hashtable transfer on $hosts->[0]";
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"SSH_TRANSFER_TIMEOUT",$strWARN);
        }elsif ($error == 31){
            #oarexec got a bad hashtable dump from bipbip
            my $strWARN = "[bipbip $Jid] Bad hashtable dump on $hosts->[0]";
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"BAD_HASHTABLE_DUMP",$strWARN);
        }elsif ($error == 33){
            #oarexec received a SIGUSR1 signal and there was an epilogue error
            my $strWARN = "[bipbip $Jid] oarexec received a SIGUSR1 signal and there was an epilogue error";
            #add_new_event($base,"STOP_SIGNAL_RECEIVED",$Jid,"$strWARN");
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"EPILOGUE_ERROR",$strWARN);
        }elsif ($error == 34){
            #oarexec received a SIGUSR1 signal
            my $strWARN = "[bipbip $Jid] oarexec received a SIGUSR1 signal; so INTERACTIVE job is ended";
            oar_Judas::oar_debug("$strWARN\n");
            #add_new_event($base,"STOP_SIGNAL_RECEIVED",$Jid,"$strWARN");
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,"Terminated",undef,undef);
            oar_Tools::notify_tcp_socket($remote_host,$remote_port,"Term");
        }elsif ($error == 40){
    	# launching oarexec timeout
            my $strWARN = "[bipbip $Jid] launching oarexec timeout, exit value = $error; the job $Jid is in Error and the node $hosts->[0] is Suspected";
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"LAUNCHING_OAREXEC_TIMEOUT",$strWARN);
        }else{
            my $strWARN = "[bipbip $Jid] error of oarexec, exit value = $error; the job $Jid is in Error and the node $hosts->[0] is Suspected";
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,undef,"EXIT_VALUE_OAREXEC",$strWARN);
        }
    }else{
        oar_Judas::oar_debug("[bipbip $Jid] I was previously killed or Terminated but I did not know that!!\n");
        unlock_table($base);
    }

    oar_Tools::notify_tcp_socket($remote_host,$remote_port,"BipBip");
}


sub job_finishing_sequence($$$$$$$$){
    my ($dbh,
        $epilogue_script,
        $almighty_host,
        $almighty_port,
        $job_id,
        $state_to_switch,
        $event_tag,
        $event_string) = @_;

    if (defined($epilogue_script)){
        # launch server epilogue
        if (-x $epilogue_script){
            my $cmd = "$epilogue_script $job_id";
            oar_Judas::oar_debug("[JOB FINISHING SEQUENCE] Launching command : $cmd\n");
            my $pid;
            my $exit_value;
            my $signal_num;
            my $dumped_core;
            my $timeout = oar_Tools::get_default_server_prologue_epilogue_timeout();
            if (is_conf("PROLOGUE_EPILOGUE_TIMEOUT")){
                $timeout = get_conf("SERVER_PROLOGUE_EPILOGUE_TIMEOUT"); 
            }
            eval{
                undef($dbh);
                $SIG{ALRM} = sub { die "alarm\n" };
                alarm($timeout);
                $pid = fork();
                if ($pid == 0){
                    exec($cmd);
                }
                my $wait_res = 0;
                # Avaoid to be disrupted by a signal
                while ($wait_res != $pid){
                    $wait_res = waitpid($pid,0);
                }
                alarm(0);
                $exit_value  = $? >> 8;
                $signal_num  = $? & 127;
                $dumped_core = $? & 128;
            };
            if ($@){
                if ($@ eq "alarm\n"){
                    undef($state_to_switch);
                    if (defined($pid)){
                        my ($children,$cmd_name) = oar_Tools::get_one_process_children($pid);
                        kill(9,@{$children});
                    }
                    my $str = "[JOB FINISHING SEQUENCE] Server epilogue timeouted (cmd : $cmd)";
                    oar_Judas::oar_error("$str\n");
                    iolib::add_new_event($dbh,"SERVER_EPILOGUE_TIMEOUT",$job_id,"$str");
                    oar_Tools::notify_tcp_socket($almighty_host,$almighty_port,"ChState");
                }
            }elsif ($exit_value != 0){
                undef($state_to_switch);
                my $str = "[JOB FINISHING SEQUENCE] Server epilogue exit code $exit_value (!=0) (cmd : $cmd)";
                oar_Judas::oar_error("$str\n");
                iolib::add_new_event($dbh,"SERVER_EPILOGUE_EXIT_CODE_ERROR",$job_id,"$str");
                oar_Tools::notify_tcp_socket($almighty_host,$almighty_port,"ChState");
            }
        }else{
            oar_Judas::oar_debug("[JOB FINISHING SEQUENCE] 2\n");
            undef($state_to_switch);
            my $str = "[JOB FINISHING SEQUENCE] Try to execute $epilogue_script but I cannot find it or it is not executable";
            oar_Judas::oar_warn("$str\n");
            add_new_event($dbh,"SERVER_EPILOGUE_ERROR",$job_id,$str);
            oar_Tools::notify_tcp_socket($almighty_host,$almighty_port,"ChState");
        }
    }
    
    if (defined($event_tag)){
        oar_Judas::oar_debug("[JOB FINISHING SEQUENCE] 4\n");
        oar_Judas::oar_warn("$event_string\n");
        add_new_event($dbh,$event_tag,$job_id,$event_string);
        oar_Tools::notify_tcp_socket($almighty_host,$almighty_port,"ChState");
    }
    if (defined($state_to_switch)){
        lock_table($dbh,["jobs","job_state_logs","resources","assigned_resources","resource_state_logs","event_logs","challenges","moldable_job_descriptions","job_types","job_dependencies","job_resource_groups","job_resource_descriptions"]);
        oar_Judas::oar_debug("[JOB FINISHING SEQUENCE] Set job $job_id into state $state_to_switch\n");
        set_job_state($dbh,$job_id,$state_to_switch);
        unlock_table($dbh);
    }
}

# END OF THE MODULE
return 1;
