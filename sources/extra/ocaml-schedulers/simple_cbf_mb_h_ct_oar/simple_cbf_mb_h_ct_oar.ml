open Types
open Interval 
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

(*       *)
(* Karma *)
(*       *)

let karma_window_size = 3600 * 30 * 24

let karma_proj_targets =  [| ("first", 75);  ("default", 25) |]  (* TODO Config SCHEDULER_FAIRSHARING_PROJECT_TARGETS *)
let karma_user_targets = [| ("oar", 100) |] (* TODO Config SCHEDULER_FAIRSHARING_USER_TARGETS *) 
let karma_coeff_proj_consumption = float_of_int 0 (* TODO Config SCHEDULER_FAIRSHARING_COEF_PROJECT *)
let karma_coeff_user_consumption = float_of_int 2 (* TODO Config SCHEDULER_FAIRSHARING_COEF_USER *)
let karma_coeff_user_asked_consumption = float_of_int 1 (* TODO Config SCHEDULER_FAIRSHARING_COEF_USER_ASK *)

let jobs_karma_sorting dbh queue now karma_window_size jobs_ids h_jobs =
  let start_window = now - karma_window_size and stop_window = now in
    let karma_sum_time_asked, karma_sum_time_used = Iolib.get_sum_accounting_window dbh queue start_window stop_window
    and karma_projects_asked, karma_projects_used = Iolib.get_sum_accounting_for_param dbh queue "accounting_project" start_window stop_window
    and karma_users_asked, karma_users_used       = Iolib.get_sum_accounting_for_param dbh queue "accounting_user" start_window stop_window 
    in
      let karma j = let user = "yop" (*TODO j.user *) and proj = "poy" (*TODO j.project *) in
        let karma_proj_used_j = try Hashtbl.find karma_projects_used proj  with Not_found -> 0.0
        (* and karma_proj_asked_j = try Hashtbl.find karma_projects_asked proj  with Not_found -> 0.0 *) (* TODO Not used ???*)
        and karma_user_used_j = try Hashtbl.find karma_users_used user  with Not_found -> 0.0
        and karma_user_asked_j = try Hashtbl.find karma_users_asked user  with Not_found -> 0.0
        and karma_proj_target = 1.0 (* TODO   ($Karma_project_targets->{$j->{project}} *)
        and karma_user_target = 1.0 (* TODO  $Karma_user_targets->{$j->{job_user}} / 100))  *)
        in
          karma_coeff_proj_consumption *. ((karma_proj_used_j /. karma_sum_time_used) -. (karma_proj_target /. 100.0)) +.
          karma_coeff_user_consumption *. ((karma_user_used_j /. karma_sum_time_used) -. (karma_user_target /. 100.0)) +.
          karma_coeff_user_asked_consumption *. ((karma_user_asked_j /. karma_sum_time_asked) -. (karma_user_target /. 100.0))
      in
      let kompare x y = let kdiff = (karma x) -. (karma y) in if kdiff = 0.0 then 0 else if kdiff > 0.0 then 1 else -1 in
        List.sort kompare jobs_ids;;

(*

my $Karma_projects = OAR::IO::get_sum_accounting_for_param($base,$queue,"accounting_project",$current_time - $Karma_window_size,$current_time);
my $Karma_users = OAR::IO::get_sum_accounting_for_param($base,$queue,"accounting_user",$current_time - $Karma_window_size,$current_time);

sub karma($){
    my $j = shift;

    my $note = 0;
    $note = $Karma_coeff_project_consumption * (($Karma_projects->{$j->{project}}->{USED} / $Karma_sum_time->{USED}) - ($Karma_project_targets->{$j->{project}} / 100));
    $note += $Karma_coeff_user_consumption * (($Karma_users->{$j->{job_user}}->{USED} / $Karma_sum_time->{USED}) - ($Karma_user_targets->{$j->{job_user}} / 100));
    $note += $Karma_coeff_user_asked_consumption * (($Karma_users->{$j->{job_user}}->{ASKED} / $Karma_sum_time->{ASKED}) - ($Karma_user_targets->{$j->{job_user}} / 100));

    return($note);
}
@jobs = sort({karma($a) <=> karma($b)} @jobs);
*)

(*               *)
(* Suspend stuff *)
(*               *)

(*
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

let resources_init_slots_determination dbh now =
  let potential_resources = Iolib.get_resource_list dbh in
  let flag_wake_up_cmd = Conf.test_key("SCHEDULER_NODE_MANAGER_WAKE_UP_CMD") in 
    if flag_wake_up_cmd then
      let resources = List.filter (fun n -> ((n.state = Alive) || (n.state = Absent))) potential_resources in
        let resource_intervals = 
          if ((List.length resources) = 0) then
            begin
              Conf.log "none available ressources for scheduling any jobs"; exit 0
            end
          else
            ints2intervals (List.map (fun n -> n.resource_id) resources) 
          in
        let available_uptos = Iolib.get_available_uptos dbh in
        (* create corresponding job from available_up parameter of resource *) 
        let pseudo_job_av_upto a_upto =
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
                                      set_of_rs = (ints2intervals (Helpers.filter_map (fun n -> n.available_upto = a_upto) (fun n -> n.resource_id) resources));} 
          in
        let pseudo_jobs_resources_available_upto = Helpers.filter_map (fun n -> n < max_time_minus_one) (fun n -> pseudo_job_av_upto n) available_uptos in

        let slot_init = {time_s = now; time_e = max_time; set_of_res = resource_intervals} in
        let slots_init_available_upto_resources = split_slots_prev_scheduled_jobs [slot_init] pseudo_jobs_resources_available_upto in
          (resource_intervals,slots_init_available_upto_resources)
    else
      let resources = List.filter (fun n -> n.state = Alive) potential_resources in
      let resource_intervals = ints2intervals (List.map (fun n -> n.resource_id) resources) in
        (resource_intervals,[{time_s = now; time_e = max_time; set_of_res = resource_intervals}])

