#!/usr/bin/ruby -w
# $Id$
# drawgantt.cgi displays gantt chart for oar resource management system 
#
# author: auguste@imag.fr
#
# requirements:
# ruby1.8 (or greater)
# libdbi-ruby
# libdbd-mysql-ruby or libdbd-pg-ruby
# libgd-ruby1.8
# libyaml-ruby
# 
#
# TODO:
# 	- transparencies for aggregation and timesharing
#		- debug postgresql case
#		- wizard for auto configuration ?
# 	- display state node information for status different of alive
# 	- sparkline chart for workload information sumarize?
#		- job/user highlighting (by apply some picture manipulation from general picture ?)
#		- fix quote problem javascript popup
#

require 'dbi'
require 'cgi'
require 'time'
require 'optparse'
require 'yaml'
require 'GD'
require 'pp'

MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
DAYS = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
RANGE_ORDER = ['1/6 day','1/2 day','1 day','3 days','week','month']
RANGE_SEC = {'1/6 day'=>14400,'1/2 day'=>43200,'1 day'=>86400,'3 days'=>259200,
		'week'=>604800,'month'=>2678400,'year'=>31622400}
RANGE_STEP = {'1/6 day'=>3600,'1/2 day'=>10800,'1 day'=>43200,'3 days'=>86400,
		'week'=>345600,'month'=>604800}

$verbose = false

$val = "" # variable for debug purpose

##########################################################################
# usefull method
#
def String.natural_order(regex=Regexp.new('(.*)'),nocase=false)
	proc do |str|
    i = true
		str =~ regex
		str = $1
    str = str.upcase if nocase
    str.gsub(/\s+/, '').split(/(\d+)/).map {|x| (i = !i) ? x.to_i : x}
  end
end

##########################################################################
# database operations
#
def base_connect
  db_type = $conf['DB_TYPE']
	if db_type == "mysql"
		db_type == "Mysql"
	end
	return DBI.connect("dbi:#{db_type}:#{$conf['DB_BASE_NAME']}:#{$conf['DB_HOSTNAME']}",
										 "#{$conf['DB_BASE_LOGIN_RO']}","#{$conf['DB_BASE_PASSWD_RO']}")
end

# list_resources
# gets the list of all resources 
# parameters : dbh
# return value : list of resources
# side effects : /
def list_resources(dbh)
	q = "SELECT * FROM resources"
	res = dbh.execute(q)
	resources = {}
	res.each do |r|
		resources[r[0]] = r.clone  
	end 
	res.finish
	return resources
end

# get all jobs in a range of date in furtur in the gantt from predictions_visu tables (= results from previous scheduling pass)
# args : dbh, start range, end range
def get_jobs_gantt_scheduled(dbh,date_begin,date_end)

	q = "SELECT jobs.job_id,jobs.job_type,jobs.state,jobs.job_user,jobs.command,jobs.queue_name,moldable_job_descriptions.moldable_walltime,jobs.properties,jobs.launching_directory,jobs.submission_time,gantt_jobs_predictions_visu.start_time,(gantt_jobs_predictions_visu.start_time + moldable_job_descriptions.moldable_walltime),gantt_jobs_resources_visu.resource_id, resources.network_address
         FROM jobs, moldable_job_descriptions, gantt_jobs_resources_visu, gantt_jobs_predictions_visu, resources
         WHERE
             gantt_jobs_predictions_visu.moldable_job_id = gantt_jobs_resources_visu.moldable_job_id AND
             gantt_jobs_predictions_visu.moldable_job_id = moldable_job_descriptions.moldable_id AND
             jobs.job_id = moldable_job_descriptions.moldable_job_id AND
             gantt_jobs_predictions_visu.start_time < #{date_end} AND
             resources.resource_id = gantt_jobs_resources_visu.resource_id AND
             gantt_jobs_predictions_visu.start_time + moldable_job_descriptions.moldable_walltime >= #{date_begin}
         ORDER BY jobs.job_id"
	res = dbh.execute(q)
	
	results = {}
	res.each do |r|
		if (results[r[0]] == nil)
			results[r[0]] = {
     	                 'job_type' => r[1],
        	               'state' => r[2],
          	             'user' => r[3],
            	           'command' => r[4],
              	         'queue_name' => r[5],
                	       'walltime' => r[6],
                  	     'properties' => r[7],
                    	   'launching_directory' => r[8],
              	         'submission_time' => r[9],
                	       'start_time' => r[10],
                  	     'stop_time' => r[11],
                    	   'resources' => [ r[12] ],
                    	   'network_addresses' => [ r[13] ]
                      	}
		else
			results[r[0]]['resources'].push(r[12]) #add resources at already existing job
		end
	end 
	res.finish
	return results
end

