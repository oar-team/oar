
#ifndef __OAR_H
#define __OAR_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#define OAR_JS_WAITING      "Waiting"
#define OAR_JS_HOLD         "Hold"
#define OAR_JS_TOLAUNCH     "toLaunch"
#define OAR_JS_TOERROR      "toError"
#define OAR_JS_TOASKRESERV  "toAskReservation"
#define OAR_JS_LAUNCHING    "Launching"
#define OAR_JS_RUNNING      "Running"
#define OAR_JS_SUSPENDED    "Suspended"
#define OAR_JS_RESUMING     "Resuming"
#define OAR_JS_FINISHING    "Finishing"
#define OAR_JS_TERMINATED   "Terminated"
#define OAR_JS_ERROR        "Error"

/**
 * The drmaa_job_ps() function SHALL store in @a remote_ps the program
 * status of the job identified by @a job_id. The possible values of
 * a program's staus are:
 *   - DRMAA_PS_UNDETERMINED
 Waiting            DRMAA_PS_QUEUED_ACTIVE
 Hold (+event ???)  DRMAA_PS_SYSTEM_ON_HOLD / DRMAA_PS_USER_ON_HOLD [default] / DRMAA_PS_USER_SYSTEM_ON_HOLD
 toLaunch           DRMAA_PS_QUEUED_ACTIVE
 toError            DRMAA_PS_FAILED
 toAskReservation   DRMAA_PS_UNDETERMINED
 Launching          DRMAA_PS_RUNNING
 Running            DRMAA_PS_RUNNING
 Suspended(event)   DRMAA_PS_SYSTEM_SUSPENDED / DRMAA_PS_USER_SUSPENDED [default]
 Resuming(event)    DRMAA_PS_SYSTEM_SUSPENDED / DRMAA_PS_USER_SUSPENDED [default]
 Finishing          DRMAA_PS_RUNNING
 Terminated         DRMAA_PS_DONE
 Error              DRMAA_PS_FAILED

 */

/* Conrol Job */
/*
*   - DRMAA_CONTROL_SUSPEND   0
*   - DRMAA_CONTROL_RESUME    1
*   - DRMAA_CONTROL_HOLD      2
*   - DRMAA_CONTROL_RELEASE   3
*   - DRMAA_CONTROL_TERMINATE 4
*/

const char *drmaa_control_to_oar_rest[5];

struct attrl {
        struct attrl *next;
        char	     *name;
        char	     *resource;
        char	     *value;
};

/* TODO: to remove, duplicate with attrl */
struct attropl {
        struct attropl	*next;
        char		*name;
        char		*resource;
        char		*value;
};

struct oar_job_status {
    int     id;
    char    *state;
    int     exit_status;
    int     walltime;
    char    *queue;
};

struct batch_status {
        struct batch_status *next;
        char	 *name;
        struct oar_job_status *status;
        char	 *text;
};

int oar_disconnect(int connect);

int oar_connect(char *server);

int oar_control_job(int connect, char *job_id, int action);

void oar_statfree(struct batch_status *stat);

void oar_status_dump(struct batch_status *stat);

struct batch_status *oar_statjob(int connect, char *id);

struct batch_status *oar_multiple_statjob(int connect, char **job_id);

char *oar_submit(int connect, struct attropl *attrib, char *script_path, char *workdir, char *queue_destination);

#endif	/*  __OAR_H  */



