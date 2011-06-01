open Types

let val_DEMT_first_length = 15 * 60
			  (* Pour l'instant 1/4 d'heure *)

let interval_DEMT_array = [| Time.lmake ~hour:8 (); Time.lmake ~hour:13 ()|]

(* Pour l'instant période d'une journée *)
let get_interval_num t a =
  let n = Array.length a in 
  let rec aux i = 
    if i < n then 
      if Time.compare t a.(i) < 0 then i else aux (i+1)
    else i in 
    aux 0 

let get_DEMT_periodic t = 
  let (h, m, s) = TimeConversion.secs2hms t in 
  let rh = h mod 24 and d = h / 24 in 
  let x = Time.make rh m s in
    (d, get_interval_num x interval_DEMT_array)

let compare_DEMT_periods (d1, i1) (d2, i2) = 
  let k = Array.length interval_DEMT_array in 
  if d1 = d2 then compare i1 i2
  else if ( ((d1 = d2 - 1) & (i1 = k) & (i2 = 0)) ||
	    ((d2 = d1 - 1) & (i1 = 0) & (i2 = k)) ) then 0
  else compare d1 d2

let is_DEMT_same_period t1 t2 = 
  (compare_DEMT_periods (get_DEMT_periodic t1) (get_DEMT_periodic t2)) = 0


let next_DEMT_batch_length l = 
  if l < 5 * 3600 then 2 * l else l + 3600
    (* Chaque intervalle est le double du précédent, sauf à la fin... *)

let get_DEMT_last_status conn = 
  let q = "SELECT DEMT_start, DEMT_end, DEMT_length FROM DEMT_status"^
	  " LIMIT 1" in 
    try let res = Iolib.execQuery conn q in 
      ( match Mysql.status conn with 
	    Mysql.StatusOK -> 
	      ( match Mysql.fetch res with 
		    None -> raise Not_found
		  | Some a -> 
		      let get s = Mysql.column res s a in 
 			( Mysql.not_null TimeConversion.datetime2secs (get "DEMT_start"), 
			  Mysql.not_null TimeConversion.datetime2secs (get "DEMT_end"),
			  Mysql.not_null Mysql.int2ml (get "DEMT_length") ) )
	  | Mysql.StatusEmpty -> raise Not_found
	  | Mysql.StatusError _ -> Conf.error "Error in get_DEMT_status")
    with Mysql.Error e -> ( Conf.warn (Printf.sprintf "get_DEMT_status: '%s'" e); 
			    let q = "CREATE TABLE DEMT_status ( 
                                      DEMT_start DATETIME NOT NULL ,
                                      DEMT_end   DATETIME NOT NULL ,
                                      DEMT_length INT NOT NULL)" in 
			    let _ = Iolib.execQuery conn q in 
			      raise Not_found )
      

let save_DEMT_status conn (start, finish, length ) =
  let q1 = "TRUNCATE TABLE DEMT_status" 
  and q2 = Printf.sprintf "INSERT INTO `DEMT_status` ( `DEMT_start` , `DEMT_end` , `DEMT_length` )
                           VALUES (%s , %s , %s)" 
	     (TimeConversion.secs2datetime start)
	     (TimeConversion.secs2datetime finish)
	     (Mysql.ml2int length) in
    ignore (Iolib.execQuery conn q1);
    ignore (Iolib.execQuery conn q2)
	    


(* This does not work 
module 'a MapGen = Map.make(struct type t = 'a let compare = compare end); *)

module MapNodes = Map.Make(struct 
			     type t = node
			     let compare = compare end)
(* Pas sur que ca marche bien ca *)
module MapListTasks = Map.Make(struct 
				 type t = task list
				 let compare = compare end)

module MapTasks = Map.Make(struct 
			     type t = task
			     let compare = compare end)

type group = {
  nodes : node list;
  possible_tasks : task list;
}

let group_to_string g =
  let ns = String.concat "," (List.map (fun n -> n.nodeId) g.nodes)  in 
  let ts = String.concat "," (List.map (fun t -> string_of_int t.taskId) g.possible_tasks) in 
  Printf.sprintf "Nodes %s - Tasks %s" ns ts
  

