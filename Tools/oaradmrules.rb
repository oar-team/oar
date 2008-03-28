#!/usr/bin/ruby  
# $Id: oaradmrules.rb 1 2008-03-11 16:00:00 ddepoisi $
# manage admission rules : add, update, delete admission_rules 
#
# requirements:
# ruby1.8 (or greater)
# libdbi-ruby 
# libdbd-mysql-ruby or libdbd-pg-ruby
# 
# To activate the verbose mode, add -w at the end of the first line. Ex : #!/usr/bin/ruby -w
#

# Usage / examples
#   This program search and read oar.conf (with OARDIR environment variable or in current directory) 
#   Each rule may have # at the front lines - useful for summary display
#   1 - list admission rules
#       ./oaradmrules.rb -l       => summary display for all admission rules
#       ./oaradmrules.rb -l -c    => full content for all admission rules
#       ./oaradmrules.rb -l 3 5   => display admission rules nb 3 and 5
#   
#   2 - add admission rules
#       ./oaradmrules.rb -a -f file		=> add admission rule from file 
#       ./oaradmrules.rb -a no_rule -f file	=> insert admission rule at the no_rule position from file 
#						   the numbers above or equal to no_rule are increased by 1 
#   3 - update admission rule
#       ./oaradmrules.rb -u no_rule -f file	=> update the admission rule specified by no_rule from file 
#
#   4 - delete admission rules
#       ./oaradmrules.rb -d no_rule [no_rule]	=> delete the admission rules specified by user 
#       ./oaradmrules.rb -d 10 12 		=> delete admission rules 10 and 12 from database 
#
#   5 - export admission rules from database into text files in current directory
#       ./oaradmrules.rb -x       	=> export all admission rules from database and create one file per admission_rule with the name admission_rule_<no_rule> 
#       ./oaradmrules.rb -x 3 5   	=> export admission rules nb 3 and 5. Files admission_rule_3 and admission_rule_5 created
#       ./oaradmrules.rb -x 3 -f file   => export admission rules nb 5 into file
#       


require 'optparse'
require 'dbi'

$msg = []
$msg[0] = "Incoherence in specified options"
$msg[1] = "Configuration file not found"
$msg[2] = "Error access to the database"
$msg[3] = "Error : file not found or unreadable"
$msg[4] = "Admission rule added"
$msg[5] = "Error : bad admission rule number"
$msg[6] = "Error : no admission rule number given"
$msg[7] = "Admission rule updated"
$msg[8] = "Error while creating file"



$config = {} 		# Contains parameters of the configuration file
$list_rules = []
$result = []
$script = ""

$fic_base = "admission_rule_"		# Default name for file export



# Load configuration
# Search config file :
# 	1) in the current directory
# 	2) in $OARDIR directory
# 	3) /etc/ directory
# return values : 
#     0 : configuration file is found and parameters are loaded 
#     1 : configuration file not found  
def load_configuration

	result = 0 

	# search config file 
        config_file = "oar.conf"
	if !File.readable?(config_file)
	   if ENV['OARDIR'] && File.readable?(ENV['OARDIR'].to_s + "/" + config_file)
	      config_file = ENV['OARDIR'] + "/" + config_file
           elsif File.readable?("/etc/" + config_file)
	          config_file = "/etc/" + config_file
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
	             $config[line[0..i - 1].strip] = v
	          else
	             $config[line] = ''
	          end
	       end
	   end
	end

	return result

end	# load_configuration






# Options for parsing
$options = {}
$options[:list] = $options[:content] = $options[:add] = $options[:file] = $options[:update] = $options[:export] = $options[:delete] = false
opts = OptionParser.new do |opts|
    opts.banner = "Usage: oaradmrules [-l [-c]] [-a [no_rule] -f file] [-u no_rule -f file] [-d no_rule [no_rule]] [-x [no_rule] -f file]"

    # list admission rules
    opts.on("-l","--list","List admission rules") do 
       $options[:list] = true 
    end

    # full content 
    opts.on("-c","--content","Full content display") do
       $options[:content] = true
    end
   
    # add admission rules
    opts.on("-a","--add","Add admission rules") do 
       $options[:add] = true 
    end

    # file name 
    opts.on("-f","--file","File which contains script for admission rule") do 
       $options[:file] = true 
    end

    # update admission rules
    opts.on("-u","--update","Update admission rules") do 
       $options[:update] = true 
    end

    # delete admission rules
    opts.on("-d","--delete","Delete admission rules") do 
       $options[:delete] = true 
    end

    # export admission rules 
    opts.on("-x","--export","Export admission rules") do
       $options[:export] = true
    end

    # help
    opts.on_tail("-h", "--help", "Show this message") do
       puts opts
       exit
    end