# get all jobs in a range of date (from past to now)
# args : dbh, start range, end range
def get_jobs_range_dates(dbh,date_begin,date_end)
	q = "SELECT jobs.job_id,jobs.job_type,jobs.state,jobs.job_user,jobs.command,jobs.queue_name,moldable_job_descriptions.moldable_walltime,jobs.properties,jobs.launching_directory,jobs.submission_time,jobs.start_time,jobs.stop_time,assigned_resources.resource_id,resources.network_address,(jobs.start_time + moldable_job_descriptions.moldable_walltime)
         FROM jobs, assigned_resources, moldable_job_descriptions, resources
         WHERE
             (   
                 jobs.stop_time >= #{date_begin} OR
                 (   
                     jobs.stop_time = '0' AND
                     (jobs.state = 'Running' OR
                      jobs.state = 'Suspended' OR
                      jobs.state = 'Resuming')
                 )
             ) AND
             jobs.start_time < #{date_end} AND
             jobs.assigned_moldable_job = assigned_resources.moldable_job_id AND
             moldable_job_descriptions.moldable_job_id = jobs.job_id AND
             resources.resource_id = assigned_resources.resource_id
         ORDER BY jobs.job_id"

	res = dbh.execute(q)
	
	results = {}
	res.each do |r|
		if (results[r[0]] == nil) 
				results[r[0]] = {
                         'job_type' => r[1],
                         'state' => r[2],
                         'user' => r[3],
                         'command' => r[4],
                         'queue_name' => r[5],
                         'walltime' => r[6],
                         'properties' => r[7],
                         'launching_directory' => r[8],
                         'submission_time' => r[9],
                         'start_time' => r[10],
                         'stop_time' => r[11],
                         'resources' => [ r[12] ],
                         'limit_stop_time' => r[14]
                         }
		else
			results[r[0]]['resources'].push(r[12]) #add resources at already existing job
		end
	end 
	res.finish
	return results
end


# Return date of the gantt for visu
def get_gantt_visu_date(dbh)
	q= "SELECT start_time FROM gantt_jobs_predictions_visu 
			WHERE moldable_job_id = 0"
	res = dbh.execute(q)
	r = res.fetch_array
	
	return r[0]
end

#get the range when nodes are dead between two dates
# arg : dbh, start date, end date
def get_resource_dead_range_date(dbh,date_begin,date_end)
	q = "SELECT resource_id, date_start, date_stop, value
               FROM resource_logs
               WHERE
                   attribute = 'state' AND
                   (
                       value = 'Absent' OR
                       value = 'Dead' OR
                       value = 'Suspected'
                   ) AND
                   date_start <= #{date_end} AND
                   (
                       date_stop = 0 OR
                       date_stop >= #{date_begin}
                   )"
	res = dbh.execute(q)
	
	results = {}
	res.each do |r|
		interval_stopDate = r[2]
		if (interval_stopDate == nil)
      interval_stopDate = date_end;
    end
		results[r[0]]=[]	if (results[r[0]]==nil)
  	results[r[0]].push([r[1],interval_stopDate,r[3]])
	end
	res.finish
	return results
end

# list property fields of the resource_properties table
# args : db ref
def list_resource_properties_fields(dbh)
	db_type = $conf['DB_TYPE']
 	if (db_type == "Pg")
		q = "SELECT pg_attribute.attname AS field
         FROM pg_class, pg_attribute
         WHERE
         	pg_class.relname = \'resources\'
          and pg_attribute.attnum > 0
          and pg_attribute.attrelid = pg_class.oid"
	else
		q = "SHOW COLUMNS FROM resources"
	end	

	res = dbh.execute(q)
	results = []
	res.each do |r|
		results << r.first
	end
  return results 
end

# get_job_types
# return a hash table with all types for the given job ID

def get_job_types(dbh,job_id)
    q = "SELECT type FROM job_types WHERE job_id = #{job_id}"
		result = []               
    res = dbh.execute(q)
		res.each do |r|
			result << r[0] 
		end
    res.finish
    return result
end


#
# Methods adapted from oarstat and iolib
#
def get_history(dbh,date_start,date_stop)
	resources = list_resources(dbh)
	job_gantt =  get_jobs_gantt_scheduled(dbh,date_start,date_stop)

	#print finished or running jobs
	jobs = job_gantt

	if $conf['cosystem']
		jobs.each do  |job_id,job|
			job['cosystem'] = true if get_job_types(dbh,job_id).include?("cosystem")
		end
	end

	jobs_history =  get_jobs_range_dates(dbh,date_start,date_stop)

	jobs_history.each do |job_id,job|
		a_type = get_job_types(dbh,job_id)
		jobs_history[job_id]['cosystem'] = true if a_type.include?('cosystem')
		if (job_gantt[job_id] == nil) || (a_type.include?("besteffort"))
    	if (jobs_history[job_id]['state'] == "Running") ||
				 (jobs_history[job_id]['state'] == "toLaunch") ||
				 (jobs_history[job_id]['state'] == "Suspended") ||
			   (jobs_history[job_id]['state'] == "Resuming") ||
				 (jobs_history[job_id]['state'] == "Launching")
				if a_type.include?("besteffort")
        	jobs_history[job_id]['stop_time'] = get_gantt_visu_date(dbh);
        else
          #This job must be already  printed by gantt
          next
        end
      end
      jobs[job_id] = jobs_history[job_id];
		end
	end

	#print Down or Suspected resources
	dead_resources = get_resource_dead_range_date(dbh,date_start,date_stop)
	#p dead_resources
	return resources,jobs,dead_resources
