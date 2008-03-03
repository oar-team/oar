#!/usr/bin/ruby  
# $Id: oarmgr.rb 1 2008-01-30 16:00:00Z ddepoisi $
# manage resources in oar database - add, update records in database 
#
# requirements:
# ruby1.8 (or greater)
# 
# To activate the verbose mode, add -w at the end of the first line. Ex : #!/usr/bin/ruby -w
#


require 'optparse'


$msg = []
$msg[0] = "Incoherence in specified options"


$cmd_user = []
$oar_cmd = ""

$list_resources_id=[]	 	# contains the list of resources to delete

# Options for parsing
$options = {}
$options[:add] = $options[:select] = $options[:property] = $options[:delete] = $options[:commit] = false
opts = OptionParser.new do |opts|
    opts.banner = "Usage: oarmgr [-a [-p]] [-s -p] [-d] [-c]"

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
       exit
    end


end




# Decompose the command given by user and store values in $cmd_user[]
def decompose_argv

    (0..ARGV.length-2).step(2) do |i|
        if ARGV[i] == "-a"
           ARGV[i+1].split('/').each do |item|
               if item.length > 0
		  decompose_param(item)
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
	   decompose_param(ARGV[i+1])
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
def decompose_param(str)

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
def decompose_list_values(str)

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

end 	# decompose_list_values




# Explore $cmd_user[] table and create oar commands - recursiv algorithm
def tree n, str
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
	  list_val = decompose_list_values($cmd_user[n-1][:property_nb])

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
def execute_command(str)

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
if !( ($options[:add] && !$options[:property] && !$options[:select] && !$options[:delete]) ||	# -a alone
      ($options[:add] && $options[:property] && !$options[:select] && !$options[:delete]) ||	# -a -p
      ($options[:select] && $options[:property] && !$options[:add] && !$options[:delete]) ||  	# -s -p
      (!$options[:select] && !$options[:property] && !$options[:add] && $options[:delete]) ) 	# -d alone

      puts $msg[0]
      exit(2)
end



# add resources
if $options[:add]

   $oar_cmd = "oarnodesetting -a "

   # Decompose ARGV[] in hash table $cmd_user
   decompose_argv

   tree 1, $oar_cmd

end 	# if $options[:add]




# update resources : -s and -p  
if $options[:select] && $options[:property]

   # Decompose ARGV[] in hash table $cmd_user
   decompose_argv
   
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
	    execute_command(str)

            i += 1
	    j += 1
	    if j > $cmd_user[0][:property_nb]
	       j = 1 
	       k += 1
	    end
	    
      end
   
   else
       	# We have a form param=host_a,host_b, host[10-20,30,35-50,70],host_c,host[80-120]
	list_val = decompose_list_values($cmd_user[0][:property_nb])

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
	    execute_command(str)
	    
	end

   end 		# if $cmd_user[0][:property_nb].is_a?(Fixnum)

end 	# if $options[:select] && $options[:property]




# delete resources
if $options[:delete]

   # Decompose ARGV[] in hash table $cmd_user
   decompose_argv

   if $cmd_user.length > 0
      # search properties matched condition
      # -d nodes=host[1-50] or -d cluster=zeus
      list_val = decompose_list_values($cmd_user[0][:property_nb])

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
       execute_command(str)
       str = "oarremoveresource " + r
       execute_command(str)
   end


end 	# if $options[:delete]









