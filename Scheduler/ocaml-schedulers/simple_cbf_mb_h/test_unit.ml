open Hierarchy_test
open Interval
open OUnit

let h0 = [{b = 1; e = 16};{b = 17; e = 32};];;
let h1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;

let test_find_hierarchy_homogenous_h1 _ =
  let h =  [|h0|] in 
  let r =  [|2|] in
  assert_equal [[]]  (find_resource_hierarchies2 [{b = 16; e = 23}] h r)

let test_find_hierarchy_homogenous_h2 _ =
  let h =  [|h0|] in 
  let r =  [|2|] in
  assert_equal [[]]  (find_resource_hierarchies2 [{b = 16; e = 23}] h r)

let suite = "Unit test for simple_cbf_mb_h" >::: ["test_find_hierarchy_homogenous_h1" >:: test_find_hierarchy_homogenous_h1;
				  "test_find_hierarchy_homogenous_h2" >:: test_find_hierarchy_homogenous_h2]
let _ =
  run_test_tt ~verbose:true suite


