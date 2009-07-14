open Interval
open Types
open Hierarchy
open Simple_cbf_mb_h
open OUnit

let h0 = [{b = 1; e = 16};{b = 17; e = 32};];;
let h1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let h2 = [{b = 1; e = 4}; {b = 5; e = 8}; {b = 9; e =12}; {b = 13; e = 16};
          {b = 17; e = 20}; {b = 21; e = 24}; {b = 25; e = 28}; {b = 29; e = 32}];;

let hierarchy_levels = [ ("node",h0);("cpu",h1);("core",h2) ];;

let c0 = [{b = 1; e = 40}] ;;  
let j1 = { time_b = 0L; walltime = 3L; hy_level_rqt = ["cpu"]; hy_nb_rqt = [4]; constraints =c0; set_of_rs = []};;


let test_find_hierarchy_homogenous_h1_0 _ =
 (* let h =  [|h0|] in  *)
  let h = [|[{b = 1; e = 16};{b = 17; e = 32};]|]  in
  let r =  [|2|] in
      assert_equal []  (find_resource_hierarchies [{b = 16; e = 23}] h r);
      assert_equal []  (find_resource_hierarchies [{b= 7;e=30}] h r);
      assert_equal [[{b = 1; e = 16}; {b = 17; e = 32}]]  (find_resource_hierarchies [{b= 1;e=32}] h r)

let test_find_hierarchy_homogenous_h1_1 _ =
  let h =  [|h1|] in 
  let res1 = [{b = 1; e = 8}; {b = 9; e = 16}] in
  let res2 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}] in
  let res3 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 25; e = 32}] in

    assert_equal [res1] (find_resource_hierarchies [{b = 1; e = 32}] h [|2|]);
    assert_equal [res2] (find_resource_hierarchies [{b = 1; e = 32}] h [|4|]);
    assert_equal [res3] (find_resource_hierarchies [{b = 1; e = 18};{b = 23; e = 32}] h [|3|]);
    assert_equal [] (find_resource_hierarchies [{b = 4; e = 18};{b = 23; e = 32}] h [|3|])

let test_find_hierarchy_homogenous_h2 _ =
  let h =  [|h0;h1|] in 
  let r =  [|2;1|] in

    assert_equal [[{b = 17; e = 24}]; [{b = 1; e = 8}]] (find_resource_hierarchies [{b=1;e=80}] h r);
    assert_equal [] (find_resource_hierarchies [{b= 7;e=20}] h r);
    assert_equal [[{b = 17; e = 24}]; [{b = 9; e = 16}]] (find_resource_hierarchies [{b= 7;e=30}]  h r)


let test_schedule_jobs_0 _ =
  let c0 = [{b = 1; e = 40}] in  
  let j0 = { time_b = 0L; walltime = 3L; hy_level_rqt = ["cpu"]; hy_nb_rqt = [4]; constraints =c0; set_of_rs = []} in
  let assign_j0 = [{time_b = 0L; walltime = 3L; hy_level_rqt = ["cpu"]; hy_nb_rqt = [4];
    constraints = [{b = 1; e = 40}]; set_of_rs = [{b = 25; e = 32}; {b = 17; e = 24}; {b = 9; e = 16}; {b = 1; e = 8}]}] in
    
    assert_equal assign_j0 (schedule_jobs [j0] [slot_max 100])


let suite = "Unit test for simple_cbf_mb_h" >::: [
          "test_find_hierarchy_homogenous_h1_0" >:: test_find_hierarchy_homogenous_h1_0;
          "test_find_hierarchy_homogenous_h1_0" >:: test_find_hierarchy_homogenous_h1_1;
				  "test_find_hierarchy_homogenous_h2" >:: test_find_hierarchy_homogenous_h2; 
          "test_schedule_jobs_0" >:: test_schedule_jobs_0
        ]

let _ =
  run_test_tt ~verbose:true suite


