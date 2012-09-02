open Types
open Interval
open Conf
open Simple_cbf_mb_h_ct
(*
TODO

1) Add security_time_overhead = SCHEDULER_JOB_SECURITY_TIME | 60
1.1) Suspend / SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE 
1.2) Fairsharing
1.0.1) Test SCHEDULER_JOB_SECURITY_TIME in container context
3) Besteffort (need resource reverse order => not sure ?)
4) Message scheduler/job (same and more than perl scheduler) (* need to be optimize vectorize*)
8) export OARCONFFILE=oar.conf as in perl version
9) to test: resources types

Done but not tested
--------------------
1) Add security_time_overhead = SCHEDULER_JOB_SECURITY_TIME | 60

*)

(*
To be supported:
----------------
* SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE
* SCHEDULER_RESOURCES_ALWAYS_ASSIGNED_TYPE (???)

Not supported:
--------------
* SCHEDULER_GANTT_HOLE_MINIMUM_TIME
* SCHEDULER_RESOURCE_ORDER
* SCHEDULER_NB_PROCESSES
* SCHEDULER_TIMEOUT
*)

let besteffort_duration = Int64.of_int (5*60)

(*
>> 2**31 => 2147483648
>> 2**31 -1 => 2147483647
*)

let max_time = 2147483648L
let max_time_minus_one = 2147483647L
(* Constant duration time of a besteffort job *)
let besteffort_duration = 300L

let hy_labels = ["resource_id";"network_address";"cpu";"core"] (*TODO: get_conf*)

(*                                                                                                                                   *)
(* for TOKEN feature                                                                                                                *)
(* SCHEDULER_TOKEN_SCRIPTS="{ fluent => '/usr/local/bin/check_fluent.sh arg1 arg2', soft2 => '/usr/local/bin/check_soft2.sh arg1' }" *)
(*                                                                                                                                   *)
let token_scripts =
  if Conf.test_key("SCHEDULER_TOKEN_SCRIPTS") then
    try Conf.str_perl_hash_to_pairs (Conf.get_value "SCHEDULER_TOKEN_SCRIPTS")
    with _ -> failwith "Syntax error in configuration file: SCHEDULER_TOKEN_SCRIPTS"
  else
    []

(*                             *)
(* Karma and Fairsharing stuff *)
(*                             *)

(* test if Fairsharing  is enabled*)
let fairsharing_flag = Conf.test_key("FAIRSHARING_ENABLED") 
let fairsharing_nb_job_limit = Conf.get_default_value "SCHEDULER_FAIRSHARING_MAX_JOB_PER_USER" "30"

let karma_window_size = Int64.of_int ( 3600 * 30 * 24 ) (* 30 days *)
(* defaults values for fairsharing *)
let k_proj_targets = "{default => 21.0}"
let k_user_targets = "{default => 22.0}"
let k_coeff_proj_consumption = "0"
let k_coeff_user_consumption = "1"
let k_karma_coeff_user_asked_consumption = "1"
(* get fairsharing config if any *)
let karma_proj_targets = Conf.str_perl_hash_to_pairs_w_convert (Conf.get_default_value "SCHEDULER_FAIRSHARING_PROJECT_TARGETS" k_proj_targets) float_of_string_e
let karma_user_targets = Conf.str_perl_hash_to_pairs_w_convert (Conf.get_default_value "SCHEDULER_FAIRSHARING_USER_TARGETS" k_user_targets) float_of_string_e
let karma_coeff_proj_consumption = float_of_string_e (Conf.get_default_value "SCHEDULER_FAIRSHARING_COEF_PROJECT" k_coeff_proj_consumption) 
let karma_coeff_user_consumption = float_of_string_e (Conf.get_default_value "SCHEDULER_FAIRSHARING_COEF_USER" k_coeff_user_consumption) 
let karma_coeff_user_asked_consumption = float_of_string_e (Conf.get_default_value "SCHEDULER_FAIRSHARING_COEF_USER_ASK" k_karma_coeff_user_asked_consumption)

