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

const char *drmaa_control_to_oar_rest[]={
    "/rholds/new.json",         /* DRMAA_CONTROL_SUSPEND   0 */
    "/resumptions/new.json",    /* DRMAA_CONTROL_RESUME    1 */
    "/holds/new.json",          /* DRMAA_CONTROL_HOLD      2 */
    "/resumptions/new.json",    /* DRMAA_CONTROL_RELEASE   3 */
    "/deletions/new.json"       /* DRMAA_CONTROL_TERMINATE 4 */
};






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
oar_connect(char *server)
{
    g_type_init (); /* only once */
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

int oar_disconnect(int connect)
{
    printf("TODO: oar_disconnect\n");

    /* we're done with libcurl, so clean it up */
    curl_global_cleanup();


    return 0;
}

int oar_control_job(int connect, char *job_id, int action)
{

    printf("oar_job_control: job_id: %s action: %i  drmaa_control: %s\n",
           job_id, action, drmaa_control_to_str(action));

    /* CURL */
    long http_code = 0;
    char *rest_url[256];
    struct curl_slist *headers = NULL;
    sprintf(rest_url,"http://localhost/oarapi/jobs/%s%s",job_id,drmaa_control_to_oar_rest[action]);
    /*printf("url:%s\n",rest_url); */
    headers = curl_slist_append(headers, "Content-Type: application/json");
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, "");
    curl_easy_setopt(curl_handle, CURLOPT_URL, rest_url);
    res = curl_easy_perform(curl_handle);
    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &http_code);
    printf("http code %ld\n",http_code);
    /* read response */
    JsonParser *parser = json_parser_new ();
    JsonReader *reader = json_reader_new (NULL);
    GError *error = NULL;
    printf("%lu bytes retrieved\n", (long)recv_data.size);
    json_parser_load_from_data (parser, recv_data.memory, -1, &error);
    json_reader_set_root (reader, json_parser_get_root (parser));

    /* test return http status */
    if (http_code >= 200 && http_code < 300) /* http successful */
    {
        json_reader_read_member (reader,"id");
        int job_id = json_reader_get_int_value (reader);
        json_reader_end_element (reader);
        printf("Http request successfull OK: job id: %d\n",job_id);
    } else
    {
        char *title=NULL;
        char *message=NULL;
        int code=0;
        json_reader_read_member(reader,"title");
        title = json_reader_get_string_value(reader);
        json_reader_end_element (reader);

        json_reader_read_member(reader,"message");
        message = json_reader_get_string_value (reader);
        json_reader_end_element (reader);

        json_reader_read_member(reader,"code");
        code = json_reader_get_int_value (reader);
        json_reader_end_element (reader);

        printf("title: %s\nmessage: %s\ncode: %d\n",title,message,code);

    }
    /* clean recv/reader/parser stuff */
    g_object_unref (reader);
    g_object_unref (parser);
    if(recv_data.memory) {
        free(recv_data.memory);
        /* ready for next receive */
        recv_data.memory = malloc(1);  /* will be grown as needed by the realloc above */
        recv_data.size = 0;
    }

    /* TODO */

    return 0;
}



struct batch_status *oar_statjob(int connect, char *id, struct attrl *attrib)
{

    /* TODO !!!
    man pbs_statjob (several mode , information on attrl)
    http://linux.die.net/man/3/pbs_statjob

    from iheb-work
        if id == NULL -> return the status of all jobs <- not implemented yet
        if id == queue Identifier ->  return the status of all jobs in the queue  <- not implemented yet
        if id == job id -> return the status of this job
        if attrl == NULL -> return all attributes
        if attrl != NULL -> return the attributes whose names are pointed by the attrl member "name".

     */
    if (id==NULL) {printf("Status of all jobs(not DONE and TERMINATED ???): TODO ");}
    if (atoi(id)==0)  {printf("Status jobs in the queue: %s Not Yet Implemented\n", id);}
    if (attrib==NULL)
    {
        printf("Return all attributs\n");
    } else
    {
        printf("Return indicates attributs\n");
    }

    struct batch_status *b_status = malloc(sizeof(struct batch_status));


    printf("TODO: oar_statjob\n");
    oardrmaa_dump_attrl(attrib, "oar_statjob");


    /* CURL stuff */
    long http_code = 0;
    char *rest_url[256];
    struct curl_slist *headers = NULL;
    sprintf(rest_url,"http://localhost/oarapi/jobs/%s.json",id);
    /*printf("url:%s\n",rest_url); */
    headers = curl_slist_append(headers, "Content-Type: application/json");
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl_handle, CURLOPT_HTTPGET, 1L); /* perform a get http request */
    curl_easy_setopt(curl_handle, CURLOPT_URL, rest_url);
    res = curl_easy_perform(curl_handle);
    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &http_code);
    printf("http code %ld\n",http_code);

    /* read response */
    JsonParser *parser = json_parser_new ();
    JsonReader *reader = json_reader_new (NULL);
    GError *error = NULL;

    printf("%lu bytes retrieved\n", (long)recv_data.size);
    json_parser_load_from_data (parser, recv_data.memory, -1, &error);
    json_reader_set_root (reader, json_parser_get_root (parser));


    /* test return http status */
    if (http_code >= 200 && http_code < 300) /* http successful */
    {
        json_reader_read_member (reader,"id");
        int job_id = json_reader_get_int_value (reader);
        json_reader_end_element (reader);
        printf("Http request successfull OK: job id: %d\n",job_id);

        json_reader_read_member (reader,"state");
        char *state = json_reader_get_string_value(reader); /* need to free after use ??? */
        json_reader_end_element (reader);
        printf("job state: %s\n",state);

        json_reader_read_member (reader,"exit_code");
        if (!json_reader_get_null_value(reader))
        {
            int exit_code = json_reader_get_int_value(reader);
            printf("exit_code: %d\n",exit_code);
        } else
        {
            printf("exit_code: is null\n"); /* set to -2 ... ???*/
        }
        json_reader_end_element (reader);
    } else
    {
        /* TODO */
    }




    /* attributes = presult2attrl(res->data,attrib); */
    /*
    attributes = oar_toPbsAttributes(oar_getLastEvent(res->data), presult2attrl(res->data,attrib));
    */
    b_status->name = fsd_strdup(id);
    b_status->next = NULL;
    /* b_status->attribs = attributes; */
    b_status->text = g_strdup("");	/* In order to avoir freeing problems in pbs_statfree */





    return 0;
}

char *job_id_str;
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

    if(recv_data.memory) {
        free(recv_data.memory);
        /* ready for next receive */
        recv_data.memory = malloc(1);  /* will be grown as needed by the realloc above */
        recv_data.size = 0;
    }

    job_id_str = (char *)malloc(50);
    sprintf(job_id_str,"%d",job_id);
    printf("job_id: %s\n",job_id_str);
    return job_id_str;
}

void oar_statfree(struct batch_status *stat)
{
    printf("TODO: oar_statfree ???\n");
}


char *oar_errno_to_txt(int err_no)
{
    printf("TODO: oar_errno_to_txt\n");
    return 0;
}
