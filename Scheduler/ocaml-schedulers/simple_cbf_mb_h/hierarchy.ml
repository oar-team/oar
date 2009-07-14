
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


let find_resource_hierarchies itv_l hy r_rqt_l =

  let master_bk = [{b=1;e=100}] in
  let nb_h = Array.length r_rqt_l in  

  let rec find_res_h result h_top_bks idx_h r_rqts_remain = match (h_top_bks,r_rqts_remain) with
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

                Printf.printf "Win idx_h=0 (List.hd r_rqts_remain) = 0 :)";
                result
              end
            else
              begin  
                (*on remonte c'est ok à ce niveau *)
                Printf.printf "On remonte ce niveau est ok\n";
                find_res_h result tl_h_top_bks (idx_h-1) tl_rs
              end
   
   | ((top_bks::tl_h_top_bks), (res::tl_rs)) ->
      match top_bks with
       | [] -> begin
                 Printf.printf "top_bks cannot be empty Bug - need to raise exception %d\n" idx_h;
                 [] 
               end
       | bk_top::next_bks_top ->
             (*  on sélectionne  les blocks de la hierarchie courante couvert par le top block*)
                  Printf.printf "intersect h_bks with cur_top_bk  \n";
                  let h_cur = hy.(idx_h) in let h_cur_bk = (fst (inter_intervals h_cur [bk_top] [] 0)) in
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
                                  Printf.printf "perdu" ;    
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
                                                find_res_h (drop ( (r_rqt_l.(idx_h)) - (List.hd tl_rs)) result) (List.tl h_top_bks) (idx_h-1) tl_rs
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
                                  Printf.printf "win" ; 
                                  new_result (* C'est gagné *)
                                end
                              else
                                begin
                                  Printf.printf "boum %d %d\n" idx_h  res;
                                  Printf.printf "boum2 %d %d\n" idx_h  (List.hd tl_rs);

                                  if (idx_h = 1) && ((List.hd tl_rs) = 0) then
                                    begin
                                      Printf.printf "Win - end" ; 
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
                                                    (* go up, next up block *)
                                                    find_res_h new_result (tl_h_top_bks) (idx_h-1) ((r-1)::(List.tl tl_rs))

                                               end
                                        | x -> begin
                                                  if  r > 1 then
                                                      begin
                                                        Printf.printf "Next top block idx %d r: %d\n" idx_h r;
                                                        find_res_h new_result (next_bks_top::tl_h_top_bks) idx_h (r_rqt_l.(idx_h)::((r-1)::(List.tl tl_rs)))
                                                      end
                                                    else
                                                      begin
                                                        Printf.printf "on a terminer ici on passe au Next top block idx %d r: %d\n" idx_h r;
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
  in find_res_h [] [master_bk] 0 (r_rqt_l.(0)::[0]);; 



(*
- : interval list array =
[|[{b = 1; e = 16}; {b = 17; e = 32}];
  [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}]|]
# r;;
- : int array = [|2; 1|]
find_resource_hierarchies2  [{b = 16; e = 23}] h r;;


*)
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


(*
let _=
  let h0 = [{b = 1; e = 16};{b = 17; e = 32};] in
  let h1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}] in

  let h =  [|h0;h1|] in
  let r =  [|2;1|] in
  find_resource_hierarchies2  [{b = 16; e = 23}] h r;;
*)

