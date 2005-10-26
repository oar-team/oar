(*pp camlp4o *)
(*
    Ocaml-MySQL: MySQL bindings for Ocaml.
    Copyright (C) 2001-2003 Shawn Wagner <shawnw@speakeasy.org>
                  1998, 1999 Christian Lindig <lindig@eecs.harvard.edu>

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
*)

module Map = MoreLabels.Map
module String = StdLabels.String
module Array = StdLabels.Array

module StrMap = Map.Make(struct type t = string let compare = compare end)

open Genlex


exception Error of string

let _ = Callback.register_exception "mysql error" (Error "Registering Callback")

(* let error msg   = raise (Error msg) *)
let fail  msg   = raise (Failure msg)

type dbd        (* database connection handle *)
type result     (* handle to access result from query *)


(* Do not change any type definition that is used by external functions 
   without changing the C source code accordingly! *)

(* Error codes *)
(* Auto-generated on Thu Feb 20 06:10:26 2003 from MySQL headers. *)
type error_code = Aborting_connection | Access_denied_error | Alter_info | Bad_db_error | Bad_field_error | Bad_host_error | Bad_null_error | Bad_table_error | Blob_cant_have_default | Blob_key_without_length | Blob_used_as_key | Blobs_and_no_terminated | Cant_create_db | Cant_create_file | Cant_create_table | Cant_create_thread | Cant_delete_file | Cant_drop_field_or_key | Cant_find_dl_entry | Cant_find_system_rec | Cant_find_udf | Cant_get_stat | Cant_get_wd | Cant_initialize_udf | Cant_lock | Cant_open_file | Cant_open_library | Cant_read_charset | Cant_read_dir | Cant_remove_all_fields | Cant_reopen_table | Cant_set_wd | Checkread | Columnaccess_denied_error | Commands_out_of_sync | Con_count_error | Conn_host_error | Connection_error | Db_create_exists | Db_drop_delete | Db_drop_exists | Db_drop_rmdir | Dbaccess_denied_error | Delayed_cant_change_lock | Delayed_insert_table_locked | Disk_full | Dup_entry | Dup_fieldname | Dup_key | Dup_keyname | Dup_unique | Empty_query | Error_on_close | Error_on_read | Error_on_rename | Error_on_write | Field_specified_twice | File_exists_error | File_not_found | File_used | Filsort_abort | Forcing_close | Form_not_found | Function_not_defined | Get_errno | Got_signal | Grant_wrong_host_or_user | Handshake_error | Hashchk | Host_is_blocked | Host_not_privileged | Illegal_grant_for_table | Illegal_ha | Insert_info | Insert_table_used | Invalid_default | Invalid_group_func_use | Invalid_use_of_null | Ipsock_error | Key_column_does_not_exits | Key_not_found | Kill_denied_error | Load_info | Localhost_connection | Mix_of_group_func_and_fields | Multiple_pri_key | Namedpipe_connection | Namedpipeopen_error | Namedpipesetstate_error | Namedpipewait_error | Net_error_on_write | Net_fcntl_error | Net_packet_too_large | Net_packets_out_of_order | Net_read_error | Net_read_error_from_pipe | Net_read_interrupted | Net_uncompress_error | Net_write_interrupted | Nisamchk | No | No_db_error | No_raid_compiled | No_such_index | No_such_table | No_such_thread | No_tables_used | No_unique_logfile | Non_uniq_error | Nonexisting_grant | Nonexisting_table_grant | Nonuniq_table | Normal_shutdown | Not_allowed_command | Not_form_file | Not_keyfile | Null_column_in_index | Old_keyfile | Open_as_readonly | Out_of_memory | Out_of_resources | Out_of_sortmemory | Outofmemory | Parse_error | Password_anonymous_user | Password_no_match | Password_not_allowed | Primary_cant_have_null | Ready | Record_file_full | Regexp_error | Requires_primary_key | Server_gone_error | Server_handshake_err | Server_lost | Server_shutdown | Shutdown_complete | Socket_create_error | Stack_overrun | Syntax_error | Table_cant_handle_auto_increment | Table_cant_handle_blob | Table_exists_error | Table_must_have_columns | Table_not_locked | Table_not_locked_for_write | Tableaccess_denied_error | Tcp_connection | Textfile_not_readable | Too_big_fieldlength | Too_big_rowsize | Too_big_select | Too_big_set | Too_long_ident | Too_long_key | Too_long_string | Too_many_delayed_threads | Too_many_fields | Too_many_key_parts | Too_many_keys | Too_many_rows | Too_many_tables | Udf_exists | Udf_no_paths | Unexpected_eof | Unknown_character_set | Unknown_com_error | Unknown_error | Unknown_host | Unknown_procedure | Unknown_table | Unsupported_extension | Update_info | Update_without_key_in_safe_mode | Version_error | Wrong_auto_key | Wrong_column_name | Wrong_db_name | Wrong_field_spec | Wrong_field_terminators | Wrong_field_with_group | Wrong_group_field | Wrong_host_info | Wrong_key_column | Wrong_mrg_table | Wrong_outer_join | Wrong_paramcount_to_procedure | Wrong_parameters_to_procedure | Wrong_sub_key | Wrong_sum_select | Wrong_table_name | Wrong_value_count | Wrong_value_count_on_row | Yes

