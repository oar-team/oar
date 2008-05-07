#!/usr/bin/ruby  
# $Id: oaradmin_modules.rb 1 2008-05-06 16:00:00 ddepoisi $
# Modules, classes and other definitions for oaradmin utility
#
# requirements:
# ruby1.8 (or greater)
# 
# To activate the verbose mode, add -w at the end of the first line. Ex : #!/usr/bin/ruby -w
#


###########################
# DEFINITIONS FOR RESOURCES
###########################

module Resources

# Decompose the command given by user and store values in $cmd_user[]
def Resources.decompose_argv

    (0..ARGV.length-2).step(2) do |i|
        if ARGV[i] == "-a"
           ARGV[i+1].split('/').each do |item|
               if item.length > 0
		  Resources.decompose_param(item)
	       end
           end
        end

        if ARGV[i] == "-p" || ARGV[i] == "-d"
           property_name = property_fixed_value = property_fixed_value2 = property_nb = ""
	   if ARGV[i+1] =~ /=/
              property_name = $`
	      property_nb = $'
	      $cmd_user.push({:property_name => property_name, :property_fixed_value => property_fixed_value, 
	                      :property_fixed_value2 => property_fixed_value2, :property_ndx => 0, :property_nb => property_nb})
           end
        end


        if ARGV[i] == "-s"
	   Resources.decompose_param(ARGV[i+1])
        end

    end	    # (0..ARGV.length-2).step(2) do |i|

    p $cmd_user if $VERBOSE

end 	# decompose_argv


# Decompose one parameter and store values in $cmd_user[]
# property_name : the name of one property. Ex : /switch=sw{3} => property_name = switch
# property_fixed_value : the fixed part of the property value. Ex : /switch=sw{3} => property_fixed_value = sw
# property_fixed_value2 : the second part of the property value. Ex : /nodes=host{12}.domain => property_fixed_value2 = .domain
# property_nb : the number of elements in the hierarchy. Ex : /switch=sw{3} => property_nb = 3
# property_ndx : current index for increments
# Ex : -a /switch=sw{3} => $cmd_user[0] = {:property_name => "switch", :property_fixed_value="sw", property_fixed_value2="", :property_nb=3}
#      -a /nodes=host{12}.domain => $cmd_user[0] = {:property_name => "nodes", :property_fixed_value="host", :property_fixed_value2=".domain", :property_nb=12}
#      -a /nodes=host-[1-12,18],host_b 
#       => $cmd_user[0] = {:property_name => "nodes", :property_fixed_value="", :property_fixed_value2="" ,:property_nb="host-[1-12,18].domain,host_b.domain"}
#      -p infiniband=NO => $cmd_user[n] = {:property_name => "infiniband", :property_fixed_value="", :property_fixed_value2="", :property_nb="NO"}
#      -a /nodes=host{12+40offset} => $cmd_user[0] = {:property_name => "nodes"  .../...  :offset=>40}  to create host41, host42, host43 .../... host52
#      -a /nodes=host{%3d12} => $cmd_user[0] = {:property_name => "nodes" .../... :format_num => "%03d"} to create host001, host002...
def Resources.decompose_param(str)

    property_name = property_fixed_value = property_fixed_value2 = property_nb = format_num = ""
    offset=0
    if str =~ /=/
       property_name = $`
       property_fixed_value = val_tmp = $'

       if val_tmp =~ Regexp.new('\{(.*)\}')
	  # we have a form /param={5}
	  property_fixed_value = $`
	  property_fixed_value2 = $'
	  property_nb = $&[1..($&.length-2)]

	  if property_nb =~ /(\+|-)\d*offset/		# offset : +50offset -1offset
	     offset = $&.to_i
	     property_nb = $`
	  end

	  if property_nb =~ /%\d*d/			# numeric format
	     format_num = $&			
 	     format_num = format_num[0..0] + "0" + format_num[1..format_num.length]
	     property_nb = $'				
	  end						

	  property_nb = property_nb.to_i

       else
	  # we have a form /param=host1,host[1-5,18]
	  property_fixed_value=""
	  property_nb = val_tmp
       end

       $cmd_user.push({:property_name => property_name, :property_fixed_value => property_fixed_value, 
                       :property_fixed_value2 => property_fixed_value2, :property_ndx => 0, :property_nb => property_nb,
		       :offset => offset, :format_num => format_num }) if $options[:add]



       # The select clause is always the first element
       $cmd_user = $cmd_user.insert(0, {:property_name => property_name, :property_fixed_value => property_fixed_value, 
	                                :property_fixed_value2 => property_fixed_value2, :property_ndx => 0, :property_nb => property_nb,
					:offset => offset, :format_num => format_num }) if $options[:select]

    end

