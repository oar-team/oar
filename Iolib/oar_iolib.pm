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
# WE SHOULD FORCE USE STRICT !!!
#use strict;

# PROTOTYPES

# CONNECTION
sub connect();
sub disconnect($);

# JOBS MANAGEMENT
sub get_job_bpid($$);
sub set_job_bpid($$$);
sub get_jobs_in_state($$);
sub is_job_desktopComputing($$);
sub get_job_host_distinct($$);
sub get_job_host_log($$);
sub get_job_host_to_frag($$);
sub get_job_cmd_user($$);
sub get_tokill_job($);
sub is_tokill_job($$);
sub get_timered_job($);
sub get_toexterminate_job($);
sub get_frag_date($$);
sub set_running_date($$);
sub set_running_date_arbitrary($$$);
sub set_finish_date($$);
sub set_job_number_of_nodes($$$);
sub form_job_properties($$);
sub add_micheline_job($$$$$$$$$$$);
sub get_oldest_waiting_idjob($);
sub get_oldest_waiting_idjob_by_queue($$);
sub get_job_list(@);
sub shift_job(\@);
sub get_job($$);
sub set_job_state($$$);
sub set_job_resa_state($$$);
sub set_job_message($$$);
sub frag_job($$);
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

# PROCESSJOBS MANAGEMENT (Host assignment to jobs)
sub delete_job_process($$);
sub delete_job_process_log($$);
sub get_host_job_distinct($$);
sub get_running_host($);
sub add_node_job_pair($$$);
sub remove_node_job_pair($$$);

# NODES MANAGEMENT
sub add_node($$$$$);
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
sub get_node_info($$);
sub get_weight_node($$);
sub set_weight_node($$$);
sub decrease_weight($$);
sub set_node_state($$$$);
sub update_node_nextFinaudDecision($$$);
sub get_all_node_properties($$);
sub get_all_nodes_properties($);
sub get_node_change_state($);
sub set_node_nextState($$$);
sub set_node_expiryDate($$$);
sub set_node_property($$$$);
sub get_constraint_string($$);
sub get_maxweight_one_node($$);
sub get_node_dead_range_date($$$);
sub get_expired_nodes($);
sub is_node_desktop_computing($$);
sub get_node_stats($);
sub order_property_node($$$);

# QUEUES MANAGEMENT
sub get_highestpriority_nonempty_queue($);
sub get_queues($);

# GANTT MANAGEMENT
sub get_gantt_scheduled_jobs($);
sub get_gantt_visu_scheduled_jobs($);
sub add_gantt_scheduled_jobs($$$$);
sub gantt_flush_tables($);
sub set_gantt_date($$);
sub get_gantt_date($);
sub get_gantt_visu_date($);
sub get_gantt_jobs_to_launch($$);
sub get_gantt_nodes_for_jobs_to_launch($$);
sub get_gantt_nodes_for_job($$);
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

# MESSAGES, INTERNAL STATE AND DEBUGGING
sub show_table($$);

#EVENTS LOG MANAGEMENT
sub add_new_event($$$$);
sub add_new_event_with_host($$$$$);
sub check_event($$$);
sub get_to_check_events($);
sub get_hostname_event($$);

# ACCOUNTING
sub check_accounting_update($$);
sub update_accounting($$$$$$$$$);

# LOCK FUNCTIONS:

sub get_lock($$$);
sub release_lock($$);

# END OF PROTOTYPES

my $besteffortQueueName = "besteffort";



# CONNECTION

# connect
# Connects to database and returns the base identifier
# parameters : /
# return value : base
# side effects : opens a connection to the base specified in ConfLib
sub connect() {
    # Connect to the database.
    init_conf("oar.conf");

    $host = get_conf("DB_HOSTNAME");
    $name = get_conf("DB_BASE_NAME");
    $user = get_conf("DB_BASE_LOGIN");
    $pwd = get_conf("DB_BASE_PASSWD");

    my $dbh = DBI->connect("DBI:mysql:database=$name;host=$host",
    $user, $pwd,
    {'RaiseError' => 1,'InactiveDestroy' => 1});
    return $dbh;
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
    my $sth = $dbh->prepare("SELECT bpid FROM jobs WHERE idJob = $jobid");
    $sth->execute();

    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    return($$ref{'bpid'});
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

    my $sth = $dbh->prepare("UPDATE jobs SET bpid = \"$bipbippid\" WHERE idJob =\"$idJob\"");
    $sth->execute();
    $sth->finish();

}



# get_jobs_in_state
# returns the list of ids of jobs in the specified state
# parameters : base, job state
# return value : flatened list of (idJob, jobType, infoType) triples
# side effects : /
sub get_jobs_in_state($$) {
    my $dbh = shift;
    my $state = shift;

    my $sth = $dbh->prepare("SELECT * FROM jobs WHERE state=\"$state\"");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        #push(@res, $ref->{'idJob'}, $ref->{'jobType'}, $ref->{'infoType'});
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

# get_job_host_distinct
# returns the list of hosts associated to the job passed in parameter
# parameters : base, jobid
# return value : list of distinct hostnames
# side effects : /
sub get_job_host_distinct($$) {
    my $dbh = shift;
    my $jobid= shift;
    my $sth = $dbh->prepare("SELECT distinct hostname FROM processJobs WHERE idJob = $jobid ORDER BY hostname");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
    }
    return @res;
}



# get_job_host_log
# returns the list of hosts associated to the job passed in parameter
# parameters : base, jobid
# return value : list of distinct hostnames
# side effects : /
sub get_job_host_log($$) {
    my $dbh = shift;
    my $jobid= shift;
    my $sth = $dbh->prepare("SELECT distinct hostname FROM processJobs_log WHERE idJob = $jobid ORDER BY hostname");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
    }
    return @res;
}


