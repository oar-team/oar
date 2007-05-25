#!/usr/bin/ruby -w
# $Id: db_converter.rb 547 2007-05-23 09:27:57Z auguste $
# db_converter is a simple oar converter from 1.6 table schema to 2.0  
#
#####################################################
# 
# USAGE
#
#####################################################
#
#	0) MAKE A DUMP OF DATABASES
# 1) adapt configuration below
# 2) run: ruby ./db_converter.rb 
#
# Note: don't care to message "/usr/lib/ruby/1.8/dbi/sql.rb:60: warning: 2 digits year is used" is not important 
#
# author: auguste@imag.fr
#
# requirements:
# 	ruby1.8 (or greater)
# 	libdbi-ruby
# 	libdbd-mysql-ruby

#####################################################
#
# CONFIGURATION
#
#####################################################

$oar_db_1 = 'oar-ita-1-6'
$host_1 = 'localhost'
$login_1 = 'root'
$passwd_1 = ''

$oar_db_2 = 'oar2test'
$host_2 = 'localhost'
$login_2 = 'root'
$passwd_2 = ''


$cluster = ['iclusters1','icluster2'] #cluster propertie (cluster field in resource table) 
$cluster_size =[50,53]


$nb_cpu = [2,2]   #number of cpu by node
$nb_core = [1,2]  #number of core by cpu

$scaling_weight_factor = [2,4] #$scaling_weight_factor equal to (nb_core * nb_cpu) / maxweight

$resource_cluster = {}

##############################################################################################

#$scaling_weight_factor = nil #$scaling_weight_factor equal to (nb_core * nb_cpu) / maxweight

$res_id = nil #intial index for resource_id
$cpu = nil  #initial index for cpu field
$core = nil #initial index for core field

$job_id_offset = nil #job_id_offset is add to oar_1.6's job_id to give oar_2's job_id one 

#$empty = false #if true flush modified oar.v2 tables before convertion    
$empty = true	 # MUST BE SET TO false (for development/testing purpose)

#####################################################
#
# NOTES:
#
# Add core in resources table en update cpuset accordingly
# All resources must be free in V1.6 database (for simplication purpose).
#
# TABLES v2 modification
# modified
# ********
#   assigned_resources 
#   jobs 
#   job_resource_descriptions 
#   job_resource_groups 
#   job_types 
#   job_state_logs 
#   moldable_job_descriptions 
#   resources 
#   resource_logs  
#		frag_jobs 	
#	  event_logs (QUESTION: Est-ce que tout les events v1.6 sont inclus ds l'ensemble des events v2.0 !!)
#   event_log_hostnames
#
# not addressed 
# *************
#   accounting
#   admission_rules
#   challenges
#   files
#   gantt_jobs_predictions
#   gantt_jobs_predictions_visu
#   gantt_jobs_resources
#   gantt_jobs_resources_visu
#   job_dependencies
#
# TABLES 1.6 
# 
# used 
# *************
#
#    event_log 
#    event_log_hosts
#    fragJobs 
#    jobs
#    jobState_log
#    nodes
#    nodeState_log
#    processJobs
#    processJobs_log

# not used 
# *************
#    accounting
#    admissionRules
#    files
#    ganttJobsNodes
#    ganttJobsNodes_visu
#    ganttJobsPrediction
#    ganttJobsPrediction_visu
#    nodeProperties
#    nodeProperties_log
#    queue
#############################################


require 'dbi'
require 'time'
require 'optparse'
require 'pp'

def to_unix_time(time)
 	year, month, day, hour, minute, sec = time.to_s.split(/ |:|-/)
	unix_sec = Time.local(year, month, day, hour, minute, sec).to_i
	return unix_sec
end

def hmstos(hms)
	h,m,s = hms.to_s.split(/:/)
	return 3600*h.to_i + 60*m.to_i + s.to_i
end

def base_connect(dbname_host,login,passwd)
	return DBI.connect("dbi:Mysql:#{dbname_host}", login,passwd)
end

def list_resources1(dbh)
	puts "Get resources (nodes) information from oar 1.6 db"	
	q = "SELECT * FROM nodes"
	return dbh.select_all(q)
end

def determine_scaling_weight_factor(dbh)
	if ($scaling_weight_factor.nil?)
		q = "SELECT MAX(maxWeight) FROM `nodes`"
		$scaling_weight_factor = ($nb_core * $nb_cpu) / dbh.select_all(q).first.first.to_i
	end
	puts "scaling_weight_factor = #{$scaling_weight_factor}"
end

def get_all_job_id1(dbh)
	q = "SELECT idJob FROM jobs"
	res = dbh.execute(q)
	all_job_id1 = []
	res.each do |id|
		all_job_id1 << id.first
	end 
	res.finish
	return all_job_id1
end