end



# Display one rule
# Ndx : index in $result[] table
def rule_display ndx

    puts "------"
    puts "Rule : " + $result[ndx][:id]						# rule number

    title = false
    $result[ndx][:rule].each do |line|						# only the beginning of the rule : each line whith # caracter
         if line.strip.length > 0
            if line[0..0] == "#" 
               if !title
      	          puts "Beginning of the rule : " + line
	          title = !title
               else
                  puts "                        " + line
               end
            else
   	       break
            end
	 end 
    end
    puts "Beginning of the rule : " if !title


    if $options[:content]								# full content display
       puts "Content : "
       puts $result[ndx][:rule] 
    end

end 	# rule_display



# Retrieve list of rules given by user in the command line
# Store numbers of rules in $list_rules
def rule_list_from_command_line

   (0..ARGV.length-1).each do |i|
	if ARGV[i] =~ /\d+/
	   $list_rules.push($&.to_s)
	end
   end

end	# rule_list_from_command_line


# Select one or more rules 
# Store selected rules in $result 
def rule_select

   q = "SELECT * FROM admission_rules "
   if $list_rules.length > 0
      q += "WHERE id IN ("
      $list_rules.each_with_index do |item, item_index|
      	 q += item
	 q += "," if item_index < $list_rules.length-1
      end
      q += ") "
   else
      q += "ORDER BY id"
   end
   rows = $dbh.execute(q)
   rows.each do |r|
   	$result.push({:id => r["id"].to_s, :rule => r["rule"]})
   end
   rows.finish

end	# rule_select



# Test if files for export admission rules already exists
# Ask question if needed
# Return : 
#    true  => files can be overwrite
#    false => do not overwrite
def test_files_exists

   fic_already_exists = []

   if $list_rules.length > 0
       # Rules specified by user
       $list_rules.each do |item|
         (0..$result.length-1).each do |i|
	     if item == $result[i][:id]
                fic_already_exists.push($fic_base + $result[i][:id]) if File.exist?($fic_base + $result[i][:id])
	     end
	 end
       end
   else
       # All rules
       (0..$result.length-1).each do |i|
           fic_already_exists.push($fic_base + $result[i][:id]) if File.exist?($fic_base + $result[i][:id])
       end
   end

   if fic_already_exists.length > 0 
      c = ""
      fic_already_exists.each { |f| 
         c += f
	 c += " "
	 }
      puts "Warning ! Some files already exists : " + c 
      print "Overwrite [N/y] ? "
      r = ""
      begin
         r = $stdin.gets.chomp
      end while ( r != "" && r != "N" && r != "y" )
      if r == "y" 
         return true
      else
         return false
      end
   else
      return true
   end 

end 	# test_files_exists



# Export a rule in a file
# n : number of rule to export
def rule_export n

    fic_name = $fic_base + $result[n][:id]
    puts "Export admission rule " + $result[n][:id] + " into file " + fic_name
    f = File.new(fic_name, "w")
    f.print $result[n][:rule]
    f.close

end 	# rule_export



# Test if the file given by user is readable or not 
# Read the content of the file which contains admission rule
# $script contains the admission rule script
def load_rule_from_file

   $script = file_name = ""
   if $options[:file]
      (0..ARGV.length-1).each do |i|
	if ARGV[i] == "-f" 
	   file_name = ARGV[i+1] if i < ARGV.length-1 
	end
      end
      if !File.readable?(file_name) 
         puts $msg[3] 
         exit(5)
      else
     	 File.open(file_name) do |file|
	      while line = file.gets
	            $script << line
	      end
	 end
      end
   end 	# if $options[:file]

end



#####################
# MAIN PROGRAM
#####################

begin
     opts.parse ARGV

     rescue OptionParser::ParseError => no_erreur
        puts no_erreur
        exit(1)

end


