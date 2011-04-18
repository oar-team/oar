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

type t = 
  | UTC
  | Local 
  | UTC_Plus of int

let tz = ref UTC

let out_of_bounds x = x < - 12 || x > 11

let in_bounds x = not (out_of_bounds x)

let gap_gmt_local = 
  let t = Unix.time () in
  (Unix.localtime t).Unix.tm_hour - (Unix.gmtime t).Unix.tm_hour

let current () = !tz

let change = function
  | UTC_Plus x when out_of_bounds x -> 
      raise (Invalid_argument "Not a valid time zone")
  | _ as t -> tz := t

let gap t1 t2 =
  let aux t1 t2 = 
    assert (t1 < t2);
    match t1, t2 with
      | UTC, Local             -> gap_gmt_local
      | UTC, UTC_Plus x        -> x
      | Local, UTC_Plus x      -> x - gap_gmt_local
      | UTC_Plus x, UTC_Plus y -> y - x
      | _                      -> assert false
  in let res = 
    if t1 = t2 then 0
    else if t1 < t2 then aux t1 t2
    else - aux t2 t1
  in
  assert (in_bounds res);
  res

let from_gmt () = gap UTC (current ())

let to_gmt () = gap (current ()) UTC