let error_of_int code = match code with
| 1000 -> Hashchk
| 1001 -> Nisamchk
| 1002 -> No
| 1003 -> Yes
| 1004 -> Cant_create_file
| 1005 -> Cant_create_table
| 1006 -> Cant_create_db
| 1007 -> Db_create_exists
| 1008 -> Db_drop_exists
| 1009 -> Db_drop_delete
| 1010 -> Db_drop_rmdir
| 1011 -> Cant_delete_file
| 1012 -> Cant_find_system_rec
| 1013 -> Cant_get_stat
| 1014 -> Cant_get_wd
| 1015 -> Cant_lock
| 1016 -> Cant_open_file
| 1017 -> File_not_found
| 1018 -> Cant_read_dir
| 1019 -> Cant_set_wd
| 1020 -> Checkread
| 1021 -> Disk_full
| 1022 -> Dup_key
| 1023 -> Error_on_close
| 1024 -> Error_on_read
| 1025 -> Error_on_rename
| 1026 -> Error_on_write
| 1027 -> File_used
| 1028 -> Filsort_abort
| 1029 -> Form_not_found
| 1030 -> Get_errno
| 1031 -> Illegal_ha
| 1032 -> Key_not_found
| 1033 -> Not_form_file
| 1034 -> Not_keyfile
| 1035 -> Old_keyfile
| 1036 -> Open_as_readonly
| 1037 -> Outofmemory
| 1038 -> Out_of_sortmemory
| 1039 -> Unexpected_eof
| 1040 -> Con_count_error
| 1041 -> Out_of_resources
| 1042 -> Bad_host_error
| 1043 -> Handshake_error
| 1044 -> Dbaccess_denied_error
| 1045 -> Access_denied_error
| 1046 -> No_db_error
| 1047 -> Unknown_com_error
| 1048 -> Bad_null_error
| 1049 -> Bad_db_error
| 1050 -> Table_exists_error
| 1051 -> Bad_table_error
| 1052 -> Non_uniq_error
| 1053 -> Server_shutdown
| 1054 -> Bad_field_error
| 1055 -> Wrong_field_with_group
| 1056 -> Wrong_group_field
| 1057 -> Wrong_sum_select
| 1058 -> Wrong_value_count
| 1059 -> Too_long_ident
| 1060 -> Dup_fieldname
| 1061 -> Dup_keyname
| 1062 -> Dup_entry
| 1063 -> Wrong_field_spec
| 1064 -> Parse_error
| 1065 -> Empty_query
| 1066 -> Nonuniq_table
| 1067 -> Invalid_default
| 1068 -> Multiple_pri_key
| 1069 -> Too_many_keys
| 1070 -> Too_many_key_parts
| 1071 -> Too_long_key
| 1072 -> Key_column_does_not_exits
| 1073 -> Blob_used_as_key
| 1074 -> Too_big_fieldlength
| 1075 -> Wrong_auto_key
| 1076 -> Ready
| 1077 -> Normal_shutdown
| 1078 -> Got_signal
| 1079 -> Shutdown_complete
| 1080 -> Forcing_close
| 1081 -> Ipsock_error
| 1082 -> No_such_index
| 1083 -> Wrong_field_terminators
| 1084 -> Blobs_and_no_terminated
| 1085 -> Textfile_not_readable
| 1086 -> File_exists_error
| 1087 -> Load_info
| 1088 -> Alter_info
| 1089 -> Wrong_sub_key
| 1090 -> Cant_remove_all_fields
| 1091 -> Cant_drop_field_or_key
| 1092 -> Insert_info
| 1093 -> Insert_table_used
| 1094 -> No_such_thread
| 1095 -> Kill_denied_error
| 1096 -> No_tables_used
| 1097 -> Too_big_set
| 1098 -> No_unique_logfile
| 1099 -> Table_not_locked_for_write
| 1100 -> Table_not_locked
| 1101 -> Blob_cant_have_default
| 1102 -> Wrong_db_name
| 1103 -> Wrong_table_name
| 1104 -> Too_big_select
| 1105 -> Unknown_error
| 1106 -> Unknown_procedure
| 1107 -> Wrong_paramcount_to_procedure
| 1108 -> Wrong_parameters_to_procedure
| 1109 -> Unknown_table
| 1110 -> Field_specified_twice
| 1111 -> Invalid_group_func_use
| 1112 -> Unsupported_extension
| 1113 -> Table_must_have_columns
| 1114 -> Record_file_full
| 1115 -> Unknown_character_set
| 1116 -> Too_many_tables
| 1117 -> Too_many_fields
| 1118 -> Too_big_rowsize
| 1119 -> Stack_overrun
| 1120 -> Wrong_outer_join
| 1121 -> Null_column_in_index
| 1122 -> Cant_find_udf
| 1123 -> Cant_initialize_udf
| 1124 -> Udf_no_paths
| 1125 -> Udf_exists
| 1126 -> Cant_open_library
| 1127 -> Cant_find_dl_entry
| 1128 -> Function_not_defined
| 1129 -> Host_is_blocked
| 1130 -> Host_not_privileged
| 1131 -> Password_anonymous_user
| 1132 -> Password_not_allowed
| 1133 -> Password_no_match
| 1134 -> Update_info
| 1135 -> Cant_create_thread
| 1136 -> Wrong_value_count_on_row
| 1137 -> Cant_reopen_table
| 1138 -> Invalid_use_of_null
| 1139 -> Regexp_error
| 1140 -> Mix_of_group_func_and_fields
| 1141 -> Nonexisting_grant
| 1142 -> Tableaccess_denied_error
| 1143 -> Columnaccess_denied_error
| 1144 -> Illegal_grant_for_table
| 1145 -> Grant_wrong_host_or_user
| 1146 -> No_such_table
| 1147 -> Nonexisting_table_grant
| 1148 -> Not_allowed_command
| 1149 -> Syntax_error
| 1150 -> Delayed_cant_change_lock
| 1151 -> Too_many_delayed_threads
| 1152 -> Aborting_connection
| 1153 -> Net_packet_too_large
| 1154 -> Net_read_error_from_pipe
| 1155 -> Net_fcntl_error
| 1156 -> Net_packets_out_of_order
| 1157 -> Net_uncompress_error
| 1158 -> Net_read_error
| 1159 -> Net_read_interrupted
| 1160 -> Net_error_on_write
| 1161 -> Net_write_interrupted
| 1162 -> Too_long_string
| 1163 -> Table_cant_handle_blob
| 1164 -> Table_cant_handle_auto_increment
| 1165 -> Delayed_insert_table_locked
| 1166 -> Wrong_column_name
| 1167 -> Wrong_key_column
| 1168 -> Wrong_mrg_table
| 1169 -> Dup_unique
| 1170 -> Blob_key_without_length
| 1171 -> Primary_cant_have_null
| 1172 -> Too_many_rows
| 1173 -> Requires_primary_key
| 1174 -> No_raid_compiled
| 1175 -> Update_without_key_in_safe_mode
| 2000 -> Unknown_error
| 2001 -> Socket_create_error
| 2002 -> Connection_error
| 2003 -> Conn_host_error
| 2004 -> Ipsock_error
| 2005 -> Unknown_host
| 2006 -> Server_gone_error
| 2007 -> Version_error
| 2008 -> Out_of_memory
| 2009 -> Wrong_host_info
| 2010 -> Localhost_connection
| 2011 -> Tcp_connection
| 2012 -> Server_handshake_err
| 2013 -> Server_lost
| 2014 -> Commands_out_of_sync
| 2015 -> Namedpipe_connection
| 2016 -> Namedpipewait_error
| 2017 -> Namedpipeopen_error
| 2018 -> Namedpipesetstate_error
| 2019 -> Cant_read_charset
| 2020 -> Net_packet_too_large
| _ -> Unknown_error


