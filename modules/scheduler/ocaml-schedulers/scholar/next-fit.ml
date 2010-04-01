
let next_fit x c =
  let rec aux dispo n accu = function
    | [] -> List.rev accu
    | t::q when t <= dispo -> aux (dispo-t) n (n::accu) q
    | t::q -> aux (c-t) (n+1) ((n+1)::accu) q
  in aux c 1 [] x;;


let  r =   next_fit  [60; 50; 15; 30; 45; 90; 75] 100;;

let f elem  =
  Printf.printf "%d " elem
in
  List.iter f r ;;


(* x = 60, 50, 15, 30, 45, 90, 75  , c =5 *)