end


# Decompose an expression of type host_a,host-[1-12,18,24-30],host_b,host_c in a table where each element is a value
# Return a table with for example : ["host_a","host-1","host-2","host-3"..."host-18","host-24",..."host_b","host_c"]
def Resources.decompose_list_values(str)

    t = []

    # numeric format
    format_num = ""
    if str =~ /%\d*d/	
       format_num = $&			
       format_num = format_num[0..0] + "0" + format_num[1..format_num.length]
       str = $`.to_s + $'.to_s				
    end						

    j = 0
    str1 = ""
    while j <= str.length-1
          c = str[j..j]
	  case 
	      when c == ","
		   if str1.length > 0 then
			t.push(str1)
			str1 = ""
		   end
		   j+=1
	      when c == "["
		   k = str[j..str.length-1] =~ /\]/
		   str3=$'
		   if str3 =~ /,/
		      str3=$`
		   end
		   str2 = str[j+1,k-1]
		   str2.split(',').each do |item|
                        if item =~ /-/
			   val_inf = $`.to_i
			   val_sup = $'.to_i
			   (val_inf..val_sup).each do |val_tmp|
			        v = val_tmp 
	      			v = sprintf("#{format_num}", v) if format_num.length > 0 
			        t.push(str1 + v.to_s + str3)
			   end
		        else
			   v = item.to_i
	        	   v = sprintf("#{format_num}", v) if format_num.length > 0 
			   t.push(str1 + v.to_s + str3)
			end
		   end
		   j+=k+1+str3.length
		   str1=""
	      else
		   str1 += c
		   j+=1
	  end
    end
    t.push(str1) if str1 != ""

    return t

end 	# Resources.decompose_list_values


# Explore $cmd_user[] table and create oar commands - recursiv algorithm
def Resources.tree n, str
    # n : the current level 
    # str : string contains the oar command to execute
    
    if n <= $cmd_user.length 
       
       # Create oarnodesetting command with correct syntax
       if $cmd_user[n-1][:property_name] == "nodes"
          str += "-h " + $cmd_user[n-1][:property_fixed_value]
       else
          str += "-p " + $cmd_user[n-1][:property_name] + "=" + $cmd_user[n-1][:property_fixed_value]
       end
       str2 = str

       if $cmd_user[n-1][:property_nb].is_a?(Fixnum)
          # We have a form /param={3}
          for i in (1..$cmd_user[n-1][:property_nb].to_i)
              $cmd_user[n-1][:property_ndx] += 1
   	      v = ($cmd_user[n-1][:property_ndx] + $cmd_user[n-1][:offset]) 
	      v = sprintf("#{$cmd_user[n-1][:format_num]}", v) if $cmd_user[n-1][:format_num].length > 0 
   	      str = str2 + v.to_s + $cmd_user[n-1][:property_fixed_value2] + " "
	      tree n+1, str
          end
       else
          # We have a form /param=host_a,host_b, host[10-20,30,35-50,70],host_c,host[80-120]
	  list_val = Resources.decompose_list_values($cmd_user[n-1][:property_nb])

	  list_val.each do |item|
	      str = str2 + item + " "
	      tree n+1, str
	  end

       end 	# if $cmd_user[n-1][:property_nb].is_a?(Fixnum)

    else

       # End of levels - execution
       execute_command(str)

       str = $oar_cmd 

    end

end	# end tree


# Execute oar command
def Resources.execute_command(str)

    puts str 

    if $options[:commit]
       r1 = `#{str}`
       r2 = $?.exitstatus

       if r2 > 0
          puts "[ERROR]" + " command : " + str
          puts r1
       end
    end

end

end	# module Resources




#################################
# DEFINITIONS FOR ADMISSION RULES
#################################

module Admission_rules

# Retrieve list of rules given by user in the command line
def Admission_rules.rule_list_from_command_line

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
def Admission_rules.load_rule_from_file

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

end 	# module Admission_rules



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



