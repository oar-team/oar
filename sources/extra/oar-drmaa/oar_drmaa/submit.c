/* $Id: submit.c 386 2011-01-06 18:13:33Z mamonski $ */
/*
 *  FedStage DRMAA for /oar Pro
 *  Copyright (C) 2006-2009  FedStage Systems
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http:/www.gnu.org/licenses/>.
 */

/*
 * Adapted from pbs_drmaa/submit.c

 */


#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <unistd.h>
#include <string.h>

#include <oar_drmaa/oar.h>
#include <oar_drmaa/oar_error.h>

#include <drmaa_utils/conf.h>
#include <drmaa_utils/drmaa.h>
#include <drmaa_utils/drmaa_util.h>
#include <drmaa_utils/datetime.h>
#include <drmaa_utils/iter.h>
#include <drmaa_utils/template.h>
#include <oar_drmaa/oar.h>
#include <oar_drmaa/oar_attrib.h>
#include <oar_drmaa/session.h>
#include <oar_drmaa/submit.h>
#include <oar_drmaa/util.h>

#ifndef lint
static char rcsid[]
#	ifdef __GNUC__
		__attribute__ ((unused))
#	endif
	= "$Id: submit.c 386 2011-01-06 18:13:33Z mamonski $";
#endif

static void
oardrmaa_submit_destroy( oardrmaa_submit_t *self );

static char *
oardrmaa_submit_submit( oardrmaa_submit_t *self );

static void
oardrmaa_submit_eval( oardrmaa_submit_t *self );


static void
oardrmaa_submit_set( oardrmaa_submit_t *self, const char *oar_attr,
		char *value, unsigned placeholders );

static void oardrmaa_submit_apply_defaults( oardrmaa_submit_t *self );
static void oardrmaa_submit_apply_job_script( oardrmaa_submit_t *self );
static void oardrmaa_submit_apply_job_state( oardrmaa_submit_t *self );
static void oardrmaa_submit_apply_job_files( oardrmaa_submit_t *self );
static void oardrmaa_submit_apply_file_staging( oardrmaa_submit_t *self );
static void oardrmaa_submit_apply_job_resources( oardrmaa_submit_t *self );
static void oardrmaa_submit_apply_job_environment( oardrmaa_submit_t *self );
static void oardrmaa_submit_apply_email_notification( oardrmaa_submit_t *self );
static void oardrmaa_submit_apply_job_category( oardrmaa_submit_t *self );


oardrmaa_submit_t *
oardrmaa_submit_new( fsd_drmaa_session_t *session, const fsd_template_t *job_template, int bulk_idx )
{
        oardrmaa_submit_t *volatile self = NULL;
	TRY
	 {
    fsd_malloc( self, oardrmaa_submit_t );
		self->session = session;
		self->job_template = job_template;
    self->script_path = NULL;
    self->workdir = NULL;
    self->walltime = NULL;
    self->environment = NULL;
		self->destination_queue = NULL;
    self->oar_job_attributes = NULL;
		self->expand_ph = NULL;
    self->destroy = oardrmaa_submit_destroy;
    self->submit = oardrmaa_submit_submit;
    self->eval = oardrmaa_submit_eval;
    self->set = oardrmaa_submit_set;
    self->apply_defaults = oardrmaa_submit_apply_defaults;
    self->apply_job_category = oardrmaa_submit_apply_job_category;
    self->apply_job_script = oardrmaa_submit_apply_job_script;
    self->apply_job_state = oardrmaa_submit_apply_job_state;
    self->apply_job_files = oardrmaa_submit_apply_job_files;
    self->apply_file_staging = oardrmaa_submit_apply_file_staging;
    self->apply_job_resources = oardrmaa_submit_apply_job_resources;
    self->apply_job_environment = oardrmaa_submit_apply_job_environment;
    self->apply_email_notification = oardrmaa_submit_apply_email_notification;
		self->apply_native_specification = oardrmaa_submit_apply_native_specification;

    self->oar_job_attributes = oardrmaa_oar_template_new();
		self->expand_ph = fsd_expand_drmaa_ph_new( NULL, NULL,
				(bulk_idx >= 0) ? fsd_asprintf("%d", bulk_idx) : NULL );
	 }
	EXCEPT_DEFAULT
	 {
		if( self )
			self->destroy( self );
	 }
	END_TRY
	return self;
}


