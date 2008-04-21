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
#   The default text editor to edit an admission rule is vi
#   The value of $EDITOR is used if $EDITOR is defined
#   Recommended format for admission rules
#	First line : title or object of the admission rule (first character is #)
#       Following lines beginning with # : description of the admission rule or main algorithm 
#    	Rest of lines : rest of the admission rule
#
#   1 - list admission rules
#       ./oaradmrules.rb -l         => display only the title or object for admission rules
#       ./oaradmrules.rb -l -v      => display also description lines for all admission rules
#       ./oaradmrules.rb -l -vv     => display all content for all admission rules
#       ./oaradmrules.rb -l 3 5     => display title for admission rules nb 3 and 5
#       ./oaradmrules.rb -lvv 3 5   => display all content for admission rules nb 3 and 5
#   
#   2 - add admission rules
#       ./oaradmrules.rb -a  			=> add admission rule using a text editor 
#       ./oaradmrules.rb -a no_rule 		=> add admission rule at the no_rule position using a text editor 
#       ./oaradmrules.rb -a -f file		=> add admission rule from file 
#       ./oaradmrules.rb -a no_rule -f file	=> insert admission rule at the no_rule position from file 
#						   the numbers above or equal to no_rule are increased by 1 
#   3 - update admission rule
#       ./oaradmrules.rb -u no_rule 		=> update the admission rule specified using a text editor 
#       ./oaradmrules.rb -u no_rule -f file	=> update the admission rule specified by no_rule from file 
#
#   4 - delete admission rules
#       ./oaradmrules.rb -d no_rule [no_rule]	=> delete the admission rules specified by user 
#       ./oaradmrules.rb -d 10 12 		=> delete admission rules 10 and 12 from database 
#
#   5 - export admission rules from database into text files in current directory
#       ./oaradmrules.rb -e       	=> export all admission rules from database and create one file per admission_rule with the name admission_rule_<no_rule> 
#       ./oaradmrules.rb -e 3 5   	=> export admission rules nb 3 and 5. Files admission_rule_3 and admission_rule_5 created
#       ./oaradmrules.rb -e 3 -f file   => export admission rules nb 5 into file
#       
#   6 - comment or uncomment an admission rule 
#       ./oaradmrules.rb -c 10      	 	=> comment all the lines of the admission rule 10 
#       ./oaradmrules.rb --no-comment 10       	=> comment all the lines of the admission rule 10 


require 'optparse'
require 'dbi'

$msg = []
$msg[0] = "Incoherence in specified options"
$msg[1] = "Configuration file not found"
$msg[2] = "Error access to the database"
$msg[3] = "Error : file not found or unreadable"
$msg[4] = "Error : bad admission rule number"
$msg[5] = "Error : no admission rule number given"


$config = {} 		# Contains parameters of the configuration file
$script = ""


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
$options[:list] = $options[:add] = $options[:file] = $options[:update] = $options[:export] = $options[:delete] = false
$options[:comment] = nil

opts = OptionParser.new do |opts|
    opts.banner = "Usage: oaradmrules [-l|-ll|-lll] [-a [no_rule] [-f file]] [-u no_rule [-f file]] [-d no_rule [no_rule]]\n                   [-e [no_rule] [-f file]] [-c|--[no-]comment no_rule]"

    # list admission rules
    opts.on("-l","--list","List admission rules") do 
       $options[:list] = true 
    end

    # add admission rules
    opts.on("-a","--add","Add an admission rule") do 
       $options[:add] = true 
    end

    # file name 
    opts.on("-f","--file","File which contains script for admission rule") do 
       $options[:file] = true 
    end

    # update admission rules
    opts.on("-u","--update","Update an admission rule") do 
       $options[:update] = true 
    end

    # delete admission rules
    opts.on("-d","--delete","Delete admission rules") do 
       $options[:delete] = true 
    end

    # export admission rules 
    opts.on("-e","--export","Export admission rules") do
       $options[:export] = true
    end

    # comment/uncomment an admission rule an admission rule 
    opts.on("-c","--[no-]comment","Comment or uncomment an admission rule") do |comment|
       $options[:comment] = comment
    end

    # help
    opts.on_tail("-h", "--help", "Show this message") do
       puts opts
       exit
    end


