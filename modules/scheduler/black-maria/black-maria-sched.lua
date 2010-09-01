require "oar"
require "table.save"


-- TODO: 
--  black-maria-notify -> notify job starting to black-maria-notify (foreign-jrms-nodefile, oar-jobidi, oar-modlable,... in json format ???)
--  black-maria-synch ->  set node allocated by foreign jrms to oar


submitted_jobs = {}

function get_job_to_execute()
end

-- Submit job on foreign JRMS
-- Jobs are submitted sequentially. It's made the assumption that there not a lot of these kinf of job. 
-- TODO: a connector for each supported JRMs
function submit_jobs(jobs_to_launch)
  local submit_cmd_part1 = "sbatch -N"
  local submit_cmd_part2 = " -l black_maria_container.sh "
  for i,job in ipair(jobs_to_launch) do
    
    f = assert  (io.popen (submit_cmd_part1 .. job.nb_res .. 
                           submit_cmd_part2 .. job.walltime
                          )
                )
    for line in f:lines() do
      print(line) 
      -- retrieve foreign_jobid
      -- sbatch: Submitted batch job 469
      b,i,jobid = line:find("sbatch.*%s(%d+)$")
      if b then
        jobid blabla
        break 
      end
    end
end

-- main

waiting_jobs = oar.get_waiting_jobs_black_maria() 

submit_jobs_to_foreign_lrms(waiting_jobs)