end

# get_date
# returns the current time in the format used by the sql database
# parameters : database
# return value : date string
# side effects : /
def get_date(dbh)
	db_type = $conf['DB_TYPE']
 	if (db_type == "Pg")
		q = "select EXTRACT(EPOCH FROM current_timestamp)";
	else
		q = "SELECT UNIX_TIMESTAMP()";
	end
	res = dbh.execute(q)
	r = res.fetch_array
	return r[0]
end




def draw_string(img,x,y,label)
	 img.string(GD::Font::SmallFont, x - (7 * label.length) / 2, y, label, $gridcolor)
end

def draw_resource_hierarchy(img)

	deltay = ($sizey-(2*$offsetgridy))/$sorted_resources.length.to_f
	
	x0 = $x_per_prop * $prop_hierarchy.length + 2

	x1 = -x0 + $left_offsetgridx
	x2 = x1 + $x_per_prop * $prop_hierarchy.length
	y = $sizey - $offsetgridy

	img.filledRectangle(x1,$offsetgridy, x2, y, $orange)

	img.line(x1, y, x2, y,  $gridcolor)

	(0..$prop_hierarchy.length ).each do |i|
		x =  -x0 + $left_offsetgridx + $x_per_prop * i
		img.line(x, $offsetgridy, x,  $sizey - $offsetgridy, $gridcolor)
	end

	$prop_hierarchy.each_with_index do |prop,p_index|

		prev_r_index = -1

		$sorted_resources.each_with_index do |resource, r_index|
			label = $resources[resource][$resource_properties_fields.index(prop)]
			if (r_index+1 < $sorted_resources.length)
				next_label = $resources[$sorted_resources[r_index+1]][$resource_properties_fields.index(prop)]
			else 
				next_label = nil
			end				

			if (label != next_label) 
				x1 = -x0 + $left_offsetgridx + $x_per_prop * p_index
				y1 = $offsetgridy + deltay * (prev_r_index +1 )
				x2 = x1 + $x_per_prop
				y2 = $offsetgridy + deltay * (r_index + 1)

				if p_index == 0
						img.line(x1, y1, $sizex - $right_offsetgridx , y1, $blue);  
				else
 					img.line(x1, y1, x2, y1, $gridcolor);   
#				img.filledRectangle(x1, y1, x2, y2, $color_gray[( ( (3 * r_index) % 15) + 16 * p_index) % 31 ])
				end
				str_resource = ""

				0.upto(p_index-1) do |i|
					plabel = $prop_hierarchy[i]
					plabel = 'host' if plabel == 'network_address'  
					str_resource << plabel + "/"
				end

				plabel = prop
				plabel = 'host' if plabel == 'network_address' 
				str_resource <<  plabel + ':<br>' 

				0.upto(p_index-1) {|i| str_resource << ($resources[resource][$resource_properties_fields.index($prop_hierarchy[i])]).to_s+"/" } 
				str_resource << label.to_s

				$map_prop_hierarchy << [x1, y1, x2, y2, str_resource]
				
				prev_r_index = r_index
			end

		end
	end

end