let make_groups tasks nodes = 

  let node_map = 
    List.fold_left 
      (fun m n -> MapNodes.add n (ref []) m) 
      MapNodes.empty 
      nodes in 
  let add_task t n = 
    try let r = MapNodes.find n node_map in r := t::(!r)
    with Not_found -> failwith "make_groups: nodes" in
  let add_task_to_node_map t = 
    List.iter (add_task t) t.allowed_nodes in

  let handle_node n r m = 
    let l, m = try 
      let l = MapListTasks.find (!r) m in 
      let m_without = MapListTasks.remove (!r) m in 
	l, m_without
    with Not_found -> [], m in 
      MapListTasks.add (!r) (n::l) m  in

  let group_map =  

    List.iter add_task_to_node_map tasks;
    MapNodes.fold handle_node node_map MapListTasks.empty in 


  let task_map = List.fold_left 
		   (fun m t -> MapTasks.add t (ref []) m) 
		   MapTasks.empty 
		   tasks in 

  let group_list = MapListTasks.fold (fun ts ns l -> 
					{ nodes = ns; possible_tasks = ts; }::l) 
		     group_map [] in
    
  let group_array = Array.of_list group_list in 
  let handle_group i g = 
    let handle t = 
      try let r = MapTasks.find t task_map in r := i::(!r)
      with Not_found -> failwith "make_groups: tasks" in
      List.iter handle g.possible_tasks in 
    Array.iteri handle_group group_array; 
    (group_array, MapTasks.map (!) task_map)
    
    
    