end



# Retrieve list of rules given by user in the command line
def rule_list_from_command_line

   r = []
   i = 0
   while i < ARGV.length 
         if ARGV[i] == "-f"
            i += 1
         else
            r.push(ARGV[i]) if !(ARGV[i] =~ /[^0-9]+/)
         end
         i += 1
   end
   return r

end	# rule_list_from_command_line



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
         exit(10)
      else
     	 File.open(file_name) do |file|
	      while line = file.gets
	            $script << line
	      end
	 end
      end
   end 	# if $options[:file]

end



# Object Rules represents a set of admission rules. This object can contain one or more rules
# Methods :
#    - display         : display one or more rules
#    - add             : add one rule
#    - update          : update one rule
#    - delete          : delete one or more rules
#    - export_to_file  : export one or more rules into files
#
# Parameters for initialization :
#    @bdd  : object for database access DBI::DatabaseHandle
class Rules

      def initialize(bdd)
	  @bdd = bdd
	  @rules_set = []
      end

      # Display rules
      # Parameters : 
      #   list_rules : list of rules given by user
      #   display_level : nb level for more details
      # if no numbers rules specified => display all rules
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def display(list_rules, display_level)
	  status = 0

	  # Load rules from database
	  select_rules(list_rules)
	  
	  # Display admission rules
	  if list_rules.length > 0
      	     # Display rules specified by user
      	     list_rules.each do |item|
         	  rule_exist=false
         	  (0..@rules_set.length-1).each do |i|
	     	      if item == @rules_set[i][:id]
	        	 rule_exist=true
			 display_rule(i, display_level)
	     	      end
	 	  end
         	  if !rule_exist
	    	     puts "Error : the rule #{item} does not exist"
		     status = 1
	 	  end
      	     end      
   	  else
      	     # Display all rules
      	     (0..@rules_set.length-1).each do |i|
          	 display_rule(i, display_level)
      	     end
   	  end
	  status
      end	# def display


      # Add one rule
      # if no number rule specified => add at the end of table
      # if number specified => insert admission rule at the no_rule position
      #    the numbers above or equal to no_rule are increased by 1
      # Parameters : 
      #    no_rule : the number rule to add
      #    script  : the content of the admission rule to add
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def add(no_rule, script)
	  status = 0
	  msg = []
	  msg[0] = "Admission rule added"
	  if no_rule
	     # no rule already exist in database ?
	     q = "SELECT * FROM admission_rules WHERE id = " + no_rule.to_s
	     rows = @bdd.select_one(q) 
	     if rows
	        # add +1 to the id rules
	        q = "SELECT * FROM admission_rules WHERE id >= " + no_rule.to_s + " ORDER BY id DESC"
  	        rows = @bdd.execute(q)
	        rows.each do |r|
		     q = "UPDATE admission_rules SET id = " + (r["id"] + 1).to_s + " WHERE id = " + r["id"].to_s
		     status = bdd_do(q)
	        end
	        rows.finish
	     end
	
	     # Add rule in database
             q = "INSERT INTO admission_rules (id, rule) VALUES(?, ?)"
	     status = bdd_do(q, no_rule, script)
	     puts msg[0] if status == 0

	  else
	     # add admission rule at the end of table
             q = "INSERT INTO admission_rules (rule) VALUES(?)"
	     status = bdd_do(q, script)
	     puts msg[0] if status == 0
	  end
	  status
      end	# def add


      # Update one rule
      # Parameters : 
      #    no_rule : the number rule to add
      #    script  : the content of the admission rule to add
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def update(no_rule, script)
	  status = 0
	  msg = []
	  msg[0] = "Admission rule updated"
          # no rule already exist in database ?
          q = "SELECT * FROM admission_rules WHERE id = " + no_rule.to_s
          rows = @bdd.select_one(q) 
          if rows
	     q = "UPDATE admission_rules SET rule = ? WHERE id = " + no_rule.to_s
	     status = bdd_do(q, script)
	     puts msg[0] if status == 0
          else
	      puts "Error : the rule " + no_rule.to_s + " does not exist"
	      status = 1
          end
	  status
      end	# def update 

      
      # Delete one or several admission rules specified by user
      # Parameters : 
      #   list_rules : list of rules given by user
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def delete(list_rules)
	  status_1 = status_2 = 0
	  select_rules(list_rules)
          list_rules.each do |item|
             rule_exist=false
             (0..@rules_set.length-1).each do |i|
	         if item == @rules_set[i][:id]
	            rule_exist=true
		    q = "DELETE FROM admission_rules WHERE id = " + @rules_set[i][:id]
	            status_2 = bdd_do(q)
	       	    puts "Admission rule " + @rules_set[i][:id] + " deleted" if status_2 == 0
	         end
	     end
             if !rule_exist
	        puts "Error : the rule #{item} does not exist"
		status_1 = 1
	     end
          end
      	  (status_1 != 0 || status_2 != 0) ? 1 : 0 
      end 	# def delete

      
      # Export one or more admission rules into files 
      # Parameters : 
      #   list_rules : list of rules given by user to export into files
      #              : export_file_name,
      #		     : export_file_name_with_no_rule
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def export_to_file(list_rules, export_file_name, export_file_name_with_no_rule)
	  status = 0 
	  select_rules(list_rules)
	  if files_overwrite(list_rules, export_file_name, export_file_name_with_no_rule) 
             if list_rules.length > 0
                # Export rules specified by user
                list_rules.each do |item|
                   rule_exist=false
                   (0..@rules_set.length-1).each do |i|
	               if item == @rules_set[i][:id]
	                  rule_exist=true
		          export_rule(i, export_file_name, export_file_name_with_no_rule)
	               end
	           end
                   if !rule_exist
	              puts "Error : the rule #{item} does not exist"
		      status = 1
	           end
                 end
             else
                 # Export all rules
                 (0..@rules_set.length-1).each do |i|
                     export_rule(i, export_file_name, export_file_name_with_no_rule)
                 end
             end
	  end
	  status
      end 	# def export_to_file


      # Edit an admission rule
      # Parameters : 
      #    no_rule            : the number rule to edit - nil if new admission rule
      #    no_rule_must_exist : test if the no_rule must be exist or not : true/false
      #    file_name          : temporary file name to store the admission rule
      #    editor             : command to be used for the text editor 
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      #    user_choice : 0 : continue and commit changes in oar database - 1 : abort changes, nothing is done in oar database
      #    script : contains the Perl script of the admission rule 
      def edit(no_rule, no_rule_must_exist, file_name, editor)
	  status = 0
	  user_choice = 1
	  script = ""

	  if no_rule && no_rule_must_exist
             q = "SELECT * FROM admission_rules WHERE id = " + no_rule.to_s
             rows = @bdd.select_one(q) 
             if rows
	 	script = rows[:rule]	
             else
	         puts "Error : the rule " + no_rule.to_s + " does not exist"
	         status = 1
             end
	  end
	  if status == 0
	     begin
             	  f = File.new(file_name, "w")
             	  if script.length > 0
             	     f.print script 
             	  else
		     f.print "# Title :  \n"
		     f.print "# Description :  \n\n" 
		  end
             	  f.close
		  rescue Exception => e
			 puts "Error while creating temporary file to edit admission rule" 
			 puts e.message
			 status=1
	     end
	     if status==0
		user_choice = ""
		status1 = true
		str = editor + " " + file_name
		begin
		    status1 = system(str)
		    if status1
	   	       begin
			   puts "(e)dit admission rule again,"
			   puts "(c)ommit changes in oar database and quit,"
			   print "(Q)uit and abort without changes in oar database :  "
			   user_choice = $stdin.gets.chomp
	   	       end while(user_choice != "e" && user_choice != "c" && user_choice != "Q")
		    else
	    	       puts "Error during the launch of the text editor with the command : " + str
		    end
		end while(user_choice != "c" && user_choice != "Q" && status1)
		status = 1 if !status1
		if status == 0 && user_choice == "c"
		   user_choice = 0
		   script = ""
		   begin 
     	 	       File.open(file_name) do |file|
	      		    while line = file.gets
	            	          script << line
	      		    end
	 	       end
		       rescue Exception => e
		   end
		end 
	     end	
	  end	  

	  begin
               File.delete(file_name)
	       rescue Exception => e
	  end

	  return status, user_choice, script

      end	# def edit


      # Comment/uncomment an admission rule
      # Parameters : 
      #    no_rule : the number rule to comment or uncomment
      #    action  : true : comment - false : uncomment
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def comment(no_rule, action)
	  status=0
          q = "SELECT * FROM admission_rules WHERE id = " + no_rule.to_s
          rows = @bdd.select_one(q) 
          if rows
	     # The no_rule is already commented or not ? 
	     str=""
	     already_commented=true
	     rows["rule"].each do |line|
	         already_commented=false if line[0..0]!="#" && line.strip.length > 0
	     end
	     if action
		if !already_commented
	           rows["rule"].each do |line|
		       str = str + "#" + line
	           end
	           status = self.update(no_rule, str)
		else
		   puts "The rule is already commented" 
		end
	     else
		if already_commented
	           rows["rule"].each do |line|
			line.length>0 ? str = str + line[1..line.length-1] : str += line
	           end
	           status = self.update(no_rule, str)
		else
		   puts "The rule is already uncommented" 
		end	
	     end 
          else
	      puts "Error : the rule " + no_rule.to_s + " does not exist"
	      status = 1
          end
	  status
      end 	# comment



      private

      # Display one rule
      def display_rule(ndx, display_level)
    	  puts "------"
    	  puts "Rule : " + @rules_set[ndx][:id]								# rule number

	  no_char = 65
	  description_end = false
	  @rules_set[ndx][:rule].each_with_index do |line,line_index|	
	 	if line_index == 0 									# title or object of the admission rule 
		   puts line[0..no_char]
		end
		if (display_level==1 || display_level==2) && line_index > 0 && !description_end		# description of the admission rule
		   if line[0..0]=="#"
		      puts line[0..no_char]
		   else
		      description_end = !description_end 
		   end
		end
		if display_level==2 && line_index > 0 && description_end				# rest of the admission rule
		   puts line[0..no_char] 
		end
	  end
      end	# def display_rule(ndx)


      # Select one or more rules 
      # Store selected rules in @rules_set 
      def select_rules(list_rules)

          q = "SELECT * FROM admission_rules "
          if list_rules.length > 0
             q += "WHERE id IN ("
             list_rules.each_with_index do |item, item_index|
      	        q += item
	        q += "," if item_index < list_rules.length-1
             end
             q += ") "
          else
             q += "ORDER BY id"
          end
          rows = @bdd.execute(q)
          rows.each do |r|
   	       @rules_set.push({:id => r["id"].to_s, :rule => r["rule"]})
          end
          rows.finish

      end	# def select_rules


      # Test if files for export admission rules already exists
      # Ask question to user, if needed, to overwrite files or not 
      # Return : 
      #    true  => files can be overwrite
      #    false => do not overwrite
      def files_overwrite(list_rules, export_file_name, export_file_name_with_no_rule)

   	  files_already_exists = []
   	  if list_rules.length > 0
       	     # Rules specified by user
       	     list_rules.each do |item|
         	  (0..@rules_set.length-1).each do |i|
	     	      if item == @rules_set[i][:id]
			 if export_file_name_with_no_rule
                            files_already_exists.push(export_file_name + @rules_set[i][:id]) if File.exist?(export_file_name + @rules_set[i][:id])
			 else
                            files_already_exists.push(export_file_name) if File.exist?(export_file_name)
			 end
	     	      end
	 	  end
       	     end
   	  else
       	     # All rules
       	     (0..@rules_set.length-1).each do |i|
           	 files_already_exists.push(export_file_name + @rules_set[i][:id]) if File.exist?(export_file_name + @rules_set[i][:id])
       	     end
   	  end

   	  if files_already_exists.length > 0 
	     c = ""
      	     files_already_exists.each { |f| 
                 c += f
	         c += " "
	     }
             puts "Warning ! Some files already exists : " + c 
             print "Overwrite [N/y] ? "
             r = ""
             begin
         	 r = $stdin.gets.chomp
             end while ( r != "" && r != "N" && r != "y" )
	     r == "y" ? true : false
	  else
      	     return true
          end 

      end 	# def files_overwrite


      # Export one rule into a file
      def export_rule(n, export_file_name, export_file_name_with_no_rule)

	  f_name = export_file_name 
	  f_name += @rules_set[n][:id] if export_file_name_with_no_rule

          puts "Export admission rule " + @rules_set[n][:id] + " into file " + f_name
          f = File.new(f_name, "w")
          f.print @rules_set[n][:rule]
          f.close

      end	# def export_rule


      # Access to the database and catch errors
      # Parameters : 
      #   q : sql order
      #   *params : parameters for sql order
      # Return : 
      #    status => code error if an error occurs
      def bdd_do(q, *params)
	  status = 0
	  begin
               @bdd.do(q, *params)
               rescue DBI::DatabaseError => e
		   status = e.err
		   puts "Error access to the database"
               	   puts "Error code: #{e.err}"
               	   puts "Error message: #{e.errstr}"
	  end
          status  
      end


