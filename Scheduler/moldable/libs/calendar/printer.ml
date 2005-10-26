(*
 * Calendar library
 * Copyright (C) 2003 Julien SIGNOLES
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License version 2, as published by the Free Software Foundation.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * 
 * See the GNU Library General Public License version 2 for more details
 *)

(*i $Id: printer.ml,v 1.1 2005/03/23 16:20:08 eyraudl Exp $ i*)

module type S = sig
  type t

  val fprint : string -> Format.formatter -> t -> unit
  val print : string -> t -> unit
  val dprint : t -> unit
  val sprint : string -> t -> string
  val to_string : t -> string

  val from_fstring : string -> string -> t
  val from_string : string -> t
end

let day_name = 
  ref (function
	 | Date.Sun -> "Sunday"
	 | Date.Mon -> "Monday"
	 | Date.Tue -> "Tuesday"
	 | Date.Wed -> "Wednesday"
	 | Date.Thu -> "Thurday"
	 | Date.Fri -> "Friday"
	 | Date.Sat -> "Saturday")

let name_of_day d = !day_name d

let short_name_of_day d = 
  let d = name_of_day d in
  try String.sub d 0 3 with Invalid_argument _ -> d

let month_name =
  ref (function
	 | Date.Jan -> "January"
	 | Date.Feb -> "February"
	 | Date.Mar -> "Mars"
	 | Date.Apr -> "April"
	 | Date.May -> "May"
	 | Date.Jun -> "June"
	 | Date.Jul -> "July"
	 | Date.Aug -> "August"
	 | Date.Sep -> "September"
	 | Date.Oct -> "October"
	 | Date.Nov -> "November"
	 | Date.Dec -> "December")

let name_of_month m = !month_name m

let short_name_of_month m = 
  let m = name_of_month m in
  try String.sub m 0 3 with Invalid_argument _ -> m

type pad =
  | Zero
  | Blank
  | Empty

(* [k] should be a power of 10. *)
let print_number fmt pad k n =
  let rec aux k n =
    let fill fmt = function
      | Zero -> Format.pp_print_int fmt 0
      | Blank -> Format.pp_print_char fmt ' '
      | Empty -> ()
    in
    if k = 0 then Format.pp_print_int fmt n
    else begin
      if n < k then fill fmt pad;
      aux (k mod 10) n
    end
  in
  if n < 0 then Format.pp_print_char fmt '-';
  aux k (abs n)

let bad_format s = raise (Invalid_argument ("bad format: " ^ s))

let not_match f s = 
  raise (Invalid_argument (s ^ " does not match the format " ^ f))

(* [Make] creates a printer from a small set of functions. *)
module Make(X : sig
	      type t
	      val make : int -> int -> int -> int -> int -> int -> t
	      val default_format : string
	      val hour : t -> int
	      val minute : t -> int
	      val second : t -> int
	      val day_of_week : t -> Date.day
	      val day_of_month : t -> int
	      val day_of_year : t -> int
	      val week : t -> int
	      val month : t -> Date.month
	      val year : t -> int
	    end) =
