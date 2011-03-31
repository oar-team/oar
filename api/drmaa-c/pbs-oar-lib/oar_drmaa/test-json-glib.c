/*
export LD_LIBRARY_PATH=/home/auguste/prog/json-glib-0.12.0/lib

gcc -I include/json-glib-1.0/ -I /usr/include/glib-2.0/ -I /usr/lib/glib-2.0/include/  -Llib/ -ljson-glib-1.0 builder-test.c 




*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <glib-object.h>

#include <json-glib/json-glib.h>

static const gchar *complex_object = "{ \"depth1\" : [ 1, { \"depth2\" : [ 2.3, [ null ], \"after array\" ], \"value2\" : true } ], \"object1\" : { } }\") == 0)";

int
main (int argc, char *argv[])
{
  g_type_init (); /* only once ???*/

  JsonBuilder *builder = json_builder_new ();
  JsonNode *node;
  JsonGenerator *generator;
  gsize length;
  gchar *data;

  json_builder_begin_object (builder);

  json_builder_set_member_name (builder, "depth1");
  json_builder_begin_array (builder);
  json_builder_add_int_value (builder, 1);

  json_builder_begin_object (builder);

  json_builder_set_member_name (builder, "depth2");
  json_builder_begin_array (builder);
  json_builder_add_double_value (builder, 2.3);

  json_builder_begin_array (builder);
  json_builder_add_null_value (builder);
  json_builder_end_array (builder);

  json_builder_add_string_value (builder, "after\"yop\" array");
  json_builder_end_array (builder); /* depth2 */

  json_builder_set_member_name (builder, "value2");
  json_builder_add_boolean_value (builder, TRUE);
  json_builder_end_object (builder);

  json_builder_end_array (builder); /* depth1 */

  json_builder_set_member_name (builder, "object1");
  json_builder_begin_object (builder);
  json_builder_end_object (builder);

  json_builder_end_object (builder);

  node = json_builder_get_root (builder);
  g_object_unref (builder);

  generator = json_generator_new ();
  json_generator_set_root (generator, node);
  data = json_generator_to_data (generator, &length);
  if (g_test_verbose ())
    {
      g_print ("Builder complex: %*s", (int)length, data);
    }
 /*
  g_assert (strncmp (data, complex_object, length) == 0);
*/
  printf("data: %s \n",data);

  g_free (data);
  json_node_free (node);
  g_object_unref (generator);
}

