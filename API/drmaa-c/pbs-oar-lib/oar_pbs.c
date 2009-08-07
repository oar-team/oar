

	/*	PBS to/from OAR		*/


/*

pbs_connect
pbs_default (just change variable)
pbs_deljob
pbs_disconnect
pbs_geterrmsg (??)
pbs_holdjob
pbs_rlsjob
pbs_sigjob (it seems that this function has a bug ??)
pbs_statfree
pbs_statjob
pbs_statque
pbs_statserver
pbs_submit (qsub ?? qsub_parse_attr, ... ??)
pbs_submit_reserv (??)
pbs_terminate ??


pbse_to_txt

*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "oar_pbs.h"

#define PBS_DEFAULT "192.168.0.1";		// Default PBS/OAR Server Name


char * pbs_server;		// server attempted to connect | connected to
				// see pbs_connect(3B)


int pbs_errno;			// PBS error number


/*
struct batch_status {
        struct batch_status *next;
        char                *name;
        struct attrl        *attribs;
        char                *text;
};
*/
/*

struct attrl {
        struct attrl *next;
        char         *name;
        char         *resource;
        char         *value;
        enum batch_op    op;    // not used
};

*/


// Prints the content of the presult list
void showAttributes(attrl *attributes) { 

    attrl *attr;
    attr = attributes;	 

    if (attributes == NULL) {
	
	printf("Attributes == NULL");
 	
    }

    while(attr != NULL) {
	
	printf("attr_name = %s, attr_resource = %s, attr_value = %s", attr->name, attr->resource, attr->value);
		 	
        attr = attr->next;
	if (attr) printf(", \n");       
    }

    printf("\n");       	
}


void showBatchStatus(batch_status *status) {
	printf("\n\n---------------------------------------------------------------\n");
	printf("-----------------------  SHOW BATCH STATUS  -----------------------\n");
	printf("---------------------------------------------------------------\n\n");
	showBatchStatus_(status);
	printf("\n\n---------------------------------------------------------------\n");
	printf("----------------------------  END BATCH STATUS --------------------\n");
	printf("---------------------------------------------------------------\n\n");

}

// Prints the content of the presult list
void showBatchStatus_(batch_status *status) { 

    batch_status *tmp;
    tmp = status;	 

    while(tmp != NULL) {
	
	printf("JOB NAME = %s, JOB DESCRIPTION = %s\n", tmp->name, tmp->text);
	showAttributes(tmp->attribs);
		 	
        tmp = tmp->next;
	if (tmp) printf("__________________________\n");
    }
    printf("\n");       	
}


// Adds a new element to the attrl list (in the end) and returns the added element address
struct attrl *addNewAttribute(attrl **list, char* name, char* resource, char* value) { 

    // We create a new presult element
    attrl *newElement = malloc(sizeof(attrl));
	
//    printf("1\n");
   
    if(!newElement) {
		printf("** AddNewAttribute ** :NO ENOUGH MEMORY FOR THE ATTRL STRUCTURE");
		exit(EXIT_FAILURE); // If we don't have enough memory 
	}

//    printf("2\n");

    // We initialize the newly created element
    newElement->name = name;		
    newElement->resource = g_strdup(resource);	
    newElement->value = g_strdup(value); // Thanks glib ;-)
    newElement->next = NULL;

//    printf("3\n");

    if(*list == NULL) {           
	
	*list = newElement;

//        printf("4\n");

        return newElement;

    } else { // We are adding the new element in the end of the list

        attrl *temp = *list;

//    	printf("5\n");

        while(temp->next != NULL) {
	    
//  	    printf(".");

            temp = temp->next;
        }  
	
//	printf("\n");    

//	printf("6\n");

        temp->next = newElement;

//	printf("7\n");

        return newElement;
    }
}



// returns 1 if the attribute is found in pattern, otherwise it returns 0
int isAnAttributeOf(char* name, struct attrl *pattern) {
	struct attrl *iterator;
	iterator = pattern;
	while (iterator != NULL){
	
		if (!strcmp(name, iterator->name)){	// If the attribute name is found
			return 1;
		} 

	iterator = iterator->next;

	}
	return 0;
}

