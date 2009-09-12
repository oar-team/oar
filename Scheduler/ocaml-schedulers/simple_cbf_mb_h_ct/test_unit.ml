open Interval
open Types
open Hierarchy
open Helpers
open Simple_cbf_mb_h_ct
open OUnit

let h0 = [{b = 1; e = 16};{b = 17; e = 32};];;
let h1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let h2 = [{b = 1; e = 4}; {b = 5; e = 8}; {b = 9; e =12}; {b = 13; e = 16};
          {b = 17; e = 20}; {b = 21; e = 24}; {b = 25; e = 28}; {b = 29; e = 32}];;

hierarchy_levels := [ ("node",h0);("cpu",h1);("core",h2) ];;
let master_top = {b = 1; e = 32} ;; 

let c0 = [{b = 1; e = 40}] ;;  
let j1 = { time_b = 0L; walltime = 3L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[4]]; constraints =[c0]; set_of_rs = []; types = []};;

let slots_init = [slot_max 100];;
let h_slots_0 = couples2hash [(0,slots_init)];;

let j0 = { time_b = 0L; walltime = 3L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[4]]; constraints =[[{b = 1; e = 40}]]; set_of_rs = []; types = []};;

let h_j0 = couples2hash [(1,j0)];;



let j10 = {time_b = 0L; walltime = 40L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[4]]; constraints = [[{b = 1; e = 40}]]; set_of_rs = [] ; types = [("container","")]};;
let j11 = {time_b = 0L; walltime = 20L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[1]]; constraints = [[{b = 1; e = 40}]]; set_of_rs = [] ; types = [("inner","1")]};;


let assign_ct_0 = [{time_b = 0L; walltime = 40L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[4]];
  types = [("container", "")]; constraints = [[{b = 1; e = 40}]];
  set_of_rs =
   [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}]};
 {time_b = 0L; walltime = 20L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[1]];
  types = [("inner", "1")]; constraints = [[{b = 1; e = 40}]];
  set_of_rs = [{b = 1; e = 8}]}];;



(* simple job scheduling *)
let test_schedule_jobs_0 _ =
  let c0 = [{b = 1; e = 40}] in  
  let j0 = { time_b = 0L; walltime = 3L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[4]]; constraints =[c0]; set_of_rs = []; types = []} in
  let assign_j0 = [ {time_b = 0L; walltime = 3L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[4]];
                    constraints = [[{b = 1; e = 40}]]; set_of_rs = [{b = 1; e = 8}; {b = 9; e = 16};{b = 17; e = 24}; {b = 25; e = 32}] ; types = []} ] in
    
    assert_equal assign_j0 (schedule_jobs [j0] [slot_max 100])

(* test with job start time (time_b) not equal to 0 needed to support job dependencies *)
let test_schedule_jobs_start_time _ =
  let c0 = [{b = 1; e = 40}] in
  let j0 = { time_b = 100L; walltime = 3L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[4]]; constraints =[c0]; set_of_rs = []; types = []} in
  let j1 = { time_b = 0L; walltime = 300L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[4]]; constraints =[c0]; set_of_rs = []; types = []} in
  let j2 = { time_b = 0L; walltime = 30L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[4]]; constraints =[c0]; set_of_rs = []; types = []} in
  let assign_j012 = [
    {time_b = 100L; walltime = 3L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[4]]; types = []; constraints = [[{b = 1; e = 40}]]; set_of_rs = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}]}; 
    {time_b = 103L; walltime = 300L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[4]]; types = []; constraints = [[{b = 1; e = 40}]]; set_of_rs = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}]};
      {time_b = 0L; walltime = 30L; hy_level_rqt = [["cpu"]]; hy_nb_rqt = [[4]]; types = []; constraints = [[{b = 1; e = 40}]]; set_of_rs = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}]}
      ] in
    assert_equal assign_j012 (schedule_jobs [j0;j1;j2] [slot_max 100])



(* test set_slots_with_prev_scheduled_jobs with container considerations *)
let test_schedule_ct_0 _ =
  let h_j = couples2hash [(1,j10);(2,j11)] in
  let h_slots_0 = couples2hash [(0,[slot_max 100])] in
    assert_equal assign_ct_0 (schedule_id_jobs_ct h_slots_0 h_j [1;2])

let suite = "Unit test for simple_cbf_mb_h_ct" >::: [
  (*        "test_schedule_jobs_0" >:: test_schedule_jobs_0; *)
          "test_schedule_jobs__start_time" >:: test_schedule_jobs_start_time;
          "test_schedule_ct_0" >:: test_schedule_ct_0;
        ]

let _ =
  run_test_tt ~verbose:true suite