(*                                                     *)
(* Sort jobs accordingly to karma value (fairsharing)  *)
(*                                                     *)
let jobs_karma_sorting dbh queue now karma_window_size jobs_ids h_jobs =
  let start_window = Int64.sub now karma_window_size and stop_window = now in
    let karma_sum_time_asked, karma_sum_time_used = Iolib.get_sum_accounting_window dbh queue start_window stop_window
    and karma_projects_asked, karma_projects_used = Iolib.get_sum_accounting_for_param dbh queue "accounting_project" start_window stop_window
    and karma_users_asked, karma_users_used       = Iolib.get_sum_accounting_for_param dbh queue "accounting_user" start_window stop_window 
    in
      let karma j = let job = try Hashtbl.find h_jobs j  with Not_found -> failwith "Karma: not found job" in
        let user = job.user and proj = job.project in
        let karma_proj_used_j  = try Hashtbl.find karma_projects_used proj  with Not_found -> 0.0
        and karma_user_used_j  = try Hashtbl.find karma_users_used user  with Not_found -> 0.0
        and karma_user_asked_j = try Hashtbl.find karma_users_asked user  with Not_found -> 0.0
        (* TODO test *)
        and karma_proj_target =  try List.assoc proj karma_proj_targets with Not_found -> 0.0 (* TODO  verify in perl 0 also ? *)
        and karma_user_target = (try List.assoc user karma_user_targets with Not_found -> 0.0  ) /. 100.0 (* TODO   verify in perl 0 also ? *)
        in
          karma_coeff_proj_consumption *. ((karma_proj_used_j /. karma_sum_time_used) -. (karma_proj_target /. 100.0)) +.
          karma_coeff_user_consumption *. ((karma_user_used_j /. karma_sum_time_used) -. (karma_user_target /. 100.0)) +.
          karma_coeff_user_asked_consumption *. ((karma_user_asked_j /. karma_sum_time_asked) -. (karma_user_target /. 100.0))
      in
      let kompare x y = let kdiff = (karma x) -. (karma y) in if kdiff = 0.0 then 0 else if kdiff > 0.0 then 1 else -1 in
        List.sort kompare jobs_ids;;

(*               *)
(* Suspend stuff *)
(*               *)

(* TODO: to finish for SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE support
my $sched_available_suspended_resource_type_tmp = get_conf("SCHEDULER_AVAILABLE_SUSPENDED_RESOURCE_TYPE");
if (!defined($sched_available_suspended_resource_type_tmp)){
    push(@Sched_available_suspended_resource_type, "default");
}else{
    @Sched_available_suspended_resource_type = split(" ",$sched_available_suspended_resource_type_tmp);
}
*)

let argv = if (Array.length(Sys.argv) > 2) then
      (Sys.argv.(1), (Int64.of_string Sys.argv.(2)))
    else
      ("default", Int64.of_float (Unix.time ()))

(*                                                                                *)
(* Determine Global Resource Intervals and Initial Slot                           *)
(* with or without resource availabilty (field available_upto in resources table) *)
(*                                                                                *)