char *oar_toPbsStatus(char *name){	// Only the first character of the returned result will be user !!

	char *value = NULL;
	
	if (!strcmp(name, "Terminated")){	/*OK*/
			value = g_strdup("C(Terminated)");	
	} else if (!strcmp(name, "Hold")){	/*OK*/
			value = g_strdup("H(Hold)");	
	} else if (!strcmp(name, "Waiting")){	/*OK*/
			value = g_strdup("W(Waiting)");	
	} else if (!strcmp(name, "toLaunch")){	/*OK*/
			value = g_strdup("Q(toLaunch)");
	} else if (!strcmp(name, "toError")){ /*OK??	It should be changed somehow to 'E' with exit_status != 0*/
			value = g_strdup("E(toError)");
	} else if (!strcmp(name, "toAckReservation")){/*OK*/
			value = g_strdup("");
	} else if (!strcmp(name, "Launching")){	/*OK*/
			value = g_strdup("R(Launching)");
	} else if (!strcmp(name, "Finishing")){	/*See job->exit_status*/
			value = g_strdup("E(Finishing)");
	} else if (!strcmp(name, "Running")){	/*See job->flags*/
			value = g_strdup("R(Running)");
	} else if (!strcmp(name, "Suspended")){	/*S ???*/
			value = g_strdup("T(Suspended)");
	} else if (!strcmp(name, "Resuming")){  /*S ???*/
			value = g_strdup("T(Resuming)");
	} else {	/*OAR job state == Error*/
			value = g_strdup("E(Error)");	/*OK??	It should be changed somehow to 'E' with exit_status != 0*/
	}

/*
case 'C': // Job is completed after having run. 
		case 'E': // Job is exiting after having run.
			job->flags &= DRMAA_JOB_TERMINATED_MASK;
			job->flags |= DRMAA_JOB_TERMINATED;
			if( job->exit_status == 0 )
				job->status = DRMAA_PS_DONE;
			else
				job->status = DRMAA_PS_FAILED;
			break;
		case 'H': // Job is held. 
			job->status = DRMAA_PS_USER_ON_HOLD;
			job->flags |= DRMAA_JOB_HOLD;
			break;
		case 'Q': // Job is queued, eligible to run or routed. 
		case 'W': // Job is waiting for its execution time to be reached. 
			job->status = DRMAA_PS_QUEUED_ACTIVE;
			job->flags &= ~DRMAA_JOB_HOLD;
			break;
		case 'R': // Job is running. 
		case 'T': // Job is being moved to new location (?). 
		 {
			if( job->flags & DRMAA_JOB_SUSPENDED )
				job->status = DRMAA_PS_USER_SUSPENDED;
			else
				job->status = DRMAA_PS_RUNNING;
			break;
		 }
		case 'S': // (Unicos only) job is suspend. 
			job->status = DRMAA_PS_SYSTEM_SUSPENDED;
			break;
		case 0:  default:
			job->status = DRMAA_PS_UNDETERMINED;
			break;
*/


	return value;
}


attrl *oar_toPbsAttributes(attrl *oar_attr_list){

	attrl *iterator;
	iterator = oar_attr_list;
	char* name;
	char* resource;
	char* value;
	attrl *next;

	while (iterator != NULL){
	
		name = iterator->name;
		//char* resource = iterator->resource;
		value = iterator->value;
		next = iterator->next;


		if (!strcmp(name, "state")){	// If the attribute name is found
			iterator->name = g_strdup(ATTR_state);
			iterator->value = oar_toPbsStatus(value);
		} 







	iterator = iterator->next;

	}
	return oar_attr_list;
}


// converts a presult variable to the attrl format (ONLY THE IMMEDIAT VALUES WILL BE CONVERTED because attrl does not support complex values (objects and arrays))
// if pattern == NULL the all the immediat values (integer, float, string) will be saved in the attrl format, otherwise, only the attributes listed in the pattern shall be converted
struct attrl *presult2attrl(presult *source, struct attrl *pattern){
	
	attrl *result = NULL;
	presult *iterator;	
	char *value;	
	// char value[200]; // Should we initialize it as a table of char, big enough to hold all converted characters ??

//	printf(":: PRESULT2ATTRL : CHKPT 1\n");

