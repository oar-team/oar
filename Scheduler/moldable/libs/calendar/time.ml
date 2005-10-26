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

(*i $Id: time.ml,v 1.1 2005/03/23 16:20:08 eyraudl Exp $ i*)

(*S Introduction.

  A time is represents by a number of seconds in UTC.
  Outside this module, a time is interpreted in the current time zone.
  So, each operations have to coerce a given time according to the current
  time zone. *)

(*S Datatypes. *)

type t = int

type field = [ `Hour | `Minute | `Second ]

(*S Conversions. *)

let one_day = 86400

let convert t t1 t2 = t + 3600 * Time_Zone.gap t1 t2

let from_gmt t = convert t Time_Zone.UTC (Time_Zone.current ())

let to_gmt t = convert t (Time_Zone.current ()) Time_Zone.UTC

(* Coerce [t] into the interval $[0; 86400[$ (i.e. a one day interval). *)
let normalize t = 
  let t = from_gmt t in
  let t_mod, t_div = to_gmt (t mod one_day), t / one_day in
  if t < 0 then t_mod + one_day, t_div - 1 else t_mod, t_div

(*S Constructors. *)

let make h m s = to_gmt (h * 3600 + m * 60 + s)

let lmake ?(hour = 0) ?(minute = 0) ?(second = 0) () = make hour minute second

let midnight () = to_gmt 0

let midday () = to_gmt 43200

let now () =
  let now = Unix.gmtime (Unix.time ()) in
  3600 * now.Unix.tm_hour + 60 * now.Unix.tm_min + now.Unix.tm_sec

(*S Getters. *)

let hour t = from_gmt t / 3600

let minute t = from_gmt t mod 3600 / 60

let second t = from_gmt t mod 60

let to_hours t = float_of_int (from_gmt t) /. 3600.

let to_minutes t = float_of_int (from_gmt t) /. 60.

let to_seconds t = from_gmt t

(*S Boolean operations. *)

let compare = compare

let equal = (==)

let is_pm t = 
  let t, _ = normalize t in 
  let m, _ = normalize (midday ()) in
  t < m

let is_am t = 
  let t, _ = normalize t in 
  let m, _ = normalize (midday ()) in
  t >= m

(*S Coercions. *)

let from_hours t = to_gmt (int_of_float (t *. 3600.))

let from_minutes t = to_gmt (int_of_float (t *. 60.))

let from_seconds t = to_gmt t

(*S Period. *)

module Period = struct

  type t = int

  let make h m s = h * 3600 + m * 60 + s
  let lmake ?(hour=0) ?(minute=0) ?(second=0) () = make hour minute second

  let length x = x

  let hour x = x * 3600
  let minute x = x * 60
  let second x = x

  let empty = 0

  let add = (+)
  let sub = (-)
  let mul = ( * )
  let div = (/)

  let opp x = - x

  let compare = compare
  let equal = (==)

  let to_seconds x = x
  let to_minutes x = float_of_int x /. 60.
  let to_hours x = float_of_int x /. 3600.

end

(*S Arithmetic operations on times and periods. *)

let add = (+)
let sub = (-)
let rem = (-)

let next x = function
  | `Hour   -> x + 3600
  | `Minute -> x + 60
  | `Second -> x + 1

let prev x = function
  | `Hour   -> x - 3600
  | `Minute -> x - 60
  | `Second -> x - 1
