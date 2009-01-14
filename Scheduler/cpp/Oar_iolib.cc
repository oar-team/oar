/******************************************************************************
# This is the iolib, which manages the layer between the modules and the
# database. This is the only base-dependent layer.
# When adding a new function, the following comments are required before the code of the function:
# - the name of the function
# - a short description of the function
# - the list of the parameters it expect
# - the list of the return values
# - the list of the side effects
******************************************************************************/

#include <string>
#include <QtSql>
#include <QSqlQuery>
#include <vector>
extern "C" {
#include <regexp.h>
}

#include "Oar_resource_tree.H"

using namespace std;

/* fonction de la iolib utilisee dans sched_gantt_... */
/*
  connect_db() - DONE
  connect() - DONE
  connect_ro() - DONE
  disconnect() - DONE
  get_specific_resource_states($base,$Resources_to_always_add_type); - DONE
  list_resources($base) - DONE
  iolib::get_gantt_scheduled_jobs(); - DONE
  get_current_job_types($base,$i); - DONE
  get_job_current_resources($base, $already_scheduled_jobs{$i}->[7],\@Sched_available_suspended_resource_type); - DONE
  get_job_suspended_sum_duration($base,$i,$current_time); - DONE
  iolib::get_resources_in_state($base,"Alive"); - DONE
  get_resources_in_state($base,"Dead")); - DONE
  get_fairsharing_jobs_to_schedule($base,$queue,$Karma_max_number_of_jobs_treated_per_user); - DONE
  get_sum_accounting_window($base,$queue,$current_time - $Karma_window_size,$current_time); - DONE
  get_sum_accounting_for_param($base,$queue,"accounting_project",$current_time - $Karma_window_size,$current_time); - DONE
  get_sum_accounting_for_param($base,$queue,"accounting_user",$current_time - $Karma_window_size,$current_time); - DONE
  get_current_job_dependencies($base,$j->{job_id})) - DONE
  get_job($base,$d); - DONE
  get_gantt_job_start_time($base,$d); - DONE
  get_current_moldable_job($base,$date_tmp[1]); - DONE
  set_job_message($base,$j->{job_id},$message); - DONE
  set_job_message($base,$j->{job_id},$message); - DONE IDEM PREC
  get_current_job_types($base,$j->{job_id}); - DONE
  get_resources_data_structure_current_job($base,$j->{job_id}); - DONE
  get_resources_that_can_be_waked_up($base, iolib::get_date($base) + $duration)) - DONE
  get_resources_that_will_be_out($base, iolib::get_date($base) + $duration)) - DONE - MERGED WITH PRECEDENT
  get_possible_wanted_resources($base_ro,$alive_resources_vector,$resource_id_used_list_vector,\@Dead_resources,"$job_properties AND $tmp_properties", $m->{resources}, $Order_part); - DONE
  add_gantt_scheduled_jobs($base,$moldable_results[$index_to_choose]->{moldable_id}, $moldable_results[$index_to_choose]->{start_date},$moldable_results[$index_to_choose]->{resources}); - DONE
  set_job_message($base,$j->{job_id},"Karma = ".sprintf("%.3f",karma($j))); - DONE PREV
  disconnect($base_ro); - DONE PREV
*/