struct
  type t = X.t

  let fprint f fmt x =
    let len = String.length f in
    let weekday = lazy (name_of_day (X.day_of_week x)) in
    let sweekday = lazy (short_name_of_day (X.day_of_week x)) in
    let day_of_week = lazy (Date.int_of_day (X.day_of_week x)) in
    let month_name = lazy (name_of_month (X.month x)) in
    let smonth_name = lazy (short_name_of_month (X.month x)) in
    let int_month = lazy (Date.int_of_month (X.month x)) in
    let day_of_month = lazy (X.day_of_month x) in
    let day_of_year = lazy (X.day_of_year x) in
    let week = lazy (X.week x) in
    let year = lazy (X.year x) in
    let syear = lazy (Lazy.force year mod 100) in
    let hour = lazy (X.hour x) in
    let shour = 
      lazy (let h = Lazy.force hour in (if h = 0 then 24 else h) mod 12) in
    let minute = lazy (X.minute x) in
    let second = lazy (X.second x) in
    let apm = lazy (if Lazy.force hour < 12 then "AM" else "PM") in
    let print_char c = Format.pp_print_char fmt c in
    let print_int pad k n = print_number fmt pad k (Lazy.force n) in
    let print_string s = Format.pp_print_string fmt (Lazy.force s) in
    let print_time pad h =
      print_int pad 10 h;
      print_char ':';
      print_int pad 10 minute;
      print_char ':';
      print_int pad 10 second in
    let rec parse_option i pad =
      let parse_char c = 
	begin match c with
	  | '%' -> print_char '%'
	  | 'a' -> print_string sweekday
	  | 'A' -> print_string weekday
	  | 'b' | 'h' -> print_string smonth_name
	  | 'B' -> print_string month_name
	  | 'c' ->
	      print_string sweekday;
	      print_char ' ';
	      print_string smonth_name;
	      print_char ' ';
	      print_int pad 10 day_of_month;
	      print_char ' ';
	      print_time pad hour;
	      print_char ' ';
	      print_int pad 1000 year
	  | 'd' -> print_int pad 10 day_of_month
	  | 'D' -> 
	      print_int pad 10 int_month;
	      print_char '/';
	      print_int pad 10 day_of_month;
	      print_char '/';
	      print_int pad 10 syear
	  | 'e' -> print_int Blank 10 day_of_month
	  | 'H' -> print_int pad 10 hour;
	  | 'i' ->
	      print_int pad 1000 year;
	      print_char '-';
	      print_int pad 10 int_month;
	      print_char '-';
	      print_int pad 10 day_of_month
	  | 'I' -> print_number fmt pad 10 (Lazy.force hour mod 12)
	  | 'j' -> print_int pad 100 day_of_year
	  | 'k' -> print_int Blank 10 hour
	  | 'l' -> print_number fmt Blank 10 (Lazy.force hour mod 12)
	  | 'm' -> print_int pad 10 int_month
	  | 'M' -> print_int pad 10 minute
	  | 'n' -> print_char '\n'
	  | 'p' -> print_string apm
	  | 'r' -> 
	      print_time pad shour;
	      print_char ' ';
	      print_string apm
	  | 'S' -> print_int pad 10 second
	  | 't' -> print_char '\t'
	  | 'T' -> print_time pad hour
	  | 'V' | 'W' -> print_int pad 10 week	     
	  | 'w' -> print_int Empty 1 day_of_week
	  | 'y' -> print_int pad 10 syear
	  | 'Y' -> print_int pad 1000 year
	  | c  -> bad_format ("%" ^ String.make 1 c)
	end;
	parse_format (i + 1)
      in
      assert (i <= len);
      if i = len then bad_format f;
      (* else *)
      match f.[i] with
	| '-' -> 
	    if pad <> Zero then bad_format f;
	    (* else *) parse_option (i + 1) Empty
	| '_' -> 
	    if pad <> Zero then bad_format f;
	    (* else *) parse_option (i + 1) Blank
	| c  -> parse_char c
    and parse_format i =
      assert (i <= len);
      if i = len then ()
      else match f.[i] with
	| '%' -> parse_option (i + 1) Zero
	| c   -> 
	    Format.pp_print_char fmt c;
	    parse_format (i + 1)
    in 
    parse_format 0;
    Format.pp_print_flush fmt ()

  let print f = fprint f Format.std_formatter

  let dprint = print X.default_format

  let sprint f d = 
    let buf = Buffer.create 15 in
    let fmt = Format.formatter_of_buffer buf in
    fprint f fmt d;
    Buffer.contents buf

  let to_string = sprint X.default_format

  let from_fstring f s = 
    let year, month, day = ref (-1), ref (-1), ref (-1) in
    let hour, minute, second = ref (-1), ref (-1), ref (-1) in
    let j = ref 0 in
    let lenf = String.length f in
    let lens = String.length s in
    let read_char c =
      if !j >= lens || s.[!j] != c then not_match f s;
      incr j 
    in
    let read_number n =
      let jn = !j + n in
      if jn > lens then not_match f s;
      let res = 
	try int_of_string (String.sub s !j n)
	with Failure _ -> not_match f s
      in 
      j := jn;
      res
    in
    let rec parse_option i = 
      assert (i <= lenf);
      if i = lenf then bad_format f;
      (* else *)
      (match f.[i] with
	 | '%' -> read_char '%'
	 | 'd' -> day := read_number 2
	 | 'D' -> 
	     month := read_number 2;
	     read_char '/';
	     day := read_number 2;
	     read_char '/';
	     year := read_number 2 + 1900
	 | 'H' -> hour := read_number 2
	 | 'i' ->
	     year := read_number 4;
	     read_char '-';
	     month := read_number 2;
	     read_char '-';
	     day := read_number 2
	 | 'm' -> month := read_number 2
	 | 'M' -> minute := read_number 2
	 | 'S' -> second := read_number 2
	 | 'T' ->
	     hour := read_number 2;
	     read_char ':';
	     minute := read_number 2;
	     read_char ':';
	     second := read_number 2
	 | 'y' -> year := read_number 2 + 1900
	 | 'Y' -> year := read_number 4
	 | c  -> bad_format ("%" ^ String.make 1 c));
      parse_format (i + 1)
    and parse_format i =
      assert (i <= lenf);
      if i = lenf then begin if !j != lens then not_match f s end
      else match f.[i] with
	| '%' -> parse_option (i + 1)
	| c -> 
	    read_char c;
	    parse_format (i + 1)
    in 
    parse_format 0; 
    X.make !year !month !day !hour !minute !second

  let from_string = from_fstring X.default_format
end

let cannot_create_event kind args =
  if List.exists ((=) (-1)) args then
    raise (Invalid_argument ("Cannot create the " ^ kind))

module DatePrinter = 
  Make(struct 
	 include Date
	 let make y m d _ _ _ =
	   cannot_create_event "date" [ y; m; d ];
	   make y m d
	 let default_format = "%i"
	 let hour _ = bad_format "hour"
	 let minute _ = bad_format "minute"
	 let second _ = bad_format "second"
       end)

module TimePrinter = 
  Make(struct
	 include Time
	 let make _ _ _ h m s =
	   cannot_create_event "time" [ h; m; s ];
	   make h m s
	 let default_format = "%T"
	 let day_of_week _ = bad_format "day_of_week"
	 let day_of_month _ = bad_format "day_of_month"
	 let day_of_year _ = bad_format "day_of_year"
	 let week _ = bad_format "week"
	 let month _ = bad_format "month"
	 let int_month _ = bad_format "int_month"
	 let year _ = bad_format "year"
       end)

module CalendarPrinter = 
  Make(struct
	 include Calendar
	 let make y m d h mn s =
	   cannot_create_event "calendar" [ y; m; d; h; mn; s ];
	   make y m d h mn s
	 let default_format = "%i %T"
       end)
