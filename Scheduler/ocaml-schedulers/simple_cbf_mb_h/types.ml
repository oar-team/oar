open Int64
open Interval

type time_t = int64

type resource_block = {
  orig : int; 
  bk_size : int; 
  nb_bk : int
}

type set_of_res_block = resource_block list

(*
(* Request of resource block one by level*)
type res_bk_rqt = {
  level_r: int;
  nb_r: int;
}  
*)
type job = {
	mutable time_b : time_t; 
	walltime : time_t;
  (*Mono request *)
	hy_level_rqt : string list;  (*Mono request *) (* need of list of list of string *)
  hy_nb_rqt : int  list;  (*Mono request *) (* need of int of list of string *)

  constraints : set_of_resources;

  (* constraints : set_of_resources * int; int Must be remove *)
  (*nb_res : int; Must be remove *)
	mutable set_of_rs : set_of_resources;
}

let set_res_bk2itv res_bk_l = 
  let rec res_bks2itv r_bk_l itv = match r_bk_l with 
    | [] -> itv
    | (x::n) -> let rec loop_bk i itv1 = 
                  if i = 0 then 
                    res_bks2itv n itv1 
                  else 
                    loop_bk (i-1) ({b = x.orig + x.bk_size * (i-1);  e = x.orig + x.bk_size * i -1;}::itv1)
                in loop_bk x.nb_bk itv
  in res_bks2itv (List.rev res_bk_l) [] ;;

let r_bk1 = {orig=1 ;bk_size=8 ; nb_bk=8 };;
set_res_bk2itv [r_bk1]

let r_bk10 = {orig=1 ;bk_size=2 ; nb_bk=8 };;
let r_bk11 = {orig=17 ;bk_size=4 ; nb_bk=2 };;