void
oardrmaa_submit_destroy( oardrmaa_submit_t *self )
{
  if( self-> script_path)
    fsd_free( self->script_path );
  if( self-> workdir)
    fsd_free( self->workdir );
  if( self-> walltime)
    fsd_free( self->walltime );
  if( self-> environment)
    fsd_free( self->environment );
  if( self->oar_job_attributes )
    self->oar_job_attributes->destroy( self->oar_job_attributes );
	if( self->expand_ph )
		self->expand_ph->destroy( self->expand_ph );
	fsd_free( self->destination_queue );
	fsd_free( self );
}


char * oardrmaa_submit_submit( oardrmaa_submit_t *self )
{
	volatile bool conn_lock = false;
  struct attrl *volatile oar_attr = NULL;
	char *volatile job_id = NULL;
	TRY
	 {
    const fsd_template_t *oar_tmpl = self->oar_job_attributes;
		unsigned i;

    for( i = 0;  i < OARDRMAA_N_OAR_ATTRIBUTES;  i++ )
		 {
      const char *name = oar_tmpl->by_code( oar_tmpl, i )->name;
      if( name  &&  name[0] != '!' && oar_tmpl->get_attr( oar_tmpl, name ) )
			 {
				struct attrl *p;
				const char *resource;
				const char *value;
        value = oar_tmpl->get_attr( oar_tmpl, name );
				fsd_malloc( p, struct attrl );
				memset( p, 0, sizeof(struct attrl) );
        p->next = oar_attr;
        oar_attr = p;
				resource = strchr( name, '.' );
				if( resource )
				 {
					p->name = fsd_strndup( name, resource-name );
					p->resource = fsd_strdup( resource+1 );
				 }
				else
					p->name = fsd_strdup( name );
				fsd_log_debug(("set attr: %s = %s", name, value));
				p->value = fsd_strdup( value );
        /* p->op = SET; */ /* TODO: can we remove it ?*/
			 }
		 }

		conn_lock = fsd_mutex_lock( &self->session->drm_connection_mutex );
retry:
    job_id = oar_submit( ((oardrmaa_session_t*)self->session)->oar_conn,
                                (struct attropl*)oar_attr, self->script_path,
                                self->workdir, self->destination_queue );

    fsd_log_info(("oar_submit() =%s", job_id));

		if( job_id == NULL )
		 {
      if (oar_errno == OAR_ERRNO_PROTOCOL || oar_errno == OAR_ERRNO_EXPIRED)
			 {
        oardrmaa_session_t *oarself = (oardrmaa_session_t*)self->session;
        if (oarself->oar_conn >= 0 )
          oar_disconnect( oarself->oar_conn );
				sleep(1);
        oarself->oar_conn = oar_connect( oarself->super.contact );
        if( oarself->oar_conn < 0 )
          oardrmaa_exc_raise_oar( "oar_connect" );
				else
					goto retry;
			 }
			else
			 {
        oardrmaa_exc_raise_oar( "oar_submit" );
			 }
		}
		conn_lock = fsd_mutex_unlock( &self->session->drm_connection_mutex );
	 }
	EXCEPT_DEFAULT
	 {
		fsd_free( job_id );
		fsd_exc_reraise();
	 }
	FINALLY
	 {
		if( conn_lock )
			conn_lock = fsd_mutex_unlock( &self->session->drm_connection_mutex );
      if( oar_attr )
        oardrmaa_free_attrl( oar_attr );
	 }
	END_TRY
	return job_id;
}


