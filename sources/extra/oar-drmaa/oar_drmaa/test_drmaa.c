/*
   simple test program based on different documentation gathered on the web
   to compile:
     gcc -g test_drmaa.c  -L.libs -loardrmaa -o test_drmaa

     export LD_LIBRARY_PATH=.libs
*/

#include <stdlib.h>

#include <drmaa.h>
extern const char *drmaa_control_to_str( int action ); /* ??? */

void instance_handling()
{
  char contact[DRMAA_CONTACT_BUFFER];
  char drm_system[DRMAA_DRM_SYSTEM_BUFFER];
  char drmaa_impl[DRMAA_DRM_SYSTEM_BUFFER];
  unsigned int major = 0;
  unsigned int minor = 0;

  drmaa_get_contact (contact, DRMAA_CONTACT_BUFFER, NULL,0);
  drmaa_get_DRM_system (drm_system, DRMAA_DRM_SYSTEM_BUFFER,NULL, 0);
  drmaa_get_DRMAA_implementation (drm_system, DRMAA_DRM_SYSTEM_BUFFER, NULL, 0);
  drmaa_version (&major, &minor, NULL, 0);
  printf ("Contact: %s\n", contact);
  printf ("DRM System: %s\n", drm_system);
  printf ("DRMAA Implementation: %s\n", drmaa_impl);
  printf ("Version: %d.%d\n", major, minor);
}
int
main ()
{
  char error[DRMAA_ERROR_STRING_BUFFER];
  int errnum = 0;
  char jobid[DRMAA_JOBNAME_BUFFER];
  char jobid_2[DRMAA_JOBNAME_BUFFER];
  
  /* Init Session */
  /* drmaa_init | oar_connect */
  errnum = drmaa_init ("localhost", error, DRMAA_ERROR_STRING_BUFFER);

  if (errnum != DRMAA_ERRNO_SUCCESS) 
  {
    fprintf (stderr, "Couldn't init DRMAA library: %s\n", error);
    return 1;
  }

  /* Do Stuff */
  /*instance handling*/
  //instance_handling();

  /* Allocate Job Template */
  drmaa_job_template_t *jt = NULL;

  errnum = drmaa_allocate_job_template (&jt, error,DRMAA_ERROR_STRING_BUFFER);
  if (errnum != DRMAA_ERRNO_SUCCESS) 
  {
    fprintf (stderr, "Couldn't allocate job template: %s\n", error);
    return 1;
  }

  char cmd1[]="/bin/sleep";
  char cmd2[]="exit";

  /* Job Templates */
  errnum = drmaa_set_attribute (jt, DRMAA_REMOTE_COMMAND, cmd2, error, DRMAA_ERROR_STRING_BUFFER);
  if (errnum != DRMAA_ERRNO_SUCCESS) 
  {
    fprintf (stderr, "Couldn't set remote command: %s\n", error);
    return 1;
  }

  /* set HOLD state at submission */
  errnum = drmaa_set_attribute(jt, DRMAA_JS_STATE, DRMAA_SUBMISSION_STATE_HOLD, NULL, 0);

  const char *args[2] = {"5", NULL};

  errnum = drmaa_set_vector_attribute (jt, DRMAA_V_ARGV, args, error, DRMAA_ERROR_STRING_BUFFER);
  if (errnum != DRMAA_ERRNO_SUCCESS) 
  {
    fprintf (stderr, "Couldn't set remote command args: %s\n", error);
    return 1;
  }

  /* Run Job */
  errnum = drmaa_run_job (jobid, DRMAA_JOBNAME_BUFFER, jt, error, DRMAA_ERROR_STRING_BUFFER);

  if (errnum != DRMAA_ERRNO_SUCCESS) 
  {
    fprintf (stderr, "Couldn't run job: %s\n", error);
    return 1;
  } else 
  {
    printf ("Your job has been submitted with id %s\n", jobid);
  }

  /* Run Job */
  /*
    errnum = drmaa_run_job (jobid_2, DRMAA_JOBNAME_BUFFER, jt, error, DRMAA_ERROR_STRING_BUFFER);
  */

  /* Get Job State */
  /**
   * The possible values of
   * a program's staus are:
   *   - DRMAA_PS_UNDETERMINED
   *   - DRMAA_PS_QUEUED_ACTIVE
   *   - DRMAA_PS_SYSTEM_ON_HOLD
   *   - DRMAA_PS_USER_ON_HOLD
   *   - DRMAA_PS_USER_SYSTEM_ON_HOLD
   *   - DRMAA_PS_RUNNING
   *   - DRMAA_PS_SYSTEM_SUSPENDED
   *   - DRMAA_PS_USER_SUSPENDED
   *   - DRMAA_PS_DONE
   *   - DRMAA_PS_FAILED
   * Terminated jobs have a status of DRMAA_PS_FAILED.
   */
  /*
  int remote_ps;
  errnum =  drmaa_job_ps(jobid, &remote_ps, error, DRMAA_ERROR_STRING_BUFFER);
  printf("drmaa_job_ps: job_id: %s job_ps: %d\n",jobid,remote_ps);



  errnum =  drmaa_job_ps(jobid, &remote_ps, error, DRMAA_ERROR_STRING_BUFFER);
  printf("2-drmaa_job_ps: job_id: %s job_ps: %d\n",jobid,remote_ps);
*/

  /* Conrol Job */
  /*
  *   - DRMAA_CONTROL_SUSPEND   0
  *   - DRMAA_CONTROL_RESUME    1
  *   - DRMAA_CONTROL_HOLD      2
  *   - DRMAA_CONTROL_RELEASE   3
  *   - DRMAA_CONTROL_TERMINATE 4
  */
  /* Delete Job */
  /*
  int i;
  for(i=0;i<0;i++)
  {
    errnum = drmaa_control(jobid, i, error, DRMAA_ERROR_STRING_BUFFER);
    if (errnum != DRMAA_ERRNO_SUCCESS)
    {
        fprintf (stderr, "Couldn't drmaa_control job: %s\n", error);
    } else
    {
     const char *str = drmaa_control_to_str(i);
     printf("drmaa_control: job_id: %s action: %s\n", jobid, str);
    }
  }
  */

  sleep(7);
  printf("drmaa_wait \n");

  int stat;
  drmaa_wait(DRMAA_JOB_IDS_SESSION_ANY, jobid, sizeof(jobid)-1, &stat, 20, NULL, NULL, 0);
  printf("drmaa_wait JobId: %s\n", jobid);


  /*
  const char **job_ids = NULL;
  job_ids = calloc( 2, sizeof(char *) );
  job_ids[0]=jobid;
  printf("drmaa_synchronize\n");
  errnum = drmaa_synchronize(job_ids, 200, 0,
          error, DRMAA_ERROR_STRING_BUFFER);
*/
  /* TODO free fsb_free_vector(job_ids); */

  if (errnum != DRMAA_ERRNO_SUCCESS)
  {
      fprintf (stderr, "Couldn't drmaa_synchronize: %s\n", error);
  }

   /* Delete Job Template*/

  errnum = drmaa_delete_job_template (jt, error,  DRMAA_ERROR_STRING_BUFFER);
  if (errnum != DRMAA_ERRNO_SUCCESS) 
  {
    fprintf (stderr, "Couldn't delete job template: %s\n", error);
    return 1;
  }


/* Exit Session */

  /* drmaa_exit | oar_disconnect */
  errnum = drmaa_exit (error, DRMAA_ERROR_STRING_BUFFER);

  if (errnum != DRMAA_ERRNO_SUCCESS) 
  {
    fprintf (stderr, "Couldn't exit DRMAA library: %s\n", error);
    return 1;
  }

  return 0;
  
/*
  return drmaa_init("hello");
  return drmaa_exit() ;
  return 0;
*/
}
