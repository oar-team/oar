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

(*i $Id: printer.mli,v 1.1 2005/03/23 16:20:08 eyraudl Exp $ i*)

(** Pretty printing.

  In the following, an "event" is either a date or a time or a calendar.
  
  This module implements three printers: one for each kind of events.
  The three printers have the same signature: 
  they mainly implement a [fprint : string -> formatter -> t -> unit] function
  and a [from_fstring : string -> string -> t] function.
  The first one prints an event according to a format string 
  (see below for a description of such a format). 
  The second one converts a string to an event according to a format string.

  A format string follows the unix date utility (with few modifications). 
  It is a string which contains two types of objects: plain characters and 
  conversion specifications. Those specifications are introduced by 
  a [%] character and their meanings are:
  - [%%]: a literal [%]
  - [%a]: short day name (by using a short version of [day_name])
  - [%A]: day name (by using [day_name])
  - [%b]: short month name (by using a short version of [month_name])
  - [%B]: month name (by using [month_name])
  - [%c]: shortcut for [%a %b %d %H:%M:%S %Y]
  - [%d]: day of month (01..31)
  - [%D]: shortcut for [%m/%d/%y]
  - [%e]: same as [%_d]
  - [%h]: same as [%b]
  - [%H]: hour (00..23)
  - [%I]: hour (01..12)
  - [%i]: shortcut for [%Y-%m-%d]: ISO-8601 notation
  - [%j]: day of year (001..366)
  - [%k]: same as [%_H]
  - [%l]: same as [%_I]
  - [%m]: month (01..12)
  - [%M]: minute (00..59)
  - [%n]: a newline (same as [\n])
  - [%p]: AM or PM
  - [%r]: shortcut for [%I:%M:%S %p]
  - [%S]: second (00..60)
  - [%t]: a horizontal tab (same as [\t])
  - [%T]: shortcut for [%H:%M:%S]
  - [%V]: week number of year (01..53)
  - [%w]: day of week (1..7)
  - [%W]: same as [%V]
  - [%y]: last two digits of year (00..99)
  - [%Y]: year (four digits)
     
  By default, date pads numeric fields with zeroes. Two special modifiers 
  between [`%'] and a numeric directive are recognized:
  - ['-' (hyphen)]: do not pad the field
  - ['_' (underscore)]: pad the field with spaces
     
  For example:
  - a possible output of [%D] is [01/06/03];
  - a possible output of [the date is %B, the %-dth] is 
  [the date is January, the 6th] is matched by ;
  - a possible output of [%c] is [Thu Sep 18 14:10:51 2003]. 

  @since 1.05 *)

(** {1 Internationalization} 

  You can manage the string representations of days and months.
  By default, the English names are used but you can change their by
  setting the references [day_name] and [month_name].

  For example,
  [day_name := function Date.Mon -> "lundi" | Date.Tue -> "mardi" | 
     Date.Wed -> "mercredi" | Date.Thu -> "jeudi" | Date.Fri -> "vendredi" |
     Date.Sat -> "samedi" | Date.Sun -> "dimanche"]
  sets the names of the days to the French names. *)

val day_name : (Date.day -> string) ref
(** String representation of a day. *)

val name_of_day : Date.day -> string
(** [name_of_day d] is equivalent to [!day_name d]. 
  Used by the specification [%A]. *)

val short_name_of_day : Date.day -> string
(** [short_name_of_day d] returns the 3 first characters of [name_of_day d]. 
  Used by the specification [%a]. *)

val month_name : (Date.month -> string) ref
(** String representation of a month. *)
  
val name_of_month : Date.month -> string
(** [name_of_month m] is equivalent to [!day_month m]. 
  Used by the specification [%B]. *)

val short_name_of_month : Date.month -> string
(** [short_name_of_month d] returns the 3 first characters of 
   [name_of_month d]. 
   Used by the specification [%b]. *)

(** {1 Printers} *)

module type S = sig
  (** Generic signature of a printer. *)

  type t 
    (** Generic type of a printer. *)

  val fprint : string -> Format.formatter -> t -> unit
    (** [fprint format formatter x] outputs [x] on [formatter] according to
      the specified [format]. Raise [Invalid_argument] if the format is 
      incorrect. *)
    
  val print : string -> t -> unit
    (** [print format] is equivalent to [fprint format Format.std_formatter] *)

  val dprint : t -> unit
    (** Same as [print d] where [d] is the default format 
      (see the printer implementations). *)

  val sprint : string -> t -> string
    (** [sprint format date] converts [date] to a string according to [format].
     *)
    
  val to_string : t -> string
    (** Same as [sprint d] where [d] is the default format
      (see the printer implementations). *)

  val from_fstring : string -> string -> t
  (** [from_fstring format s] converts [s] to a date according to [format].
    The only available specifications are [%%], [%d], [%D], [%m], [%M], [%S],
    [%T], [%y] and [%Y].
    When the format has only two digits for the year number, 1900 are added
    to this number (see the example).
    
    Raise [Invalid_argument] if either the format is incorrect 
    or the string does not match the format
    or the event cannot be created (e.g. if you do not specify a year for
    a date).
    
    For example [from_fstring "the date is %D" "the date is 01/06/03"] returns
    a date equivalent to [Date.make 1903 1 6]. *)

  val from_string : string -> t
    (** Same as [from_fstring d] where [d] is the default format. *)

end

(** Date printer.
  The specifications which use time functionalities are not available 
  on this printer.

  The default format is [%i]. *)
module DatePrinter : S with type t = Date.t

(** Time printer.
  The specifications which use date functionalities are not available 
  on this printer.
  
  The default format is [%T]. *)
module TimePrinter : S with type t = Time.t

(** Calendar printer.

  The default format is [%i %T]. *)
module CalendarPrinter : S with type t = Calendar.t