def draw_grid(img,resource_labels,origin,origin_label,range)

	if (range == 'month')
		(0..31).each do |i|
			day = Time.at(origin).strftime("%e")
			origin = origin + RANGE_SEC['1 day']
			x = $left_offsetgridx + i * (($sizex - $sum_offsetgridx) / 31.0)
			draw_string(img, x ,$offsetgridy / 2, day)
			img.line(x,$offsetgridy ,x, $sizey - $offsetgridy , $gridcolor)
		end
	elsif (range == 'week')
		(0..14).each do |i|
			x = $left_offsetgridx + i * (($sizex - $sum_offsetgridx) / 14.0)
	    if ((i & 1) == 1)
				draw_string(img, x ,$offsetgridy / 2, "12h")
	    else
				draw_string(img, x ,$offsetgridy / 2, origin_label)
				origin_label = DAYS[ (DAYS.index(origin_label) + 1) % 7]
	    end
				img.line(x,$offsetgridy ,x, $sizey - $offsetgridy , $gridcolor)
		end
	elsif (range == '3 days')
		(0..6).each do |i|
			x = $left_offsetgridx + i * (($sizex - $sum_offsetgridx) / 6.0)
	    if ((i & 1) == 1)
				draw_string(img,x ,$offsetgridy / 2, "12h")
	    else
				draw_string(img, x ,$offsetgridy / 2, origin_label)
				origin_label = DAYS[ (DAYS.index(origin_label) + 1) % 7]
	    end
				img.line(x,$offsetgridy ,x, $sizey - $offsetgridy , $gridcolor)
		end
	elsif (range == '1 day')
		(0..24).each do |i|
	    x = $left_offsetgridx + i * (($sizex - $sum_offsetgridx) / 24.0)
	    hour = (i + origin_label.to_i) % 24
	    draw_string(img, x ,$offsetgridy / 2, "#{hour.to_s}h")
			img.line(x, $offsetgridy, x, $sizey - $offsetgridy, $gridcolor)
		end	
	elsif (range == '1/2 day')
		(0..12).each do |i|
	    hour = (i + origin_label.to_i) % 24
	    x = $left_offsetgridx + i * (($sizex - $sum_offsetgridx) / 12.0)
	    draw_string(img, x ,$offsetgridy / 2, "#{hour.to_s}h")
	    img.line(x, $offsetgridy, x, $sizey - $offsetgridy, $gridcolor)
		end
	elsif (range == '1/6 day')
		(0..8).each do |i|
	    hour = (i/2 + origin_label.to_i) % 24
	    if ((i % 2) == 1)
				min = "30"
			else
				min = "00"
			end
	    x = $left_offsetgridx + i * (($sizex - $sum_offsetgridx) / 8.0)
	    draw_string(img, x, $offsetgridy / 2, "#{hour}:#{min}")
	    img.line(x, $offsetgridy, x, $sizey - $offsetgridy, $gridcolor);   
		end
	else
		puts "Range doesn't exit"
		exit 1
	end
	deltay = ($sizey-(2*$offsetgridy))/resource_labels.length.to_f 

	i=0
	resource_labels.each do |label|
		if ((i % $conf['tics_node'].to_i)==0) 
			y = $offsetgridy + i * deltay
			draw_string(img, $left_offsetgridx / 2, y , label)
			img.line($left_offsetgridx - 1 , y, $sizex - $right_offsetgridx, y, $gridcolor)
		end
		i = i + 1
	end
  img.line($left_offsetgridx - 1, $sizey - $offsetgridy, $sizex - $right_offsetgridx, $sizey - $offsetgridy, $gridcolor)

end

def draw_nowline(img,origin,range,color)
	now_x =  $left_offsetgridx + (Time.now.to_i-origin) * (($sizex - $sum_offsetgridx) / RANGE_SEC[range].to_f)
	if ((now_x > $left_offsetgridx ) && (now_x < ($sizex - $right_offsetgridx - 1)))
		img.line(now_x,(3*$offsetgridy/4) ,now_x, $sizey - (3*$offsetgridy)/4 , color);
		img.line(now_x+1,(3*$offsetgridy)/4 ,now_x+1, $sizey - (3*$offsetgridy)/4 , color);
	end
	return 
end

def build_image(origin, year, month, wday, day, hour, range, file_img, file_map)

	dbh = $dbh
	#resources, jobs, dead_resources = get_history(dbh,1155041223,1155047311)
	$resources, jobs, dead_resources = get_history(dbh,origin,origin+RANGE_SEC[range])
	dbh.disconnect

	p jobs if $verbose

	$sizey =  $resources.length * $points_per_cpu + 2 * $offsetgridy ;

	img = GD::Image.new($sizex ,$sizey )

	# allocate some colors

	

	$background =  img.colorAllocate($conf['background'])
	$gridcolor =  img.colorAllocate($conf['gridcolor'])

	$cosystem_color =  img.colorAllocate($conf['cosystem_color']) if !$conf['cosystem_color'].nil?

	$white = img.colorAllocate(255,255,255)
	$black = img.colorAllocate(0,0,0)       
	$red = img.colorAllocate(255,0,0)      
	$blue = img.colorAllocate(0,0,255)
	$orange = img.colorAllocate(0xFF,0x99,0x33)
	
	$state_color = Hash.new($red)
	$state_color['Dead'] =  $red
	$state_color['Suspected'] =  img.colorAllocate(0xFF,0x7B,0x7B)
	$state_color['Absent'] =  img.colorAllocate(0xC2,0x22,0x00)

	$color=[]
	$color[0] = $white
	(1..155).each {|i| $color[i] = img.colorAllocate((i%9) * 25, i ,(50 * i) % 255 )} 

	# make the background transparent 
	#img.transparent(white)

	#sort resources
	typed_resources = {}
	$resources.each do |r_id,r|
		typed_resources[r[1]]= Hash.new() if (typed_resources[r[1]]==nil)
		typed_resources[r[1]][r_id] = r
	end
