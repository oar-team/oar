
#ifndef __OAR_H
#define __OAR_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#define DEBUGGING true


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

struct batch_status {
        struct batch_status *next;
        char		    *name;
        struct attrl	    *attribs;
        char		    *text;
};

int oar_sigjob(int connect, char *job_id, char *signal);

int oar_holdjob(int connect, char *job_id, char *hold_type);

int oar_connect(char *server);

int oar_deljob(int connect, char *job_id);

int oar_disconnect(int connect);

int oar_rlsjob(int connect, char *job_id, char *hold_type);

void oar_statfree(struct batch_status *stat);

struct batch_status *oar_statjob(int connect, char *id, struct attrl *attrib);

char *oar_submit(int connect, struct attropl *attrib, char *script_path, char *workdir, char *queue_destination);

#endif	/*  __OAR_H  */



