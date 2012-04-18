(*                                                                       *)
(* Configuration and logging functions                                   *)
(*                                                                       *)
(* Code borrowed, in large par from oar 1.6 series and                   *) 
(* developped by Lionel Eyraud-Dubois                                    *) 
(*                                                                       *)

let log_file = ref None

let print_log s = 
  prerr_string s;
  flush stderr; 
  match !log_file with 
      Some d -> output_string d s; flush d
    | None -> ()

open Unix 
let formatted_time () = 
  let rest, seconds = modf (gettimeofday ()) in 
  let tm = localtime seconds and microseconds = int_of_float (rest *. 1e6) in
    Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d.%06d" 
      (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday
      tm.tm_hour tm.tm_min tm.tm_sec microseconds

let do_message e s = 
  print_log (Printf.sprintf "[%s] [%s] [Simple-CBF] %s\n" e (formatted_time ()) s)

let error s = 
  do_message "*Fatal Error*" s;
  failwith ("Fatal Error : "^s)

let conf_file_name = "oar.conf"
let besteffortQueueName = "besteffort"

let conf_file = 
  let dirs = 
    (try [Sys.getenv "OARDIR"]
     with Not_found -> []) @ ["/etc/oar/"] in
  let exists d = Sys.file_exists (Filename.concat d conf_file_name) in 
    try Filename.concat (List.find exists dirs) conf_file_name 
    with Not_found -> error ("Cannot find Conf File "^conf_file_name)

let chop s = 
  try 
    let l = String.length s in 
    let rec start i = 
      if i < l then 
	if s.[i] = ' ' then start (i+1) else i 
      else raise Exit in 
    let rec finish i = if i < 0 then raise Exit
    else if s.[i] = ' ' then finish (i-1) else i in 
      
  let a = start 0 and b = finish (l-1) in 
    String.sub s a (b-a+1) 
  with Exit -> String.create 0

let conf_values = 
  let t = Hashtbl.create 10 in 
    try 
      ( let file = open_in conf_file in
	let rec parse () = 
	  let l = chop (input_line file) in 
	    ( if String.length l = 0 or l.[0] = '#' then () 
	      else try 
		let i = String.index l '=' in 
		let key = chop (String.sub l 0 i) 
		and value = chop (String.sub l (i+1) ((String.length l) - i - 1)) in
      let value_chomp_quote = 
          if value.[0] = '"' then
            String.sub value 1 ((String.length value) - 2)
          else
            value
      in 
		  Hashtbl.add t key value_chomp_quote
	      with Not_found -> error ("Cannot parse "^l));
	    parse() in 
	  try parse () 
	  with End_of_file -> t)
    with Sys_error s -> error ("Cannot open conf file "^conf_file^" : "^s)

(* Log is automatically redirected in /var/log/oar.log by metascheduler *)
(* Use LOG_SCHED_FILE is a separed log file is wished *)
(*
let _ = 
  let f = try Hashtbl.find conf_values "LOG_SCHED_FILE" 
  with Not_found -> "/var/log/oar.log" in 
    try let d = open_out_gen [ Open_append; Open_text] 0o600 f in 
      log_file := Some d;
      at_exit (fun () -> close_out d);
    with Sys_error s -> 
      ( do_message "Warn" (Printf.sprintf "Cannot open log file '%s': %s" f s) )     
*)

(* 
let now, queueName = 
  match Array.length Sys.argv with 
      x when x >= 3 -> 
	( let n = try float_of_string (Sys.argv.(2))
	  with _ -> error ("Second arg should be a time, not " ^ (Sys.argv.(1))) in 
	  let q = Sys.argv.(1) in 
	    TimeConversion.unixtime2secs n, q )
    | x -> error "Expecting 2 args : time queueName"
*)

let loglevel = 
  try let s = Hashtbl.find conf_values "LOG_LEVEL" in 
    ( try int_of_string s
      with _ -> error ("LOG_LEVEL in Conffile should be INT, not " ^ s) )
  with Not_found -> 
    ( do_message "Warn" ("Couldn't find LOG_LEVEL value; assuming the worst");
      25 )

let log s = 
  if loglevel > 2 then do_message "debug" s
let warn s = 
  if loglevel > 1 then do_message "warn" s

let get_value s = 
  try Hashtbl.find conf_values s 
  with Not_found -> 
    error (Printf.sprintf "Value %s not found in confFile %s" s conf_file)

let test_key s = 
  try (ignore (Hashtbl.find conf_values s); true)  
  with Not_found -> 
    false

let get_optional_value s = 
  try Some (Hashtbl.find conf_values s)
  with Not_found -> 
    ( warn (Printf.sprintf "Value %s not found in confFile %s\n" s conf_file); 
      None )

let get_default_value s d = 
  (*Printf.sprintf "get_default_value: %s\n" s; *)
  try Hashtbl.find conf_values s
  with Not_found -> 
   d

let get_hierarchy_info =
(* ignore(Printf.sprintf "get_hierarchy_info HIERARCHY_LABELS\n"); *)
  let hierarchy_labels = Helpers.split "," (Helpers.replace " " "" (get_value "HIERARCHY_LABELS")) in
    let str_to_triplet y = let z = List.map (fun x-> int_of_string x ) (Helpers.split "," y) in 
      (List.nth z 0,List.nth z 1,List.nth z 2) 

    in

    let extract_triplet str_ts = 
      let b  =  Helpers.replace "),(" ";" str_ts in 
      let c =  Helpers.replace_regexp "(\\|)\\| " "" b in
      let str_triplets =  Helpers.split ";" c in
(*      Printf.printf "yop: %s\n" c; *)
      List.map (fun x-> str_to_triplet x) str_triplets
    in
      List.map (fun x-> (x, extract_triplet (get_value x))) hierarchy_labels
  ;;

(* function which trasnform a perl string hash in list of couple *)
(* ex { first => 75, default => 25 } : (string * int) list = [("first", 75); ("default", 25)] *) 
let str_perl_hash_to_pairs str =
  let str_pairs =  Helpers.split "," (Helpers.replace_regexp "{\\|}\\| " "" str) in
    let extraxt_pair s = let str_lpair = Helpers.split "=>" s in
      (List.hd str_lpair), (List.hd (List.tl str_lpair))
    in
      List.map (fun x-> extraxt_pair x) str_pairs

(* function which transform a perl string hash in list of couple with conversion application function*)
(* ex { first => 75, default => 25 } : (string * int) list = [("first", 75); ("default", 25)] *) 
let str_perl_hash_to_pairs_w_convert str convert=
  (* ignore(Printf.sprintf "Str_perl_hash_to_pairs_w_convert: %s" str;) *)
  let str_pairs =  Helpers.split "," (Helpers.replace_regexp "{\\|}\\| " "" str) in
    let extraxt_pair s = let str_lpair = Helpers.split "=>" s in
      (List.hd str_lpair), (convert (List.hd (List.tl str_lpair)))
    in
      List.map (fun x-> extraxt_pair x) str_pairs

(* float_of_string_e with exception*)
let float_of_string_e s =
  try float_of_string s
  with _ -> error ("float_of_string failed:"^s)