#		p typed_resources

	#
	# resources sorting and labelling
	#

	resource_labels = []

	# get conf values for sorting and labelling
	sort_label_conf = $conf["sort_label_conf"]

	# get ressource propertie field from db
	$resource_properties_fields = list_resource_properties_fields(base_connect)

	sort_label_conf.each do |sort_label_cf|
		
		type =  sort_label_cf["type"]
		type = "default" if type == nil
		first_field_property = sort_label_cf["first_field_property"]
		first_displaying_regex = Regexp.new(sort_label_cf["first_displaying_regex"])
		first_sorting_order = sort_label_cf["first_sorting_order"]
		first_sorting_regex = Regexp.new(sort_label_cf["first_sorting_regex"])
		separator = sort_label_cf["separator"]
		second_field_property = sort_label_cf["second_field_property"]
		second_displaying_regex =  Regexp.new(sort_label_cf["second_displaying_regex"])
		second_sorting_order = sort_label_cf["second_sorting_order"]
		second_sorting_regex = Regexp.new(sort_label_cf["second_sorting_regex"])

  	first_field_index = $resource_properties_fields.index(first_field_property)
		second_field_index = $resource_properties_fields.index(second_field_property)

		# group resources by first label
		first_label_groups={}
		if typed_resources[type] != nil
			typed_resources[type].each do |res_id,res_desc|
				label = res_desc[first_field_index]
				#puts label
				if first_label_groups[label] == nil  
					first_label_groups[label] = Hash.new()
					key = $resources[res_id][second_field_index].to_s
					first_label_groups[label][key]  = res_id
				else
		 			key = $resources[res_id][second_field_index].to_s
					first_label_groups[label][key]  = res_id
				end
			end
		end
		#sort first label
		sorted_first_label = []
		if (first_sorting_order == "string")
			sorted_first_label =  first_label_groups.keys.sort_by{|label| label =~ first_sorting_regex; $1.to_s} 
		elsif (first_sorting_order == "numerical") #numerical sorting order
			sorted_first_label =  first_label_groups.keys.sort_by{|label| label=~ first_sorting_regex; $1.to_i} 
		else #natural sorting order
				sorted_first_label =  first_label_groups.keys.sort_by(&String.natural_order(first_sorting_regex))
		end

		#p sorted_first_label
  	#puts "sorted_label"
		#p sorted_label

		sorted_typed_resources = []

		#sorting each group by second label
		sorted_first_label.each do |first_label|

			second_label_sorted = []
			if (second_sorting_order == "string")
				second_label_sorted = first_label_groups[first_label].keys.sort_by {|label| label =~ second_sorting_regex; $1.to_s}
			elsif (second_sorting_order == "numerical") #numerical sorting order
				second_label_sorted	= first_label_groups[first_label].keys.sort_by {|label| label =~ second_sorting_regex; $1.to_i}
			else #natural sorting order
				second_label_sorted	= first_label_groups[first_label].keys.sort_by(&String.natural_order(second_sorting_regex))
			end

			second_label_sorted.each do |label|
				sorted_typed_resources <<	first_label_groups[first_label][label]
			end
		end

		$sorted_resources = $sorted_resources + sorted_typed_resources 
 	#puts "sorted_resources"
	#p $sorted_resources

		# resources labelling

		sorted_typed_resources.each do |r|
			$resources[r][first_field_index] =~ first_displaying_regex

			displayed_label = $1					
			displayed_label = "" if ($1==nil)

			if (separator != nil)
				 displayed_label = displayed_label + separator 
			end

			if (second_field_index != nil)
				$resources[r][second_field_index].to_s =~ second_displaying_regex
				displayed_label = displayed_label + $1
			end
		
			resource_labels << displayed_label
		end
	end
	#p resource_labels

	deltay = ($sizey-(2*$offsetgridy))/$sorted_resources.length.to_f 
	
	origin_label = ""
	if ( (range == '3 days') || (range == 'week'))
		origin_label = wday 
	elsif ( (range == '1/2 day') || (range == '1/6 day') || (range == '1 day'))
		origin_label = hour
	else #month
		origin_label = day
	end

	draw_grid(img,resource_labels,origin,origin_label,range)

  draw_resource_hierarchy(img)


	scale = ($sizex - $sum_offsetgridx).to_f  / (RANGE_SEC[range].to_f) ;

	
	map_info = [] 
	jobs.each do |job_id,j|

 		start_x = ((j['start_time'].to_i  - origin).to_f * scale.to_f).to_i;
    start_x = 1 if (start_x < 1) 

		stop_x = ((j['stop_time'].to_i  - origin).to_f * scale.to_f).to_i;
	 	stop_x = $sizex - $sum_offsetgridx - 1 if (stop_x > ($sizex - $sum_offsetgridx - 1))
    
    start_x = start_x + $left_offsetgridx
    stop_x = stop_x + $left_offsetgridx

		ares_index = []
		j['resources'].each do |r|
			r_index = $sorted_resources.index(r)
			if !(r_index.nil?)
				ares_index << r_index
				if j['cosystem']
					color = $cosystem_color	
				else
					color = $color[(job_id.to_i % 154) + 1]
				end
				img.filledRectangle(start_x,$offsetgridy + deltay * r_index,stop_x,$offsetgridy + deltay * (r_index+1), color)
