open Int64
open Interval

type time_t = int64

type job = {
	mutable time_b : time_t; 
	walltime : time_t;

	hy_level_rqt : string list list;
  hy_nb_rqt : int list list;

  types : (string * string) list; 

  constraints : set_of_resources list;
	mutable set_of_rs : set_of_resources;
}

(*
let job_to_string t = let itv2str itv = Printf.sprintf "[%d,%d]" itv.b itv.e in
                      
  (String.concat ", " (List.map itv2str t.set_of_rs)) ^ (Printf.sprintf " Types: %s\n" (Helpers.concatene_sep "," Helpers.id t.types)) ^
  
  (Printf.sprintf "h_type: "^ (String.concat "*" (List.flatten t.hy_level_rqt)))^
  (Printf.sprintf "\nh_type: "^ (String.concat "*" (List.map string_of_int (List.flatten t.hy_nb_rqt)))) 

let resource_to_string n = 
  Printf.sprintf "(%d) -%s- %s" 
    n.resource_id (rstate_to_string n.state) n.network_address
*)
