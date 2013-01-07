-- 
-- a oarlib draft for lua modules and tools
--
-- TODO:
--   postgresql support

luasql = require "luasql.mysql"
oar= {}
log_level = 2
log_file = "/var/log/oar.log"
local env, con

oar.conf={}
-- TODO change oar.conf location
oar_confile_name = "/etc/oar/oar.conf"
--oar_confile_name = "/home/auguste/prog/oar/trunk/tools/oar.conf"

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
function oar.init()
  oar.conf_load()
  oar.connect()
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

  if oar.conf["LOG_LEVEL"] then log_level = oar.conf["LOG_LEVEL"] end
  if oar.conf["LOG_FILE"] then log_file = oar.conf["LOG_FILE"] end
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
--  print(sql_statement)
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
  print(query)
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
  local query = "SELECT jobs.job_id, moldable_job_descriptions.moldable_walltime, jobs.properties , moldable_job_descriptions.moldable_id, job_resource_descriptions.res_job_resource_type, job_resource_descriptions.res_job_value, jobs.job_user FROM moldable_job_descriptions, job_resource_groups, job_resource_descriptions, jobs \
    WHERE \
      moldable_job_descriptions.moldable_index = 'CURRENT' \
      AND job_resource_groups.res_group_index = 'CURRENT' \
      AND job_resource_descriptions.res_job_index = 'CURRENT' \
      AND jobs.state = 'Waiting' \
      AND jobs.scheduler_info = ''\
      AND jobs.queue_name =  '" .. queue .. "' \
      AND jobs.reservation = 'None' \
      AND jobs.job_id = moldable_job_descriptions.moldable_job_id \
      AND job_resource_groups.res_group_index = 'CURRENT' \
      AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id \
      AND job_resource_descriptions.res_job_index = 'CURRENT' \
      AND job_resource_descriptions.res_job_group_id = job_resource_groups.res_group_id \
      ORDER BY moldable_job_descriptions.moldable_id, job_resource_groups.res_group_id, job_resource_descriptions.res_job_order ASC;"

  local i =1
  for row in oar.rows(query) do
    waiting_jobs[i]=row
    i = i + 1
  end
  return waiting_jobs
end

-- update scheduler_info field for a set of jobs
function oar.set_scheduler_message_range(j_ids,msg)
  local job_ids = ""
  for i,j_id in ipairs(j_ids) do
    job_ids = job_ids .. j_id .. ','
  end
  job_ids = string.sub(job_ids, 1, -2) --chomp the last ','
  local query = "UPDATE jobs SET scheduler_info='"..msg.."' WHERE job_id IN ("..job_ids.. ")"
  print(query)
  assert (con:execute(query))
end