(* Status of MySQL database after an operation. Especially indicates empty 
   result sets *)

type status     =
                | StatusOK
                | StatusEmpty
                | StatusError of error_code

(* database field type *)

type dbty       = IntTy         (* 0  *)
                | FloatTy       (* 1  *)
                | StringTy      (* 2  *)
                | SetTy         (* 3  *)
                | EnumTy        (* 4  *)
                | DateTimeTy    (* 5  *)
                | DateTy        (* 6  *)
                | TimeTy        (* 7  *)
                | YearTy        (* 8  *)
                | TimeStampTy   (* 9  *)
                | UnknownTy     (* 10 *)
                | Int64Ty       (* 11 *)
		| BlobTy        (* 12 *)
		| DecimalTy	(* 13 *)

let pretty_type = function
  | IntTy -> "integer"
  | FloatTy -> "float"
  | StringTy -> "string"
  | SetTy -> "set"
  | EnumTy -> "enum"
  | DateTimeTy  -> "datetime"
  | DateTy        -> "date"
  | TimeTy        -> "time"
  | YearTy        -> "year"
  | TimeStampTy   -> "timestamp"
  | UnknownTy     -> "unknown"
  | Int64Ty       -> "int64"
  | BlobTy        -> "blob"
  | DecimalTy     -> "decimal"