void oardrmaa_submit_eval( oardrmaa_submit_t *self )
{
	/* self->apply_defaults( self ); useless for OAR*/
  self->apply_job_resources( self ); /* upto now set only walltime */
	self->apply_job_category( self );
  self->apply_job_environment( self ); /* not implemented */
	self->apply_job_script( self );
	self->apply_job_state( self ); /* not implemented */
	self->apply_job_files( self );
	/* self->apply_email_notification( self ); not implemented */
	self->apply_native_specification( self, NULL );
}


void oardrmaa_submit_set( oardrmaa_submit_t *self, const char *name, char *value, unsigned placeholders )
{
  fsd_template_t *oar_attr = self->oar_job_attributes;
	TRY
	 {
		if( placeholders )
			value = self->expand_ph->expand( self->expand_ph, value, placeholders );
      oar_attr->set_attr( oar_attr, name, value );
	 }
	FINALLY
	 {
		fsd_free( value );
	 }
	END_TRY
}

void oardrmaa_submit_apply_defaults( oardrmaa_submit_t *self )
{
    /* useless for OAR */
}

void oardrmaa_submit_apply_job_script( oardrmaa_submit_t *self )
{
	const fsd_template_t *jt = self->job_template;
  fsd_expand_drmaa_ph_t *expand = self->expand_ph;

  char *script_path = NULL;
  size_t script_path_len=0;

  const char *executable;
	const char *wd;
	const char *const *argv;
  const char *input_path;
  const char *const *i;
  char *environment;
  char *str_tmp = NULL;

  executable   = jt->get_attr( jt, DRMAA_REMOTE_COMMAND );
	wd           = jt->get_attr( jt, DRMAA_WD );
  argv         = jt->get_v_attr( jt, DRMAA_V_ARGV );
  input_path   = jt->get_attr( jt, DRMAA_INPUT_PATH );
  
  environment   = self->environment;

  if( wd ) /* TODO: to move ? */
	 {
		char *cwd = NULL;
		cwd = expand->expand( expand, fsd_strdup(wd),
				FSD_DRMAA_PH_HD | FSD_DRMAA_PH_INCR );
		expand->set( expand, FSD_DRMAA_PH_WD, cwd );
    self->workdir = fsd_strdup(cwd);
	 }

   if( input_path != NULL )
    {
     if( input_path[0] == ':' )
      input_path++;
    }

	if( executable == NULL )
		fsd_exc_raise_code( FSD_DRMAA_ERRNO_INVALID_ATTRIBUTE_VALUE );

  if (argv)
    {
      /* compute script_lengh length */
      /* script_path_len = 1;*/ /* begining double quote */ /* TODO: to remove ? */
      script_path_len += strlen(executable);
            for( i = argv;  *i != NULL;  i++ )
                    script_path_len += 3+strlen(*i);
            if( input_path != NULL )
                    script_path_len += strlen(" <") + strlen(input_path);
            /* script_path_len +=1;*/ /* ending double quote */ /* TODO: to remove ? */

            fsd_calloc( script_path, script_path_len+1, char );

            char *s;
            s = script_path;
            /*s += sprintf( s,"\""); */ /* begining double quote */ /* TODO: to remove ? */
            s += sprintf( s,"%s",executable);
            for( i = argv;  *i != NULL;  i++ )
                    s += sprintf( s, " '%s'", *i );
            if( input_path != NULL )
                s += sprintf( s, " <%s", input_path );
            /* s += sprintf( s,"\""); */ /* ending double quote */ /* TODO: to remove ? */

            fsd_assert( s == script_path+script_path_len );

            self->script_path = script_path;

        } else
        {
            self->script_path = fsd_strdup(executable);
        }

      if (environment) {
        fsd_calloc(str_tmp, strlen(environment) + strlen(self->script_path) +1, char);
        str_tmp[0] = '\0';
        strcat(str_tmp, environment);
        strcat(str_tmp, self->script_path);
        fsd_free(self->script_path);
       
        self->script_path = fsd_strdup(str_tmp);
        fsd_free(str_tmp);
      }
}

