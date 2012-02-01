open Interval;;
open Hierarchy;;
open Simple_cbf_mb_h_ct;;
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

let j27 = {jobid = 27; moldable_id = 27; jobstate = ""; time_b = 0L; walltime = 87L;
 types = []; hy_level_rqt = [["resource_id"]]; hy_nb_rqt = [[3]]; constraints = [[{b = 1; e = 12}]]; 
 set_of_rs = [{b = 6; e = 6};{b = 9; e = 10}]}
;;
let j24 = {jobid = 24; moldable_id = 24; jobstate = ""; time_b = 0L; walltime = 81L;
 types = []; hy_level_rqt = [["resource_id"]]; hy_nb_rqt = [[3]]; constraints = [[{b = 1; e = 12}]]; 
 set_of_rs = [{b = 3; e = 4};{b = 12; e = 12}]}
;;
let j23 = {jobid = 23; moldable_id = 23; jobstate = ""; time_b = 0L; walltime = 78L;
 types = []; hy_level_rqt = [["resource_id"]]; hy_nb_rqt = [[3]]; constraints = [[{b = 1; e = 12}]]; 
 set_of_rs = [{b = 1; e = 2};{b = 11; e = 11}]}
;;
let j19 = {jobid = 19; moldable_id = 19; jobstate = ""; time_b = 0L; walltime = 140L;
 types = []; hy_level_rqt = [["resource_id"]]; hy_nb_rqt = [[2]]; constraints = [[{b = 1; e = 12}]]; 
 set_of_rs = [{b = 7; e = 8}]}
;;
let j17 = {jobid = 17; moldable_id = 17; jobstate = ""; time_b = 0L; walltime = 213L;
 types = []; hy_level_rqt = [["resource_id"]]; hy_nb_rqt = [[1]]; constraints = [[{b = 1; e = 12}]]; 
 set_of_rs = [{b = 5; e = 5}]}
;;

let j0 = {jobid = 0; moldable_id = 0; jobstate = ""; time_b = 0L; walltime = 81L;
 types = []; hy_level_rqt = [["resource_id"]]; hy_nb_rqt = [[2]]; constraints = [[{b = 1; e = 12}]]; 
 set_of_rs = [{b = 3; e = 4}]}
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
let jobids = [27;24;23;]





set_slots_with_prev_scheduled_jobs hslots hjobs jobids 60L;;


let hjobs23 =  Hashtbl.create 10;;
Hashtbl.add hjobs23 23 j23;
;;
let jobids23 = [23];;

let hslots23 = Hashtbl.create 10;;
Hashtbl.add hslots23 0 [s0]; 
;;
let slot23 = try Hashtbl.find hslots23 0 with  Not_found -> failwith "bou" in Conf.log ("slot23:\n" ^ (Helpers.concatene_sep "\n   " slot_to_string slot23));

set_slots_with_prev_scheduled_jobs hslots23 hjobs23 jobids23 60L;;




