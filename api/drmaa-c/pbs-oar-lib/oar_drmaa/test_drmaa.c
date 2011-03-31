/*
   simple test program based on different documentation gathered on the web
   to compile:
     gcc -g test_drmaa.c  -L.libs -loardrmaa
*/

#include <drmaa.h>

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

  /* Job Templates */
  errnum = drmaa_set_attribute (jt, DRMAA_REMOTE_COMMAND, "sleeper.sh", error, DRMAA_ERROR_STRING_BUFFER);
  if (errnum != DRMAA_ERRNO_SUCCESS) 
  {
    fprintf (stderr, "Couldn't set remote command: %s\n", error);
    return 1;
  }

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
