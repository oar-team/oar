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

#define INT_1_0_2 0x010002 

int oar_errno = 0;

char *oar_api_server_url;
char oar_api_server_url_default[]="http://localhost";

int api_version = 0;

const char *drmaa_control_to_oar_rest[] = {
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
    fsd_log_fatal(("not enough memory (realloc returned NULL)\n"));
    exit(EXIT_FAILURE);
  }

  memcpy(&(mem->memory[mem->size]), ptr, realsize);
  mem->size += realsize;
  mem->memory[mem->size] = 0;

  return realsize;
}

struct memory_struct recv_data;

void init_recv_data()
{
    if(recv_data.memory) {
        free(recv_data.memory);
        /* ready for next receive */
        recv_data.memory = malloc(1);  /* will be grown as needed by the realloc above */
        recv_data.size = 0;
    }
    /* send all received data to this function  */
    curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, write_memory_callback);
    /* we pass our 'recv_data' struct to the callback function */
    curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, (void *)&recv_data);
}

void oar_api_http_error(long http_code, JsonReader *reader) {

  char *title=NULL;
  char *message=NULL;
  int code=0;

  if (http_code < 200 || http_code > 299) {

    json_reader_read_member(reader,"title");
    title = (char *)json_reader_get_string_value(reader);
    json_reader_end_element (reader);

    json_reader_read_member(reader,"message");
    message = (char *)json_reader_get_string_value (reader);
    json_reader_end_element (reader);

    json_reader_read_member(reader,"code");
    code = json_reader_get_int_value (reader);
    json_reader_end_element (reader);
  
    fsd_log_error(("HTTP error code: %ld", http_code));
    fsd_log_error(("title: %s", title));
    fsd_log_error(("message: %s", message));
    fsd_log_error(("code: %d", code));
  }
}




int oar_connect(char *server)
{
    JsonParser *parser; 
    JsonReader *reader;
    GError *error = NULL;
    char *env_oar_api_server_url;
    char rest_url[256];
    long http_code = 0;
    char *api_version_str;
    char *token;
    int i = 0;

#ifdef DEBUG
    fsd_set_verbosity_level(FSD_LOG_ALL);
#endif

    g_type_init (); /* only once */
    parser = json_parser_new ();
    reader = json_reader_new (NULL);

    
    /* set oar_api_server_url */
    env_oar_api_server_url = getenv("OAR_API_SERVER_URL");
    if (env_oar_api_server_url != NULL) {
      oar_api_server_url = env_oar_api_server_url;
    } else {
      oar_api_server_url = oar_api_server_url_default; /* set default url as server url */
    }


    /* intialize recv_data in memory storage */
    recv_data.memory = malloc(1);  /* will be grown as needed by the realloc above */
    recv_data.size = 0;

    curl_global_init(CURL_GLOBAL_ALL);
    curl_handle = curl_easy_init();
    if(!curl_handle) {
        fsd_log_fatal(("no curl handle\n"));
        exit(EXIT_FAILURE);
    }

    /* send all received data to this function  */
    curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, write_memory_callback);
    /* we pass our 'recv_data' struct to the callback function */
    curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, (void *)&recv_data);
    /* some servers don't like requests that are made without a user-agent field, so we provide one */
    curl_easy_setopt(curl_handle, CURLOPT_USERAGENT, "libcurl-agent/1.0");

    /* retreive oarapi version*/
    sprintf(rest_url,"%s/oarapi/version.json",oar_api_server_url);

    curl_easy_setopt(curl_handle, CURLOPT_URL, rest_url);
    res = curl_easy_perform(curl_handle); /* */
    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &http_code);

    if (res != CURLE_OK)
      fsd_log_error(("Curl curl_easy_getinfo failed: %s\n", curl_easy_strerror(res)));
 
    /* printf("%lu bytes retrieved\n", (long)recv_data.size); */

    json_parser_load_from_data (parser, recv_data.memory, -1, &error);
    json_reader_set_root (reader, json_parser_get_root (parser));

    /* test http error from oar-api reponse */
    oar_api_http_error(http_code, reader);

    /* printf("number of members: %d\n", json_reader_count_members (reader)); */
    json_reader_read_member (reader, "api_version");
    api_version_str = json_reader_get_string_value(reader);
    fsd_log_debug(("oarapi version:%s\n", api_version_str));

    token = strtok(api_version_str, ".");
    while( token != NULL ) {
      api_version += (atoi(token)) << (16 - i);
      i += 8;
      token = strtok(NULL, ".");
    }

    g_object_unref (reader);
    g_object_unref (parser);

    if(recv_data.memory) {
        free(recv_data.memory);
        /* ready for next receive */
        recv_data.memory = malloc(1);  /* will be grown as needed by the realloc above */
        recv_data.size = 0;
    }

    fsd_log_debug(( "oar-connect\n"));

    return 0;
}

int oar_disconnect(int connect)
{ 
    /* we're done with libcurl, so clean it up */
    curl_global_cleanup();
    return 0;
}

