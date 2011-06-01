

type time_t = int
type taskid_t = int
type nodeid_t = string
type priority_t = int
(* type task_state_t = Running | ToLaunch | Waiting (* D'autres ? *) *)
type node_state_t = Alive | Suspected | Absent

let nstate_of_string = function
    "Alive" -> Alive
  | "Suspected" -> Suspected
  | "Absent" -> Absent
  | s -> Conf.error (Printf.sprintf "nstate_of_string : unknown state %s" s)

let nstate_to_string = function 
    Alive -> "Alive"
  | Suspected -> "Suspected"
  | Absent -> "Absent" 

type node = {
  nodeId: nodeid_t;
  state : node_state_t;
  max_procs:int; 
}

type task = {
  taskId : taskid_t;
  submit_time: time_t;
  nb_procs: int;
  default_alloc: int;
  mutable allocation: int;
  mutable alloc_changed : bool;
  allowed_allocs: int list;
  run_time: int -> time_t;
  priority: priority_t;
  allowed_nodes : node list;
}

type preexisting_task = {
  pre_taskId : taskid_t;
  pre_run_time : time_t;
  pre_nb_procs : int;
  nodes: node list;
  sched_time : time_t;
  besteffort: bool;
(*  state: task_state_t; *)
}

type instance = task list * node list * preexisting_task list

type schedule = ( task * time_t * node list ) list

(* exception impossibleTask of task *)

type scheduler = instance -> schedule


(* Pretty - printing *)

let task_to_string t = 
  Printf.sprintf "(%d) %d procs; [%d-%d] %s; %d"
    t.taskId t.nb_procs
    t.default_alloc t.allocation
    (String.concat ", " (List.map (fun i -> Printf.sprintf "%d:%d" i (t.run_time i)) t.allowed_allocs))
    t.submit_time

let node_to_string n = 
  Printf.sprintf "(%s) -%s- %d" 
    n.nodeId (nstate_to_string n.state) n.max_procs

let pretask_to_string p = 
  Printf.sprintf "(%d) %d procs; @%d %d:%d [%s]; %s"
    p.pre_taskId p.pre_nb_procs
    p.sched_time 
    (List.length p.nodes)
    p.pre_run_time (String.concat "," (List.map (fun n -> n.nodeId) p.nodes))
    (if p.besteffort then "BE" else "notBE")

let assign_to_string (t, time, nodes) =
  let s = String.concat "," 
	    (List.map (fun n -> n.nodeId) nodes) in 
    Printf.sprintf "  %d: %d [%s]" t.taskId time s

