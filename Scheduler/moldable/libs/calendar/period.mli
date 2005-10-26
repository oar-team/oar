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

(*i $Id: period.mli,v 1.1 2005/03/23 16:20:08 eyraudl Exp $ i*)

(** A period represents the time passed between two events (a date, a time...).
  Only an interface defining arithmetic operations on periods is defined here.
  An implementation of this interface depends on the kind of an event (see
  module [Time.Period], [Date.Period] and [Calendar.Period]). *)

module type S = sig

  type t
    (** Type of a period. *)

  val empty : t
    (** The empty period. *)

  val add : t -> t -> t
    (** Addition of periods. *)

  val sub : t -> t -> t
    (** Substraction of periods. *)

  val opp : t -> t
    (** Opposite of a period. *)

  val compare : t -> t -> int
    (** Comparaison function between two periods.
      Same behaviour than [Pervasives.compare]. *)

  val equal: t -> t -> bool
    (** Equality function between two periods. Same behaviour than [(=)]. 
      @since 1.09.0 *)

end
