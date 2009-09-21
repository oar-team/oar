# This is the iolib, which manages the layer between the modules and the
# database. This is the only base-dependent layer.
# When adding a new function, the following comments are required before the code of the function:
# - the name of the function
# - a short description of the function
# - the list of the parameters it expect
# - the list of the return values
# - the list of the side effects

# $Id$
package iolib;
require Exporter;

use DBI;
use oar_conflib qw(init_conf get_conf is_conf reset_conf);
use Data::Dumper;
use Time::Local;
use oar_Judas qw(oar_debug oar_warn oar_error send_log_by_email set_current_log_category);
use strict;
use Fcntl;
use oar_resource_tree;
use oar_Tools;
use POSIX qw(strftime);

# suitable Data::Dumper configuration for serialization
$Data::Dumper::Purity = 1;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 0;
$Data::Dumper::Deepcopy = 1;

# PROTOTYPES

# CONNECTION
sub connect();
sub connect_ro();
sub disconnect($);

# JOBS MANAGEMENT
sub get_job_challenge($$);
sub get_jobs_in_state($$);
sub get_jobs_in_state_for_user($$$);
sub is_job_desktop_computing($$);
sub get_job_current_hostnames($$);
sub get_job_current_resources($$$);
sub get_job_host_log($$);
sub get_job_resources($$);
sub get_job_resources_properties($$);
sub get_to_kill_jobs($);
sub is_tokill_job($$);
sub get_timered_job($);
sub get_to_exterminate_jobs($);
sub get_frag_date($$);
sub set_running_date($$);
sub set_running_date_arbitrary($$$);
sub set_assigned_moldable_job($$$);
sub set_finish_date($$);
sub get_possible_wanted_resources($$$$$$$);
sub add_micheline_job($$$$$$$$$$$$$$$$$$$$$$$$$$$$$);
sub get_job($$);
sub get_job_state($$);
sub get_current_moldable_job($$);
sub set_job_state($$$);
sub set_job_resa_state($$$);
sub set_job_message($$$);
sub set_job_autoCheckpointed($$);
sub frag_job($$);
sub ask_checkpoint_job($$);
sub ask_signal_job($$$);
sub hold_job($$$);
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
sub get_jobs_to_schedule($$$);
sub get_current_job_types($$);
sub set_moldable_job_max_time($$$);

#ARRAY JOBS MANAGEMENT
sub get_jobs_in_array($$);
sub get_job_array_id($$);
sub get_job_array_index($$);
sub get_array_subjobs($$);
sub get_array_job_ids($$);


# PROCESSJOBS MANAGEMENT (Resource assignment to jobs)
sub get_resource_job($$);
sub get_node_job($$);
sub get_resources_in_state($$);
sub add_resource_job_pair($$$);

# RESOURCES MANAGEMENT
sub add_resource($$$);
sub list_nodes($);
sub list_resources($);
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
sub get_resource_dead_range_date($$$);
sub get_expired_resources($);
sub is_node_desktop_computing($$);
sub get_resources_data_structure_current_job($$);
sub get_hosts_state($);

# QUEUES MANAGEMENT
sub get_active_queues($);
sub get_all_queue_informations($);

# GANTT MANAGEMENT
sub get_gantt_scheduled_jobs($);
sub get_gantt_visu_scheduled_jobs($);
sub add_gantt_scheduled_jobs($$$$);
sub gantt_flush_tables($$$);
sub set_gantt_date($$);
sub get_gantt_date($);
sub get_gantt_visu_date($);
sub get_gantt_jobs_to_launch($$);
sub get_gantt_resources_for_jobs_to_launch($$);
sub get_gantt_resources_for_job($$);
sub set_gantt_job_startTime($$$);
sub update_gantt_visualization($);
sub get_gantt_visu_resources_for_resa($$);

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
sub get_events_for_hostname($$$);

# ACCOUNTING
sub check_accounting_update($$);
sub update_accounting($$$$$$$$$);
sub get_accounting_summary($$$$);
sub get_accounting_summary_byproject($$$$);
sub get_last_project_karma($$$$);

# LOCK FUNCTIONS:

sub get_lock($$$);
sub release_lock($$);

# END OF PROTOTYPES

my $Remote_host;
my $Remote_port;

my %State_to_num = (
    "Alive" => 1,
    "Absent" => 2,
    "Suspected" => 3,
    "Dead" => 4
);

# Log category
# set_current_log_category('main');

my $Db_type = "mysql";

sub get_database_type(){
    return($Db_type);
}

# Duration to add to all jobs when matching the available_upto resource property field
my $Cm_security_duration = 600;

# CONNECTION


my $Max_db_connection_timeout = 30;
my $Timeout_db_connection = 2;

# connect_db
# Connects to database and returns the base identifier
# return value : base
sub connect_db($$$$$$) {
    my $host = shift;
    my $dbport = shift;
    my $name = shift;
    my $user = shift;
    my $pwd = shift;
    my $debug_level = shift;
    
    if($host=~m/;/){
    	my $oldHost = $host;
			$host=~s/;.*//;
			oar_error("[IOlib] Error reading $oldHost attribute from OAR configuration file, using $host instead.\n");
		}
		if($dbport=~m/;/){
			my $oldDbport = $dbport;
			$dbport=~s/;.*//;
			oar_error("[IOlib] Error reading $oldDbport attribute from OAR configuration file, using $dbport instead.\n");
		}
		if($name=~m/;/){
			my $oldname = $name;
			$name=~s/;.*//;
			oar_error("[IOlib] Error reading $oldname attribute from OAR configuration file, using $name instead.\n");
		}
		if($user=~m/;/){
			my $olduser = $user;
			$user=~s/;.*//;
			oar_error("[IOlib] Error reading $olduser attribute from OAR configuration file, using $user instead.\n");
		}

    my $printerror = 0;
    if (defined($debug_level) and ($debug_level >= 3)){
        $printerror = 1;
    }

    my $type;
    if ($Db_type eq "Pg" || $Db_type eq "psql"){
        $type = "Pg";
    }elsif ($Db_type eq "mysql"){
        $type = "mysql";
    }else{
        oar_error("[IOlib] Cannot recognize DB_TYPE tag \"$Db_type\". So we are using \"mysql\" type.\n");
        $type = "mysql";
        $Db_type = "mysql";
    }
		my $connection_string;
    if($dbport eq "" || !($dbport>1 && $dbport<65535)){
    	$connection_string = "DBI:$type:database=$name;host=$host";
    }
    else{
    	$connection_string = "DBI:$type:database=$name;host=$host;port=$dbport";
    }
    my $dbh = DBI->connect($connection_string, $user, $pwd, {'InactiveDestroy' => 1, 'PrintError' => $printerror});
    
    if (!defined($dbh)){
        oar_error("[IOlib] Cannot connect to database (type=$Db_type, host=$host, user=$user, database=$name) : $DBI::errstr\n");
    }
    return($dbh);
}

# timeout_db
# Check the provided db handler and wait for an incremented time if not ok
sub timeout_db($$) {
  my $dbh = shift;
  my $Max_db_connection_timeout = shift;
  if (!defined($dbh)) {
        oar_warn("[IOlib] I will retry to connect to the database in $Timeout_db_connection s\n");
        send_log_by_email("OAR database connection failed","[IOlib] I will retry to connect to the database in $Timeout_db_connection s\n");
        my $sleep_time = 0;
        while ($sleep_time <= 1){
            $sleep_time = sleep($Timeout_db_connection);
        }
        if ($Timeout_db_connection < $Max_db_connection_timeout){
            $Timeout_db_connection += 2;
        }
    }
} 

# connect
# Connects to database and returns the base identifier
# parameters : /
# return value : base
# side effects : opens a connection to the base specified in ConfLib
sub connect() {
    # Connect to the database.
    my $dbh = undef;
    while (!defined($dbh)){
        reset_conf();
        init_conf($ENV{OARCONFFILE});

        my $host = get_conf("DB_HOSTNAME");
        my $dbport = get_conf("DB_PORT");
        if (not defined($dbport)) {
            $dbport = "";
        }
        my $name = get_conf("DB_BASE_NAME");
        my $user = get_conf("DB_BASE_LOGIN");
        my $pwd = get_conf("DB_BASE_PASSWD");
        $Db_type = get_conf("DB_TYPE");
        
        my $log_level = get_conf("LOG_LEVEL");

        $Remote_host = get_conf("SERVER_HOSTNAME");
        $Remote_port = get_conf("SERVER_PORT");

        $dbh = connect_db($host,$dbport,$name,$user,$pwd,$log_level);

        my $max_timeout = get_conf("MAX_DB_CONNECTION_TIMEOUT");
        $max_timeout = $Max_db_connection_timeout unless defined($max_timeout);
        timeout_db($dbh,$max_timeout);
   }
    return($dbh);
}


# connect_ro
# Connects to database and returns the base identifier
# parameters : /
# return value : base
# side effects : opens a connection to the base specified in ConfLib
sub connect_ro() {
    # Connect to the database.
    my $dbh = undef;
    while (!defined($dbh)){
        $dbh = connect_ro_one();
        my $max_timeout = get_conf("MAX_DB_CONNECTION_TIMEOUT");
        $max_timeout = $Max_db_connection_timeout unless defined($max_timeout);
        timeout_db($dbh,$max_timeout);
    }
    return($dbh);
}

