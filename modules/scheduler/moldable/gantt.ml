open Types

let security_time = 1

module NodeHash = Hashtbl.Make(struct type t = node
				      let hash = Hashtbl.hash
				      let equal = (=) end)

type interval = {
  start : time_t;
  mutable finish : time_t option;
  mutable used_procs: int;
  node: node;
}


module IntervalSet = 
  Set.Make(struct type t = interval 
		  let compare i1 i2 = 
		    let x = compare i1.start i2.start in 
		      if x <> 0 then x
		      else compare i1.node i2.node end)


type gantt = {
  mutable all_intervals: IntervalSet.t;
  by_node: interval list NodeHash.t;
  now : int;
}

let print_interval i = 
  let s_f = match i.finish with 
      None -> "+inf"
    | Some x -> string_of_int x in 
    Printf.printf " Node %s: [%d, %s] = %d\n" i.node.nodeId i.start s_f i.used_procs

let pretty_print g = 
  Printf.printf "Interval List:\n"; 
  IntervalSet.iter print_interval g.all_intervals;
  Printf.printf "By node";
  NodeHash.iter (fun n il -> Printf.printf "\n----Node %s: ---\n" n.nodeId;
		   List.iter print_interval il) g.by_node


(* PLEIN DE BOULOT ICI *)

(* is_after d x = true <=> d is after x*)
let is_after ?(eq=false) d = function 
    None -> false
  | Some x -> if eq then x <= d else x < d

let empty_gantt now nodes = 
  let create_int n = 
    { start = now;
      finish = None;
      used_procs = 0;
      node = n } in
  let int_list = List.map create_int nodes in
  { all_intervals = List.fold_left (fun n s -> IntervalSet.add s n) IntervalSet.empty int_list;
    by_node = (let t = NodeHash.create (List.length nodes) in 
		 List.iter (fun i -> NodeHash.add t i.node [i]) int_list; t);
    now =  now;}


let set_occupation gantt start nb_procs duration nodes = 
  let occupation_end = start + duration + security_time in 
  let fuse_if_necessary int_set = function
      (b::br, a::ar) when a.used_procs = b.used_procs ->
	( b.finish <- a.finish;
	  (IntervalSet.remove a int_set, (br, b::ar)) )
    | x -> (int_set, x) in 
  let set_one_node n int_set list_for_this_node = 
    let rec aux int_set int_list = function 
	[] -> (int_set, List.rev int_list)
      | i::is -> 
	  if (i.start >= occupation_end) then (int_set, List.rev_append int_list (i::is))
	  else if (is_after ~eq:true start i.finish) then aux int_set (i::int_list) is 
	  else 
	    ( (* Printf.printf "Interesting time %d\n" i.start; *)
	      if i.start < start then 
		( let fin = i.finish in 
		    i.finish <- Some start;
		    let new_int = { start = start; 
				    finish = fin;
				    used_procs = i.used_procs; 
				    node = n } in
		      aux (IntervalSet.add new_int int_set) (i::int_list) (new_int::is) )
	      else (* Here i.start >= start *)
		( i.used_procs <- i.used_procs + nb_procs;
		  let (int_set, (before, i::after)) = 
		    fuse_if_necessary int_set (int_list, i::is) in 
		    
		    if (is_after occupation_end i.finish) then 
		      (aux int_set (i::before) after )
		    else match i.finish with 
			Some x when x = occupation_end -> 
			  ( let (int_set, (before, (i::after))) = 
			      fuse_if_necessary int_set (i::before, after) in 
			      aux int_set (i::before) after (* to be checked *)
			  )
		      | _ -> 
			  ( let fin = i.finish in 
			      i.finish <- Some occupation_end;
			      let new_int = { start = occupation_end;
					      finish = fin;
					      used_procs = i.used_procs - nb_procs; 
					      (* C'est etrange ca *)
					      node = n } in 
				aux (IntervalSet.add new_int int_set) 
				  (new_int::i::before) after ) ) ) in
      aux int_set [] list_for_this_node in
    
    gantt.all_intervals <- List.fold_left 
      (fun t n -> 
	 (*	 Printf.printf "Working for node %s\n" n.nodeId; *)
	 let int_list = try NodeHash.find gantt.by_node n 
	 with Not_found -> [{ start = gantt.now;
			      finish = None;
			      used_procs = 0;
			      node = n }] in 
	 let (t, l) = set_one_node n t int_list in 
	   NodeHash.replace gantt.by_node n l; t) 
      gantt.all_intervals nodes
      
    



let create_gantt now nodes preexist = 
  let g = empty_gantt now nodes in 
    
  let one p = set_occupation g p.sched_time p.pre_nb_procs 
		p.pre_run_time p.nodes in 
    List.iter one preexist; 
    g


(* a faire: 
 * create_gantt
 * availability
 * find_first_hole
 * schedule
 *)


let availability gantt node start duration = 
  let finish = start + duration in 
  let rec aux max_procs = function 
      [] -> max_procs
    | i::_ when i.start > finish -> max_procs
    | i::is when is_after start i.finish -> aux max_procs is
    | i::is -> aux (max max_procs i.used_procs) is in 
    
  let mp = aux 0 (NodeHash.find gantt.by_node node) in 
    node.max_procs - mp



exception Found of node list
	
let find_first_hole gantt requests nodes start duration required_procs = 
 
  let k = Array.length requests in 
  let stop_times = 
    let h = NodeHash.create 10 in
    let add_one n = NodeHash.add h n None in 
      Array.iter (List.iter add_one) nodes; 
      h in
    
  let find_stop_time n start = 
    let max_used = n.max_procs - required_procs in 
    let rec aux_end so_far = function 
	[] -> so_far 
      | i::is -> if i.used_procs > max_used then so_far
	else aux_end (Some i.finish) is in 
    let rec aux_start = function 
	[] -> failwith "find_stop_time"
      | i::is as l -> if i.start >= start then aux_end None l 
	else aux_start is in 
      aux_start (NodeHash.find gantt.by_node n) in 
    
  let try_this_hole current_time = 
    let avail_nodes = ref [] in 
    let is_available n = 
      match NodeHash.find stop_times n with 
	  None -> false
	| Some None -> avail_nodes := n::(!avail_nodes); true
	| Some (Some stop) -> 
	    if stop - current_time >= duration then 
	      ( avail_nodes := n::(!avail_nodes); true) 
	    else ( NodeHash.replace stop_times n None; false) in 
    let count = List.fold_left 
		  (fun i n -> if is_available n then i+1 else i) 0 in 
    let available = Array.map count nodes  in
    let rec aux i = if i >= k then Some (!avail_nodes)
    else if available.(i) >= requests.(i) then aux (i+1) else None in 
      aux 0 in 
    
  let current_time = ref start in 
  let explore i =
    if i.start > (!current_time )
    then ( match try_this_hole (!current_time) with 
	       Some l -> raise (Found l) 
	     | None -> ()); 
    ( try match NodeHash.find stop_times i.node with 
	  None -> NodeHash.replace stop_times i.node 
	    (find_stop_time i.node i.start) 
	| Some _ -> ()
      with Not_found -> ());
    current_time := max i.start (!current_time) in 
    
    try 
      IntervalSet.iter explore gantt.all_intervals;
      match try_this_hole (!current_time) with 
	  Some l -> (!current_time, l)
	| None -> raise Not_found
    with Found l -> (!current_time, l)
