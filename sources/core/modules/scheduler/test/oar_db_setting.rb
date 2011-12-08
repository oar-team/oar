require 'dbi'
require 'yaml'
require 'rest_client'

DEFAULT_JOB_ARGS = {
  :queue => "default",
  :walltime => 7200,
  :res => "resource_id=1",
  :propreties => "",
  :type => nil
}

def oar_load_test_config
  puts "### Reading configuration ./oar_test_conf file ..." 
  $conf = YAML::load(IO::read('./oar_test.conf'))
  $db_type = $conf['DB_TYPE']
  puts "DB TYPE: #{$conf['DB_TYPE']}"
  pp $conf
end

def oar_db_connect
	if $db_type == "mysql"
		$db_type = "Mysql"
	else 
    $db_type = "Pg" #postgresql
  end 
	$dbh = DBI.connect("dbi:#{$db_type}:#{$conf['DB_BASE_NAME']}:#{$conf['DB_HOSTNAME']}",
										 "#{$conf['DB_BASE_LOGIN']}","#{$conf['DB_BASE_PASSWD']}")
  puts "DB Connection Establised"
end

def oar_db_disconnect
  $dbh.disconnect
end

def get_last_insert_id(seq)
  id = 0
  if ($db_type == "Mysql" || $db_type == "mysql" )
    id=$dbh.select_one("SELECT LAST_INSERT_ID()")[0]
  else
    id=$dbh.select_one("SELECT CURRVAL('#{seq}')")[0]
  end
  return id
end

#$jobs = DB[:jobs]
#$moldable = DB[:moldable_job_descriptions]
#$job_resource_groups = DB[:job_resource_groups]
#$job_resource_description = DB[:job_resource_descriptions]
#$job_types = DB[:job_types]
#$resources = DB[:resources]

