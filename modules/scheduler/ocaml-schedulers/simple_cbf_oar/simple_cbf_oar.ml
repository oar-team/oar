open Types
open Interval 
open Simple_cbf 
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
  		let waiting_jobs = Iolib.get_job_list conn alive_resource_intervals in
         Conf.log ("Previous Scheduled jobs:\n"^  (Helpers.concatene_sep "\n\n" job_to_string (Iolib.get_scheduled_jobs conn)) ); 

        if not (waiting_jobs = []) then
          
          let prev_scheduled_jobs = Iolib.get_scheduled_jobs conn in
          let slots_with_scheduled_jobs = split_slots_prev_scheduled_jobs [slot_init] prev_scheduled_jobs in
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