# Other tests on syntax
if !( ( $options[:list] && !$options[:content] && !$options[:add] && !$options[:file] && !$options[:update] && !$options[:delete] && !$options[:export]) || 	# -l 
      ( $options[:list] &&  $options[:content] && !$options[:add] && !$options[:file] && !$options[:update] && !$options[:delete] && !$options[:export]) || 	# -l -c
      (!$options[:list] && !$options[:content] &&  $options[:add] &&  $options[:file] && !$options[:update] && !$options[:delete] && !$options[:export]) || 	# -a -f
      (!$options[:list] && !$options[:content] && !$options[:add] &&  $options[:file] &&  $options[:update] && !$options[:delete] && !$options[:export]) || 	# -u -f
      (!$options[:list] && !$options[:content] && !$options[:add] && !$options[:file] && !$options[:update] &&  $options[:delete] && !$options[:export]) || 	# -d 
      (!$options[:list] && !$options[:content] && !$options[:add] && !$options[:file] && !$options[:update] && !$options[:delete] &&  $options[:export]) || 	# -x  
      (!$options[:list] && !$options[:content] && !$options[:add] &&  $options[:file] && !$options[:update] && !$options[:delete] &&  $options[:export]) ) 	# -x -f

      puts $msg[0]
      exit(2)
end


# Choice of the editor  
$editor = "vi"
$editor = ENV['EDITOR'] if ENV['EDITOR']


# Load configuration file
if load_configuration > 0 
	puts $msg[1]
	exit(3)
end


# Connect to the database
begin
     db_type = $config['DB_TYPE']
     db_type = "Mysql" if db_type == "mysql"
     $dbh = DBI.connect("dbi:#{db_type}:#{$config['DB_BASE_NAME']}:#{$config['DB_HOSTNAME']}",
				 "#{$config['DB_BASE_LOGIN']}","#{$config['DB_BASE_PASSWD']}")

     rescue DBI::DatabaseError => e
         puts $msg[2] 
         puts "Error code: #{e.err}"
         puts "Error message: #{e.errstr}"
	 exit(4)
end


# List admission rules
if $options[:list]

   # rules given by user
   rule_list_from_command_line

   # select rules from database
   rule_select

   if $list_rules.length > 0
      # Display rules specified by user
      $list_rules.each do |item|
         rule_exist=false
         (0..$result.length-1).each do |i|
	     if item == $result[i][:id]
	        rule_exist=true
		rule_display i
	     end
	 end
         if !rule_exist
	    puts "Error : the rule #{item} does not exist"
	 end
      end      
   else
      # Display all rules
      (0..$result.length-1).each do |i|
          rule_display i
      end
   end

end 	# if $options[:list]




# Add admission rule
if $options[:add]

   no_rule = nil 

   # retrieve no rule specified by user
   (0..ARGV.length-1).each do |i|
       if ARGV[i] == "-a" 
          if i < ARGV.length-1
	     no_rule = $&.to_s.to_i if ARGV[i+1] =~ /\d+/ 
 	  end
       end
   end

   # add one admission rule from a file 
   load_rule_from_file

   # add admission rule in database
   if no_rule
	# no rule given by user ok ?
 	if no_rule <= 0
	   puts $msg[5]
           exit(7)
	end
	# no rule already exist in database ?
	q = "SELECT * FROM admission_rules WHERE id = " + no_rule.to_s
	rows = $dbh.select_one(q) 
	if rows
	   # add +1 to the id rules
	   q = "SELECT * FROM admission_rules WHERE id >= " + no_rule.to_s + " ORDER BY id DESC"
   	   rows = $dbh.execute(q)
	   rows.each do |r|
		begin
		    q = "UPDATE admission_rules SET id = " + (r["id"] + 1).to_s + " WHERE id = " + r["id"].to_s
            	    $dbh.do(q)
            	    rescue DBI::DatabaseError => e
                	puts $msg[2] 
                	puts "Error code: #{e.err}"
                	puts "Error message: #{e.errstr}"
	        	exit(6) 
		end
	   end
	   rows.finish
	end
	
	# Add rule in database
        begin
            $dbh.do("INSERT INTO admission_rules (id, rule) VALUES(?, ?)", no_rule, $script)
	    puts $msg[4]
	    exit
            rescue DBI::DatabaseError => e
                puts $msg[2] 
                puts "Error code: #{e.err}"
                puts "Error message: #{e.errstr}"
	        exit(6) 
        end

   else
	# add admission rule at the end of table
        begin
            $dbh.do("INSERT INTO admission_rules (rule) VALUES(?)", $script)
	    puts $msg[4]
	    exit
            rescue DBI::DatabaseError => e
                puts $msg[2] 
                puts "Error code: #{e.err}"
                puts "Error message: #{e.errstr}"
	        exit(6) 
        end
   end

