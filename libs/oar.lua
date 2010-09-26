-- 
-- a oarlib draft for lua modules and tools
--
-- TODO:
--   postgresql support

require "luasql.mysql"
oar= {}
local env, con

oar.conf={}
-- TODO change oar.conf location
-- oar_confile_name = "/etc/oar/oar.conf"
oar_confile_name = "/home/auguste/prog/oar/trunk/tools/oar.conf"

-- lazy programmed table printers
function oar.print_table(t)
  for k,v in pairs(t) do
    print(k..'->'..v)
  end
end

function oar.print_tt(t)
  for k,v in pairs(t) do
    print(">>>"..k)
    oar.print_table(v)
  end
end

--
-- Load oar.conf and intialize configuration variables (oar.conf
--
function oar.conf_load()
  local f = assert(io.open(oar_confile_name, "r"))
--  local oar_confile = f:read("*all")
  local key
  local value

  if #oar.conf==0 then -- test conf is already loaded
    while true do
      local line = f:read()
      if line == nil then break end
      if (not line:match("^%s*#")) and (line:match("%S")) then -- ignore comments which begins by #
        a,b,key,value = line:find("(%S+)%s*=%s*(%S+)")
        a,b,c = value:find("\"(%S+)\"")
        if a then
          value = c
        else
          a,b,c = value:find("'(%S+)'")
          if a then
            value = c
          end
        end

        oar.conf[key] = value
      end
    end
    f:close()
  end
end

function oar.config_dump()
  for k,v in pairs(oar.conf) do
    print(k,v)
  end
end


--
-- connect to db
--
function oar.connect()
  -- create environment object
  
  env = assert (luasql.mysql())

  local db_host = oar.conf["DB_HOSTNAME"] 
  local db_name = oar.conf["DB_BASE_NAME"]
  local db_user = oar.conf["DB_BASE_LOGIN"]
  local db_passwd = oar.conf["DB_BASE_PASSWD"]
  local db_port = oar.conf["DB_PORT"]

  assert(oar.conf["DB_TYPE"]=="mysql")

  -- connect to data source
  con = assert (env:connect(db_name,db_user,db_passwd,db_host,db_port))
end

function oar.disconnect()
  con:close()
  env:close()
end

-- usefull iterator
function oar.rows (sql_statement)
  print(sql_statement)
  local cursor = assert (con:execute (sql_statement))
  return function ()
    return cursor:fetch({})
  end
end

-- set_all_job_toLaunch (for dev and debug use only)
function oar.set_all_jobs_toLaunch()
  assert (con:execute"UPDATE jobs SET state='toLaunch'")
end

function oar.sql(query)
  assert (con:execute(query))
end





-- get waiting job with first  resource request (no moldable support)  
-- return an hash table key -> job_ids, value -> jobs description  
function oar.get_waiting_jobs_no_moldable(queue)

  if not queue then queue = "default" end

  local waiting_jobs = {}
  local query = "SELECT jobs.job_id, moldable_job_descriptions.moldable_walltime, jobs.properties , moldable_job_descriptions.moldable_id, job_resource_descriptions.res_job_resource_type, job_resource_descriptions.res_job_value, job_resource_descriptions.res_job_order, job_resource_groups.res_group_property FROM moldable_job_descriptions, job_resource_groups, job_resource_descriptions, jobs \
    WHERE \
      moldable_job_descriptions.moldable_index = 'CURRENT' \
      AND job_resource_groups.res_group_index = 'CURRENT' \
      AND job_resource_descriptions.res_job_index = 'CURRENT' \
      AND jobs.state = 'Waiting' \
      AND jobs.queue_name =  '" .. queue .. "' \
      AND jobs.reservation = 'None' \
      AND jobs.job_id = moldable_job_descriptions.moldable_job_id \
      AND job_resource_groups.res_group_index = 'CURRENT' \
      AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id \
      AND job_resource_descriptions.res_job_index = 'CURRENT' \
      AND job_resource_descriptions.res_job_group_id = job_resource_groups.res_group_id \
      ORDER BY moldable_job_descriptions.moldable_id, job_resource_groups.res_group_id, job_resource_descriptions.res_job_order ASC;"

  for row in oar.rows(query) do
    waiting_jobs[row[1]]=row
  end
  return waiting_jobs
end

-- get waiting job with first  resource request (no moldable support)  
-- return an hash table key -> job_ids, value -> jobs description  
function oar.get_waiting_jobs_black_maria(queue)

  if not queue then queue = "default" end

  local waiting_jobs = {}

  -- note: jobs.scheduler_info = '' below is use to filter job already submited to foreign JRMS
  local query = "SELECT jobs.job_id, moldable_job_descriptions.moldable_walltime, jobs.properties , moldable_job_descriptions.moldable_id, job_resource_descriptions.res_job_resource_type, job_resource_descriptions.res_job_value, job_resource_descriptions.res_job_order, job_resource_groups.res_group_property FROM moldable_job_descriptions, job_resource_groups, job_resource_descriptions, jobs \
    WHERE \
      moldable_job_descriptions.moldable_index = 'CURRENT' \
      AND job_resource_groups.res_group_index = 'CURRENT' \
      AND job_resource_descriptions.res_job_index = 'CURRENT' \
      AND jobs.state = 'Waiting' \
      AND jobs.scheduler_info = '' \ 
      AND jobs.queue_name =  '" .. queue .. "' \
      AND jobs.reservation = 'None' \
      AND jobs.job_id = moldable_job_descriptions.moldable_job_id \
      AND job_resource_groups.res_group_index = 'CURRENT' \
      AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id \
      AND job_resource_descriptions.res_job_index = 'CURRENT' \
      AND job_resource_descriptions.res_job_group_id = job_resource_groups.res_group_id \
      ORDER BY moldable_job_descriptions.moldable_id, job_resource_groups.res_group_id, job_resource_descriptions.res_job_order ASC;"

  for row in oar.rows(query) do
    waiting_jobs[row[1]]=row
  end
  return waiting_jobs
end

-- update scheduler_info field for a set of jobs
function oar.set_scheduler_message_range(j_ids,msg)
  local job_ids = ""
  for i,j_id in ipairs(a) do
    job_ids = job_ids .. j_id .. ','
  end
  job_ids = string.sub(job_ids, 1, -2) --chomp the last ','
  local query = "UPDATE jobs SET scheduler_info='"..msg.."' WHERE job_id IN ("..job_ids.. ")"
  assert (con:execute(query))
end

-- retreive resource_ids by node 
function oar.get_nodes_resources_black_maria()
  local nodes_resources = {}
  local query = "SELECT resource_id, network_address FROM resources"
  for row in oar.rows(query) do
    local n = row[1]
    local r_id = row[2]
    if nodes_resources[n] then
      nodes_resources[n][#nodes_resources[n]+1] = r_id
    else
      nodes_resources[n]={r_id}
    end
  end
  return nodes_resources
end

-- save resources assignemet for one job  
function save_assign_black_maria(job)
--[[
-- TODO intearction with metascheduler ? gantt prediction / visualisation/
-- set start time
-- 
"INSERT INTO  gantt_jobs_predictions  (moldable_job_id,start_time) VALUES "^ (moldable_job_id_start_time job) in
end
