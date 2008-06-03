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


   # Decompose parameters property=value and store values in $cmd_user[]
   # property_name : the name of one property. Ex : /switch=sw{3} => property_name = switch
   # property_fixed_value : the fixed part of the property value. Ex : /switch=sw{3} => property_fixed_value = sw
   # property_fixed_value2 : the second part of the property value. Ex : /nodes=host{12}.domain => property_fixed_value2 = .domain
   # property_nb : the number of elements in the hierarchy. Ex : /switch=sw{3} => property_nb = 3
   # property_ndx : current index for increments
   # index : position to store values in $cmd_user[]
   # Ex : -a /switch=sw{3} => $cmd_user[0] = {:property_name => "switch", :property_fixed_value="sw", property_fixed_value2="", :property_nb=3}
   #      -a /nodes=host{12}.domain => $cmd_user[0] = {:property_name => "nodes", :property_fixed_value="host", :property_fixed_value2=".domain", :property_nb=12}
   #      -a /nodes=host-[1-12,18],host_b 
   #       => $cmd_user[0] = {:property_name => "nodes", :property_fixed_value="", :property_fixed_value2="" ,:property_nb="host-[1-12,18].domain,host_b.domain"}
   #      -p infiniband=NO => $cmd_user[n] = {:property_name => "infiniband", :property_fixed_value="", :property_fixed_value2="", :property_nb="NO"}
   #      -a /nodes=host{12+40offset} => $cmd_user[0] = {:property_name => "nodes"  .../...  :offset=>40}  to create host41, host42, host43 .../... host52
   #      -a /nodes=host{%3d12} => $cmd_user[0] = {:property_name => "nodes" .../... :format_num => "%03d"} to create host001, host002...
   def Resources.decompose_argv

       (0..ARGV.length-2).step(2) do |i|

           if ARGV[i] == "-a"
              ARGV[i+1].split('/').each do |item|
                  if item != ""
       		     property_name, property_fixed_value, property_fixed_value2, property_nb, format_num, offset = Resources.decompose_param(ARGV[i], item)
             	     $cmd_user.push({:property_name => property_name, :property_fixed_value => property_fixed_value, 
                          	     :property_fixed_value2 => property_fixed_value2, :property_ndx => 0, :property_nb => property_nb,
	  	          	     :offset => offset, :format_num => format_num }) 

	          end
              end
           end

           if ARGV[i] == "-s"
       	      property_name, property_fixed_value, property_fixed_value2, property_nb, format_num, offset = Resources.decompose_param(ARGV[i], ARGV[i+1])
              $cmd_user = $cmd_user.insert(0, {:property_name => property_name, :property_fixed_value => property_fixed_value, 
	                                       :property_fixed_value2 => property_fixed_value2, :property_ndx => 0, :property_nb => property_nb,
	  				       :offset => offset, :format_num => format_num }) 
           end

           if ARGV[i] == "-p"
       	      property_name, property_fixed_value, property_fixed_value2, property_nb, format_num, offset = Resources.decompose_param(ARGV[i], ARGV[i+1])
              $cmd_user.push({:property_name => property_name, :property_fixed_value => property_fixed_value, 
                       	      :property_fixed_value2 => property_fixed_value2, :property_ndx => 0, :property_nb => property_nb,
	  	       	      :offset => offset, :format_num => format_num }) 
           end

           if ARGV[i] == "-d"
              property_name = property_fixed_value = property_fixed_value2 = property_nb = ""
	      if ARGV[i+1] =~ /=/
                 property_name = $`
	         property_nb = $'
	         $cmd_user.push({:property_name => property_name, :property_fixed_value => property_fixed_value, 
	                         :property_fixed_value2 => property_fixed_value2, :property_ndx => 0, :property_nb => property_nb})
              end
           end

       end	    # (0..ARGV.length-2).step(2) do |i|

       p $cmd_user if $VERBOSE

   end 		# decompose_argv


   # Decompose parameters property=value - retrieve offset and numeric format 
   def Resources.decompose_param(form, str)

       property_name = property_fixed_value = property_fixed_value2 = property_nb = format_num = str2 = ""
       offset=0
       if str =~ /=/
          property_name = $`
          property_fixed_value = val_tmp = $'

          if val_tmp =~ /\{.*\}/
	     # case with follows forms : 
	     #    - with a number and/or numeric format and/or offset : param={5} param=part_a{12}part_b param=part_a{%2d+20offset12} 
	     #    - with % as increment operator and/or numeric format and/or offset : param={%} param=part_a{%}part_b param=part_a{%2d%+20offset} 
	     # numeric format and offset can be anywhere in {...}
	     property_fixed_value = $`
	     property_fixed_value2 = $'

	     str2 = $&[1..$&.length-2]
	     if str2 =~ /(\+|-)\d*offset/		# offset : +50offset -1offset
	        offset = $&.to_i
	        str2 = $` + $'
	     end
	     if str2 =~ /%\d*d/				# numeric format
	        format_num = $&			
 	        format_num = format_num[0..0] + "0" + format_num[1..format_num.length]
	        str2 = $` + $'
	     end						

	     property_nb = str2.to_i if form == "-a" || form == "-s"		# Only {number} form allowed with -a and -s params
	     property_nb = 1 if form == "-p"					# Only {%} form allowed with -p params

          else
	     # case with follows forms : 
	     #    - param=host1,host[1-5,18]
	     #    - param=host1,host[%2d1-5,18]
	     property_fixed_value=""
	     property_nb = val_tmp
          end

       end

       return property_name, property_fixed_value, property_fixed_value2, property_nb, format_num, offset

   end	# decompose_param


   # Decompose an expression of type host_a,host-[1-12,18,24-30],host_b,host_c in a table where each element is a value
   # Return a table with for example : ["host_a","host-1","host-2","host-3"..."host-18","host-24",..."host_b","host_c"]
   def Resources.decompose_list_values(str)

       t = []

       # numeric format
       format_num = ""
       if str =~ /%\d*d/	
          format_num = $&			
          format_num = format_num[0..0] + "0" + format_num[1..format_num.length]
          str = $` + $'				
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

   end 		# Resources.decompose_list_values


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

		 # For cpuset no
		 if $cmd_user[n-1][:property_name]=="nodes"
		    $cpuset_host_current=$cmd_user[n-1][:property_fixed_value] + v.to_s + $cmd_user[n-1][:property_fixed_value2]
		 end
		 if $cpuset_property_name != ""
		    if $cpuset_property_name == $cmd_user[n-1][:property_name] 
		       $cpuset_property_current_value = $cmd_user[n-1][:property_fixed_value] + v.to_s + $cmd_user[n-1][:property_fixed_value2]
		    end
		 end

	         tree n+1, str
             end
          else
             # We have a form /param=host_a,host_b, host[10-20,30,35-50,70],host_c,host[80-120]
	     list_val = Resources.decompose_list_values($cmd_user[n-1][:property_nb])

	     list_val.each do |item|
	         str = str2 + item + " "

		 # For cpuset no
		 if $cmd_user[n-1][:property_name]=="nodes"
		    $cpuset_host_current=item
		 end

	         tree n+1, str
	     end

          end 	# if $cmd_user[n-1][:property_nb].is_a?(Fixnum)

       else
	  # Cpuset
	  if $cpuset_host_current != $cpuset_host_previous
	     $cpuset_no=0
	     $cpuset_host_previous=$cpuset_host_current
	     $cpuset_property_previous_value = $cpuset_property_current_value
	  else
	     if $cpuset_property_name != ""
	  	if $cpuset_property_previous_value != $cpuset_property_current_value
	     	   $cpuset_no+=1
		   $cpuset_property_previous_value = $cpuset_property_current_value
	  	end
	     else
	     	$cpuset_no+=1
	     end
	  end
	  str += " -p cpuset="+$cpuset_no.to_s

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
   # Return : 
   # 	r : array contains list of admission rules
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

   # Test params on command line
   # Parameters allowed : options  -f file and numbers
   # 			  others parameters are wrong
   # Return 
   # 	false : all params are ok, true : one parameter is wrong
   def Admission_rules.test_params
       error = false
       i = 0
       while i < ARGV.length
            if ARGV[i] == "-f" 
               i += 1
            elsif ARGV[i][0..0] != "-"
                  if ARGV[i] =~ /[^0-9]+/
 	             error=true
		     break
		  end
	    end
	    i+=1
       end
       error
   end	# test_params

   # Test if the file given by user is readable or not 
   # Read the content of the file which contains admission rule
   # Return : 
   # 	status 0 : no error - 1 : an error occurs
   # 	script : content of admission rule
   def Admission_rules.load_rule_from_file
      status=0
      script = file_name = ""
      if $options[:file]
         (0..ARGV.length-1).each do |i|
	   if ARGV[i] == "-f" 
	      file_name = ARGV[i+1] if i < ARGV.length-1 
	   end
         end
         if !File.readable?(file_name) 
            $stderr.puts "Error : file "+file_name+" not found or unreadable"
            status = 1 
         else
     	    File.open(file_name) do |file|
	         while line = file.gets
	               script << line
	         end
	    end
         end
      end 	# if $options[:file]
      return status, script 
   end	# load_rule_from_file