# get_job_host_to_frag
# gets the list of hosts associated to the job passed in parameter (that should
# be in state 'ToKill') and on which the user has no other jobs running
# parameters : base, jobid
# return value : list of hostnames
# side effects : /
sub get_job_host_to_frag($$) {
    my $dbh = shift;
    my $jobid= shift;

    # gets the user associated to the job
    my $sth1 = $dbh->prepare("DROP TABLE IF EXISTS userJob");
    my $sth2 = $dbh->prepare("create temporary table userJob
                              select user
                              from jobs
                              where idJob = '".$jobid."'");

    # gets the list of hosts on which the job is deployed
    my $sth3 = $dbh->prepare("DROP TABLE IF EXISTS hostnameJob");
    my $sth4 = $dbh->prepare("create temporary table hostnameJob
                              select distinct hostname
                              from processJobs
                              where idJob = '".$jobid."'");

    # gets the list of running jobs associated to the user
    my $sth5 = $dbh->prepare("DROP TABLE IF EXISTS idUserJob");
    my $sth6 = $dbh->prepare("create temporary table idUserJob
                              select j.idJob
                              from jobs as j, userJob as u
                              where     j.user = u.user
                              and j.state = \"Running\"");

    # gets the list of hosts on which there exists some running job of the user
    my $sth7 = $dbh->prepare("DROP TABLE IF EXISTS hostnameOtherJob");
    my $sth8 = $dbh->prepare("create temporary table hostnameOtherJob
                              select distinct p.hostname
                              from processJobs as p, idUserJob as h
                              where p.idJob = h.idJob");

    # gets the list of hosts associated to the job and on which the user has
    # no other running jobs
    my $sth9 = $dbh->prepare("select hostnameJob.hostname
                              from hostnameJob left join hostnameOtherJob on hostnameJob.hostname = hostnameOtherJob.hostname
                              where hostnameOtherJob.hostname is NULL");
    $sth1->execute();
    $sth2->execute();
    $sth3->execute();
    $sth4->execute();
    $sth5->execute();
    $sth6->execute();
    $sth7->execute();
    $sth8->execute();
    $sth9->execute();

    my @res = ();
    while (my $ref = $sth9->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
    }
    return @res;
}



# get_job_cmd_user
# returns the command associated to the job passed in parameter
# parameters : base, jobid
# return value : user, command (flatened list of couples)
# side effects : /
sub get_job_cmd_user($$) {
    my $dbh = shift;
    my $jobid= shift;
    my $sth = $dbh->prepare("SELECT command,user,launchingDirectory,weight,queueName
                             FROM jobs
                             WHERE $jobid = idJob");
    $sth->execute();
    my @res = ();
    my $ref = $sth->fetchrow_hashref();
    push(@res, $ref->{'user'}, $ref->{'command'}, $ref->{'launchingDirectory'}, $ref->{'weight'}, $ref->{'queueName'});

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
    my $sth = $dbh->prepare("SELECT fragIdJob FROM fragJobs
                             WHERE fragState = \"LEON\"");
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
    my $sth = $dbh->prepare("SELECT fragIdJob FROM fragJobs
                             WHERE fragState = \"LEON_EXTERMINATE\"");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'fragIdJob'});
    }
    return @res;
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
    
    my $sth = $dbh->prepare("UPDATE jobs SET startTime = \"$runningDate\"
                             WHERE idJob =\"$idJob\"");
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
    my $sth = $dbh->prepare("UPDATE jobs SET stopTime = \"$finishDate\"
                             WHERE idJob =\"$idJob\"");
    $sth->execute();
    $sth->finish();
}


# Set the number of nodes for the specified job
# params: base, job, number of nodes
sub set_job_number_of_nodes($$$){
    my $dbh = shift;
    my $job = shift;
    my $nbNodes = shift;

    $dbh->do("UPDATE jobs SET nbNodes = $nbNodes WHERE idJob = $job");
}

# treate job properties and add a "p." before each field
# return formed job properties
sub form_job_properties($$){
    my $dbh = shift;
    my $jobproperties = shift;
    
    # add a \" instead of '
    #$jobproperties =~ s/'/\\"/g;
    #add a p. before each field names
    if ($jobproperties ne ""){
        $sth = $dbh->prepare("SHOW FIELDS FROM nodeProperties");
        $sth->execute();
        my $fields = "";
        while (my @ref = $sth->fetchrow_array()) {
            $fields .= "$ref[0]|";
        }
        chop($fields);
        $sth->finish();

        my @strSep = split("'",$jobproperties." '");
        $jobproperties = "";
        for (my $i=0; $i <= $#strSep; $i++){
            if (int($i % 2) == 0){
                $strSep[$i] =~ s/($fields)/p.$1/g ;
            }
            $jobproperties .= "$strSep[$i]\\\"";
        }
        chop($jobproperties);
        chop($jobproperties);
    }

    return($jobproperties);
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
sub add_micheline_job($$$$$$$$$$$) {
    my ($dbh, $jobType, $nbNodes , $weight, $command, $infoType, $maxTime, $queueName, $jobproperties, $startTimeReservation, $idFile) = @_;

    my $startTimeJob = "0000-00-00 00:00:00";
    my $reservationField = "None";
    my $setCommandReservation = 0;
    #Test if this job is a reservation
    if ($startTimeReservation =~ m/^\s*(\d{4}\-\d{1,2}\-\d{1,2})\s+(\d{1,2}:\d{1,2}:\d{1,2})\s*$/m){
        $reservationField = "toSchedule";
        $startTimeJob = "$1 $2";
        $setCommandReservation = 1;
        #$command = "/bin/sleep ".sql_to_duration($maxTime);
        $jobType = "PASSIVE";
    }elsif($startTimeReservation ne "0"){
        print("Syntax error near -r or --reservation option. Reservation date exemple : \"2004-03-25 17:32:12\"\n");
        return(-3);
    }

    my $rules;
    #my $user= getpwuid($<);
    my $user= getpwuid($ENV{SUDO_UID});

    # Verify the content of user command
    if ( "$command" !~ m/^[\w\s\/\.\-]*$/m ){
        print("ERROR : The command to launch contains bad characters\n");
        return(-4);
    }
    
    #Retrieve Micheline's rules from the table
    #my $sth = $dbh->prepare("SELECT rule FROM admissionRules ORDER BY priority ASC");
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
        $command = "/bin/sleep ".sql_to_duration($maxTime);
    }

    $jobproperties = form_job_properties($dbh, $jobproperties);

    # Test if properties are coherent
    if ($jobproperties ne ""){
        my $nbResults = 0;
        eval{
            my $strTmp = $jobproperties;
            $strTmp =~ s/\\//g ;
            $nbResults = $dbh->do("SELECT * FROM nodeProperties p, nodes n
                                   WHERE n.hostname = p.hostname
                                         AND n.maxWeight >= $weight
                                         AND ($strTmp)");
        };
        if ($@) {
            print("Property matching ERROR, change your -p option value\n");
            return(-1);
        }elsif ($nbResults < $nbNodes){
            printf("Not enough nodes with specified properties and weight (you want $nbNodes with a weight of $weight and only %d match) :-(\n",$nbResults);
            return(-2);
        }
    }

    #Insert job
    $dbh->do("LOCK TABLE jobs WRITE");
    $sth = $dbh->prepare("SELECT MAX(idJob)+1 FROM jobs");
    $sth->execute();
    $ref = $sth->fetchrow_hashref();
    my @tmp = values %$ref;
    my $id = $tmp[0];
    $sth->finish();
    if($id eq "") {
        $id = 1;
    }

    $dbh->do("INSERT INTO jobs
              (idJob,jobType,infoType,state,user,nbNodes,weight,command,submissionTime,maxTime,queueName,properties,launchingDirectory, reservation, startTime, idFile) VALUES
              ($id,\"$jobType\",\"$infoType\",\"Waiting\",\"$user\",$nbNodes,$weight,\"$command\",NOW(),\"$maxTime\",\"$queueName\",\"$jobproperties\",\"$ENV{PWD}\",\"$reservationField\",\"$startTimeJob\",$idFile)");

    $dbh->do("UNLOCK TABLES");

    return $id;
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
    $ref = $sth->fetchrow_hashref();
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
    $ref = $sth->fetchrow_hashref();
    my @tmp = values %$ref;
    my $id = $tmp[0];
    $sth->finish();

    if (! defined $id){
        return -1;
    }
    return $id;
}



# get_job_list
# generic function, could replace all the special cases.
# returns a flat list of all jobs matching criterion given as parameters.
# criterion is given as a flatened list of couples (name, value) and is
# interpreted as the conjonction of all the relations 'name=value'
# some minor analysis is made on values to differentiate numerical values from
# alphabetical ones.
# parameters : base, criteria list
# return value : flatened list of job tuples (as found in the base)
# side effects : /
sub get_job_list(@) {
    my $dbh = shift;
    my @criteria_list=@_;
    my $request="SELECT * FROM jobs";

    if (scalar @criteria_list){
        my $criterion=shift @criteria_list;
        my $value=shift @criteria_list;
        if ($value =~ /^[0-9]*\.?[0-9]*$/){
            $request=$request." WHERE $criterion=$value";
        }
        else{
            $request=$request." WHERE $criterion=\"$value\"";
        }
    }
    while (scalar @criteria_list){
        my $criterion=shift @criteria_list;
        my $value=shift @criteria_list;
        if ($value =~ /^[0-9]*\.?[0-9]*$/){
            $request=$request." AND $criterion=$value ";
        }else{
            $request=$request." AND $criterion=\"$value\" ";
        }
    }
    $request=$request." ORDER BY idJob ASC";
    my $sth = $dbh->prepare($request);
    $sth->execute();

    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, %$ref);
    }
    $sth->finish();
    return @res;
}



# shift_job
# extract one job from the flatened list passed in parameter.
# typically of use to extract jobs from the list returned by get_job_list
# actually works by reconstituting a hash from the couples of the list,
# stopping when finding a value already defined.
# remove the taken job from the passed list (as does shift).
# parameters : jobs list
# return value : job (as a flatened hash)
# side effects : /
sub shift_job(\@){
    local(*params)=@_;
    my %job=();

    if (scalar @params){
        my $elt=shift @params;

        while (scalar @params && !defined($job{$elt})){
            my $value=shift @params;
            $job{$elt}=$value;
            $elt=shift @params;
        }if (scalar @params){
            unshift @params,$elt;
        }
    }
    return %job;
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

    my $sth = $dbh->prepare("SELECT * FROM jobs WHERE idJob = $idJob");
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
    my $sth = $dbh->prepare("UPDATE jobs SET state = \"$state\"
                             WHERE idJob =\"$idJob\"");
    $sth->execute();
    $sth->finish();
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
    $dbh->do("UPDATE jobs
                SET message = \"$message\"
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
        $dbh->do("LOCK TABLE fragJobs WRITE");
        my $nbRes = $dbh->do("SELECT *
                             FROM fragJobs
                             WHERE fragIdJob = $idJob
                            ");

        if ( $nbRes < 1 ){
            #my $time = get_date();
            $dbh->do("INSERT INTO fragJobs (fragIdJob,fragDate)
            VALUES ($idJob,NOW())
            ");
        }
        $dbh->do("UNLOCK TABLES");
        return 0;
    }else{
        return -1;
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

    if ((defined($job)) && ((($lusr eq $job->{'user'}) || ($lusr eq "oar")) && ($job->{'state'} eq "Waiting"))) {
        my $sth = $dbh->prepare("UPDATE jobs SET state = \"Hold\"
                                 WHERE idJob =\"$idJob\"");
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

    if ((defined($job)) && ((($lusr eq $job->{'user'}) || ($lusr eq "oar"))  && ($job->{'state'} eq "Hold"))) {
        my $sth = $dbh->prepare("UPDATE jobs SET state = \"Waiting\"
                                 WHERE idJob =\"$idJob\"");
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

    $dbh->do("UPDATE fragJobs SET fragState = \"TIMER_ARMED\"
              WHERE fragIdJob = $idJob
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

    my $sth = $dbh->prepare("SELECT * FROM jobs j
                             WHERE j.state=\"Waiting\"
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

    my $sth = $dbh->prepare("SELECT * FROM jobs j
                             WHERE j.state=\"Waiting\"
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

    my $sth = $dbh->prepare("SELECT count(*) FROM jobs j
                             WHERE j.state=\"Waiting\"
                                AND j.queueName = \"$queue\"
                             LIMIT 1
                            ");
    $sth->execute();
    my ($res) = $sth->fetchrow_array();
    $sth->finish();
    return ($res > 0);
}



# Get all waiting toSchedule reservation jobs in the specified queue
# parameter : database ref, queuename
# return an array of job informations
sub get_waiting_toSchedule_reservation_jobs_specific_queue($$){
    my $dbh = shift;
    my $queue = shift;

    my $sth = $dbh->prepare("SELECT * FROM jobs j
                             WHERE j.state=\"Waiting\"
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

# delete_job_process
# destroys all the entries of a given job from the processJobs table
# parameters : base, jobid
# return value : /
# side effects : deletes from the ProcessJobs table all the selected entries
sub delete_job_process($$){
    my $dbh = shift;
    my $jobid= shift;

    #$dbh->do("INSERT INTO processJobs_log (idJob,hostname)
    #          SELECT idJob,hostname
    #          FROM processJobs
    #          WHERE idJob = '".$jobid."'");

    $dbh->do("DELETE  FROM processJobs WHERE idJob = '".$jobid."'");
#    $dbh->do("OPTIMIZE TABLE processJobs");
}



# delete_job_process_log
# destroys all the entries of a given job from the processJobs_log table
# parameters : base, jobid
# return value : /
# side effects : deletes from the ProcessJobs_log table all the selected entries
sub delete_job_process_log($$){
    my $dbh = shift;
    my $jobid= shift;

    $dbh->do("DELETE  FROM processJobs_log WHERE idJob = '".$jobid."'");
#    $dbh->do("OPTIMIZE TABLE processJobs_log");
}



# get_host_job_distinct
# returns the list of jobs associated to the hosts passed in parameter
# parameters : base, hostname
# return value : list of jobid
# side effects : /
sub get_host_job_distinct($$) {
    my $dbh = shift;
    my $hostname= shift;
    my $sth = $dbh->prepare("SELECT distinct idJob FROM processJobs
                             WHERE hostname = '".$hostname."'");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'idJob'});
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



# add_node_job_pair
# adds a new pair (jobid, hostname) to the table processjobs.
# This should match the execution of some process for the job of given id
# and on the given host.
# parameters : base, jobid, hostname
# return value : /
# side effects : adds a new entry to the table processjobs.
sub add_node_job_pair($$$) {
    my $dbh = shift;
    my $idJob = shift;
    my $hostname = shift;
    $dbh->do("INSERT INTO processJobs (idJob,hostname)
              VALUES ($idJob,\"$hostname\")");

    $dbh->do("INSERT INTO processJobs_log (idJob,hostname)
              VALUES ($idJob,\"$hostname\")");
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

# add_node
# adds a new node in the table nodes
# parameters : base, name, maxweight
# return value : /
# side effects : adds a new nodes entry to the table nodes
sub add_node($$$$$) {
    my $dbh = shift;
    my $name = shift;
    my $state = shift;
    my $maxweight = shift;
    my $desktopComputing = shift;

    $dbh->do("INSERT INTO nodes (hostname,state,maxWeight,weight)
              VALUES (\"$name\",\"$state\",$maxweight,0)");
    if ($desktopComputing) {
      $dbh->do("INSERT INTO nodeProperties (hostname,desktopComputing)
                VALUES (\"$name\",\"YES\")");
		} else {
      $dbh->do("INSERT INTO nodeProperties (hostname)
                VALUES (\"$name\")");
    }
    
    $dbh->do("INSERT INTO nodeState_log (hostname,changeState,dateStart)
              VALUES (\"$name\",\"$state\",NOW())");

}



# get_maxweight_node
# gets the max of the field maxWeight of the entries of the table nodes.
# parameters : base
# return value : maxweight
# side effects : /
sub get_maxweight_node($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT MAX(maxWeight) FROM nodes");
    $sth->execute();
    $ref = $sth->fetchrow_hashref();
    my @tmp = values %$ref;
    my $w = $tmp[0];
    $sth->finish();
    return $w;
}


# get_maxweight_one_node
# gets the field maxWeight of the given node
# parameters : base, node
# return value : maxweight
# side effects : /
sub get_maxweight_one_node($$) {
    my $dbh = shift;
    my $node = shift;

    my $sth = $dbh->prepare("SELECT maxWeight FROM nodes
                              WHERE hostname = \"$node\"");
    $sth->execute();
    $ref = $sth->fetchrow_hashref();
    my @tmp = values %$ref;
    my $w = $tmp[0];
    $sth->finish();
    return $w;
}



# get_free_shareable_nodes
# gets the list of nodes on which a new job can be added (either with
# exclusive or shared access). This function does not differentiate exclusive
# and shared accesses.
# parameters : base
# return value : list of hostnames
# side effects : /
sub get_free_shareable_nodes($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT p.hostname FROM nodes p
                             WHERE p.state=\"Alive\"
                             AND p.maxWeight > p.weight");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
    }
    $sth->finish();
    return @res;
}


# Generate the SQL sub request with property matching
# params : base, jobId
# return the string of subrequest
sub get_constraint_string($$){
    my $dbh = shift;
    my $jobId = shift;

    #Match user properties
    my $sth = $dbh->prepare("SELECT properties FROM jobs WHERE idJob = $jobId");
    $sth->execute();
    my $constraints = "";
    $constraints = ($sth->fetchrow_array())[0];
    $sth->finish();

    if ($constraints ne ""){
        $constraints = " AND ( $constraints )";
    }

#    oar_debug("--Constraints = $constraints--\n");
    return($constraints);
}



# get_free_nodes_job
# gets the list of nodes that match properties of the job passed in parameter
# and on which a new job can be added (either with exclusive or shared access).
# This function does not differentiate exclusive and shared accesses.
# parameters : base, jobid weight
# return value : list of hostnames
# side effects : /
sub get_free_nodes_job($$$) {
    my $dbh = shift;
    my $job_id = shift;
    my $job_weight = shift;

    my $constraints = get_constraint_string($dbh,$job_id);

    my $sth = $dbh->prepare("SELECT n.hostname FROM nodes n, nodeProperties p
                             WHERE n.state=\"Alive\"
                             AND n.maxWeight > n.weight AND n.maxWeight - n.weight >= $job_weight
                             AND p.hostname = n.hostname $constraints");
    $sth->execute();
    my @res = ();
    while (my @ref = $sth->fetchrow_array()) {
        push(@res, $ref[0]);
    }
    $sth->finish();
    return @res;
}



# get_free_nodes_job_killer
# If possible, returns a triplet (number of nodes, state value, and ref to a list of
# at least nbmin hostnames) in which the hostnames in the list match properties of the
# job passed in parameter and can be used for the reservation.
# The number of nodes can be greater than nbmin and is the actual number of free hosts.
# The state value state wether some besteffort jobs (that is jobs having their BestEffort
# flag to 'Yes') have been marked as 'ToFrag' (value 1) or not (value 0) in order to reach
# the required number of nodes, in such a case the scheduler has to ensure that these
# jobs have been killed before making use of the hosts.
# If the number of available hosts required is not reachable even by killing besteffort
# jobs, the function returns (0,0,"")
# parameters : base, jobid, nbmin, weight
# return value : (nbnodes, state value, list of hostnames)
# side effects : might mark some besteffort jobs as 'ToFrag' in the base
sub get_free_nodes_job_killer($$$$) {
    my $dbh = shift;
    my $job_id = shift;
    my $nbmin = shift;
    my $jobWeight = shift;

    my $doKill = 0;
    my @liste_noeuds = get_free_nodes_job($dbh, $job_id,$jobWeight);
    my $nbn = $#liste_noeuds+1;
    my %rehash = ();
    if ($nbn > 0){
        %reshash = ("nbnodes"=> $nbn, "retval" => 0,"procs" => \@liste_noeuds);
    }else{
        %reshash = ("nbnodes"=> $nbn, "retval" => 0, "procs" => "");
    }

    # On a trouve assez de noeuds libres
    if( $#liste_noeuds+1 >= $nbmin){
        return %reshash;
    }

    # Chercher les noeuds qui verifient les proprietes et qui sont occupes
    # par des jobs killable

    # recuperer les contraintes exprime par le jobs

    my $constraints = get_constraint_string($dbh,$job_id);

    # Calcul des contraintes pour ne pas avoir les memes noeuds que le contenu de @liste_noeuds
    my $hostConstraints = "";
    foreach my $i (@liste_noeuds){
        $hostConstraints .= " AND n.hostname != \"$i\"";
    }

    # Chercher les noeuds occupes ! (pas les libres) par des jobs "killable"
    # (jobProperties)
    # A CORRIGER: le poid est a 1 (au lieu de maxPoid ?)
    # A CORRIGER: Je ne verifie pas que le job est bien a running
    # (il devrait puisqu'il occupe des noeuds)
    my $sth = $dbh->prepare("SELECT distinct n.hostname, n.weight, n.maxWeight, j.idJob, jb.weight
                          FROM jobs jb, processJobs j, nodes n, nodeProperties p
                          WHERE n.state=\"Alive\"
                                AND j.hostname = n.hostname
                                AND j.hostname = p.hostname
                                AND j.idJob = jb.idJob
                                AND jb.queueName = \"$besteffortQueueName\"
                                AND n.maxWeight >= $jobWeight
                                $hostConstraints
                                $constraints");

    $sth->execute();
    my %res_noeuds ;
    my %potentialNodeWeight ;
    while (my @ref = $sth->fetchrow_array()) {
        if ((defined($potentialNodeWeight{$ref[0]})) && ($potentialNodeWeight{$ref[0]} >= $jobWeight)){
            next;
        }
        push(@{$res_noeuds{$ref[0]}}, $ref[3]);
        if (defined($potentialNodeWeight{$ref[0]})){
            $potentialNodeWeight{$ref[0]} += $ref[4];
        }else{
            $potentialNodeWeight{$ref[0]} = $ref[2] - $ref[1] + $ref[4];
        }
    }
    $sth->finish();

    my @res_empty = ();

    my @goodNodes;
    foreach my $i (keys(%res_noeuds)){
        if ($potentialNodeWeight{$i} >= $jobWeight){
            push(@goodNodes, $i);
        }
    }
    # compter le nombre de noeuds potentiels
    if ( $#goodNodes+1 + $#liste_noeuds+1 < $nbmin){
        %reshash = ("nbnodes"=> 0, "retval"=> 0, "procs"=> "" );
        return %reshash;
    }

    $doKill = 1;
    # sinon tuer les jobs jusqu'a liberer suffisament de noeuds
    # le choix des jobs est fait par
    my @job_a_tuer;
    for(my $i=0; $i < ($nbmin - ($#liste_noeuds+1)); $i++){
        if (defined($res_noeuds{$goodNodes[$i]})){
            foreach my $j (@{$res_noeuds{$goodNodes[$i]}}){
                push(@job_a_tuer, $j );
            }
        }
    }

    # sort
    @tri_job = sort(@job_a_tuer);
    oar_debug("ICI".Dumper(@tri_job));
    foreach my $i (@tri_job){
        # tuer le job correspondant
        frag_job($dbh, $i);
    }

    # on a tue des jobs
    %reshash = ("nbnodes"=> 0, "retval"=> 1, "procs"=> "");
    return %reshash;
}



# get_free_shareable_nodes_job
# gets the list of nodes that match properties of the job passed in parameter
# and on which a new job can be added (either with exclusive or shared access).
# This function does not differentiate exclusive and shared accesses.
# parameters : base, jobid weight
# return value : list of hostnames
# side effects : /
sub get_free_shareable_nodes_job($$$) {
    my $dbh = shift;
    my $job_id = shift;
    my $job_weight = shift;

    my $constraints = get_constraint_string($dbh,$job_id);

    my $sth = $dbh->prepare("SELECT n.hostname FROM nodes n, nodeProperties p
                          WHERE n.state=\"Alive\"
                          AND n.hostname = p.hostname
                          AND n.maxWeight > n.weight AND n.maxWeight - n.weight >= $job_weight $constraints");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
    }
    $sth->finish();
    return @res;
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



# get_free_exclusive_nodes_job
# gets the list of nodes that match properties of the job passed in parameter
# and on which a new job can be added with exclusive access.
# parameters : base
# return value : list of hostnames
# side effects : /
sub get_free_exclusive_nodes_job($$$) {
    my $dbh = shift;
    my $job_id = shift;
    my $jobWeight = shift;

    my $constraints = get_constraint_string($dbh,$job_id);

    my $sth = $dbh->prepare("SELECT n.hostname FROM nodes n, nodeProperties p
                             WHERE n.state=\"Alive\"
                             AND n.hostname = p.hostname
                             AND n.weight = 0 AND n.maxWeight >= $jobWeight $constraints");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
    }
    $sth->finish();
    return @res;
}



# get_free_exclusive_nodes_job_nbmin
# If possible, returns a triplet (number of nodes, state value, and ref to a list of
# at least nbmin hostnames) in which the hostnames in the list match properties of the
# job passed in parameter and can be used for an exclusive access.
# The number of nodes can be greater than nbmin and is the actual number of free hosts.
# The state value state wether some besteffort jobs (that is jobs having their BestEffort
# flag to 'Yes') have been marked as 'ToFrag' (value 1) or not (value 0) in order to reach
# the required number of nodes, in such a case the scheduler has to ensure that these
# jobs have been killed before making use of the hosts.
# If the number of available hosts required is not reachable even by killing besteffort
# jobs, the function returns (0,0,"")
# parameters : base, jobid, nbmin
# return value : (nbnodes, state value, list of hostnames)
# side effects : might mark some besteffort jobs as 'ToFrag' in the base
sub get_free_exclusive_nodes_job_nbmin($$$$) {
    my $dbh = shift;
    my $job_id = shift;
    my $nbmin = shift;
    my $jobWeight = shift;

    my $doKill = 0;
    my @liste_noeuds = get_free_exclusive_nodes_job($dbh, $job_id,$jobWeight);
    my $nbn = $#liste_noeuds+1;
    my %rehash = ();
    if ($nbn > 0){
        %reshash = ("nbnodes"=> $nbn, "retval" => 0,"procs" => \@liste_noeuds);
    }else{
        %reshash = ("nbnodes"=> $nbn, "retval" => 0, "procs" => "");
    }

    # On a trouve assez de noeuds libres
    if( $#liste_noeuds+1 >= $nbmin){
        return %reshash;
    }

    # Chercher les noeuds qui verifie les proprietes et qui sont occupes
    # par des jobs killable

    # recuperer les contraintes exprime par le jobs

    my $constraints = get_constraint_string($dbh,$job_id);

    # Chercher les noeuds occupes ! (pas les libres) par des jobs "killable"
    # (jobProperties)
    # A CORRIGER: le poid est a 1 (au lieu de maxPoid ?)
    # A CORRIGER: Je ne verifie pas que le job est bien a running
    # (il devrait puisqu'il occupe des noeuds)
    my $sth = $dbh->prepare("SELECT distinct n.hostname, j.idJob FROM processJobs j, nodes n, nodeProperties p, jobs jb
                             WHERE n.state=\"Alive\"
                             AND j.hostname = n.hostname
                             AND n.hostname = p.hostname
                             AND jb.idJob = j.idJob
                             AND jb.queueName = \"$besteffortQueueName\"
                             AND n.weight > 0 $constraints");

    #Pour la prise en compte des poids des bestefforts
    #SELECT distinct n.hostname, j.idJob, jb.weight FROM jobs jb, processJobs j, jobProperties p, nodes n WHERE jb.idJob = p.idJob AND #n.state="Alive" AND j.hostname = n.hostname AND j.idJob = p.idJob AND p.property = "Killable"  AND n.weight > 0 AND n.maxWeight >= 2;

    $sth->execute();
    my @res_noeuds = ();
    my @res_job = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res_noeuds, $ref->{'hostname'});
        push(@res_job, $ref->{'idJob'});
    }
    oar_debug("NOEUDS:".Dumper(@res_noeuds));
    oar_debug("JOBS".Dumper(@res_job));
    $sth->finish();

    my @res_empty = ();

    # compter le nombre de noeuds
    if ( $#res_noeuds+1 + $#liste_noeuds+1 < $nbmin){
        %reshash = ("nbnodes"=> 0, "retval"=> 0, "procs"=> "" );
        return %reshash;
    }

    $doKill = 1;
    my $i;
    # sinon tuer les jobs jusqu'a liberer suffisament de noeuds
    # le choix des jobs est fait par
    for( $i=0; $i < ($nbmin - ($#liste_noeuds+1)); $i++){
        if (defined($res_job[$i])){
            push(@job_a_tuer, $res_job[$i] );
        }
    }

    # sort
    @tri_job = sort(@job_a_tuer);
    oar_debug("ICI".Dumper(@tri_job));
    # uniq
    my $prevjob="";
    for( $i=0; $i < ($nbmin - ($#liste_noeuds+1)); $i++){
        if ($prevjob ne $tri_job[$i]){
            # tuer le job correspondant
            frag_job($dbh, $tri_job[$i]);
            # ne pas le faire 2 fois
            $prevjob = $tri_job[$i];
        }
    }

    # on a tue des jobs
    %reshash = ("nbnodes"=> 0, "retval"=> 1, "procs"=> "");
    return %reshash;
}



# get_alive_node_job
# gets the list of alive nodes that match properties of the job
# passed in parameter.
# parameters : base, jobid, weight
# return value : list of hostnames
# side effects : /
sub get_alive_node_job($$$) {
    my $dbh = shift;
    my $job_id = shift;
    my $weight = shift;

    my $constraints = get_constraint_string($dbh,$job_id);

    $sth = $dbh->prepare("SELECT n.hostname FROM nodes n, nodeProperties p
                          WHERE n.hostname = p.hostname
                          AND n.maxWeight >= $weight
                          AND ( n.state = \"Alive\" or
                          n.state = \"Suspected\" or
                          n.state = \"Absent\" )
                          $constraints");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
    }
    $sth->finish();
    return @res;
}



# get_really_alive_node_job
# gets the list of really alive nodes that match properties of the job
# passed in parameter.
# parameters : base, jobid, weight
# return value : list of hostnames
# side effects : /
sub get_really_alive_node_job($$$) {
    my $dbh = shift;
    my $job_id = shift;
    my $weight = shift;

    my $constraints = get_constraint_string($dbh,$job_id);

    $sth = $dbh->prepare("SELECT n.hostname FROM nodes n, nodeProperties p
                          WHERE n.hostname = p.hostname
                          AND n.maxWeight >= $weight
                          AND  n.state = \"Alive\"
                               $constraints");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
    }
    $sth->finish();
    return @res;
}



# get_alive_node
# gets the list of alive nodes.
# parameters : base
# return value : list of hostnames
# side effects : /
sub get_alive_node($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT n.hostname FROM nodes n
                             WHERE ( n.state = \"Alive\" or
                             n.state = \"Suspected\" or
                             n.state = \"Absent\" )  ");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
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
    return @res;
}



# list_nodes
# gets the list of all nodes.
# parameters : base
# return value : list of hostnames
# side effects : /
sub list_nodes($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT * FROM nodes ORDER BY hostname ASC");
    $sth->execute();
    my @res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'hostname'});
    }
    $sth->finish();
    return @res;
}



# get_node_info
# returns a ref to some hash containing data for the nodes of hostname passed in parameter
# parameters : base, hostname
# return value : ref
# side effects : /
sub get_node_info($$) {
    my $dbh = shift;
    my $hostname = shift;

    my $sth = $dbh->prepare("SELECT * FROM nodes WHERE hostname=\"$hostname\"");
    $sth->execute();

    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    return $ref;
}

# get_weight_node
# returns the current weight of node whose hostname is passed in parameter
# parameters : base, hostname
# return value : weight
# side effects : /
sub get_weight_node($$) {
    my $dbh = shift;
    my $hostname = shift;

    my $sth = $dbh->prepare("SELECT weight FROM nodes
                             WHERE hostname=\"$hostname\"");
    $sth->execute();

    my $ref = $sth->fetchrow_hashref();
    my @tmp = values %$ref;
    my $w = $tmp[0];
    $sth->finish();

    return $w;
}



# set_weight_node
# sets the current weight of node whose hostname is passed in parameter
# parameters : base, hostname, weight
# return value : /
# side effects : changes the weight value in some field of the nodes table
sub set_weight_node($$$) {
    my $dbh = shift;
    my $hostname = shift;
    my $weight = shift;

    my $sth = $dbh->prepare("UPDATE nodes SET weight = \"$weight\"
                             WHERE hostname =\"$hostname\"");
    $sth->execute();
    $sth->finish();
}



# decrease_weight
# decrease the current weight of all nodes on which some job is executed.
# The value withdrawn from the weight of nodes is the weight of the job.
# parameters : base, jobid
# return value : /
# side effects : changes the weight value in several fields of the nodes table
sub decrease_weight($$) {
    my $dbh = shift;
    my $idjob = shift;
    my @hosts = get_job_host_distinct($dbh,$idjob);

    my $job = get_job($dbh,$idjob);
    my $w = $job->{'weight'};

    foreach my $host (@hosts) {
        my $current_w = get_weight_node($dbh,$host) - $w;
        #print "Decrease weight node : $nodes new weight : $current_w (w $w) \n";
        set_weight_node($dbh,$host,$current_w);
    }
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

    $dbh->do("UPDATE nodes SET state = \"$state\", finaudDecision = \"$finaud\"
              WHERE hostname =\"$hostname\"");

    my $date = get_date($dbh);
    $dbh->do("UPDATE nodeState_log SET dateStop = \"$date\" WHERE dateStop IS NULL AND hostname = \"$hostname\"");
    $dbh->do("INSERT INTO nodeState_log (hostname,changeState,dateStart,finaudDecision)
              VALUES (\"$hostname\",\"$state\",\"$date\",\"$finaud\")");
}

# set_node_nextState
# sets the nextState field of some node identified by its hostname in the base.
# parameters : base, hostname, nextState
# return value : /
# side effects : changes the nextState value in some field of the nodes table
sub set_node_nextState($$$) {
    my $dbh = shift;
    my $hostname = shift;
    my $nextState = shift;

    $dbh->do("UPDATE nodes SET nextState = \"$nextState\", nextFinaudDecision = \"NO\"
              WHERE hostname =\"$hostname\"");
}


# update_node_nextFinaudDecision
# update nextFinaudDecision field
# parameters : base, hostname, "YES" or "NO"
# return value : /
sub update_node_nextFinaudDecision($$$){
    my $dbh = shift;
    my $hostname = shift;
    my $finaud = shift;

    $dbh->do("UPDATE nodes SET nextFinaudDecision = \"$finaud\"
              WHERE hostname =\"$hostname\"");
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
# change nodeProperties table value for the hostname and the property specified
# parameters : base, hostname, property name, value
# return : 0 if all is good, otherwise 1 if the property does not exist or the value is incorrect
sub set_node_property($$$$){
    my $dbh = shift;
    my $hostname = shift;
    my $property = shift;
    my $value = shift;

    # Test if we must change the property
    my $nbRowsAffected;
    $nbRowsAffected = $dbh->do("SELECT * FROM nodeProperties WHERE hostname = \"$hostname\" AND $property = \"$value\"");
    if ($nbRowsAffected > 0){
        return(2);
    }
    eval{
        $nbRowsAffected = $dbh->do("UPDATE nodeProperties SET $property = \"$value\"
                                    WHERE hostname =\"$hostname\"");
    };
    if ($nbRowsAffected != 1){
        return(1);
    }else{
        #Update LOG table
        my $date = get_date($dbh);
        $dbh->do("UPDATE nodeProperties_log SET dateStop = \"$date\" WHERE dateStop IS NULL AND hostname = \"$hostname\" AND property = \"$property\"");
        $dbh->do("INSERT INTO nodeProperties_log (hostname,property,value,dateStart)
                  VALUES (\"$hostname\",\"$property\",\"$value\",\"$date\")");
        return(0);
    }
}


# return all properties for a specific node
# parameters : base, hostname
sub get_all_node_properties($$){
    my $dbh = shift;
    my $node = shift;
#show fields from nodeProperties

    my $sth = $dbh->prepare("SHOW FIELDS FROM nodeProperties");
    $sth->execute();
    my @fields;
    while (my @ref = $sth->fetchrow_array()) {
        push(@fields,$ref[0]);
    }
    $sth->finish();

    my $properties;
    foreach my $i (@fields){
        $properties .= ",p.$i ";
    }
    $properties =~ s/^,//s;

    $sth = $dbh->prepare("SELECT $properties FROM nodeProperties p WHERE hostname = \"$node\"");
    $sth->execute();

    my %results;
    my @res = $sth->fetchrow_array();
    for (my $i=0; $i <= $#res; $i++){
        if (defined($res[$i])){
            $results{$fields[$i]} = $res[$i];
        }
    }

    $sth->finish();

    return %results;
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
        push(@res, $ref);
        $res{$ref->{hostname}} = $ref;
    }
    $sth->finish();

    return(%res);
}


# get node names that will change their state
# parameters : base
sub get_node_change_state($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT hostname,nextState FROM nodes WHERE nextState != \"UnChanged\"");
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

# get_highestpriority_nonempty_queue
# get one of the non empty queues of highest priority (unique if all the
# priorities are different !).
# (eg. by looking within the waiting jobs the one affected to the highest
# priority queue).
# parameters : base
# return value : queuename, schedulerpolicy
# side effects : /
sub get_highestpriority_nonempty_queue($){
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT MAX(q.priority)
                             FROM jobs j, queue q
                             WHERE j.state = \"Waiting\"
                             AND j.queueName = q.queueName
                             AND q.state = \"Active\" ");
    $sth->execute();

    my @res = $sth->fetchrow_array();
    $sth->finish();
    my $maximum = shift @res;

    if (defined($maximum)){
        $sth = $dbh->prepare("SELECT q.queueName, q.schedulerPolicy
                              FROM jobs j, queue q
                              WHERE j.state = \"Waiting\"
                              AND j.queueName = q.queueName
                              AND q.priority = $maximum
                              AND q.state = \"Active\"");
        $sth->execute();
        my $ref = $sth->fetchrow_hashref();
        $sth->finish();

        return ($ref->{'queueName'}, $ref->{'schedulerPolicy'});
    }else{
        return ();
    }
}

# get_queues
# create the list of queues sorted by descending priority
# only return the Active queues.
# return value : list of queues
# side effects : /
sub get_queues($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT queueName,schedulerPolicy
                             FROM queue
                             WHERE state = \"Active\"
                             ORDER BY priority DESC");
    $sth->execute();
    my $res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, [ $ref->{'queueName'}, $ref->{'schedulerPolicy'} ]);
    }
    $sth->finish();
    return @res;
}



# GANTT MANAGEMENT

#get previous scheduler decisions
#args : base
#return a hashtable : idJob --> [startTime,weight,walltime,queueName,\@nodes]
sub get_gantt_scheduled_jobs($){
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT g2.idJob, g2.startTime, j.weight, j.maxTime, g1.hostname, j.queueName, j.state
                             FROM ganttJobsNodes g1, ganttJobsPrediction g2, jobs j
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
#args : base,idJob,startTime,\@nodes
#return nothing
sub add_gantt_scheduled_jobs($$$$){
    my $dbh = shift;
    my $idJob = shift;
    my $startTime = shift;
    my $nodeList = shift;

    $dbh->do("INSERT INTO ganttJobsPrediction
              (idJob,startTime)
              VALUES
              ($idJob,\"$startTime\")
             ");

    foreach my $i (@{$nodeList}){
        $dbh->do("INSERT INTO ganttJobsNodes
                  (idJob,hostname)
                  VALUES
                  ($idJob,\"$i\")
                 ");
    }
}


# Remove an entry in the gantt
# params: base, idJob, node
sub remove_gantt_node_job($$$){
    my $dbh = shift;
    my $job = shift;
    my $node = shift;

    $dbh->do("DELETE FROM ganttJobsNodes WHERE idJob = $job AND hostname = \"$node\"");
}



# Add gantt date (now) in database
# args : base, date
sub set_gantt_date($$){
    my $dbh = shift;
    my $date = shift;

    $dbh->do("INSERT INTO ganttJobsPrediction
              (idJob,startTime)
              VALUES
              (0,\"$date\")
             ");
}


# Update startTime in gantt for a specified job
# args : base, job id, date
sub set_gantt_job_startTime($$$){
    my $dbh = shift;
    my $job = shift;
    my $date = shift;

    $dbh->do("UPDATE ganttJobsPrediction
              SET startTime = \"$date\"
              WHERE idJob = $job
             ");
}



# Update ganttJobsPrediction_visu and ganttJobsNodes_visu with values in ganttJobsPrediction and in ganttJobsNodes
# arg: database ref
sub update_gantt_visualization($){
    my $dbh = shift;

    $dbh->do("LOCK TABLE ganttJobsPrediction_visu WRITE, ganttJobsNodes_visu WRITE, ganttJobsPrediction WRITE, ganttJobsNodes WRITE");

    $dbh->do("DELETE FROM ganttJobsPrediction_visu");
    $dbh->do("DELETE FROM ganttJobsNodes_visu");
#    $dbh->do("OPTIMIZE TABLE ganttJobsNodes_visu, ganttJobsPrediction_visu");

    $dbh->do("INSERT INTO ganttJobsPrediction_visu
                SELECT *
                FROM ganttJobsPrediction
             ");
    
    $dbh->do("INSERT INTO ganttJobsNodes_visu
                SELECT *
                FROM ganttJobsNodes
             ");

    $dbh->do("UNLOCK TABLES");
}



# Return date of the gantt
sub get_gantt_date($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT startTime
                             FROM ganttJobsPrediction
                             WHERE idJob = 0
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
                             FROM ganttJobsPrediction_visu
                             WHERE idJob = 0
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
    $dbh->do("DELETE FROM ganttJobsPrediction");
    #$dbh->do("TRUNCATE TABLE ganttJobsNodes");
    $dbh->do("DELETE FROM ganttJobsNodes");
    
#    $dbh->do("OPTIMIZE TABLE ganttJobsNodes, ganttJobsPrediction");
}



#Get jobs to launch at a given date
#args : base, date in sql format
sub get_gantt_jobs_to_launch($$){
    my $dbh = shift;
    my $date = shift;

    my $sth = $dbh->prepare("SELECT g2.idJob, j.weight, g1.hostname
                             FROM ganttJobsNodes g1, ganttJobsPrediction g2, jobs j
                             WHERE g1.idJob = g2.idJob
                                AND j.idJob = g1.idJob
                                AND g2.startTime <= \"$date\"
                                AND j.state = \"Waiting\"
                            ");
    $sth->execute();
    my %res ;
    while (my @ref = $sth->fetchrow_array()) {
        if (!defined($res{$ref[0]})){
            $res{$ref[0]}->[0] = $ref[1];
        }
        push(@{$res{$ref[0]}->[1]}, $ref[2]);
    }
    $sth->finish();

    return %res;
}



#Get informations about nodes for jobs to launch at a given date
#args : base, date in sql format
sub get_gantt_nodes_for_jobs_to_launch($$){
    my $dbh = shift;
    my $date = shift;

    my $sth = $dbh->prepare("SELECT g1.hostname, SUM(j.weight)
                             FROM ganttJobsNodes g1, ganttJobsPrediction g2, jobs j
                             WHERE g1.idJob = g2.idJob
                                AND j.idJob = g1.idJob
                                AND g2.startTime <= \"$date\"
                                AND j.state = \"Waiting\"
                                AND j.queueName != \"besteffort\"
                             GROUP BY g1.hostname
                            ");
    $sth->execute();
    my %res ;
    while (my @ref = $sth->fetchrow_array()) {
        $res{$ref[0]} = $ref[1]; 
    }
    $sth->finish();

    return %res;
}


#Get nodes for job in the gantt diagram
#args : base, job id
sub get_gantt_nodes_for_job($$){
    my $dbh = shift;
    my $job = shift;

    my $sth = $dbh->prepare("SELECT g.hostname
                             FROM ganttJobsNodes g
                             WHERE g.idJob = $job 
                            ");
    $sth->execute();
    my @res ;
    while (my @ref = $sth->fetchrow_array()) {
        push( @res, $ref[0]); 
    }
    $sth->finish();

    return @res;
}


#Get Alive nodes for a job
#args : base, job id
sub get_gantt_Alive_nodes_for_job($$){
    my $dbh = shift;
    my $job = shift;

    my $sth = $dbh->prepare("SELECT g.hostname
                             FROM ganttJobsNodes g, nodes n
                             WHERE g.idJob = $job 
                                AND n.hostname = g.hostname
                                AND n.state = \"Alive\"
                            ");
    $sth->execute();
    my @res ;
    while (my @ref = $sth->fetchrow_array()) {
        push( @res, $ref[0]); 
    }
    $sth->finish();

    return @res;
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
    return ymdhms_to_local($year,$mon,$mday,$hour,$min,$sec);
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

# MESSAGES, INTERNAL STATE AND DEBUGGING

# show_table
# prints (using dumper) the table whose name is passed in parameter
# parameters : base, table
# return value : /
# side effects : prints the required table
sub show_table($$) {
    my $dbh = shift;
    my $table = shift;

    # Now retrieve data from the table.
    my $sth = $dbh->prepare("SELECT * FROM $table");
    $sth->execute();

    while (my $ref = $sth->fetchrow_hashref()) {
        dumper($ref);
    }
    $sth->finish();
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
    $dbh->do("INSERT INTO event_log (type,idJob,date,description) VALUES (\"$type\",$idJob,\"$date\",\"$description\")");
    my $sth = $dbh->prepare("SELECT LAST_INSERT_ID()");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    ($idFile) = values(%$ref);
    $sth->finish();
}

#add a new entry in event_log_hosts table
#args : database ref, type, job id, description, ref of an array of host names
sub add_new_event_with_host($$$$$){
    my $dbh = shift;
    my $type = shift;
    my $idJob = shift;
    my $description = shift;
    my $hostnames = shift;
    
    my $date = get_date($dbh);
    $dbh->do("LOCK TABLE event_log WRITE, event_log_hosts WRITE");
    $dbh->do("INSERT INTO event_log (type,idJob,date,description) VALUES (\"$type\",$idJob,\"$date\",\"$description\")");
    my $sth = $dbh->prepare("SELECT LAST_INSERT_ID()");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    ($idEvent) = values(%$ref);
    $sth->finish();
    
    foreach my $n (@{$hostnames}){
        $dbh->do("INSERT INTO event_log_hosts (idEvent,hostname) VALUES ($idEvent,\"$n\")");
    }
    $dbh->do("UNLOCK TABLES");
}



# Turn the field toCheck into NO
#args : database ref, event type, idJob
sub check_event($$$){
    my $dbh = shift;
    my $type = shift;
    my $idJob = shift;

    $dbh->do("UPDATE event_log SET toCheck = \"NO\" WHERE toCheck = \"YES\" AND type = \"$type\" AND idJob = $idJob");
}


# Get all events with toCheck field on YES
# args: database ref
sub get_to_check_events($){
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT type, idJob, idEvent FROM event_log WHERE toCheck = \"YES\"");
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

    my $sth = $dbh->prepare("SELECT hostname FROM event_log_hosts WHERE idEvent = $eventId");
    $sth->execute();

    my @results;
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@results, $ref->{hostname});
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