def get_job_info1(dbh,job_id)
	q = "SELECT * FROM jobs WHERE idJob=#{job_id}"
	puts q
	row = nil
	begin
		row = dbh.select_one(q)
	rescue
		pp row
		puts "yop"
	end
	return row 
end

def get_job_info1_mod(dbh,job_id)
	q = "SELECT `idJob`, `jobType`, `infoType`, `state`, `reservation`, `message`, `user`, `nbNodes`, `weight`, `command`, `bpid`, `queueName`, `maxTime`, `properties`, `launchingDirectory`, `submissionTime`, `idFile`, `accounted`, `checkpoint`, `autoCheckpointed` FROM jobs WHERE idJob=#{job_id}"

	sth = dbh.execute(q)
	row = sth.fetch_hash
  sth.finish

	begin
		res = dbh.select_one("SELECT `startTime` FROM jobs WHERE idJob=#{job_id}")
		row['startTime'] = res['startTime'] 	
	rescue
#		puts "Warning startTime = 0000-00-00 00:00:00 for job: #{job_id} ?: " + $!
		row['startTime'] = nil
	end

	begin
		res = dbh.select_one("SELECT `stopTime` FROM jobs WHERE idJob=#{job_id}")
		row['stopTime'] = res['stopTime'] 	
	rescue
#		puts "Warning stopTime = 0000-00-00 00:00:00 for job: #{job_id} ? : " + $!
		row['stopTime'] = nil
	end

	return row 
end

def get_resources_job1(dbh,job_id)
#	puts "Get resources (nodes) affected to #{job_id} jobfrom oar 1.6 db"
	q = "SELECT hostname FROM processJobs_log WHERE idJob=#{job_id}"
	res = dbh.execute(q)
	resources = []
	res.each do |r|
		resources << r.first
	end 
	res.finish
	return resources
end

def get_resources_log1(dbh)
	puts "Get resources (nodes) log information from oar 1.6 db"	
	q = "SELECT * FROM nodeState_log"
	return dbh.select_all(q)
end


def add_core_cluster_fields2(dbh2)
	puts "Add core and cluster fields to resource table on oar2 db"
	begin
		dbh2.do("ALTER TABLE `resources` ADD `core` INT UNSIGNED NOT NULL DEFAULT '0' AFTER `cpu`")
	rescue
		puts "Core field exits in resource table ? :" + $!
	end
	begin
		dbh2.do("ALTER TABLE `resources` ADD `cluster` VARCHAR(50) AFTER `suspended_jobs`")
	rescue
		puts "Cluster field exits field in resource table ? :" + $!
	end
end

