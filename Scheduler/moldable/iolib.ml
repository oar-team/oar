open Mysql
open Conf
open Types

(* A faire:
   connect
   disconnect
   get_task_list
   get_node_list
   get_preexist
   
   save_assigns

   get_DEMT_last_status
   set_DEMT_status *)

let execQuery db q = 
(*  log (Printf.sprintf "[SQL] execQuery --%s--" q); *)
  let r = exec db q in 
    match errmsg db with 
	None -> r
      | Some s -> ( error ("[Iolib] : "^s); 
		    error (" *** Query was:\n"^q);
		    failwith "execQuery" )

let connect () = 
(*  let conn = Conf.get_conn () in *)
  
  let user = get_optional_value "DB_BASE_LOGIN"
  and name = get_optional_value "DB_BASE_NAME"
  and host = get_optional_value "DB_HOSTNAME" in
  let conn = { dbuser = user;
	       dbpwd = get_optional_value "DB_BASE_PASSWD";
	       dbname = name;
	       dbhost = host;
	       dbport = None;
	     } in
    try 
      log (let o = function None -> "default" | Some s -> s in 
        Printf.sprintf "Connecting as %s@%s on %s.\n" (o user) (o host) (o name)); 
      connect conn
    with e -> ( Conf.error ("[MoldSched]: [Iolib] Connection Failed : "^(Printexc.to_string e)^"\n"))
		

let disconnect = Mysql.disconnect
  



let get_task_list db node_list = 

  let get_nodes_for_task constraints = 

    if constraints = "" then node_list 
    else begin 
      let query = Printf.sprintf "SELECT n.hostname FROM nodes n, nodeProperties p
                                WHERE n.hostname = p.hostname
                                    AND n.state = 'Alive'  AND ( %s )" constraints in  
      let res = execQuery db query in 
      let get_one_node a = 
	let get s = column res s a in 
	let id = not_null str2ml (get "hostname") in 
	  try List.find (fun n -> n.nodeId = id) node_list
	  with Not_found -> error (Printf.sprintf "Couldn't find node %s for task (%s)" id constraints) in
	
	map res get_one_node
    end in 

  let query = Printf.sprintf ("SELECT idJob, submissionTime, weight, 
				   nbNodes, maxTime, properties FROM jobs
				   WHERE state = 'Waiting' AND queueName = '%s' 
                                   AND reservation = 'None'") (Conf.queueName) in 
  let res = execQuery db query in 
  let get_one_task a = 
    let get s = column res s a in 
    let n = not_null int2ml (get "nbNodes") 
    and t = not_null TimeConversion.time2secs (get "maxTime")
    and p = not_null int2ml (get "weight")
    and c = not_null str2ml (get "properties") in 
      { taskId = not_null int2ml (get "idJob");
	submit_time = not_null TimeConversion.datetime2secs (get "submissionTime");
	nb_procs = p;
	default_alloc = n;
	allocation = n;
	alloc_changed = false;
	allowed_allocs = [n];
	run_time = (function x when x = n -> t | _ -> failwith "Task run_time");
	priority = 1; 
	allowed_nodes = get_nodes_for_task c; } in
    
    map res get_one_task 

let get_node_list db = 
  let query = "SELECT hostname, maxWeight, state FROM nodes
		WHERE state = 'Alive' OR state = 'Suspected' OR state = 'Absent'" in
  let res = execQuery db query in 
  let get_one a = 
    let get s = column res s a in 
      { nodeId = not_null str2ml (get "hostname");
	max_procs = not_null int2ml (get "maxWeight"); 
	state = not_null (fun x -> let s = str2ml x in nstate_of_string s) (get "state") ;} in
    map res get_one
      
let get_preexist db node_list = 
  let query = "SELECT g.idJob, g.startTime, queueName, maxTime, weight"^
	      "    FROM ganttJobsPrediction g, jobs j"^
              "    WHERE g.idJob = j.idJob" in
  let res = execQuery db query in 
  let get_one a = 
    let get s = column res s a in 
    let id = not_null int2ml (get "idJob") in
      { pre_taskId = id;
	pre_run_time = not_null TimeConversion.time2secs (get "maxTime");
	pre_nb_procs = not_null int2ml (get "weight");
	sched_time = not_null TimeConversion.datetime2secs (get "startTime");
	besteffort = (not_null str2ml (get "queueName")) = Conf.besteffortQueueName;
	nodes = (let q = Printf.sprintf 
			   "SELECT hostname FROM ganttJobsNodes WHERE idJob = %d" id in 
		 let res = execQuery db q in 
		 let one x = let s = str2ml x in 
		   try List.find (fun n -> n.nodeId = s) node_list 
		   with Not_found -> error (Printf.sprintf "Cannot find node %s for task %d" s id) in
		   
		   map_col res "hostname" (not_null one)); } in

    map res get_one
      
	      
let save_assigns conn assigns = 

  if not (assigns = []) then 
    let assigns_to_pred (t, time, nodes) = 
      Printf.sprintf "(%s, %s)" (ml2int t.taskId) (TimeConversion.secs2datetime time) in
    let query_pred = 
      "INSERT INTO ganttJobsPrediction (idJob, startTime) VALUES"^
      (String.concat ", " (List.map assigns_to_pred assigns)) in 
    let assigns_to_job_nodes (t, time, nodes) = 
      let idJob = ml2int t.taskId in 
      let node_to_value n = 
	Printf.sprintf "(%s, %s)" idJob (ml2str n.nodeId) in
	String.concat ", " (List.map node_to_value nodes) in 
    let query_job_nodes = 
      "INSERT INTO ganttJobsNodes (idJob, hostname) VALUES"^
      (String.concat ",\n" (List.map assigns_to_job_nodes assigns)) in 
      
      ignore (execQuery conn query_pred);
      ignore (execQuery conn query_job_nodes)
