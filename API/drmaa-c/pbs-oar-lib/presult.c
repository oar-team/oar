#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>
#include "presult.h"

// needed functions to use the presult structure




void UpCase(char *string);


// Adds a new element to the presult list (in the end)
presult *addElement(presult **list, char* key) { 

    // We create a new presult element
    presult *newElement = malloc(sizeof(presult));

    if(!newElement) exit(EXIT_FAILURE); // If we don't have enough memory     

    // We initialize the new created element
    newElement->key = key;		// It can be NULL (useful for some "twisted" values like "events", ...)
    newElement->type = UNKNOWN;		// TO BE CHANGED after calling the addElement function
    newElement->compValue = NULL;
 //   newElement->immValue.f = NULL;
    // C'est le dernier element
    newElement->next = NULL;

//    printf("CHKPT ADDELEMENT 1 : %s\n", key);    
//    printf("More Info: list = %p\n", list);    
    

    if(*list == NULL) { // If list is already empty
	
//	printf("CHKPT ADDELEMENT 2 : %p\n", newElement);           
	
	*list = newElement;	// !!!  IS IT REAALLY NECESSARY TO KEEP THIS COMMAND
        return newElement;

    } else { // We are adding the new element in the end of the list
        
//	printf("CHKPT ADDELEMENT 3\n");      

        presult *temp = *list;	// !!!

        while(temp->next != NULL) {

            temp = temp->next;
        }
	
//	printf("CHKPT ADDELEMENT 4 : %p\n", newElement);      

        temp->next = newElement;

        return newElement;
    }
}

// extract the value of the 
char* extractStringAttribute(presult *list, char* key){
	presult *tmp;
    	tmp = list;	
    
 //   printf("ShowResult, more Info: list = %p\n", list);     


    while(tmp != NULL) {
        

	if (tmp->type == STRING){
		if (!strcmp(key, tmp->key)){	// If the key is found
			return tmp->value.s;
		}  
	}		 	
 	
        tmp = tmp->next;    
    }

	return NULL;
}

// Prints the content of the presult list using showResult_
void showResult(presult *list) {
	printf("\n\n---------------------------------------------------------------\n");
	printf("-----------------------  SHOW RESULT  -------------------------\n");
	printf("---------------------------------------------------------------\n\n");
	showResult_(list);
	printf("\n\n---------------------------------------------------------------\n");
	printf("----------------------------  END  ----------------------------\n");
	printf("---------------------------------------------------------------\n\n");

}

// Prints the content of the presult list
void showResult_(presult *list) { 

    presult *tmp;
    tmp = list;	
    
 //   printf("ShowResult, more Info: list = %p\n", list);     


    while(tmp != NULL) {
	
	if (tmp->key == NULL){
		printf("{ key : NULL , ");
	} else {
		printf("{ key : %s , ", tmp->key);
	}
        

	switch(tmp->type) {

		case INTEGER:
			printf("value(INTEGER) : %d } ", tmp->immValue.i);
		break;
		
		case FLOAT:
			printf("value(FLOAT) : %f } ", tmp->immValue.f);
		break;

		case STRING:
			if (tmp->immValue.s != NULL){
				printf("value(STRING) : %s } ", tmp->immValue.s);
			} else {
				printf("value(STRING) : NULL } ");
			}
		break;

		case COMPLEX:	// if it's a JSON object or a JSON array
			printf("	[");
			showResult_(tmp->compValue);
			printf("	] }  ");
		break;

    		default:	// UNKNOWN
      		exit(EXIT_FAILURE);
      		break;

	}
		 	
 	
        tmp = tmp->next;
	if (tmp) printf(",\n");       
    }

    printf("\n");       	
}



// Sees if the presult list is empty or not
int isEmpty (presult *list) {
    return (list == NULL)? 1 : 0;
}