	if (source == NULL) {
		return NULL;
	}

//	printf(":: PRESULT2ATTRL : CHKPT 2\n");

	iterator = source;

//	printf(":: PRESULT2ATTRL : CHKPT 3\n");
	
//	int i = 0;	
	int iteratorType;

	// Test
//	printf("The presult source :\n\n");
//	printf("ATTRIBUTES BEFORE CONVERSION :\n");
//	showResult(source);
//	printf("----------------------\n\n");

	while (iterator != NULL){
		iteratorType = iterator->type;
//		printf("ROUND %d :\n",i);
		if (iteratorType != UNKNOWN && iteratorType != COMPLEX){	// if the value is not complex
//			printf("ROUND %d - 1:\n",i);
			if (pattern == NULL || isAnAttributeOf(iterator->key,pattern)==1){	// this element should be added to the generated attrl
//				printf("ROUND %d - 2:\n",i);
//				printf("KEY = %s\n", iterator->key);
				switch (iteratorType){
					case INTEGER 	:	sprintf(value, "%d", (iterator)->immValue.i); break;
   					case FLOAT 	:	// typically for the attribute "array_index" which is an integer
								sprintf(value, "%f", (iterator)->immValue.f); break;	
   					case STRING 	:	value = g_strdup((iterator)->immValue.s);break;//printf("YOOHOO\n");sprintf(value, "%s", (iterator)->immValue.s); break;
					default 	: 	value = NULL; printf(" \n!!!We should not be in this case !!!\n"); break;
				}
//				printf("ROUND %d - 3:\n",i);
//				printf("::presult2attrl1: key : %s, value : %s\n", iterator->key, value);
				addNewAttribute(&result, iterator->key, NULL, value); // the only type that can be associated to value in attrl(PBS) is string 
//				printf("::presult2attrl2: key : %s, value : %s\n", iterator->key, value);
//				printf("ROUND %d - 4:\n",i);
			}
//			printf("ROUND %d - 5:\n",i);		
		} 
//		printf("ROUND %d - 6:\n",i);
//		i++;
		iterator = iterator->next;

	}
	
//	printf(":: PRESULT2ATTRL : CHKPT 4\n");
	

	return result;

}


// connect to a pbs batch server 
// A virtual stream (TCP/IP) connection is established with the server specified by server
int pbs_connect(char *server){
	
	printf("**PBS_CONNECT BEGIN\n");
	
	if (server == NULL){
		pbs_server = pbs_default();
	} else if (!strcmp("", server)){
		pbs_server = pbs_default();
	} else {
		pbs_server = server;
	}	
	printf("**PBS_CONNECT END\n");

	return 0;	// We are not using this variable for the moment (perhaps it can be used as an index of a server URL array )
	
}

// return the pbs default server name  
char * pbs_default(void){
	return PBS_DEFAULT;
}




// delete a pbs batch job  
int pbs_deljob(int connect, char *job_id, char *extend){
	
	printf("**PBS_DELJOB BEGIN\n");

	int retcode;

	char full_url[MAX_OAR_URL_LENGTH];

	strncpy(full_url, "http://", strlen("http://")+1); // for the moment, we are using Virtualbox + OAR Live CD with the IP : 192.168.0.1

	// PBS_DEFAULT should be changed into pbs_server

	strncat(full_url, "192.168.0.1", strlen("192.168.0.1"));	

	strncat(full_url, "/oarapi/jobs/", strlen("/oarapi/jobs/"));	

  	strncat(full_url, job_id, strlen(job_id));

	exchange_result *res;
	res = oar_request_transmission (full_url, "DELETE", NULL);

	// 0 if everything is OK, otherwise the error number (see pbs_error.h)
	switch (res->code) {	// Est ce qu'il y a une possibilité de remonter directement le code OAR ??
				// Sinon, il vaut mieux implementer un convertisseur de code code d'erreur OAR2PBS
	
	  case 200 : 	retcode = PBSE_NONE;
			break;
	  case 400 : 	retcode = PBSE_IVALREQ;
			break;
	  case 401 : 	retcode = PBSE_PERM;
			break;
	  case 501 : 	retcode = PBSE_UNKREQ;
			break;
	  case 503 : 	retcode = PBSE_BADHOST;
			break;
	  default  :	retcode = PBSE_INTERNAL;
			break;
	}
	
	printf("______________________DELETING__________________________\n");
	printf(" DELETING CODE : %d\n",res->code);
	printf(" DELETING RESPONSE : \n");
	showResult(res->data);
	printf("____________________DELETING DONE_______________________\n");

	printf("**PBS_DELJOB END\n");

	return retcode;	
}