let find_resource_hierarchies_old itv_l hy r_rqt_l =

  (* result = resultat cumulatif *)
  (* itv_l_hy_top = list interval top *)
  (* itv_hy_ll = reste de hierarchie *) 
  (* itv_l_hy_prev_top = list de list top list pour remonter ?? (besoin de garder tt les niveau) *)
  (* r_h_top = ressource necessaire à niveau supérieur (besoin de garder tt les niveau) *) 
  (* r_rqt_l = reste de ressource à grignoter par niveau *)

  (* itv_l = list des resource dispo *)  
  (* result *) (* list inter*)
  (* cur_bks *)
  (* top_bks *)
  (* r_rqts_top *) 
  (* idx_h = index hierarchy *)
  (* hy = hierrachy array *) 
  (* r_rqts = ressource requests array*)

  let master_bk = [{b=1;e=100}] in
  let nb_h = Array.length r_rqt_l in  

  let rec find_res_h result h_top_bks idx_h r_rqts_remain =

      if  (List.hd r_rqts_remain) = 0 then
        if idx_h = 0 then
          begin
            Printf.printf "win idx_h=0 (List.hd r_rqts_remain) = 0" ;  
            result (* gagné *)
          end
        else
          begin  
            (*on remonte c'est ok à ce niveau *)
            Printf.printf "On remonte ce niveau est ok\n";
            find_res_h result (List.tl h_top_bks) (idx_h-1) (List.tl r_rqts_remain)
          end
      else   
        
        let top_bks = (List.hd h_top_bks) in
        (*  on separe le top block et des top_block suivant *)
        match top_bks with
          | [] -> if idx_h = 0 then
                    [] (* plus de next block *)
                  else
                    begin 
                    Printf.printf "on remonte A - idx %d r_remain %d\n" idx_h (List.hd (List.tl r_rqts_remain));
                    (* on remonte *)
                    find_res_h result  (List.tl h_top_bks) (idx_h-1) (List.tl r_rqts_remain)
                    end
          | bk_top::next_bks_top -> (* let bk_top = List.hd top_bks and next_bks_top = List.tl top_bks in *)
                    (*  on sélectionne  les blocks de la hierarchie courante couvert par le top block*)

                  Printf.printf "yop\n";
                  let h_cur = hy.(idx_h) in let h_cur_bk = (fst (inter_intervals h_cur [bk_top] [] 0)) in

                  if idx_h = (nb_h-1) then (* bottom - miam-miam - ressources*)
                  begin
                    Printf.printf "bottom - try to eat\n";

                    let sub_result = extract_n_block_itv itv_l h_cur_bk (r_rqt_l.(idx_h)) in (* bottom *)
                    match sub_result with
                      (* :( pas de miam on essaie de passe au top block suivant même niveau*) 
                      | [] -> if idx_h = 0 then
                                begin
                                Printf.printf "perdu" ;    
                                [] (* perdu *)
                                end  
                              else
                                 begin
                                  match next_bks_top with
                                    | [] -> begin
                                              Printf.printf "On remonte no more next block at this level %d %d \n" idx_h (List.hd (List.tl r_rqts_remain));
                                              find_res_h result (List.tl h_top_bks) (idx_h-1) (List.tl r_rqts_remain)
                                            end
                                    | x -> begin                                                      
                                            Printf.printf "Next top block idx %d\n" idx_h;
                                            find_res_h result (x::(List.tl h_top_bks)) idx_h r_rqts_remain
                                           end
                                 end    
                      (* c'est tout bon miam-miam les resources*)       
                      | x ->  let new_result = sub_result :: result in
                        Printf.printf "poy\n" ;  
                        (* if  r = 1 then *)
                        if idx_h = 0 then (* win *)
                          begin
                          Printf.printf "win" ; 
                          new_result (* C'est gagné *)
                          end
                        else
                          begin
                          Printf.printf "boum %d %d\n" idx_h  (List.hd r_rqts_remain);
                          Printf.printf "boum2 %d %d\n" idx_h  (List.hd (List.tl r_rqts_remain));

                          if (idx_h = 1) && ((List.hd (List.tl r_rqts_remain)) = 0) then
                             begin
                            Printf.printf "end" ; 

                            new_result
                              end
                          else
                            begin
                              let r_m = List.tl  r_rqts_remain in
                              let r = List.hd r_m in 
                          
                              (* on remonte ce coin est termine*)
                              Printf.printf "on remonte %d\n" idx_h  ;
(* bug sur le next block *)
                              let h_top = List.tl h_top_bks in 
                              find_res_h new_result ( (List.tl (List.hd h_top)) :: (List.tl h_top) ) (idx_h-1)  ((r-1)::(List.tl r_m))
                              (* find_res_h new_result (List.tl h_top_bks) (idx_h-1) ((r-1)::(List.tl r_m)) *)
                            end
                            
                          end
 
(*                            else
                            begin
                             (* new_result *)
                                
                               Printf.printf "le bloc d'a coté\n" ; 
                              (* r_h_top -1 on passe au top block suivant, on a pas fini ou on a perdu *)
                              find_res_h new_result (next_bks_top::(List.tl h_top_bks)) idx_h ((r-1)::(List.tl r_m))
                              
                            end
                          end *)
                  end  
                  else (* not then bottom *)
                    begin
                      Printf.printf "on est pas en bas\n";
                  (* extract all avalaible block *)
                    let available_bk = extract_no_empty_bk itv_l h_cur_bk in
                    if (List.length available_bk) < r_rqt_l.(idx_h) then
                      begin
                        Printf.printf "next to bks\n %d %d" idx_h (r_rqt_l.(idx_h));
                        (* passer au top_block suivant / ici y a rien il n'a pas assez *)  
                        find_res_h result (next_bks_top::(List.tl h_top_bks)) idx_h (r_rqt_l.(idx_h)::(List.tl r_rqts_remain))
                       end
                    else
                      begin
                         Printf.printf "Il y assez de block descend  nb_avai_bk %d\n" (List.length available_bk) ;
                    (* on descend *)
                         find_res_h result (available_bk::h_top_bks) (idx_h + 1) (r_rqt_l.(idx_h+1)::r_rqts_remain)
                      end
                    end
      in find_res_h [] [master_bk] 0 (r_rqt_l.(0)::[5]);; 

(*

find_resource_hierarchies itv_l hy r_rqt_l =
let h0 = [{b = 1; e = 16};{b = 17; e = 32};] ;;
let h1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;

let h =  [|h1|];;
let r = [|2|];;

let a =  [{b = 1; e = 80}];;

let master_bk = [{e=1;b=100}];; 
let h_cur = h.(0);;
let h_cur_bk = (fst (inter_intervals h_cur master_bk [] 0)) ;;

let h =  [|h1|];;
let r = [|2|];;

find_resource_hierarchies  [{b = 15; e = 80}] h r;;
: interval list list = [[{b = 17; e = 24}; {b = 25; e = 32}]]
find_resource_hierarchies  [{b = 15; e = 28};{b = 25; e = 30}] h r;;
: interval list list = []


let h =  [|h0|];;
let r = [|1|];;
find_resource_hierarchies  [{b = 15; e = 80}] h r;;
interval list list = [[{b = 17; e = 32}]]


let h =  [|h0;h1|];;
let r = [|1;1|];;
find_resource_hierarchies  [{b = 15; e = 80}] h r;;
- : interval list list = [[{b = 17; e = 24}]]

let h =  [|h0;h1|];;
let r = [|2;1|];;


let r = [|1;2|];;
# find_resource_hierarchies  [{b = 1; e = 80}] h r;;
- : interval list list = [[{b = 1; e = 8}; {b = 9; e = 16}]]

find_resource_hierarchies a h r;; 

*)

(*


match (rqts_down, top_bks) with
    | [],[] -> (*plus de top blok c'est perdu*) []

    (* bottom - bottom *)
    | (x::[],bk_top::next_bks_top) -> let itv_h_cur = (List.hd itv_hy_ll) in let itv_h_cur_bk = (fsb (inter_intervals itv_h_cur [bk_top] [] 0) in
                                       let itv_sub_result = extract_n_block_itv itv_result itv_h_cur_bk r_h_cur in (* bottom *)
                                       match itv_sub_result with
                                         (* on passe au top block suivant même niveau*) 
                                         | [] -> find_res_h result next_bks_top hs_up hs_down                  itv_l_hy_prev_top r_h_top r_rqt_l
                                         (* c'est tout bon miam-miam les resources*)       
                                         | x ->  let itv_r = itv_sub_result :: itv_result in
                                                 if r_h_top = 1 then
                                                   match 
                                                  (* on remonte ce coin est termine*)
                                                  (* si rien à remonté c'est gagné :) *)
                                                  
                                                 else
                                                  (* r_h_top -1 on passe au top block suivant, on a pas fini *)
                                                  fini ou perdu
 
    (* not bottom *)
    | (x::m,bk_top::next_bk_l_top) -> let all_itv_h_bk = (fsb (inter_intervals itv_h_cur [bk_top] [] 0) in (* extract all itv_h_current in current top_block *) 
                                      let (available_bk, nb_avail_bk) = extract_itv_by_itv_nb_inter itv_l all_itv_h_bk in (* extract all avalaible block *)
                                      if nb_avail_bk < x then
                                        (* passer au top_block suivant / ici y a rien il n'a pas assez *)
                                        find_res_h itv_result next_bk_l_top r_rqt_l
                                      else
                                    (* on descend *)
                                        find_res_h itv_result (List.hd itv_hy_ll) (List.tl itv_hy_ll) r_h_cur m
  
   
  


let find_resource_hierarchies itv_l itv_hy_l_l r_rqt_l =

  let rec find_res_h itv_result itv_hy_ll r_rqt_l = match r_rqt_l with
    


(*
val y : interval list = [{b = 5; e = 13}; {b = 15; e = 16}; {b = 19; e = 19}]
# find_ressource_hierarchies y [y] 2;;
This expression has type int but is here used with type int list
# find_ressource_hierarchies y [y] [2];;
- : interval list = [{b = 5; e = 13}; {b = 15; e = 16}]
# find_ressource_hierarchies y [y] [4];;
- : interval list = []

let a = [{b = 10; e = 15};];;
let h1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;

let h2 = [{b = 1; e = 4}; {b = 5; e = 8}; {b = 9; e = 12}; {b = 13; e = 16}; {b = 17; e = 20}; {b = 21; e = 24}; {b = 25; e = 28}; {b = 29; e = 32}];;

let h = [h1;h2];;
let r = [1;2];;

find_resource_hierarchies a h r;;



let a = [{b = 1; e = 15};];;
let h1 = [{b = 1; e = 8};];;
let h = [h1;];;
let r = [1];;
#   find_resource_hierarchies a h r;;
- : interval list = [{b = 1; e = 8}]

let a = [{b = 3; e = 14};];;
let h1 = [{b = 1; e = 16};];;
let h2 = [{b = 1; e = 4}; {b = 5; e = 8}; {b = 9; e = 12}; {b = 13; e = 16};];; 

let h = [h1;h2];;
let r = [1;2];;



*)
*)
