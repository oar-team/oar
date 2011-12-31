open Interval 

(* hierarchy_levels and master_top is updated a runtime *)
(* let hierarchy_levels = ref (h_desc_to_h_levels [ ("resource_id",[(1,1,1)]) ] ) ;;*)
let hierarchy_levels = ref  [ ("resource_id",[{b = 1; e = 1}]) ];;
let toplevel_itv = ref {b = 1; e = 64} ;; 

let h_triplets_to_itvs h_triplets =
  let rec h_t_itvs ht itvs = match ht with
    | [] -> itvs
    | (x::n) -> let (orig, bk_size,nb_bk) = x in
                let rec loop_bk i l_itv =
                  if i = 0 then
                    h_t_itvs n l_itv
                  else
                    loop_bk (i-1) ({b = orig + bk_size * (i-1);  e = orig + bk_size * i -1;}::l_itv)
                in loop_bk nb_bk itvs
  in h_t_itvs  (List.rev h_triplets) [] ;;

let h_desc_to_h_levels h_desc = 
  let rec desc_to_itvs h_d h_l = match h_d with
    | [] -> h_l
    | (x::n) -> let (label,triplets) = x in desc_to_itvs n ((label, (h_triplets_to_itvs triplets))::h_l)
  in desc_to_itvs h_desc [];;

let find_resource_hierarchies itv_l hy r_rqt_l =
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
        List.flatten (find_resource_n_h !toplevel_itv hy r_rqt_l);;

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