# connect_ro_one
# Connects to database and returns the base identifier. No loop for retry.
# parameters : /
# return value : base
# side effects : opens a connection to the base specified in ConfLib
sub connect_ro_one() {
    # Connect to the database.
    reset_conf();
    init_conf($ENV{OARCONFFILE});

    my $host = get_conf("DB_HOSTNAME");
    my $dbport = get_conf("DB_PORT");
    if (not defined($dbport)) {
        $dbport = "";
    }
    my $name = get_conf("DB_BASE_NAME");
    my $user = get_conf("DB_BASE_LOGIN_RO");
    $user = get_conf("DB_BASE_LOGIN") if (!defined($user));
    my $pwd = get_conf("DB_BASE_PASSWD_RO");
    $pwd = get_conf("DB_BASE_PASSWD") if (!defined($pwd));
    $Db_type = get_conf("DB_TYPE");
    
    my $log_level = get_conf("LOG_LEVEL");
    
    $Remote_host = get_conf("SERVER_HOSTNAME");
    $Remote_port = get_conf("SERVER_PORT");

    return connect_db($host,$dbport,$name,$user,$pwd,$log_level);
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

# Get the cpuset name for the given job
# args : database ref, job id
sub get_job_cpuset_name($$){
    my $dbh = shift;
    my $job_id = shift;

    my $sth = $dbh->prepare("   SELECT job_user
                                FROM jobs
                                WHERE
                                    job_id = $job_id
                            ");
    $sth->execute();
    my @res = $sth->fetchrow_array();
    my $cpuset = $res[0]."_".$job_id;
    return($cpuset);
}


# get_job_challenge
# gets the challenge string of a OAR Job
# parameters : base, jobid
# return value : challenge
# side effects : /
sub get_job_challenge($$){
    my $dbh = shift;
    my $job_id = shift;
    
    my $sth = $dbh->prepare("SELECT challenge,ssh_private_key,ssh_public_key
                             FROM challenges
                             WHERE
                                job_id = $job_id
                            ");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    return($ref->{challenge},$ref->{ssh_private_key},$ref->{ssh_public_key});
}

# get_count_same_ssh_keys_current_jobs
# return the number of current jobs with the same ssh keys
sub get_count_same_ssh_keys_current_jobs($$$$){
    my $dbh = shift;
    my $user = shift;
    my $ssh_private_key = shift;
    my $ssh_public_key = shift;

    $ssh_private_key = $dbh->quote($ssh_private_key);
    $ssh_public_key = $dbh->quote($ssh_public_key);
    my $sth = $dbh->prepare("   SELECT COUNT(challenges.job_id)
                                FROM challenges, jobs
                                WHERE
                                    jobs.state NOT IN (\'Terminated\',\'Error\',\'Finishing\') AND
                                    challenges.job_id = jobs.job_id AND
                                    challenges.ssh_private_key = $ssh_private_key AND
                                    challenges.ssh_public_key = $ssh_public_key AND
                                    jobs.job_user != '$user' AND
                                    challenges.ssh_private_key != \'\'
                            ");
    $sth->execute();
    my @ref = $sth->fetchrow_array();
    $sth->finish();
    return($ref[0]);
}

# get_jobs_in_state
# returns the jobs in the specified state
# parameters : base, job state
# return value : flatened list of hashref jobs
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

# get_jobs_in_state_for_user
# returns the jobs in the specified state for the optionaly specified user
# parameters : base, job state, user
# return value : flatened list of hashref jobs
# side effects : /
sub get_jobs_in_state_for_user($$$) {
    my $dbh = shift;
    my $state = $dbh->quote(shift);
    my $user = shift;
    my $user_query="";

    if (defined $user and "$user" ne "" ) {
      $user_query="AND job_user =" . $dbh->quote($user);
    }

    my $sth = $dbh->prepare("   SELECT *
                                FROM jobs
                                WHERE
                                    state = $state $user_query
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    return(@res);
}

# get_jobs_with_given_properties
# returns the jobs with specified properties
# parameters : base, where SQL constraints
# return value : flatened list of hashref jobs
# side effects : /
sub get_jobs_with_given_properties($$) {
    my $dbh = shift;
    my $where = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM jobs
                                WHERE
                                    $where
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    return(@res);
}


# is_job_desktop_computing
# return true if the job will run on desktop_computing nodes
# parameters: base, jobid
# return value: boolean
# side effects: /
sub is_job_desktop_computing($$){
    my $dbh = shift;
    my $jobid = shift;

    my $sth = $dbh->prepare("   SELECT COUNT(desktop_computing)
                                FROM assigned_resources, resources, jobs
                                WHERE
                                    jobs.job_id = $jobid AND
                                    assigned_resources.moldable_job_id = jobs.assigned_moldable_job AND
                                    assigned_resources.resource_id = resources.resource_id AND
                                    resources.desktop_computing = \'YES\'
                            ");
    $sth->execute();
    my ($count) = $sth->fetchrow_array();
    return($count > 0);
}

# get_job_current_hostnames
# returns the list of hosts associated to the job passed in parameter
# parameters : base, jobid
# return value : list of distinct hostnames
# side effects : /
sub get_job_current_hostnames($$) {
    my $dbh = shift;
    my $jobid= shift;

    my $sth = $dbh->prepare("SELECT resources.network_address as hostname
                             FROM assigned_resources, resources, moldable_job_descriptions
                             WHERE 
                                assigned_resources.assigned_resource_index = \'CURRENT\'
                                AND moldable_job_descriptions.moldable_index = \'CURRENT\'
                                AND assigned_resources.resource_id = resources.resource_id
                                AND moldable_job_descriptions.moldable_id = assigned_resources.moldable_job_id
                                AND moldable_job_descriptions.moldable_job_id = $jobid
                                AND resources.network_address != \'\'
                                AND resources.type = \'default\'
                             GROUP BY resources.network_address
                             ORDER BY resources.network_address ASC");
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
sub get_job_current_resources($$$) {
    my $dbh = shift;
    my $jobid= shift;
    my $not_type_list = shift;

    my $tmp_str;
    if (!defined($not_type_list)){
        $tmp_str = "FROM assigned_resources
                    WHERE 
                        assigned_resources.assigned_resource_index = \'CURRENT\' AND
                        assigned_resources.moldable_job_id = $jobid";
    }else{
        my $type_str;
        foreach my $t (@{$not_type_list}){
            $type_str .= $dbh->quote($t);
            $type_str .= ',';
        }
        chop($type_str);
        $tmp_str = "FROM assigned_resources,resources
                    WHERE 
                        assigned_resources.assigned_resource_index = \'CURRENT\' AND
                        assigned_resources.moldable_job_id = $jobid AND
                        resources.resource_id = assigned_resources.resource_id AND
                        resources.type NOT IN (".$type_str.")";
    }
    my $sth = $dbh->prepare("SELECT assigned_resources.resource_id as resource
                                $tmp_str
                             ORDER BY assigned_resources.resource_id ASC");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{resource});
    }
    return(@res);
}


# get_job_cpuset_uid
# returns the uid of the user for this job
# parameters : base, jobid, resource type, cpuset field
# return value : number
sub get_job_cpuset_uid($$$$) {
    my $dbh = shift;
    my $mjobid= shift;
    my $resource_type = shift;
    my $cpuset_field = shift;

    my $sth = $dbh->prepare("   SELECT resources.$cpuset_field
                                FROM jobs, resources, assigned_resources
                                WHERE
                                    resources.type = \'$resource_type\' AND
                                    assigned_resources.moldable_job_id = $mjobid AND
                                    assigned_resources.resource_id = resources.resource_id 
                                ORDER BY resources.resource_id ASC
                                LIMIT 1");
    $sth->execute();
    my $result;
    if (my @res = $sth->fetchrow_array()){
        $result = $res[0];
    }
    return($result);
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


# get_job_network_address
# returns the list of network_address associated to the job passed in parameter
# parameters : base, jobid
# return value : list of resources
# side effects : /
sub get_job_network_address($$) {
    my $dbh = shift;
    my $jobid= shift;

    my $sth = $dbh->prepare("SELECT DISTINCT(resources.network_address) as hostname
                             FROM assigned_resources, resources
                             WHERE 
                                assigned_resources.moldable_job_id = $jobid AND
                                resources.resource_id = assigned_resources.resource_id AND
                                resources.type = \'default\'
                             ORDER BY resources.network_address ASC");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{hostname});
    }
    return(@res);
}

# get_job_resource_properties
# returns the list of resources properties associated to the job passed in
# parameter
# parameters : base, jobid
# return value : list of hashs of each resource properties
# side effects : /
sub get_job_resources_properties($$) {
    my $dbh = shift;
    my $jobid= shift;

    my $sth = $dbh->prepare("SELECT resources.*
                             FROM resources, assigned_resources, jobs
                             WHERE 
                                jobs.job_id = $jobid AND
                                jobs.assigned_moldable_job = assigned_resources.moldable_job_id AND
                                assigned_resources.resource_id = resources.resource_id
                             ORDER BY resource_id ASC");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
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
                                    assigned_resources.moldable_job_id = $moldablejobid AND
                                    resources.resource_id = assigned_resources.resource_id AND
                                    resources.network_address != \'\' AND
                                    resources.type = \'default\'
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
    $sth->finish();
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
    $sth->finish();
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
    $sth->finish();
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
    if ($date < $minDate){
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
    if ($date < $minDate){
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


# set_job_exit_code
# parameters : base, jobid, exit code
sub set_job_exit_code($$$) {
    my $dbh = shift;
    my $idJob = shift;
    my $exit_code = shift;
    
    $dbh->do("  UPDATE jobs
                SET exit_code = $exit_code
                WHERE
                    job_id = $idJob
             ");
}


# get_possible_wanted_resources
# return a tree ref : a data structure with corresponding resources with what is asked
sub get_possible_wanted_resources($$$$$$$){
    my $dbh = shift;
    my $possible_resources_vector = shift;
    my $impossible_resources_vector = shift;
    my $resources_to_ignore_array = shift;
    my $properties = shift;
    my $wanted_resources_ref = shift;
    my $order_part = shift;

    my $sql_in_string = "\'1\'";
    if (defined($resources_to_ignore_array) and ($#{$resources_to_ignore_array} >= 0)){
        $sql_in_string = "resource_id NOT IN (";
        $sql_in_string .= join(",",@{$resources_to_ignore_array});
        $sql_in_string .= ")";
    }

    if (defined($order_part)){
        $order_part = "ORDER BY $order_part";
    }else{
        $order_part = "";
    }
    
    my @wanted_resources = @{$wanted_resources_ref};
    if ($wanted_resources[$#wanted_resources]->{resource} ne "resource_id"){
        push(@wanted_resources, {
                                    resource => "resource_id",
                                    value    => -1,
                                });
    }
    
    my $sql_where_string = "\'1\'";
    
    if ((defined($properties)) and ($properties ne "")){
        $sql_where_string .= " AND ( $properties )";
    }
    
    #Get only wanted resources
    my $resource_string;
    foreach my $r (@wanted_resources){
        $resource_string .= " $r->{resource},";
    }
    chop($resource_string);

    my $sth = $dbh->prepare("SELECT $resource_string
                             FROM resources
                             WHERE
                                ($sql_where_string) AND
                                $sql_in_string
                             $order_part
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
    $result = oar_resource_tree::delete_tree_nodes_with_not_enough_resources($result);

    return($result);
}


# manage the job key if option is activated
# read job key file if import from file 
# generate a job key if no import.
# function returns with $job_key_priv and $job_key_pub set if $use_job_key is set.
sub job_key_management($$$$) {
    my ($use_job_key,$import_job_key_inline,$import_job_key_file,$export_job_key_file) = @_;

    my $job_key_priv = '';
    my $job_key_pub = '';

    if (defined ($use_job_key) and !($import_job_key_inline ne "") and !($import_job_key_file ne "") and defined($ENV{OAR_JOB_KEY_FILE})){
        $import_job_key_file=$ENV{OAR_JOB_KEY_FILE};
    }
    if ((!defined($use_job_key)) and (($import_job_key_inline ne "") or ($import_job_key_file ne "") or ($export_job_key_file ne ""))){
        warn("Error: You must set the --use-job-key (or -k) option in order to use other job key related options.\n");
        return(-15,'','');
    }
    if (defined($use_job_key)){
        if (($import_job_key_inline ne "") and ($import_job_key_file ne "")){
            warn("Error: You cannot import a job key both inline and from a file at the same time.\n");
            return(-15,'','');
        }
        my $tmp_job_key_file = oar_Tools::get_default_oarexec_directory()."/oarsub_$$.jobkey";
        if (($import_job_key_inline ne "") or ($import_job_key_file ne "")){
            # job key is imported
            if ($import_job_key_inline ne "") {
                # inline import
                print ("Import job key inline.\n");
                unless (sysopen(FH,"$tmp_job_key_file",O_CREAT|O_WRONLY,0600)) {
                    warn("Error: Cannot open tmp file for writing: $tmp_job_key_file\n");
                    return(-14,'','');
                }
                syswrite(FH,$import_job_key_inline);
                close(F);
            } else {
                # file import
                print ("Import job key from file: $import_job_key_file\n");
                my $lusr= $ENV{OARDO_USER};
                # read key files: oardodo su - user needed in order to be able to read the file for sure
                # safer way to do a `cmd`, see perl cookbook 
                my $pid;
                die "cannot fork: $!" unless defined ($pid = open(SAFE_CHILD, "-|"));
                if ($pid == 0) {
                    $ENV{OARDO_BECOME_USER} = $lusr;
                    unless (exec({"oardodo"} "oardodo","cat $import_job_key_file")) {
                        warn ("Error: Cannot cannot read key file:$import_job_key_file\n");
                        exit(-14);
                    }
                    exit(0);
                }else{
                    unless (sysopen(FH,"$tmp_job_key_file",O_CREAT|O_WRONLY,0600)) {
                        warn("Error: Cannot open tmp file for writing: $tmp_job_key_file\n");
                        return(-14,'','');
                    }
                    while (<SAFE_CHILD>) {
                        syswrite(FH,$_);
                    }
                    close(FH);
                }
                close(SAFE_CHILD);
            }
            # extract the public key from the private one
            system({"bash"} "bash","-c","SSH_ASKPASS=/bin/true ssh-keygen -y -f $tmp_job_key_file < /dev/null 2> /dev/null > $tmp_job_key_file.pub");
            if ($? != 0){
                warn ("Error: Fail to extract the public key. Please verify that the job key to import is valid.\n");
                if (-e $tmp_job_key_file) { 
                    unlink($tmp_job_key_file);
                }
                if (-e $tmp_job_key_file.".pub") { 
                    unlink($tmp_job_key_file.".pub");
                }
                return(-14,'','');
            }
        } else {
            # we must generate the key
            print("Generate a job key...\n");
            # ssh-keygen: no passphrase, smallest key (1024 bits), ssh2 rsa faster than dsa.
            system({"bash"} "bash","-c",'ssh-keygen -b 1024 -N "" -t rsa -f "'.$tmp_job_key_file.'" > /dev/null');
            if ($? != 0) {
                warn ("Error: Job key generation failed ($?).\n");
                return(-14,'','');
            }
        }
        # priv and pub key file must now exist.
        unless (open(F, "< $tmp_job_key_file")){
            warn ("Error: fail to read private key.\n");
            return(-14,'','');
        }
        while ($_ = <F>){
            $job_key_priv .= $_;
        }
        close(F);
        unless (open(F, "< $tmp_job_key_file.pub")){
            warn ("Error: fail to read private key.\n");
            return(-14,'','');
        }
        while ($_ = <F>){
            $job_key_pub .= $_;
        }
        close(F);
        unlink($tmp_job_key_file,$tmp_job_key_file.".pub");
    }
    
    # last checks
    if (defined($use_job_key)){
        if ($job_key_pub eq "") {
            warn("Error: missing job public key (private key found).\n");
            return(-15,'','');
        } 
        if ($job_key_priv eq "") {
            warn("Error: missing job private key (public key found).\n");
            return(-15,'','');
        } 
        if ($job_key_pub !~ /^(ssh-rsa|ssh-dss)\s.+\n*$/){
            warn("Error: Bad job key format. The public key must begin with either `ssh-rsa' or `ssh-dss' and is only 1 line.\n");
            return(-14,'','');
        }
        $job_key_pub =~ s/\n//g;
    }

    return(0,$job_key_priv, $job_key_pub);
}


# add_micheline_job
# adds a new job(or multiple in case of array-job) to the table Jobs applying 
# the admission rules from the base  parameters : base, jobtype, nbnodes, 
# weight, command, infotype, maxtime, queuename, jobproperties, 
# startTimeReservation
# return value : ref. of array of created jobids
# side effects : adds an entry to the table Jobs
#                the first jobid is found taking the maximal jobid from 
#                jobs in the table plus 1, the next (if any) takes the next 
#                jobid. Array-job submission is atomic and array_index are 
#                sequential
#                the rules in the base are pieces of perl code directly
#                evaluated here, so in theory any side effect is possible
#                in normal use, the unique effect of an admission rule should
#                be to change parameters
sub add_micheline_job($$$$$$$$$$$$$$$$$$$$$$$$$$$$$){
   my ($dbh, $dbh_ro, $jobType, $ref_resource_list, $command, $infoType, $queue_name, $jobproperties, $startTimeReservation, $idFile, $checkpoint, $checkpoint_signal, $notify, $job_name,$job_env,$type_list,$launching_directory,$anterior_ref,$stdout,$stderr,$job_hold,$project,$use_job_key,$import_job_key_inline,$import_job_key_file,$export_job_key_file,$initial_request_string, $array_job_nb,$array_params_ref) = @_;

    my $array_id = 0;

    my $default_walltime = "3600";
    my $startTimeJob = "0";
    my $reservationField = "None";
    #Test if this job is a reservation
    if ($startTimeReservation > 0){
        $reservationField = "toSchedule";
        $startTimeJob = $startTimeReservation;
    }

    my $rules;
    my $user= $ENV{OARDO_USER};

    # Verify notify syntax
    if ((defined($notify)) and ($notify !~ m/^\s*(mail:|exec:).+$/m)){
        warn("/!\\Bad syntax for the notify option\n");
        return(-6);
    }
    
#    # Verify job name
#    if ($job_name !~ m/^\w*$/m){
#        warn("ERROR : The job name must contain only alphanumeric characters plus '_'\n");
#        return(-7);
#    }

#    # Verify the content of user command
#    if ( "$command" !~ m/^[\w\s\/\.\-]*$/m ){
#        warn("ERROR : The command to launch contains bad characters -- $command\n");
#        return(-4);
#    }
    
    # Verify the content of env variables
    if ( "$job_env" !~ m/^[\w\=\s\/\.\-\"]*$/m ){
        warn("ERROR : The specified environnement variables contains bad characters -- $job_env\n");
        return(-9);
    }
    #Retrieve Micheline's rules from the table
    my $sth = $dbh->prepare("SELECT rule FROM admission_rules ORDER BY id");
    $sth->execute();
    while (my $ref = $sth->fetchrow_hashref()) {
        $rules = $rules.$ref->{'rule'};
    }
    $sth->finish();
    #Apply rules
    eval $rules;
    if ($@) {
        warn("Admission Rule ERROR : $@ \n");
        return(-2);
    }

    #Test if the queue exists
    my %all_queues = get_all_queue_informations($dbh);
    if (!defined($all_queues{$queue_name})){
        warn("ERROR : The queue $queue_name does not exist\n");
        return(-8);
    }

    my $array_index;
    my @Job_id_list;

    if(!defined($array_params_ref)){
        for (my $i=0; $i<$array_job_nb; $i++){
            my ($err,$ssh_priv_key,$ssh_pub_key) = job_key_management($use_job_key,$import_job_key_inline,$import_job_key_file,$export_job_key_file);
            if ($err != 0){
                push(@Job_id_list, $err);
                return(\@Job_id_list);
            }
            push(@Job_id_list, add_micheline_subjob($dbh, $dbh_ro, $jobType, $ref_resource_list, $command, $infoType, $queue_name, $jobproperties, $startTimeReservation, $idFile, $checkpoint, $checkpoint_signal, $notify, $job_name,$job_env,$type_list,$launching_directory,$anterior_ref,$stdout,$stderr,$job_hold,$project,$ssh_priv_key,$ssh_pub_key,$initial_request_string, $array_id, $user, $reservationField, $startTimeJob, $default_walltime));
            if ($Job_id_list[-1] <= 0){
                return(\@Job_id_list);
            }else{
                if ($array_id <= 0){
                    $array_id = $Job_id_list[0];
                }
            }
            if (defined($use_job_key) and ($export_job_key_file ne "")){
                # we must copy the keys in the directory specified with the right name
                my $export_job_key_file_tmp = $export_job_key_file;
                $export_job_key_file_tmp =~ s/%jobid%/$Job_id_list[-1]/g;
    
                my $lusr= $ENV{OARDO_USER};
                my $pid;
                # write the private job key with the user ownership
                unless (defined ($pid = open(SAFE_CHILD, "|-"))) {
                    warn ("Error: Cannot open pipe ($?)");
                    exit(-14);
                }
                if ($pid == 0) {
                    umask(oct("177"));
                    $ENV{OARDO_BECOME_USER} = $lusr;
                    open(STDERR, ">/dev/null");
                    unless (exec({"oardodo"} "oardodo","dd of=$export_job_key_file_tmp")) {
                        warn ("Error: Cannot exec user shell ($?)");
                        exit(-14);
                    }
                }else{
                    print SAFE_CHILD $ssh_priv_key;
                    unless (close(SAFE_CHILD)) { 
                        warn ("Error: Cannot close pipe {$?}");
                        push(@Job_id_list,-14);
                        return(@Job_id_list);
                    }
                }
                print "Export job key to file: ".$export_job_key_file_tmp."\n";
            }
        }
    }else{
        $array_index=0;
        foreach my $param (@{$array_params_ref}){
            my ($err,$ssh_priv_key,$ssh_pub_key) = job_key_management($use_job_key,$import_job_key_inline,$import_job_key_file,$export_job_key_file);
            if ($err != 0){
                push(@Job_id_list, $err);
                return(\@Job_id_list);
            }
            push(@Job_id_list, add_micheline_subjob($dbh, $dbh_ro, $jobType, $ref_resource_list, $command." $param", $infoType, $queue_name, $jobproperties, $startTimeReservation, $idFile, $checkpoint, $checkpoint_signal, $notify, $job_name,$job_env,$type_list,$launching_directory,$anterior_ref,$stdout,$stderr,$job_hold,$project,$ssh_priv_key,$ssh_pub_key,$initial_request_string, $array_id, $user, $reservationField, $startTimeJob, $default_walltime));
            if ($Job_id_list[-1] <= 0){
                return(\@Job_id_list);
            }else{
                $array_index++;
                if ($array_id <= 0){
                    $array_id = $Job_id_list[0];
                }
            }
            if (defined($use_job_key) and ($export_job_key_file ne "")){
                # we must copy the keys in the directory specified with the right name
                my $export_job_key_file_tmp = $export_job_key_file;
                $export_job_key_file_tmp =~ s/%jobid%/$Job_id_list[-1]/g;
    
                my $lusr= $ENV{OARDO_USER};
                my $pid;
                # write the private job key with the user ownership
                unless (defined ($pid = open(SAFE_CHILD, "|-"))) {
                    warn ("Error: Cannot open pipe ($?)");
                    exit(-14);
                }
                if ($pid == 0) {
                    umask(oct("177"));
                    $ENV{OARDO_BECOME_USER} = $lusr;
                    open(STDERR, ">/dev/null");
                    unless (exec({"oardodo"} "oardodo","dd of=$export_job_key_file_tmp")) {
                        warn ("Error: Cannot exec user shell ($?)");
                        push(@Job_id_list,-14);
                        return(@Job_id_list);
                    }
                }else{
                    print SAFE_CHILD $ssh_priv_key;
                    unless (close(SAFE_CHILD)) { 
                        warn ("Error: Cannot close pipe {$?}");
                        push(@Job_id_list,-14);
                        return(@Job_id_list);
                    }
                }
                print "Export job key to file: ".$export_job_key_file_tmp."\n";
            }
        }
    }

   return(\@Job_id_list);
}


sub add_micheline_subjob($$$$$$$$$$$$$$$$$$$$$$$$$){
    my ($dbh, $dbh_ro, $jobType, $ref_resource_list, $command, $infoType, $queue_name, $jobproperties, $startTimeReservation, $idFile, $checkpoint, $checkpoint_signal, $notify, $job_name,$job_env,$type_list,$launching_directory,$anterior_ref,$stdout,$stderr,$job_hold,$project,$ssh_priv_key,$ssh_pub_key,$initial_request_string, $array_id, $user, $reservationField, $startTimeJob, $default_walltime) = @_;

    # Test if properties and resources are coherent
    my @dead_resources;
    foreach my $r (iolib::get_resources_in_state($dbh,"Dead")){
        push(@dead_resources, $r->{resource_id});
    }
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
            my $tree = get_possible_wanted_resources($dbh_ro, undef, $resource_id_list_vector, \@dead_resources, $tmp_properties, $r->{resources}, undef);
            $tree = oar_resource_tree::delete_unnecessary_subtrees($tree);
            if (!defined($tree)){
                # Resource description does not match with the content of the database
                if ($DBI::errstr ne ""){
                    my $tmp_err = $DBI::errstr;
                    chop($tmp_err);
                    warn("Bad resource request ($tmp_err)\n");
                }else{
                    warn("There are not enough resources for your request\n");
                }
                return(-5);
            }else{
                my @leafs = oar_resource_tree::get_tree_leafs($tree);
                foreach my $l (@leafs){
                    vec($resource_id_list_vector, oar_resource_tree::get_current_resource_value($l), 1) = 1;
                }
            }
        }
    }

    lock_table($dbh,["challenges","jobs"]);
    # Verify the content of the ssh keys
    if (($ssh_pub_key ne "") or ($ssh_priv_key ne "")){
        # Check if the keys are used by other jobs
        if (get_count_same_ssh_keys_current_jobs($dbh,$user,$ssh_priv_key,$ssh_pub_key) > 0){
            warn("/!\\ Another job is using the same ssh keys\n");
            return(-10);
        }
    }

    #Insert job
    my $date = get_date($dbh);
    #lock_table($dbh,["jobs"]);
    my $job_name_quoted = $dbh->quote($job_name);
    $notify = $dbh->quote($notify);
    $command = $dbh->quote($command);
    $job_env = $dbh->quote($job_env);
    $jobproperties = $dbh->quote($jobproperties);
    $launching_directory = $dbh->quote($launching_directory);
    $project = $dbh->quote($project);
    $initial_request_string = $dbh->quote($initial_request_string);
    $dbh->do("INSERT INTO jobs
              (job_type,info_type,state,job_user,command,submission_time,queue_name,properties,launching_directory,reservation,start_time,file_id,checkpoint,job_name,notify,checkpoint_signal,job_env,project,initial_request,array_id)
              VALUES (\'$jobType\',\'$infoType\',\'Hold\',\'$user\',$command,\'$date\',\'$queue_name\',$jobproperties,$launching_directory,\'$reservationField\',\'$startTimeJob\',$idFile,$checkpoint,$job_name_quoted,$notify,\'$checkpoint_signal\',$job_env,$project,$initial_request_string,$array_id)
             ");

    my $job_id = get_last_insert_id($dbh,"jobs_job_id_seq");
    #unlock_table($dbh);
   
    if ($array_id <= 0){
        $dbh->do("  UPDATE jobs
                    SET array_id = $job_id
                    WHERE
                        job_id = $job_id
                 ");
    }

    $ssh_priv_key = $dbh->quote($ssh_priv_key);
    $ssh_pub_key = $dbh->quote($ssh_pub_key);
    my $random_number = int(rand(1000000000000));
    $dbh->do("INSERT INTO challenges (job_id,challenge,ssh_private_key,ssh_public_key)
              VALUES ($job_id,\'$random_number\',$ssh_priv_key,$ssh_pub_key)
             ");
    unlock_table($dbh);

    if (!defined($stdout) or ($stdout eq "")){
        $stdout = "OAR";
        $stdout .= ".$job_name" if (defined($job_name));
        $stdout .= '.%jobid%.stdout';
    }
    if (!defined($stderr) or ($stderr eq "")){
        $stderr = "OAR";
        $stderr .= ".$job_name" if (defined($job_name));
        $stderr .= '.%jobid%.stderr';
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
        my $quoted_t = $dbh->quote($t);
        $dbh->do("  INSERT INTO job_types (job_id,type)
                    VALUES ($job_id,$quoted_t)
                 ");
    }

    foreach my $a (@{$anterior_ref}){
        $dbh->do("  INSERT INTO job_dependencies (job_id,job_id_required)
                    VALUES ($job_id,$a)
                 ");
    }

    if (!defined($job_hold)) {
        $dbh->do("INSERT INTO job_state_logs (job_id,job_state,date_start)
                  VALUES ($job_id,\'Waiting\',$date)
                 ");
    
        $dbh->do("  UPDATE jobs
                    SET state = \'Waiting\'
                    WHERE
                        job_id = $job_id
                 ");
    }else{
        $dbh->do("INSERT INTO job_state_logs (job_id,job_state,date_start)
                  VALUES ($job_id,\'Hold\',$date)
                 ");
    }
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


# get_job_state
# returns only the state of a job
# parameter
# parameters : base, jobid
# return value : string
# side effects : /
sub get_job_state($$) {
    my $dbh = shift;
    my $idJob = shift;

    my @res = $dbh->selectrow_array("   SELECT state
                                FROM jobs
                                WHERE
                                    job_id = $idJob
                            ");
    return($res[0]);
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
    
    if ($dbh->do("  UPDATE jobs
                    SET
                        state = \'$state\'
                    WHERE
                        job_id = $job_id AND
                        state != \'Error\' AND
                        state != \'Terminated\' AND
                        state != \'$state\'
                 ") > 0){
        my $date = get_date($dbh);
        $dbh->do("  UPDATE job_state_logs
                    SET
                        date_stop = \'$date\'
                    WHERE
                        date_stop = 0
                        AND job_id = $job_id
                ");
        $dbh->do("  INSERT INTO job_state_logs (job_id,job_state,date_start)
                    VALUES ($job_id,\'$state\',\'$date\')
                 ");

        if (($state eq "Terminated") or ($state eq "Error") or ($state eq "toLaunch") or ($state eq "Running") or ($state eq "Suspended") or ($state eq "Resuming")){
            my $job = get_job($dbh,$job_id);
            my ($addr,$port) = split(/:/,$job->{info_type});
            if ($state eq "Suspended"){
                oar_Judas::notify_user($dbh,$job->{notify},$addr,$job->{job_user},$job->{job_id},$job->{job_name},"SUSPENDED","Job is suspended.");
            }elsif ($state eq "Resuming"){
                oar_Judas::notify_user($dbh,$job->{notify},$addr,$job->{job_user},$job->{job_id},$job->{job_name},"RESUMING","Job is resuming.");
            }elsif ($state eq "Running"){
                oar_Judas::notify_user($dbh,$job->{notify},$addr,$job->{job_user},$job->{job_id},$job->{job_name},"RUNNING","Job is running.");
            }elsif ($state eq "toLaunch"){
                update_current_scheduler_priority($dbh,$job->{job_id},$job->{assigned_moldable_job},"+2","START");
            }elsif (($state eq "Terminated") or ($state eq "Error")){
                #$dbh->do("  DELETE FROM challenges
                #            WHERE job_id = $job_id
                #         ");
            
                if ($job->{stop_time} < $job->{start_time}){
                    $dbh->do("  UPDATE jobs
                                SET stop_time = start_time
                                WHERE
                                    job_id = $job_id
                             ");
                }
                if (defined($job->{assigned_moldable_job}) and ($job->{assigned_moldable_job} ne "")){
                    # Update last_job_date field for resources used
                    iolib::update_scheduler_last_job_date($dbh, $date,$job->{assigned_moldable_job});
                }
    
                if ($state eq "Terminated"){
                    oar_Judas::notify_user($dbh,$job->{notify},$addr,$job->{job_user},$job->{job_id},$job->{job_name},"END","Job stopped normally.");
                }else{
                    oar_Judas::notify_user($dbh,$job->{notify},$addr,$job->{job_user},$job->{job_id},$job->{job_name},"ERROR","Job stopped abnormally or an OAR error occured.");
                }
                update_current_scheduler_priority($dbh,$job->{job_id},$job->{assigned_moldable_job},"-2","STOP");
                
                # Here we must not be asynchronously with the scheduler
                iolib::log_job($dbh,$job->{job_id});
                # $dbh is valid so these 2 variables must be defined
                oar_Tools::notify_tcp_socket($Remote_host,$Remote_port,"ChState");
            }
        }
    }
}


# log_job
# sets the index fields to LOG on several tables
# this will speed up future queries
# parameters : base, jobid
# return value : /
sub log_job($$){
    my $dbh = shift;
    my $job_id = shift;
    
    my $job = get_job($dbh,$job_id);
        
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

    if (defined($job->{assigned_moldable_job}) and ($job->{assigned_moldable_job} ne "")){
        $dbh->do("  UPDATE assigned_resources
                    SET assigned_resource_index = \'LOG\'
                    WHERE
                        assigned_resource_index = \'CURRENT\'
                        AND moldable_job_id = $job->{assigned_moldable_job}
                ");
    }
}


# archive_some_moldable_job_nodes
# sets the index fields to LOG in the table assigned_resources
# parameters : base, mjobid, hostnames
# return value : /
sub archive_some_moldable_job_nodes($$$){
    my $dbh = shift;
    my $mjob_id = shift;
    my $hosts = shift;
   
    my $value_str;
    foreach my $v (@{$hosts}){
        $value_str .= $dbh->quote($v);
        $value_str .= ',';
    }
    chop($value_str);
    if ($Db_type eq "Pg"){
        $dbh->do("  UPDATE assigned_resources
                    SET
                        assigned_resource_index = \'LOG\'
                    FROM resources
                    WHERE
                        assigned_resources.assigned_resource_index = \'CURRENT\'
                        AND assigned_resources.moldable_job_id = $mjob_id
                        AND resources.resource_id = assigned_resources.resource_id
                        AND resources.network_address IN (".$value_str.") 
             ");
    }else{
        $dbh->do("  UPDATE assigned_resources, resources
                    SET 
                        assigned_resources.assigned_resource_index = \'LOG\'
                    WHERE
                        assigned_resources.assigned_resource_index = \'CURRENT\'
                        AND assigned_resources.moldable_job_id = $mjob_id
                        AND resources.resource_id = assigned_resources.resource_id
                        AND resources.network_address IN (".$value_str.")
                ");
    }
}


# Resubmit a job and give the new job_id
# args : database, job id
sub resubmit_job($$){
    my $dbh = shift;
    my $job_id = shift;

    my $lusr= $ENV{OARDO_USER};
    
    my $job = get_job($dbh, $job_id);
    return(0) if (!defined($job->{job_id}));
    return(-1) if ($job->{job_type} ne "PASSIVE");
    return(-2) if (($job->{state} ne "Error") and ($job->{state} ne "Terminated") and ($job->{state} ne "Finishing"));
    return(-3) if (($lusr ne $job->{job_user}) and ($lusr ne "oar") and ($lusr ne "root"));
    
    lock_table($dbh,["challenges","jobs"]);
    # Verify the content of the ssh keys
    my ($job_challenge,$ssh_private_key,$ssh_public_key) = iolib::get_job_challenge($dbh,$job_id);
    if (($ssh_public_key ne "") or ($ssh_private_key ne "")){
        # Check if the keys are used by other jobs
        if (get_count_same_ssh_keys_current_jobs($dbh,$job->{job_user},$ssh_private_key,$ssh_public_key) > 0){
            return(-4);
        }
    }

    my $command = $dbh->quote($job->{command});
    my $jobproperties = $dbh->quote($job->{properties});
    my $launching_directory = $dbh->quote($job->{launching_directory});
    my $file_id = $dbh->quote($job->{file_id});
    my $jenv = $dbh->quote($job->{job_env});
    my $project = $dbh->quote($job->{project});
    my $initial_request_string = $dbh->quote($job->{initial_request});
    my $job_name = $dbh->quote($job->{job_name});
    my $date = get_date($dbh);
    my $start_time = 0;
    $start_time = $job->{start_time} if ($job->{reservation} ne "None");
    #lock_table($dbh,["jobs"]);
    $dbh->do("INSERT INTO jobs
              (job_type,info_type,state,job_user,command,submission_time,queue_name,properties,launching_directory,file_id,checkpoint,job_name,notify,checkpoint_signal,reservation,resubmit_job_id,start_time,job_env,project,initial_request)
              VALUES (\'$job->{job_type}\',\'$job->{info_type}\',\'Hold\',\'$job->{job_user}\',$command,\'$date\',\'$job->{queue_name}\',$jobproperties,$launching_directory,$file_id,$job->{checkpoint},$job_name,\'$job->{notify}\',\'$job->{checkpoint_signal}\',\'$job->{reservation}\',$job_id,\'$start_time\',$jenv,$project,$initial_request_string)
             ");
    my $new_job_id = get_last_insert_id($dbh,"jobs_job_id_seq");
    #unlock_table($dbh);

    my $random_number = int(rand(1000000000000));
    #$dbh->do("INSERT INTO challenges (job_id,challenge)
    #          VALUES ($new_job_id,\'$random_number\')
    #         ");
    
    my $pub_key = "";
    my $priv_key = "";
    my $sth = $dbh->prepare("   SELECT ssh_private_key, ssh_public_key
                                FROM challenges
                                WHERE
                                    job_id = $job_id
                            ");
    $sth->execute();
    my $ref_keys = $sth->fetchrow_hashref();
    $sth->finish();
    if (defined($ref_keys)){
        $priv_key = $ref_keys->{ssh_private_key};
        $pub_key = $ref_keys->{ssh_public_key};
    }
    $priv_key = $dbh->quote($priv_key);
    $pub_key = $dbh->quote($pub_key);
   
    $dbh->do("INSERT INTO challenges (job_id,challenge,ssh_private_key,ssh_public_key)
              VALUES ($new_job_id,\'$random_number\',$priv_key,$pub_key)
             ");
    unlock_table($dbh);

    my $stdout_file = $dbh->quote($job->{stdout_file});
    my $stderr_file = $dbh->quote($job->{stderr_file});

    $dbh->do("UPDATE jobs
              SET
                  stdout_file = $stdout_file,
                  stderr_file = $stderr_file
              WHERE
                  state = \'Hold\'
                  AND job_id = $new_job_id
    ");

    $sth = $dbh->prepare("   SELECT moldable_id,moldable_walltime
                             FROM moldable_job_descriptions
                             WHERE
                                 moldable_job_id = $job_id
                         ");
    $sth->execute();
    my @moldable_ids = ();
    while (my @ref = $sth->fetchrow_array()) {
        push(@moldable_ids, [$ref[0], $ref[1]]);
    }
    $sth->finish();

    foreach my $m (@moldable_ids){
        my $moldable_resource = $m->[0];
        #lock_table($dbh,["moldable_job_descriptions"]);
        $dbh->do("  INSERT INTO moldable_job_descriptions (moldable_job_id,moldable_walltime)
                    VALUES ($new_job_id,\'$m->[1]\')
                 ");
        my $moldable_id = get_last_insert_id($dbh,"moldable_job_descriptions_moldable_id_seq");
        #unlock_table($dbh);
    
        $sth = $dbh->prepare("  SELECT res_group_id,res_group_property
                                FROM job_resource_groups
                                WHERE
                                    res_group_moldable_id = $moldable_resource
                             ");
        $sth->execute();
        my @groups = ();
        while (my @ref = $sth->fetchrow_array()) {
            push(@groups, [$ref[0],$ref[1]]);
        }
        $sth->finish();

        foreach my $res (@groups){
            my $r = $res->[0];
            #lock_table($dbh,["job_resource_groups"]);
            my $prop = $dbh->quote($res->[1]);
            $dbh->do("  INSERT INTO job_resource_groups (res_group_moldable_id,res_group_property)
                        VALUES ($moldable_id,$prop)
                     ");
            my $res_group_id = get_last_insert_id($dbh,"job_resource_groups_res_group_id_seq");
            #unlock_table($dbh);

            $sth = $dbh->prepare("  SELECT res_job_group_id,res_job_resource_type,res_job_value,res_job_order
                                    FROM job_resource_descriptions
                                    WHERE
                                        res_job_group_id = $r
                                ");
            $sth->execute();
            my @groups_desc = ();
            while (my @ref = $sth->fetchrow_array()) {
                push(@groups_desc, [$ref[0],$ref[1],$ref[2],$ref[3]]);
            }
            $sth->finish();

            foreach my $d (@groups_desc){
                $dbh->do("  INSERT INTO job_resource_descriptions (res_job_group_id,res_job_resource_type,res_job_value,res_job_order)
                            VALUES ($res_group_id,\'$d->[1]\',$d->[2],$d->[3])
                         ");
            }
        }
    }

    $sth = $dbh->prepare("  SELECT type
                            FROM job_types
                            WHERE
                                job_id = $job_id
                                ");
    $sth->execute();
    my @types = ();
    while (my @ref = $sth->fetchrow_array()) {
        push(@types, $ref[0]);
    }
    $sth->finish();

    foreach my $t (@types){
        $t = $dbh->quote($t);
        $dbh->do("  INSERT INTO job_types (job_id,type)
                    VALUES($new_job_id, $t)
                 ");
    }

    $dbh->do("  UPDATE job_dependencies
                SET job_id_required = $new_job_id
                WHERE
                    job_id_required = $job_id
             ");
   
    $dbh->do("INSERT INTO job_state_logs (job_id,job_state,date_start)
              VALUES ($new_job_id,\'Waiting\',$date)
             ");
    
    $dbh->do("  UPDATE jobs
                SET state = \'Waiting\'
                WHERE
                    job_id = $new_job_id
             ");

    return($new_job_id);
}


# is_job_already_resubmitted
# Check if the job was already resubmitted
# args : db ref, job id
sub is_job_already_resubmitted($$){
    my $dbh = shift;
    my $job_id = shift;

    my $sth = $dbh->prepare("   SELECT COUNT(*)
                                FROM jobs
                                WHERE
                                    resubmit_job_id = $job_id
                            ");
    $sth->execute();
    my @ref = $sth->fetchrow_array();
    $sth->finish();
   
    return($ref[0]);
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


# set_job_scheduler_info
# sets the scheduler_info field of the job of id passed in parameter
# parameters : base, jobid, message
# return value : /
sub set_job_scheduler_info($$$) {
    my $dbh = shift;
    my $idJob = shift;
    my $message = shift;

    $message = $dbh->quote($message);
    $dbh->do("  UPDATE jobs
                SET scheduler_info = $message
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

    my $lusr= $ENV{OARDO_USER};

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

    my $lusr= $ENV{OARDO_USER};

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

# ask_signal_job
# Verify if the user is able to signal the job
# args : database ref, job id, signal
# returns : 0 if all is good, 1 if the user cannot do this, 2 if the job is not running, 3 if the job is Interactive
sub ask_signal_job($$$){
    my $dbh = shift;
    my $idJob = shift;
    my $signal = shift;

    my $lusr= $ENV{OARDO_USER};

    my $job = get_job($dbh, $idJob);

    return(3) if ((defined($job)) and ($job->{job_type} eq "INTERACTIVE"));
    if((defined($job)) && (($lusr eq $job->{job_user}) or ($lusr eq "oar") or ($lusr eq "root"))) {
        if ($job->{state} eq "Running"){
            #$dbh->do("LOCK TABLE event_log WRITE");
            add_new_event($dbh,"SIGNAL_$signal",$idJob,"User $lusr requested the signal $signal on the job $idJob");
            #$dbh->do("UNLOCK TABLES");
	    #oar_debug("[oar_iolib] added an event of type SIGNAL_$signal for job $idJob\n");
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
sub hold_job($$$) {
    my $dbh = shift;
    my $idJob = shift;
    my $waiting_and_running = shift;

    my $lusr = $ENV{OARDO_USER};

    my $job = get_job($dbh, $idJob);
    
    my $event_type = "HOLD_WAITING_JOB";
    $event_type = "HOLD_RUNNING_JOB" if (defined($waiting_and_running));
    if (defined($job)){
        if (defined($waiting_and_running) and ($lusr ne "oar") and ($lusr ne "root")){
            return(-4);
        }elsif (($lusr eq $job->{job_user}) || ($lusr eq "oar") || ($lusr eq "root")){
            if (($job->{'state'} eq "Waiting") or ($job->{'state'} eq "Resuming")){
                add_new_event($dbh, $event_type, $idJob, "User $lusr launched oarhold on the job $idJob");
                return 0;
            }elsif((defined($waiting_and_running)) and (($job->{state} eq "toLaunch") or ($job->{state} eq "Launching") or ($job->{state} eq "Running"))){
                add_new_event($dbh, $event_type, $idJob, "User $lusr launched oarhold on the job $idJob");
                return 0;
            }else{
                return(-3);
            }
        }else{
            return(-2);
        }
    }else{
        return(-1);
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

    my $lusr = $ENV{OARDO_USER};

    my $job = get_job($dbh, $idJob);

    if (defined($job)){
        if (($job->{'state'} eq "Suspended") and ($lusr ne "oar") and ($lusr ne "root")){
            return(-4);
        }elsif (($lusr eq $job->{job_user}) || ($lusr eq "oar") || ($lusr eq "root")){
            if (($job->{'state'} eq "Hold") or ($job->{'state'} eq "Suspended")){
                add_new_event($dbh, "RESUME_JOB", $idJob, "User $lusr launched oarresume on the job $idJob");
                return(0);
            }
            return(-3);
        }
        return(-2);
    } else {
        return(-1);
    }
}


# get the amount of time in the suspended state of a job
# args : base, job id, time in seconds
sub get_job_suspended_sum_duration($$$){
    my $dbh = shift;
    my $job_id = shift;
    my $current_time = shift;

    my $sth = $dbh->prepare("   SELECT date_start, date_stop
                                FROM job_state_logs
                                WHERE
                                    job_id = $job_id AND
                                    (job_state = \'Suspended\' OR
                                     job_state = \'Resuming\')
                            ");
    $sth->execute();
    my $sum = 0;
    while (my $ref = $sth->fetchrow_hashref()) {
        my $tmp_sum = 0;
        if ($ref->{date_stop} == 0){
            $tmp_sum = $current_time - $ref->{date_start};
        }else{
            $tmp_sum += $ref->{date_stop} - $ref->{date_start};
        }
        $sum += $tmp_sum if ($tmp_sum > 0);
    }
    $sth->finish();

    return($sum);
}


# Return the list of jobs running on resources allocated to another given job
# args : base, resume job id
sub get_jobs_on_resuming_job_resources($$){
    my $dbh = shift;
    my $job_id = shift;

    my $sth = $dbh->prepare("   SELECT DISTINCT(j2.job_id) as jobid
                                FROM jobs j1,jobs j2,assigned_resources a1,assigned_resources a2
                                WHERE
                                    a1.assigned_resource_index = \'CURRENT\' AND
                                    a2.assigned_resource_index = \'CURRENT\' AND
                                    j1.job_id = $job_id AND
                                    a1.moldable_job_id = j1.assigned_moldable_job AND
                                    a2.resource_id = a1.resource_id AND
                                    a2.moldable_job_id = j2.assigned_moldable_job AND
                                    j2.state NOT IN (\'Suspended\',\'Resuming\')
                            ");
    $sth->execute();
    my @res;
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res,$ref->{jobid});
    }
    $sth->finish();

    return(@res);
}


# Return the list of resources where there are Suspended jobs
# args: base
sub get_current_resources_with_suspended_job($){
    my $dbh = shift;

    my $sth = $dbh->prepare("   SELECT resource_id
                                FROM assigned_resources, jobs
                                WHERE
                                    assigned_resources.assigned_resource_index = \'CURRENT\' AND
                                    jobs.state = \'Suspended\' AND
                                    jobs.assigned_moldable_job = assigned_resources.moldable_job_id
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{resource_id});
    }
    $sth->finish();

    return(@res);
}

# suspend_job_action
# perform all action when a job is suspended
# parameters : base, jobid, moldable jobid
sub suspend_job_action($$$) {
    my $dbh = shift;
    my $job_id = shift;
    my $moldable_job_id = shift;

    set_job_state($dbh,$job_id,"Suspended");
    $dbh->do("  UPDATE jobs
                SET suspended = \'YES\'
                WHERE
                    job_id = $job_id
             ");
    my @r = get_current_resources_with_suspended_job($dbh);
    $dbh->do("  UPDATE resources
                SET suspended_jobs = \'YES\'
                WHERE
                   resource_id IN (".join(",",@r).")
             ");
}


# resume_job_action
# perform all action when a job is suspended
# parameters : base, jobid
sub resume_job_action($$) {
    my $dbh = shift;
    my $job_id = shift;

    set_job_state($dbh,$job_id,"Running");
    my @r = get_current_resources_with_suspended_job($dbh);
    if ($#r >= 0){
        $dbh->do("  UPDATE resources
                    SET suspended_jobs = \'NO\'
                    WHERE
                       resource_id NOT IN (".join(",",@r).")
                 ");
    }else{
        $dbh->do("  UPDATE resources
                    SET suspended_jobs = \'NO\'
                 ");
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
sub get_jobs_to_schedule($$$){
    my $dbh = shift;
    my $queue = shift;
    my $limit = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM jobs
                                WHERE
                                    state = \'Waiting\'
                                    AND reservation = \'None\'
                                    AND queue_name = \'$queue\'
                                ORDER BY job_id
                                LIMIT $limit
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    $sth->finish();
    return(@res);
}


# get_fairsharing_jobs_to_schedule
# args : base ref, queue name
sub get_fairsharing_jobs_to_schedule($$$){
    my $dbh = shift;
    my $queue = shift;
    my $limit = shift;

    my $req = "SELECT distinct(job_user)
               FROM jobs
               WHERE
                   state = \'Waiting\'
                   AND reservation = \'None\'
                   AND queue_name = \'$queue\'
               ";
    my $sth = $dbh->prepare($req);
    $sth->execute();
    my @users = ();
    while (my @ref = $sth->fetchrow_array()) {
        push(@users, $ref[0]);
    }
    $sth->finish();

    my @res = ();
    foreach my $u (@users){
        my $req2 = "SELECT *
                    FROM jobs
                    WHERE
                        state = \'Waiting\'
                        AND reservation = \'None\'
                        AND queue_name = \'$queue\'
                        AND job_user = \'$u\'
                    ORDER BY job_id
                    LIMIT $limit
               ";
        my $sth = $dbh->prepare($req2);
        $sth->execute();
        while (my $ref = $sth->fetchrow_hashref()) {
            push(@res, $ref);
        }
        $sth->finish();
    }

    return(@res);
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


# get_job_types
# return the list of types for the given job ID
sub get_job_types($$){
    my $dbh = shift;
    my $jobId = shift;

    my $sth = $dbh->prepare("   SELECT type
                                FROM job_types
                                WHERE
                                    job_id = $jobId
                            ");
    $sth->execute();
    my @res;
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res,$ref->{type});
    }
    $sth->finish();

    return(@res);
}


# add_current_job_types
sub add_current_job_types($$$){
    my $dbh = shift;
    my $jobId = shift;
    my $type = shift;

    $dbh->do("  INSERT INTO job_types (job_id,type,types_index)
                VALUES ($jobId,\'$type\',\'CURRENT\')
             ");
}

# remove_current_job_types
sub remove_current_job_types($$$){
    my $dbh = shift;
    my $jobId = shift;
    my $type = shift;

    $dbh->do("  DELETE FROM job_types
                WHERE
                    job_id = $jobId AND
                    type = \'$type\' AND
                    types_index = \'CURRENT\'
             ");
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


# get_job_dependencies
# return an array table with all dependencies for the given job ID
sub get_job_dependencies($$){
    my $dbh = shift;
    my $jobId = shift;

    my $sth = $dbh->prepare("   SELECT job_id_required
                                FROM job_dependencies
                                WHERE
                                    job_id = $jobId
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


# set walltime for a moldable job
sub set_moldable_job_max_time($$$){
    my ($dbh, $mol, $walltime) = @_;

    $dbh->do("  UPDATE moldable_job_descriptions
                SET moldable_walltime = \'$walltime\'
                WHERE
                    moldable_id = $mol
             ");
}


#ARRAY JOBS MANAGEMENT

# get_jobs_in_array
# returns the jobs within a same array
# parameters : base, array_id
# return value : flatened list of hashref jobs ids
sub get_jobs_in_array($$) {
    my $dbh = shift;
    my $array_id = $dbh->quote(shift);

    my $sth = $dbh->prepare("   SELECT job_id
                                FROM jobs
                                WHERE
                                    array_id = $array_id
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    return(@res);
}


# get_job_array_id($$)
# get array_id of a job with given job_id
# parameters : base,  job_id
# return value : array_id of the job
# side effects : / 
sub get_job_array_id($$){
    my $dbh = shift;
    my $job_id = shift;
    my $sth;

    $sth = $dbh->prepare("  SELECT array_id
                            FROM jobs
                            WHERE
                                job_id = $job_id
                         ");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my @tmp_array = values(%$ref);

    my $array_id = $tmp_array[0];
    $sth->finish();
  
    return($array_id);
}
 

# get_job_array_index($$)
# Calculate the array_index based on a given job_id
# parameters : base, job_id
# return value : array_index of the given jobid
# side effects : / 
sub get_job_array_index($$){
    my $dbh = shift;
    my $job_id = shift;
    my $sth;

    my $array_id = get_job_array_id($dbh,$job_id);

    $sth = $dbh->prepare("  SELECT COUNT(job_id)
                            FROM jobs
                            WHERE 
                                array_id = $array_id
                                and job_id < $job_id
                         ");

    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my @tmp_array = values(%$ref);
    $sth->finish();

    return ($tmp_array[0]+1);
}


# get_array_subjobs($$)
# Get all the jobs of a given array_job
# parameters : base, array_id
# return value : array of jobs of a given array_job
# side effects : / 
sub get_array_subjobs($$){
    my $dbh = shift;
    my $array_id = shift;

    my $sth = $dbh->prepare("   SELECT *
                                FROM jobs
                                WHERE
                                    array_id = $array_id
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    $sth->finish();
    
    return(@res);
}



# get_array_job_ids($$)
# Get all the job_ids of a given array_job
# parameters : base, array_id
# return value : array of jobids of a given array_job
# side effects : / 
sub get_array_job_ids($$){
    my $dbh = shift;
    my $array_id = shift;

    my $sth = $dbh->prepare("   SELECT job_id
                                FROM jobs
                                WHERE
                                    array_id = $array_id
                            ");
    $sth->execute();

    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        my @tmp_array = values(%$ref);
        push(@res,  $tmp_array[0]);
    }

    $sth->finish();
    return(@res);
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


# get_finaud_nodes
# returns the list of nodes for finaud
# parameters : base
# return value : list of nodes
sub get_finaud_nodes($) {
    my $dbh = shift;
    my $sth = "";
    if ($Db_type eq "Pg"){
      $sth = $dbh->prepare("   SELECT DISTINCT(network_address), *
                                  FROM resources
                                  WHERE
                                    (state = \'Alive\' OR
                                    (state = \'Suspected\' AND finaud_decision = \'YES\')) AND
                                    type = \'default\'
                              ");
    }
    else{
      my @result;
      my $presth = $dbh->prepare("DESC resources"); 
      $presth->execute();
      while (my $ref = $presth->fetchrow_hashref()){
        my $current_value = $ref->{'Field'};
        push(@result, $current_value);
      }
    
      $presth->finish();
    
      my $str = "SELECT DISTINCT(network_address)";
      foreach(@result){
        $str = $str.", ".$_;
      }
      $str = $str." FROM resources
                    WHERE
                      state = \'Alive\' OR
                      (state = \'Suspected\' AND finaud_decision = \'YES\') AND
                      type = \'default\'";
      $sth = $dbh->prepare($str);
    }
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    return @res;
}


# get_resources_that_can_be_waked_up
# returns a list of resources
# parameters : base, date max
# return value : list of resource ref
sub get_resources_that_can_be_waked_up($$) {
    my $dbh = shift;
    my $max_date = shift;
    
    $max_date = $max_date + $Cm_security_duration;
    my $sth = $dbh->prepare("   SELECT *
                                FROM resources
                                WHERE
                                    state = \'Absent\' AND
                                    resources.available_upto > $max_date
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    return(@res);
}


# get_resources_that_will_be_out
# returns a list of resources
# parameters : base, job max date
# return value : list of resource ref
sub get_resources_that_will_be_out($$) {
    my $dbh = shift;
    my $max_date = shift;
    
    $max_date = $max_date + $Cm_security_duration;
    my $sth = $dbh->prepare("   SELECT *
                                FROM resources
                                WHERE
                                    state = \'Alive\' AND
                                    resources.available_upto < $max_date
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref);
    }
    return(@res);
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
    my $date_start = shift;
    my $date_end = shift;

    my $req = 
        "SELECT jobs.job_id,jobs.job_type,jobs.state,jobs.job_user,jobs.command,jobs.queue_name,moldable_job_descriptions.moldable_walltime,jobs.properties,jobs.launching_directory,jobs.submission_time,jobs.start_time,jobs.stop_time,assigned_resources.resource_id,resources.network_address,(jobs.start_time + moldable_job_descriptions.moldable_walltime)
         FROM jobs, assigned_resources, moldable_job_descriptions, resources
         WHERE
             (   
                 jobs.stop_time >= $date_start OR
                 (   
                     jobs.stop_time = \'0\' AND
                     (jobs.state = \'Running\' OR
                      jobs.state = \'Suspended\' OR
                      jobs.state = \'Resuming\')
                 )
             ) AND
             jobs.start_time < $date_end AND
             jobs.assigned_moldable_job = assigned_resources.moldable_job_id AND
             moldable_job_descriptions.moldable_job_id = jobs.job_id AND
             resources.resource_id = assigned_resources.resource_id
         ORDER BY jobs.job_id";
 
    my $sth = $dbh->prepare($req);
    $sth->execute();

    my %results;
    while (my @ref = $sth->fetchrow_array()) {
        if (!defined($results{$ref[0]})){
            $results{$ref[0]} = {
                                  'job_type' => $ref[1],
                                  'state' => $ref[2],
                                  'user' => $ref[3],
                                  'command' => $ref[4],
                                  'queue_name' => $ref[5],
                                  'walltime' => $ref[6],
                                  'properties' => $ref[7],
                                  'launching_directory' => $ref[8],
                                  'submission_time' => $ref[9],
                                  'start_time' => $ref[10],
                                  'stop_time' => $ref[11],
                                  'resources' => [ $ref[12] ],
                                  'limit_stop_time' => $ref[14]
                                 }
        }else{
            push(@{$results{$ref[0]}->{resources}}, $ref[12]);
        }
    }
    $sth->finish();

    return %results;
}



# get all jobs in a range of date in the gantt
# args : base, start range, end range
sub get_jobs_gantt_scheduled($$$){
    my $dbh = shift;
    my $date_start = shift;
    my $date_end = shift;

    my $req =
        "SELECT jobs.job_id,jobs.job_type,jobs.state,jobs.job_user,jobs.command,jobs.queue_name,moldable_job_descriptions.moldable_walltime,jobs.properties,jobs.launching_directory,jobs.submission_time,gantt_jobs_predictions_visu.start_time,(gantt_jobs_predictions_visu.start_time + moldable_job_descriptions.moldable_walltime),gantt_jobs_resources_visu.resource_id, resources.network_address
         FROM jobs, moldable_job_descriptions, gantt_jobs_resources_visu, gantt_jobs_predictions_visu, resources
         WHERE
             gantt_jobs_predictions_visu.moldable_job_id = gantt_jobs_resources_visu.moldable_job_id AND
             gantt_jobs_predictions_visu.moldable_job_id = moldable_job_descriptions.moldable_id AND
             jobs.job_id = moldable_job_descriptions.moldable_job_id AND
             gantt_jobs_predictions_visu.start_time < $date_end AND
             resources.resource_id = gantt_jobs_resources_visu.resource_id AND
             gantt_jobs_predictions_visu.start_time + moldable_job_descriptions.moldable_walltime >= $date_start
         ORDER BY jobs.job_id";
    
    my $sth = $dbh->prepare($req);
    $sth->execute();

    my %results;
    while (my @ref = $sth->fetchrow_array()) {
        if (!defined($results{$ref[0]})){
            $results{$ref[0]} = {
                                  'job_type' => $ref[1],
                                  'state' => $ref[2],
                                  'user' => $ref[3],
                                  'command' => $ref[4],
                                  'queue_name' => $ref[5],
                                  'walltime' => $ref[6],
                                  'properties' => $ref[7],
                                  'launching_directory' => $ref[8],
                                  'submission_time' => $ref[9],
                                  'start_time' => $ref[10],
                                  'stop_time' => $ref[11],
                                  'resources' => [ $ref[12] ],
                                 }
        }else{
            push(@{$results{$ref[0]}->{resources}}, $ref[12]);
        }
    }
    $sth->finish();

    return %results;
}


# get scheduling informations about Interactive jobs in Waiting state
# args : base
sub get_gantt_waiting_interactive_prediction_date($){
    my $dbh = shift;

    my $req =
        "SELECT jobs.job_id, jobs.info_type, gantt_jobs_predictions_visu.start_time, jobs.message
         FROM jobs, moldable_job_descriptions, gantt_jobs_predictions_visu
         WHERE
             jobs.state = \'Waiting\' AND
             jobs.reservation = \'None\' AND
             moldable_job_descriptions.moldable_index = \'CURRENT\' AND
             moldable_job_descriptions.moldable_job_id = jobs.job_id AND
             gantt_jobs_predictions_visu.moldable_job_id = moldable_job_descriptions.moldable_id
        ";
    
    my $sth = $dbh->prepare($req);
    $sth->execute();

    my @results;
    while (my @ref = $sth->fetchrow_array()) {
        my $tmp = {
                    'job_id' => $ref[0],
                    'info_type' => $ref[1],
                    'start_time' => $ref[2],
                    'message' => $ref[3],
                  };
        push(@results, $tmp);
    }
    $sth->finish();

    return(@results);
}


# get_desktop_computing_host_jobs($$);
# get the list of jobs and attributs affected to a desktop computing node
# parameters: base, nodename
# return value: jobs hash
# side effects: none
sub get_desktop_computing_host_jobs($$) {
    my $dbh = shift;
    my $hostname = shift;

    my $sth = $dbh->prepare("   SELECT jobs.job_id, jobs.state, jobs.command, jobs.launching_directory, jobs.stdout_file, jobs.stderr_file
                                FROM jobs, assigned_resources, resources
                                WHERE
                                    resources.network_address = \'$hostname\' AND
                                    resources.desktop_computing = \'YES\' AND
                                    resources.resource_id = assigned_resources.resource_id AND
                                    jobs.assigned_moldable_job = assigned_resources.moldable_job_id AND
                                    assigned_resources.assigned_resource_index = \'CURRENT\'
                            ");
    $sth->execute;
    my $results;
    while (my @array = $sth->fetchrow_array()) {
        $results->{$array[0]} = {
                                    state => $array[1],
                                    command => $array[2],
                                    directory => $array[3],
                                    stdout_file => oar_Tools::replace_jobid_tag_in_string($array[4],$array[0]),
                                    stderr_file => oar_Tools::replace_jobid_tag_in_string($array[5],$array[0])
                                };
    }
    return($results);
}

# get_stagein_id($$);
# retrieve stagein idFile form its md5sum
# parameters: base, md5sum
# return value: idFile or undef if md5sum is not found
# side effects: none
sub get_stagein_id($$) {
    my $dbh = shift;
    my $md5sum = shift;

    my $sth = $dbh->prepare("   SELECT file_id
                                FROM files
                                WHERE
                                    md5sum = \'$md5sum\'
                            ");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    $sth->finish();
    return($ref->{file_id});
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
    lock_table($dbh, ["files"]);
    $dbh->do("INSERT INTO files (md5sum,location,method,compression,size)
              VALUES (\'$md5sum\',\'$location\',\'$method\',\'$compression\',$size)");
    $idFile = get_last_insert_id($dbh,"files_file_id_seq");
    unlock_table($dbh);
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
    
    lock_table($dbh, ["files"]);
    $dbh->do("DELETE FROM files WHERE md5sum = \'$md5sum\'");
    unlock_table($dbh);
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
   
    my $date = get_date($dbh);
    my $sth = $dbh->prepare("   SELECT jobs.start_time
                                FROM jobs, files
                                WHERE
                                    jobs.file_id = files.file_id AND
                                    files.md5sum = \'$md5sum\'
                            ");
    $sth->execute();
    my $result = 1;
    while (my @res = $sth->fetchrow_array()){
        if (($res[0] + $expiry_delay) > $date){
            $result = 0;
            return(0);
        }
    }
    return ($result);
}

# get_job_stagein($$);
# get a job stagein information: pathname and md5sum
# parameters: base, jobid
# return value: a hash with 2 keys: pathname and md5sum
# side effects: none
sub get_job_stagein($$) {
    my $dbh = shift;
    my $jobid = shift;
    my $sth = $dbh->prepare("   SELECT files.md5sum,files.location,files.method,files.compression,files.size
                                FROM jobs, files
                                WHERE	
                                    jobs.job_id = $jobid AND
                                    jobs.file_id = files.file_id
                            ");
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
    $dbh->do("  INSERT INTO resources (network_address,state,state_num)
                VALUES (\'$name\',\'$state\',$State_to_num{$state})
             ");
    my $id = get_last_insert_id($dbh,"resources_resource_id_seq");
    #unlock_table($dbh);
    my $date = get_date($dbh);
    $dbh->do("  INSERT INTO resource_logs (resource_id,attribute,value,date_start)
                VALUES ($id,\'state\',\'$state\',\'$date\')
             ");

#    # Init cpu field with the id
#    eval{
#        $dbh->do("  UPDATE resources
#                    SET cpu = $id
#                    WHERE
#                        resource_id = $id
#                 ");
#    };

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


# get_current_assigned_nodes
# returns the current nodes
# parameters : base
sub get_current_assigned_nodes($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("   SELECT DISTINCT(resources.network_address)
                                FROM assigned_resources, resources
                                WHERE
                                    assigned_resources.assigned_resource_index = \'CURRENT\' AND
                                    resources.resource_id = assigned_resources.resource_id
                            ");
    $sth->execute();
    my %result;
    while (my @ref = $sth->fetchrow_array()){
        $result{$ref[0]} = 1;
    }
    $sth->finish();

    return(\%result);
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


# get_specific_resource_states
# returns a hashtable with each given resources and their states
# parameters : base, resource type
sub get_specific_resource_states($$){
    my $dbh = shift;
    my $type = shift;

    my %result;
    my $sth = $dbh->prepare("   SELECT resource_id, state
                                FROM resources
                                WHERE
                                    type = \'$type\'
                            ");
    $sth->execute();
    while (my @ref = $sth->fetchrow_array()){
        push(@{$result{$ref[1]}}, $ref[0]);
    }
    $sth->finish();

    return(\%result);
}

# get_resource_state
# returns the state for the resource
# parameters : base, resource_id
# return value : string
# side effects : /
# sub get_resource_state($$){
#   my $dbh = shift;
#   my $resource_id = shift;
#   my $result;
#   my $sth = $dbh->prepare("     SELECT state
#                                 FROM resources
#                                 WHERE
#                                     resource_id = $resource_id
#                             ")
#     $sth->execute();
#     while (my @ref = $sth->fetchrow_array()){
#         $result = $ref[0];
#     }
#     $sth->finish();
#     return($result);
# }


# get_current_free_resources_of_node
# return an array of free resources for the specified network_address
sub get_current_free_resources_of_node($$){
    my $dbh = shift;
    my $host = shift;

    my $sth = $dbh->prepare("   SELECT resource_id
                                FROM resources
                                WHERE
                                    network_address = \'$host\'
                                    AND resource_id NOT IN (
                                        SELECT resource_id from assigned_resources
                                        where assigned_resource_index = \'CURRENT\'                                    
                                    )
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


# get_all_resources_on_node
# returns the current resources on node whose hostname is passed in parameter
# parameters : base, hostname
# return value : resources ids
# side effects : /
sub get_all_resources_on_node($$) {
    my $dbh = shift;
    my $hostname = shift;

    my $sth = $dbh->prepare("   SELECT resource_id
                                FROM resources
                                WHERE
                                    network_address = \'$hostname\'
                            ");
    $sth->execute();
    my @result;
    while (my $ref = $sth->fetchrow_hashref()){
        push(@result, $ref->{resource_id});
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
                SET state = \'$state\', finaud_decision = \'$finaud\', state_num = $State_to_num{$state}
                WHERE
                    network_address = \'$hostname\'
             ");

    my $date = get_date($dbh);
    if ($Db_type eq "Pg"){
        $dbh->do("  UPDATE resource_logs
                    SET date_stop = \'$date\'
                    FROM resources
                    WHERE
                        resource_logs.date_stop = 0
                        AND resource_logs.attribute = \'state\'
                        AND resources.network_address = \'$hostname\'
                        AND resource_logs.resource_id = resources.resource_id
                 ");
    }else{
        $dbh->do("  UPDATE resource_logs, resources
                    SET resource_logs.date_stop = \'$date\'
                    WHERE
                        resource_logs.date_stop = 0
                        AND resource_logs.attribute = \'state\'
                        AND resources.network_address = \'$hostname\'
                        AND resource_logs.resource_id = resources.resource_id
                 ");
    }

    $dbh->do("INSERT INTO resource_logs (resource_id,attribute,value,date_start,finaud_decision)
                SELECT resources.resource_id,\'state\',\'$state\',\'$date\',\'$finaud\'
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
                SET state = \'$state\', finaud_decision = \'$finaud\', state_num = $State_to_num{$state}
                WHERE
                    resource_id = $resource_id
             ");

    my $date = get_date($dbh);
    $dbh->do("  UPDATE resource_logs
                SET date_stop = \'$date\'
                WHERE
                    date_stop = 0
                    AND attribute = \'state\'
                    AND resource_id = $resource_id
             ");
    $dbh->do("INSERT INTO resource_logs (resource_id,attribute,value,date_start,finaud_decision)
              VALUES ($resource_id, \'state\', \'$state\',\'$date\',\'$finaud\')
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
                            WHERE
                                network_address = \'$hostname\'
                          ");
    return($result);
}


# set_node_nextState_if_necessary
sub set_node_nextState_if_necessary($$$) {
    my $dbh = shift;
    my $hostname = shift;
    my $nextState = shift;

    my $result = $dbh->do(" UPDATE resources
                            SET next_state = \'$nextState\', next_finaud_decision = \'NO\'
                            WHERE
                                network_address = \'$hostname\'
                                AND state != \'$nextState\'
                                AND next_state = \'UnChanged\'
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


# update_node_nextFinaudDecision
# update nextFinaudDecision field
# parameters : base, network_address, "YES" or "NO"
sub update_node_nextFinaudDecision($$$){
    my $dbh = shift;
    my $node = shift;
    my $finaud = shift;

    $dbh->do("  UPDATE resources
                SET next_finaud_decision = \'$finaud\'
                WHERE
                    network_address = \'$node\'
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
    $dbh->do("  UPDATE resources
                SET expiry_date = \'$expiryDate\'
                WHERE
                    network_address =\'$hostname\'
             ");
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
        $nbRowsAffected = $dbh->do("UPDATE resources
                                    SET $property = \'$value\'
                                    WHERE 
                                        resources.network_address = \'$hostname\'
                                   ");
    };
    if ($nbRowsAffected < 1){
        return(1);
    }else{
        #Update LOG table
        my $date = get_date($dbh);
        if ($Db_type eq "Pg"){
            $dbh->do("  UPDATE resource_logs
                        SET date_stop = \'$date\'
                        FROM resources
                        WHERE
                            resource_logs.date_stop = 0
                            AND resources.network_address = \'$hostname\'
                            AND resource_logs.attribute = \'$property\'
                            AND resources.resource_id = resource_logs.resource_id
                     ");
        }else{
            $dbh->do("  UPDATE resources, resource_logs
                        SET resource_logs.date_stop = \'$date\'
                        WHERE
                            resource_logs.date_stop = 0
                            AND resources.network_address = \'$hostname\'
                            AND resource_logs.attribute = \'$property\'
                            AND resources.resource_id = resource_logs.resource_id
                     ");
        }

        $dbh->do("  INSERT INTO resource_logs (resource_id,attribute,value,date_start)
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
        $nbRowsAffected = $dbh->do("UPDATE resources
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
        $dbh->do("  UPDATE resource_logs
                    SET date_stop = \'$date\'
                    WHERE
                        date_stop = 0
                        AND resource_id = \'$resource\'
                        AND attribute = \'$property\'
                 ");
        $dbh->do("  INSERT INTO resource_logs (resource_id,attribute,value,date_start)
                    VALUES ($resource, \'$property\', \'$value\', \'$date\')
                 ");
        return(0);
    }
}


# add_event_maintenance_on
# add an event in the table resource_logs indicating that this 
# resource is in maintenance (state = Absent, available_upto = 0)
# params: base, resource_id, date_start
sub add_event_maintenance_on($$$){
    my $dbh = shift;
    my $resource_id = shift;
    my $date_start = shift;

    $dbh->do("  INSERT INTO resource_logs (resource_id,attribute,value,date_start)
                    VALUES ($resource_id, \'maintenance\', \'on\', \'$date_start\')
    ");

    return(0);

}

# add_event_maintenance_off
# update the event in the table resource_logs indicating that this 
# resource is in maintenance (state = Absent, available_upto = 0) 
# set the date_stop
# params: base, resource_id, date_stop
sub add_event_maintenance_off($$$){
    my $dbh = shift;
    my $resource_id = shift;
    my $date_stop = shift;

    $dbh->do("  UPDATE resource_logs
		SET date_stop = \'$date_stop\'
		WHERE
		    date_stop = 0
		    AND resource_id = \'$resource_id\'
		    AND attribute = \'maintenance\'
	      ");

    return(0);

}


# get_resources_with_given_sql
# gets the resource list with the given sql properties
# parameters : base, $sql where clause
# return value : list of resource id
# side effects : /
sub get_resources_with_given_sql($$) {
    my $dbh = shift;
    my $where = shift;

    my $sth = $dbh->prepare("   SELECT resource_id
                                FROM resources
                                WHERE
                                    $where
                            ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{resource_id});
    }
    $sth->finish();
    return(@res);
}


## return all properties for a specific resource
## parameters : base, resource
#sub get_resource_properties($$){
#    my $dbh = shift;
#    my $resource = shift;
#
#    my $sth = $dbh->prepare("   SELECT *
#                                FROM resources
#                                WHERE
#                                    resource_id = $resource");
#    $sth->execute();
#    my %results = %{$sth->fetchrow_hashref()};
#    $sth->finish();
#
#    return(%results);
#}

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

    return(%results);
}


# list property fields of the resource_properties table
# args : db ref
sub list_resource_properties_fields($){
    my $dbh = shift;
    
    my $req;
    if ($Db_type eq "Pg"){

				$req = "SELECT column_name AS field FROM information_schema.columns WHERE table_name = \'resources\'";

    }else{
        $req = "SHOW COLUMNS FROM resources";
    }

    my $sth = $dbh->prepare($req);
    $sth->execute();

    my %results;
    while (my @ref = $sth->fetchrow_array()) {
        $results{$ref[0]} = 1;
    }
    $sth->finish();

    return(%results);

}


# update_current_scheduler_priority
# Update the scheduler_priority field of the table resources
sub update_current_scheduler_priority($$$$$){
    my $dbh = shift;
    my $job_id = shift;
    my $moldable_id = shift;
    my $value = shift;
    my $state = shift;
    
    $state = "STOP" if ($state ne "START");

    if (is_conf("SCHEDULER_PRIORITY_HIERARCHY_ORDER")){
        my $types = iolib::get_current_job_types($dbh,$job_id);
        if ((defined($types->{besteffort}))
            and (($state eq "START" and (is_an_event_exists($dbh,$job_id,"SCHEDULER_PRIORITY_UPDATED_START") <= 0))
                or (($state eq "STOP") and (is_an_event_exists($dbh,$job_id,"SCHEDULER_PRIORITY_UPDATED_START") > 0)))
           ){
            my $index = 0;
            foreach my $f (split('/',get_conf("SCHEDULER_PRIORITY_HIERARCHY_ORDER"))){
                next if ($f eq "");
                $index++;

                my $sth = $dbh->prepare("   SELECT distinct(resources.$f)
                                            FROM assigned_resources, resources
                                            WHERE
                                                assigned_resource_index = \'CURRENT\' AND
                                                moldable_job_id = $moldable_id AND
                                                assigned_resources.resource_id = resources.resource_id
                                        ");
                $sth->execute();
                my $value_str;
                while (my @ref = $sth->fetchrow_array()){
                    $value_str .= $dbh->quote($ref[0]);
                    $value_str .= ',';
                }
                $sth->finish();
                return if (!defined($value_str));
                chop($value_str);
                my $req =  "UPDATE resources
                            SET scheduler_priority = scheduler_priority + ($value * $index)
                            WHERE
                                $f IN (".$value_str.")
                           ";
                $dbh->do($req);       
            }
            add_new_event($dbh,"SCHEDULER_PRIORITY_UPDATED_$state",$job_id,"Scheduler priority for job $job_id updated (".get_conf("SCHEDULER_PRIORITY_HIERARCHY_ORDER").")");
        }
    }
}


#get the range when nodes are dead between two dates
# arg : base, start date, end date
sub get_resource_dead_range_date($$$){
    my $dbh = shift;
    my $date_start = shift;
    my $date_end = shift;

    # get dead nodes between two dates
    my $req = "SELECT resource_id, date_start, date_stop, value
               FROM resource_logs
               WHERE
                   attribute = \'state\' AND
                   (
                       value = \'Absent\' OR
                       value = \'Dead\' OR
                       value = \'Suspected\'
                   ) AND
                   date_start <= $date_end AND
                   (
                       date_stop = 0 OR
                       date_stop >= $date_start
                   )
              ";

    my $sth = $dbh->prepare($req);
    $sth->execute();

    my %results;
    while (my @ref = $sth->fetchrow_array()) {
        my $interval_stopDate = $ref[2];
        if (!defined($interval_stopDate)){
            $interval_stopDate = $date_end;
        }
        push(@{$results{$ref[0]}}, [$ref[1],$interval_stopDate,$ref[3]]);
    }
    $sth->finish();

    return(%results);
}

# get_expired_resources
# get the list of resources whose expiry_date is in the past and which are not dead yet.
# 0000-00-00 00:00:00 is always considered as in the future
# parameters: base
# return value: list of resources
# side effects: /
sub get_expired_resources($){
    my $dbh = shift;
    # get expired nodes

    my $date = get_date($dbh);
    my $req = "SELECT resources.resource_id
               FROM resources
               WHERE
                   resources.state = \'Alive\' AND
                   resources.expiry_date > 0 AND
                   resources.desktop_computing = \'YES\' AND
                   resources.expiry_date < $date
              ";
    
    my $sth = $dbh->prepare($req);
    $sth->execute();
    my @results;
    while (my @res = $sth->fetchrow_array()){
        push(@results, $res[0]);
    }
    $sth->finish();
    
    return(@results);
}

# is_node_desktop_computing
# tell if a node is for desktop computing.
# parameters: base, hostname
# return value: boolean
# side effects: /
sub is_node_desktop_computing($$){
    my $dbh = shift;
    my $hostname = shift;
    
    my $sth = $dbh->prepare("   SELECT desktop_computing
                                FROM resources
                                WHERE
                                    network_address = \'$hostname\'
                            ");
    $sth->execute();
    my @ref;
    my $result;
    while (@ref = $sth->fetchrow_array()){
        $result = $ref[0];
        if ($result ne "YES"){
	    return($result);
        }
    }
    return($result);
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
#               moldable_job_id
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


# get_absent_suspected_resources_for_a_timeout
# args : base ref, timeout in seconds
sub get_absent_suspected_resources_for_a_timeout($$){
    my $dbh = shift;
    my $timeout = shift;

    my $date = get_date($dbh);
    my $req = "SELECT resource_id
                FROM resource_logs
                WHERE
                    attribute = \'state\'
                    AND date_stop = 0
                    AND date_start + $timeout < $date
              ";
    my $sth = $dbh->prepare($req);
    $sth->execute();

    my @results;
    while (my @ref = $sth->fetchrow_array()) {
        push(@results, $ref[0]);
    }
    $sth->finish();

    return(@results);

}


# get_cpuset_values_for_a_moldable_job
# get cpuset values for each nodes of a MJob
sub get_cpuset_values_for_a_moldable_job($$$){
    my $dbh = shift;
    my $cpuset_field = shift;
    my $mjob_id = shift;

    my $sql_where_string = "\'0\'";
    my $resources_to_always_add_type = get_conf("SCHEDULER_RESOURCES_ALWAYS_ASSIGNED_TYPE");
    if (defined($resources_to_always_add_type) and ($resources_to_always_add_type ne "")){
        $sql_where_string = "resources.type = \'$resources_to_always_add_type\'";
    }
    
    my $sth = $dbh->prepare("   SELECT resources.network_address, resources.$cpuset_field
                                FROM resources, assigned_resources
                                WHERE
                                    assigned_resources.moldable_job_id = $mjob_id AND
                                    assigned_resources.resource_id = resources.resource_id AND
                                    resources.network_address != \'\' AND
                                    (resources.type = \'default\' OR
                                     $sql_where_string)
                                GROUP BY resources.network_address, resources.$cpuset_field
                            ");
    $sth->execute();

    my $results;
    while (my @ref = $sth->fetchrow_array()) {
        push(@{$results->{$ref[0]}}, $ref[1]);
    }

    return($results);
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

# start_all_queues
sub start_all_queues($){
    my $dbh = shift;
    
    $dbh->do("  UPDATE queues
                SET state = \'Active\'
             ");
}


# stop_a_queue
sub stop_a_queue($$){
    my $dbh = shift;
    my $queue = shift;
    
    $dbh->do("  UPDATE queues
                SET state = \'notActive\'
                WHERE
                    queue_name = \'$queue\'
             ");
}

# start_a_queue
sub start_a_queue($$){
    my $dbh = shift;
    my $queue = shift;
    
    $dbh->do("  UPDATE queues
                SET state = \'Active\'
                WHERE
                    queue_name = \'$queue\'
             ");
}

# delete a queue
sub delete_a_queue($$){
    my $dbh = shift;
    my $queue = shift;
    
    $dbh->do("DELETE FROM queues WHERE queue_name = \'$queue\'");
}

# create a queue
sub create_a_queue($$$$){
    my $dbh = shift;
    my $queue = shift;
    my $policy = shift;
    my $priority = shift;
    
    $dbh->do("  INSERT INTO queues (queue_name,priority,scheduler_policy)
                VALUES (\'$queue\',$priority,\'$policy\')");
}


# GANTT MANAGEMENT

#get previous scheduler decisions
#args : base
#return a hashtable : job_id --> [start_time,walltime,queue_name,\@resources,state]
sub get_gantt_scheduled_jobs($){
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT j.job_id, g2.start_time, m.moldable_walltime, g1.resource_id, j.queue_name, j.state, j.job_user, j.job_name,m.moldable_id,j.suspended
                             FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, moldable_job_descriptions m, jobs j
                             WHERE
                                m.moldable_index = \'CURRENT\'
                                AND g1.moldable_job_id = g2.moldable_job_id
                                AND m.moldable_id = g2.moldable_job_id
                                AND j.job_id = m.moldable_job_id
                             ORDER BY j.start_time, j.job_id
                            ");
    $sth->execute();
    my %res ;
    my @order;
    while (my @ref = $sth->fetchrow_array()) {
        if (!defined($res{$ref[0]})){
            $res{$ref[0]}->[0] = $ref[1];
            $res{$ref[0]}->[1] = $ref[2];
            $res{$ref[0]}->[2] = $ref[4];
#            $res{$ref[0]}->[3] = $ref[3];
            $res{$ref[0]}->[4] = $ref[5];
            $res{$ref[0]}->[5] = $ref[6];
            $res{$ref[0]}->[6] = $ref[7];
            $res{$ref[0]}->[7] = $ref[8];
            $res{$ref[0]}->[8] = $ref[9];
            push(@order,$ref[0]);
        }
        push(@{$res{$ref[0]}->[3]}, $ref[3]);
    }
    $sth->finish();

    return(\@order, %res);
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

    return($res[0]);
}


# Get all waiting reservation jobs
# parameter : database ref
# return an array of moldable job informations
sub get_waiting_reservations_already_scheduled($){
    my $dbh = shift;

    my $sth = $dbh->prepare("   SELECT moldable_job_descriptions.moldable_id, gantt_jobs_predictions.start_time, gantt_jobs_resources.resource_id, moldable_job_descriptions.moldable_walltime
                                FROM jobs, moldable_job_descriptions, gantt_jobs_predictions, gantt_jobs_resources
                                WHERE
                                    (jobs.state = \'Waiting\'
                                        OR jobs.state = \'toAckReservation\')
                                    AND jobs.reservation = \'Scheduled\'
                                    AND jobs.job_id = moldable_job_descriptions.moldable_job_id
                                    AND gantt_jobs_predictions.moldable_job_id = moldable_job_descriptions.moldable_id
                                    AND gantt_jobs_resources.moldable_job_id = moldable_job_descriptions.moldable_id
                            ");
    $sth->execute();
    my $res;
    while (my @ref = $sth->fetchrow_array()) {
        push(@{$res->{$ref[0]}->{resources}}, $ref[2]);
        $res->{$ref[0]}->{start_time} = $ref[1];
        $res->{$ref[0]}->{walltime} = $ref[3];
    }
    $sth->finish();
    return($res);
}


#Flush gantt tables
sub gantt_flush_tables($$$){
    my $dbh = shift;
    my $reservations_to_keep = shift;
    my $log = shift;

    if (defined($log)){
        my $date = get_gantt_date($dbh);
        $dbh->do("  INSERT INTO gantt_jobs_predictions_log (sched_date,moldable_job_id,start_time)
                        SELECT \'$date\', gantt_jobs_predictions.moldable_job_id, gantt_jobs_predictions.start_time
                        FROM gantt_jobs_predictions
                        WHERE
                            gantt_jobs_predictions.moldable_job_id != 0
        ");
        $dbh->do("  INSERT INTO gantt_jobs_resources_log (sched_date,moldable_job_id,resource_id)
                        SELECT \'$date\', gantt_jobs_resources.moldable_job_id, gantt_jobs_resources.resource_id
                        FROM gantt_jobs_resources
        ");
    }

    my $sql = "\'1\'";
    my @jobs_to_keep = keys(%{$reservations_to_keep});
    if ($#jobs_to_keep >= 0){
        $sql = "moldable_job_id NOT IN (".join(',',@jobs_to_keep).")";
    }
    #$dbh->do("TRUNCATE TABLE gantt_jobs_predictions");
    $dbh->do("  DELETE FROM gantt_jobs_predictions
                WHERE
                    $sql
             ");
    #$dbh->do("TRUNCATE TABLE gantt_jobs_resources");
    $dbh->do("  DELETE FROM gantt_jobs_resources
                WHERE
                    $sql
             ");
    
#   $dbh->do("OPTIMIZE TABLE ganttJobs, ganttJobsPrediction");
}


sub update_scheduler_last_job_date($$$){
    my $dbh = shift;
    my $date = shift;
    my $moldable_id = shift;

    my $req;
    if ($Db_type eq "Pg"){
        $req = "UPDATE resources
                SET
                    last_job_date = $date
                FROM assigned_resources
                WHERE
                    assigned_resources.moldable_job_id = $moldable_id AND
                    assigned_resources.resource_id = resources.resource_id
               ";
    }else{
        $req = "UPDATE resources, assigned_resources
                SET
                    resources.last_job_date = $date
                WHERE
                    assigned_resources.moldable_job_id = $moldable_id AND
                    assigned_resources.resource_id = resources.resource_id
               ";
    }
    return($dbh->do($req));
}

sub search_idle_nodes($$){
    my $dbh = shift;
    my $date = shift;

    my $req = "SELECT resources.network_address
               FROM resources, gantt_jobs_resources, gantt_jobs_predictions
               WHERE
                   resources.resource_id = gantt_jobs_resources.resource_id AND
                   gantt_jobs_predictions.start_time <= $date AND
                   resources.network_address != \'\' AND
                   resources.type = \'default\' AND
		   gantt_jobs_predictions.moldable_job_id = gantt_jobs_resources.moldable_job_id
               GROUP BY resources.network_address
              ";
              
    my $sth = $dbh->prepare($req);
    $sth->execute();
    my %nodes_occupied;
    while (my @ref = $sth->fetchrow_array()) {
        $nodes_occupied{$ref[0]} = 1;
    }
    $sth->finish();

    $req = "SELECT resources.network_address, MAX(resources.last_job_date)
            FROM resources
            WHERE
                (resources.state = \'Alive\' OR
                resources.state = \'Suspected\') AND
                resources.network_address != \'\' AND
                resources.type = \'default\' AND
                resources.available_upto < 2147483647
            GROUP BY resources.network_address";
    $sth = $dbh->prepare($req);
    $sth->execute();
    my %res ;
    while (my @ref = $sth->fetchrow_array()) {
        if (!defined($nodes_occupied{$ref[0]})){
            $res{$ref[0]} = $ref[1];
        }
    }
    $sth->finish();

    return(%res);
}


sub get_next_job_date_on_node($$){
    my $dbh = shift;
    my $hostname = shift;

    my $req = "SELECT MIN(gantt_jobs_predictions.start_time)
               FROM resources, gantt_jobs_predictions, gantt_jobs_resources
               WHERE
                   resources.network_address = \'$hostname\' AND
                   gantt_jobs_resources.resource_id = resources.resource_id AND
                   gantt_jobs_predictions.moldable_job_id = gantt_jobs_resources.moldable_job_id
              ";

    my $sth = $dbh->prepare($req);
    $sth->execute();
    my @ref = $sth->fetchrow_array();
    $sth->finish();

    return($ref[0]);
}


#Get jobs to launch at a given date
#args : base, date in sql format
sub get_gantt_jobs_to_launch($$){
    my $dbh = shift;
    my $date = shift;

    my $req = "SELECT DISTINCT(j.job_id)
               FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, jobs j, moldable_job_descriptions m, resources
               WHERE
                   m.moldable_index = \'CURRENT\'
                   AND g1.moldable_job_id = g2.moldable_job_id
                   AND m.moldable_id = g1.moldable_job_id
                   AND j.job_id = m.moldable_job_id
                   AND g2.start_time <= $date
                   AND j.state = \'Waiting\'
                   AND resources.resource_id = g1.resource_id
                   AND resources.state != \'Alive\'
              ";
    my $sth = $dbh->prepare($req);
    $sth->execute();
    my %jobs_not_to_launch;
    while (my @ref = $sth->fetchrow_array()) {
        $jobs_not_to_launch{$ref[0]} = 1;
    }
    $sth->finish();

    $req = "    SELECT g2.moldable_job_id, g1.resource_id, j.job_id
                FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, jobs j, moldable_job_descriptions m, resources
                WHERE
                    m.moldable_index = \'CURRENT\'
                    AND g1.moldable_job_id = g2.moldable_job_id
                    AND m.moldable_id = g1.moldable_job_id
                    AND j.job_id = m.moldable_job_id
                    AND g2.start_time <= $date
                    AND j.state = \'Waiting\'
                    AND resources.resource_id = g1.resource_id
                    AND resources.state = \'Alive\'
           ";
    $sth = $dbh->prepare($req);
    $sth->execute();
    my %res ;
    while (my @ref = $sth->fetchrow_array()) {
        if(!defined($jobs_not_to_launch{$ref[2]})){
            $res{$ref[2]}->[0] = $ref[0];
            push(@{$res{$ref[2]}->[1]}, $ref[1]);
        }
    }
    $sth->finish();

    return(%res);
}


#Get hostname that we must wake up to launch jobs
#args : base, date in sql format, time to wait for the node to wake up
sub get_gantt_hostname_to_wake_up($$$){
    my $dbh = shift;
    my $date = shift;
	my $wakeup_time = shift;
    my $req = "SELECT resources.network_address
               FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, jobs j, moldable_job_descriptions m, resources
               WHERE
                   m.moldable_index = \'CURRENT\'
                   AND g1.moldable_job_id= g2.moldable_job_id
                   AND m.moldable_id = g1.moldable_job_id
                   AND j.job_id = m.moldable_job_id
                   AND g2.start_time <= $date + $wakeup_time
                   AND j.state = \'Waiting\'
                   AND resources.resource_id = g1.resource_id
                   AND resources.state = \'Absent\'
                   AND resources.network_address != \'\'
                   AND resources.type = \'default\'
               GROUP BY resources.network_address
              ";
    
    my $sth = $dbh->prepare($req);
    $sth->execute();
    my @res ;
    while (my @ref = $sth->fetchrow_array()) {
        push(@res, $ref[0]);
    }
    $sth->finish();

    return(@res);
}


#Get informations about resources for jobs to launch at a given date
#args : base, date in sql format
sub get_gantt_resources_for_jobs_to_launch($$){
    my $dbh = shift;
    my $date = shift;

    my $req = "SELECT g1.resource_id, j.job_id
               FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, jobs j, moldable_job_descriptions m
               WHERE
                  m.moldable_index = \'CURRENT\'
                  AND g1.moldable_job_id = m.moldable_id
                  AND m.moldable_job_id = j.job_id
                  AND g1.moldable_job_id = g2.moldable_job_id
                  AND g2.start_time <= $date
                  AND j.state = \'Waiting\'
              ";
    
    my $sth = $dbh->prepare($req);
    $sth->execute();
    my %res ;
    while (my @ref = $sth->fetchrow_array()) {
        $res{$ref[0]} = $ref[1];
    }
    $sth->finish();

    return %res;
}


#Get resources for job in the gantt diagram
#args : base, moldable job id
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
#args : base, moldable job id
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


#Get network_address allocated to a (waiting) reservation
#args : base, job id
sub get_gantt_visu_resources_for_resa($$){
    my $dbh = shift;
    my $job = shift;

    my $sth = $dbh->prepare("SELECT r.resource_id, r.network_address, r.state
                             FROM gantt_jobs_resources_visu g, moldable_job_descriptions m, resources r
                             WHERE
                                m.moldable_job_id = $job
                                AND m.moldable_id = g.moldable_job_id
                                AND g.resource_id = r.resource_id
                            ");
    $sth->execute();
    my %h;
    while (my @ref = $sth->fetchrow_array()) {
        $h{$ref[0]}->{'network_addess'}=$ref[1];
        $h{$ref[0]}->{'current_state'}=$ref[2];
    }
    $sth->finish();

    return \%h;
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
    #my ($year,$mon,$mday,$hour,$min,$sec)=local_to_ymdhms($local);
    #return ymdhms_to_sql($year,$mon,$mday,$hour,$min,$sec);
    #return $year."-".$mon."-".$mday." $hour:$min:$sec";
    return(strftime("%F %T",localtime($local)));
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
    $date = int($date / 60);
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
        $req = "select EXTRACT(EPOCH FROM current_timestamp)";
    }else{
        $req = "SELECT UNIX_TIMESTAMP()";
    }
    my $sth = $dbh->prepare($req);
    $sth->execute();
    my @ref = $sth->fetchrow_array();
    $sth->finish();

    return(int($ref[0]));
}


# MONITORING

sub register_monitoring_values($$$$){
    my $dbh = shift;
    my $table = shift;
    my $fields = shift;
    my $values = shift;

    if (! insert_monitoring_row($dbh,$table,$fields,$values)){
        my $create_str;
        $create_str = "CREATE TABLE monitoring_$table (";
        for (my $i=0; $i <= $#{$fields}; $i++){
            if ($values->[$i] =~ /^\d+$/){
                if ($Db_type eq "Pg"){
                    $create_str .= "$fields->[$i] integer,";
                }else{
                    $create_str .= "$fields->[$i] INT,";
                }
            }else{
                $create_str .= "$fields->[$i] varchar(255),"
            }
        }
        chop($create_str);
        $create_str .= ")";
        oar_debug("$create_str\n");
        if ($dbh->do($create_str)){
            if (! insert_monitoring_row($dbh,$table,$fields,$values)){
                return(2);
            }
        }else{
            return(1);
        }
    }
    
    return(0);
}

sub insert_monitoring_row($$$$){
    my $dbh = shift;
    my $table = shift;
    my $fields = shift;
    my $values = shift;

    my $value_str;
    foreach my $v (@{$values}){
        $value_str .= $dbh->quote($v);
        $value_str .= ',';
    }
    chop($value_str);
    return($dbh->do("   INSERT INTO monitoring_$table (".join(",",@{$fields}).")
                        VALUES (".$value_str.")
                    "));
}

# ACCOUNTING

# check jobs that are not treated in accounting table
# params : base, window size
sub check_accounting_update($$){
    my $dbh = shift;
    my $windowSize = shift;

    my $req = "SELECT jobs.start_time, jobs.stop_time, moldable_job_descriptions.moldable_walltime, jobs.job_id, jobs.job_user, jobs.queue_name, count(assigned_resources.resource_id), jobs.project

               FROM jobs, moldable_job_descriptions, assigned_resources, resources
               WHERE 
                   jobs.accounted = \'NO\' AND
                   (jobs.state = \'Terminated\' OR jobs.state = \'Error\') AND
                   jobs.stop_time >= jobs.start_time AND
                   jobs.start_time > 0 AND
                   jobs.assigned_moldable_job = moldable_job_descriptions.moldable_id AND
                   assigned_resources.moldable_job_id = moldable_job_descriptions.moldable_id AND
                   assigned_resources.resource_id = resources.resource_id AND
                   resources.type = 'default'
               GROUP BY jobs.start_time, jobs.stop_time, moldable_job_descriptions.moldable_walltime, jobs.job_id, jobs.project, jobs.job_user, jobs.queue_name
              "; 

    my $sth = $dbh->prepare("$req");
    $sth->execute();

    while (my @ref = $sth->fetchrow_array()) {
        my $start = $ref[0];
        my $stop = $ref[1];
        my $theoricalStopTime = $ref[2] + $start;
        print("[ACCOUNTING] Treate job $ref[3]\n");
        update_accounting($dbh,$start,$stop,$windowSize,$ref[4],$ref[7],$ref[5],"USED",$ref[6]);
        update_accounting($dbh,$start,$theoricalStopTime,$windowSize,$ref[4],$ref[7],$ref[5],"ASKED",$ref[6]);
        $dbh->do("  UPDATE jobs
                    SET accounted = \'YES\'
                    WHERE
                        job_id = $ref[3]
                 ");
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
    my $project = shift;
    my $queue = shift;
    my $type = shift;
    my $nb_resources = shift;

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
        $conso = $conso * $nb_resources;
        add_accounting_row($dbh,$windowStart,$windowStop,$user,$project,$queue,$type,$conso);
        $windowStart = $windowStop + 1;
        $start = $windowStart;
        $windowStop += $windowSize;
    }
}

# start and stop in SQL syntax
sub add_accounting_row($$$$$$$$){
    my $dbh = shift;
    my $start = shift;
    my $stop = shift;
    my $user = shift;
    my $project = shift;
    my $queue = shift;
    my $type = shift;
    my $conso = shift;

    # Test if the window exists
    my $sth = $dbh->prepare("   SELECT consumption
                                FROM accounting
                                WHERE
                                    accounting_user = \'$user\' AND
                                    accounting_project = \'$project\' AND
                                    consumption_type = \'$type\' AND
                                    queue_name = \'$queue\' AND
                                    window_start = \'$start\' AND
                                    window_stop = \'$stop\'
                            ");
    $sth->execute();
    my @ref = $sth->fetchrow_array();
    if (defined($ref[0])){
        # Update the existing window
        $conso += $ref[0];
        print("[ACCOUNTING] Update the existing window $start --> $stop , project $project, user $user, queue $queue, type $type with conso = $conso s\n");
        $dbh->do("  UPDATE accounting
                    SET consumption = $conso
                    WHERE
                        accounting_user = \'$user\' AND
                        accounting_project = \'$project\' AND
                        consumption_type = \'$type\' AND
                        queue_name = \'$queue\' AND
                        window_start = \'$start\' AND
                        window_stop = \'$stop\'
                ");
    }else{
        # Create the window
        print("[ACCOUNTING] Create new window $start --> $stop , project $project, user $user, queue $queue, type $type with conso = $conso s\n");
        $dbh->do("  INSERT INTO accounting (accounting_user,consumption_type,queue_name,window_start,window_stop,consumption,accounting_project)
                    VALUES (\'$user\',\'$type\',\'$queue\',\'$start\',\'$stop\',$conso,\'$project\')
                 ");
    }
}


sub get_sum_accounting_window($$$$){
    my $dbh = shift;
    my $queue = shift;
    my $start_window = shift;
    my $stop_window = shift;
    
    my $sth = $dbh->prepare("   SELECT consumption_type, SUM(consumption)
                                FROM accounting
                                WHERE
                                    queue_name = \'$queue\' AND
                                    window_start >= $start_window AND
                                    window_start < $stop_window
                                GROUP BY consumption_type
                            ");
    $sth->execute();

    my $results;
    while (my @r = $sth->fetchrow_array()) {
        $results->{$r[0]} = $r[1];
    }
    $sth->finish();

    return($results);
}


sub get_sum_accounting_for_param($$$$$){
    my $dbh = shift;
    my $queue = shift;
    my $param_name = shift;
    my $start_window = shift;
    my $stop_window = shift;
    
    my $sth = $dbh->prepare("   SELECT $param_name,consumption_type, SUM(consumption)
                                FROM accounting
                                WHERE
                                    queue_name = \'$queue\' AND
                                    window_start >= $start_window AND
                                    window_start < $stop_window
                                GROUP BY $param_name,consumption_type
                            ");
    $sth->execute();

    my $results;
    while (my @r = $sth->fetchrow_array()) {
        $results->{$r[0]}->{$r[1]} = $r[2];
    }
    $sth->finish();

    return($results);
}


# Get an array of consumptions by users 
# params: base, start date, ending date, optional user
sub get_accounting_summary($$$$){
    my $dbh = shift;
    my $start = shift;
    my $stop = shift;
    my $user = shift;
    my $user_query="";
    if (defined($user) && "$user" ne "") {
        $user_query="AND accounting_user = ". $dbh->quote($user);
    }

    my $sth = $dbh->prepare("   SELECT accounting_user as user,
                                       consumption_type,
                                       sum(consumption) as seconds,
                                       floor(sum(consumption)/3600) as hours,
                                       min(window_start) as first_window_start,
                                       max(window_stop) as last_window_stop
                                FROM accounting
                                WHERE
                                    window_stop > $start AND
                                    window_start < $stop
                                    $user_query
                                GROUP BY accounting_user,consumption_type
                                ORDER BY seconds
                            ");
    $sth->execute();

    my $results;
    while (my @r = $sth->fetchrow_array()) {
        $results->{$r[0]}->{$r[1]} = $r[2];
        $results->{$r[0]}->{begin} = $r[4];
        $results->{$r[0]}->{end} = $r[5];
    }
    $sth->finish();

    return($results);
}


# Get an array of consumptions by project for a given user
# params: base, start date, ending date, user
sub get_accounting_summary_byproject($$$$){
    my $dbh = shift;
    my $start = shift;
    my $stop = shift;
    my $user = shift;
    my $user_query="";
    if ("$user" ne "") {
        $user_query="AND accounting_user = ". $dbh->quote($user);
    }

    my $sth = $dbh->prepare("   SELECT accounting_user as user,
                                       consumption_type,
                                       sum(consumption) as seconds,
                                       accounting_project as project
                                FROM accounting
                                WHERE
                                    window_stop > $start AND
                                    window_start < $stop
                                    $user_query
                                GROUP BY accounting_user,project,consumption_type
                                ORDER BY project,consumption_type,seconds
                            ");
    $sth->execute();

    my $results;
    while (my @r = $sth->fetchrow_array()) {
        $results->{$r[3]}->{$r[1]}->{$r[0]} = $r[2];
    }
    $sth->finish();

    return($results);
}

# Empty the table accounting and update the jobs table
sub delete_all_from_accounting($){
    my $dbh = shift;

    $dbh->do("DELETE FROM accounting");
    $dbh->do("UPDATE jobs SET accounted = 'NO'");
}

# Remove windows from accounting
sub delete_accounting_windows_before($$){
    my $dbh = shift;
    my $duration = shift;

    $dbh->do("DELETE FROM accounting WHERE window_stop <= $duration");
}

# Get the last project Karma of user at a given date
# params: base,user,project,date
sub get_last_project_karma($$$$) {
    my $dbh = shift;
    my $user = $dbh->quote(shift);
    my $project = $dbh->quote(shift);
    my $date = shift;

    my $sth = $dbh->prepare("   SELECT message,project,start_time
                                FROM jobs
                                WHERE
                                      job_user = $user AND
                                      message like \'Karma = %\' AND
                                      project = $project AND
                                      start_time < $date
                                ORDER BY start_time desc
                                LIMIT 1
                          ");

    $sth->execute();

    return($sth->fetchrow_array());
}


#EVENTS LOG MANAGEMENT

#add a new entry in event_log table
#args : database ref, event type, job_id , description
sub add_new_event($$$$){
    my $dbh = shift;
    my $type = shift;
    my $job_id = shift;
    my $description = substr(shift,0,254);

    $description = $dbh->quote($description);
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

    my %tmp;
    foreach my $n (@{$hostnames}){
        if (!defined($tmp{$n})){
            $dbh->do("  INSERT INTO event_log_hostnames (event_id,hostname)
                        VALUES ($event_id,\'$n\')
                     ");
            $tmp{$n} = 1;
        }
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
    my $sth = $dbh->prepare("   SELECT type, job_id, event_id, description
                                FROM event_logs
                                WHERE
                                    to_check = \'YES\'
                                ORDER BY event_id
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

# Get events for the hostname given as parameter
# If date is given, returns events since that date, else return the 30 last events.
# args: database ref, network_address, date
sub get_events_for_hostname($$$){
    my $dbh = shift;
    my $host = shift;
    my $date = shift;
    my $sth;
    if ($date eq "") {
        $sth = $dbh->prepare("SELECT *
                              FROM event_log_hostnames, event_logs 
                              WHERE
                                  event_log_hostnames.event_id = event_logs.event_id
                                  AND event_log_hostnames.hostname = '$host'
                              ORDER BY event_logs.date DESC
                              LIMIT 30");
    } else {
        $sth = $dbh->prepare("SELECT *
                              FROM event_log_hostnames, event_logs
                              WHERE
                                  event_log_hostnames.event_id = event_logs.event_id
                                  AND event_log_hostnames.hostname = '$host'
                                  AND event_logs.date >= " . 
                             sql_to_local($date) .
                             " ORDER BY event_logs.date DESC");
    }
    $sth->execute();

    my @results;
    while (my $ref = $sth->fetchrow_hashref()) {
        unshift(@results, $ref);
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


sub is_an_event_exists($$$){
    my $dbh =shift;
    my $jobId = shift;
    my $event = shift;

    my $sth = $dbh->prepare("   SELECT COUNT(*)
                                FROM event_logs
                                WHERE
                                    job_id = $jobId AND
                                    type = \'$event\'
                                LIMIT 1
                            ");
    $sth->execute();
    my @r = $sth->fetchrow_array();
    $sth->finish();

    return($r[0]);
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

    if ($Db_type eq "Pg"){
        #$dbh->begin_work();
        #Cannot find the GET_LOCK function into postgres...
        return 1;
    }else{
        my $sth = $dbh->prepare("SELECT GET_LOCK(\"$mutex\",$timeout)");
        $sth->execute();
        my ($res) = $sth->fetchrow_array();
        $sth->finish();
	if ($res eq "0") {
            return 0;
        } elsif ($res eq "1") {
            return 1;
        }
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

    if ($Db_type eq "Pg"){
        #$dbh->commit();
        return 1;
    }else{
        my $sth = $dbh->prepare("SELECT RELEASE_LOCK(\"$mutex\")");
        $sth->execute();
        my ($res) = $sth->fetchrow_array();
        $sth->finish();
	if ($res eq "0") {
            return 0;
        } elsif ($res eq "1") {
            return 1;
        }
    }
    return undef;
}


sub lock_table($$){
    my $dbh = shift;
    my $tables= shift;

    if ($Db_type eq "Pg"){
        $dbh->begin_work();
    }else{
        my $str = "LOCK TABLE ";
        foreach my $t (@{$tables}){
            $str .= "$t WRITE,";
        }
        chop($str);
        $dbh->do($str);
    }
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
sub check_end_of_job($$$$$$$$$$){
    my $base = shift;
    my $Jid = shift;
    my $exit_script_value = shift;
    my $error = shift;
    my $hosts = shift;
    my $remote_host = shift;
    my $remote_port = shift;
    my $user = shift;
    my $launchingDirectory = shift;
    my $server_epilogue_script = shift;

    #lock_table($base,["jobs","job_state_logs","resources","assigned_resources","resource_state_logs","event_logs","challenges","moldable_job_descriptions","job_types","job_dependencies","job_resource_groups","job_resource_descriptions"]);
    lock_table($base,["jobs","job_state_logs","assigned_resources"]);
    my $refJob = get_job($base,$Jid);
    if (($refJob->{'state'} eq "Running") or ($refJob->{'state'} eq "Launching") or ($refJob->{'state'} eq "Suspended") or ($refJob->{'state'} eq "Resuming")){
        oar_Judas::oar_debug("[bipbip $Jid] Job $Jid is ended\n");
        set_finish_date($base,$Jid);
        set_job_state($base,$Jid,"Finishing");
        set_job_exit_code($base,$Jid,$exit_script_value) if ($exit_script_value =~ /^\d+$/);
        unlock_table($base);
        my @events;
        if($error == 0){
            oar_Judas::oar_debug("[bipbip $Jid] User Launch completed OK\n");
            push(@events, {type => "SWITCH_INTO_TERMINATE_STATE", string => "[bipbip $Jid] Ask to change the job state"});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
            oar_Tools::notify_tcp_socket($remote_host,$remote_port,"Term");
        }elsif ($error == 1){
            #Prologue error
            my $strWARN = "[bipbip $Jid] error of oarexec prologue";
            push(@events, {type => "PROLOGUE_ERROR", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 2){
            #Epilogue error
            my $strWARN = "[bipbip $Jid] error of oarexec epilogue (jobId = $Jid)";
            push(@events, {type => "EPILOGUE_ERROR", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 3){
            #Oarexec is killed by Leon normaly
            push(@events, {type => "SWITCH_INTO_ERROR_STATE", string => "[bipbip $Jid] Ask to change the job state"});
            my $strWARN = "[bipbip $Jid] the job $Jid was killed by Leon";
            oar_Judas::oar_debug("$strWARN\n");
            my $types = iolib::get_current_job_types($base,$Jid);
            if ((defined($types->{besteffort})) and (defined($types->{idempotent}))){
                if (iolib::is_an_event_exists($base,$Jid,"BESTEFFORT_KILL") > 0){
                    my $new_job_id = iolib::resubmit_job($base,$Jid);
                    oar_warn("[bipbip] We resubmit the job $Jid (new id = $new_job_id) because it is a besteffort and idempotent job.\n");
                    push(@events, {type => "RESUBMIT_JOB_AUTOMATICALLY", string => "[bipbip $Jid] the job $Jid is a besteffort and idempotent job so we resubmit it (new id = $new_job_id)"});
                }
            }
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 4){
            #Oarexec was killed by Leon and epilogue of oarexec is in error
            push(@events, {type => "SWITCH_INTO_ERROR_STATE", string => "[bipbip $Jid] Ask to change the job state"});
            my $strWARN = "[bipbip $Jid] The job $Jid was killed by Leon and oarexec epilogue was in error";
            my $types = iolib::get_current_job_types($base,$Jid);
            if ((defined($types->{besteffort})) and (defined($types->{idempotent}))){
                if (iolib::is_an_event_exists($base,$Jid,"BESTEFFORT_KILL") > 0){
                    my $new_job_id = iolib::resubmit_job($base,$Jid);
                    oar_warn("[bipbip] We resubmit the job $Jid (new id = $new_job_id) because it is a besteffort and idempotent job.\n");
                    push(@events, {type => "RESUBMIT_JOB_AUTOMATICALLY", string => "[bipbip $Jid] The job $Jid is a besteffort and idempotent job so we resubmit it (new id = $new_job_id)"});
                }
            }
            push(@events, {type => "EPILOGUE_ERROR", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 5){
            #Oarexec is not able to write in the node file
            my $strWARN = "[bipbip $Jid] oarexec cannot create the node file";
            push(@events, {type => "CANNOT_WRITE_NODE_FILE", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 6){
            #Oarexec can not write its pid file
            my $strWARN = "[bipbip $Jid] oarexec cannot write its pid file";
            push(@events, {type => "CANNOT_WRITE_PID_FILE", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 7){
            #Can t get shell of user
            my $strWARN = "[bipbip $Jid] Cannot get shell of user $user, so I suspect node $hosts->[0]";
            push(@events, {type => "USER_SHELL", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 8){
            #Oarexec can not create tmp directory
            my $strWARN = "[bipbip $Jid] oarexec cannot create tmp directory on $hosts->[0] : ".oar_Tools::get_default_oarexec_directory();
            push(@events, {type => "CANNOT_CREATE_TMP_DIRECTORY", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 10){
            #oarexecuser.sh can not go into working directory
            push(@events, {type => "SWITCH_INTO_ERROR_STATE", string => "[bipbip $Jid] Ask to change the job state"});
            my $strWARN = "[bipbip $Jid] Cannot go into the working directory $launchingDirectory of the job on node $hosts->[0]";
            push(@events, {type => "WORKING_DIRECTORY", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 20){
            #oarexecuser.sh can not write stdout and stderr files
            push(@events, {type => "SWITCH_INTO_ERROR_STATE", string => "[bipbip $Jid] Ask to change the job state"});
            my $strWARN = "[bipbip $Jid] Cannot create .stdout and .stderr files in $launchingDirectory on the node $hosts->[0]";
            push(@events, {type => "OUTPUT_FILES", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 12){
            #oarexecuser.sh can not go into working directory and epilogue is in error
            push(@events, {type => "SWITCH_INTO_ERROR_STATE", string => "[bipbip $Jid] Ask to change the job state"});
            my $strWARN = "[bipbip $Jid] Cannot go into the working directory $launchingDirectory of the job on node $hosts->[0] AND epilogue is in error";
            oar_warn("$strWARN\n");
            push(@events, {type => "WORKING_DIRECTORY", string => $strWARN});
            push(@events, {type => "EPILOGUE_ERROR", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 22){
            #oarexecuser.sh can not create STDOUT and STDERR files and epilogue is in error
            push(@events, {type => "SWITCH_INTO_ERROR_STATE", string => "[bipbip $Jid] Ask to change the job state"});
            my $strWARN = "[bipbip $Jid] Cannot create STDOUT and STDERR files AND epilogue is in error";
            oar_warn("$strWARN\n");
            push(@events, {type => "OUTPUT_FILES", string => $strWARN});
            push(@events, {type => "EPILOGUE_ERROR", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 30){
            #oarexec timeout on bipbip hashtable transfer via SSH
            my $strWARN = "[bipbip $Jid] Timeout SSH hashtable transfer on $hosts->[0]";
            push(@events, {type => "SSH_TRANSFER_TIMEOUT", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 31){
            #oarexec got a bad hashtable dump from bipbip
            my $strWARN = "[bipbip $Jid] Bad hashtable dump on $hosts->[0]";
            push(@events, {type => "BAD_HASHTABLE_DUMP", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 33){
            #oarexec received a SIGUSR1 signal and there was an epilogue error
            push(@events, {type => "SWITCH_INTO_TERMINATE_STATE", string => "[bipbip $Jid] Ask to change the job state"});
            my $strWARN = "[bipbip $Jid] oarexec received a SIGUSR1 signal and there was an epilogue error";
            #add_new_event($base,"STOP_SIGNAL_RECEIVED",$Jid,"$strWARN");
            push(@events, {type => "EPILOGUE_ERROR", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 34){
            #oarexec received a SIGUSR1 signal
            push(@events, {type => "SWITCH_INTO_TERMINATE_STATE", string => "[bipbip $Jid] Ask to change the job state"});
            my $strWARN = "[bipbip $Jid] oarexec received a SIGUSR1 signal; so INTERACTIVE job is ended";
            oar_Judas::oar_debug("$strWARN\n");
            #add_new_event($base,"STOP_SIGNAL_RECEIVED",$Jid,"$strWARN");
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
            oar_Tools::notify_tcp_socket($remote_host,$remote_port,"Term");
        }elsif ($error == 50){
    	    # launching oarexec timeout
            my $strWARN = "[bipbip $Jid] launching oarexec timeout, exit value = $error; the job $Jid is in Error and the node $hosts->[0] is Suspected";
            push(@events, {type => "LAUNCHING_OAREXEC_TIMEOUT", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }elsif ($error == 40){
            #oarexec received a SIGUSR2 signal
            push(@events, {type => "SWITCH_INTO_TERMINATE_STATE", string => "[bipbip $Jid] Ask to change the job state"});
            my $strWARN = "[bipbip $Jid] oarexec received a SIGUSR2 signal; so user process has received a checkpoint signal";
            oar_Judas::oar_debug("$strWARN\n");
            my $types = iolib::get_current_job_types($base,$Jid);
            if ((defined($types->{idempotent})) and ($exit_script_value =~ /^\d+$/)){
                if ($exit_script_value == 0){
                    my $new_job_id = iolib::resubmit_job($base,$Jid);
                    oar_warn("[bipbip] We resubmit the job $Jid (new id = $new_job_id) because it was checkpointed and it is of the type 'idempotent'.\n");
                    push(@events, {type => "RESUBMIT_JOB_AUTOMATICALLY", string => "[bipbip $Jid] The job $Jid was checkpointed and it is of the type 'idempotent' so we resubmit it (new id = $new_job_id)"});
                }else{
                    oar_warn("[bipbip] We cannot resubmit the job $Jid even if it was checkpointed and of the type 'idempotent' because its exit code was not 0 ($exit_script_value).\n");
                    push(@events, {type => "RESUBMIT_JOB_AUTOMATICALLY_CANCELLED", string => "The job $Jid was checkpointed and it is of the type 'idempotent' but its exit code is $exit_script_value"});
                }
            }
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
            oar_Tools::notify_tcp_socket($remote_host,$remote_port,"Term");
        }elsif ($error == 42){
            #oarexec received a user signal
            push(@events, {type => "SWITCH_INTO_TERMINATE_STATE", string => "[bipbip $Jid] Ask to change the job state"});
            my $strWARN = "[bipbip $Jid] oarexec received a SIGURG signal; so user process has received the user defined signal";
            oar_Judas::oar_debug("$strWARN\n");
            my $types = iolib::get_current_job_types($base,$Jid);
            if ((defined($types->{idempotent})) and ($exit_script_value =~ /^\d+$/)){
                if ($exit_script_value == 0){
                    my $new_job_id = iolib::resubmit_job($base,$Jid);
                    oar_warn("[bipbip] We resubmit the job $Jid (new id = $new_job_id) because it was signaled and it is of the type 'idempotent'.\n");
                    push(@events, {type => "RESUBMIT_JOB_AUTOMATICALLY", string => "[bipbip $Jid] The job $Jid was signaled and it is of the type 'idempotent' so we resubmit it (new id = $new_job_id)"});
                }else{
                    oar_warn("[bipbip] We cannot resubmit the job $Jid even if it was signaled and of the type 'idempotent' because its exit code was not 0 ($exit_script_value).\n");
                    push(@events, {type => "RESUBMIT_JOB_AUTOMATICALLY_CANCELLED", string => "The job $Jid was signaled and it is of the type 'idempotent' but its exit code is $exit_script_value"});
                }
            }
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
            oar_Tools::notify_tcp_socket($remote_host,$remote_port,"Term");
	}elsif ($error == 41){
            #oarexec received a SIGUSR2 signal
            push(@events, {type => "SWITCH_INTO_TERMINATE_STATE", string => "[bipbip $Jid] Ask to change the job state"});
            my $strWARN = "[bipbip $Jid] oarexec received a SIGUSR2 signal and there was an epilogue error; so user process has received a checkpoint signal";
            oar_Judas::oar_debug("$strWARN\n");
            my $types = iolib::get_current_job_types($base,$Jid);
            if ((defined($types->{idempotent})) and ($exit_script_value =~ /^\d+$/)){
                if ($exit_script_value == 0){
                    my $new_job_id = iolib::resubmit_job($base,$Jid);
                    oar_warn("[bipbip] We resubmit the job $Jid (new id = $new_job_id) because it was checkpointed and it is of the type 'idempotent'.\n");
                    push(@events, {type => "RESUBMIT_JOB_AUTOMATICALLY", string => "[bipbip $Jid] The job $Jid was checkpointed and it is of the type 'idempotent' so we resubmit it (new id = $new_job_id)"});
                }else{
                    oar_warn("[bipbip] We cannot resubmit the job $Jid even if it was checkpointed and of the type 'idempotent' because its exit code was not 0 ($exit_script_value).\n");
                    push(@events, {type => "RESUBMIT_JOB_AUTOMATICALLY_CANCELLED", string => "[bipbip $Jid] The job $Jid was checkpointed and it is of the type 'idempotent' but its exit code is $exit_script_value"});
                }
            }
            push(@events, {type => "EPILOGUE_ERROR", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
            oar_Tools::notify_tcp_socket($remote_host,$remote_port,"Term");
        }else{
            my $strWARN = "[bipbip $Jid] error of oarexec, exit value = $error; the job $Jid is in Error and the node $hosts->[0] is Suspected";
            push(@events, {type => "EXIT_VALUE_OAREXEC", string => $strWARN});
            job_finishing_sequence($base,$server_epilogue_script,$remote_host,$remote_port,$Jid,\@events);
        }
    }else{
        oar_Judas::oar_debug("[bipbip $Jid] I was previously killed or Terminated but I did not know that!!\n");
        unlock_table($base);
    }

    oar_Tools::notify_tcp_socket($remote_host,$remote_port,"BipBip");
}


sub job_finishing_sequence($$$$$$){
    my ($dbh,
        $epilogue_script,
        $almighty_host,
        $almighty_port,
        $job_id,
        $events) = @_;

    if (defined($epilogue_script)){
        # launch server epilogue
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
            $SIG{PIPE} = 'IGNORE';
            $SIG{ALRM} = sub { die "alarm\n" };
            alarm($timeout);
            $pid = fork();
            if ($pid == 0){
                undef($dbh);
                exec($cmd);
                warn("[ERROR] Cannot find $cmd\n");
                exit(-1);
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
                if (defined($pid)){
                    my ($children,$cmd_name) = oar_Tools::get_one_process_children($pid);
                    kill(9,@{$children});
                }
                my $str = "[JOB FINISHING SEQUENCE] Server epilogue timeouted (cmd : $cmd)";
                oar_error("$str\n");
                push(@{$events}, {type => "SERVER_EPILOGUE_TIMEOUT", string => $str});
            }
        }elsif ($exit_value != 0){
            my $str = "[JOB FINISHING SEQUENCE] Server epilogue exit code $exit_value (!=0) (cmd : $cmd)";
            oar_error("$str\n");
            push(@{$events}, {type => "SERVER_EPILOGUE_EXIT_CODE_ERROR", string => $str});
        }
    }
    
   
    my $types = iolib::get_current_job_types($dbh,$job_id);
    if ((!defined($types->{deploy})) and (!defined($types->{cosystem}))){
        ###############
        # CPUSET PART #
        ###############
        # Clean all CPUSETs if needed
        my $cpuset_field = get_conf("JOB_RESOURCE_MANAGER_PROPERTY_DB_FIELD");
        if (defined($cpuset_field)){
            my $cpuset_name = iolib::get_job_cpuset_name($dbh, $job_id);
            my $openssh_cmd = get_conf("OPENSSH_CMD");
            $openssh_cmd = oar_Tools::get_default_openssh_cmd() if (!defined($openssh_cmd));
            if (is_conf("OAR_SSH_CONNECTION_TIMEOUT")){
                oar_Tools::set_ssh_timeout(get_conf("OAR_SSH_CONNECTION_TIMEOUT"));
            }
            my $cpuset_file = get_conf("JOB_RESOURCE_MANAGER_FILE");
            $cpuset_file = oar_Tools::get_default_cpuset_file() if (!defined($cpuset_file));
            $cpuset_file = "$ENV{OARDIR}/$cpuset_file" if ($cpuset_file !~ /^\//);
            my $cpuset_path = get_conf("CPUSET_PATH");
            my $cpuset_full_path;
            if (defined($cpuset_path) and defined($cpuset_field)){
                $cpuset_full_path = $cpuset_path.'/'.$cpuset_name;
            }
            my $job_uid_resource_type = get_conf("JOB_RESOURCE_MANAGER_JOB_UID_TYPE");
            
            my $job = get_job($dbh, $job_id);
            my $cpuset_nodes = iolib::get_cpuset_values_for_a_moldable_job($dbh,$cpuset_field,$job->{assigned_moldable_job});
            if (defined($cpuset_nodes) and (keys(%{$cpuset_nodes}) > 0)){
                oar_Judas::oar_debug("[JOB FINISHING SEQUENCE] [CPUSET] [$job_id] Clean cpuset on each nodes\n");
                my $taktuk_cmd = get_conf("TAKTUK_CMD");
                my $job_cpuset_uid;
                $job_cpuset_uid = iolib::get_job_cpuset_uid($dbh, $job->{assigned_moldable_job}, $job_uid_resource_type, $cpuset_field) if (defined($job_uid_resource_type));
                my $job_user = oar_Tools::format_job_user($job->{job_user},$job_id,$job_cpuset_uid);
                my ($job_challenge,$ssh_private_key,$ssh_public_key) = iolib::get_job_challenge($dbh,$job_id);
                $ssh_public_key = oar_Tools::format_ssh_pub_key($ssh_public_key,$cpuset_full_path,$job->{job_user},$job_user);

                my $cpuset_data_hash = {
                    job_id => $job_id,
                    name => $cpuset_name,
                    nodes => $cpuset_nodes,
                    cpuset_path => $cpuset_path,
                    ssh_keys => {
                                    public => {
                                                file_name => oar_Tools::get_default_oar_ssh_authorized_keys_file(),
                                                key => $ssh_public_key
                                              },
                                    private => {
                                                file_name => oar_Tools::get_private_ssh_key_file_name($cpuset_name),
                                                key => $ssh_private_key
                                               }
                                },
                    oar_tmp_directory => oar_Tools::get_default_oarexec_directory(),
                    user => $job->{job_user},
                    job_user => $job_user,
                    job_uid => $job_cpuset_uid,
                    types => $types,
                    log_level => oar_Judas::get_log_level()
                };
                my ($tag,@bad) = oar_Tools::manage_remote_commands([keys(%{$cpuset_nodes})],$cpuset_data_hash,$cpuset_file,"clean",$openssh_cmd,$taktuk_cmd,$dbh);
                if ($tag == 0){
                    my $str = "[JOB FINISHING SEQUENCE] [CPUSET] [$job_id] Bad cpuset file : $cpuset_file\n";
                    oar_error($str);
                    push(@{$events}, {type => "CPUSET_MANAGER_FILE", string => $str});
                }elsif ($#bad >= 0){
                    oar_error("[job_finishing_sequence] [$job_id] Cpuset error and register event CPUSET_CLEAN_ERROR on nodes : @bad\n");
                    push(@{$events}, {type => "CPUSET_CLEAN_ERROR", string => "[job_finishing_sequence] OAR suspects nodes for the job $job_id : @bad", hosts => \@bad});
                }
            }
        }
        ####################
        # CPUSET PART, END #
        ####################
    }

    foreach my $e (@{$events}){
        oar_Judas::oar_debug("$e->{string}\n");
        if (defined($e->{hosts})){
            add_new_event_with_host($dbh,$e->{type},$job_id,$e->{string},$e->{hosts});
        }else{
            add_new_event($dbh,$e->{type},$job_id,$e->{string});
        }
    }

    # Just to force commit
    lock_table($dbh,["accounting"]);
    unlock_table($dbh);

    oar_Tools::notify_tcp_socket($almighty_host,$almighty_port,"ChState") if ($#{$events} >= 0);
}


# END OF THE MODULE
return 1;
