#!/usr/bin/ruby  
# $Id: oaradmin_modules.rb 1 2008-05-06 16:00:00 ddepoisi $
# Modules, classes and other definitions for oaradmin utility
#
# requirements:
# ruby1.8 (or greater)
# 
# To activate the verbose mode, add -w at the end of the first line. Ex : #!/usr/bin/ruby -w
#


require 'fileutils'
require 'rexml/document'
require 'time'


###########################
# DEFINITIONS FOR RESOURCES
###########################

module Resources

   # Test syntax in command line
   # Return :
   #	0 : no error
   #	1 : one parameter is wrong
   #    2 : a parameter after an option is missing
   #    3 : one error occurs in {...} expression with -a or -s option. 
   #        only a numeric value with optional numeric format and offset are allowed
   #    4 : one error occurs in {...} expression with -p option
   #        only % character with optional numeric format and offset are allowed
   #    5 : {...} expression not allowed with -d option
   def Resources.parsing
       r=0
       i=0
       while i<ARGV.length

	     # A parameter must be exist after some options
             if ARGV[i] =~ /^(\-a|\-\-add|\-p|\-\-property|\-s|\-\-select)$/ 
	        if ARGV[i+1].nil?
	     	   r=2
	     	   return r
	     	end 
	     end

	     # Test each parameter after an option
	     case
		when ARGV[i] == "-a" || ARGV[i] == "--add"
		     if !(ARGV[i+1] =~ /^\/\S+=\S+/)
		        r=1
		        return r
		     else
   		        ARGV[i+1].split('/').each do |item|
			    if item != "" 
	   		       if !(item =~ /\S+=\S+/)
		      		  r=1
		      		  return r
	   		       else
	      		  	  r = Resources.parsing_value(item.split('=')[1], "-a")
				  if r > 0
				     r = 3 
				     return r 
	      			  end 
	   		       end
			    end
   		        end
		     end
		     i+=1

		when ARGV[i] == "-p" || ARGV[i] == "--property"
		     if !(ARGV[i+1] =~ /\S+=\S+/)
		        r=1
		        return r
		     else
	      	        r = Resources.parsing_value(ARGV[i+1].split('=')[1], "-p")
		        if r > 0
		           r = 4 
		           return r 
	      	        end 
		     end 
		     i+=1

		when ARGV[i] == "-s" || ARGV[i] == "--select"
		     if !(ARGV[i+1] =~ /^\w\S*=\S+/)
		        r=1
		        return r
		     else
	      	        r = Resources.parsing_value(ARGV[i+1].split('=')[1], "-s")
		        if r > 0
		           r = 3 
		           return r 
	      	        end 
		     end 
		     i+=1

		when ARGV[i] == "-d" || ARGV[i] == "--delete"
		     if ARGV[i+1] && ARGV[i+1] != "-c" && ARGV[i+1] != "--commit"
		        if !(ARGV[i+1] =~ /^\w\S*=\S+/)
		           r=1
		           return r
		        else
	  		   if ARGV[i+1] =~ /\{.*\}/
			      r=5
			      return r
			   end
		        end 
		     end
		     i+=1

		when ARGV[i] == "-c" || ARGV[i] == "--commit"
		     # Nothing to do

       		when ARGV[i] =~ /^\-\-\S+=\S+$/
		     # Nothing to do
		
		else
		    r=1      
		    return r

	     end 	# case
	     i+=1
       end 	# while i<ARGV.length

       return r
   end 	# Resources.parsing

   # Test syntax of values using {...} expression
   # Return 
   #    0 : no error
   #    1 : one error occurs in {...} expression 
   def Resources.parsing_value(v, form)
       r = 0
       if form == "-a" || form == "-s"		# Only {number} form allowed with optional numeric format and offset when {...} operator is used 
	  if v =~ /\{.*\}/
	     r = 1 if !(v =~ /\{((%\d*d)|((\+|\-)\d*offset))*\d+((%\d*d)|((\+|\-)\d*offset))*\}/)
	  end
       end
       if form == "-p" 				# Only {%} form allowed with optional numeric format and offset when {...} operator is used 
	  if v =~ /\{.*\}/
	     r = 1 if !(v =~ /\{((%\d*d)|((\+|\-)\d*offset))*%((%\d*d)|((\+|\-)\d*offset))*\}/)
	  end
       end


       return r
   end 	# Resources.parsing_value


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
   #      We can use /nodes or /node. Ex : -a /node=mycluster[1-10]
   def Resources.decompose_argv

       (0..ARGV.length-1).each do |i|

           if ARGV[i] == "-a" || ARGV[i] == "--add"
              ARGV[i+1].split('/').each do |item|
                  if item != ""
       		     property_name, property_fixed_value, property_fixed_value2, property_nb, format_num, offset = Resources.decompose_param(ARGV[i], item)
             	     $cmd_user.push({:property_name => property_name, :property_fixed_value => property_fixed_value, 
                          	     :property_fixed_value2 => property_fixed_value2, :property_ndx => 0, :property_nb => property_nb,
	  	          	     :offset => offset, :format_num => format_num }) 

	          end
              end
           end

           if ARGV[i] == "-s" || ARGV[i] == "--select"
       	      property_name, property_fixed_value, property_fixed_value2, property_nb, format_num, offset = Resources.decompose_param(ARGV[i], ARGV[i+1])
              $cmd_user = $cmd_user.insert(0, {:property_name => property_name, :property_fixed_value => property_fixed_value, 
	                                       :property_fixed_value2 => property_fixed_value2, :property_ndx => 0, :property_nb => property_nb,
	  				       :offset => offset, :format_num => format_num }) 
           end

           if ARGV[i] == "-p" || ARGV[i] == "--property"
       	      property_name, property_fixed_value, property_fixed_value2, property_nb, format_num, offset = Resources.decompose_param(ARGV[i], ARGV[i+1])
              $cmd_user.push({:property_name => property_name, :property_fixed_value => property_fixed_value, 
                       	      :property_fixed_value2 => property_fixed_value2, :property_ndx => 0, :property_nb => property_nb,
	  	       	      :offset => offset, :format_num => format_num }) 
           end

           if ARGV[i] == "-d" || ARGV[i] == "--delete"
              property_name = property_fixed_value = property_fixed_value2 = property_nb = ""
	      if ARGV[i+1] =~ /=/
                 property_name = $`
	         property_nb = $'
	         $cmd_user.push({:property_name => property_name, :property_fixed_value => property_fixed_value, 
	                         :property_fixed_value2 => property_fixed_value2, :property_ndx => 0, :property_nb => property_nb})
              end
           end

       end 		#(0..ARGV.length-1) do |i|

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

	     property_nb = str2.to_i if form=="-a" || form=="--add" || form=="-s" || form=="--select"		# Only {number} form allowed with -a and -s params
	     property_nb = 1 if form=="-p" || form=="--property"						# Only {%} form allowed with -p params

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


   # Test if properties specified in command line exist in OAR database. Use "oarproperty -l" command
   # Test done only with -c option.
   # If one property does not exist, display error message and exit
   def Resources.properties_exists
       properties = nil
       prop_command_line=[]	# properties from command line
       if $options[:commit]

	  # retrieve all properties from command line
	  ARGV.each do |i|
    	      if i =~ /\//
       		 i.split('/').each do |j|
		   prop_command_line.push($`) if j =~ /=/
      		 end
    	      elsif i =~ /=/
		   prop_command_line.push($`) 
    	      end
	  end

	  # Test also cpuset property name if defined by user
	  prop_command_line.push($options[:cpusetproperty_name]) if $options[:cpusetproperty_name] != ""

	  # "nodes" or "node" are keywords for oaradmin
	  prop_command_line.delete_if {|x| x == "nodes" || x == "node" }

          r1 = `oarproperty -l`
          r2 = $?.exitstatus
          if r2 > 0
             $stderr.puts "[OARADMIN ERROR]: can't execute oarproperty -l command." 
	     exit(2)
 	  else
	     properties = prop_command_line - r1.split("\n")
	     if !properties.empty?
	        $stderr.print "[OARADMIN ERROR]: One or more properties does not exist : "
	        $stderr.print properties.join(", ") + " ! \n"
	        $stderr.print "[OARADMIN ERROR]: Please, use oarproperty command before.\n"
	        exit(3)
	     end
 
          end
       end
   end 	# Resources.properties_exists


   # Explore $cmd_user[] table and create oar commands - recursiv algorithm
   def Resources.tree n, str
       # n : the current level 
       # str : string contains the oar command to execute
    
       if n <= $cmd_user.length 
       
          # Create oarnodesetting command with correct syntax
          if $cmd_user[n-1][:property_name] == "nodes" || $cmd_user[n-1][:property_name] == "node"
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
		 if $cmd_user[n-1][:property_name]=="nodes" || $cmd_user[n-1][:property_name]=="node"
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
		 if $cmd_user[n-1][:property_name]=="nodes" || $cmd_user[n-1][:property_name]=="node"
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
             $stderr.puts "[OARADMIN ERROR]" + " command : " + str
             $stderr.puts r1
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
            if ARGV[i] == "-f" || ARGV[i]== "--file" || ARGV[i] == "-n" || ARGV[i] == "--number"
               i += 1
            else
               r.push(ARGV[i]) if !(ARGV[i] =~ /[^0-9]+/)
            end
            i += 1
      end
      return r

   end	# rule_list_from_command_line

   # Test params on command line
   # Parameters allowed : options  -f, -n, numbers 
   # 			  others parameters are wrong
   # Return 
   # 	false : all params are ok, true : one parameter is wrong
   def Admission_rules.test_params
       error = false
       i = 0
       while i < ARGV.length
            if ARGV[i] == "-f"
               i += 1
	    elsif ARGV[i] == "-n" || ARGV[i] == "--number"
		  i+=1
                  if ARGV[i].nil? || (ARGV[i] =~ /[^0-9]+/)
 	             error=true
		     break
		  end
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
      attr_accessor :rule_id,
		    :exist,				# rule exist y/n ?
		    :script,				# content of the admission rule - script Perl
      		    :export_file_name, 			# filename used to export	
		    :export_file_name_with_rule_id,	# filename must use number rule y/n
      		    :rule_id_must_exist, 		# the rule_id must be exist or not : true/false
      		    :file_name,          		# temporary file name to store the admission rule
      		    :editor,             		# command to be used for the text editor 
      		    :action,                            # true : comment - false : delete comments
      		    :silent_mode                        # silent mode for output y/n
		    
      def initialize(bdd, rule_id)
	  @bdd = bdd
	  @rule_id = rule_id
	  @script=""
	  @exist=false
      	  @export_file_name="" 
	  @export_file_name_with_rule_id=false
          @rule_id_must_exist=false
      	  @file_name=""
      	  @editor=""
	  @action=false
	  @silent_mode = false

	  if !rule_id.nil?
	     q = "SELECT * FROM admission_rules WHERE id = " + rule_id.to_s
	     rows = @bdd.select_one(q) 
	     if rows
	        @script = rows["rule"] 
	        @exist = true
	     end
	  end

	  @repository = Repository.new

      end

      # Display rule
      def display(display_level)
    	  puts "------"
    	  puts "Rule : " + @rule_id.to_s								# rule number

	  no_char = 65
	  mark_more_text = "..."
	  if display_level == 2		# display all text with -lll option
	     no_char = -1
	     mark_more_text=""
	  end

	  description_end = false
	  @script.each_with_index do |line,line_index|	
	 	if line_index == 0 									# title or object of the admission rule 
		   str = line[0..no_char]
		   str += mark_more_text if line.length > no_char+2
		   puts str
		end
		if (display_level==1 || display_level==2) && line_index > 0 && !description_end		# description of the admission rule
		   if line[0..0]=="#"
		      str = line[0..no_char]
		      str += mark_more_text if line.length > no_char+2
		      puts str
		   else
		      description_end = !description_end 
		   end
		end
		if display_level==2 && line_index > 0 && description_end				# rest of the admission rule
		   str = line[0..no_char]
		   str += mark_more_text if line.length > no_char+2
		   puts str
		end
	  end
      end	# def display(display_level)

      # Add rule 
      # if no number rule specified => add at the end of table
      # if number specified => insert admission rule at the rule_id position
      #    the numbers above or equal to rule_id are increased by 1 if necessary
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      def add
	  status = status2 = 0
	  msg = []
	  msg[0] = "Admission rule added"
	  id_tmp = 0
	  @repository.create
	  if @exist
	     # rule id already exist in database : add +1 to the rule ids
	     q = "SELECT * FROM admission_rules WHERE id >= " + @rule_id.to_s + " ORDER BY id DESC"
  	     rows = @bdd.execute(q)
	     
	     rows.each do |r|
	     	  q = "UPDATE admission_rules SET id = " + (r["id"] + 1).to_s + " WHERE id = " + r["id"].to_s
	     	  status = Bdd.do(@bdd, q)
		  if status==0 && @repository.active && status2==0
		     @repository.file_name="admission_rule_"+(r["id"] + 1).to_s
		     @repository.file_content=r["rule"]
		     if File.exist?(@repository.path_working_copy+"/"+@repository.file_name)
		     	status2 = @repository.write
		     else
		     	status2 = @repository.write
		   	@repository.add if status2==0
		     end
		  end
	     end
	     rows.finish
	
	     # Add rule in database
             q = "INSERT INTO admission_rules (id, rule) VALUES(?, ?)"
	     status = Bdd.do(@bdd, q, @rule_id, @script)
	     if status == 0
	        puts msg[0] 
		if status2 == 0 && @repository.active
		   @repository.file_name="admission_rule_"+@rule_id.to_s
		   @repository.file_content=@script
		   status2 = @repository.write
		   @repository.log_commit = "Add new admission rule #" + @rule_id.to_s + "\nNumber that already existed"
		   @repository.commit
		end
	     end
	  else
	     if !@rule_id.nil?
	        # Add rule in database
                q = "INSERT INTO admission_rules (id, rule) VALUES(?, ?)"
	        status = Bdd.do(@bdd, q, @rule_id, @script)
		if status == 0
	           puts msg[0] 
		   id_tmp=@rule_id
		end
	     else
	        # add admission rule at the end of table
                q = "INSERT INTO admission_rules (rule) VALUES(?)"
	        status = Bdd.do(@bdd, q, @script)
		if status==0
	           puts msg[0]
		   if @repository.active 
		      # Retrieve id for versioning
	     	      q = "SELECT max(id) FROM admission_rules" 
	     	      rows = @bdd.select_one(q)
		      id_tmp = rows[0]
		   end
		end
	     end
	     if status==0 && @repository.active
		@repository.file_name="admission_rule_"+id_tmp.to_s
		@repository.file_content=@script
		if @repository.write == 0
		   @repository.add
		   @repository.log_commit = "Add new admission rule #" + id_tmp.to_s
		   @repository.commit
		end
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
	     @repository.create
	     q = "UPDATE admission_rules SET rule = ? WHERE id = " + @rule_id.to_s
	     status = Bdd.do(@bdd, q, @script)
	     if status == 0
	        puts msg[0]
		if @repository.active
		   @repository.file_name="admission_rule_"+@rule_id.to_s
		   @repository.file_content=@script
		   if @repository.write == 0
		      @repository.log_commit = "Update admission rule #" + @rule_id.to_s 
		      @repository.commit
		   end
		end
	     end
          else
	      $stderr.puts "Error : the rule " + @rule_id.to_s + " does not exist"
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
	     q = "DELETE FROM admission_rules WHERE id = " + @rule_id.to_s
	     status_2 = Bdd.do(@bdd, q)
	     puts "Admission rule " + @rule_id.to_s + " deleted" if status_2 == 0
	  else
	     $stderr.puts "Error : the rule " + @rule_id.to_s + " does not exist"
	     status_1 = 1
	  end
      	  (status_1 != 0 || status_2 != 0) ? 1 : 0 
      end 	# def delete

      # Export one rule into a file
      def export
	  status=0
	  f_name = @export_file_name 
	  f_name += @rule_id.to_s if @export_file_name_with_rule_id
	  begin
               f = File.new(f_name, "w")
               f.print @script
               f.close
               puts "Export admission rule " + @rule_id.to_s + " into file " + f_name if silent_mode==false
	       rescue Exception => e
                      $stderr.puts "Error while creating file "+f_name
                      $stderr.puts e.message
                      status=1
	  end
	  status
      end	# def export

      # Edit an admission rule
      # Return :
      #    status : 0 : no error - > 0 : one error occurs
      #    user_choice : 0 : continue and commit changes in oar database - 1 : abort changes, nothing is done in oar database
      def edit
	  status = 0
	  user_choice = 1

	  if @exist==false && @rule_id_must_exist
	     $stderr.puts "Error : the rule " + @rule_id.to_s + " does not exist"
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
	      $stderr.puts "Error : the rule " + @rule_id.to_s + " does not exist"
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
		    :export_file_name_with_rule_id,	# filename must use number rule y/n
		    :silent_mode			# silent mode for output y/n

      def initialize(bdd, rules_set_user)
	  @bdd = bdd
	  @rules_set_user = rules_set_user
      	  @export_file_name="" 
	  @export_file_name_with_rule_id=false
	  @silent_mode = false
	
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
	    	 $stderr.puts "Error : the rule " + r.rule_id.to_s + " does not exist"
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
	  rule_ids_deleted=""
	  repository = Repository.new
	  @rules_set.each do |r|
	      repository.create if r.exist
	      status_2 = r.delete
	      status_1 = 1 if status_2 != 0
	      if status_2 == 0 && repository.active 
		 repository.file_name = "admission_rule_" + r.rule_id.to_s
		 rule_ids_deleted += "#" + r.rule_id.to_s + " "
		 repository.delete
	      end 
	  end
	  if repository.active && rule_ids_deleted != ""
	     repository.log_commit = "Delete admission(s) rule(s) "+rule_ids_deleted
	     repository.commit
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
		if @export_file_name_with_rule_id
                   files_already_exists.push(@export_file_name + r.rule_id.to_s) if File.exist?(@export_file_name + r.rule_id.to_s)
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
	  	    r.export_file_name_with_rule_id = @export_file_name_with_rule_id
		    r.silent_mode = @silent_mode
	            r.export 
	         else
	    	    $stderr.puts "Error : the rule " + r.rule_id.to_s + " does not exist"
		    status = 1
	         end
	     end
	  end
	  status
      end 	# def export

end	# class Rules_set



# Object Repository 
# Methods : 
#     - create 	       : create repository and working copy
#     - write          : write data in working copy
#     - add	       : execute svn add command
#     - delete         : delete file(s) in working copy and execute svn delete command
#     - commit         : execute svn commit command
#     - display_status : display error messages if repository does not exists or is unreadable
class Repository
      attr_accessor :file_name,			# File name to write in working copy
		    :file_content,		# Content of data to write in working copy
		    :log_commit,		# Log for commit 
		    :path_working_copy, 	# Path working copy
		    :active, 			# Versioning feature is active or not
		    :exists, 			# Repository exists y/n
		    :silent_mode,		# Silent mode for output y/n
		    :display_diff_changes	# Number changes to display

      def initialize
	  @file_name = ""
	  @file_content = ""
	  @log_commit = ""
	  @active = false
          @path_repository = ""		# Path of the repository
          @path_working_copy = ""	# Path of the working copy
	  @access_method = "file://"
	  @exists = false		# Repository exists y/n
	  @silent_mode=false
	  @display_diff_changes=nil

	  conf = Oar.load_configuration
          @active = true if !conf['OARADMIN_VERSIONING'].nil?  && conf['OARADMIN_VERSIONING'].upcase == "YES"

          # Files already exists ?
	  home_user_oar = ""
	  s = `getent passwd oar`
	  home_user_oar = s.split(":")[5].to_s
	  @path_repository = home_user_oar + "/.oaradmin/rp/svn_repository"
	  @path_working_copy = home_user_oar + "/.oaradmin/wc/svn_repository"
	  @exists = true if File.exist?(@path_repository)  
      end

      # Write file in working copy
      # Return :
      #    status 0 : no error - 1 : one error occurs
      def write
      	  status=0
	  begin
	       f = File.new(@path_working_copy+"/"+@file_name,"w")
	       f.print @file_content
	       f.close
	       rescue Exception => e
	              $stderr.puts "[OARADMIN ERROR]: Error while writing data in working copy for versioning"
		      $stderr.puts "[OARADMIN ERROR]: " + e.message
		      status=1
	  end
	  status
      end

      # Execute svn add command
      # Return :
      #    status 0 : no error - 1 : one error occurs
      def add
	  status=0
	  str = "svn add " + @path_working_copy+"/"+@file_name
          `#{str}`
	  r = $?.exitstatus
	  if r > 0
	     $stderr.puts "[OARADMIN ERROR]: Error while the svn add command"
	     status=1
	  end
	  status
      end

      # Delete a file in working copy and execute svn delete command
      # Return :
      #    status 0 : no error - 1 : one error occurs
      def delete 
	  status=0
	  begin
	       File.delete(@path_working_copy+"/"+@file_name)
	       rescue Exception => e
	              $stderr.puts "[OARADMIN ERROR]: Error while deleting data in working copy for versioning"
		      $stderr.puts "[OARADMIN ERROR]: " + e.message
		      status=1
	  end
	  if status==0
	     str = "svn delete " + @path_working_copy+"/"+@file_name 
             `#{str}`
	     r = $?.exitstatus
	     if r > 0
	        $stderr.puts "[OARADMIN ERROR]: Error while the svn delete command"
	        status=1
	     end
	  end
	  status
      end

      # Execute svn commit
      # Return :
      #    status 0 : no error - 1 : one error occurs
      def commit
	  status=0
	  str = "svn commit " + @path_working_copy + " -m " + '"' + @log_commit + '"'  
          `#{str}`
	  r = $?.exitstatus
	  if r > 0
	     $stderr.puts "[OARADMIN ERROR]: Error while the svn commit command"
	     status=1
	  else
	     puts "Versioning done" if !@silent_mode
	  end
	  status
      end

      
      # Create repository and working copy
      # Return :
      #    status 0 : no error - 1 : one error occurs
      def create
	  status=0

          if @active && !@exists
	     puts "Initialization of repository" 
	     paths = @path_repository.split("/")
	     current_dir = ""
	     (1..paths.length-2).each { |i| current_dir += "/" + paths[i] }
	     begin
	         FileUtils.mkdir_p current_dir
	         rescue Exception => e
	  	        $stderr.puts "[OARADMIN ERROR]: can't create " + current_dir + " directory for repository"
	  	        $stderr.puts "[OARADMIN ERROR]: " + e.message
	  	        status=1
	     end
	     if status==0
	        str = "svnadmin create " + @path_repository
                `#{str}`
	        r = $?.exitstatus
	        if r > 0
		   $stderr.puts "[OARADMIN ERROR]: Error while creating repository"
		   status=1
	        end
	     end 
	     if status==0 
	        paths = @path_working_copy.split("/")
	        current_dir = ""
	        (1..paths.length-2).each { |i| current_dir += "/" + paths[i] }
	        begin
	            FileUtils.mkdir_p current_dir
	            rescue Exception => e
		           $stderr.puts "[OARADMIN ERROR]: can't create " + current_dir + " directory for working copy."
		           $stderr.puts "[OARADMIN ERROR]: " + e.message
		           status=1
	        end
	     end
	     if status==0
	        str = "svn checkout " + @access_method + @path_repository + " " + @path_working_copy
                `#{str}`
	        r = $?.exitstatus
	        if r > 0
		   $stderr.puts "[OARADMIN ERROR]: Error while creating working copy"
		   status=1
	        end
	     end
	     if status==0
	        # Add all admission rules in working copy
	        list_rules = []
                $config=Oar.load_configuration
                dbh = Bdd.connect($config)
	        rules = Rules_set.new(dbh, list_rules)
                rules.export_file_name=@path_working_copy+"/"+"admission_rule_"
                rules.export_file_name_with_rule_id=true
	        rules.silent_mode=true
                rules.export
	        files = Dir[@path_working_copy+"/*"]
	        files.sort!
	        files.each do |f|
		     @file_name = File.split(f)[1]
		     self.add 
	        end
		@silent_mode=true

		# Add conf files 
		all_conf_files=["oar.conf", "monika.conf", "drawgantt.conf"]
		all_conf_files.each do |file|
		    r, conf_file = Oar.conf_file_readable(file)
		    if r==0
		       f = IO::read(conf_file)
                       @file_name=file 
                       @file_content=f
                       self.write
                       self.add
                    end
		end

		# Commit
	        @log_commit = "Initialization of repository"
	        self.commit 
		@silent_mode=false 
	     end
	     @exists=true if status==0
          end 	# if @active && !@exists 
	  status
      end	# create

      # Display error messages if repository does not exists or is unreadable 
      # Return :
      #    status 0 : no error - 1 : one error occurs
      def display_status
	  status=0
	  if !@active
	     $stderr.puts "[OARADMIN ERROR]: Versioning feature is not active"
	     $stderr.puts "[OARADMIN ERROR]: You can activate this feature with the parameter OARADMIN_VERSIONING in the OAR conf file"
	     status=1
	  elsif !@exists
	        $stderr.puts "[OARADMIN ERROR]: The repository does not exists or is unreadable"
	        status=1
	  end
	  status
      end	# display_status

end	# class Repository


# Object Revisions : contains revisions of Repository
# Methods :
#     - display_diff : display diff between revisions
class Revisions < Repository

      attr_accessor	:rev_id		# rev_id given by user

      # Load revisions
      def initialize(file_name)
	  super() 
	  @rev=[]			# Contains revisions numbers and dates
	  @file_name = file_name
	  @rev_id=nil

	  if !@active || !@exists
	     display_status
	  else
             # Retrieve all log from repository
             # Select all revisions numbers where a file, or admission rule is mentioned
	     status=0
             str = "svn log " + @access_method + @path_repository + " -v --xml"
             r = `#{str}`
             status = $?.exitstatus
	     if status > 0
	        $stderr.puts "[OARADMIN ERROR]: Error while browsing the repository"
	        status=1
	     else
	        xml_tags_not_found_paths = xml_tags_not_found_date = xml_tags_not_found_revision = false
                xml = REXML::Document.new(r)
                xml.root.each_element { |e|
             	    if !e.elements["paths"].nil?
             	       e.elements["paths"].each_element { |f|
             	         if f.get_text == "/" + @file_name
             	            d = nil
             		    if !e.elements["date"].nil?
             		       d = e.elements["date"].get_text.to_s
			       # with svn xml output format date is 2008-08-03T17:50:57.759877Z
			       # convert to 2008-08-03 19:50:57 +0200 
			       d1 = Time.xmlschema(d).localtime.strftime("%Y-%m-%d %H:%M:%S")
			       d2 = Time.xmlschema(d).localtime.rfc822.to_s
			       d = d1 + " " + d2[26,5] 
             		    else
		    	       xml_tags_not_found_date = true 
             		    end
			    if !e.attributes["revision"].nil?
             		       @rev.push({:rev=>e.attributes["revision"], :date=>d, :action=>f.attributes["action"]})
			    else
		    	       xml_tags_not_found_revision = true
			    end
             	         end
             	       }
		    else
		       xml_tags_not_found_paths = true
             	    end
                }
                @rev.push({:rev=>"0", :date=>""}) 	# For diff while add admission rules or files
	        if xml_tags_not_found_paths || xml_tags_not_found_date || xml_tags_not_found_revision
		   str2="[OARADMIN ERROR]: Some xml attribute(s) or tag(s) not found : "
		   str2 += "paths " if xml_tags_not_found_paths
		   str2 += "date " if xml_tags_not_found_date
		   str2 += "revision " if xml_tags_not_found_revision
		   $stderr.puts str2
		   $stderr.puts "[OARADMIN ERROR]: Please check xml format with command "+str
		   status=1
	        end
	     end	# if status > 0
	  end 	# if !@active || !@exists
      end	# initialize


      # Display historical changes
      # Execute diffs between revisions 
      # Return :
      #    status 0 : no error - 1 : one error occurs
      def display_diff
	  status=0
          if @rev.length >= 2
	     # First index in revisions @rev[0] is the latest revision in repository: r #latest 
	     # Last index in revisions @rev[length-1] is the older revision in repository : r #1
	     # We display changes, so we must have at least 2 revisions for an admission rule or a file
	     i=0
	     k=1
	     if @display_diff_changes.nil?
	        @display_diff_changes=@rev.length-1
	     else
		@display_diff_changes=@display_diff_changes.to_i
	     end
	     all_diffs = ""
	     while k <= @display_diff_changes && i <= @rev.length-2
		   cmd_diff = "svn diff " + @access_method + @path_repository + " -r " + @rev[i+1][:rev] + ":" + @rev[i][:rev]
		   r = `#{cmd_diff}`
		   status = $?.exitstatus
		   if status==0
		      one_diff = ""
		      file_found = false
		      r.each do |line|
			if file_found
			   if line[0..6]=="Index: "
			      if line != "Index: "+file_name
			         break
			      end
			   else
			      one_diff += line
			   end
			end
			if line.chomp == "Index: "+file_name
			   file_found=true
			end
		      end		# r.each do |line|
		      all_diffs += "Change(s) between r"+@rev[i+1][:rev]+" "
		      all_diffs += "("+@rev[i+1][:date].to_s+") " if @rev[i+1][:rev].to_s != "0" 
		      all_diffs += "and r"+@rev[i][:rev]+" ("+@rev[i][:date].to_s+")\n"
		      all_diffs += one_diff
		      all_diffs += "\n"
		   else
	     	      $stderr.puts "[OARADMIN ERROR]: Error while browsing the repository"
	     	      $stderr.puts "[OARADMIN ERROR]: Error while command : "+cmd_diff
	     	      status=1
		   end
		   i+=1
		   k+=1
	     end

	     # Display results
	     puts all_diffs

          else
	     puts "[OARADMIN ERROR]: File " + @file_name + " not found in repository"
          end	# if @rev.length >= 2

	  status
      end 	# display_diff

      # Retrieve the content of a file as it existed in a revision number
      # Return :
      #    0 : no error
      #    1 : The revision 0 exists but contains no file. 
      #        There is no file at rev 0 in a svn repository
      #    2 : The revision number specified by user is greater
      #        than the revision number of repository
      #    3 : svn cat repository/file@rev is impossible.
      #        The #rev specified by user does not contains the file @file_name 
      def retrieve_file_rev
	  status=0

	  # @rev contains always r0. So we must have at least 2 elements in @rev for the file
	  if @rev.length < 2
	     $stderr.puts "[OARADMIN ERROR]: File " + @file_name + " not found in repository"
	     return 1
	  end

	  # Retrieve revision max from repository
	  rev_max_repository=nil
	  str = "svn info " + @access_method + @path_repository + " --xml"
	  r = `#{str}` 
	  xml = REXML::Document.new(r)
	  xml.root.each_element { |e|
	  rev_max_repository = e.attributes["revision"].to_i
	  }
	  if @rev_id > rev_max_repository
	     $stderr.puts "[OARADMIN ERROR]: The revision #"+ @rev_id.to_s + " does not exist in repository"
	     $stderr.puts "[OARADMIN ERROR]: The latest revision in repository is #" + rev_max_repository.to_s 
	     return 2
	  end

	  # #rev given by user exists in repository
	  # test if the #rev given by user exists for the file 
	  str = "svn list " + @access_method + @path_repository + " -r " + @rev_id.to_s + " --xml" 
	  r = `#{str}`
	  xml = REXML::Document.new(r)
	  file_exist_in_rev = false
	  xml.root.each_element { |e|
	      e.each_element { |f|
		file_exist_in_rev = true if f.elements["name"].get_text == @file_name
	      }
          }
	  if !file_exist_in_rev
	     # test for more information to user
	     # perhaps #rev given by user is a revision where the file was deleted
	     file_deleted_in_rev=false
	     (0..@rev.length-2).each do |i|
		 file_deleted_in_rev=true if @rev[i][:rev].to_i == @rev_id && @rev[i][:action]=="D"
	     end	# (0..@rev.length-2).each do |i|

	     $stderr.puts "[OARADMIN ERROR]: Bad revision number. The file " + @file_name + " does not exist in revision #"+ @rev_id.to_s
	     if file_deleted_in_rev
	        $stderr.puts "[OARADMIN ERROR]: In #" + @rev_id.to_s + " the file was deleted. So it does not exist. To retrieve the content, try an older #rev"
	     end

	     return 3
	  end

	  # File @file_name exist in #rev
          str = "svn cat " + @access_method + @path_repository + "/" + @file_name + "@" + @rev_id.to_s
          @file_content = `#{str}`

	  status
      end 	# retrieve_file_rev


end 	# class Revisions



