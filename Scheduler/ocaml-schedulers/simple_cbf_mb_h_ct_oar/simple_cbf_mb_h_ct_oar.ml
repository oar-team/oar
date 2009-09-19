open Types
open Interval 
open Simple_cbf_mb_h_ct
open Mysql
(*
TODO
1) Extract resources/pseudo_job function from _ function
2) Debug
3) Besteffort
4) Message scheduler/job (same and more than perl scheduler)
5) Complete Tests infrastructure (automatic test / ruby) and add more tests...
6) Doc
*)

let besteffort_duration = Int64.of_int (5*60)

(*
>> 2**31 => 2147483648
>> 2**31 -1 => 2147483647
*)
let max_time = 2147483648L
let max_time_minus_one = 2147483647L


let argv = if (Array.length(Sys.argv) > 2) then
      (Sys.argv.(1), (Int64.of_string Sys.argv.(2)))
    else
      ("default", Int64.of_float (Unix.time ()))

(* Determine global resource intervals and init_slots with or without resource availabilty (fied available_upto in resources table *)
let resources_init_slots_determination dbh now =
  let potential_resources = Iolib.get_resource_list dbh in
  let flag_wake_up_cmd = Conf.test_key("SCHEDULER_NODE_MANAGER_WAKE_UP_CMD") in (* TO COMPLETE *)
  (* TODO add condition test/case if (is_conf("SCHEDULER_NODE_MANAGER_WAKE_UP_CMD")){ *)
  
     
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
    let filter_map f_map f_filter =
      let rec find accu = function
        | [] -> List.rev accu
        | x :: l -> if (f_filter x) then find ((f_map x) :: accu) l else find accu l in
        find []
      in

    let filter_a_upto_id a =
      let rec find accu = function
        | [] -> List.rev accu
        | x :: l -> if (x.available_upto = a) then find (x.resource_id :: accu) l else find accu l in
        find []
      in
    let pseudo_job_av_upto a_upto =
                                    { jobid=0;
                                      moldable_id=0;
                                      time_b = if (a_upto<now) then now else a_upto;
                                     (* walltime = Int64.sub max_time_minus_one a_upto; *)
                                      walltime = if (a_upto<now) then (Int64.sub max_time_minus_one now) else (Int64.sub max_time_minus_one a_upto);
                                      types = [];
                                      constraints = [];
                                      hy_level_rqt = [];
                                      hy_nb_rqt = [];
                                      set_of_rs = (ints2intervals (filter_a_upto_id a_upto resources)); } 
      in
    let pseudo_jobs_resources_available_upto = filter_map (fun n -> pseudo_job_av_upto n) (fun n -> if (n < max_time_minus_one) then true else false) available_uptos in

    let slot_init = {time_s = now; time_e = max_time; set_of_res = resource_intervals} in
    let slots_init_available_upto_resources = split_slots_prev_scheduled_jobs [slot_init] pseudo_jobs_resources_available_upto in
    (resource_intervals,slots_init_available_upto_resources) 

 (*   (resource_intervals,[slot_init]) *)

(*               *)
(* Main function *)
(*               *)
let _ = 
	try
		Conf.log "Starting";

    Hierarchy.hierarchy_levels := Hierarchy.h_desc_to_h_levels Conf.get_hierarchy_info; (* get hierarchy description from oar.conf and convert it in hierarchy levels *)

    let (queue,now) = argv in
		let conn = let r = Iolib.connect () in at_exit (fun () -> Iolib.disconnect r); r in
      let h_slots = Hashtbl.create 10 in
	(*
      Hashtbl.add h_slots 0 [slot_init]; 
*)
      let  (resource_intervals,slots_init_available_upto_resources) = resources_init_slots_determination conn now in
        Hashtbl.add h_slots 0 slots_init_available_upto_resources;  

  		let (waiting_j_ids,h_waiting_jobs) = Iolib.get_job_list conn queue resource_intervals in (* TODO false -> alive_resource_intervals, must be also filter by type-default !!!  Are-you sure ??? *)
        
      Conf.log ("Job waiting ids"^ (Helpers.concatene_sep "," string_of_int waiting_j_ids));

      if (List.length waiting_j_ids) > 0 then
        begin
          ignore (Iolib.get_job_types conn waiting_j_ids h_waiting_jobs);(*TODO how to avoid 'Warning Y: unused variable v' *) 
          (* set specific walltime for waiting besteffort jobs *)
          (* TODO only if queue = besteffort ??? *)
          (* WHY hash_order ??? *)
          (* TODO......BESTEFFORT *)
          (*
          hash_order (fun n-> if ( List.mem "besteffort" n.types) then n.walltime <- besteffort_duration else ()) waiting_j_ids h_waiting_jobs;
          *)
          (* take into account previously scheduled jobs *)
          let prev_scheduled_jobs = Iolib.get_scheduled_jobs conn in
          let slots_with_scheduled_jobs = if not ( prev_scheduled_jobs = []) then
            let (h_prev_scheduled_jobs_types, prev_scheduled_job_ids) = Iolib.get_job_types_hash_ids conn prev_scheduled_jobs in
            (* exclude besteffort jobs *)
            (* test if job have besteffort type *)
(* TODO BESTEFFORT 
            let besteffort_mem job_test = 
              List.mem "besteffort" ( try Hashtbl.find h_prev_scheduled_jobs_types job_test.jobid
                                      with Not_found -> failwith "Must no failed here").types in
            let prev_scheduled_jobs_no_bt =  List.filter (fun n -> not (besteffort_mem n)) prev_scheduled_jobs in
              Conf.log ("Previous Scheduled jobs no besteffort:\n"^  (Helpers.concatene_sep "\n\n" job_to_string prev_scheduled_jobs_no_bt) ); 
*)
(*            let prev_scheduled_jobs_no_bt = prev_scheduled_jobs in (* TODO BESTEFFORT *) *)
            (* split_slots_prev_scheduled_jobs [slot_init] prev_scheduled_jobs_no_bt *)
             set_slots_with_prev_scheduled_jobs h_slots h_prev_scheduled_jobs_types prev_scheduled_job_ids
          else ()
          in
          (* now compute an assignement for waiting jobs - MAKE A SCHEDULE *)
          let assignement_jobs = 
            begin
(*
              slots_with_scheduled_jobs; (* fill slots with prev scheduled jobs *)  
*)
              schedule_id_jobs_ct h_slots h_waiting_jobs waiting_j_ids
            end 
          in
            Conf.log ((Printf.sprintf "Queue: %s, Now: %s" queue (ml642int now)));
(*          Conf.log ("slot_init:\n  " ^  slot_to_string slot_init); *)
(*
            Conf.log ("slots_with_scheduled_jobs:\n  " ^ (Helpers.concatene_sep "\n   " slot_to_string slots_with_scheduled_jobs));
*)
(*
  				  Conf.log ( "Resources found:\n   " ^ (Helpers.concatene_sep "\n   " resource_to_string resources) );        
	  		    Conf.log ( "Waiting jobs:\n"^  (Helpers.concatene_sep "\n   " job_waiting_to_string waiting_jobs) ); 
*)
            Conf.log ("Previous Scheduled jobs:\n"^  (Helpers.concatene_sep "\n\n" job_to_string prev_scheduled_jobs) ); 
		        Conf.log ("Assigns:\n" ^  (Helpers.concatene_sep "\n\n" job_to_string assignement_jobs)); 
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

