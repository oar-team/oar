require "oar"
require "pp"
-- TODO: 

-- 1)

--  black-maria-notify -> notify job starting to black-maria-notify (foreign-jrms-nodefile, oar-jobidi, oar-modlable,... in json format ???)
--  black-maria-synch ->  set node allocated by foreign jrms to oar

submitted_jobs = {}

-- index correspondance for job's attributs in return of get_waiting_jobs_black_maria function 
j_id= 1
walltime = 2
nb_res = 4
modalble_id = 5


function get_job_to_execute()
end

-- Submit job on foreign LRMS
-- Jobs are submitted sequentially. It's made the assumption that there not a lot of these kind of job at a given time. 
-- TODO: a connector for each supported LRMS (priority to SLUMR)
function submit_to_jrms(jobs_to_launch)
  local job_ids = {}
  local submit_cmd_part1 = "./sbatch -N"
  local submit_cmd_part2 = " -l black_maria_pilot.sh "
  for i,job in ipairs(jobs_to_launch) do
    job_ids[i] = job[j_id]
    print("BKM: submit job to LRMS")
    local cmd = submit_cmd_part1 .. job[nb_res] .. submit_cmd_part2 ..
                job[j_id] .." ".. 
                job[walltime] .." "..
                job[modalble_id]
                
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

oar.conf_load()
oar.connect()


--waiting_jobs = oar.get_waiting_jobs_no_moldable(queue)
waiting_jobs = oar.get_waiting_jobs_black_maria(queue) 
dumptable(waiting_jobs)

print(waiting_jobs[1][2])
submit_to_jrms(waiting_jobs)
