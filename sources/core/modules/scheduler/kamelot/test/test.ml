(*                                                                *)
(* This file is not use for compilation only for debuging purpose *)
(* to track jobs' overlapping bug                                 *)
(* Author: auguste@imag.fr                                        *)
(*                                                                *)

(*
Bug on itv ordering
# s3;;
- : Simple_cbf_mb_h_ct.slot =
{time_s = 0L; time_e = 2147483648L; set_of_res = [{b = 1; e = 5}]}
# split_slots_prev_scheduled_one_job [s3] j24;;
- : Simple_cbf_mb_h_ct.slot list =
[{time_s = 0L; time_e = 80L; set_of_res = [{b = 5; e = 5}; {b = 1; e = 2}]};
 {time_s = 81L; time_e = 2147483648L; set_of_res = [{b = 1; e = 5}]}]

-> split_slots [s3] j24;; -> sub_intervals s3.set_of_res j24.set_of_rs;;
- : Interval.interval list = [{b = 5; e = 5}; {b = 1; e = 2}]

Expected:
- : Simple_cbf_mb_h_ct.slot list =
[{time_s = 0L; time_e = 80L; set_of_res = [{b = 1; e = 2};{b = 5; e = 5};]};
 {time_s = 81L; time_e = 2147483648L; set_of_res = [{b = 1; e = 5}]}]

 sub_intervals [{b = 1; e = 5}] [{b = 3; e = 4}; {b = 12; e = 12}];;
[{b = 1; e = 2};{b = 5; e = 5};]

*)

open Interval;;
open Hierarchy;;
open Scheduling;;
open Types;;

let hierarchy_levels = ref  [ ("resource_id",[{b = 1; e = 12}]) ];;
let toplevel_itv = ref {b = 1; e = 12} ;;

(* let smax = slot_max 12;;*)
let s0 = {time_s = 0L; time_e = 2147483648L; set_of_res = [{b = 1; e = 12}]};;

let s1 =  {time_s = 0L; time_e = 2147483648L; set_of_res = [{b=7;e=8}; {b=5;e=5}; {b=1;e=2};{b=11;e=11}]};;
let s2 =  {time_s = 0L; time_e = 2147483648L; set_of_res = [{b=5;e=5}; {b=1;e=2}]};;
let s3 =  {time_s = 0L; time_e = 2147483648L; set_of_res = [{b = 1; e = 5}; {b = 7; e = 8}; {b = 11; e = 12}]};;
let s3 =  {time_s = 0L; time_e = 2147483648L; set_of_res = [{b = 1; e = 5}; {b = 7; e = 8}]};;

let s3 =  {time_s = 0L; time_e = 2147483648L; set_of_res = [{b = 1; e = 5}]};;
let hslots = Hashtbl.create 10;;
Hashtbl.add hslots 0 [s0];
;;


(* Prev
now= 1328014985
job_id: 27 start_time: 1328014984 walltime: 88  res_itv: [6,6], [9,10]
88-1 = 87
job_id: 24 start_time: 1328014978 walltime: 88  res_itv: [3,4], [12,12]
88-7 = 81
job_id: 23 start_time: 1328014975 walltime: 88  res_itv: [1,2], [11,11]
88-10 = 78
job_id: 19 start_time: 1328014867 walltime: 258  res_itv: [7,8]
258 - 118 =140
job_id: 17 start_time: 1328014862 walltime: 336  res_itv: [5,5]
336 - 123 = 213

*)

(*
let j27 = {jobid = 27; moldable_id = 27; jobstate = ""; time_b = 0L; w_time= 87L;
 types = []; hy_level_rqt = [["resource_id"]]; hy_nb_rqt = [[3]]; constraints = [[{b = 1; e = 12}]];
 set_of_rs = [{b = 6; e = 6};{b = 9; e = 10}]; rq={}}
;;
*)

let j27 = {jobid = 27; moldable_id = 27; jobstate = ""; user = ""; project = ""; time_b = 0L; w_time= 87L;
 types = []; set_of_rs = [{b = 6; e = 6};{b = 9; e = 10}];
 rq = [{mlb_id = 27; walltime = 87L; constraints = [[{b = 1; e = 12}]]; hy_level_rqt =  [["resource_id"]]; hy_nb_rqt = [[3]];}]
 }
;;


let j24 = {jobid = 24; moldable_id = 24; jobstate = ""; user = ""; project = ""; time_b = 0L; w_time= 81L;
 types = []; set_of_rs = [{b = 3; e = 4};{b = 12; e = 12}];
 rq = [{mlb_id = 24; walltime = 81L; constraints = [[{b = 1; e = 12}]]; hy_level_rqt =  [["resource_id"]]; hy_nb_rqt = [[3]];}]
}
;;

let j23 = {jobid = 23; moldable_id = 23; jobstate = ""; user = ""; project = ""; time_b = 0L; w_time= 78L;
 types = []; set_of_rs = [{b = 1; e = 2};{b = 11; e = 11}];
 rq = [{mlb_id = 23; walltime = 78L; constraints = [[{b = 1; e = 12}]]; hy_level_rqt =  [["resource_id"]]; hy_nb_rqt = [[3]];}]
}
;;

let j19 = {jobid = 19; moldable_id = 19; jobstate = ""; user = ""; project = ""; time_b = 0L; w_time= 140L;
 types = []; set_of_rs = [{b = 7; e = 8}];
 rq = [{mlb_id = 18; walltime = 140L; constraints = [[{b = 1; e = 12}]]; hy_level_rqt =  [["resource_id"]]; hy_nb_rqt = [[2]];}]
}
;;

let j17 = {jobid = 17; moldable_id = 17; jobstate = ""; user = ""; project = ""; time_b = 0L; w_time= 213L;
 types = []; set_of_rs = [{b = 5; e = 5}];
 rq = [{mlb_id = 17; walltime = 213L; constraints = [[{b = 1; e = 12}]]; hy_level_rqt =  [["resource_id"]]; hy_nb_rqt = [[1]];}]
}
;;

let j0 = {jobid = 0; moldable_id = 0; jobstate = ""; user = ""; project = ""; time_b = 0L; w_time= 81L;
 types = []; set_of_rs = [{b = 3; e = 4}];
 rq = [{mlb_id = 2; walltime = 81L; constraints = [[{b = 1; e = 12}]]; hy_level_rqt =  [["resource_id"]]; hy_nb_rqt = [[2]];}]
}
;;

let hjobs =  Hashtbl.create 10;;
Hashtbl.add hjobs 27 j27;
Hashtbl.add hjobs 24 j24;
Hashtbl.add hjobs 23 j23;
Hashtbl.add hjobs 19 j19;
Hashtbl.add hjobs 17 j17;
;;

let slot0 = try Hashtbl.find hslots 0 with  Not_found -> failwith "bou" in Conf.log ("slot0:\n" ^ (Helpers.concatene_sep "\n   " slot_to_string slot0));

(* let jobids = [27;24;23;19;17];; *) (* BOU *)
(* let jobids = [17;19;23;24;27];; *)
let jobids = [27;24;23;];; (* Bou *)

set_slots_with_prev_scheduled_jobs hslots hjobs jobids 60L;;

let hjobs23 =  Hashtbl.create 10;;
Hashtbl.add hjobs23 23 j23;
;;

let jobids23 = [23];;

let hslots23 = Hashtbl.create 10;;
Hashtbl.add hslots23 0 [s0];
;;
let slot23 = try Hashtbl.find hslots23 0 with  Not_found -> failwith "hash" in Conf.log ("slot23:\n" ^ slots_to_string slot23);

set_slots_with_prev_scheduled_jobs hslots23 hjobs23 jobids23 60L;;

(*                                                          *)
(* test bug from gofree observation                         *)
(* - left slot disparition during previous job insertion in *)
(*   slots                                                  *)

(*    split_slots_prev_scheduled_one_job : l_slots oblivion *)


open Interval;;
open Hierarchy;;
open Scheduling;;
open Types;;


let display_slot0 h_s0 = let slots0 = try Hashtbl.find h_s0 0 with  Not_found -> failwith "hash" in Conf.log ("slot0:\n" ^ slots_to_string slots0);
;;

(* let smax = slot_max 12;;*)
let s0 = {time_s = 10L; time_e = 2147483648L; set_of_res = [{b = 1; e = 12}]};;

let j00 = {jobid = 0; moldable_id = 1; jobstate = ""; user = ""; project = ""; time_b = 0L; w_time= 100L; types = []; set_of_rs = [{b = 1; e = 10}]; rq = [] } ;;

let j10 = {jobid = 1; moldable_id = 1; jobstate = ""; user = ""; project = ""; time_b = 10L; w_time= 90L; types = []; set_of_rs = [{b = 1; e = 10}]; rq = [] } ;;

let j11 = {jobid = 2; moldable_id = 2; jobstate = ""; user = ""; project = ""; time_b = 100L; w_time= 100L; types = []; set_of_rs = [{b = 1; e = 10}]; rq = [] } ;;

let hjobs =  Hashtbl.create 10;;
Hashtbl.add hjobs 0 j00;
Hashtbl.add hjobs 1 j10;
Hashtbl.add hjobs 2 j11;
;;

let hslots0 = Hashtbl.create 10;;
Hashtbl.add hslots0 0 [s0];
;;

let jobids = [1;2]
;;

set_slots_with_prev_scheduled_jobs hslots0 hjobs jobids 60L;;
display_slot0 hslots0;;

let slot0 = try Hashtbl.find hslots0 0 with  Not_found -> failwith "hash" in Conf.log ("slot0:\n" ^ slots_to_string slot0);


let lst_s00 = split_slots_prev_scheduled_one_job [s0] j00
;;

(*
[0,2] -> bug
    [slot: time_s 100, time_e: 199 itv:={ [11,12]}|slot: time_s 200, time_e: 2147483648 itv:={ [1,12]}]

Good ->
    [slot: time_s 10, time_e: 99 itv:={ [11,12]}|slot: time_s 100, time_e: 199 itv:={ [11,12]}|slot: time_s 200, time_e: 2147483648 itv:={ [1,12]}]

[1,2] -> bug
    [slot: time_s 100, time_e: 199 itv:={ [11,12]}|slot: time_s 200, time_e: 2147483648 itv:={ [1,12]}]

Good ->
    [slot: time_s 10, time_e: 99 itv:={ [11,12]}|slot: time_s 100, time_e: 199 itv:={ [11,12]}|slot: time_s 200, time_e: 2147483648 itv:={ [1,12]}]

*)

(*
 lst_s00;;
- : Scheduling.slot list =
[{time_s = 10L; time_e = 99L; set_of_res = [{b = 11; e = 12}]};
 {time_s = 100L; time_e = 2147483648L; set_of_res = [{b = 1; e = 12}]}]
#

  j11;;
- : Types.job =
{jobid = 2; jobstate = ""; user = ""; project = ""; moldable_id = 2;
 time_b = 100L; w_time = 100L; types = []; set_of_rs = [{b = 1; e = 10}];
 rq = []}
#

      split_slots_prev_scheduled_one_job lst_s00 j11;;

- : Scheduling.slot list =
[{time_s = 100L; time_e = 199L; set_of_res = [{b = 11; e = 12}]};
 {time_s = 200L; time_e = 2147483648L; set_of_res = [{b = 1; e = 12}]}]

val lst_s11 : Scheduling.slot list =
  [{time_s = 0L; time_e = 9L; set_of_res = [{b = 5; e = 6}]};
   {time_s = 10L; time_e = 99L; set_of_res = [{b = 11; e = 12}]};
   {time_s = 100L; time_e = 2147483648L; set_of_res = [{b = 1; e = 12}]}]
# split_slots_prev_scheduled_one_job lst_s11 j11;;
- : Scheduling.slot list =
[{time_s = 100L; time_e = 199L; set_of_res = [{b = 11; e = 12}]};
 {time_s = 200L; time_e = 2147483648L; set_of_res = [{b = 1; e = 12}]}]

*)