// disconnect from a pbs batch server  
int pbs_disconnect(int connect){

	printf("**PBS_DISCONNECT BEGIN\n");
	printf("**PBS_DISCONNECT END\n");	
	return PBSE_NONE;	// We are not using this variable for the moment

}



// get error message for last pbs batch operation 
char * pbs_geterrmsg(int connect){
	
	printf("**PBS_GETERRMSG BEGIN\n");	
	printf("**PBS_GETERRMSG END\n");
	return "pbs_geterrmsg : NOT IMPLEMENTED YET !! \n";

}

// place a hold on a pbs batch job 
// The only Hold_type suported here is : USER_HOLD  (OTHER_HOLD and SYSTEM_HOLD are not supported here yet) 
int pbs_holdjob(int connect, char *job_id, char *hold_type, char *extend){

	printf("**PBS_HOLDJOB BEGIN\n");
	int retcode;

	char full_url[MAX_OAR_URL_LENGTH];
	char* HOLD_REQ;
	HOLD_REQ = "{\"action\":\"hold\"}";	// JSON

	strncpy(full_url, "http://", strlen("http://")+1); // for the moment, we are using Virtualbox + OAR Live CD with the IP : 192.168.0.1

	// PBS_DEFAULT should be changed into pbs_server

	strncat(full_url, "192.168.0.1", strlen("192.168.0.1"));	

	strncat(full_url, "/oarapi/jobs/", strlen("/oarapi/jobs/"));	

  	strncat(full_url, job_id, strlen(job_id));
	
	printf("HOLDING FULL URL = %s\n", full_url);

	exchange_result *res;
	res = oar_request_transmission (full_url, "POST", HOLD_REQ);

	// 0 if everything is OK, otherwise the error number (see pbs_error.h)
	switch (res->code) {	// Est ce qu'il y a une possibilité de remonter directement le code OAR ??
				// Sinon, il vaut mieux implementer un convertisseur de code code d'erreur OAR2PBS
	
	  case 200 : 	retcode = PBSE_NONE;
			break;
	  case 400 : 	retcode = PBSE_IVALREQ;
			break;
	  case 401 : 	retcode = PBSE_PERM;
			break;
	  case 501 : 	retcode = PBSE_UNKREQ;
			break;
	  case 503 : 	retcode = PBSE_BADHOST;
			break;
	  default  :	retcode = PBSE_INTERNAL;
			break;
	}
	

	printf("______________________HOLDING__________________________\n");
	printf(" HOLDING CODE : %d\n",res->code);
	printf(" HOLDING RESPONSE : \n");
	showResult(res->data);
	printf("____________________HOLDING DONE_______________________\n");

	printf("**PBS_HOLDJOB END\n");

	return retcode;	
	

}

