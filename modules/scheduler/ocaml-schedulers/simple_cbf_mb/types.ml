open Int64
open Interval

type time_t = int64
type job = {
  
	mutable time_b : time_t; 
	walltime : time_t;
	nb_res : int;
	mutable set_of_rs : set_of_resources;
}


