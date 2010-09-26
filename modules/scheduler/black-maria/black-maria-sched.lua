require "oar"
require "pp"
-- TODO: 

-- 1)

--  black-maria-notify -> notify job starting to black-maria-notify (foreign-jrms-nodefile, oar-jobidi, oar-modlable,... in json format ???)
--  black-maria-synch ->  set node allocated by foreign jrms to oar

submitted_jobs = {}

function get_job_to_execute()
end

-- Submit job on foreign LRMS
-- Jobs are submitted sequentially. It's made the assumption that there not a lot of these kind of job at a given time. 
-- TODO: a connector for each supported LRMS (priority to SLUMR)
function submit_to_jrms(jobs_to_launch)
  local submit_cmd_part1 = "sbatch -N"
  local submit_cmd_part2 = " -l black_maria_pilot.sh "
  for i,job in ipair(jobs_to_launch) do

    print("BKM: submit job to LRMS")
    
    f = assert  (io.popen (submit_cmd_part1 .. job.nb_res .. 
                           submit_cmd_part2 .. job.walltime
                          )
                )
    for line in f:lines() do
      print(line) 
      -- retrieve foreign_jobid
      -- sbatch: Submitted batch job 469
      b,i,jid_jrms = line:find("sbatch.*%s(%d+)$")
      if b then
        
        -- save serialize job info
        break 
      end
    end

-- update scheduler_info jobs' field to not to resubmit in next cycle
-- TODO: build job_ids
  oar.set_scheduler_message_range(job_ids,"submitted to JRMS")
end

-- main

queue = "default"
if arg[1] then queue = arg[1]

waiting_jobs = oar.get_waiting_jobs_black_maria(queue) 

exit
submit_to_jrms(waiting_jobs)
