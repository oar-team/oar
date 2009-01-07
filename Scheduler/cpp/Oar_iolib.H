#ifndef OAR_IOLIB_H
#define OAR_IOLIB_H

#include <string>
#include "Oar_resource_tree.H"

using namespace std;

/*
  Type utilisé pour l'extraction de des données (pas de hashref par query)
  Version prise de la doc OAR le 8 octobre 2008 (OAR >= 2.3.0)

 */

struct resources_iolib {
  unsigned int resource_id; // INT UNSIGNED 	resource identifier
  string type; // VARCHAR(100) DEFAULT "default" resource type (used
	       // for licence resources for example)
  string network_address; // VARCHAR(100) node name (used to connect
			  // via SSH)
  string state; // ENUM('Alive', 'Dead' , 'Suspected', 'Absent')
		// resource state
  string next_state;// 	ENUM('UnChanged', 'Alive', 'Dead', 'Absent',
		    // 	'Suspected') DEFAULT 'UnChanged' state for the
		    // 	resource to switch
  bool finaud_decision; // 	ENUM('YES', 'NO') DEFAULT 'NO' tell if
			  // 	the actual state results in a "finaud"
			  // 	module decision
  bool next_finaud_decision; // ENUM('YES', 'NO') DEFAULT 'NO' tell
			       // if the next node state results in a
			       // "finaud" module decision
  int state_num; // INT corresponding state number (useful with the
		 // SQL "ORDER" query)
  bool suspended_jobs; // 	ENUM('YES','NO') specify if there is
		       // 	at least one suspended job on the
		       // 	resource
  unsigned int scheduler_priority;// 	INT UNSIGNED arbitrary number
				  // 	given by the system to select
				  // 	resources with more
				  // 	intelligence
  string switch_name; // 	VARCHAR(50) 	name of the switch
  unsigned int cpu; // 	INT UNSIGNED 	global cluster cpu number
  unsigned int cpuset; // 	INT UNSIGNED field used with the
		       // 	JOB_RESOURCE_MANAGER_PROPERTY_DB_FIELD
  bool besteffort; // 	ENUM('YES','NO') 	accept or not besteffort jobs
  bool deploy; // ENUM('YES','NO') 	specify if the resource is deployable
  unsigned int expiry_date; // INT UNSIGNED field used for the desktop
			    // computing feature
  bool desktop_computing; // ENUM('YES','NO') tell if it is a desktop
			  // computing resource (with an agent)
  unsigned int last_job_date; // INT UNSIGNED store the date when the
			      // resource was used for the last time
  unsigned int cm_availability; //INT UNSIGNED used with compute mode
				//features to know if an Absent
				//resource can be switch on

};


struct gantt_sched_jobs {
  unsigned int job_id;
  unsigned int start_time;
  unsigned int moldable_walltime;
  vector<unsigned int> resource_id_vec;
  string queue_name;
  string state;
  string job_user;
  string job_name;
  unsigned int moldable_id;
  bool suspended;
};


/**
   Extraction de la table jobs (select * dans perl, limite ici)
   usage de
   - get_fairsharing_jobs_to_schedule limite a
   (job_id, job_user, job_name, properties)
   + appel a karma limite a
   (project, job_user)
*/

struct jobs_iolib_restrict {
  unsigned int job_id; // 	INT UNSIGNED 	job identifier
  string job_name; // 	VARCHAR(100) 	name given by the user
  string job_user; //	VARCHAR(255) 	user name
  string properties; // TEXT 	properties that assigned nodes must match
  string project; //  VARCHAR(255) 	arbitrary name given by the user or an admission rule
};

/**
   Extraction de la table job dans get_job
   limite a 
   - state ENUM('Waiting','Hold', 'toLaunch', 'toError', 'toAckReservation', 'Launching', 'Running' 'Suspended', 'Resuming', , 'Finishing', 'Terminated', 'Error') 	job state
   - job_type ENUM('INTERACTIVE', 'PASSIVE') DEFAULT 'PASSIVE' 	specify if the user wants to launch a program or get an interactive shell
   - exit_code INT DEFAULT 0 	exit code for passive jobs
*/
struct jobs_get_job_iolib_restrict {
  string state;
  string job_type;
  int exit_code;
};


/**
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
*/
struct resources_per_job {
  string resource;
  string value;
};

struct property_resources_per_job {
  string property;
  vector<resources_per_job> resources;
};


struct resources_data_moldable {
  vector<property_resources_per_job> prop_res;
  unsigned int walltime;
  unsigned int moldable_job_id;
};

/**
   # Get start_time for a given job
   # args : base, job id
*/
struct gantt_job_start_time
{
  unsigned int start_time;
  unsigned int moldable_job_id;
};


/**
   listes des fonctions
*/

/**
  # connect_db
  # Connects to database and returns the base identifier
  # return value : base
*/
extern int connect_db(string dbhost, int dbport, string dbname,
		      string dblogin, string dbpasswd, int debug_level=0);

/**
  # connect
  # Connects to database and returns the base identifier
  # parameters : /
  # return value : base
  # side effects : opens a connection to the base specified in ConfLib
*/


extern bool connect();