end	# if $options[:add]



# Update admission rule
if $options[:update]

   no_rule = nil 

   # retrieve no rule specified by user
   (0..ARGV.length-1).each do |i|
       if ARGV[i] == "-u" 
          if i < ARGV.length-1
	     no_rule = $&.to_s.to_i if ARGV[i+1] =~ /\d+/ 
 	  end
       end
   end

   load_rule_from_file

   if no_rule
      if no_rule <= 0
         puts $msg[5]
         exit(7)
      end
      # no rule already exist in database ?
      q = "SELECT * FROM admission_rules WHERE id = " + no_rule.to_s
      rows = $dbh.select_one(q) 
      if rows
	 begin
	     q = "UPDATE admission_rules SET rule = ? WHERE id = " + no_rule.to_s
             $dbh.do(q, $script)
	     puts $msg[7]
             rescue DBI::DatabaseError => e
               	puts $msg[2] 
               	puts "Error code: #{e.err}"
               	puts "Error message: #{e.errstr}"
	       	exit(6) 
	 end
      else
	  puts "Error : the rule " + no_rule.to_s + " does not exist"
      end
   else
      puts $msg[6]
      exit(7) 
   end

end	# if $options[:update]



# Delete admission rules
if $options[:delete]

   # rules given by user
   rule_list_from_command_line

   # select rules from database
   rule_select

   if $list_rules.length > 0
      # Delete rules specified by user
      $list_rules.each do |item|
         rule_exist=false
         (0..$result.length-1).each do |i|
	     if item == $result[i][:id]
	        rule_exist=true
        	begin
		    q = "DELETE FROM admission_rules WHERE id = " + $result[i][:id]
            	    $dbh.execute(q)
	       	    puts "Admission rule " + $result[i][:id] + " deleted"
            	    rescue DBI::DatabaseError => e
                	puts $msg[2] 
                	puts "Error code: #{e.err}"
                	puts "Error message: #{e.errstr}"
	        	exit(6) 
        	end
	     end
	 end
         if !rule_exist
	    puts "Error : the rule #{item} does not exist"
	 end
      end      
   else
      puts $msg[6]
      exit(7)
   end

#   if $list_rules.length > 0
#      # Display rules specified by user
#      $list_rules.each do |item|
#         rule_exist=false
#         (0..$result.length-1).each do |i|
#	     if item == $result[i][:id]
#	        rule_exist=true
#		rule_display i
#	     end
#	 end
#         if !rule_exist
#	    puts "Error : the rule #{item} does not exist"
#	 end
#      end      
#   else
#      # Display all rules
#      (0..$result.length-1).each do |i|
#          rule_display i
#      end
#   end
# ZZZZ


end	# if $options[:delete]



# Export admission rules
if $options[:export]

   # rules given by user
   rule_list_from_command_line

   # select rules from database
   rule_select


   if $options[:file]   								# export one admission rule into a file specified by user 
      if $list_rules.length > 0
	 if $list_rules[0].to_i == 0
	    puts $msg[5]
	    exit(7) 
	 end
	 
         rule_exist=false
         (0..$result.length-1).each do |i|
	     if $list_rules[0] == $result[i][:id]
	        rule_exist=true
 		# Create file
		file_name = "" 
		(0..ARGV.length-1).each do |j|
		   if ARGV[j] == "-f"
		      file_name = ARGV[j+1] if j < ARGV.length-1
		   end
		end
		f = File.new(file_name, "w")
		f.print $result[i][:rule]
		f.close
		puts "Export admission rule " + $result[i][:id] + " into file " + file_name
	     end
	 end
         if !rule_exist
	    puts "Error : the rule #{$list_rules[0]} does not exist"
	 end



      else
	 puts $msg[6]
	 exit(7)
      end
   elsif test_files_exists								# export one or several admission rules into default file name
      if $list_rules.length > 0
          # Export rules specified by user
          $list_rules.each do |item|
            rule_exist=false
            (0..$result.length-1).each do |i|
	        if item == $result[i][:id]
	           rule_exist=true
		   rule_export i
	        end
	    end
            if !rule_exist
	       puts "Error : the rule #{item} does not exist"
	    end
          end
      else
          # Export all rules
          (0..$result.length-1).each do |i|
              rule_export i
          end
      end
   else
      puts "Nothing done"
   end		# if test_files_exists

end 	# if $options[:export]



# Disconnect from database
$dbh.disconnect if $dbh



