open Mysql
open Int64
open Interval
type time_t = int64
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
	walltime : time_t;
	mutable nb_res : int;
	mutable set_of_rs : set_of_resources;
}

(* Pretty - printing ** TO MOVE in helpers ??? **)

let job_to_string t = let itv2str itv = Printf.sprintf "[%d,%d]" itv.b itv.e in 
  (Printf.sprintf "(%d) start_time %s; walltime %s:" t.jobid (ml642int t.time_b) (ml642int t.walltime)) ^
  (String.concat ", " (List.map itv2str t.set_of_rs))

let resource_to_string n = 
  Printf.sprintf "(%d) -%s- %s" 
    n.resource_id (rstate_to_string n.state) n.network_address
