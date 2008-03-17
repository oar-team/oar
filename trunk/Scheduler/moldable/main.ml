open Types

let _ = 
  try 
    Conf.log "Starting";
    let conn = let r = Iolib.connect () in 
      at_exit (fun () -> Iolib.disconnect r); r in
    let nodes = Iolib.get_node_list conn in
    let alive_nodes = List.filter (fun n -> n.state = Alive) nodes in 
    let tasks = Iolib.get_task_list conn alive_nodes in
    let preexist = Iolib.get_preexist conn nodes in
      
      
      (* Should be a print_instance function *)
      Conf.log (Printf.sprintf "Now = %d, Queue = %s" Conf.now Conf.queueName);
      Conf.log ("Tasks found:"^
		  ( Outils.concatene_sep "\n   " task_to_string tasks) );
      (*    List.iter (fun t -> Printf.eprintf "   %s\n" (task_to_string t)) tasks; *)
      Conf.log ( "Nodes found:\n   " ^
		   (Outils.concatene_sep "\n   " node_to_string nodes) );
      Conf.log ( "PreTasks found:\n   "^
		   (Outils.concatene_sep "\n   " pretask_to_string preexist) );
      
      (* Filters out the tasks that will never be able to be scheduled *)
      
      let reasonable_tasks = 
	let nb_ok_nodes t = 
	  List.length (List.filter (fun n -> n.max_procs >= t.nb_procs) t.allowed_nodes) in 
	  List.filter (fun t -> (nb_ok_nodes t) >= Outils.min Outils.id t.allowed_allocs) tasks in 
	
      (* Do the actual scheduling *)
      let assigns = Scheduler.schedule_DEMT conn Conf.now (reasonable_tasks, alive_nodes, preexist) in 
	
	
	(* Should be a print_result function *)
	Conf.log "Assigns:";
	List.iter (fun a -> Conf.log (assign_to_string a)) assigns;
	
	(* Saves the allocation of tasks that have changed *)
(*	Iolib.set_nodes conn (List.filter (fun t -> t.alloc_changed) tasks); *)
	(* Save the assignments in the database *)
	Iolib.save_assigns conn assigns; 
	exit 0
  with e -> 
    let error_message = Printexc.to_string e in 
      Conf.error error_message;;


(*    with 
	ImpossibleTask t -> 
	  Printf.eprintf "Task %s cannot be scheduled\n" (task_to_string t);; *)
     