int oar_control_job(int connect, char *job_id, int action)
{
    /* printf("oar_job_control: job_id: %s action: %i  drmaa_control: %s\n", job_id, action, drmaa_control_to_str(action)); */
    /* CURL */
    long http_code = 0;
    char rest_url[256];
    struct curl_slist *headers = NULL;
    sprintf(rest_url,"%s/oarapi/jobs/%s%s",oar_api_server_url,job_id,drmaa_control_to_oar_rest[action]);
    /*printf("url:%s\n",rest_url); */
    headers = curl_slist_append(headers, "Content-Type: application/json");
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, "");
    curl_easy_setopt(curl_handle, CURLOPT_URL, rest_url);
    res = curl_easy_perform(curl_handle);
    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &http_code);
    /* printf("http code %ld\n",http_code); */

    /* read response */
    JsonParser *parser = json_parser_new ();
    JsonReader *reader = json_reader_new (NULL);
    GError *error = NULL;

    /* printf("%lu bytes retrieved\n", (long)recv_data.size); */
    json_parser_load_from_data (parser, recv_data.memory, -1, &error);
    json_reader_set_root (reader, json_parser_get_root (parser));

    /* test return http status */
    oar_api_http_error(http_code, reader);

    /* clean recv/reader/parser stuff */
    g_object_unref (reader);
    g_object_unref (parser);
    if(recv_data.memory) {
        free(recv_data.memory);
        /* ready for next receive */
        recv_data.memory = malloc(1);  /* will be grown as needed by the realloc above */
        recv_data.size = 0;
    }

    return 0;
}

struct batch_status *oar_statjob(int connect, char *id)
{
    char *state = NULL;
    int exit_code = -2;
    int walltime = 0;
    char *queue = NULL;
    int job_id = 0;

    struct batch_status *b_status = malloc(sizeof(struct batch_status));

    /* CURL stuff */
    long http_code = 0;
    char rest_url[256];
    char *exit_code_str;
    struct curl_slist *headers = NULL;
    sprintf(rest_url,"%s/oarapi/jobs/%s.json",oar_api_server_url,id);
    /* fsd_log_debug(("url:%s\n",rest_url)); */
    headers = curl_slist_append(headers, "Content-Type: application/json");

    init_recv_data();

    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl_handle, CURLOPT_HTTPGET, 1L); /* perform a get http request */
    curl_easy_setopt(curl_handle, CURLOPT_URL, rest_url);
    res = curl_easy_perform(curl_handle);
    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &http_code);

    /* read response */
    JsonParser *parser = json_parser_new ();
    JsonReader *reader = json_reader_new (NULL);
    GError *error = NULL;

    /* fsd_log_debug(("%lu bytes retrieved\n", (long)recv_data.size)); */
    json_parser_load_from_data (parser, recv_data.memory, -1, &error);
    json_reader_set_root (reader, json_parser_get_root (parser));

    /* test return http status */

    if (http_code >= 200 && http_code < 300) /* http successful */
    {
        json_reader_read_member (reader,"id");
        job_id = json_reader_get_int_value (reader);
        json_reader_end_element (reader);

        json_reader_read_member (reader,"state");
        state = json_reader_get_string_value(reader); /* need to free after use ??? */
        json_reader_end_element (reader);

        json_reader_read_member(reader,"exit_code");

        if (!json_reader_get_null_value(reader))
        {

	  if (api_version >= INT_1_0_2) { 
	    exit_code = json_reader_get_int_value (reader);
	  } else {
	    exit_code_str = json_reader_get_string_value(reader);
            exit_code = atoi(exit_code_str);
	  }
	  
	  if ((exit_code & 0x7f) == 0) {
	      exit_code = exit_code >> 8;
            } else {
	    exit_code = (exit_code & 0x7f) + 128;
	  }
            /* fsd_log_debug(("exit_code_str: %s exit_code8: %d\n",exit_code_str, exit_code)); */
        }
        json_reader_end_element (reader);

        json_reader_read_member (reader,"walltime");
	if (api_version >= INT_1_0_2) {
	  walltime = json_reader_get_int_value (reader);
	} else {
	  if (!json_reader_get_null_value(reader))   {
	    walltime = atoi(json_reader_get_string_value(reader));
	  }
	}
	json_reader_end_element (reader);
	  
        json_reader_read_member (reader,"queue");
        queue = json_reader_get_string_value(reader);
        json_reader_end_element (reader);

        /*printf("job state: %s\n",state);*/
        fsd_log_debug(("job state: %s\n",state));
    } else
    {
        /* test return http status */
      oar_api_http_error(http_code, reader);

    }

    struct oar_job_status *j_status = malloc(sizeof(struct oar_job_status ));

    j_status->id = job_id; /*TODO do we need it ? assert between job_id and atoi(id) */
    j_status->state = fsd_strdup(state);
    j_status->exit_status = exit_code;
    j_status->walltime = walltime;
    j_status->queue = fsd_strdup(queue);

    b_status->name = fsd_strdup(id);
    b_status->next = NULL;
    b_status->status = j_status;
    b_status->text = fsd_strdup(""); /* In order to avoir freeing problems in pbs_statfree */

    /* clean recv/reader/parser stuff TODO */
    g_object_unref (reader);
    g_object_unref (parser);

    if(recv_data.memory) {
        free(recv_data.memory);
        recv_data.memory = malloc(1);
        recv_data.size = 0;
    }

    /* TODO if return NULL and set oar_errno approprietly*/

    return b_status;
}