// release a hold on a pbs batch job 
// The only Hold_type suported here is : USER_HOLD  (OTHER_HOLD and SYSTEM_HOLD are not supported here yet) 
int pbs_rlsjob(int connect, char *job_id, char *hold_type, char *extend){

	printf("**PBS_RLSJOB BEGIN\n");

	int retcode;
	exchange_result *res;
	char full_url[MAX_OAR_URL_LENGTH];
	char* RESUME_REQ;
	RESUME_REQ = "{\"action\":\"resume\"}";	// JSON   

	strncpy(full_url, "http://", strlen("http://")+1); // for the moment, we are using Virtualbox + OAR Live CD with the IP : 192.168.0.1

	// PBS_DEFAULT should be changed into pbs_server

	strncat(full_url, "192.168.0.1", strlen("192.168.0.1"));	

	strncat(full_url, "/oarapi/jobs/", strlen("/oarapi/jobs/"));	

  	strncat(full_url, job_id, strlen(job_id));
	
	printf("RELEASING FULL URL = %s\n", full_url);

	res = oar_request_transmission (full_url, "POST", RESUME_REQ);

	// 0 if everything is OK, otherwise the error number (see pbs_error.h)
	switch (res->code) {	// Est ce qu'il y a une possibilité de remonter directement le code OAR ??
				// Sinon, il vaut mieux implementer un convertisseur de code code d'erreur OAR2PBS
	
	  case 200 : 	retcode = PBSE_NONE;
			break;
	  case 400 : 	retcode = PBSE_IVALREQ;
			break;
	  case 401 : 	retcode = PBSE_PERM;
			break;
	  case 501 : 	retcode = PBSE_UNKREQ;
			break;
	  case 503 : 	retcode = PBSE_BADHOST;
			break;
	  default  :	retcode = PBSE_INTERNAL;
			break;
	}
	


	// We should free non-used memory here !!


	printf("______________________RELEASING__________________________\n");
	printf(" RELEASING CODE : %d\n",res->code);
	printf(" RELEASING RESPONSE : \n");
	showResult(res->data);
	printf("____________________RELEASING DONE_______________________\n");

	printf("**PBS_RLSJOB END\n");

	return retcode;

}

// send a signal to a pbs batch job  
int pbs_sigjob(int connect, char *job_id, char *signal, char *extend){

	printf("**PBS_SIGJOB BEGIN\n");	

	printf("***SIGJOB INFORMATION BEGIN:\n");
	printf("***connection : %d\n",connect);	// The connection number has no meaning in the OAR DRMAA implementation (for the moment)
	printf("***Job Id : %s\n",job_id);
	printf("***Signal : %s\n",signal);
	printf("***extend : %s\n",extend);
	printf("***SIGJOB INFORMATION END:\n");

	printf("**PBS_SIGJOB END\n");
	
//	"SIGSTOP" -> job suspend	oarhold -r ??? but how do we get this in OAR-API ??
//	"SIGCONT" -> job resume
//	"SIGKILL"	
//	"SIGINT"
/*
		 {"SIGUSR1", SIGUSR1},
		 {"SIGTERM", SIGTERM},
		 {"SIGALRM", SIGALRM},
		 {"SIGUSR2", SIGUSR2},
		 {"SIGSEGV", SIGSEGV},
		 {"SIGHUP",  SIGHUP},
		 {"SIGQUIT", SIGQUIT},
		 {"SIGILL", SIGILL},
		 {"SIGABRT", SIGABRT},
		 {"SIGFPE", SIGFPE},
		 {"SIGKILL", SIGKILL}

*/

	return PBSE_INTERNAL; // PBSE_NONE ??
}

/*
struct batch_status {
        struct batch_status *next;
        char                *name;
        struct attrl        *attribs;
        char                *text;
};
*/
/*

struct attrl {
        struct attrl *next;
        char         *name;
        char         *resource;
        char         *value;
        enum batch_op    op;    // not used
};

*/


// Get job information from batch system
struct batch_status *pbs_statjob(int connect, char *id, struct attrl *attrib, char *extend){

	printf("**PBS_STATJOB BEGIN\n");	
/*
	printf("---- Asked for attributes PRINTING:\n");
	showAttributes(attrib);
	printf("---- Asked for attributes END PRINTING:\n");		
*/
	char *id2 = g_strdup(id);	// Il ne faut pas faire ça dans cette méthode mais plutot dans pbs_submit, ...

	exchange_result *res;
	char full_url[MAX_OAR_URL_LENGTH];
	struct attrl *attributes;
	// We create a new batch_status element
   	batch_status *bstatus = malloc(sizeof(batch_status));

	if(!bstatus) {
		printf("PBS_STATJOB :NO ENOUGH MEMORY FOR BATCH_STATUS");
		exit(EXIT_FAILURE); // If we don't have enough memory 
	}

