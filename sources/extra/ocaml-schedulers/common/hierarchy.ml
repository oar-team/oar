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
                  if (i = 0) then
                    h_t_itvs n l_itv
                  else
                    loop_bk (i-1) ({b = orig + bk_size * (i-1);  e = orig + bk_size * i -1;}::l_itv)
                in loop_bk nb_bk itvs
  in h_t_itvs  (List.rev h_triplets) [] ;;

(* Hierarchy.h_desc_to_h_levels [  ("resource_id", [(1,2,4);(20,3,4)] )];;   *)
(* [{Interval.b = 1; Interval.e = 2}; {Interval.b = 3; Interval.e = 4};      *)
(* {Interval.b = 5; Interval.e = 6}; {Interval.b = 7; Interval.e = 8};       *)
(* {Interval.b = 20; Interval.e = 22}; {Interval.b = 23; Interval.e = 25};   *)
(* {Interval.b = 26; Interval.e = 28}; {Interval.b = 29; Interval.e = 31}])] *)

let h_desc_to_h_levels h_desc = 
  let rec desc_to_itvs h_d h_l = match h_d with
    | [] -> h_l
    | (x::n) -> let (label,triplets) = x in desc_to_itvs n ((label, (h_triplets_to_itvs triplets))::h_l)
  in desc_to_itvs h_desc [];;

(*                                                                                          *)
(* Converter hierarchy ressource_id by field values to hierarchy levels (list of intervals) *)
(*                                                                                          *)
(* let h = Helpers.couples2hash [(1,[1;2;3]);(2,[5;6;7])];;                                 *)
(* let h_desc = Hierarchy.hy_array2hy_itvs [|h|] ["resource_id"];;                          *)

(* TODO: need to keep order on id value *)
(* TODO: not use ??? *)

let hy_array2hy_itvs_old hy_id_array hy_labels =
    let hy_id_lst = Array.to_list hy_id_array in
    let h_scat_to_itvs h = Hashtbl.fold (fun k v acc -> (ints2intervals v)::acc) h [] in 
    let h_scat_label hy_ids hy_label = (hy_label,(h_scat_to_itvs hy_ids))
      in List.rev (List.map2 h_scat_label hy_id_lst hy_labels);;

(* 

let h = Helpers.couples2hash [("1",[1;2;3;7;10;11;8]);("2",[5;6;7])];;
let k = Helpers.couples2hash [("r_id",["1";"2"])];;
let h_desc = Hierarchy.hy_array2hy_itvs [|h|] k ["r_id"];; 
  [("r_id",v[[{Interval.b = 1; Interval.e = 3}; {Interval.b = 7; Interval.e = 8}; {Interval.b = 10; Interval.e = 11}];
     [{Interval.b = 5; Interval.e = 7}]])]

let k = Helpers.couples2hash [("r_id",["2";"1"])];;
let h_desc = Hierarchy.hy_array2hy_itvs [|h|] k ["r_id"];; 
[("r_id", [[{Interval.b = 5; Interval.e = 7}];
 [{Interval.b = 1; Interval.e = 3}; {Interval.b = 7; Interval.e = 8}; {Interval.b = 10; Interval.e = 11}]])]

*)
(* TODO: not use ??? *)
let hy_array2hy_itvs hy_id_array h_val_order hy_labels = 
    let hy_id_lst = Array.to_list hy_id_array in
    let ordered_val k = try Hashtbl.find h_val_order k with Not_found -> failwith ("Can't Hashtbl.find h_val_order for "^k) in  
    let h_scat_to_itvs h h_lbl = Helpers.hash_map (fun x -> ints2intervals x) (ordered_val h_lbl) h in  
    let h_scat_label hy_ids hy_label = (hy_label,(h_scat_to_itvs hy_ids hy_label))
      in List.rev (List.map2 h_scat_label hy_id_lst hy_labels);;

(*                                                                                                                           *)
(* hy_iolib2hy_level: function to generate hierarchy_level from the result provides by get_resource_list_w_hierarchy function *) 
(*                                                                                                                           *)

