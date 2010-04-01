#!/usr/bin/ruby  
#
# $Id: oar_modules.rb 2008-04-05 16:00:00 ddepoisi $
# Contains ruby modules
#
# requirements:
# ruby1.8 (or greater)



module Oar

       # Search a oar conf file in differents path
       #        search also in the directory of oar.conf
       # Return :
       #    status : 0 file is readable / 1 otherwise
       #    config_file : full path name of the file 
       def Oar.conf_file_readable(config_file)
	   status=1
	   full_path=""

	   # search config file 
	   if File.readable?(config_file)
	      full_path = config_file
	      status=0
	   elsif ENV['OARCONFFILE'] 
		 path_tmp = File.split(ENV['OARCONFFILE'])[0]
		 if File.readable?(path_tmp+"/"+config_file)
	            full_path = path_tmp+"/"+config_file 
		    status=0
		 end
           elsif File.readable?("/etc/" + config_file)
	             full_path = "/etc/" + config_file
		     status=0
           elsif File.readable?("/etc/oar/" + config_file)
	             full_path = "/etc/oar/" + config_file
		     status=0
	   end

	   return status, full_path
       end	# Oar.conf_file_readable	



       # Load configuration
       # Search config file :
       # 	1) in the current directory
       # 	2) in $OARDIR directory
       # 	3) /etc/ directory
       # return value : 
       #     Always return a hash 
       #     If the configuration file not found, the hash is empty 
       def Oar.load_configuration

	   result = 0 
	   r = {}

	   # search config file 
           config_file = "oar.conf"
	   if !File.readable?(config_file)
	      if ENV['OARCONFFILE'] && File.readable?(ENV['OARCONFFILE'])
	         config_file = ENV['OARCONFFILE']
              elsif File.readable?("/etc/" + config_file)
	             config_file = "/etc/" + config_file
              elsif File.readable?("/etc/oar/" + config_file)
	             config_file = "/etc/oar/" + config_file
	      else
	   	   result = 1
	      end
	   end

           # load parameters
           if result == 0 
	      File.foreach(config_file) do |line|
	          line.strip!
	          # Skip comments and whitespace
	          if (line[0] != ?# and line =~ /\S/ )
	             i = line.index('=')
	             if (i)
	                v  = line[i + 1..-1].strip
	                v = v[1..v.length-2]
	                r[line[0..i - 1].strip] = v
	             else
	                r[line] = ''
	             end
	          end
	      end
	   end

	   return r

       end	# load_configuration

       # Print OAR version number       
       def Oar.version_number
	   version="OAR version : "
	   conf = Oar.load_configuration
	   dbh = Bdd.connect(conf) 
	   if dbh
	      table = "schema"	     
	      table = "`" + table + "`" if conf['DB_TYPE'].upcase == "MYSQL" 
	      q = "SELECT * FROM " + table + " ORDER BY version DESC"
	      rows = dbh.select_one(q) 
	      version += rows["version"] if rows
	      dbh.disconnect 
	   end
	   puts version
       end 	# Oar.version_number

end	# module Oar



# This module contains database features : access, update tables... using DBI
# Return values :
#    dbh : Database handle
#          dbh == nil if an error occurs
module Bdd
      
       # Connection to the database 
       # Params : conf is a hash 
       def Bdd.connect(conf)

           db_type = conf['DB_TYPE']
           db_type = "Mysql" if db_type == "mysql"
	   dbh = nil
	   !conf['DB_PORT'].nil? && conf['DB_PORT'].to_i>1 && conf['DB_PORT'].to_i < 65535 ? db_port=";port="+conf['DB_PORT'] : db_port=""
           begin
     	       dbh = DBI.connect("dbi:#{db_type}:host=#{conf['DB_HOSTNAME']};database=#{conf['DB_BASE_NAME']}#{db_port}",
	       		        	 "#{conf['DB_BASE_LOGIN']}","#{conf['DB_BASE_PASSWD']}")

     	       rescue DBI::DatabaseError => e
                      $stderr.puts "Error during the connection to the database" 
                      $stderr.puts "Error code: #{e.err}"
                      $stderr.puts "Error message: #{e.errstr}"
	   end
	
	   return dbh

       end	# def Bdd.connect


      # Access to the database and catch errors
      # Parameters : 
      #   dbh : databasehandle
      #   q : sql order
      #   *params : parameters for sql order
      # Return : 
      #    status => code error if an error occurs
      def Bdd.do(dbh, q, *params)
	  status = 0
	  begin
               dbh.do(q, *params)
               rescue DBI::DatabaseError => e
		   status = e.err
		   $stderr.puts "Error access to the database"
               	   $stderr.puts "Error code: #{e.err}"
               	   $stderr.puts "Error message: #{e.errstr}"
	  end
          status  
      end 	# def Bdd.do

end	# module Bdd