#			yop = "*#{start_x} #{$offsetgridy + deltay * r_index} #{stop_x} #{$offsetgridy + deltay * (r_index+1)}*"
			end
		end
		#display job_id
		if (ares_index.length > $nb_cont_res && (stop_x - start_x)  > $sizex / $xratio)
			sorted_index = ares_index.sort

			i_low =  sorted_index.first
			i_high =  sorted_index.first

			sorted_index.each do |r|
				if (r != i_high) 
					if (r > i_high + 1 )
						if (i_high -i_low) >= $nb_cont_res
							draw_string(img,(stop_x+start_x)/2,$offsetgridy+deltay*(i_high+i_low+1)/2-5,job_id.to_s) if !j['cosystem']
							map_info << [start_x,$offsetgridy+deltay*i_low,stop_x,$offsetgridy+deltay*(i_high+1),job_id]	
						end
						i_low = r
						i_high = r
					else
						i_high = i_high + 1
					end
				end
			end

			if (i_high -i_low) >= $nb_cont_res
				draw_string(img,(stop_x+start_x)/2,$offsetgridy+deltay*(i_high+i_low+1)/2.0-5,job_id.to_s)  if !j['cosystem']
				map_info << [start_x,$offsetgridy+deltay*i_low,stop_x,$offsetgridy+deltay*(i_high+1),job_id]	
			end
		end 
	end

	dead_map = ""
	dead_resources.each do |resource,dead_period|
		dead_period.each do |a|

			start_time,stop_time,value = a

			start_x = ((start_time.to_i - origin).to_f * scale.to_f).to_i;
    	start_x = 1	if (start_x < 1) 
			
			stop_x = ((stop_time.to_i - origin).to_f * scale.to_f).to_i;
			stop_x = $sizex - $sum_offsetgridx - 1 if ( (stop_x > ($sizex - $sum_offsetgridx - 1)) || (stop_x < 0) )

	    start_x = start_x + $left_offsetgridx
  	  stop_x = stop_x + $left_offsetgridx

			r_index = $sorted_resources.index(resource)
			
			if !r_index.nil?
				x1 = start_x
				x2 = stop_x
				y1 = $offsetgridy + deltay * r_index
				y2 = $offsetgridy + deltay * (r_index+1)
				
				img.filledRectangle(x1,y1,x2,y2, $state_color[value])
				dead_map << '<area shape="rect" coords="' + "#{x1},#{y1},#{x2},#{y2}" +
					'" onmouseout="return nd()" onmouseover="return overlib(\'' +
					"Resource Id: #{resource}" +
					"<br>Host: #{$resources[resource][$resource_properties_fields.index('network_address')]}" + 
					"<br>State: #{value}" +
				'\')" >'
			end

		end
	end
	
	#draw_nowline
	draw_nowline(img,origin,range,$red)

	f_img = File::new("#{$conf['web_root']}/#{$conf['directory']}/#{$conf['web_cache_directory']}/#{file_img}", 'w')
	img.png(f_img)
	f_img.close

	f_map = File::new("#{$conf['web_root']}/#{$conf['directory']}/#{$conf['web_cache_directory']}/#{file_map}", 'w')
	f_map.puts  '<map name="' + $prefix + '_ganttmap">'
	map_info.each do |info|
		j = jobs[info[4]]
		if j['cosystem']
			cosystem = "<br>Job Cosystem"
		else
			cosystem = ''
		end
		f_map.puts '<area shape="rect" coords="' + 
					 "#{info[0]},#{info[1]},#{info[2]},#{info[3]}" + 
					 '" href="monika.cgi?job='+ "#{info[4]}" +
					 '" onmouseout="return nd()" onmouseover="return overlib(\'' +
					 "JobId: #{info[4]}" +
					 cosystem +
					 "<br>User: #{j['user']}" + 
					 "<br>Type: #{j['job_type']}" +
					 "<br>State: #{j['state']}" +
#					 "<br>Command: #{j['command']}" +   TODO: fix quote problem
					 "<br>Queue: #{j['queue_name']}" + 
					 "<br>Nb resources: #{j['resources'].length}" +
					 "<br>Submission: #{Time.at(j['submission_time'].to_i).strftime("%a %b %e %H:%M %Y")}" +
					 "<br>Start: #{Time.at(j['start_time'].to_i).strftime("%a %b %e %H:%M %Y")}" +
					 "<br>End: #{Time.at(j['stop_time'].to_i).strftime("%a %b %e %H:%M %Y")}" +
					 '\')" >'
	end

	$map_prop_hierarchy.each do |info|
		f_map.puts '<area shape="rect" coords="' + 
					 "#{info[0]},#{info[1]},#{info[2]},#{info[3]}" + 
					 '" onmouseout="return nd()" onmouseover="return overlib(\'' +
					 "#{info[4]}" +
					 '\')" >'
	end

	f_map.puts dead_map

	f_map.puts '</map>'
	f_map.close

	return 