(* database login informations -- use None for default values *)

type db         =
                { dbhost    : string option  (*    database server host *)
                ; dbname    : string option  (*    database name        *)
                ; dbport    : int option     (*    port                 *)
                ; dbpwd     : string option  (*    user password          *)
                ; dbuser    : string option  (*    database user        *)
                }

type field = { name : string; (* Name of the field *)
               table : string option; (* Table name, or None if a constructed field *)
               def : string option; (* Default value of the field *)
               ty : dbty;
               max_length : int; (* Maximum width of field for the result set *)
               flags : int; (* Flags set *)
               decimals : int (* Number of decimals for numeric fields *)
             } 



(* low level C interface *)

let defaults = { dbhost = None; dbname = None; dbport = None; dbpwd = None; dbuser = None }
                                
external connect    : db -> dbd                             = "db_connect"

let quick_connect ?host ?database ?port ?password ?user () =
  connect { dbhost = host; dbname = database; dbport = port; dbpwd = password; dbuser = user }

external change_user : dbd -> db -> unit                    = "db_change_user"    

let quick_change ?user ?password ?database conn =
  change_user conn { defaults with
		       dbuser = user; dbpwd = password; dbname = database }

external select_db   : dbd -> string -> unit                = "db_select_db"
external list_dbs    : dbd -> ?pat:string -> unit -> string array option = "db_list_dbs"
external disconnect : dbd -> unit                           = "db_disconnect"
external ping       : dbd -> unit                           = "db_ping"
external exec       : dbd -> string -> result               = "db_exec"
external real_status     : dbd -> int                         = "db_status"
external errmsg     : dbd -> string option                  = "db_errmsg"
external escape     : string -> string                      = "db_escape"
external fetch      : result -> string option array option  = "db_fetch" 
external to_row     : result -> int64 -> unit                 = "db_to_row"
external size       : result -> int64                         = "db_size"
external affected    : dbd -> int64                           = "db_affected"
external insert_id: dbd -> int64 = "db_insert_id"
external fields     : result -> int                         = "db_fields"
external client_info : unit -> string = "db_client_info"
external host_info   : dbd -> string = "db_host_info"
external server_info : dbd -> string = "db_server_info"
external proto_info  : dbd -> int    = "db_proto_info"
external fetch_field : result -> field option = "db_fetch_field"
external fetch_fields : result -> field array option = "db_fetch_fields"
external fetch_field_dir : result -> int -> field option = "db_fetch_field_dir"