	// if id == NULL -> return the status of all jobs	<- not implemented yet
	// if id == queue Identifier ->  return the status of all jobs in the queue  <- not implemented yet
	// if id == job id -> return the status of this job

	// if attrl == NULL -> return all attributes
	// if attrl != NULL -> return the attributes whose names are pointed by the attrl member "name".
	
	if (id == NULL) {	// return the status of all jobs
		
		return NULL;		
		
	} else {	// If it's a job id (see difference between queue and job IDs in OAR)  <- queue ID not implemented
		// nothing to do here !!
		// not for the moment
	}


	strncpy(full_url, "http://", strlen("http://")+1); // for the moment, we are using Virtualbox + OAR Live CD with the IP : 192.168.0.1

	// PBS_DEFAULT should be changed into pbs_server

	strncat(full_url, "192.168.0.1", strlen("192.168.0.1"));	

	strncat(full_url, "/oarapi/jobs/", strlen("/oarapi/jobs/"));

//	printf("CHKPT 0 : ID = %s\n", id);	

  	strncat(full_url, id, strlen(id));

//	printf("CHKPT 1 : ID = %s\n", id);	

	printf("STAT JOB FULL URL = %s\n", full_url);

//	printf("CHKPT 2 : ID = %s\n", id);	
	
	res = oar_request_transmission (full_url, "GET", NULL);

//	printf("CHKPT 3 : ID = %s\n", id);

//	printf("STAT JOB CHKPT 1\n");	

	if (res->code != 200){	// If we have encountered a problem
		printf("**PBS_STATJOB END (error)\n");
		return NULL;
	}
	// Everything is OK

//	printf("CHKPT 4 : ID = %s\n", id);

//	printf("STAT JOB CHKPT 2\n");
	
	// convert the res->code from presult to the attrl format (ONLY THE IMMEDIAT VALUES WILL BE CONVERTED because attrl does not support complex values (objects and arrays)) 
	//showResult(res->data);
	//attributes = presult2attrl(res->data,attrib);
	attributes = oar_toPbsAttributes(presult2attrl(res->data,attrib));
//	printf("STAT JOB CHKPT 3\n");
	
	id = id2;
	bstatus->name = id;
	bstatus->next = NULL;
	bstatus->attribs = attributes;
	bstatus->text = g_strdup("OAR : NO COMMENTS");	// In order to avoir freeing problems in pbs_statfree

//	printf("STAT JOB CHKPT 4\n");

//	printf("CHKPT 5 : ID = %s\n", id);


	
/*	
	
	printf("\n\nBEFORE RETURNING STATUS \n\n");

	printf("STAT JOB CHKPT 3\n");	
	printf("text: %s\n", bstatus->text);
	printf("local id = %s", id);

	printf("STAT JOB CHKPT 4\n");
	printf("name: %s\n", bstatus->name);


	printf("ATTRIBUTES AFTER CONVERSION :\n");
	showAttributes(attributes);
	
	printf("STAT JOB CHKPT 5\n");

	showBatchStatus(bstatus);
*/

	printf("**PBS_STATJOB END\n");

	return bstatus;
}


						// ** NOT IMPLEMENTED ** //
// obtain status of pbs batch queues
struct batch_status *pbs_statque(int connect, char *id, struct attrl *attrib, char *extend){

	printf("**PBS_STATQUE BEGIN\n");
	printf("**PBS_STATQUE END\n");
	
	return NULL;	// Ce n'est pas possible en ce moment via la OAR-API à moins de faire un parcours des infos de toutes les jobs et construire la liste des files à partir de ça
			// ou créer une autre fonctions dans OAR-API pour faire ça	


}

						// ** NOT IMPLEMENTED ** //
// obtain status of a pbs batch server
struct batch_status *pbs_statserver(int connect, struct attrl *attrib, char *extend){
	printf("**PBS_STATSERVER BEGIN\n");
	printf("**PBS_STATSERVER END\n");
	return NULL;
}


void free_attrl(struct attrl *attribs){

//	printf("**** FREE_ATTRL BEGIN\n");

	while (attribs != 0)
         {
           struct attrl *next = attribs->next;
           free (attribs->name);
           free (attribs->resource);
           free (attribs->value);
           free (attribs);
           attribs = next;
         }
	
	if (attribs != 0){
		printf("\n\n**** FREE ATTRIBS : SOME SPACE WAS NOT FREED ****\n\n");
	}

//	printf("**** FREE_ATTRL END\n");

}

