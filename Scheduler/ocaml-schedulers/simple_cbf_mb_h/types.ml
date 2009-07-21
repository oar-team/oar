open Int64
open Interval

type time_t = int64

type job = {
	mutable time_b : time_t; 
	walltime : time_t;
(*
  (*Mono request *)
	hy_level_rqt : string list;  (*Mono request *) (* need of list of list of string *)
  hy_nb_rqt : int  list;  (*Mono request *) (* need of int of list of string *)
*)
	hy_level_rqt : string list list;
  hy_nb_rqt : int list list;  
  
  constraints : set_of_resources list;
	mutable set_of_rs : set_of_resources;
}
