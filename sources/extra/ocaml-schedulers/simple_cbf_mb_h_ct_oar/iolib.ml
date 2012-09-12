(*pp cpp -P -w *)
(* previous line is to ask OcamlMakefile to preprocess this file with cpp preprocesseur *)

(* Postgresql very sensitive ? "type = \"default\""    "type = 'default'" *)

(* preprocessor part *)

#ifdef POSTGRESQL
  #define DBD Postgresql_driver
  #define NoN
  #define NoNStr  
#else
  #define DBD Mysql_driver
  #define NoN not_null
  #define NoNStr not_null str2ml
#endif

open Int64
open DBD
open Types
open Interval
open Helpers

let max_nb_resources = 200000;;
let connect () = DBD.connect ();;
let disconnect dbh = DBD.disconnect dbh;;

(*                      *)
(* get resource from db *)
(*                      *)
let get_resource_list dbh  = 
  let query = "SELECT resource_id, network_address, state, available_upto FROM resources" in
  let res = execQuery dbh query in
  let get_one_resource a =
    { ord_r_id = NoN int_of_string a.(0); (* for use to suppport order_by *)
      resource_id = NoN int_of_string a.(0); (* resource_id *)
      network_address = NoNStr a.(1); (* network_address *)
      state = NoN rstate_of_string a.(2); (* state *)
      available_upto = NoN Int64.of_string a.(3) ;} (* available_upto *)
  in
    map res get_one_resource ;;

(*                                                                 *)
(* get resource and return from db with hierarchy information      *)
(* label of fields must be provide for scattered hierarchy support *)
(* returns:                                                        *)
(*  - flat resource list: id state networks adress                 *)
(*  - h_value_order:  hash(h_label) -> list(h_value)                *)
(*  - hierarchy_info: array(h_labels)->hash(h_values)->list(id)     *)
(*  - array ord2init_ids[r_order_by_id]=r_init_id                  *)
(*  - array init2ord_ids[r_init_id]=r_order_by_id                  *) 

let get_resource_list_w_hierarchy dbh (hy_labels: string list) scheduler_resource_order =
  (* h_value_order hash stores for each hy label the occurence order of different hy values *)
  let h_value_order = Hashtbl.create 10 in  List.iter (fun x -> Hashtbl.add h_value_order x [] ) hy_labels;
  let ord2init_ids = Array.make max_nb_resources 0 and init2ord_ids = Array.make max_nb_resources 0  in (* arrays to translate resource id intial/ordered*) 
  let i = ref 0 in (* count for ordererd resourced_id *) 

  (*let hy_id_array = List.map (fun x -> Hashtbl.create 10) hy_labels in *)
  (* list of hashs to compute scattered hierarchy *)

  let hy_ary_labels = Array.of_list hy_labels in (* hy_ary_labels array need to populate h_value_order hash*) 
  let ary = Array.make (List.length hy_labels) 0 in
  let hy_id_array = Array.map (fun x -> Hashtbl.create 10) ary in
  let query = "SELECT resource_id, network_address, state, available_upto, " ^ 
               (Helpers.concatene_sep "," id hy_labels) ^ " FROM resources ORDER BY " ^
               scheduler_resource_order in
  let res = execQuery dbh query in
  let get_one_resource a = 
     (* populate hashes of hy_id_ary array and h_value_order hash*)
      i := !i + 1;
      for var = 4 to ((Array.length a)-1) do
        let value = NoNStr a.(var) in
        let h_label = hy_ary_labels.(var-4) in
        let ordered_values = try Hashtbl.find h_value_order h_label with Not_found -> failwith ("Can't Hashtbl.find h_value_order for " ^ h_label) in
        (* test is value for this ressource this h_label is already present else add in the list*)
        if (not (List.mem value ordered_values)) then
          Hashtbl.replace h_value_order h_label (ordered_values @ [value]);
        
        let add_res_id h value = 
          let lst_value = try Hashtbl.find h value with Not_found -> [] in
            Hashtbl.replace h value (lst_value @ [!i])
        in 
          add_res_id (hy_id_array.(var-4)) value
      done;
      ord2init_ids.(!i) <- NoN int_of_string a.(0); 
      init2ord_ids.(NoN int_of_string a.(0)) <- !i;
      (* Conf.log ("i:"^ (string_of_int !i)); *)
      (* Conf.log ("rid:"^(NoN id a.(0))); *)
    { ord_r_id = !i;                                (* id resulting from order_by ordering *)
      resource_id = NoN int_of_string a.(0);        (* resource_id *)
      network_address = NoNStr a.(1);               (* network_address *)
      state = NoN rstate_of_string a.(2);           (* state *)
      available_upto = NoN Int64.of_string a.(3) ;} (* available_upto *)
  in
    ((map res get_one_resource), h_value_order, hy_id_array, ord2init_ids, init2ord_ids) ;;