-- retrieve resource_ids by node 
function oar.get_nodes_resources_black_maria()
  local nodes_resources = {}
  local query = "SELECT resource_id, network_address FROM resources"
  for row in oar.rows(query) do
    local n = row[2]
    local r_id = row[1]
    if nodes_resources[n] then
      nodes_resources[n][#nodes_resources[n]+1] = r_id
    else
      nodes_resources[n]={r_id}
    end
  end
  return nodes_resources
end

-- retrieve resource_ids by node 
function oar.get_hierarchy()
  local i=0
  local id=0
  local values={}
  local value_ordered={}  
  local hy_id = {} -- store list of id by value
  local  query = "SELECT resource_id, network_address FROM resources"
  for row in oar.rows(query) do
    i=i+1
    local value = row[1]
    --print(value,row[2])
    if not values[value] then
      values[value] = 1 -- to remember it 
      table.insert(value_ordered,value) -- to remember order
      hy_id[value] = {}
    end
    table.insert(hy_id[value],i)
  end
  print(i)
  return value_ordered,hy_id
end

-- ocaml (string * Interval.interval list list) list


-- set_assigned_moldable_job
-- sets the assigned_moldable_job field to the given value
function oar.set_assigned_moldable_job(job_id,moldable_job_id)
  local query = "UPDATE jobs SET assigned_moldable_job =" .. moldable_job_id ..
                 "WHERE job_id = " .. job_id ..")"
  assert(con:execute(query))
end

-- save resources assignemet for one job  
function oar.save_assignements_black_maria(moldable_job_id,resource_ids)

  local values = ""
  for i,r_id in ipairs(resource_ids) do
    values = values ..'('.. moldable_job_id .. ',' .. r_id .. ',\'CURRENT\'),' 
  end

  values = string.sub(values, 1, -2) --chomp the last ','
  local query = "INSERT INTO assigned_resources (moldable_job_id,resource_id,assigned_resource_index) VALUES " .. values
  assert (con:execute(query))
end

---
--- helper section
---
 
-- white space split string function returns multiple strings
function oar.wssplit(text, start)
  local s,e,word = string.find(text, "(%S+)", start or 1)
  if s then return word, oar.wssplit(text, e+1); end
end

-- white space split string function, returns a table
function oar.tsplit(str) 
  local t = {}
  local function helper(word) table.insert(t, word) return "" end
  if not str:gsub("%S+", helper):find"%S" then return t end
end

function oar.write_log(msg)
  -- TODO 
  print(msg)
end

function oar.debug(msg)
  if log_level > 2 then
    oar.write_log('[debug] '..msg)
  end
end

function oar.warn(msg)
  if log_level > 1 then
    oar.write_log('[info] '..msg)
  end
end

function oar.error(msg)
  oar.write_log('[error] '..msg)
end

---
--- this code come from lua's wiki site
--- http://lua-users.org/wiki/SortedIteration
---


--------------------------------------
-- Insert value of any type into array
--------------------------------------
local function arrayInsert( ary, val, idx )
    -- Needed because table.insert has issues
    -- An "array" is a table indexed by sequential
    -- positive integers (no empty slots)
    local lastUsed = #ary + 1
    local nextAvail = lastUsed + 1

    -- Determine correct index value
    local index = tonumber(idx) -- Don't use idx after this line!
    if (index == nil) or (index > nextAvail) then
        index = nextAvail
    elseif (index < 1) then
        index = 1
    end

    -- Insert the value
    if ary[index] == nil then
        ary[index] = val
    else
        -- TBD: Should we try to allow for skipped indices?
        for j = nextAvail,index,-1 do
            ary[j] = ary[j-1]
        end
        ary[index] = val
    end
end

--------------------------------
-- Compare two items of any type
--------------------------------
local function compareAnyTypes( op1, op2 ) -- Return the comparison result
    -- Inspired by http://lua-users.org/wiki/SortedIteration
    local type1, type2 = type(op1),     type(op2)
    local num1,  num2  = tonumber(op1), tonumber(op2)
    
    if ( num1 ~= nil) and (num2 ~= nil) then  -- Number or numeric string
        return  num1 < num2                     -- Numeric compare
    elseif type1 ~= type2 then                -- Different types
        return type1 < type2                    -- String compare of type name
    -- From here on, types are known to match (need only single compare)
    elseif type1 == "string"  then            -- Non-numeric string
        return op1 < op2                        -- Default compare
    elseif type1 == "boolean" then
        return op1                              -- No compare needed!
         -- Handled above: number, string, boolean
    else -- What's left:   function, table, thread, userdata
        return tostring(op1) < tostring(op2)  -- String representation
    end
end

-------------------------------------------
-- Iterate over a table in sorted key order
-------------------------------------------
local function pairsByKeys (tbl, func)
    -- Inspired by http://www.lua.org/pil/19.3.html
    -- and http://lua-users.org/wiki/SortedIteration

    if func == nil then
        func = compareAnyTypes
    end

    -- Build a sorted array of the keys from the passed table
    -- Use an insertion sort, since table.sort fails on non-numeric keys
    local ary = {}
    local lastUsed = 0
    for key --[[, val--]] in pairs(tbl) do
        if (lastUsed == 0) then
            ary[1] = key
        else
            local done = false
            for j=1,lastUsed do  -- Do an insertion sort
                if (func(key, ary[j]) == true) then
                    arrayInsert( ary, key, j )
                    done = true
                    break
                end
            end
            if (done == false) then
                ary[lastUsed + 1] = key
            end
        end
        lastUsed = lastUsed + 1
    end

    -- Define (and return) the iterator function
    local i = 0                -- iterator variable
    local iter = function ()   -- iterator function
        i = i + 1
        if ary[i] == nil then
            return nil
        else
            return ary[i], tbl[ary[i]]
        end
    end
    return iter
end



---------------------------------------------
-- Return indentation string for passed level
---------------------------------------------
local function tabs(i)
    return string.rep(".",i).." "   -- Dots followed by a space
end

-----------------------------------------------------------
-- Return string representation of parameter's value & type
-----------------------------------------------------------
local function toStrType(t)
    local function fttu2hex(t) -- Grab hex value from tostring() output
        local str = tostring(t);
        if str == nil then
            return "tostring() failure! \n"
        else
            local str2 = string.match(str,"[ :][ (](%x+)")
            if str2 == nil then
                return "string.match() failure: "..str.."\n"
            else
                return "0x"..str2
            end
        end
    end
    -- Stringify a value of a given type using a table of functions keyed
    -- by the name of the type (Lua's version of C's switch() statement).
    local stringify = {
        -- Keys are all possible strings that type() may return,
        -- per http://www.lua.org/manual/5.1/manual.html#pdf-type.
        ["nil"]     = function(v) return "nil (nil)"          end,
        ["string"]    = function(v) return '"'..v..'" (string)'     end,
        ["number"]    = function(v) return v.." (number)"         end,
        ["boolean"]   = function(v) return tostring(v).." (boolean)"  end,
        ["function"]  = function(v) return fttu2hex(v).." (function)" end,
        ["table"]   = function(v) return fttu2hex(v).." (table)"  end,
        ["thread"]    = function(v) return fttu2hex(v).." (thread)" end,
        ["userdata"]  = function(v) return fttu2hex(v).." (userdata)" end
    }
    return stringify[type(t)](t)
end



-------------------------------------
-- Count elements in the passed table
-------------------------------------
local function lenTable(t)    -- What Lua builtin does this simple thing?
    local n=0                   -- '#' doesn't work with mixed key types
    if ("table" == type(t)) then
        for key in pairs(t) do  -- Just count 'em
            n = n + 1
        end
        return n
    else
        return nil
    end
end

--------------------------------
-- Pretty-print the passed table
--------------------------------
local function do_dumptable(t, indent, seen)
    -- "seen" is an initially empty table used to track all tables
    -- that have been dumped so far.  No table is dumped twice.
    -- This also keeps the code from following self-referential loops,
    -- the need for which was found when first dumping "_G".
    if ("table" == type(t)) then  -- Dump passed table
        seen[t] = 1
        if (indent == 0) then
            print ("The passed table has "..lenTable(t).." entries:")
            indent = 1
        end
        for f,v in pairsByKeys(t) do
            if ("table" == type(v)) and (seen[v] == nil) then    -- Recurse
                print( tabs(indent)..toStrType(f).." has "..lenTable(v).." entries: {")
                do_dumptable(v, indent+1, seen)
                print( tabs(indent).."}" )
            else
                print( tabs(indent)..toStrType(f).." = "..toStrType(v))
            end
        end
    else
        print (tabs(indent).."Not a table!")
    end
end

--------------------------------
-- Wrapper to handle persistence
--------------------------------
function dumptable(t)   -- Only global declaration in the package
    -- This wrapper exists only to set the environment for the first run:
    -- The second param is the indentation level.
    -- The third param is the list of tables dumped during this call.
    -- Getting this list allocated and freed was a pain, and this
    -- wrapper was the best solution I came up with...
    return do_dumptable(t, 0, {})
end

--------------
--------------
--
-- copy table function from lua-users.oar/wiki
-- http://lua-users.org/wiki/CopyTable
--

function oar.deepcopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

-- array2itv
function oar.array2itvs(a)
  local b
  local e
  local ary_b={}
  local ary_e={}
  table.sort(a)
  b=a[1]
  e=b
  for i,v in ipairs(a) do
    if (v-e>1) then
      table.insert(ary_b,b)
      table.insert(ary_e,e)
      b=v
    end
    e=v
  end
  table.insert(ary_b,b)
  table.insert(ary_e,e)
  return ary_b,ary_e
end  

--[[
-- The Whole Enchillada
print("\ndumptable(_G=", _G, "):")
dumptable(_G)

-- Empty table --
print("\ndumptable({}):")
dumptable({})

-- Module table --
print("\ndumptable(os=", os, "):")
dumptable(os)

]]--
