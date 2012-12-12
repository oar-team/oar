#!/usr/bin/ruby
require 'dbi'
require 'yaml'
require 'rest_client'
require 'pp'
begin
  require 'pry'
rescue LoadError
  puts 'Warning: pry seems absent (catch LoadError)'
end

DEFAULT_JOB_ARGS = {
  :queue => "default",
  :walltime => 7200,
  :res => "resource_id=1",
  :properties => "",
  :type => nil,
  :user =>  ENV['USER']
}

OARCONFFILE =   'export OARCONFFILE="/etc/oar/oar.conf"'

SCHED_PERL_TS = "/usr/lib/oar/schedulers/oar_sched_gantt_with_timesharing"
SCHED_PERL_FS = "/usr/lib/oar/schedulers/oar_sched_gantt_with_timesharing_and_fairsharing"
SCHED_OCAML = "/usr/lib/oar/schedulers/simple_cbf_mb_h_ct_oar_mysql"
SCHED_OCAML_A = "/home/auguste/prog/oar/sources/extra/ocaml-schedulers/simple_cbf_mb_h_ct_oar/simple_cbf_mb_h_ct_oar_mysql"
SCHED_KAMELOT = "/usr/local/lib/oar/schedulers/kamelot_mysql"

##
# This method load db configuration from ./oar_test.conf file
#
def oar_load_test_config
  puts "### Reading configuration ./oar_test_conf file ..." 
  $conf = YAML::load(IO::read('./oar_test.conf'))
  $db_type = $conf['DB_TYPE']
  puts "DB TYPE: #{$conf['DB_TYPE']}"
  pp $conf
end

def oar_db_connect
	if ($db_type == "Mysql"||$db_type == "mysql")
    $PG = false
    $MYSQL = true
    $db_type = "Mysql"
	else 
    $PG = true
    $MYSQL = false
  end
  puts  "dbi:#{$db_type}:#{$conf['DB_BASE_NAME']}:#{$conf['DB_HOSTNAME']}",
				"#{$conf['DB_BASE_LOGIN']}","#{$conf['DB_BASE_PASSWD']}"

#	$dbh = DBI.connect("dbi:#{$db_type}:#{$conf['DB_BASE_NAME']}:#{$conf['DB_HOSTNAME']}:mysql_local_infile=1",
  $dbh = DBI.connect("dbi:#{$db_type}:#{$conf['DB_BASE_NAME']}:#{$conf['DB_HOSTNAME']}",
										 "#{$conf['DB_BASE_LOGIN']}","#{$conf['DB_BASE_PASSWD']}")
  puts "DB Connection Establised"
end

def oar_db_disconnect
  $dbh.disconnect
end

#TODO use table variable
def get_last_insert_id(table="jobs_job_id_seq")
  id = 0
  if ($db_type == "Mysql" || $db_type == "mysql" )
    id=$dbh.select_one("SELECT LAST_INSERT_ID()")[0]
  else
    id=$dbh.select_one("SELECT CURRVAL('jobs_job_id_seq')")[0]
  end
  return id
end