let resources_init_slots_determination dbh now potential_resources =
  let flag_wake_up_cmd = Conf.test_key("SCHEDULER_NODE_MANAGER_WAKE_UP_CMD") ||
                        (((compare (Conf.get_default_value "ENERGY_SAVING_INTERNAL" "no") "yes")==0) && Conf.test_key("ENERGY_SAVING_NODE_MANAGER_WAKE_UP_CMD"))
  in 
    
    if flag_wake_up_cmd then
      (*                                                                                                             *)
      (* generate initial slot with no dead and suspected resources and with resources (nodes) which can be waked up *)
      (*                                                                                                             *)
    begin
      Conf.log "Energy Saving and Wakeup Mode are enabled";
      let hash_available_upto_by_resources =  Hashtbl.create 10 in
      let hash_available_upto_by_resources_populate r =
          let res_lst = try Hashtbl.find hash_available_upto_by_resources r.available_upto
                        with Not_found -> Hashtbl.add hash_available_upto_by_resources r.available_upto [r.ord_r_id];[]
                        in
                          match res_lst with
                             [] -> ()
                            | x -> Hashtbl.replace hash_available_upto_by_resources r.available_upto (x @ [r.ord_r_id]) 
      in
      let resources = List.filter (fun n -> if (n.state = Alive) || (n.state = Absent) then
                                              begin 
                                                hash_available_upto_by_resources_populate n; 
                                                true
                                              end 
                                            else 
                                              false
                                  )
                                  potential_resources in

        let resource_intervals = 
          if ((List.length resources) = 0) then
            begin
              Conf.log "none available ressources for scheduling any jobs"; exit 0
            end
          else
            ints2intervals (List.map (fun n -> n.ord_r_id) resources) 
        in                     
        (* create corresponding job from available_up parameter of resource *) 
        let pseudo_job_av_upto a_upto res_itv =
          { jobid=0;
            jobstate="";
            moldable_id=0;
            time_b = if (a_upto<now) then now else a_upto;
            (* walltime = Int64.sub max_time_minus_one a_upto; *)
            walltime = if (a_upto<now) then (Int64.sub max_time_minus_one now) else (Int64.sub max_time_minus_one a_upto);
            types = [];
            constraints = [];
            hy_level_rqt = [];
            hy_nb_rqt = [];
            set_of_rs = res_itv;
            user = "";
            project = "";
          } 
          in
        (* create pseudo_jobs from hastable which containts resources' id by distinct available upto *) 
        let pseudo_jobs_resources_available_upto =  Hashtbl.fold (fun avail_upto r_set acc -> 
            if (avail_upto < max_time_minus_one)   then
               (pseudo_job_av_upto avail_upto (ints2intervals r_set)) :: acc 
            else 
              acc
           ) hash_available_upto_by_resources []
        in
        (* generate initial slot with no dead and suspected resources and with resources (nodes) which can be waked up *)
        let slot_init = {time_s = now; time_e = max_time; set_of_res = resource_intervals} in
        let slots_init_available_upto_resources = split_slots_prev_scheduled_jobs [slot_init] pseudo_jobs_resources_available_upto in
          (resource_intervals,slots_init_available_upto_resources)
    end
  else
      let resources = List.filter (fun n -> n.state = Alive) potential_resources in
      let resource_intervals = ints2intervals (List.map (fun n -> n.ord_r_id) resources) in
        (resource_intervals,[{time_s = now; time_e = max_time; set_of_res = resource_intervals}])

(*               *)
(* Main function *)
(*               *)
let _ = 
	try
		Conf.log "Starting";

    let (queue,now) = argv in
    let security_time_overhead = Int64.of_string  (Conf.get_default_value "SCHEDULER_JOB_SECURITY_TIME" "60") in   (* int no for  ? *)
		let conn = let r = Iolib.connect () in at_exit (fun () -> Iolib.disconnect r); r in
    (* retreive ressources, hierarchy_info to convert to hierarchy_level, array to translate r_id to/from initial order and sql order_by order *)
      let (potential_resources, hierarchy_info, ord2init_ids, init2ord_ids)  = Iolib.get_resource_list_w_hierarchy conn hy_labels "scheduler_priority ASC, state_num ASC, available_upto DESC, suspended_jobs ASC, network_address DESC, resource_id ASC" in
      (* obtain hierarchy_levels from hierarchy_info given by get_resource_list_w_hierarchy *)
      let hierarchy_levels = Hierarchy.hy_iolib2hy_level hierarchy_info hy_labels in
      let h_slots = Hashtbl.create 10 in
	    (* Hashtbl.add h_slots 0 [slot_init]; *)
      let  (resource_intervals,slots_init_available_upto_resources) = resources_init_slots_determination conn now potential_resources in
        Hashtbl.add h_slots 0 slots_init_available_upto_resources;  
      
  		let (waiting_j_ids,h_waiting_jobs) =
        if fairsharing_flag then
          let limited_job_ids = Iolib.get_limited_by_user_job_ids_to_schedule conn queue fairsharing_nb_job_limit in
          Iolib.get_job_list_fairsharing  conn resource_intervals queue besteffort_duration security_time_overhead fairsharing_flag limited_job_ids
        else
          Iolib.get_job_list_fairsharing  conn resource_intervals queue besteffort_duration security_time_overhead fairsharing_flag []
      in (* TODOfalse -> alive_resource_intervals, must be also filter by type-default !!!  Are-you sure ??? *)
      Conf.log ("job waiting ids: "^ (Helpers.concatene_sep "," string_of_int waiting_j_ids));

      if (List.length waiting_j_ids) > 0 then (* Jobs to schedule ?*)
        begin
          
          (* get types attributs of wating jobs *)
          ignore (Iolib.get_job_types conn waiting_j_ids h_waiting_jobs);
          
          (* fill slots with prev scheduled jobs  *)
          let prev_scheduled_jobs = Iolib.get_scheduled_jobs conn init2ord_ids [] security_time_overhead now in (* TODO available_suspended_res_itvs *)
          if not ( prev_scheduled_jobs = []) then
            let (h_prev_scheduled_jobs_types, prev_scheduled_job_ids_tmp) = Iolib.get_job_types_hash_ids conn prev_scheduled_jobs in
            let prev_scheduled_job_ids =
              if queue != "besteffort" then
                (* exclude besteffort jobs *)
                let besteffort_mem_remove job_id = 
                  let test_bt = List.mem_assoc "besteffort" ( try Hashtbl.find h_prev_scheduled_jobs_types job_id 
                                                              with Not_found -> failwith "Must no failed here: besteffort_mem").types in
                                                              if test_bt then Hashtbl.remove  h_prev_scheduled_jobs_types job_id else ();
                                                              test_bt  
                  in  
                    List.filter (fun n -> not (besteffort_mem_remove n)) prev_scheduled_job_ids_tmp
 (*               Conf.log ("Previous Scheduled jobs no besteffort:\n"^  (Helpers.concatene_sep "\n\n" job_to_string prev_scheduled_jobs_no_bt) ); *)
              else
                prev_scheduled_job_ids_tmp
            in
             
            (* display previous scheduled jobs 
            Hashtbl.iter (fun k v -> printf "prev job: %s,  %s\n" k ) h_prev_scheduled_jobs_types; 
            *)
            (* Conf.log ("length h_slots:"^(string_of_int (Hashtbl.length h_slots))); *)
            (* 
            let slots_with_scheduled_jobs = try Hashtbl.find h_slots 0 with  Not_found -> failwith "Can't slots #0" in 
            Conf.log ("slots_with_scheduled_jobs_before #0:\n  " ^ (Helpers.concatene_sep "\n   " slot_to_string slots_with_scheduled_jobs));
         
            Conf.log ("length h_prev_scheduled_jobs_types:"^(string_of_int (Hashtbl.length h_prev_scheduled_jobs_types)));
            *)
             set_slots_with_prev_scheduled_jobs h_slots h_prev_scheduled_jobs_types prev_scheduled_job_ids security_time_overhead;

            (*             
             let slots_with_scheduled_jobs = try Hashtbl.find h_slots 0 with  Not_found -> failwith "Can't slots #0" in 
               Conf.log ("slots_with_scheduled_jobs after #0:\n  " ^ (Helpers.concatene_sep "\n   " slot_to_string slots_with_scheduled_jobs));
            *)  

          else ();

          Conf.log "go to make a schedule";

          (* get jobs' dependencies information *) 
          let h_jobs_dependencies = Iolib.get_current_jobs_dependencies conn    in
          let h_req_jobs_status   = Iolib.get_current_jobs_required_status conn in

          let all_ordered_waiting_j_ids =
            if fairsharing_flag then
              (* ordering jobs indexes accordingly to fairsharing functions *) 
              jobs_karma_sorting conn queue now karma_window_size waiting_j_ids h_waiting_jobs 
            else
              waiting_j_ids
            in
          let ordered_waiting_j_ids =
            if Conf.test_key("MAX_JOB_PER_SCHEDULING_ROUND") then
              begin
                Conf.log ("MAX_JOB_PER_SCHEDULING_ROUND: " ^  (Conf.get_value "MAX_JOB_PER_SCHEDULING_ROUND"));
                fst (Helpers.split_at all_ordered_waiting_j_ids (int_of_string  (Conf.get_value "MAX_JOB_PER_SCHEDULING_ROUND")))
              end
            else
              all_ordered_waiting_j_ids
            in
          (*                                                               *)
          (* now compute an assignement for waiting jobs - MAKE A SCHEDULE *)
          (*                                                               *)
          let (assignement_jobs, noscheduled_jids) = 
            schedule_id_jobs_ct_dep h_slots h_waiting_jobs hierarchy_levels h_jobs_dependencies h_req_jobs_status ordered_waiting_j_ids security_time_overhead
          in
            Conf.log ((Printf.sprintf "Queue: %s, Now: %s" queue (Int64.to_string now)));
            (*Conf.log ("slot_init:\n  " ^  slot_to_string slot_init);*)
            (* let slots_with_scheduled_jobs = try Hashtbl.find h_slots 0 with  Not_found -> failwith "Can't slots #0" in 
            Conf.log ("slots_with_scheduled_jobs #0:\n  " ^ (Helpers.concatene_sep "\n   " slot_to_string slots_with_scheduled_jobs));*)

  				  (* Conf.log ("Resources found:\n   " ^ (Helpers.concatene_sep "\n   " resource_to_string resources) ); *)     
	  		    (* Conf.log ("Waiting jobs:\n"^  (Helpers.concatene_sep "\n   " job_waiting_to_string waiting_jobs) ); *)
            (* Conf.log ("Previous Scheduled jobs:\n"^  (Helpers.concatene_sep "\n\n" job_to_string prev_scheduled_jobs) ); 
		        Conf.log ("Assigns:\n" ^  (Helpers.concatene_sep "\n\n" job_to_string assignement_jobs));
            *)
            Conf.log ("Ids of noscheduled jobs:" ^ (Helpers.concatene_sep "," (fun n-> Printf.sprintf "%d" n) noscheduled_jids) );

            (* save assignements into db *)
            Iolib.save_assigns conn assignement_jobs;  
            Conf.log "Terminated";
 		        exit 0
          end
        else
	        Conf.log "No jobs to schedule, terminated";
          exit 0 
  with e -> 
    let error_message = Printexc.to_string e in 
      Conf.error error_message;;

