#!/usr/bin/ruby  
# $Id: oaradmin.rb 1 2008-05-05 16:00:00 ddepoisi $
#
# oaradmin : utility to manage oar configuration 
#
# requirements:
# ruby1.8 (or greater)
# libdbi-ruby 
# libdbd-mysql-ruby or libdbd-pg-ruby
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
   exit(1)
end



#####################
# MAIN PROGRAM
#####################

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

case
    when $subcommand_choice==0 	
	# ################
	# Manage resources 
	# ################

        $msg[0] = "Incoherence or syntax error in specified options"

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
		       else
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

           Resources.tree 1, $oar_cmd

        end 	# if $options[:add]


        # update resources : -s and -p  
        if $options[:select] && $options[:property]

           # Decompose ARGV[] in hash table $cmd_user
           Resources.decompose_argv
   
           if $cmd_user[0][:property_nb].is_a?(Fixnum)
              # We have a form param={3} - Ex : core={2} nodes=mycluster{12}.local
              # Recover the max value of param 
              val_max = -1
              r = `oarnodes -a -Y`
              if $?.exitstatus == 0
		 r_hash = YAML::load(r)
                 if $cmd_user[0][:property_name] == "nodes"
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
              end	# if $?.exitstatus == 0

              i = j = k = 1
              i += $cmd_user[0][:offset]
              while i <= val_max && j+$cmd_user[0][:offset] <= val_max
	    
	            # First part of oar command
	            str = "oarnodesetting "

	            # Properties in the oar command
	            (1..$cmd_user.length-1).each do |n|
	    	        str += "-p " + $cmd_user[n][:property_name] + "="
		        if $cmd_user[n][:property_nb] =~ /%/
		           str = str + $`.to_s + k.to_s + $'.to_s
		        else
		           str += $cmd_user[n][:property_nb]
		        end
		        str += " "
	            end
	    
 	            # --sql clause in the oar command or -h hostname
	            v = i
	            v = sprintf("#{$cmd_user[0][:format_num]}", v) if $cmd_user[0][:format_num].length > 0 
	            v = v.to_s
	            if $cmd_user[0][:property_name] == "nodes"
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

                    i += 1
	            j += 1
	            if j > $cmd_user[0][:property_nb]
	               j = 1 
	               k += 1
	            end
	    
              end
   
           else
       	        # We have a form param=host_a,host_b, host[10-20,30,35-50,70],host_c,host[80-120]
	        list_val = Resources.decompose_list_values($cmd_user[0][:property_nb])

 	        list_val.each do |item|
	
	            # First part of oar command
	            str = "oarnodesetting "

	            # Properties in the oar command
	            (1..$cmd_user.length-1).each do |n|
	                str += "-p " + $cmd_user[n][:property_name] + "=" + $cmd_user[n][:property_nb] + " "
	            end
	    
	            # --sql clause in the oar command or -h hostname
	            if $cmd_user[0][:property_name] == "nodes"
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
	    
	        end

           end 		# if $cmd_user[0][:property_nb].is_a?(Fixnum)

        end 	# if $options[:select] && $options[:property]


        # delete resources
        if $options[:delete]

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
                 if $cmd_user[0][:property_name] == "nodes"
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
           $list_resources_id.each do |r|
               str = "oarnodesetting -r " + r + " -s Dead -n "
               Resources.execute_command(str)
               str = "oarremoveresource " + r
               Resources.execute_command(str)
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

        $script = ""

        # Options for parsing
        $options = {}
        $options[:list] = $options[:add] = $options[:file] = $options[:edit] = $options[:export] = $options[:delete] = false
        $options[:comment] = nil

        opts = OptionParser.new do |opts|
            opts.banner = "Usage: oaradmin rules [-l|-ll|-lll [no_rules]] [-a [no_rule] [-f file]] [-d no_rule [no_rules]] \n                      [-x [no_rules] [-f file]] [-e no_rule [-f file]] [-1 no_rule] [-0 no_rule]"

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

        if !( ( $options[:list] && !$options[:add] && !$options[:file] && !$options[:edit] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? ) ||   # -l 
              (!$options[:list] &&  $options[:add] && !$options[:file] && !$options[:edit] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? ) ||   # -a 
              (!$options[:list] &&  $options[:add] &&  $options[:file] && !$options[:edit] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? ) ||   # -a -f
              (!$options[:list] && !$options[:add] && !$options[:file] &&  $options[:edit] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? ) ||   # -e 
              (!$options[:list] && !$options[:add] &&  $options[:file] &&  $options[:edit] && !$options[:delete] && !$options[:export] &&  $options[:comment].nil? ) ||   # -e -f
              (!$options[:list] && !$options[:add] && !$options[:file] && !$options[:edit] &&  $options[:delete] && !$options[:export] &&  $options[:comment].nil? ) ||   # -d 
              (!$options[:list] && !$options[:add] && !$options[:file] && !$options[:edit] && !$options[:delete] &&  $options[:export] &&  $options[:comment].nil? ) ||   # -e  
              (!$options[:list] && !$options[:add] &&  $options[:file] && !$options[:edit] && !$options[:delete] &&  $options[:export] &&  $options[:comment].nil? ) ||   # -e -f
              (!$options[:list] && !$options[:add] && !$options[:file] && !$options[:edit] && !$options[:delete] && !$options[:export] && !$options[:comment].nil? )  )   # comment

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
	         no_rule = nil 
   	         list_rules = Admission_rules.rule_list_from_command_line
   	         if list_rules.length > 1
                    $stderr.puts $msg[4]
		    puts opts
                    exit(6)
   	         end
		 no_rule = list_rules[0].to_i if !list_rules.empty?
	         if no_rule && no_rule == 0 
	            $stderr.puts $msg[2]
	            exit(6)
	         end

	         if $options[:file]
   	            # add admission rule from a file 
   	            status, $script = Admission_rules.load_rule_from_file
	            exit(6) if status != 0
		    rule = Rule.new(dbh, no_rule)
		    rule.script = $script
		    status = rule.add
	            exit(6) if status != 0
	         else
   	            # add admission rule using a text editor 
	            file_name = directory + "OAR_tmp_" + filename_base
	            file_name += no_rule.to_s if no_rule
		    rule = Rule.new(dbh, no_rule)
		    rule.script = ""
		    rule.no_rule_must_exist = false
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
		 no_rule = list_rules[0].to_i
	         if no_rule == 0 
	            $stderr.puts $msg[2]
	            exit(7)
	         end
	         if $options[:file] 
   	            # update admission rule from a file 
	            status, $script = Admission_rules.load_rule_from_file
	            exit(7) if status != 0
		    rule = Rule.new(dbh, no_rule)
		    rule.script = $script
		    status = rule.update
	            exit(7) if status != 0
	         else
	            # edit admission rule using a text editor
	            file_name = directory + "OAR_tmp_" + filename_base
	            file_name += no_rule.to_s if no_rule
		    rule = Rule.new(dbh, no_rule)
		    rule.no_rule_must_exist = true
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
		    rules.export_file_name_with_no_rule=false
   	         else
		    rules.export_file_name=filename_base
		    rules.export_file_name_with_no_rule=true
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

        end

        # Disconnect from database
        dbh.disconnect if dbh



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