def oar_job_insert(j_args={})
  args = {}
  DEFAULT_JOB_ARGS.each do |k,v|
    if j_args[k].nil?
      args[k]=v
    else
      args[k]=j_args[k]
    end
  end
  sth = $dbh.execute("insert into jobs (job_name,state,queue_name,properties,launching_directory,checkpoint_signal) values 
                                      ('yop','Waiting','#{args[:queue]}','#{args[:properties]}','yop',0)")
  sth.finish

  job_id= get_last_insert_id('jobs_job_id_seq') 

  #moldable_id = $moldable.insert(:moldable_job_id => job_id, :moldable_walltime => walltime)
  $dbh.execute("insert into moldable_job_descriptions (moldable_job_id,moldable_walltime) values (#{job_id},#{args[:walltime]})").finish 
  moldable_id = get_last_insert_id('moldable_job_descriptions_moldable_id_seq')

  args[:res].split("+").each do |r|
    #res_group_id =	$job_resource_groups.insert(:res_group_moldable_id => moldable_id, :res_group_property => 'type = "default"')
    $dbh.execute("insert into job_resource_groups (res_group_moldable_id,res_group_property) values 
                                                  (#{moldable_id},'type = ''default''')").finish
    res_group_id = get_last_insert_id('job_resource_groups_res_group_id_seq')

    r.split('/').each_with_index do |type_value,order|
      type,value = type_value.split('=')
      #$job_resource_description.insert(:res_job_group_id => res_group_id.to_i, :res_job_resource_type => type, :res_job_value => value.to_i, :res_job_order => order.to_i)
      $dbh.execute("insert into job_resource_descriptions (res_job_group_id, res_job_resource_type, res_job_value, res_job_order ) 
                   values (#{res_group_id.to_i},'#{type}',#{value.to_i},#{order.to_i})").finish
    end  
  end

  #job's types insertion
  if !args[:types].nil?
    !args[:types].split(',').each do |type|
#      $job_types.insert(:job_id => job_id, :type => type)
      $dbh.execute("insert into job_types (job_id, type) values (#{job_id},'#{type}')").finish
    end
  end

  return job_id
end


def multiple_requests_execute(reqs)
  #Strange dbi_mysql doesn't accept multiple request in one dbh.execute ???
  reqs.split(';').each do |r|
    if (r =~ /\w/)
      $dbh.execute(r).finish
    end
  end
end

def oar_truncate_jobs
#  DB << "
 requests = "
    TRUNCATE accounting;
    TRUNCATE assigned_resources;
    TRUNCATE challenges;
    TRUNCATE event_logs;
    TRUNCATE event_log_hostnames;
    TRUNCATE files;
    TRUNCATE frag_jobs;
    TRUNCATE gantt_jobs_predictions;
    TRUNCATE gantt_jobs_predictions_log;
    TRUNCATE gantt_jobs_predictions_visu;
    TRUNCATE gantt_jobs_resources;
    TRUNCATE gantt_jobs_resources_log;
    TRUNCATE gantt_jobs_resources_visu;
    TRUNCATE jobs;
    TRUNCATE job_dependencies;
    TRUNCATE job_resource_descriptions;
    TRUNCATE job_resource_groups;
    TRUNCATE job_state_logs;
    TRUNCATE job_types;
    TRUNCATE moldable_job_descriptions;
    TRUNCATE resource_logs;
"
  multiple_requests_execute(requests)
end

def oar_update_visu
  requests = "
    DELETE FROM gantt_jobs_predictions_visu;
    DELETE FROM gantt_jobs_resources_visu;
    INSERT INTO gantt_jobs_predictions_visu SELECT * FROM gantt_jobs_predictions;
    INSERT INTO gantt_jobs_resources_visu SELECT * FROM gantt_jobs_resources;
  "
  multiple_requests_execute(requests)
end

def oar_truncate_gantt
 requests = "
    TRUNCATE gantt_jobs_predictions;
    TRUNCATE gantt_jobs_predictions_log;
    TRUNCATE gantt_jobs_predictions_visu;
    TRUNCATE gantt_jobs_resources;
    TRUNCATE gantt_jobs_resources_log;
    TRUNCATE gantt_jobs_resources_visu;
  "
  multiple_requests_execute(requests)
end


def oar_sql_file(file_name)
  if $db_type == "Mysql"
    puts "mysql --user=#{$conf['DB_BASE_LOGIN']} --password= #{$conf['DB_BASE_PASSWD']}  #{$conf['DB_BASE_NAME']}  < #{file_name}" 
    system("mysql --user=#{$conf['DB_BASE_LOGIN']} --password=#{$conf['DB_BASE_PASSWD']}  #{$conf['DB_BASE_NAME']}  < #{file_name}")
  else
    puts "Sorry not implemented"
  end
#  requests =  File.open(file_name, "r").read
#  multiple_requests_execute(requests)
end

def oar_resource_insert(args={})

  if (args.nil?)
    $dbh.execute("insert into resources (state) values ('Alive')").finish
  else
    if !args[:nb_resources].nil?
      args[:nb_resources].times do
         $dbh.execute("insert into resources (state) values ('Alive')").finish   
      end
    end
  end
end

def oar_truncate_resources
#  DB << "
  requests = "
    TRUNCATE resources;
    TRUNCATE resource_logs;
    "
  multiple_requests_execute(requests)
end

def oar_db_clean
  oar_truncate_jobs
  oar_truncate_resources
end

def get_start_time(job_id)
 $dbh.execute("select jobs.start_time from jobs where jobs.job_id=#{job_id}").first.first
end

def get_start_stop_time(job_id)
  res=$dbh.execute("select jobs.start_time, jobs.stop_time from jobs where jobs.job_id=#{job_id}")
  r = res.first
  res.finish
  return r
end

def delete_assignements_from_start_time(start_time)
# $dbh.execute("SELECT * FROM assigned_resources,jobs, moldable_job_descriptions WHERE
#                jobs.start_time > #{start_time} AND
#                jobs.assigned_moldable_job = assigned_resources.moldable_job_id )"

  $dbh.execute("DELETE assigned_resources FROM assigned_resources,jobs, moldable_job_descriptions WHERE
                jobs.start_time > #{start_time} AND
                jobs.assigned_moldable_job = assigned_resources.moldable_job_id")
end

# limitations
# * advance reservation
# * submission time is not translated
def reset_job_from_start_time(start_time, now, delay = 10)
 
  # Running jobs:  
  #   change state
  #   change start time and stop time
  delta = now - start_time
  $dbh.execute("UPDATE jobs  
    SET 
      state='Running', 
      start_time = #{delta} + jobs.start_time, 
      stop_time = 0  
    WHERE 
      start_time < #{start_time} AND
      stop_time > #{start_time}
    ")

  # Reset future jobs
  #   delete_assignements
  delete_assignements_from_start_time(start_time)
  #   change state waiting 
  $dbh.execute("UPDATE jobs SET state='Waiting' WHERE jobs.start_time > #{start_time}")

end

# reset all jobs to state=waiting,  remove assigned resources and switch index to CURRENT
def oar_reset_all_jobs(state="'Waiting'")
 $dbh.execute("TRUNCATE assigned_resources")
 $dbh.execute("UPDATE jobs SET state=#{state}")
 $dbh.execute("UPDATE moldable_job_descriptions SET moldable_index = 'CURRENT'")
 $dbh.execute("UPDATE job_resource_groups SET res_group_index = 'CURRENT'")
 $dbh.execute("UPDATE job_resource_descriptions SET res_job_index = 'CURRENT'")
 $dbh.execute("UPDATE job_resource_groups SET res_group_index = 'CURRENT'")
 $dbh.execute("UPDATE job_resource_descriptions SET res_job_index = 'CURRENT'") 
end


#
# oar_jobs_sleepify:
# Remove previous allocations 
# Sets command field by sleep with job execution time as argument and jobs' state to hold.
# Returns array which contains job_ids and corresponding submission times begin from 0 (first submitted job)

def oar_jobs_sleepify()
  resume_seq=[]
  # Remove previous allocations 
  requests = "
    TRUNCATE accounting;
    TRUNCATE assigned_resources;
    TRUNCATE challenges;
    TRUNCATE event_logs;
    TRUNCATE event_log_hostnames;
    TRUNCATE files;
    TRUNCATE frag_jobs;
    TRUNCATE gantt_jobs_predictions;
    TRUNCATE gantt_jobs_predictions_log;
    TRUNCATE gantt_jobs_predictions_visu;
    TRUNCATE gantt_jobs_resources;
    TRUNCATE gantt_jobs_resources_log;
    TRUNCATE gantt_jobs_resources_visu;
    TRUNCATE job_state_logs;
    TRUNCATE resource_logs;
"
  multiple_requests_execute(requests)

  oar_reset_all_jobs("'Hold'")
 
  q = "SELECT job_id, submission_time, start_time, stop_time FROM jobs"
  puts "Be careful we're scanning all jobs"
  res = $dbh.execute(q)
  orig_subtime = 0
  res.each do |j|
    execution_time = j[3]-j[2]
    if orig_subtime == 0
      orig_subtime = j[1]
    end
    subtime =  j[1] - orig_subtime
    puts "job_id: #{j[0]} start_time: #{j[1]} modify_subtime: #{subtime} execution_time: #{execution_time}"
    resume_seq.push([j[0],subtime])

    $dbh.execute("UPDATE jobs  
      SET
        command = 'sleep #{execution_time}',
        launching_directory = '/tmp',
        stdout_file= '/tmp/oar.#{j[0]}.out',
        stderr_file= '/tmp/oar.#{j[0]}.err',
        job_user = 'kameleon' 
      WHERE
        job_id =  #{j[0]}")
  end
  res.finish
  return resume_seq
end

def oar_replay(sequence)
  #  RestClient.post 'http://kameleon:kameleon@localhost/oarapi-priv/jobs/1/resumptions/new.yaml','' 
  ref_time = Time.now.to_f + 1
  #puts "ref_time: #{ref_time}"
  sequence.each do |step|
    job_id, release_time = step
    time2sleep =  release_time - (Time.now.to_f - ref_time)
    sleep time2sleep if (time2sleep > 0)
    puts  "Release job:#{job_id} error_release_time: #{Time.now.to_f - ref_time - release_time}"
    #puts "Release job:#{job_id} release_time: #{release_time} effective_release_time: #{Time.now.to_f - ref_time}" 
    RestClient.post "http://kameleon:kameleon@localhost/oarapi-priv/jobs/#{job_id}/resumptions/new.yaml",''
  end
end


#SELECT assigned_resources.resource_id
#FROM jobs, assigned_resources, moldable_job_descriptions, resources
#WHERE
# jobs.job_id = 2 AND
# jobs.assigned_moldable_job = assigned_resources.moldable_job_id AND
# moldable_job_descriptions.moldable_job_id = 2 AND
# resources.resource_id = assigned_resources.resource_id

def oar_job_times(job_id)
end

def oar_job_resources(job_id)
  q = " SELECT assigned_resources.resource_id
    FROM jobs, assigned_resources, moldable_job_descriptions
    WHERE
      jobs.job_id = #{job_id} AND
      jobs.assigned_moldable_job = assigned_resources.moldable_job_id AND
      moldable_job_descriptions.moldable_job_id = #{job_id}" 
  res = $dbh.execute(q)
  r=[]
  res.each do |r_id|
    r << r_id.first
  end
  res.finish
  return r   
end

def oar_jobs_overlap?
  q = "SELECT job_id, start_time, stop_time FROM jobs"
  puts "Be careful we're scanning all jobs"
  res = $dbh.execute(q)
  previous_jobs = []
  print "Test job:"
  res.each do |j|
    print "#{j[0]} "
    r =  oar_job_resources(j[0]) 
    previous_jobs.each do |k|
      if ((j[1]>k[1]) and (j[1]<k[2])) or ((j[2]>k[1]) and (j[2]<k[2])) or  ((j[1]<k[1]) and (j[2]>k[2]))
        if (r&k[3])!=[]
          puts
          puts "Jobs overlap: #{j[0]} #{k[0]}"
          pp [j[0],j[1],j[2],r]
          pp k
        end
      end
    end
    previous_jobs.push([j[0],j[1],j[2], oar_job_resources(j[0])]) #oar_job_resources ugly (bad performance)  
  end
end




if ($0=='irb')
  puts 'irb session detected, db connection launched'
  oar_load_test_config
  oar_db_connect
end
# 50.times do |i| oar_job_insert(:res=>"resource_id=#{i}",:walltime=> 300) end