end

##################################

def cgi_html(cgi)

	popup_hour = ["00:00","01:00","02:00","03:00","04:00","05:00","06:00","07:00","08:00","09:00","10:00","11:00","12:00","13:00","14:00","15:00","16:00","17:00","18:00","19:00","20:00","21:00","22:00","23:00"]
	popup_day = ["1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","23","24","25","26","27","28","29","30","31"]
	popup_month = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct', 'Nov','Dec']
	popup_year = []
	popup_range = RANGE_ORDER

#	cgi = CGI.new("html3") # add HTML generation methods

#	now = Time.now
	now = Time.at(get_date($dbh))
	range = $conf['default_range']
	month, day, hour, year = now.strftime("%b %e %H:00 %Y").split(" ")
	popup_year = [(year.to_i-1).to_s, year, (year.to_i+1).to_s ]

	origin = 0

	if (cgi.params['day'].length>0)
		hour = cgi.params['hour'].to_s
		day	= cgi.params['day'].to_s
		month = cgi.params['month'].to_s
		year = cgi.params['year'].to_s
		range = cgi.params['range'].to_s
		origin =  Time.local(year,month,day,hour).to_i
	else
		range = $conf['default_range']
		origin = now.to_i-RANGE_SEC[range]/2
	end	

	#
	# zoom +-, left,rigth, default ?
	#
	if (cgi.params['plus.x'].length>0)
		if (range != RANGE_ORDER.first)
			next_range = RANGE_ORDER[RANGE_ORDER.index(range) - 1]
			origin = origin + (RANGE_SEC[range] - RANGE_SEC[next_range]) / 2
			range = next_range  
		end
	end

	if (cgi.params['minus.x'].length>0)
		if (range != RANGE_ORDER.last)
			next_range = RANGE_ORDER[RANGE_ORDER.index(range) + 1]
			origin = origin + (RANGE_SEC[range] - RANGE_SEC[next_range]) / 2
			range = next_range  
		end
	end

	if (cgi.params['left.x'].length>0)
		origin = origin - RANGE_STEP[range]
	end

	if (cgi.params['right.x'].length>0)
		origin = origin + RANGE_STEP[range]
	end

	if (cgi.params['action'].to_s == 'Default')
		range = $conf['default_range']
		origin = now.to_i-RANGE_SEC[range]/2
	end

	if (range == '3 days') || (range == 'week') || (range == 'month')
		origin = origin - origin % 86400 - Time.at(origin).gmt_offset + 86400
	else
 		origin = origin - origin % 3600
	end
	
	wday, month, day, hour, year = Time.at(origin).strftime("%a %b %e %H:00 %Y").split(" ")
	
	#
	#set displaying params
	#
	popup_year[popup_year.index(year)]= [year,true]
	popup_month[popup_month.index(month)]= [month,true]
	popup_day[popup_day.index(day)]= [day,true]
	popup_hour[popup_hour.index(hour)]= [hour,true]
	popup_range[popup_range.index(range)]= [range,true]

	#
	#image and map files naming
	#
	file_range = range
	file_range = '1_day' if (range =='1 day') 
	file_range = '1_2_day' if (range =='1/2 day') 
	file_range = '1_6_day' if (range == '1/6 day') 

	file_img =  $prefix+ '_gantt_' + year + '_' + month + '_' + day + '_' + hour + '_' + file_range
	file_map =  $prefix+ '_map_' + year + '_' + month + '_' + day + '_' + hour + '_' + file_range

	#test if it's on old file ?
	if (origin + RANGE_SEC[range] > now.to_i)
   	file_img = file_img + '_' + now.to_i.to_s + '.png';
    file_map = file_map + '_' + now.to_i.to_s + '.map';
	else
    file_img = file_img + '.png';
    file_map = file_map + '.map';
	end

	#
	#cache flushing according to nb_file_cache_limit
	#
	path_file = "#{$conf['web_root']}/#{$conf['directory']}/#{$conf['web_cache_directory']}/"
	file_list = Dir.glob("#{path_file}*.{png,map}")

	#puts file_list.length 
	if (file_list.length > $conf['nb_file_cache_limit']) 
		file_time = {}
		file_list.each do |file|
			file_time[file] = File.atime(file).to_i  
		end
		file_time_sorted = file_time.sort{|a,b| a[1]<=>b[1]}
		#puts file_time_sorted.length/2
		file_time_sorted[0..file_time_sorted.length/2].each do |f| 
			begin
				File.delete(f.first)
			rescue
				$stderr.print "Can't flush file: " + $! if $verbose
			end
		end
	end

	#build image file
	build_image(origin, year, month, wday, day, hour, range, file_img, file_map) if !File.exist?(path_file+file_img)
	
	map = ""
	path_file_map = "#{$conf['web_root']}/#{$conf['directory']}/#{$conf['web_cache_directory']}/#{file_map}"

	File.open(path_file_map) do |file|
		while line = file.gets
			map << line
		end
	end

	#$stderr.print ">>>>#{cgi.params['mode'].class}"

	if (cgi.params['mode'].to_s=='image_map_only')
			f_img = file_img
			f_map = file_map
		if cgi.params['path'].to_s != "no"
			f_img = "/#{$conf['directory']}/#{$conf['web_cache_directory']}/#{file_img}"
			f_map = "/#{$conf['directory']}/#{$conf['web_cache_directory']}/#{file_map}"
		end
		cgi.out("text/plain") { "#{f_img}" + "\n" + "#{f_map}" }
	else
	  cgi.out {
		  cgi.html {
			  cgi.head { "\n"+cgi.title{$title} } +			
			  cgi.body { "\n"+
#				  "##### #{$val} #####" +
				  cgi.form("get"){
#					  "**#{cgi.params}**\n" +
#					  $title +
					  cgi.h3 { $title } + "\n"+
					  # Javascript stuff thanks to NCSA TITAN cluster's page    
					  CGI.escapeElement('<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>') + "\n" +
					  CGI.escapeElement('<script src="/'+"#{$conf['directory']}"+
						  								'/js/overlib.js" language="JavaScript"></script>') + "\n" +
					  CGI.escapeElement("<em> Origin </em>") +
					  cgi.popup_menu("NAME" => "year", "VALUES" => popup_year) +
					  cgi.popup_menu("NAME" => "month", "VALUES" => popup_month) +
					  cgi.popup_menu("NAME" => "day", "VALUES" => popup_day) +
						cgi.popup_menu("NAME" => "hour", "VALUES" => popup_hour) +	
						CGI.escapeElement("<em> Range </em>") +
						cgi.popup_menu("NAME" => "range", "VALUES" => popup_range) +
						cgi.submit("Draw","action") +
						cgi.submit("Default","action") +
						cgi.image_button("/#{$conf['directory']}/#{$conf['web_icons_directory']}/gorilla-left.png", "left", "left") +
						cgi.image_button("/#{$conf['directory']}/#{$conf['web_icons_directory']}/gorilla-right.png", "right", "right") +
						cgi.image_button("/#{$conf['directory']}/#{$conf['web_icons_directory']}/gorilla-minus.png", "minus", "minus") +
						cgi.image_button("/#{$conf['directory']}/#{$conf['web_icons_directory']}/gorilla-plus.png", "plus", "plus") +
						cgi.br + "\n" +
						CGI.escapeElement(map) + "\n" +
						CGI.escapeElement('<div style="text-align: center">') +
#						cgi.img("/#{$conf['directory']}/#{$conf['web_cache_directory']}/yop.png", "gantt image","" ) +
						cgi.img("SRC" => "/#{$conf['directory']}/#{$conf['web_cache_directory']}/#{file_img}",
										"ALT" => "gantt image", "USEMAP" => "#" + $prefix +"_ganttmap" ) +
						CGI.escapeElement('</div>'); 
					}
				}
			}
		}
	end 
