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

(*i $Id$ i*)

(*S Introduction.

  A calendar is representing by its (exact) Julian Day -. 0.5.
  This gap of 0.5 is because the Julian period begins 
  January first, 4713 BC at MIDDAY (and then, this Julian day is 0.0). 
  But, for implementation facilities, the Julian day 0.0 is coded as
  January first, 4713 BC at MIDNIGHT.\\ *)

(* Round a float to the nearest int. *)
let round x =
  let f, i = modf x in
  int_of_float i + (if f < 0.5 then 0 else 1)

(*S Datatypes. *)

type t = float

type day = Date.day = Sun | Mon | Tue | Wed | Thu | Fri | Sat

type month = Date.month =
    Jan | Feb | Mar | Apr | May | Jun | Jul | Aug | Sep | Oct | Nov | Dec

type year = int

type field = [ Date.field | Time.field ]

(*S Conversions. *)

let convert x t1 t2 = x +. float_of_int (Time_Zone.gap t1 t2) /. 24.

let to_gmt x = convert x (Time_Zone.current ()) Time_Zone.UTC

let from_gmt x = convert x Time_Zone.UTC (Time_Zone.current ())

let from_date x = to_gmt (float_of_int (Date.to_jd x)) -. 0.5

(* Return the integral part of [x] as a date. *)
let to_date x = Date.from_jd (int_of_float (from_gmt x +. 0.5))

(* Return the fractional part of [x] as a time. *)
let to_time x = 
  let t, _ = modf (from_gmt x +. 0.5) in 
  let i = round (t *. 86400.) in
  assert (i < 86400);
  Time.from_seconds i

(*S Constructors. *)

let is_valid x = x >= 0. && x < 2914695.

let create d t = 
  to_gmt (float_of_int (Date.to_jd d) +. 
	    float_of_int (Time.to_seconds t) /. 86400.) -. 0.5

let make y m d h mn s = 
  let x = create (Date.make y m d) (Time.make h mn s) in
  if is_valid x then x else raise Date.Out_of_bounds

let lmake ~year ?(month=1) ?(day=1) ?(hour=0) ?(minute=0) ?(second=0) () =
  make year month day hour minute second

let now () = 
  let now = Unix.gmtime (Unix.time ()) in
  from_gmt (make 
	      (now.Unix.tm_year + 1900) 
	      (now.Unix.tm_mon + 1) 
	      (now.Unix.tm_mday) 
	      (now.Unix.tm_hour) 
	      (now.Unix.tm_min) 
	      (now.Unix.tm_sec))

let from_jd x = to_gmt x

let from_mjd x = to_gmt x +. 2400000.5

(*S Getters. *)

let to_jd x = from_gmt x

let to_mjd x = from_gmt x -. 2400000.5

let days_in_month x = Date.days_in_month (to_date x)

let day_of_week x = Date.day_of_week (to_date x)

let day_of_month x = Date.day_of_month (to_date x)

let day_of_year x = Date.day_of_year (to_date x)

let week x = Date.week (to_date x)

let month x = Date.month (to_date x)

let year x = Date.year (to_date x)

let hour x = Time.hour (to_time x)

let minute x = Time.minute (to_time x)

let second x = Time.second (to_time x)

(*S Coercions. *)

let from_unixtm x =
  make
    (x.Unix.tm_year + 1900) (x.Unix.tm_mon + 1) x.Unix.tm_mday
    x.Unix.tm_hour x.Unix.tm_min x.Unix.tm_sec

let to_unixtm x =
  let tm = Date.to_unixtm (to_date x)
  and t = to_time x in
  { tm with 
      Unix.tm_sec = Time.second t; 
      Unix.tm_min = Time.minute t; 
      Unix.tm_hour = Time.hour t }

let jan_1_1970 = 2440587.5

let from_unixfloat x = to_gmt (x /. 86400. +. jan_1_1970)

let to_unixfloat x = (from_gmt x -. jan_1_1970) *. 86400.

