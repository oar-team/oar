/******************************************************************


OAR DRMAA-C : A C library for using the OAR DRMS
Copyright (C) 2009  LIG <http://www.liglab.fr/>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
<http://www.gnu.org/licenses/>

**********************************************************************/



/**
	JSON parser v2 : we create a Linked list for the received JSON stream 
*/

#include <glib.h>
#include <stdlib.h>
#include <glib-object.h>
#include <json-glib/json-glib.h>
#include "jparser.h"


static void putIntoResultList(JsonNode *node, presult **result);
static int load_json(const gchar *file);



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

  
  // We fill result with the stream data
  putIntoResultList(root, &result);     //print_json(root);
  result = result->compValue;		// We delete the fictional first element      !! SHOULD WE FREE SOME SPACE ??!!


  // Give back the result
  showResult(result);

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

  
  // We fill result with the stream data
  putIntoResultList(root, &result);     //print_json(root);
  result = result->compValue;		// We delete the fictional first element      !! SHOULD WE FREE SOME SPACE ??!!

 // manipulate the object tree and then exit
//  g_object_unref (parser);

  res->status = EXIT_SUCCESS;
  res->data = result;
  
//  g_print ("After puttting into structure\n");
// showResult(res->data);

  return res;
}


static void putObjectIntoResultList(JsonObject *object, presult **result) {
	

  GList *next = NULL;
  GList *members = NULL;
  presult *currentElement;

  next = members = json_object_get_members(object);


  while( next ) {

	currentElement = addElement(result, (const gchar*)next->data);
	JsonNode *node = json_object_get_member(object,(const gchar*)next->data);
	putIntoResultList(node, &currentElement);
	next = next->next;
  }

  g_list_free(members);		// We free some space
}



static void putArrayIntoResultList(JsonArray *array, presult **result) {

  GList *elements, *l;
  presult *currentElement;

  elements = json_array_get_elements (array);


  for (l = elements; l != NULL; l = l->next) {
	JsonNode *element = l->data;
	currentElement = addElement(result, NULL);
	putIntoResultList(element, &currentElement);    
  }  

  g_list_free(elements);	/// We free some space
}


// COMPATIBILITY WITH UTF16 -> TO BE TESTED
static void putIntoResultList(JsonNode *node, presult **result) {

  switch( JSON_NODE_TYPE(node) ) {

  	case JSON_NODE_OBJECT:
	(*result)->type = COMPLEX;	// TYPE = COMPLEX
	putObjectIntoResultList(json_node_get_object(node), &((*result)->compValue));	
    	break;

 	case JSON_NODE_ARRAY:
	(*result)->type = COMPLEX;	// TYPE = COMPLEX
	putArrayIntoResultList(json_node_get_array(node), &((*result)->compValue));   
	break;

  	case JSON_NODE_VALUE:
    	switch(json_node_get_value_type(node)) {	// For the moment, the only used type in the OAR-API is String (char*) with the exception of "array_index" which is an Integer

    		case G_TYPE_BOOLEAN:{
      		gboolean value = json_node_get_boolean(node);
		
			if (value){
				(*result)->type = INTEGER;	// Boolean will be converted to Integer
				(*result)->immValue.i = 1;	
			} else {
				(*result)->type = INTEGER;
				(*result)->immValue.i = 0;	
			}
      		}break;

   		case G_TYPE_INT:
		(*result)->type = INTEGER;
		(*result)->immValue.i = json_node_get_int(node);
		break;

    		case G_TYPE_LONG:
		(*result)->type = INTEGER;
		(*result)->immValue.i = json_node_get_int(node);
      		break;

    		case G_TYPE_UINT:
		(*result)->type = INTEGER;
		(*result)->immValue.i = json_node_get_int(node);
		break;

    		case G_TYPE_ULONG:
		(*result)->type = INTEGER;
		(*result)->immValue.i = json_node_get_int(node);
      		break;

    		case G_TYPE_ENUM:
      		break;

    		case G_TYPE_STRING:
		(*result)->type = STRING;
		(*result)->immValue.s = json_node_get_string(node);
      		break;

    		case G_TYPE_FLOAT:	
		(*result)->type = FLOAT;
		(*result)->immValue.f = json_node_get_double(node);
      		break;

    		case G_TYPE_DOUBLE:
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
	(*result)->type = STRING;
	(*result)->immValue.s = "NULL";	
    	break;

  	default:
//	g_print("Checkpoint NODE_UNKNOWN\n");
//    	g_print("node: unknown\n");
    	break;
  }
}