struct batch_status * oar_multiple_statjob(int connect, char **job_ids)
{
    struct batch_status *j_status;
    struct batch_status *b_status=NULL;
    struct batch_status *cur_status=NULL;

    /* iterate on job_ids (list of job id) */
    while(*job_ids !=NULL)
    {
        j_status = oar_statjob(connect, *job_ids);
        if(j_status==NULL)
        {
            fsd_log_debug(("TODO oar_statjob return NULL in oar_multiple_statjob\n"));
        }

        if (cur_status == NULL) {
            b_status = j_status;
            cur_status = j_status;
        } else
        {
            cur_status->next = j_status;
            cur_status = j_status;
        }
        job_ids++;
    }

    return b_status; /* TODO return null if ERROR */

}

char *oar_submit(int connect, struct attropl *attrib, char *script_path, char *workdir, char *queue_destination)
{
    struct attropl *i;
    long http_code = 0;
    char *job_id_str;

    fsd_log_info(("oar_submit: script_path: %s\n%s\nqueue_destination %s\nattributs:\n", script_path, queue_destination));
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

    /* set script path is interpreted as commands with args by oar api*/ 
    json_builder_set_member_name (builder, "script_path");
    json_builder_add_string_value (builder, script_path);

    /* set workdir */
    if (workdir) { 
      json_builder_set_member_name (builder, "workdir");
      json_builder_add_string_value (builder, workdir);
    } 

     /* set queue */
    /* if (queue_destination) { */
      json_builder_set_member_name (builder, "queue");
      json_builder_add_string_value (builder, queue_destination);
    /* } */

    /* TODO native spec and array */
    for( i = attrib;  i != NULL;  i = i->next )
    {
        json_builder_set_member_name (builder, i->name);
        json_builder_add_string_value (builder, i->value);
    }


    json_builder_end_object (builder);
    node = json_builder_get_root (builder);

    generator = json_generator_new ();
    json_generator_set_root (generator, node);
    data = json_generator_to_data (generator, &length);

    fsd_log_debug(("data: >>>%s<<< \n",data));
    g_object_unref (builder);
    json_node_free (node);
    g_object_unref (generator);


    char rest_url[256];
    sprintf(rest_url,"%s/oarapi/jobs.json",oar_api_server_url);
    /*printf("rest_url:%s\n", rest_url); */

    /* CURL */
    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);

    curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, data);
    curl_easy_setopt(curl_handle, CURLOPT_URL, rest_url);

    res = curl_easy_perform(curl_handle);
    if (res != CURLE_OK)
      fsd_log_error(("Curl curl_easy_getinfo failed: %s\n", curl_easy_strerror(res)));

    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &http_code);

    fsd_log_debug(("%lu bytes retrieved\n", (long)recv_data.size));

    g_free (data);

    json_parser_load_from_data (parser, recv_data.memory, -1, &error);
    json_reader_set_root (reader, json_parser_get_root (parser));

    oar_api_http_error(http_code, reader);

    json_reader_read_member (reader,"id");
    int job_id = json_reader_get_int_value (reader);

    /* TODO if jobid = 0 erreur !!! , http error also ???? */

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
    return job_id_str;
}

void oar_status_dump(struct batch_status *stat)
{
    struct batch_status *next;
    while( stat!=NULL) {
        next = stat->next;
        fsd_log_debug(("job name: %s\n",stat->name));
        fsd_log_debug(("status: id: %d state: %s exit_status: %d walltime: %d queue: %s\n",
               stat->status->id, stat->status->state, stat->status->exit_status, stat->status->walltime, stat->status->queue));
        fsd_log_debug(("text: %s\n",stat->text));
        stat = next;
    }
}

void free_oar_job_status(struct oar_job_status *j_status)
{
    free(j_status->state);
    free(j_status->queue);
    free(j_status);
}

void oar_statfree(struct batch_status *stat)
{
#if 1
    struct batch_status *next;

    fsd_log_debug(("oar_statfree\n"));

    while( stat!=NULL) {
        next = stat->next;
        free(stat->name);
        free_oar_job_status(stat->status);
        free(stat->text);
        free(stat);
        stat = next;
    }
#endif
}

char *oar_errno_to_txt(int err_no)
{
    /*TODO: oar_errno_to_txt*/
    return "oar_errno_to_txt: not implemented\n";
}
