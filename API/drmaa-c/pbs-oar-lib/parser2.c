/**
	Parseur du flux json de la OAR-API (avec renvoi d'une liste chainée comme resultat)
	!!! NE PAS OUBLIER DE LIBERER LA MEMOIRE DANS LE PROGRAMME APPELANT !!!
*/

#include <glib.h>
#include <stdlib.h>
#include <glib-object.h>
#include <json-glib/json-glib.h>

// Pour les entrées/sorties sur le type presult (parsing result)
#include "presult.h"


static void putIntoResultList(JsonNode *node, presult **result);
static int load_json(const gchar *file);



// Main temporaire pour tester
int main(int argc, char **argv) {

  if( argc < 2 ) {
    g_print ("Usage: test <filename.json>\n");
    return EXIT_FAILURE;
  }
  g_type_init();
  return load_json(argv[1]);
}

static int load_json(const gchar *file) {

  JsonParser *parser = NULL;
  JsonNode *root = NULL;
  GError *error = NULL;
  parser = json_parser_new ();
  error = NULL;
  json_parser_load_from_file (parser, file, &error);

  // La liste chainée contenant le résultat de la requete
  presult *result = NULL;
  result = addElement(&result, NULL);

  if( error ) {
    g_print ("Unable to parse `%s': %s\n", file, error->message);
    g_error_free (error);
    g_object_unref (parser);
    return EXIT_FAILURE;
  }

  root = json_parser_get_root (parser);
  
//  g_print("Checkpoint 1\n");

//  g_print("Result2 before : %p\n",&result);

  
  // remplissage de la presult par les informations du flux JSON
  putIntoResultList(root, &result);     //print_json(root);
  result = result->compValue;	// Pour enlever le premier element (qui est fictif)  

//  g_print("Checkpoint 2\n");

  // Impression du résultat
  showResult(result);

//  g_print("Checkpoint 3\n"); 

  getDrmaaState(result); 

  /* manipulate the object tree and then exit */
  g_object_unref (parser);

  return EXIT_SUCCESS;
}


//static void print_json_object(JsonObject *object) {
static void putObjectIntoResultList(JsonObject *object, presult **result) {
	
//	g_print("Checkpoint NODE_OBJECT -2\n");	
	

  GList *next = NULL;
  GList *members = NULL;

//	g_print("Checkpoint NODE_OBJECT -1\n");	

  next = members = json_object_get_members(object);
	
//	g_print("Checkpoint NODE_OBJECT 0\n");  

  presult *currentElement;

//	g_print("Checkpoint NODE_OBJECT 1\n");


  //g_print("{");

//	g_print("Checkpoint NODE_OBJECT 2\n");

  while( next ) {

	//g_print("%s: ", (const gchar*)next->data );
//	printf("Parser, more Info: list = %p\n", *result); 
	currentElement = addElement(result, (const gchar*)next->data);
	JsonNode *node = json_object_get_member(object,(const gchar*)next->data);
	putIntoResultList(node, &currentElement);
	next = next->next;
	if( next ) {  
//		g_print(", \n"); 	// S'il y a d'autres elements, on imprime ','
	}
  }

//	g_print("Checkpoint NODE_OBJECT 3\n");  

  //g_print("}\n");

//	g_print("Checkpoint NODE_OBJECT 4\n");	

  g_list_free(members);	// Est ce qu'on les concerve pour liberer la mémoire
			// ou bien on les enlève pour utiliser la structure plus tard  ??
}


//static void print_json_array(JsonArray *array) {
static void putArrayIntoResultList(JsonArray *array, presult **result) {

  GList *elements, *l;
  presult *currentElement;

  elements = json_array_get_elements (array);

  //g_print("[\n");	

  for (l = elements; l != NULL; l = l->next) {
	JsonNode *element = l->data;
	currentElement = addElement(result, NULL);
	putIntoResultList(element, &currentElement);

	if (l!=NULL){
	//	g_print(",\n");
      	}     
  }  

  //g_print("]");

  g_list_free(elements);	// Est ce qu'on les concerve pour liberer la mémoire
				// ou bien on les enlève pour utiliser la structure plus tard  ??
}