(*S Boolean operations on dates. *)

let equal x y = abs_float (x -. y) < 1e-6

let compare x y = 
  if equal x y then 0 
  else if x < y then -1
  else 1

let is_leap_day x = Date.is_leap_day (to_date x)

let is_gregorian x = Date.is_gregorian (to_date x)

let is_julian x = Date.is_julian (to_date x)

let is_pm x = Time.is_pm (to_time x)

let is_am x = Time.is_am (to_time x)

(*S Period. *)

module Period = struct
  type t = { d : Date.Period.t; t : Time.Period.t }

  let split x =
    let rec aux s =
      if s < 86400 then 0, s else let d, s = aux (s - 86400) in d + 1, s
    in
    let s = Time.Period.length x.t in
    let d, s =
      if s >= 0 then aux s else let d, s = aux (- s) in - (d + 1), - s + 86400
    in
    assert (s >= 0 && s < 86400);
    Date.Period.day d, Time.Period.second s

  let normalize x =
    let days, seconds = split x in
    { d = Date.Period.add x.d days; t = seconds }

  let empty = { d = Date.Period.empty; t = Time.Period.empty }

  let make y m d h mn s = 
    normalize { d = Date.Period.make y m d; t = Time.Period.make h mn s }

  let lmake 
    ?(year=0) ?(month=0) ?(day=0) ?(hour=0) ?(minute=0) ?(second=0) () =
    make year month day hour minute second

  let year x = { empty with d = Date.Period.year x }

  let month x = { empty with d = Date.Period.month x }

  let week x = { empty with d = Date.Period.week x }

  let day x = { empty with d = Date.Period.day x }

  let hour x = normalize { empty with t = Time.Period.hour x }

  let minute x = normalize { empty with t = Time.Period.minute x }

  let second x = normalize { empty with t = Time.Period.second x }

  let add x y = 
    normalize { d = Date.Period.add x.d y.d; t = Time.Period.add x.t y.t }

  let sub x y = 
    normalize { d = Date.Period.sub x.d y.d; t = Time.Period.sub x.t y.t }

  let opp x = normalize { d = Date.Period.opp x.d; t = Time.Period.opp x.t }

  (* Lexicographical order over the fields of the type [t].
     Yep, [Pervasives.compare] correctly works. *)
  let compare = Pervasives.compare

  let equal = (=)

  let to_date x = x.d

  let from_date x = { empty with d = x }

  let from_time x = { empty with t = x }

  exception Not_computable = Date.Period.Not_computable

  let to_time x = 
    Time.Period.add (Time.Period.hour (Date.Period.nb_days x.d * 24)) x.t

  let ymds x =
    let y, m, d = Date.Period.ymd x.d in
    y, m, d, Time.Period.to_seconds x.t

end

(*S Arithmetic operations on calendars and periods. *)

let split x = 
  let t, d = modf (from_gmt (x +. 0.5)) in 
  let t, d = round (t *. 86400.), int_of_float d in
  let t, d = if t < 0 then t + 86400, d - 1 else t, d in
  assert (t >= 0 && t < 86400);
  Date.from_jd d, Time.from_seconds t

let unsplit d t =
  to_gmt (float_of_int (Date.to_jd d) +. 
	    (float_of_int (Time.to_seconds t) /. 86400.)) -. 0.5

let add x p =
  let d, t = split x in
  unsplit (Date.add d p.Period.d) (Time.add t p.Period.t)

let rem x p = add x (Period.opp p)

let sub x y = 
  let d1, t1 = split x
  and d2, t2 = split y in
  Period.normalize { Period.d = Date.sub d1 d2; Period.t = Time.sub t1 t2 }

let next x f = 
  let d, t = split x in
  match f with
    | #Date.field as f -> unsplit (Date.next d f) t
    | #Time.field as f -> unsplit d (Time.next t f)

let prev x f = -. next (-. x) f
