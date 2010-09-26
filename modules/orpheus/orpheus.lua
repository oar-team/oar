--
--[[
SIGUSR1 signal triggers the get to 

No supported
 - Interactive Job
 - Killing job
 - Best effort (side effect of killing job capacity)

TODO:
* Pour le kill: le plus simple proposer une alternative de 
signal_oarexec($$$$$$$) dans oar_Tools.pm et modifier leon.pl pour l'appeler

* walltime (optional) only command !
* install/uninstall 
* arg (walltime)
* without signal (why?)
* Readme
* oar.conf
* Best effort / kill job
* testx
* oar.lua

DONE:


]]--

require "socket"
require "signal"
require "luasql.mysql"

-- some globals
chronos = {} -- array to keep end of execution time of jobs 

default_walltime  = 10

t0 = os.time()
n_last = 1 -- os.time - os.time() + 1 (for chronos indice
nb_launched_jobs = 0
nb_terminated_jobs = 0
nb_received_signals =0
nb_get_jobs = 0

almighty_port = 6666 -- TODO: must be extracted from oar.conf

-- create environment object
env = assert (luasql.mysql())
-- connect to data source
con = assert (env:connect("oar","oar","oar")) -- TODO: must be extracted from oar.conf

-- signal handler function use to notify orpheus that there are jobs to run
signal.signal("SIGUSR1", 
    function(n, i) 
      print("signal handler", n, i) 
      nb_received_signals = nb_received_signals +1
    end);

-- usefull iterator
function rows (connection, sql_statement)
  local cursor = assert (connection:execute (sql_statement))
  return function ()
    return cursor:fetch({})
  end
end

function split(text, start)
  local s,e,word = string.find(text, "(%S+)", start or 1)
  if s then return word, split(text, e+1); end
end

-- get pid of current orpheus process
function getpid()
  local fproc = io.open("/proc/self/stat","r")
  return split(fproc:read("*l"))
end

-- create the orpheus signal sender 
function create_signal_sender()
  local pid = getpid()
  os.execute("rm -f /tmp/orpheus_signal_sender; echo 'kill -s USR1 " .. pid .."' > /tmp/orpheus_signal_sender; chmod 755 /tmp/orpheus_signal_sender;")
end

-- set_all_job_toLaunch (for dev and debug use only)
function set_all_jobs_toLaunch()
  assert (con:execute"UPDATE jobs SET state='toLaunch'")
end

-- get job to launch + set running + insert in chronos
function get_jobs()
  local job_ids = ""
  local execution_time = default_walltime
  local command, arg_time 
  local ti = os.time() - t0 
  -- orpheus start_time for this get jobs cycle be carefull of SQL processing time it'll include in global time job execution 
  for row in rows(con,"SELECT job_id, command from jobs WHERE state='toLaunch'") do
    job_id = row[1]
    job_ids = job_ids .. job_id .. ','
    -- determine the execution time (if no arg_time take command as execution time else command
    if row[2] then 
      command, arg_time = split(row[2])
      if arg_time then
        execution_time = arg_time
      else
        execution_time = command
      end
    end

    i = ti + execution_time 
    if not chronos[i] then chronos[i] = {} end
    -- job id insert in stop_time
    chronos[i][#chronos[i]+1] = job_id
    -- job is running now !!!
    nb_launched_jobs = nb_launched_jobs + 1
  end
  job_ids = string.sub(job_ids, 1, -2) --chomp the last ','

  -- set job running
  -- p = "UPDATE jobs SET state='Running' WHERE job_id IN "..jobids
  -- print(p)
  assert (con:execute("UPDATE jobs SET state='Running' WHERE job_id IN ("..job_ids..')'))

end

function terminated_jobs()
  local n1 = os.time() - t0
  local terminated_jobs = 0
  local terminated_job_ids = "" 
  for i=n_last,n1 do
    if chronos[i] then
      for k,v in ipairs(chronos[i]) do
        print("terminated job_id: ",v,"i:",i)
        terminated_job_ids = terminated_job_ids  .. v .. ','
        terminated_jobs = terminated_jobs + 1
      end
      chronos[i]={} --bye bye job_ids 
    end
  end
  n_last = n1
  if terminated_jobs ~= 0 then
    nb_terminated_jobs = nb_terminated_jobs + terminated_jobs

    terminated_job_ids = string.sub(terminated_job_ids, 1, -2) --chomp the last ','
    -- update jobs oar db table and set stop time ??
    assert (con:execute("UPDATE jobs SET state='Terminated',stop_time='".. t0+n1 ..
                        "' WHERE job_id IN ("..terminated_job_ids..")"))
    -- send Scheduling command to almighty
    notify_almighty()
  end
end

-- notify jobs' termination
function notify_almighty()
  local client = socket.connect("localhost",almighty_port)
  client:send("Scheduling\n")
  client:close()
end

-- main loop
socket.select(nil,nil,1)
-- create orpheus_signal_sender (runner moduler must be a symlink to it)
create_signal_sender()

--set_all_jobs_toLaunch() -- only for dev and debug
--get_jobs()

-- select
k = 0
while true do

  socket.select(nil,nil,1)

  if (nb_received_signals > nb_get_jobs) then
--    set_all_jobs_toLaunch() -- ONLY for dev and debug
    get_jobs()
    nb_get_jobs = nb_received_signals 
  end

  terminated_jobs()
  if (k % 10) == 0 then
    print("nb_launched_jobs: ", nb_launched_jobs, 
          "nb_terminated_jobs: ", nb_terminated_jobs , 
          "nb_running_jobs: ", nb_launched_jobs-nb_terminated_jobs,
          "\nnb_recv_signal/nb_get_jobs", nb_received_signals, nb_get_jobs)
  end
  k = k +1
end

con:close()
env:close()



