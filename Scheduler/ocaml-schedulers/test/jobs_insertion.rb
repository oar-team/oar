
require 'sequel'

DB = Sequel.mysql(
  "oar",
  :user=>"oar",
  :password=>"oar",  
  :host => "localhost"  
 )  

jobs = DB[:jobs]
puts dataset.count


job_id =dataset.insert(:job_name=>"yop")
puts a