end	# class Rules





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
if !( ( $options[:list] && !$options[:add] && !$options[:file] && !$options[:update] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? ) ||   # -l 
      (!$options[:list] &&  $options[:add] && !$options[:file] && !$options[:update] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? ) ||   # -a 
      (!$options[:list] &&  $options[:add] &&  $options[:file] && !$options[:update] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? ) ||   # -a -f
      (!$options[:list] && !$options[:add] && !$options[:file] &&  $options[:update] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? ) ||   # -u 
      (!$options[:list] && !$options[:add] &&  $options[:file] &&  $options[:update] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? ) ||   # -u -f
      (!$options[:list] && !$options[:add] && !$options[:file] && !$options[:update] &&  $options[:delete] && !$options[:export] &&  $options[:comment].nil? ) ||   # -d 
      (!$options[:list] && !$options[:add] && !$options[:file] && !$options[:update] && !$options[:delete] &&  $options[:export] &&  $options[:comment].nil? ) ||   # -e  
      (!$options[:list] && !$options[:add] &&  $options[:file] && !$options[:update] && !$options[:delete] &&  $options[:export] &&  $options[:comment].nil? ) ||   # -e -f
      (!$options[:list] && !$options[:add] && !$options[:file] && !$options[:update] && !$options[:delete] && !$options[:export] && !$options[:comment].nil? )  )   # [no]comment

      puts $msg[0]
      exit(2)
