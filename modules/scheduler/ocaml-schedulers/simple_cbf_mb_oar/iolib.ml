open Mysql
open Conf
open Types
open Interval
open Helpers

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


let execQuery db q = 
(*  log (Printf.sprintf "[SQL] execQuery --%s--" q); *)
  let r = exec db q in 
    match errmsg db with 
				None -> r
      | Some s -> ignore (Conf.error ("[Iolib] : "^s)); 
		              ignore (Conf.error (" *** Query was:\n"^q));
		              failwith "execQuery"

(* iolib::list_resources *)
let get_resource_list db = 
  let query = "SELECT * FROM resources" in
  let res = execQuery db query in 
  let get_one a = 
    let get s = column res s a in 
      { resource_id = not_null int2ml (get "resource_id");
				network_address = not_null str2ml (get "network_address"); 
				state = not_null (fun x -> let s = str2ml x in rstate_of_string s) (get "state") ;} in
    			map res get_one

(* get_job_list *) 
(* get jobid,walltime, nb_res *) 
(* WARNING !!! only one occurence must be allowed, it doesn't support moldable and multiple resources requirement or hierachy*)
let get_job_list db initial_resources =
  
  let get_resources_for_job  constraints = 
    if constraints = "" then 
      initial_resources 
    else begin 
(* TO CONTINUE *)
      let query = Printf.sprintf "SELECT resource_id FROM resources WHERE state = 'Alive'  AND ( %s )" constraints in  
      let res = execQuery db query in 
      let get_one_resource a = let get s = column res s a in 
	    let r_id = not_null int2ml (get "resource_id") in
      r_id in
      let matching_resources = (map res get_one_resource) in
	        (ints2intervals matching_resources, List.length matching_resources)
    end in

  let query = "
    SELECT jobs.job_id, moldable_job_descriptions.moldable_walltime, jobs.properties, 
           moldable_job_descriptions.moldable_id, job_resource_descriptions.res_job_value
    FROM moldable_job_descriptions, job_resource_groups, job_resource_descriptions, jobs
    WHERE jobs.state = 'Waiting'
    AND jobs.reservation = 'None'
    AND jobs.job_id = moldable_job_descriptions.moldable_job_id
    AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id
    AND job_resource_descriptions.res_job_group_id = job_resource_groups.res_group_id
    ORDER BY job_id ASC ;" in
  let res = execQuery db query in 
  let get_one_job a = 
    let get s = column res s a in 
      let j_id = not_null int2ml (get "job_id") 
      and j_walltime = not_null int642ml (get "moldable_walltime")
      and j_moldable_id = not_null int2ml (get "moldable_id")
      and j_properties = not_null str2ml (get "properties")
      and j_nb_res = not_null int2ml (get "res_job_value") in
      let j_constraints = get_resources_for_job j_properties in
        { 
          jobid = j_id;
          moldable_id = j_moldable_id;
          time_b = Int64.zero;
          walltime = j_walltime;
          types = [];
          constraints = j_constraints;
          nb_res = j_nb_res;
          set_of_rs = [];
        } in
      map res get_one_job 

(* iolib::get_gantt_scheduled_jobs *)
let get_scheduled_jobs dbh =
  let query = "SELECT j.job_id, g2.start_time, m.moldable_walltime, g1.resource_id, j.queue_name, j.state, j.job_user, j.job_name,m.moldable_id,j.suspended
      FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, moldable_job_descriptions m, jobs j
      WHERE
        m.moldable_index = 'CURRENT'
        AND g1.moldable_job_id = g2.moldable_job_id
        AND m.moldable_id = g2.moldable_job_id
        AND j.job_id = m.moldable_job_id
      ORDER BY j.start_time, j.job_id;" in
  let res = execQuery dbh query in
(* let first_res = fetch res *)
    let first_res = function
      | None -> []
      | Some first_job -> 
 (*   if not (first_res = None) then *)
          let newjob_res job_res = 
(* function
           | None -> failwith "pas glop" (*not reacheable*) 
           | Some job_res -> *)
              let get s = column res s job_res in 
              let j_id = not_null int2ml (get "job_id")
              and j_walltime = not_null int642ml (get "moldable_walltime")
              and j_moldable_id = not_null int2ml (get "moldable_id")
              and j_start_time = not_null int642ml (get "start_time")
              and j_nb_res = not_null int2ml (get "resource_id") in 

                ( {
                  jobid = j_id;
                  moldable_id = j_moldable_id;
	                time_b = j_start_time;
	                walltime = j_walltime;
                  types = [];
                  constraints = ([],0); (* constraints irrelevant for already scheduled job *)
	                nb_res = 1; 
                  set_of_rs = []; (* will be set when all resource_id are fetched *)
                }, 
                  [j_nb_res]) 
       in

        let get_job_res job_res =
          let get s = column res s job_res in 
            let j_id = not_null int2ml (get "job_id")
            and j_nb_res = not_null int2ml (get "resource_id") in 
          (j_id, j_nb_res)
        in 
      
      let rec aux result job_l current_job_res = match result with
        | None ->   let job = fst current_job_res in 
                      job.set_of_rs <- ints2intervals (snd current_job_res);
                      List.rev (job::job_l) 
        | Some x -> let j_r = get_job_res x in 
                    let j_current = fst current_job_res in
                      if ((fst j_r) = j_current.jobid) then
                        begin 
                          j_current.nb_res <- ( j_current.nb_res + 1);
                          aux (fetch res) job_l (j_current, (snd j_r) :: (snd current_job_res))
                        end 
                      else
                        begin
                          j_current.set_of_rs <- ints2intervals (snd current_job_res); 
                          aux (fetch res) (j_current::job_l) (newjob_res x)
                        end
        in
          aux (fetch res) [] (newjob_res first_job) 
    in
      first_res (fetch res)


 

(* NOT USE only ONE job see save_assignS to job list assignement*)
let save_assign conn job =
  let moldable_job_id = ml2int job.moldable_id in 
    let  moldable_job_id_start_time j = 
      Printf.sprintf "(%s, %s)" moldable_job_id  (ml642int j.time_b) in
    let query_pred = 
      "INSERT INTO  gantt_jobs_predictions  (moldable_job_id,start_time) VALUES "^ (moldable_job_id_start_time job) in

(*  ignore (execQuery conn query_pred) *)
 
      let resource_to_value res_id = 
	      Printf.sprintf "(%s, %s)" moldable_job_id (ml2int res_id) in
	    let query_job_resources =
      "INSERT INTO  gantt_jobs_resources (moldable_job_id,resource_id) VALUES "^
     	(String.concat ", " (List.map resource_to_value (intervals2ints job.set_of_rs))) 
    in
      Conf.log query_pred;
      Conf.log query_job_resources;
      ignore (execQuery conn query_pred);
      ignore (execQuery conn query_job_resources)

let save_assigns conn jobs = (* TODO *)
  let  moldable_job_id_start_time j =
     Printf.sprintf "(%s, %s)" (ml2int j.moldable_id) (ml642int j.time_b) in
  let query_pred = 
    "INSERT INTO  gantt_jobs_predictions  (moldable_job_id,start_time) VALUES "^ 
     (String.concat ", " (List.map moldable_job_id_start_time jobs)) in

(*  ignore (execQuery conn query_pred) *)
 
   let job_resource_to_value j =
       let moldable_id = ml2int j.moldable_id in 
       let resource_to_value res = 
	      Printf.sprintf "(%s, %s)" moldable_id (ml2int res) in
        String.concat ", " (List.map resource_to_value (intervals2ints j.set_of_rs)) in 


	    let query_job_resources =
      "INSERT INTO  gantt_jobs_resources (moldable_job_id,resource_id) VALUES "^
     	(String.concat ",\n " (List.map job_resource_to_value jobs)) 
    in
      Conf.log query_pred;
      Conf.log query_job_resources;
      ignore (execQuery conn query_pred);
      ignore (execQuery conn query_job_resources)

let get_job_types dbh jobs =
  let h_jobs =  Hashtbl.create 1000 in
  let job_ids = List.map (fun n -> Hashtbl.add h_jobs n.jobid n; n.jobid) jobs in 
  let job_ids_str = Helpers.concatene_sep "," string_of_int job_ids in
  
  let query = "SELECT job_id, type FROM job_types WHERE types_index = 'CURRENT' AND job_id IN (" ^ job_ids_str ^ ");" in
  
  let res = execQuery dbh query in
   let add_id_types a = 
    let get s = column res s a in 
      let job = try Hashtbl.find h_jobs (not_null int2ml (get "job_id"))
      with Not_found -> failwith "get_job_type error can't find job_id" in
        job.types <- (not_null  str2ml (get "type"))::job.types in
          ignore (map res add_id_types);
          h_jobs

