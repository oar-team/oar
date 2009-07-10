#include <glib.h>
#include <stdlib.h>
#include <glib-object.h>
#include <json-glib/json-glib.h>

static void print_json(JsonNode *node);
static int print_json_from_file(const gchar *file);

/* Pour un meilleur affichage */
static size_t s_Level = 0;
static const char* s_pIndention = "  ";
static int s_IsKey = 0;

// Pour ameliorer l'affichage du résultat
static void print_indention() {
    size_t i;
    
    for (i = 0; i < s_Level; ++i) {
        printf(s_pIndention); // !!!!
    }
}


int main(int argc, char **argv) {

  if( argc < 2 ) {
    g_print ("Usage: test <filename.json>\n");
    return EXIT_FAILURE;
  }
  g_type_init();
  return print_json_from_file(argv[1]);
}

static int print_json_from_file(const gchar *file)
{
  JsonParser *parser = NULL;
  JsonNode *root = NULL;
  GError *error = NULL;
  parser = json_parser_new ();
  error = NULL;
  json_parser_load_from_file (parser, file, &error);

  if( error ) {
    g_print ("Unable to parse `%s': %s\n", file, error->message);
    g_error_free (error);
    g_object_unref (parser);
    return EXIT_FAILURE;
  }

  root = json_parser_get_root (parser);
  print_json(root);

  /* manipulate the object tree and then exit */
  g_object_unref (parser);

  return EXIT_SUCCESS;
}

static void print_json_object(JsonObject *object)
{
  GList *next = NULL;
  GList *members = NULL;
  next = members = json_object_get_members(object);

  if (!s_IsKey) print_indention();
  s_IsKey = 0;
  g_print("{");
  ++s_Level;

  while( next ) {
	s_IsKey = 1;
        print_indention();
	g_print("%s: ", (const gchar*)next->data );
	JsonNode *node = json_object_get_member(object,(const gchar*)next->data);
	print_json(node);
	next = next->next;
	if( next ) {  
		g_print(", \n"); 
	}
  }
  
  if (s_Level > 0) --s_Level;
  print_indention();
  g_print("}\n");

  g_list_free(members);	// Est ce qu'on les concerve pour liberer la mémoire
			// ou bien on les enlève pour utiliser la structure plus tard  ??
}

static void print_json_array(JsonArray *array)
{

  GList *elements, *l;

  elements = json_array_get_elements (array);

  if (!s_IsKey) print_indention();
  s_IsKey = 0;
  g_print("[\n");	
  ++s_Level;

  for (l = elements; l != NULL; l = l->next) {
	JsonNode *element = l->data;
	print_json(element);
	if (!s_IsKey) print_indention();
        s_IsKey = 0;
	if (l!=NULL){
		g_print(",\n");
      	}     
  }  

  if (s_Level > 0) --s_Level;
  print_indention();
  g_print("]");

  g_list_free(elements);	// Est ce qu'on les concerve pour liberer la mémoire
				// ou bien on les enlève pour utiliser la structure plus tard  ??
}


// TESTER LA COMPATIBILITE AVEC UTF16 !!
static void print_json(JsonNode *node)
{
  switch( JSON_NODE_TYPE(node) ) {	// A vérifier si elle couvre tous les types ou non !!

  	case JSON_NODE_OBJECT:
    	print_json_object(json_node_get_object(node));
    	break;

 	case JSON_NODE_ARRAY:
    	print_json_array(json_node_get_array(node));
    	break;

  	case JSON_NODE_VALUE:
    	switch(json_node_get_value_type(node)) {

    		case G_TYPE_BOOLEAN: {
      		gboolean value = json_node_get_boolean(node);
		if (!s_IsKey) print_indention();
        	s_IsKey = 0;
      		g_print("%s\n", value ? "true" : "false" );
      		} break;

   		case G_TYPE_INT:
		if (!s_IsKey) print_indention();
                s_IsKey = 0;
     		g_print("%d", json_node_get_int(node));
		break;

    		case G_TYPE_LONG:
		if (!s_IsKey) print_indention();
                s_IsKey = 0;
     		g_print("%d", json_node_get_int(node));
      		break;

    		case G_TYPE_UINT:
		if (!s_IsKey) print_indention();
                s_IsKey = 0;
     		g_print("%d", json_node_get_int(node));
		break;

    		case G_TYPE_ULONG:
      		g_print("%d", json_node_get_int(node));
      		break;

    		case G_TYPE_ENUM:
      		break;

    		case G_TYPE_STRING:
		if (!s_IsKey) print_indention();
        	s_IsKey = 0;
      		g_print("\"%s\"", json_node_get_string(node));
      		break;

    		case G_TYPE_FLOAT:	
		if (!s_IsKey) print_indention();
        	s_IsKey = 0;
      		g_print("%f", json_node_get_double(node));
      		break;

    		case G_TYPE_DOUBLE:
		if (!s_IsKey) print_indention();
        	s_IsKey = 0;
      		g_print("%f", json_node_get_double(node));
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
	if (!s_IsKey) print_indention();
        s_IsKey = 0;
    	g_print("null\n");
    	break;

  	default:
    	g_print("node: unknown\n");
    	break;
  }
}

