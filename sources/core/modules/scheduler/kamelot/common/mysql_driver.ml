open Mysql
open Conf

let connect () = 
(*  let conn = Conf.get_conn () in *)
  
  let user = get_optional_value "DB_BASE_LOGIN"
  and name = get_optional_value "DB_BASE_NAME"
  and host = get_optional_value "DB_HOSTNAME" in
  let conn = { dbuser = user;
	       dbpwd = get_optional_value "DB_BASE_PASSWD";
	       dbname = name;
	       dbhost = host;
	       dbport = None;
         dbsocket = None;
	     } in
    try 
      log (let o = function None -> "default" | Some s -> s in 
        Printf.sprintf "Connecting as %s@%s on %s.\n" (o user) (o host) (o name)); 
      connect ~options:[OPT_LOCAL_INFILE(true)] conn
    with e -> ( Conf.error ("[Kamelot]: Connection Failed : "^(Printexc.to_string e)^"\n"))

let disconnect = Mysql.disconnect

let execQuery db q = 
(*  log (Printf.sprintf "[SQL] execQuery --%s--" q); *)
  let r = exec db q in 
    match errmsg db with 
				None -> r
      | Some s -> ignore (Conf.error ("[Iolib] : "^s)); 
		              ignore (Conf.error (" *** Query was:\n"^q));
		              failwith "execQuery"

let iter f x = ignore (Mysql.map f x)
let map = Mysql.map 
let fetch = Mysql.fetch

let not_null = Mysql.not_null
let str2ml = Mysql.str2ml
