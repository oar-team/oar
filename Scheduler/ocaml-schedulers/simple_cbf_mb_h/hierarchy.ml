
open Interval 

(*
vim regular / replace expression to manage comment around Printf debug fonctions
#add ocaml comments
:%s/\(.*Printf\.printf.*\)/(* \1 *)/
#remove ocaml comments

(*
:%s/^(\*\(.*Printf\.printf.*\)\*)/\1/ 

*)

(* some default values *) 
let h0 = [{b = 1; e = 16};{b = 17; e = 32};];;
let h1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let h2 = [{b = 1; e = 4}; {b = 5; e = 8}; {b = 9; e =12}; {b = 13; e = 16};
          {b = 17; e = 20}; {b = 21; e = 24}; {b = 25; e = 28}; {b = 29; e = 32}];;

let hierarchy_levels = [ ("node",h0);("cpu",h1);("core",h2) ];;
let master_top = {b = 1; e = 32} ;; 


type resource_block = {
  orig : int; 
  bk_size : int; 
  nb_bk : int
}

type set_of_res_block = resource_block list

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


(*
  let r_bk1 = {orig=1 ;bk_size=8 ; nb_bk=8 };;
  set_res_bk2itv [r_bk1]

  let r_bk10 = {orig=1 ;bk_size=2 ; nb_bk=8 };;
  let r_bk11 = {orig=17 ;bk_size=4 ; nb_bk=2 };;
*)



let find_resource_hierarchies master_top itv_l hy r_rqt_l =
 let rec find_resource_n_h (top: Interval.interval) h r = match (h, r) with
  | ([],_) | (_,[]) -> failwith "Bug ??- need to raise exception ???\n"; (* TODO *)
  | (tops::tl_h, n0::m) ->
      let h_itv = inter_intervals tops [top] in
      let available_bk = extract_no_empty_bk itv_l h_itv in
      if (List.length available_bk) < n0 then
        []
      else
        if List.length m = 1 then
          (* iter sur top *)
          let rec iter_n_no_empty result n bks = match (bks,n) with
            | (_,0) -> List.rev result (* win *)
            | (bk::tl_bks, nn) -> 
              begin
                let h_itv = inter_intervals (List.hd tl_h)  [bk] in
                let sub_result = extract_n_block_itv itv_l h_itv (List.hd m) in
                match sub_result with 
                  | [] -> iter_n_no_empty result nn tl_bks
                  | x  -> iter_n_no_empty (sub_result::result) (nn-1) tl_bks
              end 
            | ([],_) -> [] (* failed*)
            
          in iter_n_no_empty [] n0 available_bk
        else
          let rec iter_n_find (result: Interval.interval list list) n (bks: Interval.interval list)  = match (bks,n) with
            | (_,0) -> List.rev result (* win *)
            | (bk::tl_bks, nn) -> 
              begin
                let sub_result = find_resource_n_h bk tl_h m in
                match sub_result with 
                  | [] -> iter_n_find result nn tl_bks
                  | x  -> iter_n_find ((List.flatten x)::result) (nn-1) tl_bks
              end 
            | ([],_) -> [] (* failed*)
          in iter_n_find [] n0 available_bk
    in
      if (List.length hy) = 1 then
        extract_n_block_itv itv_l (List.hd hy) (List.hd r_rqt_l) 
      else
        List.flatten (find_resource_n_h  master_top hy r_rqt_l);;
 


(*
let h0 = [{b = 1; e = 16};{b = 17; e = 32};];;
let h1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;

let h =  [|h0;h1|] ;;
let r =  [|2;1|] ;;
let e1 =  [{b = 16; e = 23}] ;;
let e2 =  [{b = 16; e = 23}] ;;
let e3 =  [{b = 16; e = 23}] ;;

let res1 =  [{b = 1; e = 8}];;

let t = [
  (e1,h,r,res1);
  (e2,h,r,res1);
  (e3,h,r,res1);
];;
*)

(*
let test_find_hierarchies test_list =
 let test = fun x ->
  let (input, hys, r_reqts, result) = x in 
  let r = find_resource_hierarchies input hys r_reqts in 
    if r = [result] then
      Printf.printf "****** OK ******\n"
    else
      Printf.printf "####### Bou ######\n"
 in
  List.iter (fun x -> test x) test_list;;
*)

(*
let _=

 find_resource_hierarchies {b = 1; e = 32} [{b = 1; e = 32}] [h0;h1;h2] [2;1;1];;
*)

(*
  let h =  [|h0;h1|] in
  let r =  [|2;1|] in
  find_resource_hierarchies [{b = 1; e = 32}] [|h0;h1;h2|] [|2; 1; 1|];;
*)
(*  find_resource_hierarchies [{b = 1; e = 32}] h r;; *)
(*
find_resource_hierarchies [{b = 10; e = 32}] [|h0;h1|] [|2; 2|]; bug
find_resource_hierarchies [{b = 1; e = 32}] [|h0;h1;h2|] [|1; 1; 1|];

find_resource_hierarchies [{b = 1; e = 32}] [|h0;h1;h2|] [|1; 1; 1|];; (OK)

find_resource_hierarchies [{b = 1; e = 32}] [|h0;h1;h2|] [|2; 1; 1|];; (Failed)

*)


(*
  let h =  [|h0;h1|] in
  let r =  [|2;1|] in

 find_resource_2_h  [{b = 1; e = 32}] h r;;
*)
