open Types
open Interval 
open Simple_cbf_mb_h_ct
open Mysql
(*
TODO
6) arrange file ???
4) get_scheduled_jobs ???

*)

let besteffort_duration = Int64.of_int (5*60)

let argv = if (Array.length(Sys.argv) > 2) then
      (Sys.argv.(1), (Int64.of_string Sys.argv.(2)))
    else
      ("default", Int64.of_float (Unix.time ()))

let _ =
	try
		Conf.log "Starting";

    Hierarchy.hierarchy_levels := Hierarchy.h_desc_to_h_levels Conf.get_hierarchy_info; (* get hierarchy description from oar.conf and convert it in hierarchy levels *)

    let (queue,now) = argv in
		let conn = let r = Iolib.connect () in at_exit (fun () -> Iolib.disconnect r); r in

			let resources = Iolib.get_resource_list conn in
    	let alive_resources = List.filter (fun n -> n.state = Alive) resources in
      let alive_resource_intervals = ints2intervals (List.map (fun n -> n.resource_id) alive_resources) in


      (* create intial slots and hashtable of slots to manage containers *)
      let h_slots = Hashtbl.create 10 in
      let slot_init = {time_s = now; time_e = Int64.max_int; set_of_res = alive_resource_intervals} in
      Hashtbl.add h_slots 0 [slot_init];

  		let (waiting_j_ids,h_waiting_jobs) = Iolib.get_job_list conn queue alive_resource_intervals in (* TODO false -> alive_resource_intervals, must be also filter by type-default !!!  Are-you sure ??? *)
        
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
              slots_with_scheduled_jobs; (* fill slots with prev scheduled jobs *)  
              schedule_id_jobs_ct h_slots h_waiting_jobs waiting_j_ids
            end 
          in
            Conf.log ((Printf.sprintf "Queue: %s, Now: %s" queue (ml642int now)));
            Conf.log ("slot_init:\n  " ^  slot_to_string slot_init);
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

