
type 'a resultat = { 
  mutable weight: int;
  mutable selected: ('a * int array) list;
  mutable dismissed: 'a list;
}

(* Decoupe de [0;n] en k intervalles Xi de taille limité par maxs.(i)*)
let first_cut n k maxs = 
  let t = Array.make k 0 and s = ref n in 
    for i = k - 1 downto 0 do 
      let u = min !s maxs.(i) in 
	t.(i) <- u; s := !s - u; done; if !s > 0 then failwith "Cuts" else t
let is_last_cut n k maxs c = 
  let s = ref n in 
    try for i = 0 to k - 1 do 
      let u = min !s maxs.(i) in 
	if c.(i) = u then s := !s - u
	else failwith "No"; done; if !s != 0 then failwith "Cuts" else true
    with Failure "No" -> false
(* next_cut: search the first unconstrained value after 
 * the first positive one *)
let next_cut n k maxs c = 
  let i = ref (k - 1) and s = ref 0 in 
    while c.(!i) = 0 do decr i; done;
    s := c.(!i); decr i;
    while (!i >= 0) & (c.(!i) >= maxs.(!i)) do 
      s := !s + c.(!i); decr i; done;
    if !i < 0 then failwith "Cuts";
    let res = (*Array.copy*) c in (* Small memory optimization. We'll see.. *)
      res.(!i) <- res.(!i) + 1; decr s;
      for j = k - 1 downto (!i+1) do
	let u = min !s maxs.(j) in 
	  res.(j) <- u; s := !s - u; 
      done; 
      if !s > 0 then failwith "Cuts" else res
let iter_cut n k maxs f = 
  let rec aux i = 
    ignore (f i);
    if is_last_cut n k maxs i then () 
    else aux (next_cut n k maxs i) in
    aux (first_cut n k maxs)


let apply_cut res state cut = 
  let n = Array.length res 
  and k = Array.length cut in 
    for i = 0 to n - 1 do 
      let add = if i + 1 < k then cut.(i+1) else 0 
      and sub = if i - n + k >= 0 then cut.(i - n + k) else 0 in
	res.(i) <- state.(i) + add - sub
    done
      


let make_occupation state = 
  Array.mapi (fun i n -> if n > 0 then [i, n] else []) state 
let find_occupation occ (s, c) = 
  let rec get n = function 
      [] -> if n > 0 then raise Not_found else [], []
    | (i, x)::next -> 
	if x < n then  
	  let a, b = get (n-x) next in 
	    (((i, x)::a), b)
	else let r = if n = x then next else (i, x - n)::next in 
	  ([(i, n)], r) in
  let l = Array.length occ in 
  let res = Array.make l 0 in 
    for i = s - 1 to l - 1 do 
      let a, b = get c.(i) occ.(i) in 
	( occ.(i) <- b;
	  List.iter (fun (j, x) -> res.(j) <- res.(j) + x) a;
	  if i >= s then occ.(i - s) <- a@occ.(i-s) )
    done;
    res

let greedy_occupation occ s n = 
  let rec get_max n = function 
      [] -> n, [], []
    | (i, x)::next -> 
	if x < n then  
	  let r, a, b = get_max (n-x) next in 
	    (r, ((i, x)::a), b)
	else let r = if n = x then next else (i, x - n)::next in 
	  (0, [(i, n)], r) in
  let l = Array.length occ in 
  let res = Array.make l 0 in 
  let rec fill k u = 
    if u <= 0 then res
    else if k >= l then raise Not_found
    else let r, a, b = get_max u occ.(k) in 
      ( Printf.printf "u = %d; k = %d; get_max gives %d\n" u k r;
	occ.(k) <- b;
	List.iter (fun (j, x) -> res.(j) <- res.(j) + x) a;
	if k >= s then occ.(k - s) <- a@occ.(k - s); 
	fill (k+1) r ) in
    fill (s-1) n


(* This version is for nodes with weight (= more than one procs per node)
   but no properties. *)

let no_properties_general cmp_val sum_val start 
  ?(print_task = ignore) 
  ?(print_choice = ignore)
  list procs_fun nodes_fun w_fun state = 

  let k = Array.length state in 
  let max_vect = let t = Array.make k 0 and x = ref 0 in 
    for i = k - 1 downto 0 do x := !x + state.(i); t.(i) <- !x; done; t in 

  let best_choice val_fun x s = 
    let procs = procs_fun x in
    let nodes = nodes_fun x in 
    let nb_inter = k - procs + 1 in
    let bonus = w_fun x in 
    let best_result = ref (val_fun s, None) in 
    let maxs = Array.sub s (procs - 1) nb_inter in
    let s2 = Array.copy s in 
    let try_one_cut c = 
      apply_cut s2 s c;
      let v = fst (!best_result)
      and u = sum_val bonus (val_fun s2) in 
	if cmp_val u v > 0 then 
	  best_result := (u, Some (Array.copy s2, (Array.copy c))) in
      if nb_inter > 0 then 
	( try iter_cut nodes nb_inter maxs try_one_cut
	  with Failure "Cuts" -> () );
      match !best_result with 
	  (v, None) -> ((x, None), s, v)
	| (v, Some (s2, c)) -> ((x, Some c), s2, v) in
    
  let res = Dynamic_program.general list max_vect state best_choice start in 

  let accepted, dismissed = 
    Outils.filter_map (function 
			   x, None -> Outils.Two x
			 | x , Some c -> Outils.One (x, c) ) res in

    List.iter print_task dismissed;
    List.iter print_choice accepted;

  let occupation = make_occupation state in 
    ( List.map (fun (x, c) -> (x, find_occupation occupation (procs_fun x, c))) accepted, 
      dismissed )
    

let no_properties_int l = no_properties_general compare (+) 0 l


(* With properties. Now state is an int array array. state.(i).(j) 
   is the nb of nodes with j procs in the i-th group. 

   It is *not* assumed that all state.(i) have same dimension.

   groups_fun should take a task and return the list of groups it can be assigned to *)
    
let properties_general cmp_val sum_val start_val
  ?(print_task = ignore) 
  ?(print_choice = ignore)
  ?start_occupation
  list procs_fun nodes_fun w_fun groups_fun state = 

  let nb_groups = Array.length state in 

  let make_one_max_vect state_group = 
    let k = Array.length state_group in 
    let max_vect = 
      let t = Array.make k 0 and x = ref 0 in 
	for j = k - 1 downto 0 do 
	  x := !x + state_group.(j); t.(j) <- !x; done; t in 
      max_vect in 
  let max_vects = Array.map make_one_max_vect state in 
  let global_max = Array.concat (Array.to_list max_vects) 
  and global_state = Array.concat (Array.to_list state) in 

  let ks = Array.map Array.length state in 
  let starting_pos = Outils.partial_sums ks in
    
  let dim = Array.length global_max in 

  let best_choice val_fun x s = 
    let sbis = Array.copy s in 
    let groups = groups_fun x  
    and procs = procs_fun x 
    and nodes = nodes_fun x 
    and bonus = w_fun x in 
    let best_result = ref (val_fun s, None) in 

    let maxs = 
      let t = Array.make dim 0 in
      let fill_group g = 
	let start = starting_pos.(g) + procs - 1 
	and len = ks.(g) - procs + 1 in 
	  Array.blit s start t start len in 
	List.iter fill_group groups; 
	t in 

    let apply_big_cut res cut = 
      for g = 0 to nb_groups - 1 do
	let n = ks.(g) 
	and start = starting_pos.(g) in 
	  for i = 0 to n - 1 do 
	    let add = if i + procs < n then cut.(start + i + procs) else 0
	    and sub = cut.(start + i) in 
	      res.(start + i) <- s.(start + i) + add - sub
	  done;
      done in 

    let s2 = Array.copy s in 
    let try_one_cut c = 
      apply_big_cut s2 c;
      let v = fst !best_result
      and o = sum_val bonus (val_fun s2) in 
	if cmp_val o v > 0 then 
	  best_result := (o, Some (Array.copy s2, 
				   Array.copy c)) in
      ( try iter_cut nodes dim maxs try_one_cut
	with Failure "Cuts" -> () );
      match !best_result with 
	  (v, None) -> ((x, None), sbis, v) 
	| (v, Some (glob, cut)) -> 
	    ((x, Some cut), glob, v) in 
    
  let res = Dynamic_program.general list global_max global_state best_choice start_val in
    
  let transform_full_cut c = 
    let res = Array.init nb_groups (fun i -> Array.make (Array.length state.(i)) 0) in 
      for g = 0 to nb_groups - 1 do 
	for i = 0 to ks.(g) - 1 do 
	  res.(g).(i) <- c.(starting_pos.(g) + i);
	done;
      done; 
      res in 
    
  let accepted, dismissed = 
    Outils.filter_map (function (x, None) -> Outils.Two x
			 | (x, Some c) -> Outils.One (x, transform_full_cut c)) res in

    List.iter print_task dismissed;
    List.iter print_choice accepted;
    
    (* Now I have to handle accepted tasks *)

    let occupation = 
      match start_occupation with 
	  None -> Array.map make_occupation state
	| Some s -> s in 
    let find_for_one (x, c) = 
      let s = procs_fun x in 
      let res = Array.init nb_groups 
		  (fun g -> find_occupation occupation.(g) (s, c.(g))) in 
	
	(x, res) in  
      
      (List.map find_for_one accepted, dismissed) 


let heuristic_properties  ?(print_task = ignore) 
    ?(print_choice = ignore)
    list procs_fun nodes_fun w_fun groups_fun state = 

  let nb_groups = Array.length state in 

  let zeros = Array.init nb_groups (fun i -> Array.make (Array.length state.(i)) 0) in 

  let rec simplify list pre_schedule pre_occupation = 
(*    Printf.printf "Starting to simplify ...:";
    Array.iter (Array.iter (Printf.printf "%d ")) state;
    print_newline(); *)

(*    let max_usage = 
      let tmp = Array.map Array.copy zeros in 
      let one_task t = 
	let one_group g = 
	  let p = (procs_fun t) - 1 in 
	    if p < Array.length tmp.(g) then 
	      tmp.(g).(p) <- tmp.(g).(p) + (nodes_fun t) in 
	  List.iter one_group (groups_fun t) in 
	List.iter one_task list; tmp in *)
      
    let rec find_easy_group groups_buf task_list occupation g = 
      if g >= nb_groups then groups_buf, task_list
      else begin
	let try_occupation = Array.copy occupation.(g) in 
	let rec handle task_buf = function 
	    [] -> task_buf 
	  | t::ts -> 
	      match try Some (greedy_occupation try_occupation (procs_fun t) (nodes_fun t))
	      with Not_found -> None with 
		  Some cut -> handle ((t, cut)::task_buf) ts
		| None -> [] in 
	  let in_group, not_in_group = 
	    List.partition (fun t -> List.mem g (groups_fun t)) task_list in

	    match handle [] (List.sort (Outils.cmp (fun t -> -(procs_fun t))) in_group) with 
		[] -> find_easy_group groups_buf task_list occupation (g+1)
	      | l -> 
		  ( (* List.iter (fun (_, c) -> apply_cut state.(g) state.(g) c) l; *)
		    occupation.(g) <- try_occupation; 
		    let full_cut_list = 
		      List.map (fun (x, c) -> let tmp = Array.copy zeros in 
				  tmp.(g) <- c; (x, tmp)) l in
		      find_easy_group (full_cut_list@groups_buf) not_in_group occupation (g+1) )
      end in 

    let schedule, remaining_tasks = find_easy_group [] list pre_occupation 0 in 
      match schedule with 
	  [] -> ( (*Printf.printf "End of simplification\n";*) (list, pre_schedule))
	| _ -> simplify remaining_tasks (schedule@pre_schedule) pre_occupation in 
    
  let occup = Array.map make_occupation state in
  let list, sch = simplify list [] occup in 
    
    (*print_endline "--------------";
    List.iter print_choice sch;
    print_endline "--------------";
    flush stdout; *)
    
    (* additional optimizations : 
     * I could get rid of the groups that were not constrained -- no task can be sent to them 
     * I could group tasks that behave the same -- same procs, nodes, and groups. Just remember 
     *   their weight, and sort them *)

    (* It would also be nice to take the besteffort jobs into account. *)

    let a, d = 
      properties_general compare (+) 0 
	~print_task ~print_choice ~start_occupation:occup
	list procs_fun nodes_fun w_fun groups_fun state in 
      
      (sch@a, d)

(* type x = {id : int;
	  nodes: int;
	  procs: int;
	  w: int; }
  

let t = [{id = 0; nodes = 3; procs = 1; w = 1; };
	 {id = 1; nodes = 1; procs = 4; w = 1; };
	 {id = 2; nodes = 2; procs = 3; w = 1; }; 
	 {id = 3; nodes = 1; procs = 2; w = 2; }   ]

let m = [|10; 0; 0; 2|]

let n x = x.nodes
let p x = x.procs
let w x = x.w

(* 
open Dynamic_program;;
program_int t p n w m;; 
*)

let _ = program_int t p n w m *)
