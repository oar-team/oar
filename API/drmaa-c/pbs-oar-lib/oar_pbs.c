

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

    if(!newElement) exit(EXIT_FAILURE); // If we don't have enough memory     

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

// convert a presult variable to the attrl format (ONLY THE IMMEDIAT VALUES WILL BE CONVERTED because attrl does not support complex values (objects and arrays))
// if pattern == NULL the all the immediat values (integer, float, string) will be saved in the attrl format, otherwise, only the attributes listed in the pattern shall be converted
struct attrl *presult2attrl(presult *source, struct attrl *pattern){
	
	attrl *result = NULL;
	presult *iterator;	
	char *value;		// char value[200]; // Should we initialize it as a table of char, big enough to hold all converted characters ??

//	printf(":: PRESULT2ATTRL : CHKPT 1\n");

	if (source == NULL) {
		return NULL;
	}

//	printf(":: PRESULT2ATTRL : CHKPT 2\n");

	iterator = source;

//	printf(":: PRESULT2ATTRL : CHKPT 3\n");
	
//	int i = 0;	

	// Test
//	printf("The presult source :\n\n");
//	printf("ATTRIBUTES BEFORE CONVERSION :\n");
//	showResult(source);
//	printf("----------------------\n\n");

	while (iterator != NULL){
	
//		printf("ROUND %d :\n",i);
		if (iterator->type != UNKNOWN && iterator->type != COMPLEX){	// if the value is not complex
//			printf("ROUND %d - 1:\n",i);
			if (pattern == NULL || isAnAttributeOf(iterator->key,pattern)==1){	// this element should be added to the generated attrl
//				printf("ROUND %d - 2:\n",i);
				switch (iterator->type){
					case INTEGER 	:	sprintf(value, "%d", (iterator)->immValue.i); break;
   					case FLOAT 	:	// typically for the attribute "array_index" which is an integer
								sprintf(value, "%f", (iterator)->immValue.f); break;	
   					case STRING 	:	sprintf(value, "%s", (iterator)->immValue.s); break;
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
	
	
	if (server == NULL){
		pbs_server = pbs_default();
	} else if (!strcmp("", server)){
		pbs_server = pbs_default();
	} else {
		pbs_server = server;
	}	

	return 0;	// We are not using this variable for the moment (perhaps it can be used as an index of a server URL array )
	
}

// return the pbs default server name  
char * pbs_default(void){
	return PBS_DEFAULT;
}




// delete a pbs batch job  
int pbs_deljob(int connect, char *job_id, char *extend){
	
	int retcode;

	char full_url[MAX_OAR_URL_LENGTH];

	strncpy(full_url, "http://", sizeof(full_url)); // for the moment, we are using Virtualbox + OAR Live CD with the IP : 192.168.0.1
	strncat(full_url, pbs_server, sizeof(full_url));
	strncat(full_url, "/oarapi/jobs/", sizeof(full_url));
  	strncat(full_url, job_id, sizeof(full_url));

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
	
	return retcode;	
}


// disconnect from a pbs batch server  
int pbs_disconnect(int connect){

	return PBSE_NONE;	// We are not using this variable for the moment

}



// get error message for last pbs batch operation 
char * pbs_geterrmsg(int connect){
	
	return "pbs_geterrmsg : NOT IMPLEMENTED YET !! \n";

}

// place a hold on a pbs batch job 
// The only Hold_type suported here is : USER_HOLD  (OTHER_HOLD and SYSTEM_HOLD are not supported here yet) 
int pbs_holdjob(int connect, char *job_id, char *hold_type, char *extend){

	int retcode;

	char full_url[MAX_OAR_URL_LENGTH];
	char* HOLD_REQ;
	HOLD_REQ = "{\"method\":\"hold\"}";	// JSON

	strncpy(full_url, "http://", sizeof(full_url)); // for the moment, we are using Virtualbox + OAR Live CD with the IP : 192.168.0.1
	strncat(full_url, pbs_server, sizeof(full_url));
	strncat(full_url, "/oarapi/jobs/", sizeof(full_url));
  	strncat(full_url, job_id, sizeof(full_url));

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
	
	return retcode;	
	

}

// release a hold on a pbs batch job 
// The only Hold_type suported here is : USER_HOLD  (OTHER_HOLD and SYSTEM_HOLD are not supported here yet) 
int pbs_rlsjob(int connect, char *job_id, char *hold_type, char *extend){

	int retcode;
	exchange_result *res;
	char full_url[MAX_OAR_URL_LENGTH];
	char* RESUME_REQ;
	RESUME_REQ = "{\"method\":\"resume\"}";	// JSON

	strncpy(full_url, "http://", sizeof(full_url)); // for the moment, we are using Virtualbox + OAR Live CD with the IP : 192.168.0.1
	strncat(full_url, pbs_server, sizeof(full_url));
	strncat(full_url, "/oarapi/jobs/", sizeof(full_url));
  	strncat(full_url, job_id, sizeof(full_url));

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




	return retcode;

}

// send a signal to a pbs batch job  
int pbs_sigjob(int connect, char *job_id, char *signal, char *extend){
	

	// WHAT KIND OF SIGNAL CAN WE HAVE HERE ??!!

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

	char *id2 = g_strdup(id);	// Il ne faut pas faire ça dans cette méthode mais plutot dans pbs_submit, ...

	exchange_result *res;
	char full_url[MAX_OAR_URL_LENGTH];
	struct attrl *attributes;
	// We create a new batch_status element
   	batch_status *bstatus = malloc(sizeof(batch_status));

	if(!bstatus) {
		printf("NO ENOUGH MEMORY");
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

	printf("CHKPT 0 : ID = %s\n", id);	

  	strncat(full_url, id, strlen(id));

	printf("CHKPT 1 : ID = %s\n", id);	

	printf("STAT JOB FULL URL = %s\n", full_url);

	printf("CHKPT 2 : ID = %s\n", id);	
	
	res = oar_request_transmission (full_url, "GET", NULL);

	printf("CHKPT 3 : ID = %s\n", id);

	printf("STAT JOB CHKPT 1\n");	

	if (res->code != 200){	// If we have encountered a problem
		return NULL;
	}
	// Everything is OK

	printf("CHKPT 4 : ID = %s\n", id);

	printf("STAT JOB CHKPT 2\n");
	
	// convert the res->code from presult to the attrl format (ONLY THE IMMEDIAT VALUES WILL BE CONVERTED because attrl does not support complex values (objects and arrays)) 
	//showResult(res->data);
	attributes = presult2attrl(res->data,attrib);

	id = id2;
	bstatus->name = id;
	bstatus->next = NULL;
	bstatus->attribs = attributes;
	bstatus->text = "OAR : NO COMMENTS";

	printf("CHKPT 5 : ID = %s\n", id);


	
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
	return bstatus;
}


						// ** NOT IMPLEMENTED ** //
// obtain status of pbs batch queues
struct batch_status *pbs_statque(int connect, char *id, struct attrl *attrib, char *extend){
	
	return NULL;	// Ce n'est pas possible en ce moment via la OAR-API à moins de faire un parcours des infos de toutes les jobs et construire la liste des files à partir de ça
			// ou créer une autre fonctions dans OAR-API pour faire ça	


}

						// ** NOT IMPLEMENTED ** //
// obtain status of a pbs batch server
struct batch_status *pbs_statserver(int connect, struct attrl *attrib, char *extend){
	return NULL;
}

// to free space
void pbs_statfree(struct batch_status *stat){

	printf("NOT IMPLEMENTED YET\n");

}


// Issue a batch request to submit a new batch job.
// The returned value is the job ID
char *pbs_submit(int connect, struct attropl *attrib, char *script, char *destination, char *extend){

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

	// 0 if everything is OK, otherwise the error number (see pbs_error.h)
	switch (res->code) {	// Est ce qu'il y a une possibilité de remonter directement le code OAR ??
				// Sinon, il vaut mieux implementer un convertisseur de code code d'erreur OAR2PBS
	
	  case 200 : 	jobId = extractStringAttribute(res->data,"id");	// get the value (job_id) of the id field
			break;
	  default  :	return NULL;	// We couldn't submit the Job
			break;
	}
	
	return jobId;

}

						// ** NOT IMPLEMENTED ** //
// terminate a pbs batch server 	
int pbs_terminate(int connect, int manner, char *extend){

	// NOT IMPLEMENTED YET IN THE OAR-API
	return 0;	// everything is OK
	
}