let schedule_DEMT conn now (tasks, nodes, preexist) = 
  

  let start_first, length_first, is_new_batch = 
    try let (last_batch_start, supposed_end,
	     last_batch_length) = get_DEMT_last_status conn in
      
      if is_DEMT_same_period last_batch_start now then 
	if now < supposed_end then 
	  supposed_end, next_DEMT_batch_length last_batch_length, false
	else now, next_DEMT_batch_length last_batch_length, true 
      else raise Not_found
    with Not_found -> ( Conf.log "[Scheduler] Starting with new values";
			now, val_DEMT_first_length, true ) in
    (* Faut-il se souvenir des jobs contenus dans le batch en cours ? *)
    (* Disons que pour se rendre compte qu'ils ont tous finis avant la fin prévue c'est pas mal... *)
    (* Pour l'instant je vais decider que non *)

  (* Verifier s'il faut remettre a zero (tous les matins ?) *)

  (* Fills in the Gantt Chart with all pre-existing tasks *)
  (* Except the besteffort ones, which are silently ignored (but only if we're NOT scheduling the besteffort queue...) *)
  let gantt = Gantt.create_gantt now nodes 
		(if Conf.queueName = Conf.besteffortQueueName then preexist 
		 else List.filter (fun p -> not p.besteffort) preexist) in




  let one_interval start length tasks = 
    
    (* J'ai besoin de :
     *  Pour chaque intervalle, trouver les saloperies au milieu. 
     *  Je crois que pour commencer ca va bloquer les noeuds 
     *   sur toute la longueur du batch. *)

  (* Separer les noeuds en groupes d'affinite. Qui se ressemble... *)

    let make_node_vect group = 
      let annoted_node_list = 
	List.filter (fun (_, x) -> x > 0) 
	  (List.map (fun n -> (n, Gantt.availability gantt n start length)) 
	     group.nodes) in
	match annoted_node_list with 
	    [] -> ( match group.possible_tasks with 
			[] -> [||]
		      | l -> let m = snd (Outils.cheap_max (fun t->t.nb_procs) l) in 
			  Array.make m [])
	  | _ -> ( let (_, max_weight_nodes) = 
		     Outils.cheap_max snd annoted_node_list 
		   and max_weight_tasks = 
		     match group.possible_tasks with 
			 [] -> 0
		       | l -> snd (Outils.cheap_max (fun t->t.nb_procs) l) in
		   let max_weight = Pervasives.max max_weight_tasks max_weight_nodes in
		   let u = Array.make (max_weight) [] in 
		     List.iter (fun (n, x) -> u.(x-1) <- n::(u.(x-1))) annoted_node_list; 
		     u ) in 
      
    (* Manque le calcul de l'allocation canonique *)
    (* Et aussi le regroupement des taches courtes *)
    let procs_fun t = t.nb_procs
    and nodes_fun t = t.allocation
    and w_fun t = t.priority in 

      (* Selects the tasks short enough to be scheduled in this batch *)
    let (short, long) = 
      List.partition (fun t -> t.run_time t.allocation < length) tasks in 


    let group_array, maptasks = make_groups short nodes in 
    let group_vect = 
      Array.map (fun g -> make_node_vect g) group_array in 
    let node_vect = Array.concat (Array.to_list group_vect) in 
    let availability_vector = Array.map (Array.map List.length) group_vect in 

    let groups_fun t = MapTasks.find t maptasks in

(*      (* Get rid of tasks for which not enough nodes are available *)
    let (runnable, non_runnable) = 
      let is_ok t = 
	let n = nodes_fun t and p = procs_fun t in 
	List.exists (fun 
      List.partition *)

      (* Dynamic programming to find which set of tasks is best to be scheduled
	 in this batch. *)

      Conf.log ("Going for selection."^
		  (Outils.concatene (fun t -> "\n   "^(task_to_string t)) short)^
		  (Outils.concatene 
		     (fun g -> "\n   "^(Outils.concatene_sep 
					  " - " string_of_int (Array.to_list g)))
		     (Array.to_list availability_vector)));

    let accepted, rejected = 
      Selection.heuristic_properties (List.sort (Outils.cmp (fun t -> - t.submit_time)) short) 
	procs_fun nodes_fun 
	w_fun groups_fun availability_vector in 
      
      (* Ici, s'il reste des noeuds libres, je pourrais peut-etre taper sur la plus longue tache *)

      (* Then List Schedule the accepted tasks, sorted by increasing submission time *)
    let max_time = ref now in 
    let schedule_one (t, c) = 
      let duration = t.run_time t.allocation in 
      let full_cut = Array.concat (Array.to_list c) in 

      let (time, nodes) = 
	Gantt.find_first_hole gantt full_cut node_vect 
	  now duration t.nb_procs in 
	Conf.log (Printf.sprintf "Searching for hole for %d: %s -- %s" t.taskId
		    (Outils.concatene_sep "," string_of_int (Array.to_list full_cut))
		    (Outils.concatene_sep "," 
		       (fun l -> Outils.concatene_sep " " (fun n -> n.nodeId) l)
		       (Array.to_list node_vect) )
		 );
	Conf.log (Printf.sprintf "Found %d (%s) on %s"
		    time (TimeConversion.secs2datetime time) 
		    (Outils.concatene_sep "," (fun n -> n.nodeId) nodes) );
      let selected_nodes = Outils.first_n nodes t.allocation in 
	Gantt.set_occupation gantt time t.nb_procs duration selected_nodes; 
	max_time := max (!max_time) (time + duration);
	(t, time, selected_nodes) in 
    let partial_schedule = 
      List.map schedule_one 
	(List.sort (Outils.cmp (fun (t, _) -> t.submit_time)) accepted) in 

      (* I should print out the tasks scheduled in each interval. *)
      Conf.log (Printf.sprintf  "New interval: %d - %d (%d)" start (!max_time) length);
      List.iter (fun a -> Conf.log ("  "^(assign_to_string  a))) partial_schedule;

      (partial_schedule, !max_time, long@rejected) in 

  let rec all_intervals is_first start length tasks partial_schedule = 
    match tasks with [] -> partial_schedule
      | _ -> let (schedule, end_date, reste) = one_interval start length tasks in
	  if is_first && is_new_batch then 
	    save_DEMT_status conn (start, end_date, length);
	  if schedule <> [] then 
	    all_intervals false end_date (next_DEMT_batch_length length) reste (schedule@partial_schedule)
	  else all_intervals false (start+length) (next_DEMT_batch_length length) reste partial_schedule in 
    
  let g, m = make_groups tasks nodes in 
    
    Array.iteri (fun i g -> Conf.log (Printf.sprintf "Group %d : %s" i (group_to_string g))) g;
    MapTasks.iter (fun t l -> Conf.log (Printf.sprintf "%d : %s" t.taskId
					  (String.concat "," (List.map string_of_int l)))) m;

    all_intervals true start_first length_first tasks

      

(* Commencer par prevoir tous les batchs jusqu'au bout *)
(* Poids multiples -> sac a dos multiple -- a definir *)
(* Reservations -> 2 possibilites:
 *   Bloquer un noeud reserve sur tout la longueur du batch 
 *   Prendre tous les noeuds reserves qqpart et 
 *      faire un mini-batch a l'interieur *)

(* Si possible, tasser les batchs sur lesquels il reste des noeuds libres *)

(* Ici j'ai une liste ordonnee de taches allouees 
   Pas vraiment; pb des poids et des proprietes... *)

		     (* Mettre a jour le Gantt en faisant le tassage : list scheduling *)

    []
