***********************************************************************************************************
***************************************Library Documentation***********************************************
***********************************************************************************************************

i) librspectests:

Class: Test

Methods:

  1. test_get_version                  - Testing the GET /version REST API
  2. test_get_timezone                 - Testing the GET /timezone REST API
  3. test_get_jobs_details             - Testing the GET /jobs/details REST API
  4. test_get_running_jobs             - Testing the GET /jobs REST API
  5. test_get_jobs_id (jid)            - Testing the GET /jobs/<ID> REST API
  6. test_job_in_queue(jid)            - Test to check if job is there in queue GET /jobs/details API
  7. test_job_notin_queue(jid)         - Test to check if job is deleted from queue using GET /jobs/details API
  8. test_get_jobs_table               - Testing the GET /jobs/table REST API
  9. test_submit_job (jhash)           - Testing the POST /jobs REST API
 10. test_jobs_delete_post (jid)       - Testing the POST /jobs/id/deletions/new REST API
 11. test_jobs_delete (jid)            - Testing the DELETE /jobs/<id> REST API
 12. test_get_resources                - Testing the GET /resources REST API
 13. test_get_resources_full           - Testing the GET /resources/full REST API
 14. test_job_rholds (jid)             - Testing the POST /jobs/<id>/rholds/new REST API
 15. test_job_hold (jid)	       - Testing the POST /jobs/<jobid>/holds/new REST API
 16. test_job_resumption (jid)         - Testing the POST /jobs/<id>/resumption/new REST API
 17. test_job_update (jid, actionhash) - Testing POST /jobs/<id>/ API (deleting use when browsers dont support DELETE)
 18. test_if_job_delete_updated (jid)  - Testing POST /jobs/<id>/ to see if job is updated with actionhash, Call this after calling above method
 19. test_job_checkpoint (jid)         - Testing the POST /jobs/<jobid>/checkpoints/new REST API
 20. test_job_running (jid)            - Testing if job is currently running                     - 



ii) librestapi:

Class: OarApis

Methods:

  1. get(api,uri)                      - GET REST OAR API; Function to get objects from the api
  2. post(api,uri,j)		       - POST REST OAR API; Function to create/delete/hold/resume objects through the api
  3. delete(api, uri)		       - DELETE REST OAR API; Function to Delete objects through the api
  4. oar_version		       - Gives version info & Timezone about OAR and OAR API/Server.
  5. oar_timezone		       - Gives the timezone of the OAR API server.
  6. full_job_details		       - List the current jobs & some details like assigned resources
  7. run_job_details                   - L ist currently running jobs
  8. specific_job_details(jobid)       - Get Details of a specific job
  9. dump_job_table		       - Dump the jobs table (only current jobs)
 10. submit_job(jhash)		       - Submits job
 11. del_job(jobid)                    - Delete job - POST /jobs/id/deletions/new
 12. send_checkpoint(jobid)            - Send checkpoint signal to a job
 13. hold_waiting_job(jobid)	       - Hold a Waiting job
 14. hold_running_job(jobid)           - Hold a Running job
 15. resume_hold_job(jobid)            - Resume a Holded job
 16. send_signal_job(jobid, signo)     - Send signal to a job with signalno.
 17. update_job(jobid, actionhash)     - Update a job
 18. resource_list_state               - Get list of Resources and state
 19. list_resource_details             - Get list of all the resources and all their details
 20. specific_resource_details(jobid)  - Get details of resources identified by an ID
 21. resource_of_nodes(netaddr)        - Get details about the resources belonging to the node identified by network address
 22. create_resource(rhash)            - Create Resource
 23. statechange_resource(jid,harray)  - Change the state of resources of a job
 24. delete_job(jobid)		       - Delete or kill a job using DELETE API
 25. delete_resource(resid)            - Delete the resource identified by id
 26. delete_resource_cpuset(node,cpuid)- Delete the resource corresponding to cpuset id on node node.
 