def insert_resources2(dbh,resources)

	puts "Insert resources"

	if ($res_id.nil?)
		q = "SELECT MAX(resource_id) FROM `resources`"
		max_resource_id= dbh.select_all(q).first.first.to_i

		if (max_resource_id == 0)
			$res_id = 1
			$core = 1
			$cpu = 1
		  
		else
			q = "SELECT `cpu`, `core`  FROM `resources` WHERE resource_id=#{max_resource_id}"
			cpu, core = dbh.select_all(q).first
			$res_id = max_resource_id + 1
			$core = core + 1
			$cpu = cpu + 1
		end
	end

	r_id = $res_id
	resources_conv = {}

	resource_index_begin =0	

	$cluster.each_with_index do |cluster,index_cluster|
	
		resources[resource_index_begin..(resource_index_begin + $cluster_size[index_cluster]-1) ].each do |res|

			resources_conv[res['hostname']] = []
			$resource_cluster[res['hostname']] = index_cluster 
			i = 0
			$nb_cpu[index_cluster].times do |cp| 
				$nb_core[index_cluster].times do |co|
					begin
						dbh.do("INSERT INTO `resources` ( `resource_id` , `network_address` , `cluster`, `cpu` , `core` , `cpuset`) 
VALUES ('#{r_id}', '#{res['hostname']}', '#{cluster}', '#{$cpu}','#{$core}','#{i}')")
					rescue
						puts "Unable to INSERT resource: " + $!
						exit
					end
					resources_conv[res['hostname']] << r_id
					$core += 1
					i += 1
					r_id += 1
				end
				$cpu += 1
			end
		end
	resource_index_begin = resource_index_begin + 	 $cluster_size[index_cluster]

	end
	return resources_conv
end

def insert_resource_logs2(dbh,resources_log1,res_conv)

	puts "Insert resources log"

	resources_log1.each do |res_log|

		node = res_log['hostname']
		node.each do |res_id|
			date_stop = "0"	
			begin
				date_stop = to_unix_time(res_log['dateStop']) if res_log['dateStop'].class != NilClass 
				dbh.do("INSERT INTO `resource_logs` (`resource_id` , `attribute` , `value` , `date_start` , `date_stop` , `finaud_decision` )
VALUES ('#{res_id}','state','#{res_log['changeState']}', '#{to_unix_time(res_log['dateStart'])}', '#{date_stop}','#{res_log['finaudDecision']}')")
			rescue
				puts "Failed to insert resource logs: " + $!
				exit
			end
		end
	end
end

def determine_job_id_offset(dbh)
	if ($job_id_offset.nil?)
		q = "SELECT MAX(job_id) FROM `jobs`"
		$job_id_offset = dbh.select_all(q).first.first.to_i
	end
	puts "job_id_offset = #{$job_id_offset}"
end

def insert_job2(dbh,job,res_conv, assigned_resources)

	job_id2 = job['idJob'].to_i + $job_id_offset

	begin
			dbh.do("INSERT INTO `moldable_job_descriptions` ( `moldable_id` , `moldable_job_id` , `moldable_walltime` , `moldable_index` ) VALUES ( '#{job_id2}', '#{job_id2}', '#{hmstos(job['maxTime'])}', 'LOG')")
	rescue
		puts "Failed to insert moldable job descriptions: " + $!
		exit
	end

	begin
		dbh.do("INSERT INTO `job_resource_groups` ( `res_group_id` , `res_group_moldable_id` , `res_group_property` , `res_group_index` ) VALUES (?, ?, ?, ?)", job_id2, job_id2 , "type = 'default" ,'LOG')
	rescue
		puts "Failed to insert job resource groups: " + $!
		exit
	end

	message = ""
	start_time = 0
	stop_time = 0

	begin
		message =  job['message'] if job['message'].class != NilClass
		start_time = to_unix_time(job['startTime']) if job['startTime'].class != NilClass
 		stop_time = to_unix_time(job['stopTime']) if job['stopTime'].class != NilClass

		dbh.do("INSERT INTO `jobs` ( `job_id` , `job_name`, `job_type` , `info_type` , `state` , `reservation` , `message` , `job_user` , `command`, `queue_name` , `properties` , `launching_directory` , `submission_time` , `start_time` , `stop_time` , `file_id` , `accounted` , `assigned_moldable_job` , `checkpoint`) 
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", 
job_id2, 'converted' , job['jobType'], job['infoType'], job['state'], job['reservation'], message, job['user'], job['command'], job['queueName'], job['properties'], job['launchingDirectory'], to_unix_time(job['submissionTime']), start_time, stop_time, job['idFile'], job['accounted'], job['idJob'], job['checkpoint'] )

	rescue
		puts "Failed to insert job: " + $!
		exit
	end

	if (job['queueName'] == "deploy" || job['queueName'] == "besteffort") 
		begin
			dbh.do("INSERT INTO `job_types` ( `job_id` , `type` , `types_index` )
	VALUES ('#{job_id2}', '#{job['queueName']}', 'LOG')")
		rescue
			puts "Failed to insert job types: " + $!
			exit
		end
	end


# job_state_logs

	#insert assigned resources
	nb_res = 0	
	assigned_resources.each do |node|
		
		if ($resource_cluster[node].nil?)
			puts "WARNING: node: #{node} is unkwon"
		else
#		puts $scaling_weight_factor,"node",node,$resource_cluster[node],"yop",job['weight']
			($scaling_weight_factor[$resource_cluster[node]]*job['weight'].to_i).times do |i|
				begin
					dbh.do("INSERT INTO `assigned_resources` ( `moldable_job_id` , `resource_id` , `assigned_resource_index` ) VALUES ('#{job_id2}', '#{res_conv[node][i]}', 'LOG')")
					nb_res = nb_res + 1	
#puts "job_id: #{job_id2} res_id:#{res_conv[node][i]}  i:#{i}"

				rescue
					puts "Failed to insert assigned resources: " + $!
					exit
				end
			end
		end
	end

  begin
	dbh.do("INSERT INTO `job_resource_descriptions` ( `res_job_group_id` , `res_job_resource_type` , `res_job_value` , `res_job_order`, `res_job_index`) VALUES ('#{job_id2}', 'core', '#{nb_res}', '0', 'LOG')")
	rescue
		puts "Failed to insert job resource descriptions: " + $!
		exit
	end


end


def convert_job_state_logs(dbh1,dbh2)

	puts "Convert job state logs"
	sth = dbh1.execute("SELECT * FROM jobState_log")
  sth.each do |row|

	job_id2 = row['jobId'].to_i + $job_id_offset

	date_stop = "0"	
		begin	
			date_stop = to_unix_time(row['dateStop']) if row['dateStop'].class != NilClass 
			dbh2.do(" INSERT INTO `job_state_logs` (`job_id` , `job_state` , `date_start` , `date_stop` )
VALUES ('#{job_id2}','#{row['jobState']}','#{to_unix_time(row['dateStart'])}','#{date_stop}')")
		rescue
			puts "Unable to INSERT job state logs: " + $!
			exit
		end
  end
  sth.finish
end

def convert_frag_jobs(dbh1,dbh2)

	puts "Convert frag jobs"
	sth = dbh1.execute("SELECT * FROM fragJobs")
  sth.each do |row|
		job_id2 = row['fragIdJob'].to_i + $job_id_offset

		begin
			dbh2.do("INSERT INTO `frag_jobs` ( `frag_id_job` , `frag_date` , `frag_state` )
			VALUES ('#{job_id2}','#{to_unix_time(row['fragDate'])}','#{row['fragState']}')")
		rescue
			puts "Unable to INSERT frag jobs: " + $!
			exit
		end
  end
  sth.finish
end

def convert_event_logs(dbh1,dbh2)
	puts "Convert event_logs"
	sth = dbh1.execute("SELECT * FROM event_log")
  sth.each do |row|
		job_id2 = row['idJob'].to_i + $job_id_offset
		begin
			dbh2.do("INSERT INTO `event_logs` ( `event_id` , `type` , `job_id` , `date` , `description` , `to_check` )
VALUES (?, ?, ?, ?, ?, ?)",
row['idEvent'], row['type'], job_id2, to_unix_time(row['date']), row['description'], row['toCheck'] )
		rescue
			puts "Unable to INSERT event logs: " + $!
			exit
		end
  end
  sth.finish
end

def convert_event_log_hostnames(dbh1,dbh2)
	puts "Convert event log hostnames"
	sth = dbh1.execute("SELECT * FROM event_log_hosts")
  sth.each do |row|
		begin
			dbh2.do("INSERT INTO `event_log_hostnames` ( `event_id` , `hostname` ) VALUES ('#{row['idEvent']}','#{row['hostname']}')")
		rescue
			puts "Unable to INSERT  event log hostnames: " + $!
			exit
		end
  end
  sth.finish
end

def empty_db(dbh,name)

	puts "\nEMPTY some tables of #{name} database (oar v2.0) !!"	
	puts
	puts "resources, resource_logs, moldable_job_descriptions, job_resource_descriptions, job_resource_groups, jobs, job_types, assigned_resources, job_state_logs, frag_jobs, event_logs, event_log_hostnames"
		
	sleep 5

	dbh.do("TRUNCATE TABLE `resources`") 
	dbh.do("TRUNCATE TABLE `resource_logs`") 
	dbh.do("TRUNCATE TABLE `moldable_job_descriptions`") 
	dbh.do("TRUNCATE TABLE `job_resource_descriptions`") 
	dbh.do("TRUNCATE TABLE `job_resource_groups`") 
	dbh.do("TRUNCATE TABLE `jobs`") 	
	dbh.do("TRUNCATE TABLE `job_types`") 
	dbh.do("TRUNCATE TABLE `assigned_resources`") 
	dbh.do("TRUNCATE TABLE `job_state_logs`") 
	dbh.do("TRUNCATE TABLE `frag_jobs`") 
	dbh.do("TRUNCATE TABLE `event_logs`") 
	dbh.do("TRUNCATE TABLE `event_log_hostnames`") 

end

#############################################

puts "\ndb_converter oar v1.6 to v2.0:"
puts "  See the begin of this script file for configuration details"
puts

dbh1 = base_connect("#{$oar_db_1}:#{$host_1}",$login_1,$passwd_1)
dbh2 = base_connect("#{$oar_db_2}:#{$host_2}",$login_2,$passwd_2)

empty_db(dbh2,$oar_db_2) if $empty
	
dbh2.do("TRUNCATE TABLE `resources`") 

# Get resources
resources = list_resources1(dbh1)
#resources.each do |res|
#	puts "node information: hostname: #{res['hostname']} maxWeight: #{res['maxWeight']}"
#end

#determine_scaling_weight_factor(dbh1)

# Add core and cluster fields
add_core_cluster_fields2(dbh2)

# Insert resources
res_conv2 = insert_resources2(dbh2,resources)
insert_resource_logs2(dbh2,get_resources_log1(dbh1),res_conv2)

determine_job_id_offset(dbh2)

#get_all_job_id1
all_job_id1 = get_all_job_id1(dbh1)

all_job_id1.each_with_index do |job_id,i|
#	job_info = all_job_id1.first
	puts "#{i} jobs processed" if (i % 100) == 0
	job_info =  get_job_info1_mod(dbh1,job_id)

	assigned_resources = get_resources_job1(dbh1,job_id)

	insert_job2(dbh2,job_info, res_conv2, assigned_resources)	
end

convert_job_state_logs(dbh1,dbh2)
convert_frag_jobs(dbh1,dbh2)
convert_event_logs(dbh1,dbh2)
convert_event_log_hostnames(dbh1,dbh2)

puts "\nConvertion is terminated"
puts
