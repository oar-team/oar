
require 'sequel'

DB = Sequel.mysql(
  "oar",
  :user=>"oar",
  :password=>"oar",  
  :host => "localhost"  
 )
DEFAULT_QUEUE = "default"
DEFAULT_WALLTIME = 7200
DEFAULT_RES = "resource_id=1"
DEFAULT_PROPERTIES = ""
DEFAULT_TYPES = nil

$jobs = DB[:jobs]
$moldable = DB[:moldable_job_descriptions]
$job_resource_groups = DB[:job_resource_groups]
$job_resource_description = DB[:job_resource_descriptions]
$job_types = DB[:job_types]
$resources = DB[:resources]

def oar_job_insert(args={})
  res = DEFAULT_RES
  walltime = DEFAULT_WALLTIME
	queue = DEFAULT_QUEUE
  properties = DEFAULT_PROPERTIES
  types = DEFAULT_TYPES

  if !args[:res].nil?
    res = args[:res]
  end
  if !args[:walltime].nil?
    walltime = args[:walltime]
  end
  if !args[:queue].nil?
    queue = args[:queue]
  end
  if !args[:properties].nil?
    properties = args[:properties]
  end
  if !args[:types].nil?
    types = args[:types]
  end


  job_id = $jobs.insert(:job_name=>"yop", :state => "Waiting", :queue_name => queue, :properties => properties)

  moldable_id = $moldable.insert(:moldable_job_id => job_id, :moldable_walltime => walltime)

  res.split("+").each do |r|
    res_group_id =	$job_resource_groups.insert(:res_group_moldable_id => moldable_id, :res_group_property => "type = 'default'")
    r.split('/').each_with_index do |type_value,order|
      type,value = type_value.split('=')
      $job_resource_description.insert(:res_job_group_id => res_group_id, :res_job_resource_type => type, :res_job_value => value.to_i, :res_job_order => order.to_i)
    end  
  end

  #job's types insertion
  if !types.nil?
    types.split(',').each do |type|
      $job_types.insert(:job_id => job_id, :type => type)
    end
  end

  return job_id
end

def oar_empty_jobs
  $jobs.delete
  $moldable.delete
  $job_resource_groups.delete
  $job_resource_description.delete
end

def oar_truncate_jobs
  DB << "
    TRUNCATE `accounting`;
    TRUNCATE `assigned_resources`;
    TRUNCATE `challenges`;
    TRUNCATE `event_logs`;
    TRUNCATE `event_log_hostnames`;
    TRUNCATE `files`;
    TRUNCATE `frag_jobs`;
    TRUNCATE `gantt_jobs_predictions`;
    TRUNCATE `gantt_jobs_predictions_log`;
    TRUNCATE `gantt_jobs_predictions_visu`;
    TRUNCATE `gantt_jobs_resources`;
    TRUNCATE `gantt_jobs_resources_log`;
    TRUNCATE `gantt_jobs_resources_visu`;
    TRUNCATE `jobs`;
    TRUNCATE `job_dependencies`;
    TRUNCATE `job_resource_descriptions`;
    TRUNCATE `job_resource_groups`;
    TRUNCATE `job_state_logs`;
    TRUNCATE `job_types`;
    TRUNCATE `moldable_job_descriptions`;
    TRUNCATE `resource_logs`;
  "
end

def oar_update_visu
  DB << "DELETE FROM gantt_jobs_predictions_visu"
  DB << "DELETE FROM gantt_jobs_resources_visu"
  DB << "INSERT INTO gantt_jobs_predictions_visu SELECT * FROM gantt_jobs_predictions"
  DB << "INSERT INTO gantt_jobs_resources_visu SELECT * FROM gantt_jobs_resources"
end

def oar_sql_file file_name
  DB << File.open(file_name, "r").read
end

puts "DB connection up"

