#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>
#include "presult.h"

// Les entrées/sorties sur la liste chainée presult (contenant le résultat d'un GET par exemple)




void UpCase(char *string);

// Pour l'instant, on ajoute l'element a la fin (consomme plus de CPU que l'ajout en tete mais concerve l'ordre)
presult *addElement(presult **list, char* key) { 
    // On crée un nouvel element
    presult *newElement = malloc(sizeof(presult));

    if(!newElement) exit(EXIT_FAILURE); // En cas ou on n'arrive pas à reserver d l'espace mem. pour cet element     

    // On définie les valeurs du nouvel élément
    newElement->key = key;
    newElement->type = UNKNOWN;		// A changer lors de l'instanciation de "Value" (imm. ou comp.)
    newElement->compValue = NULL;
 //   newElement->immValue.f = NULL;
    // C'est le dernier element
    newElement->next = NULL;

//    printf("CHKPT ADDELEMENT 1 : %s\n", key);    
//    printf("More Info: list = %p\n", list);    
    

    if(*list == NULL) { // Si la liste ne contient aucun élement
	
//	printf("CHKPT ADDELEMENT 2 : %p\n", newElement);           
	
	*list = newElement;	// !!!  A voir si laisse comme ça ou non ?! si ça pose des problèmes ou pas  !!!
        return newElement;

    } else { // Sinon, on l'ajoute à la fin
        
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

void showResult(presult *list) {
	printf("\n\n---------------------------------------------------------------\n");
	printf("-----------------------  SHOW RESULT  -------------------------\n");
	printf("---------------------------------------------------------------\n\n");
	showResult_(list);
	printf("\n\n---------------------------------------------------------------\n");
	printf("----------------------------  END  ----------------------------\n");
	printf("---------------------------------------------------------------\n\n");

}

void showResult_(presult *list) { // Affiche une liste chainée contenant le résultat

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

		case COMPLEX:	// Si la valeur est de type complexe (contient plusieurs elements)
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


void UpCase(char *string)
{
  register int t;

  for(t=0; string[t]; ++t)  {
    string[t] = toupper(string[t]);
  }
}



// !!!   A TESTER POUR VOIR SI ON ARRIVE A AVOIR TOUS LES ETATS OU PAS !!!!!


void getDrmaaState(presult *list){ // Affiche l'état DRMAA correspondant à cet état OAR

    presult *tmp;
    tmp = list;	
    char state[20]= "Hold";


    while((tmp != NULL)&&(tmp->key!=NULL)&&(strcmp("state", tmp->key))) {

        tmp = tmp->next;
    }
    if (tmp != NULL){	// On a pu récuperer l'état OAR du Job

//	printf("CHK PT 1\n");		

	strcpy (state, tmp->immValue.s);

//	printf("CHK PT 2\n");

	UpCase(state);

//	printf("CHK PT 3\n");

	printf("OAR STATE = %s\n",state); 

	if (!strcmp("WAITING", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_QUEUED_ACTIVE ");

	} else if (!strcmp("HOLD", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_USER_ON_HOLD"); // !! expression régulière requise !!

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
		printf("DRMAA STATE = %s\n","DRMAA_PS_USER_SUSPENDED"); // !!  expression régulière requise !!

	} else if (!strcmp("RESUMING", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_USER_SUSPENDED"); // !!  expression régulière requise !!

	} else if (!strcmp("TERMINATED", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_DONE");

	} else if (!strcmp("ERROR", state)) {
		printf("DRMAA STATE = %s\n","DRMAA_PS_FAILED");	// Il faut récupérer le code d'erreur (il faut vior si la structure récupéré quand on a "ERROR" contient une clé appelé "state" ?)

	} else {
		printf("DRMAA STATE = %s\n","DRMAA_PS_UNDETERMINED"); 
	}


    } else {	// On n'a pas réussi à récuperer l'état OAR du système

	printf("NO OAR STATE FOUND\n"); 
	printf("DRMAA STATE = %s\n","DRMAA_PS_UNDETERMINED"); 
	
    }
          	
}
