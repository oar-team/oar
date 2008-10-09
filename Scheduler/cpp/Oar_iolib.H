#ifndef OAR_IOLIB_H
#define OAR_IOLIB_H

#include <string>

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

#endif
