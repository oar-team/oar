open Hierarchy
open Interval
open OUnit

let h0 = [{b = 1; e = 16};{b = 17; e = 32};]
let h1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}]

let test_find_hierarchy_homogenous_h1_0 _ =
  let h =  [|h0|] in 
  let r =  [|2|] in
      assert_equal [[]]  (find_resource_hierarchies [{b = 16; e = 23}] h r);
      assert_equal [[]]  (find_resource_hierarchies [{b= 7;e=30}] h r);
      assert_equal [[{b = 1; e = 16}; {b = 17; e = 32}]]  (find_resource_hierarchies [{b= 1;e=32}] h r)

let test_find_hierarchy_homogenous_h1_1 _ =
  let h =  [|h1|] in 
  let res1 = [{b = 1; e = 8}; {b = 9; e = 16}] in
  let res2 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}] in
  let res3 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 25; e = 32}] in

  assert_equal [res1] (find_resource_hierarchies [{b = 1; e = 32}] h [|2|]);
  assert_equal [res2] (find_resource_hierarchies [{b = 1; e = 32}] h [|4|]);
  assert_equal [res3] (find_resource_hierarchies [{b = 1; e = 18};{b = 23; e = 32}] h [|3|]);
  assert_equal [[]] (find_resource_hierarchies [{b = 4; e = 18};{b = 23; e = 32}] h [|3|])

let test_find_hierarchy_homogenous_h2 _ =
  let h =  [|h0;h1|] in 
  let r =  [|2;1|] in

  assert_equal [[{b = 17; e = 24}]; [{b = 1; e = 8}]] (find_resource_hierarchies [{b=1;e=80}] h r);
  assert_equal [[]] (find_resource_hierarchies [{b= 7;e=20}] h r);
  assert_equal [[{b = 17; e = 24}]; [{b = 9; e = 16}]] (find_resource_hierarchies [{b= 7;e=30}]  h r)

let suite = "Unit test for simple_cbf_mb_h" >::: [
          "test_find_hierarchy_homogenous_h1_0" >:: test_find_hierarchy_homogenous_h1_0;
          "test_find_hierarchy_homogenous_h1_0" >:: test_find_hierarchy_homogenous_h1_1;
				  "test_find_hierarchy_homogenous_h2" >:: test_find_hierarchy_homogenous_h2]
let _ =
  run_test_tt ~verbose:true suite