/*
presult deleteElement(presult **list) {	// Supprime un element en queue de la liste
    
    if (*list == NULL){ // Si la liste est vide
	return NULL;
    } else {
  
    	if((*list)->next == NULL) { // Si la liste contient un seul element
        
        	free(*list); // On libere l'element 
        	return NULL;
	} else {	// Si on a plus qu'un element : parcours de la liste

    		presult *tmp1 = *list; // Pointe sur le dernier element
    		presult *tmp2 = *list; // Pointe sur l'avant dernier element 

    		
    		while((*tmp1)->next != NULL) {
       		 
        		tmp2 = tmp1;
        		
        		tmp1 = (*tmp1)->next;
    		}

    		(*tmp2->next) = NULL; // l'avant dernier devient le dernier
    		free(tmp1);
		return list;	// !!!

	}
    }
 
}



presult findElement(presult list, char* key) { // Rechercher l'element dont la clé est key
    element *tmp=list;
    
    while(tmp != NULL)
    {
        if(!strcmp(tmp->key, key)) {
        
            return tmp;
        } else {

        tmp = tmp->next;
	
	}
    }
    return NULL; // Si on ne trouve pas l'element recherche
}


presult findElementNumber(presult list, int index)
{   
    element *tmp=list;    
    int i;

    for(i=0; i<index && tmp != NULL; i++) {
        tmp = tmp->next;
    }
 
    if(tmp == NULL) { // S'il y a moins de "index" elements dans "list"
        return NULL;
    } else {
        return tmp;
    }
}


void removeResult(presult list) {
    if(list != NULL) { // Si la liste est NULL alors on a rien a faire
        element *tmp;
        tmp = list->next;
	removeResult(list->compValue); // On libere la liste des valeurs complexes
        free(list);
        removeResult(tmp);
    }
}

*/



// Puts all the characters into upper case
void UpCase(char *string)
{
  register int t;

  for(t=0; string[t]; ++t)  {
    string[t] = toupper(string[t]);
  }
}



// !!!  SOME MORE TESTS ARE REQUIRED HERE TO SEE IF WE CAN GET ALL THE STATES OR NOT !!!!!


// Prints the DRMAA state of the job (conversion of OAR states)
void getDrmaaState(presult *list){ 

    presult *tmp;
    tmp = list;	
    char state[20]= "Hold";


    while((tmp != NULL)&&(tmp->key!=NULL)&&(strcmp("state", tmp->key))) {

        tmp = tmp->next;
    }
    if (tmp != NULL){	// We were able to get the job state

//	printf("CHK PT 1\n");		

	strcpy (state, tmp->immValue.s);

//	printf("CHK PT 2\n");

	UpCase(state);

//	printf("CHK PT 3\n");

	printf("OAR STATE = %s\n",state); 

	if (!strcmp("WAITING", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_QUEUED_ACTIVE ");

	} else if (!strcmp("HOLD", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_USER_ON_HOLD"); // !! for the moment, only the user can request a HOLD in OAR !!

	} else if (!strcmp("TOLAUNCH", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_QUEUED_ACTIVE ");

	} else if (!strcmp("TOERROR", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_FAILED");

	} else if (!strcmp("TOACKRESERVATION", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_UNDETERMINED");

	} else if (!strcmp("LAUNCHING", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_RUNNING");

	} else if (!strcmp("FINISHING", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_RUNNING");

	} else if (!strcmp("RUNNING", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_RUNNING");

	} else if (!strcmp("SUSPENDED", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_USER_SUSPENDED"); // !! for the moment, only the user can request a SUSPEND in OAR !!

	} else if (!strcmp("RESUMING", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_USER_SUSPENDED"); // !! for the moment, only the user can request a RESUME in OAR !!

	} else if (!strcmp("TERMINATED", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_DONE");

	} else if (!strcmp("ERROR", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_FAILED");	// Here, we should parse the message to get the error number

	} else {
		printf("DRMAA STATE = %s\n","DRMAA_PS_UNDETERMINED"); 
	}


    } else {	// We were not able to get the OAR state of the job !!

	printf("NO OAR STATE FOUND\n"); 
	printf("DRMAA STATE = %s\n","DRMAA_PS_UNDETERMINED"); 
	
    }
          	
}