end 	# module Admission_rules




# Object Rule represent an admission rule
# Methods : 
#    - display : display the rule
#    - add     : add the rule
#    - update  : update the rule
#    - edit    : edit the rule with a text editor
#    - delete  : delete the rule
#    - export  : export the rule
#    - comment : comment or delete comments in the rule
class Rule
      attr_accessor :no_rule,				# rule id 
		    :exist,				# rule exist y/n ?
		    :script,				# content of the admission rule - script Perl
      		    :export_file_name, 			# filename used to export	
		    :export_file_name_with_no_rule,	# filename must use number rule y/n
      		    :no_rule_must_exist, 		# the no_rule must be exist or not : true/false
      		    :file_name,          		# temporary file name to store the admission rule
      		    :editor,             		# command to be used for the text editor 
      		    :action                             # true : comment - false : delete comments
		    
      def initialize(bdd, no_rule)
	  @bdd = bdd
	  @no_rule = no_rule
	  @script=""
	  @exist=false
      	  @export_file_name="" 
	  @export_file_name_with_no_rule=false
          @no_rule_must_exist=false
      	  @file_name=""
      	  @editor=""
	  @action=false

	  if !no_rule.nil?
	     q = "SELECT * FROM admission_rules WHERE id = " + no_rule.to_s
	     rows = @bdd.select_one(q) 
	     if rows
	        @script = rows["rule"] 
	        @exist = true
	     end
	  end
      end

      # Display rule
      def display(display_level)
    	  puts "------"
    	  puts "Rule : " + @no_rule.to_s								# rule number

	  no_char = 65
	  description_end = false
	  @script.each_with_index do |line,line_index|	
	 	if line_index == 0 									# title or object of the admission rule 
		   str = line[0..no_char]
		   str += "..." if line.length > no_char+2
		   puts str
		end
		if (display_level==1 || display_level==2) && line_index > 0 && !description_end		# description of the admission rule
		   if line[0..0]=="#"
		      str = line[0..no_char]
		      str += "..." if line.length > no_char+2
		      puts str
		   else
		      description_end = !description_end 
		   end
		end
		if display_level==2 && line_index > 0 && description_end				# rest of the admission rule
		   str = line[0..no_char]
		   str += "..." if line.length > no_char+2
		   puts str
		end
	  end
      end	# def display(display_level)

      # Add rule 
      # if no number rule specified => add at the end of table
      # if number specified => insert admission rule at the no_rule position
      #    the numbers above or equal to no_rule are increased by 1 if necessary
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def add
	  status = 0
	  msg = []
	  msg[0] = "Admission rule added"
	  if @exist
	     # no rule already exist in database : add +1 to the id rules
	     q = "SELECT * FROM admission_rules WHERE id >= " + @no_rule.to_s + " ORDER BY id DESC"
  	     rows = @bdd.execute(q)
	     rows.each do |r|
	     	  q = "UPDATE admission_rules SET id = " + (r["id"] + 1).to_s + " WHERE id = " + r["id"].to_s
	     	  status = Bdd.do(@bdd, q)
	     end
	     rows.finish
	
	     # Add rule in database
             q = "INSERT INTO admission_rules (id, rule) VALUES(?, ?)"
	     status = Bdd.do(@bdd, q, @no_rule, @script)
	     puts msg[0] if status == 0
	  else
	     if !@no_rule.nil?
	        # Add rule in database
                q = "INSERT INTO admission_rules (id, rule) VALUES(?, ?)"
	        status = Bdd.do(@bdd, q, @no_rule, @script)
	        puts msg[0] if status == 0
	     else
	        # add admission rule at the end of table
                q = "INSERT INTO admission_rules (rule) VALUES(?)"
	        status = Bdd.do(@bdd, q, @script)
	        puts msg[0] if status == 0
	     end
	  end
	  status
      end	# def add

      # Update one rule 
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def update
	  status = 0
	  msg = []
	  msg[0] = "Admission rule updated"
          if @exist
	     q = "UPDATE admission_rules SET rule = ? WHERE id = " + @no_rule.to_s
	     status = Bdd.do(@bdd, q, @script)
	     puts msg[0] if status == 0
          else
	      $stderr.puts "Error : the rule " + @no_rule.to_s + " does not exist"
	      status = 1
          end
	  status
      end	# def update 

      # Delete the admission rule 
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def delete
	  status_1 = status_2 = 0
          if @exist
	     q = "DELETE FROM admission_rules WHERE id = " + @no_rule.to_s
	     status_2 = Bdd.do(@bdd, q)
	     puts "Admission rule " + @no_rule.to_s + " deleted" if status_2 == 0
	  else
	     $stderr.puts "Error : the rule " + @no_rule.to_s + " does not exist"
	     status_1 = 1
	  end
      	  (status_1 != 0 || status_2 != 0) ? 1 : 0 
      end 	# def delete

      # Export one rule into a file
      def export

	  f_name = @export_file_name 
	  f_name += @no_rule.to_s if @export_file_name_with_no_rule
          puts "Export admission rule " + @no_rule.to_s + " into file " + f_name
          f = File.new(f_name, "w")
          f.print @script
          f.close

      end	# def export

      # Edit an admission rule
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      #    user_choice : 0 : continue and commit changes in oar database - 1 : abort changes, nothing is done in oar database
      def edit
	  status = 0
	  user_choice = 1

	  if @exist==false && @no_rule_must_exist
	     $stderr.puts "Error : the rule " + @no_rule.to_s + " does not exist"
	     status = 1
	  end	  

	  if status == 0
	     begin
		  @script = "# Title :  \n# Description :  \n\n" if @script.length == 0
             	  f = File.new(file_name, "w")
             	  f.print @script 
             	  f.close
		  rescue Exception => e
			 $stderr.puts "Error while creating temporary file to edit admission rule" 
			 $stderr.puts e.message
			 status=1
	     end
	     if status==0
		user_choice = ""
		status1 = true
		str = @editor + " " + @file_name
		old_script = @script
		begin
		    status1 = system(str)
		    if status1
		       @script = ""
		       begin 
     	 	           File.open(file_name) do |file|
	      		        while line = file.gets
	            	              @script << line
	      		        end
	 	           end
		           rescue Exception => e
		       end
		       # Ask question to user only if changes are made in admission rule content
		       if @script != old_script
	   	          begin
			      puts "(e)dit admission rule again,"
			      puts "(c)ommit changes in oar database and quit,"
			      print "(Q)uit and abort without changes in oar database :  "
			      user_choice = $stdin.gets.chomp
	   	          end while(user_choice != "e" && user_choice != "c" && user_choice != "Q")
		       else
			  user_choice = "Q"
		       end
		    else
	    	       $stderr.puts "Error during the launch of the text editor with the command : " + str
		    end
		end while(user_choice != "c" && user_choice != "Q" && status1)
		status = 1 if !status1
		user_choice = 0 if status == 0 && user_choice == "c"
	     end	
	  end	  

	  begin
               File.delete(file_name)
	       rescue Exception => e
	  end

	  return status, user_choice

      end	# def edit


      # Disable a rule : commenting the code
      #                  add # at the beginning of each line
      # Enable a rule  : removing comments 
      # 	         delete # at the beginning of each line
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def comment
	  status=0
          if @exist
	     # The rule is already commented or not ? 
	     str=""
	     already_commented=true
	     @script.each do |line|
	         already_commented=false if line[0..0]!="#" && line.strip.length > 0
	     end
	     if @action
		if !already_commented
	           @script.each do |line|
		       str = str + "#" + line
	           end
		   @script = str
	           status = self.update
		else
		   puts "The rule is already disabled" 
		end
	     else
		if already_commented
	           @script.each do |line|
			line.length>0 ? str = str + line[1..line.length-1] : str += line
	           end
		   @script = str
	           status = self.update
		else
		   puts "The rule is already enabled" 
		end	
	     end 
          else
	      $stderr.puts "Error : the rule " + @no_rule.to_s + " does not exist"
	      status = 1
          end
	  status
      end 	# comment

