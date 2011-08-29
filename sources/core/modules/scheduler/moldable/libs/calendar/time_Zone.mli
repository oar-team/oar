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

(** Time zone management.

  You can [change] the [current] time zone in your program by side effect. *)

(** Type of a time zone. *)
type t = 
  | UTC             (** Greenwich Meridian Time              *)
  | Local           (** Local Time                           *)
  | UTC_Plus of int (** Another time zone specified from UTC *)

val current : unit -> t
(** Return the current time zone. It is [UTC] before any change. *)

val change : t -> unit
(** Change the current time zone by another one. 
  Raise [Invalid_argument] if the specified time zone is [UTC_Plus x] with
  x < -12 or x > 11 *)

val gap : t -> t -> int
(** Return the gap between two time zone. 
  E.g. [gap UTC (UTC_Plus 5)] returns 5 and, at Paris in summer,
  [gap Local UTC] returns -2. *)

val from_gmt : unit  -> int
(** [from_gmt ()] is equivalent to [gap UTC (current ())]. *)

val to_gmt : unit -> int
(** [to_gmt ()] is equivalent to [gap (current ()) UTC]. *)
