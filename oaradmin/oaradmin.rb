#!/usr/bin/ruby  
# $Id: oaradmin.rb 1 2008-05-05 16:00:00 ddepoisi $
#
# oaradmin : utility to manage oar configuration 
#
# requirements:
# ruby1.8 (or greater)
# libdbi-ruby 
# libdbd-mysql-ruby or libdbd-pg-ruby
# libyaml-ruby
# 
# To activate the verbose mode, add -w at the end of the first line. Ex : #!/usr/bin/ruby -w
#


require 'optparse'
require 'dbi'
require 'yaml'
require 'oar_modules'
require 'oaradmin_modules'



$msg = []
$options= {} 		

$subcommand = []
$subcommand[0] = {:short_form=>"re",   :long_form=>"resources",  :description=>"manage resources in oar database"} 
$subcommand[1] = {:short_form=>"ru",   :long_form=>"rules",      :description=>"manage admission rules"} 
$subcommand[2] = {:short_form=>"",     :long_form=>"conf",       :description=>"edit conf file and keep changes in Svn repository"} 
$subcommand[8] = {:short_form=>"",     :long_form=>"help",       :description=>"print this help message"} 
$subcommand[9] = {:short_form=>"ver",  :long_form=>"version",    :description=>"print OAR version number"} 


# Display usage
def subcommand_usage
   puts "Usage: oaradmin <subcommand>"
   puts "Utility to manage oar configuration"
   puts
   puts "Available subcommands : "
   (0..$subcommand.length-1).each do |i|
       if !$subcommand[i].nil? 
          str = "   "+$subcommand[i][:long_form]
          str += " ("+$subcommand[i][:short_form]+")" if $subcommand[i][:short_form].length>0 
          str = str.ljust(27)+$subcommand[i][:description] 
          puts str
       end
   end 
   puts
   puts "See also oaradmin man page for more information"
   puts
   exit(1)
end



#####################
# MAIN PROGRAM
#####################

# Enable to execute a subcommand with an alias
# Ex : oaradminresources instead of oaradmin re 
#      oaradminrules     instead of oaradmin rules
if File.basename($0) != "oaradminresources" && File.basename($0) != "oaradminrules"

   $subcommand_choice=-1
   $subcommand.each_index do |i|
       $subcommand_choice = i if !$subcommand[i].nil? && !ARGV[0].nil? && (ARGV[0]==$subcommand[i][:short_form] || ARGV[0]==$subcommand[i][:long_form])
   end
   if $subcommand_choice == -1
      $stderr.puts "Incoherence in specified subcommand" if !ARGV[0].nil?
      subcommand_usage
   end

   # New ARGV with options only
   ARGV.delete_at(0)

else
   $subcommand_choice = 0 if File.basename($0) == "oaradminresources"
   $subcommand_choice = 1 if File.basename($0) == "oaradminrules"
end

