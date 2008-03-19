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
#       ./oaradmrules.rb -l -f    => full content for all admission rules
#       ./oaradmrules.rb -l 3 5   => display admission rules nb 3 and 5
#   
#   2 - export admission rules from database into text files in current directory
#       ./oaradmrules.rb -x       => export all admission rules from database and create one file per admission_rule with the name admission_rule_<no_rule> 
#       ./oaradmrules.rb -x 3 5   => export admission rules nb 3 and 5. Files admission_rule_3 and admission_rule_5 created
#       


require 'optparse'
require 'dbi'

$msg = []
$msg[0] = "Incoherence in specified options"
$msg[1] = "Configuration file not found"
$msg[2] = "Error access to the database"



$config = {} 		# Contains parameters of the configuration file
$list_rules = []
$result = []

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
$options[:list] = $options[:full] = $options[:export] = false
opts = OptionParser.new do |opts|
    opts.banner = "Usage: oaradmrules [-l [-f]] [-x]"

    # list admission rules
    opts.on("-l","--list","List admission rules") do 
       $options[:list] = true 
    end

    # full 
    opts.on("-f","--full","Full content display") do
       $options[:full] = true
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


    if $options[:full]								# full display
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
if !( ($options[:list]   &&  !$options[:full]  &&  !$options[:export]) || 			# -l alone
      ($options[:list]   &&   $options[:full]  &&  !$options[:export]) || 			# -l -f
      (!$options[:list]  &&  !$options[:full]  &&   $options[:export]) ) 			# -x alone 

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
         puts $msg[2] = "Error access to the database"
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



# Export admission rules
if $options[:export]

   # rules given by user
   rule_list_from_command_line

   # select rules from database
   rule_select

   if test_files_exists
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