(*               *)
(* Main function *)
(*               *)
let _ = 
	try
		Conf.log "Starting";

    (* get hierarchy description from oar.conf and convert it in hierarchy levels and set master_top (toplevel interval) *)
    Hierarchy.hierarchy_levels := Hierarchy.h_desc_to_h_levels Conf.get_hierarchy_info;
    Hierarchy.toplevel_itv := List.hd (List.assoc "resource_id" !Hierarchy.hierarchy_levels) ; 

    let (queue,now) = argv in
    let security_time_overhead = Int64.of_string  (Conf.get_default_value "SCHEDULER_JOB_SECURITY_TIME" "60") in   (* int no for  ? *)
		let conn = let r = Iolib.connect () in at_exit (fun () -> Iolib.disconnect r); r in
      let h_slots = Hashtbl.create 10 in
	    (* Hashtbl.add h_slots 0 [slot_init]; *)
      let  (resource_intervals,slots_init_available_upto_resources) = resources_init_slots_determination conn now in
        Hashtbl.add h_slots 0 slots_init_available_upto_resources;  

  		let (waiting_j_ids,h_waiting_jobs) = Iolib.get_job_list conn resource_intervals queue besteffort_duration security_time_overhead in (* TODO 
      false -> alive_resource_intervals, must be also filter by type-default !!!  Are-you sure ??? *)
      Conf.log ("job waiting ids: "^ (Helpers.concatene_sep "," string_of_int waiting_j_ids));

      if (List.length waiting_j_ids) > 0 then (* Jobs to schedule ?*)
        begin

          (* get types attributs of wating jobs *)
          ignore (Iolib.get_job_types conn waiting_j_ids h_waiting_jobs);
          
          (* fill slots with prev scheduled jobs  *)
          let prev_scheduled_jobs = Iolib.get_scheduled_jobs conn [] security_time_overhead now in (* TODO available_suspended_res_itvs *)
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
             let slots_with_scheduled_jobs = try Hashtbl.find h_slots 0 with  Not_found -> failwith "Can't slots #0" in 
             Conf.log ("slots_with_scheduled_jobs_before #0:\n  " ^ (Helpers.concatene_sep "\n   " slot_to_string slots_with_scheduled_jobs));
         
             Conf.log ("length h_prev_scheduled_jobs_types:"^(string_of_int (Hashtbl.length h_prev_scheduled_jobs_types)));

             set_slots_with_prev_scheduled_jobs h_slots h_prev_scheduled_jobs_types prev_scheduled_job_ids security_time_overhead;
             
             let slots_with_scheduled_jobs = try Hashtbl.find h_slots 0 with  Not_found -> failwith "Can't slots #0" in 
             Conf.log ("slots_with_scheduled_jobs after #0:\n  " ^ (Helpers.concatene_sep "\n   " slot_to_string slots_with_scheduled_jobs));
  

          else ();

          Conf.log "go to make a schedule";

          (* get jobs' dependencies information *) 
          let h_jobs_dependencies = Iolib.get_current_jobs_dependencies conn    in
          let h_req_jobs_status   = Iolib.get_current_jobs_required_status conn in

          (* now compute an assignement for waiting jobs - MAKE A SCHEDULE *)
          let (assignement_jobs, noscheduled_jids) = schedule_id_jobs_ct_dep h_slots h_waiting_jobs h_jobs_dependencies h_req_jobs_status waiting_j_ids security_time_overhead
          in
            Conf.log ((Printf.sprintf "Queue: %s, Now: %s" queue (Int64.to_string now)));
            (*Conf.log ("slot_init:\n  " ^  slot_to_string slot_init);*)
            let slots_with_scheduled_jobs = try Hashtbl.find h_slots 0 with  Not_found -> failwith "Can't slots #0" in 
            Conf.log ("slots_with_scheduled_jobs #0:\n  " ^ (Helpers.concatene_sep "\n   " slot_to_string slots_with_scheduled_jobs));
  				  (* Conf.log ("Resources found:\n   " ^ (Helpers.concatene_sep "\n   " resource_to_string resources) ); *)     
	  		    (* Conf.log ("Waiting jobs:\n"^  (Helpers.concatene_sep "\n   " job_waiting_to_string waiting_jobs) ); *)

            Conf.log ("Previous Scheduled jobs:\n"^  (Helpers.concatene_sep "\n\n" job_to_string prev_scheduled_jobs) ); 
		        Conf.log ("Assigns:\n" ^  (Helpers.concatene_sep "\n\n" job_to_string assignement_jobs));
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