void oardrmaa_submit_apply_job_state( oardrmaa_submit_t *self )
{
	const fsd_template_t *jt = self->job_template;
  fsd_template_t *oar_attr = self->oar_job_attributes;
	const char *job_name = NULL;
	const char *submit_state = NULL;
	const char *drmaa_start_time = NULL;

	job_name = jt->get_attr( jt, DRMAA_JOB_NAME );
	submit_state = jt->get_attr( jt, DRMAA_JS_STATE );
	drmaa_start_time = jt->get_attr( jt, DRMAA_START_TIME );

	if( job_name != NULL )
                oar_attr->set_attr( oar_attr, OARDRMAA_JOB_NAME, job_name );

	if( submit_state != NULL )
	 {
    if( !strcmp(submit_state, DRMAA_SUBMISSION_STATE_HOLD) )
      oar_attr->set_attr( oar_attr, OARDRMAA_HOLD, "1" );
    else if ( strcmp(submit_state, DRMAA_SUBMISSION_STATE_ACTIVE) ) {
	    fsd_exc_raise_fmt( FSD_ERRNO_INVALID_VALUE,
		    "invalid value of %s attribute (%s|%s)",
				DRMAA_JS_STATE, DRMAA_SUBMISSION_STATE_ACTIVE,
				DRMAA_SUBMISSION_STATE_HOLD );
    }

	 }

	if( drmaa_start_time != NULL )
	 {
                /*
		time_t start_time;
                char oar_start_time[20];
		struct tm start_time_tm;
                */
      fsd_log_error((" drmaa_start_time NOT YET IMPLEMENTED\n"));
                /*
		start_time = fsd_datetime_parse( drmaa_start_time );
		localtime_r( &start_time, &start_time_tm );
                sprintf( oar_start_time, "%04d%02d%02d%02d%02d.%02d",
				start_time_tm.tm_year + 1900,
				start_time_tm.tm_mon + 1,
				start_time_tm.tm_mday,
				start_time_tm.tm_hour,
				start_time_tm.tm_min,
				start_time_tm.tm_sec
				);

                oar_attr->set_attr( oar_attr, OARDRMAA_EXECUTION_TIME, oar_start_time );
                */
	 }
}


void oardrmaa_submit_apply_job_files( oardrmaa_submit_t *self )
{
	const fsd_template_t *jt = self->job_template;
  fsd_template_t *oar_attr = self->oar_job_attributes;
	const char *join_files;
	bool b_join_files;
	int i;

	for( i = 0;  i < 2;  i++ )
	 {
		const char *drmaa_name;
    const char *oar_name;
		const char *path;

		if( i == 0 )
		 {
			drmaa_name = DRMAA_OUTPUT_PATH;
      oar_name   = OARDRMAA_STDOUT_FILE;
		 }
		else
		 {
			drmaa_name = DRMAA_ERROR_PATH;
      oar_name   = OARDRMAA_STDERR_FILE;
		 }

		path = jt->get_attr( jt, drmaa_name );
		if( path != NULL )
		 {
			if( path[0] == ':' )
				path++;
      self->set(self, oar_name, fsd_strdup(path), FSD_DRMAA_PH_HD | FSD_DRMAA_PH_WD | FSD_DRMAA_PH_INCR);
		 }
	 }

   join_files = jt->get_attr( jt, DRMAA_JOIN_FILES );
	 b_join_files = join_files != NULL  &&  !strcmp(join_files,"y");

    if (b_join_files) { 

    const char *path;
    path = jt->get_attr( jt, DRMAA_OUTPUT_PATH );
    if  ( path != NULL ) { /* STDOUT is fixed*/
      if( path[0] == ':' )
		    path++;
      /* copy value to OARDRMAA_STDERR_FILE */
      self->set(self,OARDRMAA_STDERR_FILE , fsd_strdup(path), FSD_DRMAA_PH_HD | FSD_DRMAA_PH_WD | FSD_DRMAA_PH_INCR); 
		} else {
      self->set(self,OARDRMAA_STDOUT_FILE , fsd_strdup("OAR.%jobid%.stdout_stderr"), FSD_DRMAA_PH_HD | FSD_DRMAA_PH_WD | FSD_DRMAA_PH_INCR); 
      self->set(self,OARDRMAA_STDERR_FILE , fsd_strdup("OAR.%jobid%.stdout_stderr"), FSD_DRMAA_PH_HD | FSD_DRMAA_PH_WD | FSD_DRMAA_PH_INCR); 
    }
  }
}

