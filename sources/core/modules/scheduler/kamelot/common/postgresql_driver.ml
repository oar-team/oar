open Postgresql
open Conf

type q_res = {
  result: Postgresql.result;
  ntuples: int;
  mutable nt: int;
} 

let connect () = 
  let user = get_optional_value "DB_BASE_LOGIN"
  and name = get_optional_value "DB_BASE_NAME"
  and host = get_optional_value "DB_HOSTNAME"
  and passwd = get_optional_value "DB_BASE_PASSWD" in
    let o = function None -> "" | Some s -> s in
      log ( Printf.sprintf "Connecting as %s@%s on %s.\n" (o user) (o host) (o name)); 
      let str_connection = Printf.sprintf  "host=%s user=%s password=%s dbname=%s"  (o host) (o user) (o passwd) (o name) in 
        (* let str_connection = Some "host=" in *)
        new connection ~conninfo:str_connection ();;

let disconnect dbh = dbh#finish;;


let execQuery (dbh:Postgresql.connection)  q = (* TODO must be completed *)
  let res = dbh#exec q in
    { result = res;
      ntuples = res#ntuples;
      nt = 0;
    }
(* TODO test status see dbi_postgresql.ml in ocamldbi *)
;; 

(* TODO to modify/simply !!! *)
let iter (qres) f = 
  let rec loop i result_lst = match i with
    | x when (x==qres.ntuples) -> ()
    | _ -> loop (i+1) ((f (qres.result#get_tuple i))::result_lst)
  in loop 0 [] ;;


(* let map (q_result:Postgresql.result) f = *) 
let map (qres) f = 
  let rec loop i result_lst = match i with
      | x when (x==qres.ntuples) -> List.rev result_lst
(*    | x when (x==qres.ntuples) -> result_lst *)
    | _ -> loop (i+1) ((f (qres.result#get_tuple i))::result_lst)
  in loop 0 [] ;;

let fetch qres =
  if (qres.nt == qres.ntuples) then
    None
  else
    let r = qres.result#get_tuple qres.nt in
      qres.nt <- qres.nt + 1;
      Some r;;


