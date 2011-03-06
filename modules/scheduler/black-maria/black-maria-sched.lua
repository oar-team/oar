require "oar"

oar.conf_load()
oar.connect()

submitted_jobs = {}

if not oar.conf["BKM_SYNC_HOST"] then
  bkm_sync_host = oar.conf["SERVER_HOSTNAME"] 
else
  bkm_sync_host = oar.conf["BKM_SYNC_HOST"]
end

if not oar.conf["BKM_SYNC_PORT"] then 
  bkm_sync_port = 2220
else
  bkm_sync_port = oar.conf["BKM_SYNC_PORT"]
end

-- index correspondance for job's attributs in return of get_waiting_jobs_black_maria function 
j_id= 1
walltime = 2
nb_res = 6
modalble_id = 4
user =  7
-- Submit job on foreign LRMS
-- Jobs are submitted sequentially. It's made the assumption that there not a lot of these kind of job at a given time. 
-- TODO: a connector for each supported JRMS (priority to SLURM)
function submit_to_jrms(jobs_to_launch)
  local job_ids = {}
  -- TODO must add oardodo user

  local submit_cmd_part1 = " sbatch_oardodo --workdir=/tmp/ -n"
  local submit_cmd_part2 = " black-maria-pilot.sh "
  for i,job in ipairs(jobs_to_launch) do
    local oardodo = "export OARDO_BECOME_USER="..job[user].."; oardodo "
    job_ids[i] = job[j_id]
    print("BKM: submit job to LRMS")
    local nb_nodes = job[nb_res]
    if oar.conf["BKM_RESOURCE_FACTOR"] then 
      nb_nodes = nb_nodes / oar.conf["BKM_RESOURCE_FACTOR"]
    end
    local cmd = oardodo ..
                submit_cmd_part1 .. nb_nodes .. 
                " -t " .. job[walltime]/60 .. ":10" .. -- TODO adapt for each RJMSand parametrize timeguard 10 seconds here
                submit_cmd_part2 ..
                bkm_sync_host .. " " ..
                bkm_sync_port .. " " ..
                job[j_id] .." " ..
                job[modalble_id] .. " " ..
                job[walltime]
--    cmd = "export OARDO_BECOME_USER=kameleon; oardodo yop1"           
    print("BKM: " .. cmd)

    f = assert  (io.popen (cmd)) -- TODO retrieve the exist status value
    for line in f:lines() do
      print(line) 
      -- retrieve foreign_jobid
      -- sbatch: Submitted batch job 469
      b,i,jid_jrms = line:find("sbatch.*%s(%d+)$")
      if b then
        print("Prout:" .. jid_jrms) 
        -- save serialize job info (
        break 
      end
    end
  end
-- update scheduler_info jobs' field to not to resubmit in next cycle
-- TODO: build job_ids

--  oar.set_scheduler_message_range(job_ids,"submitted to JRMS")
end

--
-- main
--

queue = "default"
if arg[1] then queue = arg[1] end

print("BKM-sched launched with queue: "..queue)

waiting_jobs = oar.get_waiting_jobs_black_maria(queue) 
dumptable(waiting_jobs)

if #waiting_jobs>0 then
  submit_to_jrms(waiting_jobs)
else
  print("BKM-sched: nothing to do")
end