(*                                              *)
(* get distinct availableupto                   *)
(* to remove, can be obtain from resources list *)
(*                                              *)

let get_group_available_uptos dbh =
  let query = "SELECT available_upto FROM resources GROUP BY available_upto" in
  let res = execQuery dbh query in 
  let get_one a = NoN Int64.of_string a.(0)  (* available_upto *)
    in
      map res get_one;;

(* get the amount of time in the suspended state of a job
   args : base, job id, time in seconds
   adapted from  OAR::IO::get_job_suspended_sum_duration
*)

let get_job_suspended_sum_duration dbh job_id now = 
  let query =  Printf.sprintf "SELECT date_start, date_stop
               FROM job_state_logs
               WHERE
                job_id = %d AND
                (job_state = 'Suspended' OR job_state = 'Resuming')" job_id in
  let res = execQuery dbh query in
    let rec summation sum next_rest = match next_rest with
      | None -> sum
      | Some a -> let date_start = NoN Int64.of_string  a.(0) and date_stop = NoN Int64.of_string  a.(1) in
                  let res_time = if  (date_stop = 0L) then sub now date_start else sub date_stop date_start in
                  if (res_time > 0L) then
                    add sum res_time
                  else
                    sum
    in
      summation 0L (fetch res);;

(*                                                                                         *)
(* get_job_list_fairsharing: retrieve jobs to schedule with important relative information *)
(*                                                                                         *)
(*  init2ord_ids need to id convertion due to order_by support                             *)