let hy_iolib2hy_level_old hy_iolib =
  let  h1_io2_h1_lvl lvl_name h1_io_value  = (* give list of res interval by scattered block for a hierarchy level *)
    (*  second term is list of list of res interval for  scattered block for one hy level *)
    (lvl_name, ( Hashtbl.fold (fun k1 r_ids acc1 -> (Interval.ints2intervals r_ids)::acc1) h1_io_value []) )
  in
    Hashtbl.fold (fun k v acc -> (h1_io2_h1_lvl k v)::acc) hy_iolib [];;

(* let hy_iolib2hy_level hy_iolib (hy_labels: string list) = *)
let hy_iolib2hy_level h_value_order hy_iolib hy_labels =
  let  h1_io2h1_lvl h1_label h1_level =
    let h1_ordered_values = try Hashtbl.find h_value_order h1_label with Not_found -> failwith ("Can't find key in h_value_order for " ^ h1_label) in
    let h1_rids h_value =  try Hashtbl.find h1_level h_value with Not_found -> failwith ("Can't find key in h1_level for " ^ h_value ) in
    (* list of list of res interval for  scattered block for one hy level *)
    List.map (fun h_v -> (Interval.ints2intervals (h1_rids h_v) )) h1_ordered_values in
  let h1_lvls =  Array.to_list hy_iolib in
    List.map2 (fun x y -> (x,(h1_io2h1_lvl x y))) hy_labels h1_lvls ;; 

(*                                                                                                        *)
(* One a the core function                                                                                *)
(* Find ressources accordingly to resource requirements, hierarchy structures and available resources itv *)
(* Notes: hierarchy blocks are contiguous not scattered                                                   *)
(*                                                                                                        *)
(* TODO: not use ??? *)
let find_resource_hierarchies itv_l hy r_rqt_l =
 let rec find_resource_n_h (top: Interval.interval) h r = match (h, r) with
  | ([],_) | (_,[]) -> failwith "Bug ??- need to raise exception ???\n"; (* TODO *)
  | (tops::tl_h, n0::m) ->
      let h_itv = inter_intervals tops [top] in (* ???? *)
      let available_bk = extract_no_empty_bk itv_l h_itv in
      if ((List.length available_bk) < n0) then
        []
      else
        if (List.length m = 1) then
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
      if ((List.length hy) = 1) then
        extract_n_block_itv itv_l (List.hd hy) (List.hd r_rqt_l)
      else
        List.flatten (find_resource_n_h !toplevel_itv hy r_rqt_l);;

(*
let h0 = [{b = 1; e = 16};{b = 17; e = 32};];;
let h1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;

# h0;;
- : Interval.interval list = [{b = 1; e = 16}; {b = 17; e = 32}]
# h1;;
- : Interval.interval list =
[{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}]

find_resource_hierarchies [{b = 1; e = 32}] [h0;h1] [2; 1;];

- : Interval.interval list = [{b = 1; e = 8}; {b = 17; e = 24}]

*)

(* *)
(* *)
(* *)
(* TODO: remove !toplevel_itv ? use first level hierarchy ????  *)