// COMPATIBILITE AVEC UTF16 ?! -> A TESTER
static void putIntoResultList(JsonNode *node, presult **result) {

  switch( JSON_NODE_TYPE(node) ) {	// A vérifier si elle couvre tous les types ou non !! (pour l'instant le seul type de retour utilisé dans la OAR-API est le String (char*) )

  	case JSON_NODE_OBJECT:
    	//print_json_object(json_node_get_object(node));
//	g_print("Checkpoint NODE_OBJECT\n");
//  	g_print("Result2 after : %p\n",*result);
//  	g_print("result->compValue : %p\n",(*result)->compValue);
	(*result)->type = COMPLEX;	// TYPE = COMPLEX
	putObjectIntoResultList(json_node_get_object(node), &((*result)->compValue));	//Evo
    	break;

 	case JSON_NODE_ARRAY:
    	//print_json_array(json_node_get_array(node));
//	g_print("Checkpoint NODE_ARRAY\n");
	(*result)->type = COMPLEX;	// TYPE = COMPLEX
	putArrayIntoResultList(json_node_get_array(node), &((*result)->compValue));   //Evo 	
	break;

  	case JSON_NODE_VALUE:
    	switch(json_node_get_value_type(node)) {

    		case G_TYPE_BOOLEAN:{
//		g_print("Checkpoint NODE_BOOLEAN\n");
      		gboolean value = json_node_get_boolean(node);

      		//g_print("%s\n", value ? "true" : "false" );			
			if (value){					//Evo (transformation en char*)
				(*result)->type = INTEGER;
				(*result)->immValue.i = 1;
			} else {
				(*result)->type = INTEGER;
				(*result)->immValue.i = 0;	
			}
      		}break;

   		case G_TYPE_INT:
//		g_print("Checkpoint NODE_INT\n");

		(*result)->type = INTEGER;
		(*result)->immValue.i = json_node_get_int(node);
		//char tmp_buffer[7];
		//sprintf(tmp_buffer, "%d", json_node_get_int(node));		//Evo (transformation en char*)
		//(*result)->immValue = tmp_buffer;
     		//g_print("%d", json_node_get_int(node));
		break;

    		case G_TYPE_LONG:
//     		g_print("%d", json_node_get_int(node));
		(*result)->type = INTEGER;
		(*result)->immValue.i = json_node_get_int(node);
      		break;

    		case G_TYPE_UINT:
//     		g_print("%d", json_node_get_int(node));
		(*result)->type = INTEGER;
		(*result)->immValue.i = json_node_get_int(node);
		break;

    		case G_TYPE_ULONG:
//     		g_print("%d", json_node_get_int(node));
		(*result)->type = INTEGER;
		(*result)->immValue.i = json_node_get_int(node);
      		break;

    		case G_TYPE_ENUM:
      		break;

    		case G_TYPE_STRING:
//		g_print("Checkpoint NODE_STRING\n");
		(*result)->type = STRING;
		(*result)->immValue.s = json_node_get_string(node);			// Evo
      		// g_print("\"%s\"", json_node_get_string(node));
      		break;

    		case G_TYPE_FLOAT:	
//     		g_print("%f", json_node_get_double(node));
		(*result)->type = FLOAT;
		(*result)->immValue.f = json_node_get_double(node);
      		break;

    		case G_TYPE_DOUBLE:
 //    		g_print("%f", json_node_get_double(node));
		(*result)->type = FLOAT;
		(*result)->immValue.f = json_node_get_double(node);
      		break;

    		case G_TYPE_POINTER:
		break;

    		case G_TYPE_BOXED:
		break;

    		case G_TYPE_PARAM:
		break;

    		case G_TYPE_OBJECT:
		break;

    		default:
      		g_print("unsupported type!\n");
      		break;
    	}
    	break;

  	case JSON_NODE_NULL:
//	g_print("Checkpoint NODE_NULL\n");
	(*result)->type = STRING;
	(*result)->immValue.s = "NULL";							// Evo
    	//g_print("null\n");
    	break;

  	default:
//	g_print("Checkpoint NODE_UNKNOWN\n");
//    	g_print("node: unknown\n");
    	break;
  }
}

