open Mysql
open Int64
open Interval
type time_t = int64 (* 64 bits int because of unix_time use *)
type jobid_t = int

(* type job_state_t = Running | ToLaunch | Waiting (* Do we need it for simple_cbf_oar ? *) *)
type resource_state_t = Alive | Suspected | Absent 

let rstate_of_string = function
    "Alive" -> Alive
  | "Suspected" -> Suspected
  | "Absent" -> Absent
  | s -> Conf.error (Printf.sprintf "rstate_of_string : unknown state %s" s)

let rstate_to_string  = function 
    Alive -> "Alive"
  | Suspected -> "Suspected"
  | Absent -> "Absent" 

type resource = {
	resource_id: int;
	network_address: string;
  state: resource_state_t;
}

type job =  {
  jobid : jobid_t;
  moldable_id : int;
	mutable time_b : time_t;
	mutable walltime : time_t; (* mutable need to reset besteffort's one*)
  mutable types : string list;
	mutable hy_level_rqt : string list list;  
  mutable hy_nb_rqt : int list list;
  mutable constraints : set_of_resources list; 
	mutable set_of_rs : set_of_resources;
}

(* Pretty - printing ** TO MOVE in helpers ??? **)

let job_to_string t = let itv2str itv = Printf.sprintf "[%d,%d]" itv.b itv.e in
                      
  (Printf.sprintf "(%d) start_time %s; walltime %s:" t.jobid (ml642int t.time_b) (ml642int t.walltime)) ^
  (String.concat ", " (List.map itv2str t.set_of_rs)) ^ (Printf.sprintf " Types: %s\n" (Helpers.concatene_sep "," Helpers.id t.types)) ^
  
  (Printf.sprintf "h_type: "^ (String.concat "*" (List.flatten t.hy_level_rqt)))^
  (Printf.sprintf "\nh_type: "^ (String.concat "*" (List.map string_of_int (List.flatten t.hy_nb_rqt)))) 

let resource_to_string n = 
  Printf.sprintf "(%d) -%s- %s" 
    n.resource_id (rstate_to_string n.state) n.network_address
