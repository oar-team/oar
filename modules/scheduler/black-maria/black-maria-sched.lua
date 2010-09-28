require "oar"

oar.conf_load()
oar.connect()

submitted_jobs = {}

if oar.conf["BKM_SYNC_HOST"]==nil then
  bkm_sync_host = oar.conf["SERVER_HOSTNAME"] 
else
  bkm_sync_host = oar.conf["BKM_SYNC_HOST"]
end

if oar.conf["BKM_SYNC_PORT"]==nil then 
  bkm_sync_port = 2220
else
  bkm_sync_port = oar.conf["BKM_SYNC_PORT"]
end

-- index correspondance for job's attributs in return of get_waiting_jobs_black_maria function 
j_id= 1
walltime = 2
nb_res = 4
modalble_id = 5

-- Submit job on foreign LRMS
-- Jobs are submitted sequentially. It's made the assumption that there not a lot of these kind of job at a given time. 
-- TODO: a connector for each supported JRMS (priority to SLURM)
function submit_to_jrms(jobs_to_launch)
  local job_ids = {}
  local submit_cmd_part1 = "./sbatch -N"
  local submit_cmd_part2 = " -l black_maria_pilot.sh "
  for i,job in ipairs(jobs_to_launch) do
    job_ids[i] = job[j_id]
    print("BKM: submit job to LRMS")
    -- TODO 
    -- TODO walltime for foreign JRMS
    -- TODO
    local cmd = submit_cmd_part1 .. job[nb_res] .. submit_cmd_part2 ..
                bkm_sync_host ..
                bkm_sync_port ..
                job[j_id] .." " ..
                job[modalble_id] .. "" ..
                job[walltime]
                
    print("BKM: " .. cmd)

    f = assert  (io.popen (cmd))
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

  oar.set_scheduler_message_range(job_ids,"submitted to JRMS")
end

--
-- main
--
queue = "default"
if arg[1] then queue = arg[1] end

waiting_jobs = oar.get_waiting_jobs_black_maria(queue) 
dumptable(waiting_jobs)

print(waiting_jobs[1][2])
submit_to_jrms(waiting_jobs)