let find_resource_hierarchies_scattered itv_l (hy_scat: interval list list list)  (r_rqt_l: int list) =
 let rec find_resource_n_h (top: interval list) (h: interval list list list)  r = match (h, r) with
  | ([],_) | (_,[]) -> failwith "Bug ??- need to raise exception ???\n"; (* TODO *)
  | (sh_tops::tl_h, n0::m) ->  (* ???? *)
      let scat_h_itvs = Helpers.map_wo_empty (fun sh_top -> inter_intervals sh_top top) sh_tops in (* remove resources which are present in upper level *)
      let available_bk = keep_no_empty_scat_bks itv_l scat_h_itvs  in                              (* remove empty scattered blocks                     *) 
      if (List.length available_bk) < n0 then (* not enough scattered blocks *)
        []
      else
        if List.length m = 1 then (* reach last level hierarchy of requested resources *)
          (* iter sur top *)
          let rec iter_n_no_empty result n bks = match (bks,n) with
            | (_,0) -> List.rev result (* win *)
            | (scat_bk::tl_bks, nn) -> 
              begin
                (* remove resources which are present in upper level *)
                let scat_h_itvs = Helpers.map_wo_empty (fun x -> inter_intervals x scat_bk) (List.hd tl_h) in
                (* remove empty scattered blocks  *)
                let sub_result = extract_n_scattered_block_itv itv_l scat_h_itvs (List.hd m) in (*   extract_n_scattered_block_itv ;)*)
                match sub_result with 
                  | [] -> iter_n_no_empty result nn tl_bks
                  | x  -> iter_n_no_empty (sub_result::result) (nn-1) tl_bks
              end 
            | ([],_) -> [] (* failed*)
            
          in iter_n_no_empty [] n0 available_bk
        else (* next hierarchy level *)
          let rec iter_n_find (result: Interval.interval list list) n (scat_bks: Interval.interval list list)  = match (scat_bks,n) with
            | (_,0) -> List.rev result (* win *)
            | (scat_bk::tl_bks, nn) -> 
              begin
                let sub_result = find_resource_n_h scat_bk tl_h m in
                match sub_result with 
                  | [] -> iter_n_find result nn tl_bks
                  | x  -> iter_n_find ((List.flatten x)::result) (nn-1) tl_bks
              end 
            | ([],_) -> [] (* failed*)
          in iter_n_find [] n0 available_bk
    in
      if (List.length hy_scat) = 1 then (* TODO BEST *)
        extract_n_scattered_block_itv itv_l (List.hd hy_scat) (List.hd r_rqt_l) (*   extract_n_scattered_block_itv ;)*) 
      else
        List.flatten (find_resource_n_h [!toplevel_itv] hy_scat r_rqt_l);;

(*
let h0 = [[{b = 1; e = 16}];[{b = 17; e = 32}]];;
let h1 = [[{b = 1; e = 8}];[{b = 9; e = 16}];[{b = 17; e = 24}];[{b = 25; e = 32}]];;

find_resource_hierarchies_scattered  [{b = 1; e = 32}] [h0] [2]
- : Interval.interval list = [{b = 1; e = 16}; {b = 17; e = 32}]


find_resource_hierarchies_scattered  [{b = 1; e = 32}] [h0;h1] [2; 1;];
- : Interval.interval list = [{b = 1; e = 8}; {b = 17; e = 24}]

let h01 = [[{b = 1; e = 7};{b = 41; e =47 }];[{b = 17; e = 32}]];;

# find_resource_hierarchies_scattered  [{b = 1; e = 50}] [h01] [1];;
- : Interval.interval list = [{b = 1; e = 7}; {b = 41; e = 47}]
# find_resource_hierarchies_scattered  [{b = 1; e = 50}] [h01] [2];; 
- : Interval.interval list = [{b = 1; e = 7}; {b = 17; e = 32}; {b = 41; e = 47}]

*)



(*
let h0 = [{b = 1; e = 16};{b = 17; e = 32};];;
let h1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;

# h0;;
- : Interval.interval list = [{b = 1; e = 16}; {b = 17; e = 32}]
# h1;;
- : Interval.interval list =
[{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}]

find_resource_hierarchies [{b = 1; e = 32}] [h0;h1] [2; 1;];

- : Interval.interval list = [{b = 1; e = 8}; {b = 17; e = 24}]

let h0 = [{b = 1; e = 6}; {b = 17; e = 32}];;
let h2 = [{b = 1; e = 4}; {b = 5; e = 6}; {b = 17; e = 24}; {b = 25; e = 32}];;

#   find_resource_hierarchies [{b = 1; e = 32}] [h0;h1] [2; 1;];;
- : Interval.interval list = [{b = 1; e = 6}; {b = 17; e = 24}]

*)