/**
   Questions ouvertes:

   - dans OAR perl, il y a dans des string double-cote avec " " il y a
   plein de " \'CURRENT\' " qui sont equivalents a " 'CURRENT'
   ". Etonnant non ? C'est idem en C++, donc je les laisse :-)
*/
namespace iolib 
{

QSqlDatabase db;

/*
  # connect_db
  # Connects to database and returns the base identifier
  # return value : base
*/

int connect_db(string dbhost, int dbport, string dbname, string dblogin, string dbpasswd, int debug_level=0)
{
  db = QSqlDatabase::addDatabase("oardb");
  db.setHostName(QString::fromStdString( dbhost ));
  db.setPort(dbport);
  db.setDatabaseName(QString::fromStdString( dbname ));
  db.setUsername(QString::fromStdString( dblogin ));
  db.setpassword(QString::fromStdString( dbpasswd ));

  bool ok = db.open();

  /* TODO: ajouter le traitement d'erreur
     if (!defined($dbh)){
        oar_error("[IOlib] Cannot connect to database (type=$Db_type, host=$host, user=$user, database=$name) : $DBI::errstr\n");
        if ($Timeout_db_connection < $Max_db_connection_timeout){
            $Timeout_db_connection += 2;
        }
        oar_warn("[IOlib] I will retry to connect to the database in $Timeout_db_connection s\n");
        send_log_by_email("OAR database connection failed","[IOlib] I will retry to connect to the database in $Timeout_db_connection s\n");
        sleep($Timeout_db_connection);
    }
  */

  return ok;
}

/**
  # connect
  # Connects to database and returns the base identifier
  # parameters : /
  # return value : base
  # side effects : opens a connection to the base specified in ConfLib
*/


bool connect() {
  //# Connect to the database.
  init_conf(getenv("OARCONFFILE"));
  
  string dbhost = get_conf("DB_HOSTNAME");
  string dbport = get_conf("DB_PORT");
  string dbname = get_conf("DB_BASE_NAME");
  string dblogin = get_conf("DB_BASE_LOGIN");
  string dbpwd = get_conf("DB_BASE_PASSWD");
  string Db_type = get_conf("DB_TYPE");
  
  string log_level = get_conf("LOG_LEVEL");
  
  string Remote_host = get_conf("SERVER_HOSTNAME");
  string Remote_port = get_conf("SERVER_PORT");

  

  return connect_db(dbhost, dbport, dbname, dblogin, dbpasswd, debug_level);
}

/* 
   # connect_ro
   # Connects to database and returns the base identifier
   # parameters : /
   # return value : base
   # side effects : opens a connection to the base specified in ConfLib
*/
bool connect_ro() {
  return connect();
}

/*
  # disconnect
  # Disconnect from database
  # parameters : base
  # return value : /
  # side effects : closes a previously opened connection to the specified base
*/
void disconnect() {
  assert( db.isValid() );
  db.close();
}

/*
  # get_specific_resource_states
  # returns a hashtable with each given resources and their states
  # parameters : base, resource type
*/
map< string, string > 
get_specific_resource_states(string type) {
  assert( db.isValid() );
  QSqlQuery query;
  query.setForwardOnly(true);
  string req = "   SELECT resource_id, state\
                   FROM resources\
                   WHERE\
                    type = \'" +type+"\'\
                ";
  query.exec(req);
  vector< pair< string, string> > result;
  while( query.next() )
    {
      string resource_id = query.value(1).toString();
      string state = query.value(0).toString();

      result.insert( pair<string, string>(resource_id, state) );
    }
  return result;
}

/*
  # list_resources
  # gets the list of all resources
  # parameters : base
  # return value : list of resources
  # side effects : /
*/

static bool yesNo2Bool(string s)
{
  if ( s == "YES" )
    return true;
  if ( s == "NO" )
    return false;
  assert( s == "YES" || s == "NO" );
}

static struct resources_iolib fillResourcesStruct(QSqlQuery &req)
{
  /* the value of the structure must be given in the same order a
     filled by the SELECT call.
  */
  resources_iolib result;

  result.resource_id = req.value(0).toUInt();
  result.type = req.value(1).toString();
  result.network_address = req.value(2).toString();
  result.state = req.value(3).toString();
  result.next_state = req.value(4).toString();
  result.finaud_decision = yesNo2Bool(req.value(5).toString());
  result.next_finaud_decision = yesNo2Bool(req.value(6).toString());
  result.state_num = req.value(7).toUInt();
  result.suspended_jobs = yesNo2Bool(req.value(8).toString());
  result.scheduler_priority = req.value(9).toUInt();
  result.switch_name = req.value(10).toString();
  result.cpu = req.value(11).toUInt();
  result.cpuset = req.value(12).toUInt();
  result.besteffort = yesNo2Bool(req.value(13).toString());
  result.deploy = yesNo2Bool(req.value(14).toString());
  result.expiry_date = req.value(15).toUInt(); 
  result.desktop_computing = yesNo2Bool(req.value(16).toString());
  result.last_job_date = req.value(17).toUInt();
  result.cm_availability = req.value(18).toUInt();