let get_job_list_fairsharing dbh default_resources queue besteffort_duration security_time_overhead fairsharing_flag fs_jobids init2ord_ids =
  let flag_besteffort = if (queue == "besteffort") then true else false in
  let jobs = Hashtbl.create 1000 in      (* Hashtbl.add jobs jid ( blabla *)
  let constraints = Hashtbl.create 10 in (* Hashtable of constraints to avoid recomputing of corresponding interval list*)

  let get_constraints j_ppt r_ppt = 
    if (j_ppt = "") && ( r_ppt = "type = 'default'" || r_ppt = "" ) then
      default_resources
    else
      let and_sql = if ((j_ppt = "") || (r_ppt = "")) then "" else " AND " in 
      let sql_cts = j_ppt ^ and_sql^ r_ppt in  
        try Hashtbl.find constraints sql_cts (* cache the result, a more general/elagant approach is to use memoize function *)
        with Not_found ->
          begin  
            let query = Printf.sprintf "SELECT resource_id FROM resources WHERE ( %s )"  sql_cts in
            let res = execQuery dbh query in 
            let get_one_resource a = init2ord_ids.(NoN int_of_string a.(0)) in (* resource_id and convert it*)
            let matching_resources = (map res get_one_resource) in 
            let itv_cts = ints2intervals matching_resources in
              Hashtbl.add constraints sql_cts itv_cts;
            itv_cts
          end  
  in 
  let query_base = Printf.sprintf "
    SELECT jobs.job_id, moldable_job_descriptions.moldable_walltime, jobs.properties,
        moldable_job_descriptions.moldable_id,  
        job_resource_descriptions.res_job_resource_type,
        job_resource_descriptions.res_job_value,
        job_resource_descriptions.res_job_order, 	
        job_resource_groups.res_group_property,
        jobs.job_user, 
        jobs.project
    FROM moldable_job_descriptions, job_resource_groups, job_resource_descriptions, jobs
    WHERE
      moldable_job_descriptions.moldable_index = 'CURRENT'
      AND job_resource_groups.res_group_index = 'CURRENT'
      AND job_resource_descriptions.res_job_index = 'CURRENT' "
  and query_end = "
      AND jobs.reservation = 'None'
      AND jobs.job_id = moldable_job_descriptions.moldable_job_id
      AND job_resource_groups.res_group_index = 'CURRENT'
      AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id
      AND job_resource_descriptions.res_job_index = 'CURRENT'
      AND job_resource_descriptions.res_job_group_id = job_resource_groups.res_group_id
      ORDER BY moldable_job_descriptions.moldable_id, job_resource_groups.res_group_id, job_resource_descriptions.res_job_order ASC;"
  in
    let query =
      if fairsharing_flag then
        query_base ^ " AND jobs.job_id IN (" ^ (Helpers.concatene_sep "," id fs_jobids) ^ ") " ^ query_end 
      else
        query_base ^ " AND jobs.state = 'Waiting' AND jobs.queue_name = '" ^ queue ^"' "^ query_end 
    in
  let res = execQuery dbh query in 

  let get_one_row a = ( 
    NoN int_of_string a.(0),                          (* job_id *)
    (if flag_besteffort then besteffort_duration else 
      NoN Int64.of_string a.(1)),                     (* moldable_walltime *)
      NoN int_of_string a.(3),                        (* moldable_id *)
      NoNStr a.(2),                                   (* properties *)
      NoNStr a.(4),                                   (* res_job_resource_type *)
      NoN int_of_string a.(5),                        (* res_job_value *)
      NoN int_of_string a.(6),                        (* res_job_order *)
      NoNStr a.(7),                                   (* res_group_property *)
      NoNStr a.(8),                                   (* job_user *)   
      NoNStr a.(9)                                    (* job_project *)
  )

  in let result = map res get_one_row in

  let rec scan_res res_query prev_job r_o r_t r_v cts jids = match res_query with
      [] -> begin
              (* complete previous job *)
              prev_job.hy_level_rqt <- r_t;
              prev_job.hy_nb_rqt <- r_v;
              prev_job.constraints <- cts;
              (* add job to hashtable *)
              Hashtbl.add jobs prev_job.jobid prev_job;
              (List.rev jids, jobs) (* return list of job_ids jobs' hashtable *)
            end 
      | row::m ->
                let (j_id,j_walltime, j_moldable_id, properties, r_type, r_value, r_order, r_properties, user, project) = row in
                if (prev_job.jobid != j_id) then (* next job *)
                  begin
                    (* complete prev job *)
                    if (prev_job.jobid !=0) then 
                      begin
                        prev_job.hy_level_rqt <- List.rev r_t;
                        prev_job.hy_nb_rqt <- List.rev r_v;
                        prev_job.constraints <- List.rev cts;
                       
         (*               Printf.printf "jobs: %s\n" (job_to_string prev_job);   *)
                        Hashtbl.add jobs prev_job.jobid prev_job
                      end;
                    (* prepare next job *)
                    let j = {
                          jobid = j_id;
                          jobstate = "";
                          moldable_id = j_moldable_id;
                          time_b = Int64.zero;
                          walltime = add j_walltime security_time_overhead; (* add security_time_overhead *)
                          types = [];
                          constraints = [];
                          hy_level_rqt = [];
                          hy_nb_rqt = [];
                          set_of_rs = [];
                          user = user;
                          project = project;
                      } in
                    scan_res m j r_order [[r_type]] [[r_value]] [(get_constraints properties r_properties)] (j_id::jids)
                  end                    
                else
                  begin (* same job *)
                    if r_order = 0 then  (*new resource request*)
                      scan_res m prev_job r_order ([r_type]::r_t) ([r_value]::r_v) ((get_constraints properties r_properties)::cts) jids
    
                    else (*one hierarchy requirement to resource request*)
                      scan_res m prev_job r_order (((List.hd r_t) @ [r_type])::(List.tl r_t))
                                           (((List.hd r_v) @ [r_value])::(List.tl r_v))
                                           cts
                                           jids
                  end
  in  scan_res result {jobid=0;jobstate="";moldable_id =0;time_b=Int64.zero;walltime=Int64.zero; (* the job is used *)
                      types=[];constraints=[];hy_level_rqt=[];hy_nb_rqt=[]; set_of_rs =[];
                      user="";project=""} 
               0 [] [] [] [];; 


(*                                                                            *)
(* get_scheduled_jobs_no_suspend : retrieve already previously scheduled jobs *)
(* OAR::IO::get_gantt_scheduled_jobs            in perl version               *)
(* without suspend jobs support                                               *)

let get_scheduled_jobs_no_suspend dbh security_time_overhead =
   let query = "SELECT j.job_id, g2.start_time, m.moldable_walltime, g1.resource_id, j.queue_name, j.state, j.job_user, j.job_name,m.moldable_id,j.suspended, j.project
      FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, moldable_job_descriptions m, jobs j
      WHERE
        m.moldable_index = 'CURRENT'
        AND g1.moldable_job_id = g2.moldable_job_id
        AND m.moldable_id = g2.moldable_job_id
        AND j.job_id = m.moldable_job_id
      ORDER BY j.start_time, j.job_id;" in

  let res = execQuery dbh query in
    let first_res = function
      | None -> []
      | Some first_job -> 
 (*   if (not (first_res = None)) then *)
          let newjob_res a = 
(* function
           | None -> failwith "pas glop"  
           | Some job_res -> *)
              let j_id = NoN int_of_string a.(0)           (* job_id *)
              and j_state =  NoNStr a.(5)                  (* job state *)
              and j_walltime = NoN Int64.of_string a.(2)   (* moldable_walltime *)
              and j_moldable_id = NoN int_of_string a.(8)  (* moldable_id *)
              and j_start_time = NoN Int64.of_string a.(1) (* start_time *)
              and j_nb_res = NoN int_of_string a.(3)       (* resource_id *)
              and j_user =  NoNStr a.(4)                   (* job_user *)
              and j_project = NoNStr a.(9) in              (* project *)
            
                ( {
                  jobid = j_id;
                  jobstate = j_state;
                  moldable_id = j_moldable_id;
	                time_b = j_start_time;
	                walltime = add j_walltime security_time_overhead; (* add security_time_overhead *)
                  types = [];
                  constraints = [];  (* constraints irrelevant fortest_container already scheduled job *)
                  hy_level_rqt = []; (*  *)
                  hy_nb_rqt = [];    (*  *)
                  set_of_rs = [];    (* will be set when all resource_id are fetched *)
                  user = j_user;
                  project = j_project;
                }, 
                  [j_nb_res]) 
       in

        let get_job_res a =
          let j_id = NoN int_of_string a.(0)         (* job_id *)
          and j_nb_res =  NoN int_of_string a.(3) in (*resource_id *)
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
(*                                                                *)
(* get_scheduled_jobs: retrieve already previously scheduled jobs *)
(* OAR::IO::get_gantt_scheduled_jobs in perl version              *)
(* with suspend jobs support                                      *)
(* TODO Remove used field in query ??? *)

let get_scheduled_jobs dbh init2ord_ids available_suspended_res_itvs security_time_overhead now =
   let query = "SELECT j.job_id, g2.start_time, m.moldable_walltime, g1.resource_id, j.queue_name, j.state, j.job_user, j.job_name,m.moldable_id,j.suspended, j.project
      FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, moldable_job_descriptions m, jobs j
      WHERE
        m.moldable_index = 'CURRENT'
        AND g1.moldable_job_id = g2.moldable_job_id
        AND m.moldable_id = g2.moldable_job_id
        AND j.job_id = m.moldable_job_id
        ORDER BY j.start_time, j.job_id;" in
(*        ORDER BY j.start_time; in *)

  let res = execQuery dbh query in
    let first_res = function
      | None -> []
      | Some first_job -> 
          let newjob_res a = 
              let j_id = NoN int_of_string a.(0)                   (* job_id *)
              and  j_walltime_init  = NoN Int64.of_string a.(2) in (* moldable_walltime *)
                let j_start_time = NoN Int64.of_string a.(1)       (* start_time *) 
                and j_walltime =
                  if ( NoNStr a.(9)) == "YES" then      (* take into account suspended time *)
                    add j_walltime_init (get_job_suspended_sum_duration dbh j_id now)
                  else
                    j_walltime_init
                and j_state = NoNStr a.(5)                          (* job state *)
                and j_moldable_id = NoN int_of_string a.(8)         (* moldable_id *)
                and j_r_id = init2ord_ids.(NoN int_of_string a.(3)) (* resource_id translated to order_by_resource_id *)
                and j_user =  NoNStr a.(4)                          (* job_user *)
                and j_project = NoNStr a.(9) in                     (* project *)
                ( {
                  jobid = j_id;
                  jobstate =  j_state;
                  moldable_id = j_moldable_id;
	                time_b = j_start_time;
	                walltime = add j_walltime security_time_overhead; (* add security_time_overhead *)
                  types = [];
                  constraints = [];                                 (* constraints irrelevant fortest_container already scheduled job *)
                  hy_level_rqt = [];                                (*  *)
                  hy_nb_rqt = [];                                   (*  *)
                  set_of_rs = [];                                   (* will be set when all resource_id are fetched *)
                  user = j_user;
                  project = j_project;
                }, 
                  [j_r_id]) 
       in

        let get_job_res a =
          let j_id = NoN int_of_string a.(0)                     (* job_id *)
          and j_r_id = init2ord_ids.(NoN int_of_string a.(3)) in (* resource_id translated to order_by_resource_id *)
          (j_id, j_r_id)
        in   
      let job_itv_res_setting state job_res =
          let  set_res =  ints2intervals job_res in
          if (state == "Suspended") then
          (* TODO Remove resources of the type specified in SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE *)
             inter_intervals set_res available_suspended_res_itvs
          else
            set_res
      in
      let rec aux result job_l current_job_res = match result with
        | None ->   let job = fst current_job_res in 
                      job.set_of_rs <- job_itv_res_setting job.jobstate (snd current_job_res);
(* TODO VERIFY-TEST_overlapping_bug                     List.rev (job::job_l)  *)
                        job::job_l
                      
        | Some x -> let j_r = get_job_res x in 
                    let j_current = fst current_job_res in
                      if ((fst j_r) = j_current.jobid) then
                        begin 
                          aux (fetch res) job_l (j_current, (snd j_r) :: (snd current_job_res))
                        end 
                      else
                        begin
                          j_current.set_of_rs <- job_itv_res_setting j_current.jobstate (snd current_job_res); 
                          aux (fetch res) (j_current::job_l) (newjob_res x)
                        end
        in
          aux (fetch res) [] (newjob_res first_job) 
    in
      first_res (fetch res)

(*                                             *)
(* Save ONE job assign                         *)
(*                                             *)
let save_assignt_one_job dbh job =
  let moldable_job_id = string_of_int job.moldable_id in 
    let  moldable_job_id_start_time j = 
(*      Printf.sprintf "(%s, %s)" moldable_job_id  (Int64.to_string j.time_b) in *)
      "(" ^ moldable_job_id ^ "," ^ (Int64.to_string j.time_b) ^ ")" in
    let query_pred = 
      "INSERT INTO  gantt_jobs_predictions  (moldable_job_id,start_time) VALUES "^ (moldable_job_id_start_time job) in

(*  ignore (execQuery conn query_pred) *)
 
      let resource_to_value res_id = 
	      (* Printf.sprintf "(%s, %s)" moldable_job_id (ml2int res_id) in *)
        "(" ^ moldable_job_id ^ "," ^ (string_of_int res_id ) ^ ")" in

	    let query_job_resources =
      "INSERT INTO  gantt_jobs_resources (moldable_job_id,resource_id) VALUES "^
     	(String.concat ", " (List.map resource_to_value (intervals2ints job.set_of_rs))) 
    in
(*
      Conf.log query_pred;
      Conf.log query_job_resources;
*)
      ignore (execQuery dbh query_pred);
      ignore (execQuery dbh query_job_resources)

(*                                                                                           *)
(* Save jobs assignements into 2 SQL request                                                 *)
(* Be careful this does not scale after beyond 1 millions of  (moldable_job_id,start_time)   *)
(*                                                                                           *)
let save_assigns_2_rqts conn jobs ord2init_ids=
  let  moldable_job_id_start_time j =
    (* Printf.sprintf "(%s, %s)" (ml2int j.moldable_id) (ml642int j.time_b) in *)
    "(" ^ (string_of_int j.moldable_id) ^ "," ^ (Int64.to_string j.time_b) ^ ")" in

  let query_pred = 
    "INSERT INTO  gantt_jobs_predictions  (moldable_job_id,start_time) VALUES "^ 
     (String.concat ", " (List.map moldable_job_id_start_time jobs)) in

(*  ignore (execQuery conn query_pred) *)
 
    let job_resource_to_value j =
      let moldable_id = string_of_int j.moldable_id in 
      let resource_to_value res = 
	      (* Printf.sprintf "(%s, %s)" moldable_id (ml2int res) in *)
        "(" ^ moldable_id ^ "," ^ (string_of_int ord2init_ids.(res)) ^ ")" in
        String.concat ", " (List.map resource_to_value (intervals2ints j.set_of_rs)) in 

	    let query_job_resources =
      "INSERT INTO  gantt_jobs_resources (moldable_job_id,resource_id) VALUES "^
     	(String.concat ",\n " (List.map job_resource_to_value jobs)) 
    in
(*
      Conf.log query_pred;
      Conf.log query_job_resources;
*)
      ignore (execQuery conn query_pred);
      ignore (execQuery conn query_job_resources)


(*                        *)
(* Save jobs' assignemnts *)
(*                        *)
let save_assigns dbh jobs ord2init_ids =
(*  List.iter (fun x -> save_assignt_one_job dbh x) jobs;; *)
  save_assigns_2_rqts dbh jobs ord2init_ids;;


(*                                                  *)
(** retrieve job_type for all jobs in the hashtable *)
(*                                                  *)
let get_job_types dbh job_ids h_jobs =  
  let job_ids_str = Helpers.concatene_sep "," string_of_int job_ids in
  let query = "SELECT job_id, type FROM job_types WHERE types_index = 'CURRENT' AND job_id IN (" ^ job_ids_str ^ ");" in
  
  let res = execQuery dbh query in
   let add_id_types a = 
      let job = try Hashtbl.find h_jobs ( NoN int_of_string a.(0)) (* job_id *)
        with Not_found -> failwith "get_job_type error can't find job_id" in
        let jt0 = Helpers.split "=" (NoNStr a.(1)) in (* type *)

        let jt = if ((List.length jt0) = 1) then (List.hd jt0)::[""] else jt0 in  
        job.types <- ((List.hd jt), (List.nth jt 1))::job.types in
          ignore (map res add_id_types);;

(*                                                                            *)
(* retrieve job_type for all jobs in the hashtable                            *)
(* TODO factorize with get_job_types ?? change simple_cbf**.ml ??? REMOVE ??? *)
(*                                                                            *)
let get_job_types_hash_ids dbh jobs =
  let h_jobs =  Hashtbl.create 1000 in
  let job_ids = List.map (fun n -> Hashtbl.add h_jobs n.jobid n; n.jobid) jobs in 

  let job_ids_str = Helpers.concatene_sep "," string_of_int job_ids in
  
  let query = "SELECT job_id, type FROM job_types WHERE types_index = 'CURRENT' AND job_id IN (" ^ job_ids_str ^ ");" in
  
  let res = execQuery dbh query in
    let add_id_types a =
      let job = try Hashtbl.find h_jobs (NoN int_of_string a.(0)) (* job_id *)
        with Not_found -> failwith "get_job_type error can't find job_id" in
        let jt0 = Helpers.split "=" (NoNStr a.(1)) in (* type *)

        let jt = if ((List.length jt0) = 1) then (List.hd jt0)::[""] else jt0 in 
        job.types <- ((List.hd jt), (List.nth jt 1))::job.types in
          ignore (map res add_id_types);

  (*  Conf.log ("length h_jobs:"^(string_of_int (Hashtbl.length h_jobs))); *)
  (h_jobs, job_ids);;

(* retrieve jobs dependencies *)
(* return an hashtable, key = job_id, value = list of required jobs *)
let get_current_jobs_dependencies dbh =
  let h_jobs_dependencies =  Hashtbl.create 100 in
  let query = "SELECT job_id, job_id_required FROM job_dependencies WHERE job_dependency_index = 'CURRENT'" in
  let res = execQuery dbh query in
  let get_one a =
    let job_id = NoN int_of_string a.(0) in (* job_id *)
    let job_id_required = NoN int_of_string a.(1) in (* job_id_required *)

    let dependencies = try Hashtbl.find h_jobs_dependencies job_id with Not_found -> (Hashtbl.add h_jobs_dependencies job_id []; []) in
    Hashtbl.replace h_jobs_dependencies job_id (job_id_required::dependencies) in
      ignore (map res get_one);
      h_jobs_dependencies;;

(*                                                                         *)
(* retrieve status of required jobs of jobs with dependencies              *)
(* return an hashtable, key = job_id, value = list of required jobs_status *)

let get_current_jobs_required_status dbh =
  let h_jobs_required_status =  Hashtbl.create 100 in

(* TODO to simplify ??? / remove unsed fields *)
  let query = " SELECT jobs.job_id, jobs.state, jobs.job_type, jobs.exit_code, jobs.start_time, moldable_job_descriptions.moldable_walltime
                FROM jobs,job_dependencies, moldable_job_descriptions
                WHERE job_dependencies.job_dependency_index = 'CURRENT' 
                AND jobs.job_id = job_dependencies.job_id_required
                AND jobs.job_id = moldable_job_descriptions.moldable_job_id
                GROUP BY jobs.job_id;" in
  let res = execQuery dbh query in
  let get_one a =
    let j_id = NoN int_of_string a.(0) (* job_id *) 
    and j_state = NoNStr a.(1) (* state *)
    and j_jtype = NoNStr a.(2) (* job_type *)
    and j_exit_code = NoN int_of_string a.(3) (* exit_code *)

(*
    and j_start_time = not_null int642ml (get "start_time")
    and j_walltime = not_null int642ml (get "moldable_walltime")
*)
      in (j_id, {
(*                  jr_id = j_id; *)
                  jr_state = j_state;
                  jr_jtype = j_jtype;
                  jr_exit_code = j_exit_code;
(*
                  jr_start_time = j_start_time;
                  jr_walltime = j_walltime;
*)
                })
    in 
    let results = map res get_one in
      ignore ( List.iter (fun x -> Hashtbl.add h_jobs_required_status (fst x) (snd x) ) results);
      h_jobs_required_status;;
(*    
 set_job_message
 sets the message field of the job of id passed in parameter
 parameters : dbh, job_id, message
 return value : /
 side effects : changes the field message of the job in the table Jobs
*)
let set_job_message dbh job_id message = 
  let query =  Printf.sprintf "UPDATE jobs SET message = '%s' WHERE job_id = %d" message job_id in
    ignore (execQuery dbh query)

(*
  set_job_scheduler_info
  sets the scheduler_info field of the job of id passed in parameter
  parameters : dbh, job_id, message
  return value : /
*)
let set_job_scheduler_info dbh job_id message = 
  let query =  Printf.sprintf "UPDATE jobs SET scheduler_info = '%s' WHERE job_id = %d" message job_id in
    ignore (execQuery dbh query)

let set_job_and_scheduler_message dbh job_id message =  
  let query =  Printf.sprintf "UPDATE jobs SET  message = '%s', scheduler_info = '%s',   WHERE job_id = %d" message message job_id in
    ignore (execQuery dbh query)

let set_job_and_scheduler_message_range dbh job_ids message =
  let job_ids_str = Helpers.concatene_sep "," string_of_int job_ids in
  let query =  Printf.sprintf "UPDATE jobs SET  message = '%s', scheduler_info = '%s',   WHERE IN ('%s');" message message job_ids_str in
    ignore (execQuery dbh query)

(*
 get_job_current_resources
 returns the list of resources associated to the job passed in parameter
 parameters : base, jobid
 return value : list of resources
*)

let get_job_current_resources dbh job_id no_type_lst =

  let partial_query = function 
    | None -> Printf.sprintf "FROM assigned_resources
                    WHERE 
                        assigned_resources.assigned_resource_index = 'CURRENT' AND
                        assigned_resources.moldable_job_id = %d" job_id

    | Some x -> let str_t_lst = String.concat "," x in
              Printf.sprintf "FROM assigned_resources,resources
                    WHERE 
                        assigned_resources.assigned_resource_index = 'CURRENT' AND
                        assigned_resources.moldable_job_id = %d AND
                        resources.resource_id = assigned_resources.resource_id AND
                        resources.type NOT IN ('%s')" job_id str_t_lst
  in 
  let query = "SELECT assigned_resources.resource_id " ^ (partial_query no_type_lst) ^ 
                 "ORDER BY assigned_resources.resource_id ASC" 
  in
  let res = execQuery dbh query in
    map res (function a -> NoN int_of_string a.(0));;
 
(*                   *)
(* Fairsharing Stuff *)
(*                   *)

(*                                                               *)
(* get_sum_accounting_window                                     *)
(* Adapted form  OAR::IO::get_sum_accounting_window              *)
(* return two value karma_sum_time_asked and karma_sum_time_used *)
(*                                                               *)

let get_sum_accounting_window dbh queue start_window stop_window =
  let query = Printf.sprintf " SELECT consumption_type, SUM(consumption)
                               FROM accounting
                               WHERE
                                   queue_name = '%s' AND
                                   window_start >= %Lu AND
                                   window_start < %Lu
                               GROUP BY consumption_type" queue start_window stop_window 
  in
  let res = execQuery dbh query in
  let get_one a =  (NoNStr a.(0), NoN float_of_string a.(1)) in
  let results = map res get_one in

  let rec scan_results r asked used = match r with
    | []   -> (asked, used)
    | x::m -> let extract = function 
                | ("ASKED", a) -> scan_results m a used
                | ("USED", u)  -> scan_results m asked u
                | (_,_)        -> failwith "Consumption type is not supported: " 
              in extract x     
  in scan_results results 1.0 1.0 ;;

(*                                                      *)
(*  get_sum_accounting_for_param                        *)
(* Adapted form  OAR::IO:: get_sum_accounting_for_param *)
(* return ...                                           *)

let get_sum_accounting_for_param dbh queue param_name start_window stop_window =
  let karma_used = Hashtbl.create 1000 and karma_asked = Hashtbl.create 1000 in  
  let query = Printf.sprintf "SELECT %s,consumption_type, SUM(consumption)
                                FROM accounting
                                WHERE
                                    queue_name = '%s' AND
                                    window_start >= %Lu AND
                                    window_start < %Lu
                                GROUP BY %s,consumption_type" param_name queue start_window stop_window param_name
  in
  let res = execQuery dbh query in
  let get_one a = (NoNStr a.(1), NoNStr a.(0), NoN float_of_string a.(2)) in
  let results = map res get_one in

  let rec scan_results r  = match r with
    | []   -> (karma_asked, karma_used)
    | x::m -> let extract = function 
                | ("ASKED", k, v) ->  begin 
                                        Hashtbl.add karma_asked k v; 
                                        scan_results m
                                      end  
                | ("USED", k, v)  ->  begin 
                                        Hashtbl.add karma_asked k v; 
                                        scan_results m
                                      end  
                | (_,_,_)        -> failwith ("Consumption type is not supported (with param) : " ^ param_name)
              in extract x     
  in scan_results results ;;

(*                                                                *)
(* get_limited_by_user_job_ids_to_schedule                        *)
(* Adapted form  OAR::IO::get_fairsharing_jobs_to_schedule        *)
(* return job indices with limited number of job by user          *)
(*                                                                *)
let get_limited_by_user_job_ids_to_schedule dbh queue limit =
  (* get a limit number of job ids for a given user *)
  let get_job_ids_user user =
    let query = Printf.sprintf "
      SELECT *
      FROM jobs
      WHERE
        state = 'Waiting'
        AND reservation = 'None'
        AND queue_name = '%s'
        AND job_user = '%s'
        ORDER BY job_id
        LIMIT %s;"
    queue user limit in
  let res = execQuery dbh query in
  (* let get_one a = NoNStr a.(0) in *)
    map res (function a ->  NoNStr a.(0) )  
  in
  let get_waiting_users =  
    (* get all users with a waiting job *)
    let query = Printf.sprintf "
      SELECT distinct(job_user)
      FROM jobs
      WHERE
        state = 'Waiting'
        AND reservation = 'None'
        AND queue_name = '%s';"
      queue in
    let res = execQuery dbh query in
      map res (function a ->  NoNStr a.(0) )
  in 
  List.flatten (List.map get_job_ids_user get_waiting_users)