end
#################################################################################################################
### main
#################################################################################################################

cgi = CGI.new("html3") # add HTML generation methods

configfile = '/etc/oar/drawgantt.conf'
configfile = cgi.params['configfile'].to_s if (cgi.params['configfile'].length>0)
$prefix= ""
$prefix= cgi.params['prefix'].to_s if (cgi.params['prefix'].length>0)

puts "### Reading configuration file..." if $verbose

$conf = YAML::load(IO::read(configfile))

if cgi['conf'].length > 0
	conf = YAML::load(cgi['conf'])
	#override configuration parameters with received ones
	conf.each do |key,value|
		$conf.delete(key) if $conf[key]
	 	$conf[key] = value
	end
end

$title = $conf['title'] || 'Gantt Chart' 
$sizex = $conf['sizex']
#$sizey = $conf['sizey']
$offsetgridy = $conf['offsetgridy']
$left_offsetgridx = $conf['left_offsetgridx']
$right_offsetgridx = $conf['right_offsetgridx']
$sum_offsetgridx = $left_offsetgridx + $right_offsetgridx

$tics_node = $conf['tics_node']
$points_per_cpu = $conf['points_per_cpu']
$xratio = $conf['xratio']
$nb_cont_res = $conf['nb_cont_res']

$prop_hierarchy = $conf['prop_hierarchy']

$x_per_prop = 10

$map_prop_hierarchy = [] 
$sorted_resources = []

$dbh = base_connect

cgi_html(cgi)

#p list_resource_properties_fields(base_connect)
#p list_resources(base_connect)