  return result;
}

/** TODO SIMPLIFICATION : l usage de cette fonction est uniquement
    d'obtenir la liste des ID pour remplir le vecteur de bit !
    
    TODO RTFM: il est possible de faire semblable au caode perl avec
    QtSQLModel ! readonly avec 
 */

vector <resources_iolib> resources_extractor(bool withState, string state="") {
  assert(db.isValid());
  QSqlQuery query;
  query.setForwardOnly(true);
  vector <resources_iolib> result;
  string req = "SELECT resource_id, type, network_address, state, next_state, finaud_decision, next_finaud_decision, state_num, suspended_jobs, scheduler_priority, switch, cpu, cpuset, besteffort, deploy, expiry_date, desktop_computing, last_job_date, cm_availability\
                FROM resources\
                ";
  if (withState)
    {
      req += "WHERE\
               state = \'" << state << "\'");
    }


  query.exec(req);
  while( query.next() )
    {
      result.push_back( fillResourcesStruct(req) );
    }

  return result;
}

vector <resources_iolib> list_resources()
{
  return resources_extractor(false);
}

/*
  # GANTT MANAGEMENT
  
  #get previous scheduler decisions
  #args : base
  #return a hashtable : job_id --> [start_time,walltime,queue_name,\@resources,state]
  # TODO commentaire PERL faux: bien plus d'information et pas de resssource !
*/
pair< vector<unsigned int>, map<unsigned int, struct gantt_sched_jobs>  >
get_gantt_scheduled_jobs(){
  QSqlQuery query;
  query.setForwardOnly(true);
  map<unsigned int, struct gantt_sched_jobs> result;
  vector<unsigned int> order;
  assert(db.isValid());
  
  string req("SELECT j.job_id, g2.start_time, m.moldable_walltime, g1.resource_id, j.queue_name, j.state, j.job_user, j.job_name,m.moldable_id,j.suspended\
                             FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, moldable_job_descriptions m, jobs j\
                             WHERE\
                                m.moldable_index = \'CURRENT\'\
                                AND g1.moldable_job_id = g2.moldable_job_id\
                                AND m.moldable_id = g2.moldable_job_id\
                                AND j.job_id = m.moldable_job_id\
                             ORDER BY j.start_time, j.job_id\
                            ");
  query.exec(req);
  while( query.next() )
    {
      struct gantt_sched_jobs val;
      unsigned int jid;

      if (result.find(query.value(0).toUint()) != result.end()) {
	jid = query.value(0).toUint();
	val.job_id = jid;
	val.start_time = query.value(1).toUint();
	moldable_walltime = query.value(2).toUint();
	queue_name = query.value(4).toString();
	state = query.value(5).toString();
	job_user = query.value(6).toString();
	job_name = query.value(7).toString();
	moldable_id = query.value(7).toUInt();
	suspended = yesNo2Bool(req.value(8).toString());
	order.push_back(jid);
	result.insert( pair<unsigned int, struct gantt_sched_jobs>(jid, val) );
      }
      result[jid].resource_id_vec.push_back( query.value(3).toUint() );
    };

  return pair< vector<unsigned int>, map<unsigned int, struct gantt_sched_jobs>  >(order, result);
}

/**
  # get_current_job_types
  # return a hash table with all types for the given job ID
*/
static regexp *rexp_get_current_job_types = 0;

