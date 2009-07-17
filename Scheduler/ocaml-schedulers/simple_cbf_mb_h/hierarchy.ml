
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



(* need to be optimzed ??? *)
(* need a special case for unitary resource hierarchy *)
(* itv list MUST BE ORDERED by ascending resource id*)

let rec drop n = function
	| (_ :: l) when n > 0 -> drop (n-1) l
	| l -> l;; 

let find_resource_n_hierarchies itv_l hy r_rqt_l =
  let nb_h = Array.length r_rqt_l in 
  let top_master = [{b=1;e=32}] in (* TODO parameter ??? *) 
  let rec find result h idx r = match (h,r) with


    |([], res::_) -> if (res=0) && (idx= -1) then
        begin
          Printf.printf "Win \n";
          result
        end
       else
        begin
          Printf.printf "Bug ??- need to raise exception ???\n"; (* TODO *)
          [] 
        end

    | (_, []) -> 
        begin
          Printf.printf "Bug ??- need to raise exception ???\n"; (* TODO *)
          [] 
        end

    | ((tops::tl_h), (res::tl_r)) when res = 0 ->
        begin
          Printf.printf "res = 0\n";
          if idx = 0 then
            begin
              Printf.printf "Win \n";  (* TODO  to verify perhaps this is section is not needed *)
              result
            end
          else
           begin
             Printf.printf "Cont: subtree is OK - Go up - next top \n";
             let rh = List.hd tl_r in
             if rh = 1 then
               (* go up *)
               find result tl_h (idx-1) ((rh-1)::(List.tl tl_r))
                else
               (* go next branch same level *)
               find result ((List.tl tops)::tl_h) idx (r_rqt_l.(idx)::((rh-1)::(List.tl tl_r)))

             (*
             let hd_tl_h = List.hd tl_h in let tl_tl_h = List.tl tl_h in
             find result ((List.tl hd_tl_h)::tl_tl_h) (idx-1) (((List.hd tl_r)-1)::(List.tl tl_r)) 
              *)
           end 
        end

    | ((tops::tl_h), (res::tl_r)) ->
      match tops with
        | [] -> begin
                  if idx = 0 then
                    begin
                       Printf.printf "Failed: idx = 0 and no more resource to scan\n";
                       []
                    end
                  else
                    begin
                      Printf.printf "Cont: tops is empty, drop branch result and go up - (next top ???) \n";
                      (* TODO verify Array.sub *)
                      let sub_r_rqts = Array.sub r_rqt_l (idx+1) (nb_h-idx-2) in
                      let nb_sub_result = Array.fold_left (fun a b -> a*b) ((r_rqt_l.(idx)) - res) sub_r_rqts in (* compute nb sub_result to drop *)
                      find (drop  nb_sub_result result)  ((List.tl tops)::tl_h) idx  (r_rqt_l.(idx)::tl_r)
                    end
                 end
        | (top::tl_tops) -> 
                begin
                  Printf.printf "intersection\n";    
                  let h_itv =  inter_intervals (hy.(idx)) [top] in
                  if idx = (nb_h-1) then
                    begin
                      (*        *)
                      (* bottom *)
                      (*        *)            
                      Printf.printf "Bottom - Try to eat\n";
                      let sub_result = extract_n_block_itv itv_l h_itv (r_rqt_l.(idx)) in
                      match sub_result with
                        | [] -> begin
                                  Printf.printf "Failed: try next top block\n" ;
                                  find result (tl_tops::tl_h) idx r
                                end
                        | x -> begin
                                  Printf.printf "Cont: eating OK - go up - next top\n" ;
                                  let new_result = sub_result :: result in
                                  (*
                                    find new_result tl_h (idx-1) (((List.hd tl_r)-1)::(List.tl tl_r))
                                  *)
                                  let rh = List.hd tl_r in
                                  if rh = 1 then
                                    (* go up *)
                                    find new_result tl_h (idx-1) ((rh-1)::(List.tl tl_r))
                                  else
                                    (* go next branch same level *)
                                    find new_result (tl_tops::tl_h) idx (r_rqt_l.(idx)::((rh-1)::(List.tl tl_r)))
                                end
                    end
                  else
                    begin
                      (*            *)
                      (* Not bottom *)
                      (*            *)
                      Printf.printf "not the bottom\n";
                      (* extract all avalaible block *)
                      let available_bk = extract_no_empty_bk itv_l h_itv in
                      if (List.length available_bk) < r_rqt_l.(idx) then
                        begin
                          (* passer au top_block suivant / ici y a rien il n'a pas assez *)
                          Printf.printf "Cont: next top\n"; (* dropper ce qui est aquis dans sous branches ??? TODO *)
                          find result (tl_tops::tl_h) idx r
                        end
                      else
                        begin
                           Printf.printf "Cont go down\n";
                           find result (available_bk::h) (idx+1) (r_rqt_l.(idx+1)::r)
                        end
                    end 
                end

    in find [] ([top_master]) 0 (r_rqt_l.(0)::[1]);; 

  

let find_resource_1_h  itv_l hy r_rqt_l = 
   extract_n_block_itv itv_l hy.(0) r_rqt_l.(0);;
  
let find_resource_2_h  itv_l hy r_rqt_l = 
  let n0 = r_rqt_l.(0) in
  let available_bk = extract_no_empty_bk itv_l hy.(0) in
  if (List.length available_bk) < n0 then
    []
  else
    let rec find result bks n = match (bks,n) with
      | (_,0) -> List.rev result
      | (x::m,_) -> begin
                      let h_itv =  inter_intervals [x] (hy.(1)) in
                      let sub_result =  extract_n_block_itv itv_l h_itv r_rqt_l.(1) in
                      match sub_result with
                        | [] ->  find result m n
                        | y -> find (sub_result::result) m (n-1)
                    end
      | ([],_) -> [] 
    in find [] available_bk n0;;



(* supprimer itv l *)
let rec find_resource_n_h (top: Interval.interval) itv_l h r = match (h, r) with
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
                let sub_result = find_resource_n_h bk itv_l tl_h m in
                match sub_result with 
                  | [] -> iter_n_find result nn tl_bks
                  | x  -> iter_n_find ((List.flatten x)::result) (nn-1) tl_bks
              end 
            | ([],_) -> [] (* failed*)
          in iter_n_find [] n0 available_bk
;;
 



let find_resource_hierarchies itv_l hy r_rqt_l =
  let nb_h = Array.length r_rqt_l in
  match nb_h with
    | 1 -> [find_resource_1_h  itv_l hy r_rqt_l]
    | 2 -> find_resource_2_h  itv_l hy r_rqt_l
  (*  | _ -> find_resource_n_hierarchies itv_l hy r_rqt_l;; *)
    | _ -> find_resource_2_h  itv_l hy r_rqt_l;;


let find_resource_hierarchies_old itv_l hy r_rqt_l =
  
  let nb_h = Array.length r_rqt_l in  

  let rec find_res_h result h_top_bks idx_h r_rqts_remain = match (h_top_bks, r_rqts_remain) with
   | (_::_, []) -> begin
                     Printf.printf "Bug ??- need to raise exception %d\n" idx_h;
                     [] 
                   end
   | ([],_) -> begin
                 Printf.printf "Bug - need to raise exception %d\n" idx_h;
                 [] 
               end
   | ((top_bks::tl_h_top_bks), (res::tl_rs)) when res = 0 ->
            if idx_h = 0 then
              begin

                Printf.printf "Win idx_h=0 (List.hd r_rqts_remain) = 0 :)\n\n";
                result
              end
            else
              begin  
                (*on remonte c'est ok à ce niveau *) (* ATTENTION..............*)
                Printf.printf "On remonte ce niveau est ok\n";

                let tl_h_top = (List.tl h_top_bks) in let nxt_bks = (List.tl (List.hd tl_h_top)) in

                find_res_h result (nxt_bks::(List.tl tl_h_top)) (idx_h-1) (((List.hd tl_rs)-1)::(List.tl tl_rs)) 
              end
   
   | ((top_bks::tl_h_top_bks), (res::tl_rs)) ->
      match top_bks with
       | [] -> begin
                 Printf.printf "top_bks cannot be empty Bug - need to raise exception ??? pas sûr%d\n" idx_h;
                 [] 
               end
       | bk_top::next_bks_top ->
             (*  on sélectionne  les blocks de la hierarchie courante couvert par le top block*)
                  Printf.printf "intersect h_bks with cur_top_bk  \n";
                  let h_cur = hy.(idx_h) in let h_cur_bk = inter_intervals h_cur [bk_top] in
                  if idx_h = (nb_h-1) then (* bottom - miam-miam - ressources*)
                    begin
                    (*        *)
                    (* bottom *)
                    (*        *)
                  
                    Printf.printf "bottom - try to eat\n";
                    let sub_result = extract_n_block_itv itv_l h_cur_bk (r_rqt_l.(idx_h)) in
                    match sub_result with
                      (* :( pas de miam on essaie de passe au top block suivant même niveau*) 
                      | [] -> if idx_h = 0 then
                                begin
                                  Printf.printf "perdu\n" ;    
                                  [] (* perdu *)
                                end  
                              else
                                begin
                                  match next_bks_top with
                                    | [] -> begin
                                              Printf.printf "On remonte no more next block at this level %d %d \n" idx_h (List.hd tl_rs);
                                              (* caution we need to remove some ressource besoin d'un arbre pas sur on déplie et on pas!!! *)
                                              (* on dépile x fois surement ??? *) (* BUG-BUG *)
                                              if (idx_h = 1) && (List.length h_top_bks) = 2 then
                                                (* Perdu *)
                                                []
                                              else
                                                (* on remonte au dessus et il faut faire next block au dessus *)
                                                let tl_h_top = (List.tl h_top_bks) in let nxt_bks = (List.tl (List.hd tl_h_top)) in
                                                find_res_h (drop ( (r_rqt_l.(idx_h)) - (List.hd tl_rs)) result) (nxt_bks::(List.tl tl_h_top)) (idx_h-1) tl_rs
                                            end
                                     | x -> begin                                                      
                                              Printf.printf "Next top block idx %d\n" idx_h;
                                              find_res_h result (x::(List.tl h_top_bks)) idx_h r_rqts_remain
                                            end
                                end    

                      (* c'est tout bon miam-miam les resources*)       
                      | x ->  let new_result = sub_result :: result in
                              Printf.printf  "Miam OK\n"; 
                              if idx_h = 0 then (* win *)
                                begin
                                  Printf.printf "Win\n\n" ; 
                                  new_result (* C'est gagné *)
                                end
                              else
                                begin
                                  Printf.printf "boum %d %d\n" idx_h  res;
                                  Printf.printf "boum2 %d %d\n" idx_h  (List.hd tl_rs);

                                  if (idx_h = 1) && ((List.hd tl_rs) = 0) then
                                    begin
                                      Printf.printf "Win - end\n\n" ; 
                                      new_result
                                    end
                                  else
                                    begin
                                      (* on remonte ce coin est termine*)
                                       Printf.printf "on passe au prochain top block ou on monte %d\n" idx_h  ;


                                      let r = List.hd tl_rs in
                                      match next_bks_top with
                                        | [] -> begin
                                                  Printf.printf "no more next block at this level, go up %d %d \n" idx_h (List.hd tl_rs);
                                                  (* caution we need to remove some ressource besoin d'un arbre pas sur on déplie et on pas!!! *)
                                                  (* on dépile x fois surement ??? *) (* BUG-BUG *)
                                                  if r > 1 then
                                                    begin
                                                      Printf.printf "Bad il faut enlever les new_result";
                                                      new_result
                                                    end
                                                  else
                                                    begin
                                                    (* go up, next up block *) (* ATTENTION..............*)
                                                    (* let tl_h_top = (List.tl h_top_bks) in let nxt_bks = (List.tl (List.hd tl_h_top)) in *)
                                                      Printf.printf "Go up\n";
                                                      find_res_h new_result tl_h_top_bks (idx_h-1) ((r-1)::(List.tl tl_rs))
                                                    end
                                               end
                                        | x -> begin
                                                  if  r > 1 then
                                                      begin
                                                        Printf.printf "Next top block idx %d r: %d\n" idx_h r;
                                                        find_res_h new_result (next_bks_top::tl_h_top_bks) idx_h (r_rqt_l.(idx_h)::((r-1)::(List.tl tl_rs)))
                                                      end
                                                    else
                                                      begin(* ATTENTION..............*)

                                                        Printf.printf "on a terminer ici on passe au Next top block idx %d r: %d\n" idx_h r;
                                                        (* let tl_h_top = (List.tl h_top_bks) in let nxt_bks = (List.tl (List.hd tl_h_top)) in
                                                        find_res_h new_result (nxt_bks::(List.tl tl_h_top))  (idx_h-1) ((r-1)::(List.tl tl_rs)) *)
                                                        find_res_h new_result tl_h_top_bks (idx_h-1) ((r-1)::(List.tl tl_rs))
                                                      end
                                               end

                                    end
                                end
                  end
                  else
                  (*                *)
                  (* not the bottom *)
                  (*                *)
                    begin
                      Printf.printf "not the bottom\n";
                      (* extract all avalaible block *)
                      let available_bk = extract_no_empty_bk itv_l h_cur_bk in
                      if (List.length available_bk) < r_rqt_l.(idx_h) then
                        begin
                          Printf.printf "next to bks\n %d %d" idx_h (r_rqt_l.(idx_h));
                          (* passer au top_block suivant / ici y a rien il n'a pas assez *)  
                          find_res_h result (next_bks_top::tl_h_top_bks) idx_h (r_rqt_l.(idx_h)::tl_rs)
                        end
                      else
                        begin
                          Printf.printf "Il y assez de block descend  nb_avai_bk %d r_lower %d\n" (List.length available_bk) (r_rqt_l.(idx_h+1)) ;
                          (* on descend *)
                         find_res_h result (available_bk::h_top_bks) (idx_h + 1) (r_rqt_l.(idx_h+1)::r_rqts_remain)
                      end
                    end

(*
      | (_,_) -> begin
                    Printf.printf "Mouais\n";
                    []
                  end
*)
  in find_res_h [] [] 0 [r_rqt_l.(0)];; 


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

let _=

 find_resource_n_h {b = 1; e = 32} [{b = 1; e = 32}] [h0;h1;h2] [2;1;1];;

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