/** 
   # connect_ro
   # Connects to database and returns the base identifier
   # parameters : /
   # return value : base
   # side effects : opens a connection to the base specified in ConfLib
*/
extern bool connect_ro();

/**
  # disconnect
  # Disconnect from database
  # parameters : base
  # return value : /
  # side effects : closes a previously opened connection to the specified base
*/
extern void disconnect();
/*
  # get_specific_resource_states
  # returns a hashtable with each given resources and their states
  # parameters : base, resource type
*/
extern map< string, string > 
get_specific_resource_states(string type);
/*
  # list_resources
  # gets the list of all resources
  # parameters : base
  # return value : list of resources
  # side effects : /
*/

extern vector <resources_iolib> list_resources();
/*
  # GANTT MANAGEMENT
  
  #get previous scheduler decisions
  #args : base
  #return a hashtable : job_id --> [start_time,walltime,queue_name,\@resources,state]
  # TODO commentaire PERL faux: bien plus d'information et pas de resssource !
*/
extern pair< vector<unsigned int>, map<unsigned int, struct gantt_sched_jobs> >
get_gantt_scheduled_jobs();
/**
  # get_current_job_types
  # return a hash table with all types for the given job ID
*/
extern map<string, string>
get_current_job_types(unsigned int jobId);

/*
  # get_job_current_resources
  # returns the list of resources associated to the job passed in parameter
  # parameters : base, jobid
  # return value : list of resources
  # side effects : /
*/
extern vector<unsigned int>
get_job_current_resources(unsigned int jobid, vector<string> not_type_list);
/**
# get the amount of time in the suspended state of a job
# args : base, job id, time in seconds
*/
extern unsigned int get_job_suspended_sum_duration(unsigned int job_id,
						   unsigned int current_time);
/**
   # get_resources_in_state
   # returns the list of resources in the state specified
   # parameters : base, state
   # return value : list of resource ref

   c'est une quasi-copie de list_resources, j'ai mutualiser le code
*/


extern vector<resources_iolib> get_resources_in_state(string state);
/**
  # get_fairsharing_jobs_to_schedule
  # args : base ref, queue name
*/
extern vector<jobs_iolib_restrict> 
get_fairsharing_jobs_to_schedule(string queue, unsigned int limit);

extern map<string, unsigned int> 
get_sum_accounting_window(string queue,
			  unsigned int start_window,
			  unsigned int stop_window);
extern map<pair<string, string>, unsigned int> 
get_sum_accounting_for_param(string queue, string param_name,
			     unsigned int start_window,
			     unsigned int stop_window);
/**
   # get_current_job_dependencies
   # return an array table with all dependencies for the given job ID
*/
extern vector<unsigned int>
get_current_job_dependencies(unsigned int jobId);
/**
  # get_job
  # returns a ref to some hash containing data for the job of id passed in
  # parameter
  # parameters : base, jobid
  # return value : ref
  # side effects : /

  job extraction is restricted to 
  - state 
  - job_type
  - exit_code
*/


extern struct jobs_get_job_iolib_restrict
get_job_restrict(unsigned int idJob);
/**
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
*/
extern vector<resources_data_moldable>
get_resources_data_structure_current_job(unsigned int job_id);

/**
   # get_resources_that_can_be_waked_up
   # returns a list of resources
   # parameters : base, date max
   # return value : list of resource ref

   # get_resources_that_will_be_out
   # returns a list of resources
   # parameters : base, job max date
   # return value : list of resource ref

   restricted version to resource_id (the only used data in the scheduler)
*/
extern vector<unsigned int>
get_resources_that_can_be_waked_up_or_will_be_out(unsigned int max_date, bool waked_up);
/**
   # Get start_time for a given job
   # args : base, job id

   WARNING: no undef are returned in this version !
*/
extern struct gantt_job_start_time 
get_gantt_job_start_time(unsigned int job);
/**
   # get_current_moldable_job_restrict_moldable_wall_time
   # returns a ref to some hash containing data for the moldable job of id passed in
   # parameter
   # parameters : base, moldable job id
   # return value : ref
   # side effects : /

   restricted to moldable_wall_time
*/
extern unsigned int 
get_current_moldable_job_restrict_moldable_walltime(unsigned int moldableJobId);
/**
   # set_job_message
   # sets the message field of the job of id passed in parameter
   # parameters : base, jobid, message
   # return value : /
   # side effects : changes the field message of the job in the table Jobs
*/
extern int set_job_message(unsigned int idJob, string message); 
/**
   # get_possible_wanted_resources
   # return a tree ref : a data structure with corresponding resources with what is asked
*/
extern oar_resource_tree::TreeNode *
get_possible_wanted_resources(
			      vector<bool> possible_resources_vector,
			      vector<bool> impossible_resources_vector,
			      vector<unsigned int> resources_to_ignore_array,
			      string properties,
			      vector<property_resources_per_job> wanted_resources_ref, /* TODO: verify type */
			      string order_part);
/*
  #add scheduler decisions
  #args : base,moldable_job_id,start_time,\@resources
  #return nothing
*/
extern void add_gantt_scheduled_jobs(unsigned int id_moldable_job,
				     unsigned int start_time,
				     vector<unsigned int> resource_list);

#endif