map<string, string>
get_current_job_types(unsigned int jobId){
  QSqlQuery query;
  query.setForwardOnly(true);
  map<string, string> res;
  
  if (rexp == 0)
    rexp_get_current_job_types = regcomp("^\s*(\w+)\s*=\s*(.+)$")

  string req = "   SELECT type\
                   FROM job_types\
                   WHERE\
                        types_index = \'CURRENT\'\
                        AND job_id = $jobId\
                "
  assert(db.isValid());

  query.exec(req);

  while( query.next() )
    {
      int valrec;
      valres = regexec(rexp_get_current_job_types, query.value(0).toString() );

      if (valres)
	{
	  res.insert( pair<string, string>( string(startp[1], endp[1]),
					    string(startp[2], endp[1]) ) );
	}
      else
	{
	  res.insert(pair<string, string>( query.value(0).toString(),
					   "true") );
	}
    }
  return res;
}

/*
  # get_job_current_resources
  # returns the list of resources associated to the job passed in parameter
  # parameters : base, jobid
  # return value : list of resources
  # side effects : /
*/

static 
string quote_sql2(const string s)
{
  string res=s;
  size_t value = std::string::npos;

  value = res.find_first_of("'", 0);
  while(value != std::string::npos)
    {
      res.replace(value, 1, "''");
      value +=2;
      value = res.find_first_of("'", value);
    }
  return res;
} 

vector<unsigned int>
get_job_current_resources(unsigned int jobid, vector<string> not_type_list) 
{
  vector <unsigned int> result;
  QSql query;
  string tmp_str;
  assert(db.isValid());
  string req;
  
  if (not_type_list.size() == 0)
    {
      tmp_str= "FROM assigned_resources\
                WHERE\
                  assigned_resources.assigned_resource_index = \'CURRENT\' AND\
                  assigned_resources.moldable_job_id = ";
      tmp_str << jobid;
    }
  else
    {
      string type_str;
      for(i=0; i< not_type_list.size(); i++)
	{
	  if (i > 0)
	    type_str << ",";
	  type_str << quote_sql2( not_type_list[i] );
	}
      tmp_str = "FROM assigned_resources,resources\
                 WHERE\
                  assigned_resources.assigned_resource_index = \'CURRENT\' AND\
                  assigned_resources.moldable_job_id =";
      tmp_str << jobid << " AND\
              resources.resource_id = assigned_resources.resource_id AND\
              resources.type NOT IN (" << type_str << ")";


    }
  req = "SELECT assigned_resources.resource_id as resource ";
  req << tmp_str << " ORDER BY assigned_resources.resource_id ASC";

  
  query.exec(req);
  while( query.next() )
    {
      unsigned int resource_id = query.value(0).toUint();
      result.push_back( resource_id );
    }

  return result;
}

/**
# get the amount of time in the suspended state of a job
# args : base, job id, time in seconds
*/
unsigned int get_job_suspended_sum_duration(unsigned int job_id,
					    unsigned int current_time)
{
  assert(db.isValid());
  QSqlQuery query;
  query.setForwardOnly(true);
  unsigned int sum;

  string req = "SELECT date_start, date_stop\
                FROM job_state_logs\
                WHERE\
                 job_id = " << job_id<< " AND\
                     (job_state = \'Suspended\' OR\
                      job_state = \'Resuming\')";

  query.exec(req);
  sum =0;
  while( query.next() )
    {
      unsigned int tmp_sum = 0;
      unsigned int date_start =  query.value(0).toUInt();
      unsigned int date_stop = query.value(1).toUInt();

      if ( date_stop == 0 ) 
	tmp_sum = current_time - date_start;
      else
	tmp_sum = date_stop - date_start;

      sum += tmp_sum;
    }
  
  return sum;
}

/**
   # get_resources_in_state
   # returns the list of resources in the state specified
   # parameters : base, state
   # return value : list of resource ref

   c'est une quasi-copie de list_resources, j'ai mutualiser le code
*/


vector<resources_iolib> get_resources_in_state(string state)
{
  return resources_extractor(true, state);
}


/** 
    remplissage de la structure jobs restreinte 
*/
static struct jobs_iolib_restrict fillJobsStructRestrict(QSqlQuery &query)
{
  /* the value of the structure must be given in the same order a
     filled by the SELECT call.
  */
  jobs_iolib_restrict result;