end


# Load configuration file
if load_configuration > 0 
	puts $msg[1]
	exit(3)
end

filename_base = "admission_rule_"

# Text editor to edit an admission rule 
editor = "vi"
editor = ENV['EDITOR'] if ENV['EDITOR']

# Directory to edit an admission rule
directory="/tmp/"
if $config['OAR_RUNTIME_DIRECTORY']
   directory = $config['OAR_RUNTIME_DIRECTORY']
   directory += "/" if directory[directory.length-1..directory.length-1]!="/" 
end

# Connect to the database
begin
     db_type = $config['DB_TYPE']
     db_type = "Mysql" if db_type == "mysql"
     dbh = DBI.connect("dbi:#{db_type}:#{$config['DB_BASE_NAME']}:#{$config['DB_HOSTNAME']}",
				 "#{$config['DB_BASE_LOGIN']}","#{$config['DB_BASE_PASSWD']}")

     rescue DBI::DatabaseError => e
         puts $msg[2] 
         puts "Error code: #{e.err}"
         puts "Error message: #{e.errstr}"
	 exit(4)
end

rules = Rules.new(dbh) 

case
    when $options[:list]
	 # List admission rules
	 
   	 # rules given by user
   	 list_rules = rule_list_from_command_line
	 
         level = level_max = 0
   	 (0..ARGV.length-1).each do |i|
	     level = 1 if ARGV[i]=~/-ll/ 
	     level = 2 if ARGV[i]=~/-lll/ 
	     level_max = level if level > level_max
	 end
	 level = level_max

   	 status = rules.display(list_rules, level)
	 exit(5) if status != 0


    when $options[:add]
	 # Add admission rule

	 no_rule = nil 
   	 # retrieve no rule specified by user
   	 (0..ARGV.length-1).each do |i|
       	     if ARGV[i] == "-a" 
          	if i < ARGV.length-1
	     	   no_rule = $&.to_s.to_i if ARGV[i+1] =~ /\d+/ 
 	  	end
       	     end
   	 end

	 if no_rule && no_rule == 0 
	    puts $msg[4]
	    exit(6)
	 end

	 if $options[:file]
   	    # add admission rule from a file 
   	    load_rule_from_file
   	    status = rules.add(no_rule, $script)
	    exit(6) if status != 0
	 else
   	    # add admission rule using a text editor 
	    file_name = directory + "OAR_tmp_" + filename_base
	    file_name += no_rule.to_s if no_rule
	    status, user_choice, $script = rules.edit(no_rule, false, file_name, editor)
	    if status==0 && user_choice==0
   	       status = rules.add(no_rule, $script)
	       exit(6) if status != 0
	    end
	 end


    when $options[:update]
	 # Update admission rule

   	 no_rule = nil 
   	 # retrieve no rule specified by user
   	 (0..ARGV.length-1).each do |i|
       	     if ARGV[i] == "-u" 
          	if i < ARGV.length-1
	     	   no_rule = $&.to_s.to_i if ARGV[i+1] =~ /\d+/ 
 	  	end
       	     end
   	 end

	 if no_rule 
	    if no_rule == 0 
	       puts $msg[4]
	       exit(7)
	    end
	    if $options[:file] 
   	       # update admission rule from a file 
	       load_rule_from_file
   	       status = rules.update(no_rule, $script)
	       exit(7) if status != 0
	    else
	       # update admission rule using a text editor
	       file_name = directory + "OAR_tmp_" + filename_base
	       file_name += no_rule.to_s if no_rule
	       status, user_choice, $script = rules.edit(no_rule, true, file_name, editor)
	       if status==0 && user_choice==0
   	          status = rules.update(no_rule, $script)
	          exit(7) if status != 0
	       end
	    end
	 else
      	    puts $msg[5]
      	    exit(7)
	 end


    when $options[:delete]
	 # Delete admission rules

   	 # rules given by user
   	 list_rules = rule_list_from_command_line

   	 if list_rules.length > 0
      	    status = rules.delete(list_rules)
	    exit(8) if status != 0
   	 else
      	    puts $msg[5]
      	    exit(8)
   	 end


    when $options[:export]
	 # Export admission rules

   	 # rules given by user
   	 list_rules = rule_list_from_command_line

   	 if list_rules.length >= 2 && $options[:file]
            puts $msg[0]
            exit(9)
   	 end

   	 if $options[:file]
      	    user_file_name = "" 
      	    (0..ARGV.length-1).each do |i|
          	if ARGV[i] == "-f"
             	   user_file_name = ARGV[i+1] if i < ARGV.length-1
          	end
      	    end
      	    status = rules.export_to_file(list_rules, user_file_name, false)
   	 else
      	    status = rules.export_to_file(list_rules, filename_base, true)
   	 end
	 exit(9) if status != 0


    when !$options[:comment].nil?
	 # Comment or uncomment an admission rules
   	 list_rules = rule_list_from_command_line
   	 if list_rules.length == 0 || list_rules.length > 1
            puts $msg[0]
            exit(10)
   	 end

      	 status = rules.comment(list_rules, $options[:comment])
	 exit(10) if status != 0

end




# Disconnect from database
dbh.disconnect if dbh





