open Types
open Interval 
open Simple_cbf_mb 
open Mysql
(*
TODO
6) arrange file
4) get_scheduled_jobs

DONE:

- add scheduled in simple_cbf
- Add Intervals.ml
- test save_assign
- do save_assigns
- test sub_intervals A-B w/ B > A
- get_scheduled_jobs
- ARGV

*)


let besteffort_duration = Int64.of_int (5*60)

let argv = if (Array.length(Sys.argv) > 2) then
      (Sys.argv.(1), (Int64.of_string Sys.argv.(2)))
    else
      ("default", Int64.of_float (Unix.time ()))

let _ =
	try
		Conf.log "Starting";
    let (queue,now) = argv in
		let conn = let r = Iolib.connect () in at_exit (fun () -> Iolib.disconnect r); r in

			let resources = Iolib.get_resource_list conn in
    	let alive_resources = List.filter (fun n -> n.state = Alive) resources in
      let alive_resource_intervals = ints2intervals (List.map (fun n -> n.resource_id) alive_resources) in
      let slot_init = {time_s = now; time_e = Int64.max_int; nb_free_res = List.length alive_resources; set_of_res = alive_resource_intervals} in
  		let waiting_jobs = Iolib.get_job_list conn (alive_resource_intervals, List.length alive_resources) in
      
 (*        Conf.log ("Previous Scheduled jobs:\n"^  (Helpers.concatene_sep "\n\n" job_to_string (Iolib.get_scheduled_jobs conn)) ); *)

        if not (waiting_jobs = []) then 
          let h_waiting_jobs =  Iolib.get_job_types conn waiting_jobs in
          
          (* set specific walltime for waiting besteffort jobs *)
          List.iter (fun n-> if ( List.mem "besteffort" n.types) then n.walltime <- besteffort_duration else ()) waiting_jobs;

          (* take into account previously scheduled jobs *)
          let prev_scheduled_jobs = Iolib.get_scheduled_jobs conn in
          let slots_with_scheduled_jobs = if not ( prev_scheduled_jobs = []) then
            let h_prev_scheduled_jobs_types = Iolib.get_job_types conn prev_scheduled_jobs in
            (* exclude besteffort jobs *)
            (* test if job have besteffort type *)
            let besteffort_mem job_test = 
              List.mem "besteffort" (try Hashtbl.find h_prev_scheduled_jobs_types job_test.jobid
                                     with Not_found -> failwith "Must no failed here").types in
            let prev_scheduled_jobs_no_bt =  List.filter (fun n -> not (besteffort_mem n)) prev_scheduled_jobs in
              Conf.log ("Previous Scheduled jobs no besteffort:\n"^  (Helpers.concatene_sep "\n\n" job_to_string prev_scheduled_jobs_no_bt) ); 
              split_slots_prev_scheduled_jobs [slot_init] prev_scheduled_jobs_no_bt
          else [slot_init]

          in
          (* now compute an assignement for waiting jobs - MAKE A SCHEDULE *)
          let assignement_jobs = schedule_jobs waiting_jobs slots_with_scheduled_jobs in

            Conf.log ((Printf.sprintf "Queue: %s, Now: %s" queue (ml642int now)));
            Conf.log ("slot_init:\n  " ^  slot_to_string slot_init);
            Conf.log ("slots_with_scheduled_jobs:\n  " ^ (Helpers.concatene_sep "\n   " slot_to_string slots_with_scheduled_jobs));
(*
  				  Conf.log ( "Resources found:\n   " ^ (Helpers.concatene_sep "\n   " resource_to_string resources) );        
	  		    Conf.log ( "Waiting jobs:\n"^  (Helpers.concatene_sep "\n   " job_waiting_to_string waiting_jobs) ); 
*)
            Conf.log ("Previous Scheduled jobs:\n"^  (Helpers.concatene_sep "\n\n" job_to_string prev_scheduled_jobs) ); 
		        Conf.log ("Assigns:\n" ^  (Helpers.concatene_sep "\n\n" job_to_string assignement_jobs)); 
            Iolib.save_assigns conn assignement_jobs;        
 		        exit 0 
        else
           exit 0 

  with e -> 
    let error_message = Printexc.to_string e in 
      Conf.error error_message;;

