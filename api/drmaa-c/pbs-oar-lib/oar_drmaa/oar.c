#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <unistd.h>
#include <string.h>

#include <drmaa_utils/conf.h>
#include <drmaa_utils/drmaa.h>
#include <drmaa_utils/drmaa_util.h>
#include <drmaa_utils/datetime.h>
#include <drmaa_utils/iter.h>
#include <drmaa_utils/template.h>
#include <oar_drmaa/oar_error.h>
#include <oar_drmaa/oar.h>
#include <oar_drmaa/util.h>


#include <curl/curl.h>

#ifndef lint
static char rcsid[]
#	ifdef __GNUC__
                __attribute__ ((unused))
#	endif
        = "$Id: $";
#endif

int oar_errno = 0;

CURL *curl;
CURLcode res;

int
oar_sigjob(int connect, char *job_id, char *signal)
{
    return 0;
}

int
oar_holdjob(int connect, char *job_id, char *hold_type)
{
    printf("oar_holdjob\n");
    return 0;
}

int
oar_connect(char *server)
{
    curl = curl_easy_init();
    curl = curl_easy_init();
    if(curl) {
      curl_easy_setopt(curl, CURLOPT_URL, "http://localhost/oarapi/resources.json");
      res = curl_easy_perform(curl);
    }
    /* always cleanup */
    curl_easy_cleanup(curl);

    fsd_set_verbosity_level(FSD_LOG_ALL);

    fsd_log_debug(( "OAR-CONNECT\n"));

    printf("oar_connect\n");

    return 0;
}


int oar_deljob(int connect, char *job_id)
{
    printf("oar_deljob\n");
    return 0;
}

int oar_disconnect(int connect)
{
    printf("oar_disconnect\n");
    return 0;
}

int oar_rlsjob(int connect, char *job_id, char *hold_type)
{
    printf("oar_rlsjob\n");
    return 0;
}

void oar_statfree(struct batch_status *stat)
{
    printf("oar_statfree\n");
}

struct batch_status *oar_statjob(int connect, char *id, struct attrl *attrib)
{
    printf("oar_statjob\n");
    return 0;
}

char *job_id_foo;
char str_job_id[]="1234";
char *oar_submit(int connect, struct attropl *attrib, char *script, char *destination)
{
    printf("oar_submit\n");
    printf("script: %s destination %s\n",script,destination);
    oardrmaa_dump_attrl( attrib, NULL );
    job_id_foo = (char *)malloc((strlen(str_job_id) + 1) * sizeof(char));
    strcpy(job_id_foo, str_job_id);
    return job_id_foo;
}

/*
fsd_template_t *oardrmaa_oar_template_new(void)
{
    printf("oardrmaa_oar_template_new\n");
    return 0;
}

int oardrmaa_oar_attrib_by_name( const char *name )
{
    printf("oardrmaa_oar_attrib_by_name\n");
    return 0;
}
*/
char *oar_errno_to_txt(int err_no)
{
    printf("oar_errno_to_txt\n");
    return 0;
}
