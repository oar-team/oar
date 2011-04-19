open Mysql

let offset = Date.make 2000 1 1
let offset_int = Date.to_mjd offset

let date2days da = 
  Date.Period.nb_days (Date.sub da offset)
let days2date i = Date.add offset (Date.Period.day i)


let ymd2days (y, m, d) = 
  date2days (Date.make y m d)
let days2ymd i =
  let d =  days2date i in 
    (Date.year d, Date.int_of_month (Date.month d), Date.day_of_month d)
    

let hms2secs (h, m, s) = 
    (h*60 + m)*60 + s 

let unixtime2secs t = 
  let s = Unix.localtime t in 
    (date2days (Date.from_unixfloat t)) * 86400 
    + hms2secs (s.Unix.tm_hour, s.Unix.tm_min, s.Unix.tm_sec)

let datetime2secs s = 
  let (y, m, d, h, min, secs) = Mysql.datetime2ml s in 
  let nb_days = ymd2days (y, m, d) in 
    nb_days*86400 + hms2secs (h, min, secs)

let time2secs st = 
  hms2secs (time2ml st)

let secs2hms s = 
  let rs = s mod 60 and m = s / 60 in 
  let rm = m mod 60 and h = m / 60 in 
    (h, rm, rs) 

let secs2time s = 
  ml2time (secs2hms s)

let secs2ymdhms s = 
  let (h, rm, rs) = secs2hms s in 
  let rh = h mod 24 and d = h / 24 in 
  let (year, month, day) = days2ymd d in 
    (year, month, day, rh, rm, rs)

let secs2datetime s = 
  let u = secs2ymdhms s in 
  ml2datetime u 