let status dbd =
  let x = real_status dbd in
  match x with
    0 -> StatusOK
  | 1065 -> StatusEmpty
  | _ -> StatusError (error_of_int x)

let errno dbd = error_of_int (real_status dbd)

(* [sub start len str] returns integer obtained from substring of length 
   [len] from [str] *)
  
let sub start len str = int_of_string (String.sub str ~pos:start ~len)

(* xxx2ml parses a string returned from a MySQL field typed xxx and turns it into a 
   corresponding OCaml value.

   MySQL uses the following representations for date/time values
    
   DATETIME     yyyy-mm-dd hh:mm:ss
   DATE         yyyy-mm-dd'
   TIME         hh:mm:ss'
   YEAR         yyyy'
   TIMESTAMP    YYYYMMDDHHMMSS'
*)   
 

let int2ml   str        = int_of_string str
let decimal2ml   str    = str
let int322ml str        = Int32.of_string str
let int642ml str        = Int64.of_string str
let nativeint2ml str    = Nativeint.of_string str
let float2ml str        = float_of_string str
let str2ml   str        = str
let enum2ml  str        = str
let blob2ml  str        = str

(* [set2ml str] parses a comma separated list of words in [str] and
   returns them in a list.  MySQL uses this format for sets of values
   *)

let set2ml str =
    let lexer       = make_lexer [ "," ]                                in
    let tokens      = lexer(Stream.of_string str)                       in
    let rec list    = parser
                      | [< 'Ident i; t = tail >]    -> i :: t
                      | [< >]                       -> []               
    and tail        = parser
                      | [< 'Kwd ","; l = list >]    -> l
                      | [< >]                       -> []               in
            try
                list tokens
            with Parsing.Parse_error -> fail ("not a proper set: " ^ str)


let datetime2ml str =
    assert (String.length str = 19);

    let year    = sub 0  4 str   in
    let month   = sub 5  2 str   in 
    let day     = sub 8  2 str   in
    let hour    = sub 11 2 str   in
    let minute  = sub 14 2 str   in
    let second  = sub 17 2 str   in
        (year,month,day,hour,minute,second)

let date2ml str =
    assert (String.length str = 10);

    let year    = sub 0  4 str   in
    let month   = sub 5  2 str   in 
    let day     = sub 8  2 str   in
        (year,month,day)

   
let time2ml str =
    assert ((String.length str >= 8) && (String.length str <=9));
     
  let bonus = (String.length str) - 8 in 
    let hour    = sub 0 (2+bonus) str   in
    let minute  = sub (3+bonus) 2 str   in
    let second  = sub (6+bonus) 2 str   in
        (hour,minute,second)
    
                                  
let year2ml str =
    assert (String.length str = 4);
    sub 0 4 str
    

let timestamp2ml str =
    assert (String.length str = 14);

    let year    = sub 0  4 str   in
    let month   = sub 4  2 str   in 
    let day     = sub 6  2 str   in
    let hour    = sub 8  2 str   in
    let minute  = sub 10 2 str   in
    let second  = sub 12 2 str   in
        (year,month,day,hour,minute,second)


            

(* [opt f v] applies [f] to optional value [v]. Use this to fetch
   data of known type from database fields which might be NULL:
   [opt int2ml str] *)

let opt f arg = match arg with 
    | None      -> None
    | Some x    -> Some (f x)
    
(* [not_null f v] applies [f] to [Some v]. Use this to fetch data of known 
   type from database fields which never can be NULL: [not_null int2ml str] 
*)
    
let not_null f arg = match arg with
    | None      -> fail "not_null was applied to None"
    | Some x    -> f x 


let names result =
  Array.init (fields result) ~f:(function offset ->
    match fetch_field_dir result offset with
      Some field -> field.name
    | None -> "")
  
let types result =
  Array.init (fields result) ~f:(function offset ->
    match fetch_field_dir result offset with
      Some field -> field.ty
    | None -> (fail "Unknown type in field"))

(* [column result] returns a function [col] which fetches columns from
   results by column name.  [col] has type string -> 'a array -> 'b. 
   Where the first argument is the name of the column. 
   

        let r   = exec dbd "select * from table"  in
        let col = col r                           in
        let rec loop = function
            None   -> []
            Some a -> not_null int2ml (col "label" a) :: loop (fetch r)
        in 
            loop (fetch r)
        
*)

        
let column result =
    let names = names result                                    in
    let map   = (* maps names to positions *)
        match Array.length names with
        | 0 -> StrMap.empty
        | n -> let rec loop i map =
                 if   i = n 
                 then map
                 else loop (i+1) (StrMap.add ~key:names.(i) ~data:i map)
               in
                 loop 0 StrMap.empty                            in
     (* return column name from array and apply f *)
     let col ~key ~row =
       row.(StrMap.find key map)
     in
        col

(* ml2xxx encodes OCaml values into strings that match the MysQL syntax of 
   the corresponding type *)
  
let ml2str str  = "'" ^ escape str ^ "'"
let ml2blob     = ml2str
let ml2int x    = string_of_int x
let ml2decimal x    = x
let ml322int x  = Int32.to_string x
let ml642int x  = Int64.to_string x
let mlnative2int x = Nativeint.to_string x
let ml2float x  = string_of_float x
let ml2enum x   = escape x
let ml2set x    = let rec loop arg = match arg with
                    | []        -> ""
                    | [x]       -> escape x
                    | x::y::ys  -> escape x ^ "," ^ loop (y::ys)
                  in
                    loop x  

let ml2datetimel ~year ~month ~day ~hour ~min ~sec =
    Printf.sprintf "'%04d-%02d-%02d %02d:%02d:%02d'"
      year month day hour min sec
let ml2datetime (year,month,day,hour,min,sec) =
  ml2datetimel ~year ~month ~day ~hour ~min ~sec

let ml2datel ~year ~month ~day =
  Printf.sprintf "%04d-%02d-%02d" year month day
let ml2date (year,month,day) =
  ml2datel ~year ~month ~day

let ml2timel ~hour ~min ~sec =
  Printf.sprintf "%02d:%02d%02d" hour min sec
let ml2time (hour,min,sec) =
  ml2timel ~hour ~min ~sec

let ml2year yyyy = Printf.sprintf "%04d" yyyy

let ml2timestampl ~year ~month ~day ~hour ~min ~sec =
    Printf.sprintf "%04d%02d%02d%02d%02d%02d" year month day hour min sec
let ml2timestamp (year,month,day,hour,min,sec) =
  ml2timestampl ~year ~month ~day ~hour ~min ~sec



(* [values vs] creates from a list of values in MySQL format
   a vector (x,y,z,..) for the MySQL values construct *)

let values vs = 
    let rec loop arg = match arg with
        | []        -> ""
        | [x]       -> x
        | x::y::ys  -> x ^ "," ^ loop (y::ys)
    in
        "(" ^ loop vs ^ ")"


(* Apply f to each row or a specific column of the results *)
let iter res ~f =
  if size res > Int64.zero then
    let rec loop () =
      match fetch res with
	  Some row -> f row; loop ()
	| None -> () in
      to_row res Int64.zero;
      loop ()

let iter_col res ~key ~f =
  let col = column res ~key in
  iter res ~f:(function row -> f (col ~row))

let iter_cols res ~key ~f =
  let col = column res in
  iter res ~f:(function row -> f (Array.map key ~f:(function key -> col ~key ~row)))

let map res ~f =
  if size res > Int64.zero then
    let rec loop lst = 
      match fetch res with
	  Some row -> loop (f row :: lst)
	| None -> lst in
      to_row res Int64.zero;
      List.rev (loop [])
  else
    []
      
let map_col res ~key ~f =
  let col = column res ~key in
  map res ~f:(function row -> f (col ~row))

let map_cols res ~key ~f =
  let col = column res in
  map res ~f:(function row -> f (Array.map key ~f:(function key -> col ~key ~row)))

