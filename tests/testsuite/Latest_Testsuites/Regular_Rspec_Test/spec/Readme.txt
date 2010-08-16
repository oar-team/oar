                     *****************************
                      Regular RSpec Testing Files
                     *****************************

Few Sample scenario spec files have been written. 
Similar procedure can be followed to write one's own test scenarios for APIs.

scenario1_spec.rb 
******************

Note: Give enough time for job to get removed from queue after it is deleted.
1.Submits a job and checks if submitted.
2.Tests the queue of running jobs if the submitted job is present.
3.Deletes the submitted job and checks if it is registered for deletion.
4.Tests if the job is no more listed in the queue of running jobs.

scenario2_spec.rb
******************

Note: Create an infiniteloop_script.sh 
1.Submits job that runs infinitely with 5mnts walltime, checks if submitted.
2.Test if the job is present in the queue of running jobs
3.Sleep for time little greater than the walltime i.e 5mnts
4.Test if the job is absent in queue as it is killed after the walltime 

scenario3_spec.rb
*****************

1.Submits a job, check if submitted
2.Test if job is present in the queue of running jobs
3.Checkpoint the job.
4.Test if the job has been checkpointed.
Note: The job must still be running when it is checkpointed.

scenario4_spec.rb
******************

1.Submit a job that runs for 2 minutes, check if submitted
2.Test if job is in the queue of running jobs
3.Test if the job is still running after 1 minute
Note: Submit a job that keeps running for 2 mintes.

scenario5_spec.rb
******************

Note: You need OAR/ROOT privileges for Holding and resuming jobs
1.Submit a job, check if submitted
2.Test if the job is present in the queue of running jobs
3.Hold the running job, check if job has been registered for hold.
4.Test if the job is absent in the queue of running jobs
5.Resume the held job, check if job registered to resume
6.Test if job is present in the queue of running jobs

Also Note: An alternative APIURI is needed for this scenario5 which is capable of both submitting jobs and resuming/holding running jobs. 



