
let general list max_values start_state best_choice_fun start_value = 
  let k = Array.length max_values in 
  let bases, l = 
    let t = Array.make k 0 in 
    let b = ref 1 in 
      for i = 0 to k-1 do 
	t.(i) <- !b; b := !b * (max_values.(i) + 1); 
      done; 
      t, !b in 
  let res_ind_to_state = Array.make k 0 in
  let index_to_state i = 
    let res = Array.copy res_ind_to_state in 
    let rec aux j t = 
      if t > 0 & j >= 0 then 
	let u = t / bases.(j) and v = t mod bases.(j) in 
	  res.(j) <- u; aux (j-1) v in
      aux (k-1) i; res in 
  let state_to_index t = 
    let res = ref 0 in 
      for i = 0 to k-1 do 
	res := !res + t.(i) * bases.(i); done;
      !res in

  let objs = Array.of_list list in 
  let nbobjs = Array.length objs in 
    if nbobjs = 0 then [] 
    else 
      let whole_state = Array.init nbobjs (fun i -> Hashtbl.create 1000) in 
	(* Maybe I should code it as a sparse thing... *)	
      let rec compute index obj = 
	try Hashtbl.find whole_state.(obj) index 
	with Not_found -> 
	  let val_fun = 
	    if obj + 1 < nbobjs then function s -> fst (compute (state_to_index s) (obj+1))
	    else function s -> start_value in 
	  let (c, s, nv) = best_choice_fun val_fun objs.(obj) (index_to_state index) in 
	  let other_index = 
	    if obj + 1 < nbobjs then 
	      let i = state_to_index s in
		( if not (Hashtbl.mem whole_state.(obj+1) i) then  
		    Printf.printf "Index %d wrong for obj %d\n" i obj);
		i
	    else -1 in
	  let nx = (nv, (c, other_index)) in 
	    ( Hashtbl.add whole_state.(obj) index nx; 
	      nx ) in
	
      let rec build buf i obj = 
	if i = -1 then buf 
	else 
	  let (_, (c, oi)) = 
	    try Hashtbl.find whole_state.(obj) i
	    with Not_found -> failwith "general" in 
	    build (c::buf) oi (obj+1) in 
      let (c, i) = snd (compute (state_to_index start_state) 0) in 
	List.rev (build [c] i 1)
	  

let general_exhaustive list max_values start_state best_choice_fun start_value = 
  let k = Array.length max_values in 
  let bases, l = 
    let t = Array.make k 0 in 
    let b = ref 1 in 
      for i = 0 to k-1 do 
	t.(i) <- !b; b := !b * (max_values.(i) + 1); 
      done; 
      t, !b in 
  let res_ind_to_state = Array.make k 0 in 
  let index_to_state i = 
    let res = Array.copy res_ind_to_state in 
    let rec aux j t = 
      if t > 0 & j >= 0 then 
	let u = t / bases.(j) and v = t mod bases.(j) in 
	  res.(j) <- u; aux (j-1) v in
      aux (k-1) i; res in 
  let state_to_index t = 
    let res = ref 0 in 
      for i = 0 to k-1 do 
	res := !res + t.(i) * bases.(i); done;
      !res in

  let rec aux old_state new_state = function 
      [] -> snd old_state.(state_to_index start_state)
    | x::xs -> 
	for i = 0 to l - 1 do 
          let val_fun s = fst old_state.(state_to_index s) in
          let (c, s, nv) = best_choice_fun val_fun x (index_to_state i) in 
            new_state.(i) <- (nv, c::(snd old_state.(state_to_index s))) 
	done;
	aux new_state old_state xs in
  let make_state () = Array.make l (start_value, []) in
    aux (make_state()) (make_state()) list