void oardrmaa_submit_apply_file_staging( oardrmaa_submit_t *self )
{
    /*TODO: Do we need it ? */
}


void oardrmaa_submit_apply_job_resources( oardrmaa_submit_t *self )
{
	const fsd_template_t *jt = self->job_template;
	const char *cpu_time_limit = NULL;
	const char *walltime_limit = NULL;

  fsd_template_t *oar_attr = self->oar_job_attributes;


  /* NOTE: In OAR DRMAA_DURATION_HLIMIT corresponds to walltime */
	cpu_time_limit = jt->get_attr( jt, DRMAA_DURATION_HLIMIT );
	walltime_limit = jt->get_attr( jt, DRMAA_WCT_HLIMIT ); /* addressed a just before submission */
  
	if( walltime_limit )
	 {
    fsd_log_error(("DRMAA_WCT_HLIMIT NOT YET IMPLEMENTED\n"));
    /* not supported in OAR
    oar_attr->set_attr( oar_attr, "Resource_List.pcput", cpu_time_limit ); 
    oar_attr->set_attr( oar_attr, "Resource_List.cput", cpu_time_limit );
    */
	 }
	if( cpu_time_limit) { 
    self->walltime = fsd_strdup(cpu_time_limit);
  }
}

void oardrmaa_submit_apply_job_environment( oardrmaa_submit_t *self )
{
	const fsd_template_t *jt = self->job_template;
	const char *const *env_v;
  char export[] = "export ";

	env_v = jt->get_v_attr( jt, DRMAA_V_ENV);

	if (env_v)
	{
		char *env_c = NULL;
		int ii = 0, len = 0;

    len = strlen(export);

		ii = 0;
		while (env_v[ii]) {
			len += strlen(env_v[ii]) + 1;
			ii++;
		}

		fsd_calloc(env_c, len + 1 + 1, char);
		env_c[0] = '\0';

	  strcat(env_c, export); /* copy export */

		ii = 0;
		while (env_v[ii]) {
			strcat(env_c, env_v[ii]);
			strcat(env_c, " ");
			ii++;
		}

		env_c[strlen(env_c) -1 ] = ';'; /*replace the last ',' */
    self->environment=fsd_strdup(env_c);
    /* printf("env_c: %s\n",env_c); */

		fsd_free(env_c);
	}
}


void oardrmaa_submit_apply_email_notification( oardrmaa_submit_t *self )
{
	/* TODO  not implemented*/
}

void oardrmaa_submit_apply_job_category( oardrmaa_submit_t *self )
{
	const char *job_category = NULL;
	const char *category_spec = NULL;
	fsd_conf_option_t *value = NULL;

	job_category = self->job_template->get_attr(
			self->job_template, DRMAA_JOB_CATEGORY );
	if( job_category == NULL  ||  job_category[0] == '\0' )
		job_category = "default";
	value = fsd_conf_dict_get( self->session->job_categories,
			job_category );
	if( value != NULL  &&  value->type == FSD_CONF_STRING )
		category_spec = value->val.string;
	if( category_spec != NULL )
		self->apply_native_specification( self, category_spec );
}

