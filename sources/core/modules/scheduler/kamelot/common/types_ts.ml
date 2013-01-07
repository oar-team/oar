open Int64
open Interval
type time_t = int64 (* 64 bits int because of unix_time use *)
type jobid_t = int

(* type job_state_t = Running | ToLaunch | Waiting (* Do we need it for simple_cbf_oar ? *) *)
type resource_state_t = Alive | Suspected | Absent | Dead 

let rstate_of_string = function
    "Alive" -> Alive
  | "Suspected" -> Suspected
  | "Absent" -> Absent
  | "Dead" -> Dead
  | s -> Conf.error (Printf.sprintf "rstate_of_string : unknown state %s" s)

let rstate_to_string  = function 
    Alive -> "Alive"
  | Suspected -> "Suspected"
  | Absent -> "Absent"
  | Dead -> "Dead" 

type placeholder_t = No_Placeholder | Set_Placeholder | Use_Placeholder

type resource = {
  ord_r_id: int;
	resource_id: int;
	network_address: string;
  state: resource_state_t;
  available_upto: time_t;
}

type jreq = {        (* to manage the different request for each moldable id by job *)
  mlb_id : int;      (* modable id *)
  walltime : time_t; (* mutable need to reset besteffort's one*)
  constraints: set_of_resources list;   (* list of constraint - clause SQL WHERE clause *)
  hy_level_rqt : string list list;      (* sum of (list of hierarchiy)  or sum of sub-reservation like switch=1 + nodes=2/cpu=4 *)
  hy_nb_rqt : int list list;            (* the coresponding number or resources requested for  sum of (list of hierarchiy) *)
}

type job = { (* job can be a modable job *)
  jobid : jobid_t;
  jobstate : string;
  user : string;
  project : string;

  mutable moldable_id : int; (* selected moldable_id *)

  mutable time_b : time_t; (* start time *)
  mutable w_time : time_t; (* effective walltime when attr*)

  mutable types : (string * string) list;
  mutable set_of_rs : set_of_resources; (* the assigned resources *)

  mutable ts : bool;           (* timesharing flag *)
  mutable ts_user : string;    (* timesharing on user *)
  mutable ts_jobname : string; (* timesharing on jobname *)
  mutable ph : placeholder_t;  (* placeholder none, set or use *)
  mutable ph_name : string;    (* name of placeholder *)
  mutable rq : jreq list;      (* only one request resource is non moldable *)
(* TODO add used_rq for moldable .....*)


}

(* job_required_status is used for job dependencies *)
type job_required_status = {
(*  jr_id : jobid_t; *)
  jr_state : string;
  jr_jtype : string; 
  jr_exit_code : int;
}

(* jreq to string /!\ WITHOUT constraints *)
let jreq_to_string jreq = 
    "\nmoldable_id: " ^ (string_of_int jreq.mlb_id) ^  "\nwalltime: " ^ (Int64.to_string jreq.walltime) ^        
    "\nhy_level_rqt: [" ^ (String.concat "],[" (List.map (fun x->(String.concat "," x)) jreq.hy_level_rqt)) ^ 
    "]\nhy_nb_rqt: [" ^ (String.concat "],[" (List.map (fun x-> (Helpers.concatene_sep "," (fun b -> string_of_int b) x)) jreq.hy_nb_rqt)) ^
    "]\n"
;;

let job_to_string j = let itv2str itv = Printf.sprintf "[%d,%d]" itv.b itv.e in
  (Printf.sprintf "job_id: %d start_time: %s walltime: %s " j.jobid (Int64.to_string j.time_b) (Int64.to_string j.w_time)) ^ 
  (Printf.sprintf " res_itv: ") ^ (String.concat ", " (List.map itv2str j.set_of_rs)) ^ 
  (Printf.sprintf "\n types: %s " (Helpers.concatene_sep "," (fun n -> String.concat "*" [fst(n);snd(n)]) j.types)) ^
  (Helpers.concatene_sep "\n" (fun x->jreq_to_string x) j.rq)

let resource_to_string n = 
  Printf.sprintf "(%d) -%s- %s" n.resource_id (rstate_to_string n.state) n.network_address