case
    when $subcommand_choice==0 	
	# ################
	# Manage resources 
	# ################

        $msg[0] = "Incoherence or syntax error in specified options"
        $msg[1] = "A parameter after an option is missing"
        $msg[2] = "With -a and -s options, in {...} expression only a numeric value with optional numeric format and offset are allowed"
        $msg[3] = "With -p option, in {...} expression only % character with optional numeric format and offset are allowed"
        $msg[4] = "With -d option, {...} expression is not allowed"
        $msg[5] = "[OARADMIN]: No resource selected"
        $msg[6] = "[OARADMIN ERROR]: Oaradmin uses oarnodes -Y command. So perl-yaml package must be installed with oarnodes"
        $msg[7] = "[OARADMIN ERROR]: Oaradmin uses oarnodes command. So oar-user package must be installed" 

        $cmd_user = []
        $oar_cmd = ""

        $list_resources_id=[]	 	# contains the list of resources to delete

        # Options for parsing
        $options = {}
        $options[:add] = $options[:select] = $options[:property] = $options[:delete] = $options[:commit] = false
	$options[:cpusetproperty] = false
	$options[:cpusetproperty_name] = ""
        opts = OptionParser.new do |opts|
            opts.banner = "Usage: oaradmin resources [-a [--cpusetproperty=prop][-p]] [-s -p] [-d] [-c]"

            # add resources
            opts.on("-a","--add","Add new resources") do 
               $options[:add] = true 
            end

            # cpusetproperty
            opts.on("--cpusetproperty=prop","Property name for cpuset numbers") do |opt|
	       $options[:cpusetproperty]=true
               $options[:cpusetproperty_name] = opt 
            end

            # update resources
            opts.on("-s","--select","Select resources for update") do
               $options[:select] = true
            end
    
            opts.on("-p","--property","Set value for a property") do
               $options[:property] = true
            end

            # delete resources
            opts.on("-d","--delete","Delete resources") do
               $options[:delete] = true
            end

            # execute and modify database oar
            opts.on("-c","--commit", "Commit in oar database") do
               $options[:commit] = true
            end

            # help
            opts.on_tail("-h", "--help", "Show this message") do
               puts opts
               exit(1)
            end
        end

        begin
             opts.parse ARGV
             rescue OptionParser::ParseError => no_erreur
                puts no_erreur
                puts opts
                exit(1)
        end

        # Other tests on syntax
        if ARGV.empty?
           puts opts
           exit(1)
        end

        if !( ($options[:add] && !$options[:property] && !$options[:select] && !$options[:delete]) ||	# -a alone
              ($options[:add] && $options[:property] && !$options[:select] && !$options[:delete]) ||	# -a -p
              ($options[:select] && $options[:property] && !$options[:add] && !$options[:cpusetproperty] && !$options[:delete]) ||  	# -s -p
              (!$options[:select] && !$options[:property] && !$options[:add] && !$options[:cpusetproperty] && $options[:delete]) ) 	# -d alone

              puts $msg[0]
              puts opts
              exit(1)
        end

        # Tests syntax in command line
        r = Resources.parsing
	if r > 0
              puts $msg[0] if r == 1
              puts $msg[1] if r == 2
              puts $msg[2] if r == 3
              puts $msg[3] if r == 4
              puts $msg[4] if r == 5
	      
              puts opts
              exit(1)
        end

        # add resources
        if $options[:add]

           $oar_cmd = "oarnodesetting -a "

	   # Test syntax for --cpusetproperty
	   if [:cpusetproperty]
	      i=0
	      while i<ARGV.length
	   	    if !ARGV[i].nil? && ARGV[i][0..1]=="--"
	   	       if ARGV[i]=~/^--\S+=\S+/
	   	          ARGV.delete_at(i)	
	   	          redo
	   	       elsif ARGV[i]!="--add" && ARGV[i]!="--property" && ARGV[i]!="--select" && ARGV[i]!="--delete" && ARGV[i]!="--commit"
            		  puts $msg[0]
              		  puts opts
              		  exit(1)
	   	       end
	   	    end
	   	    i+=1
	      end
	   end

           # Decompose ARGV[] in hash table $cmd_user
           Resources.decompose_argv

	   $cpuset_host_previous = $cpuset_host_current = ""
	   $cpuset_property_previous_value = $cpuset_property_current_value = ""
	   $cpuset_no=0	   
	   $cpuset_property_name=$options[:cpusetproperty_name]

	   # Properties exists in OAR database ?
	   Resources.properties_exists

           Resources.tree 1, $oar_cmd

        end 	# if $options[:add]


        # update resources : -s and -p  
        if $options[:select] && $options[:property]

	   # Properties exists in OAR database ?
	   Resources.properties_exists

           # Decompose ARGV[] in hash table $cmd_user
           Resources.decompose_argv
   
           if $cmd_user[0][:property_nb].is_a?(Fixnum)
              # We have a form param={3} - Ex : core={2} nodes=mycluster{12}.local
              # Recover the max value of param 
              val_max = -1
              r = `oarnodes -a -Y`
              if $?.exitstatus == 0
		 r_hash = YAML::load(r)
                 if $cmd_user[0][:property_name] == "nodes" || $cmd_user[0][:property_name] == "node"
	            str = "network_address"
                 else
	            str = $cmd_user[0][:property_name]
	         end
		 str2 = $cmd_user[0][:property_fixed_value]
		 str3 = $cmd_user[0][:property_fixed_value2]
		 r_hash_list_nodes=r_hash.keys		 
		 r_hash_list_nodes.each do |n|		 
		      r_hash_list_resources = r_hash[n].keys 
		      r_hash_list_resources.each do |r|
			   r_hash[n][r]['properties'].each do |key,value|
			        if key==str
				   value=value.to_s
				   if value =~ /^#{str2}\d+#{str3}/
				      if value =~ /\d+/
	   				 if $`.to_s == str2 && $'.to_s == str3
	                       	            val_max = $&.to_i if $&.to_i > val_max
	   				 end
				      end
				   end
				end
			   end 
		      end
		 end
	      elsif $?.exitstatus == 6
		    $stderr.puts $msg[6]
		    exit(2)
	      elsif $?.exitstatus == 127
		    $stderr.puts $msg[7]
		    exit(2)
              end	# if $?.exitstatus == 0

	      resources_selected=false
              i = j = k = 1
              i += $cmd_user[0][:offset]
              while i <= val_max && j+$cmd_user[0][:offset] <= val_max
	    
	            # First part of oar command
	            str = "oarnodesetting "

	            # Properties in the oar command
	            (1..$cmd_user.length-1).each do |n|
	    	        str += "-p " + $cmd_user[n][:property_name] + "="
		        if $cmd_user[n][:property_nb].is_a?(Fixnum)
			   # we can have the follows forms : property=param{%}  property=text_part_a{%2d%+20offset}text_part_b
			   v = k + $cmd_user[n][:offset]
	         	   v = sprintf("#{$cmd_user[n][:format_num]}", v) if $cmd_user[n][:format_num].length > 0 
   	         	   str += $cmd_user[n][:property_fixed_value] + v.to_s + $cmd_user[n][:property_fixed_value2]
			else
			   # we can have : property=value but without {%} operator
		           str += $cmd_user[n][:property_nb]
			end
		        str += " "
	            end
	    
 	            # --sql clause in the oar command or -h hostname
	            v = i
	            v = sprintf("#{$cmd_user[0][:format_num]}", v) if $cmd_user[0][:format_num].length > 0 
	            v = v.to_s
	            if $cmd_user[0][:property_name] == "nodes" || $cmd_user[0][:property_name] == "node"
	               str = str + "-h " + $cmd_user[0][:property_fixed_value] + v + $cmd_user[0][:property_fixed_value2] 
	            else
	                str += "--sql "
                        str += '"'
		        str = str + $cmd_user[0][:property_name] + "="
		        if $cmd_user[0][:property_fixed_value].length > 0 
		           str = str + "'" + $cmd_user[0][:property_fixed_value] + v + $cmd_user[0][:property_fixed_value2]+ "'"
		        else
		           str += v
		        end
	                str += '"'
	            end

	            # Execution
	            Resources.execute_command(str)

		    resources_selected=true
                    i += 1
	            j += 1
	            if j > $cmd_user[0][:property_nb]
	               j = 1 
	               k += 1
	            end
	    
              end
	      puts $msg[5] if !resources_selected
 
           else
       	        # We have a form param=host_a,host_b, host[10-20,30,35-50,70],host_c,host[80-120]
	        list_val = Resources.decompose_list_values($cmd_user[0][:property_nb])
		k = 1
 	        list_val.each do |item|
	
	            # First part of oar command
	            str = "oarnodesetting "

	            # Properties in the oar command
	            (1..$cmd_user.length-1).each do |n|
	                str += "-p " + $cmd_user[n][:property_name] + "=" 
		        if $cmd_user[n][:property_nb].is_a?(Fixnum)
			   # we can have the follows forms : property=param{%}  property=text_part_a{%2d%+20offset}text_part_b
			   v = k + $cmd_user[n][:offset]
	         	   v = sprintf("#{$cmd_user[n][:format_num]}", v) if $cmd_user[n][:format_num].length > 0 
   	         	   str += $cmd_user[n][:property_fixed_value] + v.to_s + $cmd_user[n][:property_fixed_value2]
			else
			   # we can have : property=value but without {%} operator
		           str += $cmd_user[n][:property_nb]
			end
		    	str += " "
	            end
	    
	            # --sql clause in the oar command or -h hostname
	            if $cmd_user[0][:property_name] == "nodes" || $cmd_user[0][:property_name] == "node"
	               str = str + "-h " + item  
	            else
	                str += "--sql "
                        str += '"'
		        str = str + $cmd_user[0][:property_name] + "="
	        
		        if item =~ /[^0-9]/ 
		           str = str + "'" + item + "'"
		        else
		           str += item
		        end
		
		        str += '"'
	            end

	            # Execution
	            Resources.execute_command(str)
	    		
		    k += 1

	        end

           end 		# if $cmd_user[0][:property_nb].is_a?(Fixnum)

        end 	# if $options[:select] && $options[:property]


        # delete resources
        if $options[:delete]

	   # Properties exists in OAR database ?
	   Resources.properties_exists

           # Decompose ARGV[] in hash table $cmd_user
           Resources.decompose_argv

           if $cmd_user.length > 0
              # search properties matched condition
              # -d nodes=host[1-50] or -d cluster=zeus
              list_val = Resources.decompose_list_values($cmd_user[0][:property_nb])

              # Recover list of resource_id
              # $list_resources_id[] contains the list of resources to delete
              r = `oarnodes -a -Y`
              if $?.exitstatus == 0
		 r_hash = YAML::load(r)
                 if $cmd_user[0][:property_name] == "nodes" || $cmd_user[0][:property_name] == "node"
	            str = "network_address"
                 else
	            str = $cmd_user[0][:property_name]
	         end
                 list_val.each do |v|
		     r_hash_list_nodes=r_hash.keys
		     r_hash_list_nodes.each do |n|		 
		          r_hash_list_resources = r_hash[n].keys 
		          r_hash_list_resources.each do |r|
			       r_hash[n][r]['properties'].each do |key,value|
			            if key==str
				       value=value.to_s
				       $list_resources_id.push(r_hash[n][r]['properties']['resource_id'].to_s) if value==v
				    end
			       end 
		          end
		     end
		 end
	      elsif $?.exitstatus == 6
		     $stderr.puts $msg[6]
		     exit(3)
	      elsif $?.exitstatus == 127
		     $stderr.puts $msg[7]
		     exit(3)
              end	# if $?.exitstatus == 0
           else
              # search all resources_id
              r = `oarnodes -a -Y`
              if $?.exitstatus == 0
		 r_hash = YAML::load(r)
		 r_hash_list_nodes=r_hash.keys
		 r_hash_list_nodes.each do |n|		 
		      r_hash_list_resources = r_hash[n].keys 
		      r_hash_list_resources.each do |r|
			   $list_resources_id.push(r_hash[n][r]['properties']['resource_id'].to_s) 
		      end
		 end
	      elsif $?.exitstatus == 6
		    $stderr.puts $msg[6]
		    exit(3)
	      elsif $?.exitstatus == 127
		    $stderr.puts $msg[7]
		    exit(3)
              end 
           end 

	   # Sort
	   $list_resources_id.each do |item|
		item=item.to_i
	   end
	   $list_resources_id.sort!
	   $list_resources_id.each do |item|
		item=item.to_s
	   end

           # Delete each resource_id
           if !$list_resources_id.empty? 
              $list_resources_id.each do |r|
                  str = "oarnodesetting -r " + r + " -s Dead -n "
                  Resources.execute_command(str)
                  str = "oarremoveresource " + r
                  Resources.execute_command(str)
              end
	   else
	      puts $msg[5]
	   end

        end 	# if $options[:delete]




    when $subcommand_choice==1
	# ######################
	# Manage admission rules
	# ######################

        $msg[0] = "Incoherence in specified options"
        $msg[1] = "Configuration file not found"
        $msg[2] = "Error : bad admission rule number"
        $msg[3] = "Error : no admission rule number given"
        $msg[4] = "Error : too many admission rule numbers"
        $msg[5] = "One parameter is bad"
        $msg[6] = "Error : two parameters are required, rule_id and revision number"
        $msg[7] = "Error : a revision number must be greater than zero"

        $script = ""

        # Options for parsing
        $options = {}
        $options[:list] = $options[:add] = $options[:file] = $options[:edit] = $options[:export] = $options[:delete] = false
        $options[:history] = $options[:history_no] = $options[:revert] = false
        $options[:comment] = nil

        opts = OptionParser.new do |opts|
            opts.banner = "Usage: oaradmin rules [-l|-ll|-lll [rule_ids]] [-a [rule_id] [-f file]] [-d rule_id [rule_ids]] \n                      [-x [rule_ids] [-f file]] [-e rule_id [-f file]] [-1 rule_id] [-0 rule_id]\n                      [-H rule_id [-n number]] [-R rule_id rev]"

            # list admission rules
            opts.on("-l","--list","List admission rules") do 
               $options[:list] = true 
            end

            # add an admission rule
            opts.on("-a","--add","Add an admission rule") do 
               $options[:add] = true 
            end

            # file name 
            opts.on("-f","--file","File which contains script for admission rule") do 
               $options[:file] = true 
            end

            # delete admission rules
            opts.on("-d","--delete","Delete admission rules") do 
               $options[:delete] = true 
            end

            # export admission rules 
            opts.on("-x","--export","Export admission rules") do
               $options[:export] = true
            end

            # edit an admission rule
            opts.on("-e","--edit","Edit an admission rule") do 
               $options[:edit] = true 
            end

            # Enable the admission rule 
            opts.on("-1","--enable","Enable the admission rule (removing comments)") do 
               $options[:comment] = false
            end

            # Disable the admission rule 
            opts.on("-0","--disable","Disable the admission rule (commenting the code)") do 
               $options[:comment] = true
            end

            # Show the changes made on the admission rule 
            opts.on("-H","--history","Show all changes made on the admission rule") do 
               $options[:history] = true
            end

            # Number of latest changes to display  
            opts.on("-n","--number","Number of latest changes to display") do 
               $options[:history_no] = true
            end

            # Revert to the admission rule as it existed in a revision number 
            opts.on("-R","--revert","Revert to the admission rule as it existed in a revision number") do 
               $options[:revert] = true
            end

            # help
            opts.on_tail("-h", "--help", "Show this message") do
               puts opts
               exit
            end

        end

        begin
             opts.parse ARGV
             rescue OptionParser::ParseError => no_erreur
                puts no_erreur
	        puts opts
                exit(1)
        end

        # Other tests on syntax
        if ARGV.empty?
           puts opts
           exit(1)
        end

        if !( ( $options[:list] && !$options[:add] && !$options[:file] && !$options[:edit] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? && 
	       !$options[:history] && !$options[:history_no] && !$options[:revert] ) ||   # -l 
              (!$options[:list] &&  $options[:add] && !$options[:file] && !$options[:edit] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? &&
	       !$options[:history] && !$options[:history_no] && !$options[:revert] ) ||   # -a 
              (!$options[:list] &&  $options[:add] &&  $options[:file] && !$options[:edit] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? &&
	       !$options[:history] && !$options[:history_no] && !$options[:revert] ) ||   # -a -f
              (!$options[:list] && !$options[:add] && !$options[:file] &&  $options[:edit] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? &&
	       !$options[:history] && !$options[:history_no] && !$options[:revert] ) ||   # -e 
              (!$options[:list] && !$options[:add] &&  $options[:file] &&  $options[:edit] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? &&
	       !$options[:history] && !$options[:history_no] && !$options[:revert] ) ||   # -e -f
              (!$options[:list] && !$options[:add] && !$options[:file] && !$options[:edit] &&  $options[:delete] && !$options[:export] &&  $options[:comment].nil? &&
	       !$options[:history] && !$options[:history_no] && !$options[:revert] ) ||   # -d 
              (!$options[:list] && !$options[:add] && !$options[:file] && !$options[:edit] && !$options[:delete] &&  $options[:export] &&  $options[:comment].nil? &&
	       !$options[:history] && !$options[:history_no] && !$options[:revert] ) ||   # -e  
              (!$options[:list] && !$options[:add] &&  $options[:file] && !$options[:edit] && !$options[:delete] &&  $options[:export] &&  $options[:comment].nil? &&
	       !$options[:history] && !$options[:history_no] && !$options[:revert] ) ||   # -e -f
              (!$options[:list] && !$options[:add] && !$options[:file] && !$options[:edit] && !$options[:delete] && !$options[:export] && !$options[:comment].nil? &&
	       !$options[:history] && !$options[:history_no] && !$options[:revert] ) ||   # comment
              (!$options[:list] && !$options[:add] && !$options[:file] && !$options[:edit] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? && 
	        $options[:history] && !$options[:history_no] && !$options[:revert] ) ||   # -H 
              (!$options[:list] && !$options[:add] && !$options[:file] && !$options[:edit] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? && 
	        $options[:history] &&  $options[:history_no] && !$options[:revert] ) ||   # -H -n
              (!$options[:list] && !$options[:add] && !$options[:file] && !$options[:edit] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? && 
	       !$options[:history] && !$options[:history_no] &&  $options[:revert] ) )    # -R 

              puts $msg[0]
              puts opts
              exit(1)
        end

	if Admission_rules.test_params
           puts $msg[5]
           puts opts
           exit(1)
	end

        # Load configuration
        $config=Oar.load_configuration
        if $config.empty?
           $stderr.puts $msg[1]
           exit(3)
        end

        filename_base = "admission_rule_"

	editor, directory = Edit.env($config)

        # Connect to the database
        dbh = Bdd.connect($config)
        exit(4) if dbh.nil?

        case
            when $options[:list]
	         # List admission rules
	 
   	         # rules given by user
   	         list_rules = Admission_rules.rule_list_from_command_line
	 
                 level = level_max = 0
   	         (0..ARGV.length-1).each do |i|
	             level = 1 if ARGV[i]=~/-ll/ 
	             level = 2 if ARGV[i]=~/-lll/ 
	             level_max = level if level > level_max
	         end
	         level = level_max

		 rules = Rules_set.new(dbh, list_rules)
   	         status = rules.display(level)
	         exit(5) if status != 0


            when $options[:add]
	         # Add admission rule
	         rule_id = nil 
   	         list_rules = Admission_rules.rule_list_from_command_line
   	         if list_rules.length > 1
                    $stderr.puts $msg[4]
		    puts opts
                    exit(6)
   	         end
		 rule_id = list_rules[0].to_i if !list_rules.empty?
	         if rule_id && rule_id == 0 
	            $stderr.puts $msg[2]
	            exit(6)
	         end

	         if $options[:file]
   	            # add admission rule from a file 
   	            status, $script = Admission_rules.load_rule_from_file
	            exit(6) if status != 0
		    rule = Rule.new(dbh, rule_id)
		    rule.script = $script
		    status = rule.add
	            exit(6) if status != 0
	         else
   	            # add admission rule using a text editor 
	            file_name = directory + "OAR_tmp_" + filename_base
	            file_name += rule_id.to_s if rule_id
		    rule = Rule.new(dbh, rule_id)
		    rule.script = ""
		    rule.rule_id_must_exist = false
		    rule.file_name = file_name
		    rule.editor = editor 
	            status, user_choice = rule.edit
	            if status==0 && user_choice==0
		       status = rule.add
	               exit(6) if status != 0
	            end
	         end


            when $options[:edit]
	         # Update admission rule
   	         # rules given by user
   	         list_rules = Admission_rules.rule_list_from_command_line
   	         if list_rules.length == 0 
                    $stderr.puts $msg[3]
		    puts opts
                    exit(7)
   	         end
   	         if list_rules.length > 1
                    $stderr.puts $msg[4]
		    puts opts
                    exit(7)
   	         end
		 rule_id = list_rules[0].to_i
	         if rule_id == 0 
	            $stderr.puts $msg[2]
	            exit(7)
	         end
	         if $options[:file] 
   	            # update admission rule from a file 
	            status, $script = Admission_rules.load_rule_from_file
	            exit(7) if status != 0
		    rule = Rule.new(dbh, rule_id)
		    rule.script = $script
		    status = rule.update
	            exit(7) if status != 0
	         else
	            # edit admission rule using a text editor
	            file_name = directory + "OAR_tmp_" + filename_base
	            file_name += rule_id.to_s if rule_id
		    rule = Rule.new(dbh, rule_id)
		    rule.rule_id_must_exist = true
		    rule.file_name = file_name
		    rule.editor = editor 
	            status, user_choice = rule.edit
	            exit(7) if status != 0
	            if status==0 && user_choice==0
		       status = rule.update
	               exit(7) if status != 0
	            end
	         end


            when $options[:delete]
	         # Delete admission rules

   	         # rules given by user
   	         list_rules = Admission_rules.rule_list_from_command_line

   	         if list_rules.length > 0
      	            rules = Rules_set.new(dbh, list_rules)
      	            status = rules.delete
	            exit(8) if status != 0
   	         else
      	            $stderr.puts $msg[3]
		    puts opts
      	            exit(8)
   	         end


            when $options[:export]
	         # Export admission rules

   	         # rules given by user
   	         list_rules = Admission_rules.rule_list_from_command_line

   	         if $options[:file] && list_rules.length !=1
                    puts $msg[0]
		    puts opts
                    exit(9)
   	         end

		 rules = Rules_set.new(dbh, list_rules)
   	         if $options[:file]
      	            user_file_name = "" 
      	            (0..ARGV.length-1).each do |i|
          	        if ARGV[i] == "-f"
             	           user_file_name = ARGV[i+1] if i < ARGV.length-1
          	        end
      	            end
		    rules.export_file_name=user_file_name
		    rules.export_file_name_with_rule_id=false
   	         else
		    rules.export_file_name=filename_base
		    rules.export_file_name_with_rule_id=true
   	         end
   	         status = rules.export
	         exit(9) if status != 0


            when !$options[:comment].nil?
	         # Enable or disable an admission rule
   	         list_rules = Admission_rules.rule_list_from_command_line
   	         if list_rules.length == 0 
                    $stderr.puts $msg[3]
		    puts opts
                    exit(10)
   	         end
   	         if list_rules.length > 1
                    puts $msg[4]
		    puts opts
                    exit(10)
   	         end

		 rule = Rule.new(dbh, list_rules[0])
		 rule.action = $options[:comment]
      	         status = rule.comment
	         exit(10) if status != 0


            when $options[:history]
		 # Show the changes made on the admission rule
	         rule_id = nil 
   	         list_rules = Admission_rules.rule_list_from_command_line
   	         if list_rules.length > 1
                    $stderr.puts $msg[4]
		    puts opts
                    exit(11)
   	         end
   	         if list_rules.length == 0 
                    $stderr.puts $msg[3]
		    puts opts
                    exit(11)
   	         end
		 rule_id = list_rules[0].to_i 
	         if rule_id == 0 
	            $stderr.puts $msg[2]
	            exit(11)
	         end

		 revisions = Revisions.new("admission_rule_"+rule_id.to_s)
		 exit(11) if !revisions.active || !revisions.exists
   	         if $options[:history_no]
      	            (0..ARGV.length-1).each do |i|
          	        if ARGV[i] == "-n" || ARGV[i] == "--number" 
		           if i < ARGV.length-1 && ARGV[i+1].to_i > 0
             	              revisions.display_diff_changes = ARGV[i+1] 
			   else
		    	      $stderr.puts "The number of changes must be greater than zero"
		    	      exit(11)
			   end
          	        end
      	            end
		 end
		 status = revisions.display_diff
		 exit(11) if status != 0

            when $options[:revert]
		 # Revert to the admission rule as it existed in a revision number 
	         rule_id = nil 
   	         list_rules = Admission_rules.rule_list_from_command_line
   	         if list_rules.length != 2		# In this case, list_rules[0] is the rule_id 
                    $stderr.puts $msg[6]		# and list_rules[1] is the revision number             
		    puts opts
                    exit(12)
   	         end
		 rule_id = list_rules[0].to_i 
	         if rule_id == 0 
	            $stderr.puts $msg[2]
	            exit(12)
	         end
	         if list_rules[1].to_i == 0 
	            $stderr.puts $msg[7]
	            exit(12)
	         end
		 revisions = Revisions.new("admission_rule_"+rule_id.to_s)
		 exit(12) if !revisions.active || !revisions.exists
		 revisions.rev_id = list_rules[1].to_i
		 status = revisions.retrieve_file_rev
		 exit(12) if status != 0

		 # Add or update in oar database
		 rule = Rule.new(dbh, rule_id)
		 if rule.exist
		    # rule already exist in oar database => update
		    rule.script = revisions.file_content
                    status = rule.update
		    exit(12) if status != 0
		 else
		    # rule does not exist in oar database and we have an old content
		    # from repository. So, rule was deleted
                    rule.script = revisions.file_content
                    status = rule.add
		    exit(12) if status != 0
		 end

        end	# case

        # Disconnect from database
        dbh.disconnect if dbh


    when $subcommand_choice==2
	# ##############################################
	# Edit conf file and keep changes for versioning
	# ##############################################

        $msg[0] = "Incoherence in specified options"
        $msg[1] = "Error : no file name given"
        $msg[2] = "Error : too many file name given"
        $msg[3] = "Error : a number must be specified"
        $msg[4] = "One parameter is bad"
        $msg[5] = "Error : a revision number must be greater than zero"

        # Options for parsing
        $options = {}
        $options[:edit] = $options[:history] = $options[:history_no] = $options[:revert] = false

        opts = OptionParser.new do |opts|
            opts.banner = "Usage: oaradmin conf [-e conf_file] [-H conf_file [-n number]] [-R conf_file rev]"

            # edit the conf file
            opts.on("-e","--edit","Edit the conf file") do
               $options[:edit] = true
            end

            # Show the changes made on conf file 
            opts.on("-H","--history","Show all changes made on the conf file") do 
               $options[:history] = true
            end

            # Number of latest changes to display  
            opts.on("-n","--number","Number of latest changes to display") do 
               $options[:history_no] = true
            end

            # Revert to the conf file as it existed in a revision number 
            opts.on("-R","--revert","Revert to the conf file as it existed in a revision number") do 
               $options[:revert] = true
            end

            # help
            opts.on_tail("-h", "--help", "Show this message") do
               puts opts
               exit
            end

        end

        begin
             opts.parse ARGV
             rescue OptionParser::ParseError => no_erreur
                puts no_erreur
	        puts opts
                exit(1)
        end

        # Other tests on syntax
        if ARGV.empty?
           puts opts
           exit(1)
        end

        if !( ( $options[:edit] && !$options[:history] && !$options[:history_no] && !$options[:revert] ) ||   # -e 
	      (!$options[:edit] &&  $options[:history] && !$options[:history_no] && !$options[:revert] ) ||   # -H 
              (!$options[:edit] &&  $options[:history] &&  $options[:history_no] && !$options[:revert] ) ||   # -H -n
	      (!$options[:edit] && !$options[:history] && !$options[:history_no] &&  $options[:revert] ) )    # -R 

              puts $msg[0]
              puts opts
              exit(1)
        end


        case
            when $options[:edit]
                 # Edit conf file 
                 status, file_name = Conf_file.test_params
		 if status == 1
		    $stderr.puts $msg[1]
		    puts opts
		    exit(1)
		 end
		 if status == 2
		    $stderr.puts $msg[2]
		    puts opts
		    exit(1)
		 end

         	 if !File.readable?(file_name)
            	    $stderr.puts "Error : file "+file_name+" not found or unreadable"
            	    status = exit(1)
         	 end

        	 $config=Oar.load_configuration
		 editor, directory = Edit.env($config)

	         # edit file
		 rule = Rule.new(nil, nil)
		 rule.file_name = directory + "OAR_tmp_" + File.basename(file_name) 
		 rule.editor = editor
		 rule.context="file" 
                 rule.script = ""
                 File.open(file_name) do |file|
                      while line = file.gets
                            rule.script << line
                      end
                 end
		 file_content_before_update = rule.script
	         status, user_choice = rule.edit
	         exit(2) if status != 0
	         if status==0 && user_choice==0
		    repository = Repository.new
		    if !repository.active
		       repository.display_status 
		    else
		        repository.create
		    end	# if !repository.active

		    # update file
          	    begin
               	         f = File.open(file_name, "w")
               	         f.print rule.script
               	         f.close
               	         puts "Update file " + file_name 
               	         rescue Exception => e
                    	        $stderr.puts "Error while updating file "+file_name
                      	        $stderr.puts e.message
                      	        exit(2)
          	    end

		    if repository.active && repository.exists
		       repository.file_name = File.basename(file_name)
		       # First add in repository before update if file does not exist
		       if !repository.file_exist?
		           repository.file_content=file_content_before_update
		           if repository.write==0
		              repository.add
                              repository.log_commit = "Add file before update with oaradmin conf"
		    	      repository.silent_mode=true 
                              repository.commit
		    	      repository.silent_mode=false
		           end
		       end
		    
		       # Update in repository
                       repository.file_content=rule.script
                       if repository.write==0
                          repository.log_commit = "Update file "
                          repository.commit
                       end
		    end		# if repository.active
		 end	# if status==0 && user_choice==0

                
            when $options[:history]
		 # Show the changes made on the file 
                 status, file_name = Conf_file.test_params
		 if status != 0 
		    $stderr.puts $msg[1] if status==1
		    $stderr.puts $msg[2] if status==2
		    $stderr.puts $msg[3] if status==3
		    puts opts
		    exit(1)
		 end

		 revisions = Revisions.new(File.basename(file_name))
		 exit(3) if !revisions.active || !revisions.exists
   	         if $options[:history_no]
      	            (0..ARGV.length-1).each do |i|
          	        if ARGV[i] == "-n" || ARGV[i] == "--number" 
		           if i < ARGV.length-1 && ARGV[i+1].to_i > 0
             	              revisions.display_diff_changes = ARGV[i+1] 
			   else
		    	      $stderr.puts "The number of changes must be greater than zero"
		    	      exit(3)
			   end
          	        end
      	            end
		 end
		 status = revisions.display_diff
		 exit(3) if status != 0


            when $options[:revert]
		 # Revert to the file as it existed in a revision number 

		 status, file_name, rev = Conf_file.test_params2
		 if status != 0
		    puts $msg[4]
		    puts opts
		    exit(4) 
		 end
		 if rev.to_i == 0
		    puts $msg[5]
		    exit(4)
		 end

		 revisions = Revisions.new(File.basename(file_name))
		 exit(4) if !revisions.active || !revisions.exists
		 revisions.rev_id = rev.to_i
		 status = revisions.retrieve_file_rev
		 exit(4) if status != 0

		 # We have a content for the file 
		 # Test if the specified file in command line exists or not
		 # If exist, try to versioning it before overwrite
		 # It is not really necessary. Repository must have the older version of the file
		 # But file can be change without using oaradmin conf. So the latest revision in repository
		 # can be different from the file on disk
		 ask_overwrite = resp_overwrite = false
		 repository = Repository.new
		 if File.exists?(file_name)
		    if File.readable?(file_name)
		       str = ""
		       File.open(file_name) do |file|
			    while line = file.gets
				  str << line
			    end
		       end
		       repository.file_name = File.basename(file_name) 
		       repository.file_content=str
		       if repository.write==0
                          repository.log_commit = "Versioning file before overwrite it with --revert command"
                          repository.silent_mode=true
                          repository.commit
		       else
			  ask_overwrite = true
		       end
		    else
             	       $stderr.puts  "[OARADMIN ERROR]: file " + file_name + " is unreadable"
		       ask_overwrite = true
		    end
		 end	# if File.exists?(file_name)

		 if ask_overwrite
             	    puts  "[OARADMIN]: Warning ! Versioning of file " + file_name + " is impossible"
             	    puts  "[OARADMIN]: So, if you overwrite file, the current version will be lost"
		    print "[OARADMIN]: Overwrite [N/y] ? "
             	    r = ""
             	    begin
         	 	r = $stdin.gets.chomp
             	    end while ( r != "" && r != "N" && r != "y" )
	     	    resp_overwrite = r == "y" 
		 end
		 if (ask_overwrite && resp_overwrite) || !ask_overwrite
		    begin
		         f = File.open(file_name, "w")
		         f.print revisions.file_content
		         f.close
		         puts "Update file " + file_name
		         rescue Exception => e
			        $stderr.puts "Error while updating file "+file_name
			        $stderr.puts e.message
			        exit(4)
		    end

		    # Update repository	
		    repository.file_name = File.basename(file_name)
		    repository.file_content=revisions.file_content
		    if repository.write==0
		       repository.log_commit = "Update file"
		       repository.silent_mode=false
		       repository.commit
		    end
		 end 	# if (ask_overwrite && resp_overwrite) || !ask_overwrite
 
	end	# case



    when $subcommand_choice==8
	# #############
	# Display usage 
	# ############
	subcommand_usage


    when $subcommand_choice==9
	# ########################
	# Print OAR version number
	# ########################
	Oar.version_number


end