static void parse_resources(fsd_template_t *oar_attr,const char *resources)
{
  /* TODO: TO REMOVE ? */
	char * volatile name = NULL;
	char *arg = NULL;
	char *value = NULL;
	char *ctxt = NULL;
	char * volatile resources_copy = fsd_strdup(resources);

	TRY
	  {
		for (arg = strtok_r(resources_copy, ",", &ctxt); arg; arg = strtok_r(NULL, ",",&ctxt) )
		{
			char *psep = strchr(arg, '=');

			if (psep) 
			{
				*psep = '\0';
				name = fsd_asprintf("Resource_List.%s", arg);
				value = ++psep;
        oar_attr->set_attr( oar_attr, name , value );
				fsd_free(name);
				name = NULL;
			}
			else
			{
          fsd_exc_raise_fmt(FSD_DRMAA_ERRNO_INVALID_ATTRIBUTE_VALUE, "Invalid native specification: %s (Invalid resource specification: %s)", resources, arg);
			}
		}
	  }
	FINALLY
	  {
		fsd_free(name);
		fsd_free(resources_copy);
	  }
	END_TRY
}

static void parse_additional_attr(fsd_template_t *oar_attr,const char *add_attr)
{
	char * volatile name = NULL;
	char *arg = NULL;
	char *value = NULL;
	char *ctxt = NULL, *ctxt2 = NULL;
	char * volatile add_attr_copy = fsd_strdup(add_attr);

	TRY
	  {
		for (arg = strtok_r(add_attr_copy, ",", &ctxt); arg; arg = strtok_r(NULL, ":",&ctxt) )
		{
			name = fsd_strdup(strtok_r(arg, "=", &ctxt2));
			value = strtok_r(NULL, "=", &ctxt2);
      oar_attr->set_attr( oar_attr, name , value );
			fsd_free(name);
			name = NULL;
		}
	  }
	FINALLY
	  {
		fsd_free(name);
		fsd_free(add_attr_copy);
	  }
	END_TRY
}

