
let first_fit x c =
  let n = List.length x in
  let disponible = Array.make n c
  and rangement = Array.make n (-1) in
  let rec premier_conteneur_suffisant depuis = function
    | v when v <= disponible.(depuis) -> depuis
    | v -> premier_conteneur_suffisant (depuis+1) v in
  let rec aux j = function
    | [] -> Array.to_list rangement
    | t::q -> let i = premier_conteneur_suffisant 0 t in
       rangement.(j) <- i+1;
       disponible.(i) <- disponible.(i) - t;
       aux (j+1) q
  in aux 0 x;;


let  r =   first_fit  [60; 50; 15; 30; 45; 90; 75] 100;;

let f elem  =
  Printf.printf "%d " elem
in
  List.iter f r ;;


(* x = 60, 50, 15, 30, 45, 90, 75  , c =5 *)
