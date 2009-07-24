/**
	JSON parser v2 : we create a Linked list for the received JSON stream 
*/

#include <glib.h>
#include <stdlib.h>
#include <glib-object.h>
#include <json-glib/json-glib.h>

// In order to use the presult structure which will contain the parsing-result
//#include "presult.h"
#include "jparser.h"


static void putIntoResultList(JsonNode *node, presult **result);
static int load_json(const gchar *file);



// A temporary main for tests
/*
int main(int argc, char **argv) {

  if( argc < 2 ) {
    g_print ("Usage: test <filename.json>\n");
    return EXIT_FAILURE;
  }
  
  return load_json(argv[1]);
}
*/

// Loads a JSON stream from a file, parses it and give back the result
static int load_json(const gchar *file) {

  g_type_init();

  JsonParser *parser = NULL;				// The JSON parser
  JsonNode *root = NULL;
  GError *error = NULL;
  parser = json_parser_new ();
  error = NULL;
  json_parser_load_from_file (parser, file, &error);	//We load a JSON stream from the file "file"

//  TO READ FROM A BUFFER AND NOT FROM A FILE
//  gchar *data;
//  json_parser_load_from_data (parser, data, sizeof(data), &error); //strlen() ??

  presult *result = NULL;				// The linked list which will contain the result
  result = addElement(&result, NULL);

  if( error ) {		// If the JSON stream is corrupted, we return an EXIT_FAILURE state
    g_print ("Unable to parse `%s': %s\n", file, error->message);
    g_error_free (error);
    g_object_unref (parser);
    return EXIT_FAILURE;
  }

  root = json_parser_get_root (parser);
  
//  g_print("Checkpoint 1\n");

//  g_print("Result before : %p\n",&result);

  
  // We fill result with the stream data
  putIntoResultList(root, &result);     //print_json(root);
  result = result->compValue;		// We delete the fictional first element      !! SHOULD WE FREE SOME SPACE ??!!

//  g_print("Checkpoint 2\n");

  // Give back the result
  showResult(result);

//  g_print("Checkpoint 3\n"); 

  getDrmaaState(result); 

  // manipulate the object tree and then exit
  g_object_unref (parser);

  return EXIT_SUCCESS;
}

// Loads a JSON stream from "stream" and give back the result
jresult *load_json_from_stream(const gchar *stream) {

  g_type_init();

  JsonParser *parser = NULL;				// The JSON parser
  JsonNode *root = NULL;
  GError *error = NULL;
  parser = json_parser_new ();
  error = NULL;
//  json_parser_load_from_file (parser, file, &error);	//We load a JSON stream from the file "file"

//  TO READ FROM A BUFFER AND NOT FROM A FILE
  json_parser_load_from_data (parser, stream, strlen(stream), &error);

  presult *result = NULL;				// The linked list which will contain the result
  result = addElement(&result, NULL);

  jresult *res = malloc(sizeof(jresult));		// The JSON parsing result

  if( error ) {		// If the JSON stream is corrupted, we return an EXIT_FAILURE state
    g_print ("Unable to parse the stream: %s\n", error->message);
    g_error_free (error);
    g_object_unref (parser);
    res->status = EXIT_FAILURE;
    res->data = NULL;
    return res;
  }

  root = json_parser_get_root (parser);
  
//  g_print("Checkpoint 1\n");

//  g_print("Result before : %p\n",&result);

  
  // We fill result with the stream data
  putIntoResultList(root, &result);     //print_json(root);
  result = result->compValue;		// We delete the fictional first element      !! SHOULD WE FREE SOME SPACE ??!!

//  g_print("Checkpoint 2\n");

  // Give back the result
//  g_print ("Before puttting into structure\n");
//  showResult(result);
  
//  g_print("Checkpoint 3\n"); 

//  getDrmaaState(result); 


	// I have to find a solution to this problem (duplicate??): I have to do a  "g_object_unref (parser);"


  // manipulate the object tree and then exit
//  g_object_unref (parser);

  res->status = EXIT_SUCCESS;
  res->data = result;
  
//  g_print ("After puttting into structure\n");
// showResult(res->data);

  return res;
}


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
//		g_print(", \n"); 
	}
  }

//	g_print("Checkpoint NODE_OBJECT 3\n");  

  //g_print("}\n");

//	g_print("Checkpoint NODE_OBJECT 4\n");	

  g_list_free(members);		// We free some space
}



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

  g_list_free(elements);	/// We free some space
}


// COMPATIBILITY WITH UTF16 -> TO BE TESTED
static void putIntoResultList(JsonNode *node, presult **result) {

  switch( JSON_NODE_TYPE(node) ) {

  	case JSON_NODE_OBJECT:
    	//print_json_object(json_node_get_object(node));
//	g_print("Checkpoint NODE_OBJECT\n");
//  	g_print("Result2 after : %p\n",*result);
//  	g_print("result->compValue : %p\n",(*result)->compValue);
	(*result)->type = COMPLEX;	// TYPE = COMPLEX
	putObjectIntoResultList(json_node_get_object(node), &((*result)->compValue));	
    	break;

 	case JSON_NODE_ARRAY:
    	//print_json_array(json_node_get_array(node));
//	g_print("Checkpoint NODE_ARRAY\n");
	(*result)->type = COMPLEX;	// TYPE = COMPLEX
	putArrayIntoResultList(json_node_get_array(node), &((*result)->compValue));   
	break;

  	case JSON_NODE_VALUE:
    	switch(json_node_get_value_type(node)) {		// For the moment, the only used type in the OAR-API is String (char*) with the exception of "array_index" which is an Integer

    		case G_TYPE_BOOLEAN:{
//		g_print("Checkpoint NODE_BOOLEAN\n");
      		gboolean value = json_node_get_boolean(node);

      		//g_print("%s\n", value ? "true" : "false" );			
			if (value){
				(*result)->type = INTEGER;	// It becomes a Integer
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
		//sprintf(tmp_buffer, "%d", json_node_get_int(node));	
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
		(*result)->immValue.s = json_node_get_string(node);			
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
	(*result)->immValue.s = "NULL";	
    	//g_print("null\n");
    	break;

  	default:
//	g_print("Checkpoint NODE_UNKNOWN\n");
//    	g_print("node: unknown\n");
    	break;
  }
}