end	# class Rule




# Object Rules_set contains several admission rules
# Methods : 
#    - display : display rules
#    - delete  : display rules
#    - export  : export rules into files
class Rules_set

      attr_accessor :export_file_name, 			# filename used to export	
		    :export_file_name_with_no_rule	# filename must use number rule y/n

      def initialize(bdd, rules_set_user)
	  @bdd = bdd
	  @rules_set_user = rules_set_user
      	  @export_file_name="" 
	  @export_file_name_with_no_rule=false
	
	  # No rules specified by user 
	  # => load all rules from database
	  if @rules_set_user.length==0
	     q = "SELECT id FROM admission_rules ORDER BY id"
  	     rows = @bdd.execute(q)
	     rows.each do |r|
		  @rules_set_user.push(r["id"])
	     end
	     rows.finish
	  end
 
	  @rules_set=[]
	  @rules_set_user.each do |r|
		@rules_set.push(Rule.new(@bdd, r))	
	  end
      end

      # Display rules
      # Parameters : 
      #   display_level : nb level for more details
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def display(display_level)
	  status = 0
	  @rules_set.each do |r|
	      if r.exist
	         r.display(display_level) 
	      else
	    	 $stderr.puts "Error : the rule " + r.no_rule.to_s + " does not exist"
		 status = 1
	      end
	  end
	  status
      end	# def display

      # Delete one or several admission rules specified by user
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def delete
	  status_1 = status_2 = 0
	  @rules_set.each do |r|
	      status_2 = r.delete
	      status_1 = 1 if status_2 != 0
	  end
      	  status_1 
      end 	# def delete

      # Export admission rules into files 
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def export
	  status = 0
	  overwrite_files = true 
	 
	  # Files already exists ? Question to user : Overwrite y/n ? 
   	  files_already_exists = []
       	  @rules_set.each do |r|
		if @export_file_name_with_no_rule
                   files_already_exists.push(@export_file_name + r.no_rule.to_s) if File.exist?(@export_file_name + r.no_rule.to_s)
		 else
                   files_already_exists.push(@export_file_name) if File.exist?(@export_file_name)
		 end
       	  end

   	  if !files_already_exists.empty? 
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
	     overwrite_files = r == "y" 
	  else
      	     overwrite_files = true
          end 

	  if overwrite_files 
	     @rules_set.each do |r|
	         if r.exist
      	  	    r.export_file_name = @export_file_name 
	  	    r.export_file_name_with_no_rule = @export_file_name_with_no_rule
	            r.export 
	         else
	    	    $stderr.puts "Error : the rule " + r.no_rule.to_s + " does not exist"
		    status = 1
	         end
	     end
	  end
	  status
      end 	# def export

end	# class Rules_set


