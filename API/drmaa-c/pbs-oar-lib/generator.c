#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <glib-object.h>

#include <json-glib/json-glib.h>
#include <json-glib/json-gobject.h>

#define JOB_TYPE_OBJECT                (job_object_get_type ())
#define JOB_OBJECT(obj)                (G_TYPE_CHECK_INSTANCE_CAST ((obj), JOB_TYPE_OBJECT, JobObject))
#define JOB_IS_OBJECT(obj)             (G_TYPE_CHECK_INSTANCE_TYPE ((obj), JOB_TYPE_OBJECT))
#define JOB_OBJECT_CLASS(klass)        (G_TYPE_CHECK_CLASS_CAST ((klass), JOB_TYPE_OBJECT, JobObjectClass))
#define JOB_IS_OBJECT_CLASS(klass)     (G_TYPE_CHECK_CLASS_TYPE ((klass), JOB_TYPE_OBJECT))
#define JOB_OBJECT_GET_CLASS(obj)      (G_TYPE_INSTANCE_GET_CLASS ((obj), JOB_TYPE_OBJECT, JobObjectClass))

typedef struct _JobObject              JobObject;
typedef struct _JobObjectClass         JobObjectClass;


//
//	REVOIR LA CONVERSION DES STRINGS (Si les strings sont bien convertis ou non)
//


struct _JobObject	// Pour l'instant tous les paramètres de la OAR-API sont de type String
{
  GObject parent_instance;
  gchar *resource;
  gchar *script_path;
  gchar *script;
  gchar *workdir;
  gchar *other_options;
  gchar *action;

};

struct _JobObjectClass
{
  GObjectClass parent_class;
};

GType job_object_get_type (void);

/*** implementation ***/

enum
{
  PROP_0,

  PROP_RESOURCE,
  PROP_SCRIPT_PATH,
  PROP_SCRIPT,
  PROP_WORKDIR,
  PROP_OTHER_OPTIONS,	// voir oarsub --help
  PROP_ACTION
};

G_DEFINE_TYPE (JobObject, job_object, G_TYPE_OBJECT);

static void
job_object_finalize (GObject *gobject)	//liberer la mémoire (tous les pointeurs)
{
  g_free (JOB_OBJECT (gobject)->resource);
  g_free (JOB_OBJECT (gobject)->script_path);
  g_free (JOB_OBJECT (gobject)->script);
  g_free (JOB_OBJECT (gobject)->workdir);
  g_free (JOB_OBJECT (gobject)->other_options);
  g_free (JOB_OBJECT (gobject)->action);

  G_OBJECT_CLASS (job_object_parent_class)->finalize (gobject); //?
}

static void
job_object_set_property (GObject      *gobject,
                          guint         prop_id,
                          const GValue *value,
                          GParamSpec   *pspec)
{
  switch (prop_id)
    {
    case PROP_RESOURCE:
      g_free (JOB_OBJECT (gobject)->resource);
      JOB_OBJECT (gobject)->resource = g_value_dup_string (value);
      break;
    case PROP_SCRIPT_PATH:
      g_free (JOB_OBJECT (gobject)->script_path);
      JOB_OBJECT (gobject)->script_path = g_value_dup_string (value);
      break;
    case PROP_SCRIPT:
      g_free (JOB_OBJECT (gobject)->script);
      JOB_OBJECT (gobject)->script = g_value_dup_string (value);
      break;
    case PROP_WORKDIR:
      g_free (JOB_OBJECT (gobject)->workdir);
      JOB_OBJECT (gobject)->workdir = g_value_dup_string (value);
      break;
    case PROP_OTHER_OPTIONS:
      g_free (JOB_OBJECT (gobject)->other_options);
      JOB_OBJECT (gobject)->other_options = g_value_dup_string (value);
      break;
    case PROP_ACTION:	// delete, checkpoint, hold, resume, ...
      g_free (JOB_OBJECT (gobject)->action);
      JOB_OBJECT (gobject)->action = g_value_dup_string (value);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (gobject, prop_id, pspec);
    }
}

static void
job_object_get_property (GObject    *gobject,
                          guint       prop_id,
                          GValue     *value,
                          GParamSpec *pspec)
{
  switch (prop_id)
    {
    case PROP_RESOURCE:
      g_value_set_string (value, JOB_OBJECT (gobject)->resource);
      break;
    case PROP_SCRIPT_PATH:
     g_value_set_string (value, JOB_OBJECT (gobject)->script_path);
      break;
    case PROP_SCRIPT:
      g_value_set_string (value, JOB_OBJECT (gobject)->script);
      break;
    case PROP_WORKDIR:
      g_value_set_string (value, JOB_OBJECT (gobject)->workdir);
      break;
    case PROP_OTHER_OPTIONS:
      g_value_set_string (value, JOB_OBJECT (gobject)->other_options);
      break;
    case PROP_ACTION:
      g_value_set_string (value, JOB_OBJECT (gobject)->action);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (gobject, prop_id, pspec);
    }
}

