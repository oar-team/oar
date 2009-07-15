#include <stdlib.h>
#include "presult.h"

// Les entrées/sorties sur la liste chainée presult (contenant le résultat d'un GET par exemple)

presult addElement(presult list, char* key, char* immValue, presult compValue) { // Pour l'instant, on ajoute l'element a la fin (consomme plus de CPU que l'ajout en tete mais concerve l'ordre)
    // On crée un nouvel element
    element* newElement = malloc(sizeof(element));
 
    // On définie les valeurs du nouvel élément
    newElement->key = key;
    newElement->immValue = immValue;
    newElement->compValue = compValue;

    // C'est le dernier element
    newElement->next = NULL;
 
    if(list == NULL) { // Si la liste ne contient aucun élement
        
        return newElement;

    } else { // Sinon, on l'ajoute à la fin
        
        element* temp = list;

        while(temp->next != NULL) {

            temp = temp->next;
        }

        temp->next = newElement;

        return list;
    }
}

void showResult(presult list) { // Affiche une liste chainée contenant le résultat

    element *tmp = list;

    while(tmp != NULL) {

        printf("{ key : %s , ", tmp->key);
	if (tmp->compValue != NULL){ // Si la valeur est de type complexe (contient plusieurs elements)
		printf("[");
		showResult(tmp->compValue);
		printf("] }  ");
	} else { // S'il s'agit d'une valeur de type simple
		if (tmp->immValue != NULL){
			printf("value : %s } ", tmp->immValue);
		} else {
			printf("value : NULL } ");
		}
	}		 	
	printf(",");       
 	
        tmp = tmp->next;
    }
}

int isEmpty (presult list) {
    return (list == NULL)? 1 : 0;
}


presult deleteElement(presult list) {	// Supprime un element en queue de la liste
    
    if (list == NULL){ // Si la liste est vide
	return NULL;
    } else {
  
    	if(list->next == NULL) { // Si la liste contient un seul element
        
        	free(list); // On libere l'element 
        	return NULL;
	} else {	// Si on a plus qu'un element : parcours de la liste

    		element* tmp1 = list; // Pointe sur le dernier element
    		element* tmp2 = list; // Pointe sur l'avant dernier element 

    		
    		while(tmp1->next != NULL) {
       		 
        		tmp2 = tmp1;
        		
        		tmp1 = tmp1->next;
    		}

    		tmp2->next = NULL; // l'avant dernier devient le dernier
    		free(tmp1);
    		return list;	

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