// to free some space (the stat results)
void pbs_statfree(struct batch_status *stat){

	printf("**PBS_STATFREE BEGIN\n");

	while (stat != 0)
         {
           struct batch_status *next = stat->next;
//	   printf("**PBS_STATFREE NAME\n");
           free (stat->name);
	   if (stat->text!=0){
//		printf("**PBS_STATFREE TEXT\n");
	   	free (stat->text);
	   }           
//	   printf("**PBS_STATFREE ATTRIBS\n");
	   free_attrl(stat->attribs);	
//	   printf("**PBS_STATFREE PTR\n");
           free (stat);
           stat = next;
         }
	
	if (stat != 0){
		printf("\n\n**** PBS STAT FREE : SOME SPACE WAS NOT FREED ****\n\n");
	}

	printf("**PBS_STATFREE END\n");

}


// Issue a batch request to submit a new batch job.
// The returned value is the job ID
char *pbs_submit(int connect, struct attropl *attrib, char *script, char *destination, char *extend){

	printf("**PBS_SUBMIT BEGIN\n");
	printf("***SUBMISSION INFORMATION BEGIN:\n");
	printf("***connection : %d\n",connect);	// The connection number has no meaning in the OAR DRMAA implementation (for the moment)
	printf("***script : %s\n",script);
	printf("***destination : %s\n",destination);
	printf("***extend : %s\n",extend);
	printf("***attributes :\n");
	showAttributes(attrib);
	printf("\n***SUBMISSION INFORMATION END:\n");

	exchange_result *res;
	presult *iterator;
	char full_url[MAX_OAR_URL_LENGTH];
	char* jobId;	// returned value
	char* JOB_DETAILS;
	JOB_DETAILS = "{\"script_path\":\"\\/usr\\/bin\\/id\",\"resource\":\"\\/nodes=2\\/cpu=1\"}";	// JSON --> It should be adapted to the user request
	
			
	
	strncpy(full_url, "http://", strlen("http://")+1); // for the moment, we are using Virtualbox + OAR Live CD with the IP : 192.168.0.1

	// PBS_DEFAULT should be changed into pbs_server

	strncat(full_url, "192.168.0.1", strlen("192.168.0.1"));	

	strncat(full_url, "/oarapi/jobs", strlen("/oarapi/jobs"));
	
	printf("SUBMISSION FULL URL = %s\n", full_url);
	
	res = oar_request_transmission (full_url, "POST", JOB_DETAILS);

	if (res == NULL){
		printf("SUBMISSION RESULT = NULL\n");
		printf("**PBS_SUBMIT END\n");	
		return NULL;
	}else{

	// 0 if everything is OK, otherwise the error number (see pbs_error.h)
	switch (res->code) {	// Est ce qu'il y a une possibilité de remonter directement le code OAR ??
				// Sinon, il vaut mieux implementer un convertisseur de code code d'erreur OAR2PBS
	
	  case 200 : 	jobId = extractStringAttribute(res->data,"id");	// get the value (job_id) of the id field
			break;
	  default  :
			printf("SUBMISSION RESULT = %d\n", res->code);
			showResult(res->data);
			return NULL;	// We couldn't submit the Job
			break;
	}

	printf("**PBS_SUBMIT END\n");	

	return jobId;
	}
}

						// ** NOT IMPLEMENTED ** //
// terminate a pbs batch server 	
int pbs_terminate(int connect, int manner, char *extend){

	printf("**PBS_TERMINATE BEGIN\n");
	printf("**PBS_TERMINATE END\n");
	// NOT IMPLEMENTED YET IN THE OAR-API
	return 0;	// everything is OK
	
}

char *pbse_to_txt(int err) {
	printf("**PBSE_TO_TXT BEGIN\n");
	printf("**PBSE_TO_TXT END\n");
	return "PBSE_TO_TXT NOT IMPLEMENTED YET WITH OAR MESSAGES LIST";
}
