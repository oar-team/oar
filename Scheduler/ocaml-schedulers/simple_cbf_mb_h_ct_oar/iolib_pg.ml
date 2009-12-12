open Postgresql 
open Conf
open Types
open Interval
open Helpers

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

let test_db (dbh:Postgresql.connection) =
  let res = dbh#exec ~expect:[Tuples_ok] ("select * from admission_rules") in
	if res#ntuples <> 0 then (
    let tpl = res#get_tuple 0 in
      print_string tpl.(0);
      for i = 1 to Array.length tpl - 1 do print_string (" " ^ tpl.(i)) done;
      print_newline ();
    ) else (Printf.printf "Bou\n") ;;


(* let map (q_result:Postgresql.result) f = *)
let map (q_result) f = 
  let rec loop i result_lst = match i with
    | -1 -> result_lst
    | _ -> loop (i-1) ((f (q_result#get_tuple i))::result_lst)
  in loop (q_result#ntuples-1) [] ;;


let fetch qres =
  if (qres.nt == qres.ntuples) then
    None
  else
    let r = qres.result#get_tuple qres.nt in
      qres.nt <- qres.nt + 1;
      Some r;;

let get_resource_list (dbh:Postgresql.connection)  = 
  let query = "SELECT resource_id, network_address, state, available_upto FROM resources" in
  let res = dbh#exec ~expect:[Tuples_ok] query in
  let get_one_resource a =
    { resource_id =  int_of_string a.(0);
      network_address =  a.(1);
      state = rstate_of_string a.(2);
      available_upto = Int64.of_string a.(3) ;}
  in
    map res get_one_resource ;;


let test_fetch_resource dbh =
  let query = "SELECT resource_id FROM resources" in
  let res = execQuery dbh query in
  let rec aux row res_id_lst = match row with
    | None -> res_id_lst
    | Some x-> aux (fetch res) (x::res_id_lst)
    in
      aux (fetch res) [];;

(*
  let get_one a = 
    let get s = column res s a in 
      { resource_id = not_null int2ml (get "resource_id");
				network_address = not_null str2ml (get "network_address"); 
				state = not_null (fun x -> let s = str2ml x in rstate_of_string s) (get "state"); 
        available_upto = not_null int642ml (get "available_upto");} 
     in
    			map res get_one

*)

