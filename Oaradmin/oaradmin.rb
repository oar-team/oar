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
require 'oar_modules'
require 'oaradmin_modules'



$msg = []
$options= {} 		

$subcommand = []
$subcommand[0] = {:short_form=>"re", :long_form=>"resources", :description=>"manage resources in oar database"} 
$subcommand[1] = {:short_form=>"ru", :long_form=>"rules",     :description=>"manage admission rules"} 
$subcommand[9] = {:short_form=>"",   :long_form=>"help",      :description=>"display usage"} 


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

$msg[0] = "Incoherence in specified options"

$cmd_user = []
$oar_cmd = ""

$list_resources_id=[]	 	# contains the list of resources to delete

# Options for parsing
$options = {}
$options[:add] = $options[:select] = $options[:property] = $options[:delete] = $options[:commit] = false
opts = OptionParser.new do |opts|
    opts.banner = "Usage: oaradmin resources [-a [-p]] [-s -p] [-d] [-c]"

    # add resources
    opts.on("-a","--add","Add new resources") do 
       $options[:add] = true 
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
      ($options[:select] && $options[:property] && !$options[:add] && !$options[:delete]) ||  	# -s -p
      (!$options[:select] && !$options[:property] && !$options[:add] && $options[:delete]) ) 	# -d alone

      puts $msg[0]
      puts opts
      exit(1)
end


# add resources
if $options[:add]

   $oar_cmd = "oarnodesetting -a "

   # Decompose ARGV[] in hash table $cmd_user
   Resources.decompose_argv

   Resources.tree 1, $oar_cmd

end 	# if $options[:add]


# update resources : -s and -p  
if $options[:select] && $options[:property]

   # Decompose ARGV[] in hash table $cmd_user
   Resources.decompose_argv
   
   if $cmd_user[0][:property_nb].is_a?(Fixnum)
      # We have a form param={3} - Ex : core={2} nodes={12}
      # Recover the max value of param 
      val_max = -1
      r = `oarnodes -a`
      if $?.exitstatus == 0
         if $cmd_user[0][:property_name] == "nodes"
	    str = "network_address"
         else
	    str = $cmd_user[0][:property_name]
	 end
	 str = str + "=" + $cmd_user[0][:property_fixed_value]
	 r.each_line do |line|
	   if line =~ /#{str}/
              if $'=~ /\d+/
                 val_tmp = $&.to_s.to_i
                 suite=$'
	         if suite =~ /,/
	            suite = $`
	         end
	         if suite == $cmd_user[0][:property_fixed_value2] 
	               val_max = val_tmp if val_tmp > val_max
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
      r = `oarnodes -a`
      if $?.exitstatus == 0
         if $cmd_user[0][:property_name] == "nodes"
	    str = "network_address"
         else
	    str = $cmd_user[0][:property_name]
         end
         str += "=" 

         list_val.each do |v|
	    str2 = str + v
	    r.each_line do |line|
	      if line =~ /#{str2}/
	         str3 = $&
                 suite=$'
	         if suite =~ /,/
	            suite = $`
	         end
                 if (str3.split('=')[1] + suite) == v
  	            if line =~ Regexp.new('resource_id=\d+')
      	               $list_resources_id.push($&.to_s.split('=')[1])
      	            end
	         end
	      end 
	    end
         end
      end	# if $?.exitstatus == 0
   else
      # search all resources_id
      r = `oarnodes -a`
      if $?.exitstatus == 0
         r.each_line do |line|
  	   if line =~ Regexp.new('resource_id=\d+')
      	      $list_resources_id.push($&.to_s.split('=')[1])
      	   end
         end
      end 
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
$msg[2] = "Error access to the database"
$msg[4] = "Error : bad admission rule number"
$msg[5] = "Error : no admission rule number given"

$script = ""

# Options for parsing
$options = {}
$options[:list] = $options[:add] = $options[:file] = $options[:update] = $options[:export] = $options[:delete] = false
$options[:comment] = nil

opts = OptionParser.new do |opts|
    opts.banner = "Usage: oaradmin rules [-l|-ll|-lll] [-a [no_rule] [-f file]] [-u no_rule [-f file]] [-d no_rule [no_rule]]\n                      [-e [no_rule] [-f file]] [-c|--[no-]comment no_rule]"

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
      puts opts
      exit(1)
end

# Load configuration
$config=Oar.load_configuration
if $config.empty?
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
dbh = Bdd.connect($config)
exit(4) if dbh.nil?

rules = Rules.new(dbh) 

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
   	    Admission_rules.load_rule_from_file
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
	       Admission_rules.load_rule_from_file
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
   	 list_rules = Admission_rules.rule_list_from_command_line

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
   	 list_rules = Admission_rules.rule_list_from_command_line

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
   	 list_rules = Admission_rules.rule_list_from_command_line
   	 if list_rules.length == 0 || list_rules.length > 1
            puts $msg[0]
            exit(10)
   	 end

      	 status = rules.comment(list_rules, $options[:comment])
	 exit(10) if status != 0

end

# Disconnect from database
dbh.disconnect if dbh



    when $subcommand_choice==9
	# #############
	# Display usage 
	# ############
	subcommand_usage

end