  result.job_id = query.value(0).toUInt();
  result.job_name = query.value(1).toString();
  result.job_user = query.value(2).toString();
  result.properties = query.value(3).toString();
  result.project = query.value(4).toString();

  return result;
}
 
/**
  # get_fairsharing_jobs_to_schedule
  # args : base ref, queue name
*/
vector<jobs_iolib_restrict> get_fairsharing_jobs_to_schedule(string queue, unsigned int limit)
{
  assert(db.isValid());
  QSqlQuery query;
  query.setForwardOnly(true);
  unsigned int sum;

  string req = "SELECT distinct(job_user)\
                FROM jobs\
                WHERE\
                   state = \'Waiting\'\
                   AND reservation = \'None\'\
                   AND queue_name = \'" << queue << "\'\
               ";

  vector<string> users;
  query.exec(req);
  while( query.next() )
    {
      users.insert( string(query.value(0).toString() ) );
    }
  
  vector<jobs_iolib_restrict> res;
  for(vector<string>::iterator u = users.begin();
      u != users.end();
      u++)
    {
      string req2 = "SELECT job_id,job_name,job_user,properties,project\
                     FROM jobs\
                     WHERE			\
                        state = \'Waiting\'\
                        AND reservation = \'None\'\
                        AND queue_name = \'" << queue << "\'	\
                        AND job_user = \'" << *u << "\'		\
                     ORDER BY job_id				\
                     LIMIT "<< limit <<"			\
               ";
      query.exec(req);
      while( query.next() )
	{
	  res.insert( fillJobsStructRestrict(query) );
	}
    }
  return res;
}

map<string, unsigned int> get_sum_accounting_window(string queue,
					      unsigned int start_window,
					      unsigned int stop_window)
{
  assert(db.isValid());
  QSqlQuery query;
  query.setForwardOnly(true);
  unsigned int sum;

  string req = "SELECT consumption_type, SUM(consumption)\
                                FROM accounting		 \
                                WHERE					\
                                    queue_name = \'" << queue << "\' AND \
                                    window_start >= " << start_window << " AND \
                                    window_start < " << stop_window << " \
                                GROUP BY consumption_type		\
                ";

  query.exec(req);
  sum =0;
  map<string,string> results
  while( query.next() )
    {
      string consumption_type =  query.value(0).toString();
      unsigned int sum_consumption = query.value(1).toUInt();
      
      results.insert( pair<string, unsigned int>( consumption_type, sum_consumption));
    }
  
  return results;
}

/**
  TODO: no comment in perl !
*/
map<pair<string, string>, unsigned int> 
get_sum_accounting_for_param(string queue, string param_name,
			     unsigned int start_window, unsigned int stop_window)
{
  assert(db.isValid());
  QSqlQuery query;
  query.setForwardOnly(true);
  unsigned int sum;

  string req = "   SELECT " << param_name<< ",consumption_type, SUM(consumption)\
                   FROM accounting\
                   WHERE\
                      queue_name = \'" << queue<< "\' AND\
                      window_start >= " << start_window<< " AND\
                      window_start < "<< stop_window<< "\
                   GROUP BY " << param_name<< ",consumption_type\
              ";

  query.exec(req);
  sum =0;
  map< pair<string,string>, unsigned int> results
  while( query.next() )
    {
      string param =  query.value(0).toString();
      string consumption_type = query.value(1).toString(); 
      string sum_consumption = query.value(2).toUInt();
      
      results.insert( pair<pair<string,string>, unsigned int>( pair<string,string>( param, consumption_type ), sum_consumption));
    }
  
  return results;
}

