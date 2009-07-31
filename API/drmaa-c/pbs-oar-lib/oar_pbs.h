#ifndef _OAR_PBS_H
#define _OAR_PBS_H 


# include "oar_exchange.h" 	// A JSON parser for OAR-API responses
# include <pbs_ifl.h>
# include <pbs_error.h>


typedef struct batch_status batch_status;
typedef struct attrl attrl;

int pbs_connect(char *server);

char * pbs_default(void);

int pbs_deljob(int connect, char *job_id, char *extend);

int pbs_disconnect(int connect);

char * pbs_geterrmsg(int connect);

int pbs_holdjob(int connect, char *job_id, char *hold_type, 
		       char *extend);

int pbs_rlsjob(int connect, char *job_id, char *hold_type, char *extend);

int pbs_sigjob(int connect, char *job_id, char *signal, char *extend);

void pbs_statfree(struct batch_status *stat);

struct batch_status *pbs_statjob(int connect, char *id, struct attrl *attrib, char *extend);

struct batch_status *pbs_statque(int connect, char *id, struct attrl *attrib, char *extend); 

struct batch_status *pbs_statserver(int connect, struct attrl *attrib, char *extend);

char *pbs_submit(int connect, struct attropl *attrib, char *script,
	char *destination, char *extend);
	
int pbs_terminate(int connect, int manner, char *extend);

void show_BatchStatus(batch_status *status);	// This is not a part of PBS functions >> a test function
struct attrl *addNewAttribute(attrl **list, char* name, char* resource, char* value); // This is not a part of PBS functions >> a test function

char * pbs_server;		/* server attempted to connect | connected to */
				/* see pbs_connect(3B)			      */

int pbs_errno;			/* error number */

extern int MAX_OAR_URL_LENGTH;

#endif