/* TODO complete */
void oardrmaa_submit_apply_native_specification( oardrmaa_submit_t *self, const char *native_specification )
{
	if( native_specification == NULL )
		native_specification = self->job_template->get_attr(self->job_template, DRMAA_NATIVE_SPECIFICATION );
	if( native_specification == NULL ) return;

  fsd_iter_t * volatile args_list = fsd_iter_new(NULL, 0);
  fsd_template_t *oar_attr = self->oar_job_attributes;
  
  char *arg = NULL;
  volatile char * native_spec_copy = fsd_strdup(native_specification);
  char * ctxt = NULL;
	int opt = 0;
  const char *walltime = self->walltime;
  char * resource = NULL;
  char c1 = ' ';
  char c2 = ' ';
		TRY
		 {
			for (arg = strtok_r(native_spec_copy, " \t", &ctxt); arg; arg = strtok_r(NULL, " \t",&ctxt) ) {
				if (!opt) {
					if ( (arg[0] != '-') || ((strlen(arg) != 2) &&  arg[2] != ' ' && arg[1] !='-' ) )
						fsd_exc_raise_fmt(FSD_DRMAA_ERRNO_INVALID_ATTRIBUTE_VALUE,
								"Invalid native specification: %s",
								native_specification);
					if(arg[1] == '-') {
            /*parse_additional_attr(oar_attr, arg+2); TODO to remove*/
            /* to manage long option */
            c1 = arg[2];
            c2 = arg[3];
            if (c1 == 'r' && c2== 'e') {
              opt = 'r'; /* reservation */
            } else if  (c1 == 's' && c2== 'i') {
              opt = 's'; /* signal */ 
            } else if  (c1 == 't' && c2== 'y') {
              opt = 't'; /* type */
            } else if  (c1 == 'd' && c2== 'i') {
              opt = 'd'; /* directory */
            } else if  (c1 == 'p' && c2== 'r') {
              opt = 'j'; /* project */
            } else if  (c1 == 'n' && c2== 'a') {
              opt = 'n'; /* name */
            } else if  (c1 == 'a' && c2== 'n') {
              opt = 'a'; /* anterior */
            } else if  (c1 == 'n' && c2== 'o') {
              opt = 'o'; /* notify */
            } else if  (c1 == 'r' && c2== 'e') {
              opt = 'u'; /* resubmit */
            } else if  (c1 == 'u' && c2== 's') {
              opt = 'k'; /* use-job-key */
            } else if  (c1 == 'i' && arg[17]== 'f') {
              opt = 'i'; /* import-job-key-from-file" */
            } else if  (c1 == 'i' && arg[17]== 'i') {
              opt = 'm'; /* import-job-key-inline */
            } else if  (c1 == 'h' && c2== 'o') {
              opt = 'h'; /* hold */
            }
					}
					else {
						opt = arg[1];
					}
					
				} else {
					switch (opt) {
            /*				
						case 'W' :
              parse_additional_attr(oar_attr, arg);
							break;
            */
            case 'l' :
              if (walltime) {/* add walltime is present */
                asprintf(&resource, "%s,walltime=%s", arg, walltime);
                oar_attr->set_attr( oar_attr, "resource" , resource );
                walltime = NULL;
              } else {
                oar_attr->set_attr( oar_attr, "resource" , arg );
              }
							break;
          	case 'q' :
							self->destination_queue = fsd_strdup( arg );
							break;
            case 'p' :
							oar_attr->set_attr( oar_attr, "property" , arg );
							break;
						case 'r' :
              oar_attr->set_attr( oar_attr, "reservation" , arg );
							break;
            case 'c': /* bind (artificially) to checkpoint */
              oar_attr->set_attr( oar_attr, "checkpoint" , arg );
							break;
            case 's': /* bind (artificially) to signal */
              oar_attr->set_attr( oar_attr, "signal" , arg );
							break;
            case 't' : /* TODO transform to json ....*/
              oar_attr->set_attr( oar_attr, "type" , arg );
							break;
						case 'd' :
              oar_attr->set_attr( oar_attr, "directory" , arg );
            case 'j' :/* bind (artificially) to project */
              oar_attr->set_attr( oar_attr, "project" , arg );
							break;
						case 'n' :
              oar_attr->set_attr( oar_attr, "name" , arg );
							break;
						case 'a' :
              oar_attr->set_attr( oar_attr, "anterior" , arg );
							break;
						case 'o' : /* bind (artificially) to notify */
              oar_attr->set_attr( oar_attr, "notify" , arg );
							break;
						case 'u' : /* bind (artificially) to resubmit */
              oar_attr->set_attr( oar_attr, "resubmit" , arg );
							break;
            case 'i' : /* import-job-key-from-file" */ 
              oar_attr->set_attr( oar_attr, "import-job-key-from-file" , arg );
            case 'm' : /* bind (artificially) to import-job-key-inline */
              oar_attr->set_attr( oar_attr, "import-job-key-inline" , arg );
						case 'O' :
              oar_attr->set_attr( oar_attr, "stdout" , arg );
							break;
						case 'E' :
              oar_attr->set_attr( oar_attr, "stderr" , arg );
							break;
						default :
							
							fsd_exc_raise_fmt(FSD_DRMAA_ERRNO_INVALID_ATTRIBUTE_VALUE,
									"Invalid native specification: %s (Unsupported option: -%c)",
									native_specification, opt);
					}

					opt = 0;
				}
			}

			if (opt) /* option without optarg */ {
        switch (opt) {
          case 'h' : /* bind (artificially) to hold */
            oar_attr->set_attr( oar_attr, "hold" , "1" );
					  break;
          case 'k' : /* use-job-key */ 
            oar_attr->set_attr( oar_attr, "use-job-key" , "1" );

          default :
				    fsd_exc_raise_fmt(FSD_DRMAA_ERRNO_INVALID_ATTRIBUTE_VALUE,
						  "Invalid native specification: %s  (Unsupported option: -%c)",
			        native_specification, opt);
        }
		  }
    }
		FINALLY
		 {
			args_list->destroy(args_list);
			fsd_free(native_spec_copy);
		 }
		END_TRY
 
    if (walltime) {
        asprintf(&resource, "walltime=%s", arg, walltime);
        oar_attr->set_attr( oar_attr, "resource" , resource );
    }
}
   