/**
   # get_current_job_dependencies
   # return an array table with all dependencies for the given job ID
*/
vector<unsigned int> get_current_job_dependencies(unsigned int jobId)
{
  assert(db.isValid());
  QSqlQuery query;
  query.setForwardOnly(true);

  string req = "   SELECT job_id_required\
                   FROM job_dependencies\
                   WHERE\
                        job_dependency_index = \'CURRENT\'\
                        AND job_id = "<< jobId <<"\
                ";

  query.exec(req);
  vector<unsigned int> results
  while( query.next() )
    {
      unsigned int job_id_required =  query.value(0).toUInt();
      
      results.push_back( job_id_required );
    }
  
  return results;
}


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


struct jobs_get_job_iolib_restrict
get_job_restrict(unsigned int idJob) 
{
  assert(db.isValid());
  QSqlQuery query;
  query.setForwardOnly(true);

  string req = "   SELECT state, job_type, exit_code\
                   FROM jobs\
                   WHERE\
                       job_id = << " idJob << "\
                ";

  query.exec(req);

  struct jobs_get_job_iolib_restrict results;
  results.state = "ONE VALUE"
  while( query.next() )
    {
      string state = query.value(0).toString();
      string job_type = query.value(1).toString();
      int exit_code =  query.value(2).toInt();
      
      assert(results.state == "ONE VALUE");
      results.state = state;
      results.job_type = job_type;
      results.exit_code = exit_code;
    }
  
  return results;
}

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
vector<resources_data_moldable>
get_resources_data_structure_current_job(unsigned int job_id)
{
  assert(db.isValid());
  QSqlQuery query;
  query.setForwardOnly(true);

  string req = "   SELECT moldable_job_descriptions.moldable_id, job_resource_groups.res_group_id, moldable_job_descriptions.moldable_walltime, job_resource_groups.res_group_property, job_resource_descriptions.res_job_resource_type, job_resource_descriptions.res_job_value\
                   FROM moldable_job_descriptions, job_resource_groups, job_resource_descriptions, jobs\
                   WHERE\
                        jobs.job_id = " << job_id << "\
                        AND jobs.job_id = moldable_job_descriptions.moldable_job_id\
                        AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id\
                        AND job_resource_descriptions.res_job_group_id = job_resource_groups.res_group_id\
                   ORDER BY moldable_job_descriptions.moldable_id, job_resource_groups.res_group_id, job_resource_descriptions.res_job_order ASC\
                            ";
 

  query.exec(req);
  vector<resources_data_moldable> result;
  int group_index = -1;
  int moldable_index = -1;
  int previous_group = 0;
  int previous_moldable = 0;

  while( query.next() )
    {
      //  moldable_job_descriptions.moldable_id
      unsigned int moldable = query.value(0).toUInt();
      // job_resource_groups.res_group_id
      unsigned int group = query.value(1).toUInt();
      // moldable_job_descriptions.moldable_walltime
      unsigned int walltime = query.value(2).toUInt();
      // job_resource_groups.res_group_property
      string property = query.value(3).toString();
      // job_resource_descriptions.res_job_resource_type
      string resource = query.value(4).toString();
      // job_resource_descriptions.res_job_value
      string value = query.value(5).toString();

      if (previous_moldable != moldable)
	{
	  moldable_index ++;
	  previous_moldable = moldable;
	  group_index = 0;
	  previous_group = group;
	}
      else if (previous_group != group)
	{
	  group_index++;
	  previous_group = group;
	}
      // Store walltime
      if (result.size() < moldable+1)
	result.push_back(resources_data_moldable());
      result[moldable_index].walltime = walltime;
      result[moldable_index].moldable_job_id = moldable;

      // Store properties group
      if (result[moldable_index].prop_res.size() < group_index+1)
	result[moldable_index].prop_res.push_back(property_resources_per_job()); 
      result[moldable_index].prop_res[group_index].property = property;
 
      resources_per_job tmp_res;
      tmp_res.resource = resource;
      tmp_res.value = value;


      result[moldable_index].prop_res[group_index].resources.push_back(tmp_res);
        
    }
  return(result);
}

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
vector<unsigned int> get_resources_that_can_be_waked_up_or_will_be_out(unsigned int max_date, bool waked_up) 
{  
  assert(db.isValid());
  QSqlQuery query;
  query.setForwardOnly(true);

  string status;
  string compar_oper;

  switch(waked_up)
    {
    case true:
      status = "Absent";
      compare_oper = ">";
      break;
    case false:
      status = "Alive";
      compare_oper = "<";
      break;
    }

  string req = "   SELECT resource_id\
                   FROM resources\
                   WHERE\
                     state = \'" << status << "\' AND\
                     resources.cm_availability " << compare_oper <<" " << max_date << "\
                ";
                
  query.exec(req);

  vector <unsigned int> results;
  while( query.next() )
    {
      unsigned int resource_id = query.value(0).toUInt();
      results.push_back(resource_id);
    }
  
  return results;
}