static void
job_object_class_init (JobObjectClass *klass)
{
  GObjectClass *gobject_class = G_OBJECT_CLASS (klass);

  gobject_class->set_property = job_object_set_property;
  gobject_class->get_property = job_object_get_property;
  gobject_class->finalize = job_object_finalize;

  g_object_class_install_property (gobject_class,
                                   PROP_RESOURCE,
                                   g_param_spec_string ("resource", "Resource", "The resource that we want to have",
                                                        NULL,
                                                        G_PARAM_READWRITE));
  g_object_class_install_property (gobject_class,
                                   PROP_SCRIPT_PATH,
                                   g_param_spec_string ("script_path", "Script_path", "The path where to launch the script",
                                                        NULL,
                                                        G_PARAM_READWRITE));

  g_object_class_install_property (gobject_class,
                                   PROP_SCRIPT,
                                   g_param_spec_string ("script", "Script", "The script",
                                                        NULL,
                                                        G_PARAM_READWRITE));

  g_object_class_install_property (gobject_class,
                                   PROP_WORKDIR,
                                   g_param_spec_string ("workdir", "Workdir", "The directory where we will be working on",
                                                        NULL,
                                                        G_PARAM_READWRITE));
  g_object_class_install_property (gobject_class,
                                   PROP_OTHER_OPTIONS,
                                   g_param_spec_string ("other_options", "Other_options", "Baz",
                                                        NULL,
                                                        G_PARAM_READWRITE));

  g_object_class_install_property (gobject_class,
                                   PROP_ACTION,
                                   g_param_spec_string ("action", "Action", "the job that will be deleted",
                                                        NULL,
                                                        G_PARAM_READWRITE));

}


static gchar*
json_strescape (const gchar *source)
{

 	// IL FAUT PEUT ETRE AJOUTER DES "\"" avant et après pour que la sortie soit un String

if (source==NULL){
	return NULL;
}

  gchar *dest, *q;
  gunichar *ucs4;
  gint i, longueur;

  if (!g_utf8_validate (source, -1, NULL))
    return g_strescape (source, NULL);

  longueur = g_utf8_strlen (source, -1);
  dest = q = g_malloc (longueur * 6 + 1);

  ucs4 = g_utf8_to_ucs4_fast (source, -1, NULL);

/* 
 // Pour les strings, on leurs ajoute des '"' au début et à la fin
  *q++ = '\\';
  *q++ = '"';
*/
  
  for (i = 0; i < longueur; i++)
    {
      switch (ucs4 [i]) {
      case '\\':
        *q++ = '\\';
        *q++ = '\\';
        break;
      case '"':
        *q++ = '\\';
        *q++ = '"';
        break;
      case '\b':
        *q++ = '\\';
        *q++ = 'b';
        break;
      case '\f':
        *q++ = '\\';
        *q++ = 'f';
        break;
      case '\n':
        *q++ = '\\';
        *q++ = 'n';
        break;
      case '\r':
        *q++ = '\\';
        *q++ = 'r';
        break;
      case '\t':
        *q++ = '\\';
        *q++ = 't';
        break;
      case '/' :
	*q++ = '\\';
        *q++ = '/';
	break;
      default:
        if ((ucs4 [i] >= (gunichar)0x7F) || (ucs4 [i] <= (gunichar)0x1F)) 
	// d'après la documentation de JSON (et non pas de Glib qui ne considère pas le SLASH comme un caractère à "envelopper"),
	// the range 0x01-0x1F (everything below SPACE) and in the range 0x7F-0xFF (all non-ASCII chars)
          {
            g_sprintf (q, "\\u%04x", ucs4 [i]);
            q += 6;
          }
        else
          *q++ = ((gchar)ucs4 [i]);
      }
    }

/*  
  // Pour les strings, on leurs ajoute des '"' au début et à la fin
  *q++ = '\\';
  *q++ = '"';	
*/
 
  *q++ = 0;

  g_free (ucs4);

  return dest;
}


static void
job_object_init (JobObject *object)
{

  object->resource = g_strdup (json_strescape("/nodes=2/cpu=1"));
  //object->resource = g_strdup ("/nodes=2/cpu=1");
						
  object->script_path = g_strdup (json_strescape("/usr/bin/id"));
  //object->script_path = g_strdup ("/usr/bin/id");

  object->script = g_strdup (NULL);
  object->workdir = g_strdup (NULL);
  object->other_options = g_strdup (NULL);
  object->action = g_strdup (NULL);

}

static char*
job_serialize (char* resource, char* script_path, char* script, char* workdir, char* other_options, char* action)
{
  JobObject *obj = g_object_new (JOB_TYPE_OBJECT, NULL);
  gchar *data;
  gsize len;
  
//  g_print("checkpoint1\n");
  JOB_OBJECT (obj)->resource = g_strdup(json_strescape(resource));
  JOB_OBJECT (obj)->script_path = g_strdup(json_strescape(script_path));
  JOB_OBJECT (obj)->script = g_strdup(json_strescape(script));
  JOB_OBJECT (obj)->workdir = g_strdup(json_strescape(workdir));
  JOB_OBJECT (obj)->other_options = g_strdup(json_strescape(other_options));
  JOB_OBJECT (obj)->action = g_strdup(json_strescape(action));

//  g_print("checkpoint2\n");

  data = json_serialize_gobject (G_OBJECT (obj), &len);

  g_assert (data != NULL);
  g_assert_cmpint (len, >, 0);
  g_assert_cmpint (len, ==, strlen (data));

  if (g_test_verbose ())
    g_print ("JobObject:\n%s\n", data);

  
  //g_free (data);
  g_object_unref (obj);
  return data;
}


char* to_json (char* resource, char* script_path, char* script, char* workdir, char* other_options, char* action)
{
  g_type_init ();

  return job_serialize(resource, script_path, script, workdir, other_options, action);

}


int
main (int   argc,
      char *argv[])
{
  g_type_init ();
  g_test_init (&argc, &argv, NULL);

  
  // Je dois modifier les valeurs "par défaut" ou passer des valeurs à ce niveau !!! (ce n'est pas encore le cas, vu que job_object_init() le fait par magie !!)

  //g_test_add_func ("/serialize/gobject", job_serialize(""));
g_print(job_serialize("/nodes=2/cpu=1","/usr/bin/id",NULL,NULL,NULL,"delete"));
return 0;
 // return g_test_run ();
}