##
# Direct database job insertion
# [Supported args] :queue, :user, :properties
# @examples
#   oar_job_insert(:res=>"resource_id=#{i}",:walltime=> 300) 
#
#   "{ sql1 }/prop1=1/prop2=3+{sql2}/prop3=2/prop4=1/prop5=1+...,walltime=1:00:00"
#   "/switch=2/nodes=10+{type = 'mathlab'}/licence=20"
#   oar_job_insert({:res=>"host=1/cpu=2/core=2+cpu=1/core=2"})
#
#    oar_job_insert(:res=>"resource_id=2", :properties=>"network_address='node004'", :walltime=> 300) 
#
def oar_job_insert(j_args={})
  args = {}
  DEFAULT_JOB_ARGS.each do |k,v|
    if j_args[k].nil?
      args[k]=v
    else
      args[k]=j_args[k]
    end
  end
  sth = $dbh.execute("insert into jobs (job_name,state,queue_name,properties,launching_directory,checkpoint_signal,job_user) values 
                                      ('yop','Waiting','#{args[:queue]}','#{args[:properties]}','yop',0,'#{args[:user]}')")
  sth.finish

  job_id= get_last_insert_id() 

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

##
#  oar_bulk_job_insert(10) {|i| [(i % max_nb_res) +1,300]} # [nb_res,walltime]
#
def oar_bulk_job_insert(nb_jobs,j_args={})

  args = {}
  DEFAULT_JOB_ARGS.each do |k,v|
    if j_args[k].nil?
      args[k]=v
    else
      args[k]=j_args[k]
    end
  end

  puts "oar_bulk_job_insert:" 
  puts "/!\\ be carefull, it's suppose that moldable_id=res_group_id=job_id"
  puts "truncate jobs' tables"
  oar_truncate_jobs
  query_jobs = "insert into jobs (job_name,state,queue_name,properties,launching_directory,checkpoint_signal,job_user) values "
  query_moldable_job_descriptions = "insert into moldable_job_descriptions (moldable_job_id,moldable_walltime) values "
  query_job_resource_groups = "insert into job_resource_groups (res_group_moldable_id,res_group_property) values "
  query_job_resource_descriptions = "insert into job_resource_descriptions (res_job_group_id, res_job_resource_type, res_job_value, res_job_order) values "

  nb_jobs.times do |i|
    job_id = i+1
    nb_res,walltime = yield job_id
    query_jobs += "('yop','Waiting','#{args[:queue]}','#{args[:properties]}','yop',0,'#{args[:user]}'),"
    query_moldable_job_descriptions += "(#{job_id},#{walltime}),"
    query_job_resource_groups +=  "(#{job_id},'type = ''default'''),"
    query_job_resource_descriptions += "(#{job_id},'resource_id',#{nb_res},1),"
  end
#  puts query_jobs.chop
#  puts query_moldable_job_descriptions.chop
#  puts query_job_resource_groups.chop
#  puts query_job_resource_descriptions.chop
  $dbh.execute(query_jobs.chop).finish
  $dbh.execute(query_moldable_job_descriptions.chop).finish
  $dbh.execute(query_job_resource_groups.chop).finish
  $dbh.execute(query_job_resource_descriptions.chop).finish
end

def multiple_requests_execute(reqs)
  #Strange dbi_mysql doesn't accept multiple request in one dbh.execute ???
  reqs.split(';').each do |r|
    if (r =~ /\w/)
      $dbh.execute(r).finish
    end
  end
end

##
# This method remove data from all jobs in database
#
def oar_truncate_jobs
#  DB << "
 rst_id = ""
 rst_id = "RESTART IDENTITY" if $PG
 requests = "
    TRUNCATE accounting #{rst_id};
    TRUNCATE assigned_resources #{rst_id};
    TRUNCATE challenges #{rst_id};
    TRUNCATE event_logs #{rst_id};
    TRUNCATE event_log_hostnames #{rst_id};
    TRUNCATE files #{rst_id};
    TRUNCATE frag_jobs #{rst_id};
    TRUNCATE gantt_jobs_predictions #{rst_id};
    TRUNCATE gantt_jobs_predictions_log #{rst_id};
    TRUNCATE gantt_jobs_predictions_visu #{rst_id};
    TRUNCATE gantt_jobs_resources #{rst_id};
    TRUNCATE gantt_jobs_resources_log #{rst_id};
    TRUNCATE gantt_jobs_resources_visu #{rst_id};
    TRUNCATE jobs #{rst_id};
    TRUNCATE job_dependencies #{rst_id};
    TRUNCATE job_resource_descriptions #{rst_id};
    TRUNCATE job_resource_groups #{rst_id};
    TRUNCATE job_state_logs #{rst_id};
    TRUNCATE job_types #{rst_id};
    TRUNCATE moldable_job_descriptions #{rst_id};
    TRUNCATE resource_logs #{rst_id};
"
  multiple_requests_execute(requests)
end

##
# Update gantt prediction related tables to provide global gantt data after a scheduling round. 
#
def oar_update_visu
  requests = "
    DELETE FROM gantt_jobs_predictions_visu;
    DELETE FROM gantt_jobs_resources_visu;
    INSERT INTO gantt_jobs_predictions_visu SELECT * FROM gantt_jobs_predictions;
    INSERT INTO gantt_jobs_resources_visu SELECT * FROM gantt_jobs_resources;
  "
  multiple_requests_execute(requests)
end

##
# Truncate gantt prediction related tables. 
#

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
  if $db_type == "mysql"
    puts "mysql --user=#{$conf['DB_BASE_LOGIN']} --password= #{$conf['DB_BASE_PASSWD']}  #{$conf['DB_BASE_NAME']}  < #{file_name}" 
    system("mysql --user=#{$conf['DB_BASE_LOGIN']} --password=#{$conf['DB_BASE_PASSWD']}  #{$conf['DB_BASE_NAME']}  < #{file_name}")
  else
    puts "Sorry not implemented"
  end
#  requests =  File.open(file_name, "r").read
#  multiple_requests_execute(requests)
end

#
# oar_resource_insert
# @param [args={}] set number of ressources to insert by :nb_resources=> int 
# @return Returns nothing
# @example
#   #insert 100 raw resources
#   oar_resource_insert(:nb_resources=>100)
#   #insert 2 network_addresses w/ 2 cpu w/ 4 cores, resulting to 2*2*4 resources
#   oar_resource_insert(:ip_cpu_core=>[2,2,4]) #

def oar_resource_insert(args={})
  if (args=={})
    $dbh.execute("insert into resources (state) values ('Alive')").finish
  else
    if !args[:nb_resources].nil?
      nb_res =  args[:nb_resources].to_i
      nb_100 = nb_res/100
      nb_residual = nb_res - 100 * nb_100
      puts "nb_100: #{nb_100} , nb_residual: #{nb_residual}"
      if (nb_100>0)
        ressources_100 = ("('localhost','Alive')," * 100).chop
        nb_100.times do
           $dbh.execute("insert into resources (network_address, state) values #{ressources_100}").finish   
        end
      end
      if (nb_residual>0)
        nb_residual_ressources = ("('localhost','Alive')," * nb_residual).chop
        $dbh.execute("insert into resources (network_address, state) values #{nb_residual_ressources}").finish   
      end
    elsif !args[:ip_cpu_core].nil?
      q = ""
      cpu = 0; core =0
      values = args[:ip_cpu_core]
      values[0].times do |ip|
        values[1].times do 
          values[2].times do 
             q += "('Alive','127.0.0.#{ip+1}','#{cpu}','#{core}'),"
             core += 1
          end
          cpu += 1
        end
      end
      puts q
      $dbh.execute("insert into resources (state, network_address, cpu, core) values" + q.chop ).finish
    end
 
  end
end

def oar_test_insert_resources(k,x, alter=false)
  oar_truncate_resources
  puts "nb_insert: #{k}, size of insert in nb_resources: #{x}  nb_ressources: #{k*x} alter: #{alter}"
  t0 = Time.now
  ressources = ("('localhost','Alive')," * x).chop
  t_string = Time.now - t0
  puts "t_string: #{t_string}"
 
  t0 = Time.now
  $dbh.execute("ALTER TABLE resources DISABLE KEYS").finish if alter
  k.times do
    $dbh.execute("insert into resources (network_address, state) values #{ressources}").finish   
  end 
  $dbh.execute("ALTER TABLE resources ENABLE KEYS").finish if alter

  t_insert = Time.now - t0
  puts "t_insert: #{t_insert}"

  puts "t_total:  #{t_string+t_insert} t_string: #{t_string} t_insert: #{t_insert}"
end


def oar_test_insert(k,x, alter=false)
  oar_truncate_gantt
  puts "nb_insert_req: #{k}, block size: #{x},  nb_inserted_row #{k*x}"

  t0 = Time.now
  $dbh.execute("ALTER TABLE gantt_jobs_resources DISABLE KEYS").finish if alter
  k.times do |i|
    gantt_str = ""
    x.times do |j|
      gantt_str += "(#{1000+i},#{10000+j})," 
    end
    gantt_str = gantt_str.chop
    $dbh.execute("insert into  gantt_jobs_resources (moldable_job_id, resource_id) values #{gantt_str}").finish   
  end 
  $dbh.execute("ALTER TABLE gantt_jobs_resources ENABLE KEYS").finish if alter

  t_insert = Time.now - t0
  puts "insert_time: #{t_insert}"
end




def oar_test_insert_load_infile(k,shm=true)
  oar_truncate_gantt
  puts "nb_insert: #{k}"
  if shm then
    file_name = '/run/shm/massive_insert'
  else
    file_name = '/tmp/oar-massive-insert'
  end

  if $PG then
    #need to oar by a superuser for PG;
    #sudo -u postgres /usr/bin/psql -c "ALTER ROLE oar WITH SUPERUSER;"
    query = "COPY gantt_jobs_resources FROM '#{file_name}' WITH DELIMITER AS ','"
  else 
    query = "LOAD DATA LOCAL INFILE '#{file_name}' INTO TABLE gantt_jobs_resources"
  end

  t0 = Time.now
  File.delete(file_name) if File.exist?(file_name)
  f = File.open(file_name,'w')
  k.times do |k|
    f.write("#{k+1},#{k+1000}\n")
  end
  f.close
  t1 = Time.now 
  t_file = t1 - t0

  $dbh.execute(query)
  t_load_data = Time.now - t1
  puts "t_file: #{t_file}"
  puts "t_load_data: #{t_load_data}"

  puts "t_total:  #{t_file+t_load_data} t_file: #{t_file} t_insert: #{t_load_data}"
end

def oar_truncate_resources
#  DB << "
  rst_id = ""
  rst_id = "RESTART IDENTITY" if $PG
  requests = "
    TRUNCATE resources #{rst_id};
    TRUNCATE resource_logs #{rst_id};
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

##
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

##
# Remove previous allocations 
# Sets command field by sleep with job execution time as argument and jobs' state to hold.
# Returns array which contains job_ids and corresponding submission times begin from 0 (first submitted job)
def oar_jobs_sleepify(user=ENV['USER'])
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
# new to add user switching
    $dbh.execute("UPDATE jobs  
      SET
        command = 'sleep #{execution_time}',
        launching_directory = '/tmp',
        stdout_file= '/tmp/oar.#{j[0]}.out',
        stderr_file= '/tmp/oar.#{j[0]}.err',
        job_user = '#{user}' 
      WHERE
        job_id =  #{j[0]}")
  end
  res.finish
  return resume_seq
end

def oar_replay(sequence,user=ENV['USER'])
  #  RestClient.post 'http://kameleon:kameleon@localhost/oarapi-priv/jobs/1/resumptions/new.yaml','' 
  ref_time = Time.now.to_f + 1
  #puts "ref_time: #{ref_time}"
  sequence.each do |step|
    job_id, release_time = step
    time2sleep =  release_time - (Time.now.to_f - ref_time)
    sleep time2sleep if (time2sleep > 0)
    puts  "Release job:#{job_id} error_release_time: #{Time.now.to_f - ref_time - release_time}"
    #puts "Release job:#{job_id} release_time: #{release_time} effective_release_time: #{Time.now.to_f - ref_time}"
    if user=="kameleon" 
      RestClient.post "http://kameleon:kameleon@localhost/oarapi-priv/jobs/#{job_id}/resumptions/new.yaml",''
    else
      RestClient.post "http://localhost/oarapi/jobs/#{job_id}/resumptions/new.yaml",''
    end
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


def oar_jobs_overlap_after_scheduling?(security_time=60)
  puts "oar_jobs_overlap_after_scheduling?"
  puts "/!\\ BE CAREFULL, we suppose moldable_id == job id /!\\"
  puts "Security_time: #{security_time}"

  #Get already scheduled (with  running, launching or tolaunch jobs)

  q1 = "SELECT j.job_id, g2.start_time, m.moldable_walltime, g1.resource_id, j.state,m.moldable_id
        FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, moldable_job_descriptions m, jobs j
        WHERE
         m.moldable_index = 'CURRENT'
         AND g1.moldable_job_id = g2.moldable_job_id
         AND m.moldable_id = g2.moldable_job_id
         AND j.job_id = m.moldable_job_id
        ORDER BY j.start_time, j.job_id;"

  puts "We're scanning 'Running' jobs"
  r1 = $dbh.execute(q1)
  end_time={}
  sched_ressources = {}

  r1.each do |r|
    if end_time[r[0]].nil?
      end_time[r[0]] =  r[1] + r[2] + security_time
      sched_ressources[r[0]] = []
      raise "/!\\ job_id not equal to .moldable_id : #{r[0]} #{r[5]}" if r[0] != r[5] 
    end
    sched_ressources[r[0]] << r[3]
  end
  #
  # Get newly_scheduled jobs
  # 
  n_start_time={}
  n_sched_ressources = {}
  puts "/!\\ Get scheduled job information. BE CAREFULL, we suppose moldable_id == job id /!\\"
  q2 = "SELECT moldable_job_id, start_time FROM gantt_jobs_predictions"
  r2 = $dbh.execute(q2)
  r2.each do |r|
    n_start_time[r[0]] = r[1]
    n_sched_ressources[r[0]] = []
  end
  r2.finish

# TODO TOREMOVE ???
#  q3 = "SELECT moldable_job_id,resource_id FROM gantt_jobs_resources"
#  r3 = $dbh.execute(q3)
#  r3.each do |r|
#    sched_ressources[r[0]] << r[1]
#  end
#  r3.finish

  puts "test overlapping"
  #iterate on newly scheduled job
  n_start_time.each do |jid,start_time|
    #iterate on "running" job
    end_time.each do |r_jid,e_time|
      if (e_time > start_time)
        #test resources overlap
        if (n_sched_ressources[jid] & sched_ressources[r_jid])!=[]
          puts "jobs overlapping #{rjid} #{jid}"
          pp [r_jid, end_time, sched_ressources[r_jid]]
          pp [jid, start_time, n_sched_ressources[jid]]
        end
      end  
    end
  end
  puts "oar_jobs_overlap_after_scheduling? end"
end

#
# oar_sleepy: populate db from dump (oar.ocaml.12res.20110323.sql), reset jobs' state to wainting, set scheduler to ocaml and re
#
def oar_sleepfy 
  puts "/!\\ BE CAREFULL, not portable action...surely it'll fail /!\\"
  oar_sql_file("/home/auguste/prog/test_oar_sched/oar.ocaml.12res.20110323.sql")
  oar_sql_file("/home/auguste/oar/sources/core/database/mysql_default_admission_rules.sql")
  $dbh.execute("UPDATE queues SET scheduler_policy='simple_cbf_mb_h_ct_oar_mysql', state='Active' WHERE queue_name='default'").finish
  return oar_jobs_sleepify
end

def oar_fairsharing_test sched
  #TODO test if oar running
  puts "Be carefull be sure to oar-server is stopped"
  now = Time.now.to_i
  oar_db_clean
  users = []
  if false
    oar_sql_file("/home/auguste/prog/test_oar_sched/oar_foehn+nanostar-accounting.sql")
    users = ["debreu","pianezj","lebacq","gallee","drouet","wiesenfe","meunie8x","thibert","chardon","lafaysse"]
  else
    10.times do |u|
      user = "zozo"+u.to_s
      users.push user
      10.times do |i|
        j = 24 * 36000
        w_start = now - j*(i+1)
        w_stop = now -  j*(i+1) + j/10
        consum = 100000 * (10-u)   
        sth = $dbh.execute("insert into accounting (window_start,window_stop,accounting_user,accounting_project,queue_name,consumption_type,consumption) values (#{w_start},#{w_stop},'#{user}','default','default','USED',#{consum})")
        sth.finish
        sth = $dbh.execute("insert into accounting (window_start,window_stop,accounting_user,accounting_project,queue_name,consumption_type, consumption) values (#{w_start},#{w_stop},'#{user}','default','default','ASKED',#{consum})")
        sth.finish
      end 
    end
  end
  #add ressources
  nb_r = 12
  oar_resource_insert({:nb_resources=>nb_r})
  #add jobs
  jids = []
  users.each do |u|
    puts "add job for user: #{u}"
    5.times do
      jids.push oar_job_insert(:res=>"resource_id=#{nb_r}",:walltime=> 300, :user=>u)
    end
  end
  puts jids
  #execute sched
  sched_cmd = 'OARCONFFILE="/etc/oar/oar.conf" '+ sched + " default #{Time.now.to_i}" 
  puts "Launch sched: #{sched}"
  puts "cmd: #{sched_cmd}"
  system sched_cmd

  res=$dbh.execute("SELECT * FROM gantt_jobs_predictions")
  h_job_time = {}
  res.each do |r|
    h_job_time[r[0]]=r[1]
  end
  job_time_sorted = h_job_time.sort_by { |id, t_start| t_start }
  return job_time_sorted
end

##
# strip oar.conf: remove test config from /etc/oar/oar.conf to /tmp/oar.conf
#
def oar_strip_config
  system("rm /tmp/oar.conf")
  oar_tmp = File.open("/tmp/oar.conf", "w")
  end_tag = "#BEGIN TEST CONFIGURATION"
  File.open("/etc/oar/oar.conf").each do |line|
    break if line =~ /#{end_tag}/
    oar_tmp.puts line
  end
  oar_tmp.puts end_tag
  oar_tmp.close
  system "sudo sh -c 'cat /tmp/oar.conf_tmp >  /etc/oar/oar.conf'"
end


##
#  displays predicted startime 
# 
#  todo: display resources
def oar_get_job_pred(job_id)
  startime = $dbh.execute("SELECT start_time FROM gantt_jobs_predictions WHERE moldable_job_id=#{job_id}")
  puts "Job id: #{job_id} startime=#{startime.first}    /!\\ Be careful it's assumed that moldable_job_id=job_id, no moldable support"
  return startime
end


##
#
# convert unix time to string (equiv. to Time.at(t))
#
def oar_time(t)
  return Time.at(t)
end

oar_load_test_config
oar_db_connect

if defined?(Pry)=="constant"
  binding.pry :quiet => true
end

if ($0=='irb')
  puts 'irb session detected, db connection launched'
elsif (/oar_db_setting/ =~ $0)
  puts "oar_db_setting used as command"
  eval(ARGV[0])
end

# 50.times do |i| oar_job_insert(:res=>"resource_id=#{i}",:walltime=> 300) end