/**
   # Get start_time for a given job
   # args : base, job id

   WARNING: no undef are returned in this version !
*/
struct gantt_job_start_time get_gantt_job_start_time(unsigned int job)
{
  assert(db.isValid());
  QSqlQuery query;
  query.setForwardOnly(true);
 
  string req = "   SELECT gantt_jobs_predictions.start_time, gantt_jobs_predictions.moldable_job_id\
                   FROM gantt_jobs_predictions,moldable_job_descriptions\
                   WHERE\
                      moldable_job_descriptions.moldable_job_id = " << job <<"\
                      AND gantt_jobs_predictions.moldable_job_id = moldable_job_descriptions.moldable_id\
";
                
  query.exec(req);

  struct gantt_job_start_time results={};
  if ( query.next() )
    { 
      results.start_time = query.value(0).toUInt();
      results.moldable_job_id = query.value(1).toUInt();
    }
  else
    assert(0);
  
  assert(! query.next()); /* only one answer ! */
  return results;
}

/**
   # get_current_moldable_job_restrict_moldable_wall_time
   # returns a ref to some hash containing data for the moldable job of id passed in
   # parameter
   # parameters : base, moldable job id
   # return value : ref
   # side effects : /

   restricted to moldable_wall_time
*/
unsigned int 
get_current_moldable_job_restrict_moldable_walltime(unsigned int moldableJobId) 
{
  assert(db.isValid());
  QSqlQuery query;
  query.setForwardOnly(true);
 
  string req = "   SELECT moldable_walltime\
                   FROM moldable_job_descriptions\
                   WHERE\
                        moldable_index = \'CURRENT\'\
                        AND moldable_id = " << moldableJobId << "\
               ";
                
  query.exec(req);

  unsigned int results=0;
  if ( query.next() )
    { 
      results = query.value(0).toUInt();
    }
  else
    assert(0);
  
  assert(! query.next()); /* only one answer ! */
  return results;
}

/**
   # set_job_message
   # sets the message field of the job of id passed in parameter
   # parameters : base, jobid, message
   # return value : /
   # side effects : changes the field message of the job in the table Jobs
*/
int set_job_message(unsigned int idJob, string message) 
{
  assert(db.isValid());
  QSqlQuery query;
  string req = "  UPDATE jobs\
                  SET message = " << message << "\
                  WHERE\
                     job_id = "<< idJob<<"\
               ";
                
  query.exec(req);
  return 0;
}

