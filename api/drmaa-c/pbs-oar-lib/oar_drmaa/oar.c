#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include <drmaa_utils/conf.h>
#include <drmaa_utils/drmaa.h>
#include <drmaa_utils/drmaa_util.h>
#include <drmaa_utils/datetime.h>
#include <drmaa_utils/iter.h>
#include <drmaa_utils/template.h>
#include <oar_drmaa/oar_error.h>
#include <oar_drmaa/oar.h>
#include <oar_drmaa/util.h>

/* curl to perform http access*/
#include <curl/curl.h>
/* json-glib and glib to manipulate json. Be carefull need version >= 0.12.0 (for reader/builder) */
#include <glib.h>
#include <json-glib/json-glib.h>


#ifndef lint
static char rcsid[]
#	ifdef __GNUC__
                __attribute__ ((unused))
#	endif
        = "$Id: $";
#endif

int oar_errno = 0;

struct memory_struct {
  char *memory;
  size_t size;
};

CURL *curl_handle;
CURLcode res;
struct memory_struct recv_data; /* to store oar_rest_api get results */

static size_t
write_memory_callback(void *ptr, size_t size, size_t nmemb, void *data)
{
  size_t realsize = size * nmemb;
  struct memory_struct *mem = (struct memory_struct *)data;

  mem->memory = realloc(mem->memory, mem->size + realsize + 1);
  if (mem->memory == NULL) {
    /* out of memory! */
    printf("not enough memory (realloc returned NULL)\n");
    exit(EXIT_FAILURE);
  }

  memcpy(&(mem->memory[mem->size]), ptr, realsize);
  mem->size += realsize;
  mem->memory[mem->size] = 0;

  return realsize;
}

struct memory_struct recv_data;

int
oar_sigjob(int connect, char *job_id, char *signal)
{
    return 0;
}

int
oar_holdjob(int connect, char *job_id, char *hold_type)
{
    printf("oar_holdjob\n");
    return 0;
}

int
oar_connect(char *server)
{
    g_type_init (); /* only once ??? */
    JsonParser *parser = json_parser_new ();
    JsonReader *reader = json_reader_new (NULL);
    GError *error = NULL;

    /* intialize recv_data in memory storage */
    recv_data.memory = malloc(1);  /* will be grown as needed by the realloc above */
    recv_data.size = 0;

    curl_global_init(CURL_GLOBAL_ALL);
    curl_handle = curl_easy_init();
    if(!curl_handle) {
        printf("no curl handle\n");
        exit(EXIT_FAILURE);
    }

    /* send all received data to this function  */
    curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, write_memory_callback);
    /* we pass our 'recv_data' struct to the callback function */
    curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, (void *)&recv_data);
    /* some servers don't like requests that are made without a user-agent field, so we provide one */
    curl_easy_setopt(curl_handle, CURLOPT_USERAGENT, "libcurl-agent/1.0");



    curl_easy_setopt(curl_handle, CURLOPT_URL, "http://localhost/oarapi/resources.json");
    res = curl_easy_perform(curl_handle); /* */

    printf("%lu bytes retrieved\n", (long)recv_data.size);

    json_parser_load_from_data (parser, recv_data.memory, -1, &error);
    json_reader_set_root (reader, json_parser_get_root (parser));

    printf("number of members: %d\n", json_reader_count_members (reader));

    json_reader_read_member (reader, "total");
    json_reader_is_value (reader);
    printf("total: %d\n",json_reader_get_int_value (reader));

    g_object_unref (reader);
    g_object_unref (parser);

    if(recv_data.memory) {
        free(recv_data.memory);
        /* ready for next receive */
        recv_data.memory = malloc(1);  /* will be grown as needed by the realloc above */
        recv_data.size = 0;
    }

    fsd_set_verbosity_level(FSD_LOG_ALL);

    fsd_log_debug(( "OAR-CONNECT\n"));

    printf("oar_connect\n");

    return 0;
}


int oar_deljob(int connect, char *job_id)
{
    printf("oar_deljob\n");
    return 0;
}

int oar_disconnect(int connect)
{
    printf("oar_disconnect\n");

    /* we're done with libcurl, so clean it up */
    curl_global_cleanup();


    return 0;
}

int oar_rlsjob(int connect, char *job_id, char *hold_type)
{
    printf("oar_rlsjob\n");
    return 0;
}

void oar_statfree(struct batch_status *stat)
{
    printf("oar_statfree\n");
}

struct batch_status *oar_statjob(int connect, char *id, struct attrl *attrib)
{
    printf("oar_statjob\n");
    return 0;
}

char *job_id_foo;
char str_job_id[]="1234";
char *oar_submit(int connect, struct attropl *attrib, char *script_path, char *workdir, char *queue_destination)
{
    printf("oar_submit\n");
    printf("script_path: %s \nqueue_destination %s\n", script_path, queue_destination);
    oardrmaa_dump_attrl( attrib, NULL );

    /* builder */
    JsonBuilder *builder = json_builder_new ();
    JsonNode *node;
    JsonGenerator *generator;
    gsize length;
    gchar *data;

    /* reader */
    JsonParser *parser = json_parser_new ();
    JsonReader *reader = json_reader_new (NULL);
    GError *error = NULL;

    /* build request */

    json_builder_begin_object (builder);

    json_builder_set_member_name (builder, "script_path");
    json_builder_add_string_value (builder, script_path);

    json_builder_end_object (builder);
    node = json_builder_get_root (builder);

    generator = json_generator_new ();
    json_generator_set_root (generator, node);
    data = json_generator_to_data (generator, &length);

    printf("data: >>>%s<<< \n",data);
    g_object_unref (builder);
    json_node_free (node);
    g_object_unref (generator);

    /* CURL */

    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);

    curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, data);
    curl_easy_setopt(curl_handle, CURLOPT_URL, "http://localhost/oarapi/jobs.json");

    res = curl_easy_perform(curl_handle);

    printf("%lu bytes retrieved\n", (long)recv_data.size);

    g_free (data);

    json_parser_load_from_data (parser, recv_data.memory, -1, &error);
    json_reader_set_root (reader, json_parser_get_root (parser));
    json_reader_read_member (reader,"id");
    int job_id = json_reader_get_int_value (reader);
    printf("job id: %d\n",job_id);

    g_object_unref (reader);
    g_object_unref (parser);
/*
    job_id_foo = (char *)malloc((strlen(str_job_id) + 1) * sizeof(char));
    strcpy(job_id_foo, str_job_id);
 */

    job_id_foo = (char *)malloc(50);
    sprintf(job_id_foo,"%d",job_id);
    printf("job_id: %s\n",job_id_foo);
    return job_id_foo;
}

/*
fsd_template_t *oardrmaa_oar_template_new(void)
{
    printf("oardrmaa_oar_template_new\n");
    return 0;
}

int oardrmaa_oar_attrib_by_name( const char *name )
{
    printf("oardrmaa_oar_attrib_by_name\n");
    return 0;
}
*/
char *oar_errno_to_txt(int err_no)
{
    printf("oar_errno_to_txt\n");
    return 0;
}