/**
   # get_possible_wanted_resources
   # return a tree ref : a data structure with corresponding resources with what is asked
*/
TreeNode *get_possible_wanted_resources(
				  vector<bool> possible_resources_vector,
				  vector<bool> impossible_resources_vector,
				  vector<unsigned int> resources_to_ignore_array,
				  
				  string properties,
				  vector<property_resources_per_job> wanted_resources_ref, /* TODO: verify type */
				  string order_part)
{
  string sql_in_string= "\'1\'";

  if (resources_to_ignore_array.size() > 0 )
    {
      sql_in_string = "resource_id NOT IN (";
      for(vector<unsigned int>::iterator i
	    = resources_to_ignore_array.begin();
	  i != resources_to_ignore_array.end();
	  i++)
	{
	  static bool debut=1;
	  switch (debut)
	    {
	    case 0:
	      sql_in_string += ",";
	    case 1:
	      debut = 0;
	    }
	  sql_in_string += "" << *i;
	}
      sql_in_string = ")";
    }

  if (order_part != "")
    order_part =  "ORDER BY " << order_part;

  /* copy !*/
  wanted_resources = wanted_resources_ref;
  int nb_res = wanted_resources.resources.size();
  if (wanted_resources.resources[nb_res - 1]->resource != "resource_id")
    wanted_resources.resources.push_back( resources_per_job("resource_id",
							    "-1"));

  string sql_where_string = "\'1\'";
    
  if (properties != "")
    sql_where_string += " AND ( " << properties <<" )";

    
  /* #Get only wanted resources */
  string resource_string;
  for(vector<resources_per_job>::iterator i
	    =  wanted_resources.resources.begin();
	  i !=  wanted_resources.resources.end();
	  i++)
    {
      static bool debut=1;
      switch (debut)
	{
	case 0:
	  resource_string += ",";
	case 1:
	  debut = 0;
	  break;
	}
      resource_string += "" << i->resource;
    }

  assert(db.isValid());
  QSqlQuery query;
  query.setForwardOnly(true);
 
  string req = "SELECT " << resource_string << "\
                FROM resources\
                WHERE\
                   ("<< sql_where_string<< ") AND\
                    " << sql_in_string << "\
                " << order_part <<"\
               ";
                
  query.exec(req);

  /* how to send back Undef ? why ? */
    
  /*  # Initialize root */
  TreeNode *result;
  result = new( TreeNode(0) );
  int wanted_children_number = wanted_resources.resources[0].value;
  result->set_needed_children_number(wanted_children_number);
  
  while( query.next() )
    {
      TreeNode *father_ref = result;
      for(i=0; i < wanted_resources.resources.size(); i++)
	{
          /**  # Feed the tree for all resources */
	  father_ref = father_ref->add_child(wanted_resources.resources[i].resource,
					     query.value(i).toString() );

	  int wanted_children_number;
	  if ( i < wanted_resources.resources.size() - 1)
	    wanted_children_number = wanted_resources.resources[i+1].value;
	  else
	    wanted_children_number = 0;

	  father_ref->set_needed_children_number(wanted_children_number);

          /*  # Verify if we must keep this child if this is resource_id resource name */
	  if ( wanted_resources.resources[i].resource == "resource_id" )
	    {
	      if (impossible_resources_vector.size() > 0 
		  && impossible_resources_vector[ query.value(i).toInt() ] )
		{
		  father_ref->delete_subtree();
		  i = wanted_resources.resources.size(); /* the end */
		}
	      else 
		if ( possible_resources_vector.size() > 0 
		  && ! possible_resources_vector[ query.value(i).toInt() ])
		  {
		    father_ref->delete_subtree();
		    i = wanted_resources.resources.size(); /* the end */
		  }
	    }
	}
    }
  result->delete_tree_nodes_with_not_enough_resources();

  return result;
}

/**
  #add scheduler decisions
  #args : base,moldable_job_id,start_time,\@resources
  #return nothing
*/
void add_gantt_scheduled_jobs(unsigned int id_moldable_job,
			     unsigned int start_time,
			     vector<unsigned int> resource_list)
{
  assert(db.isValid());
  QSqlQuery query;


  string req = "    INSERT INTO gantt_jobs_predictions (moldable_job_id,start_time)\
                    VALUES ("<< id_moldable_job<< ",\'"<< start_time<<"\')\
               ";

  query.exec(req);

  for(vector<unsigned int>::iterator i = resource_list.begin();
      i !=  resource_list.end();
      i++)
    {
      QSqlQuery query2;
      string req2 = "   INSERT INTO gantt_jobs_resources (moldable_job_id,resource_id)\
                        VALUES ("<<id_moldable_job<<","<<*i<<")\
               ";

      query.exec();
    }
}

}
