/* $Id: drmaa_base.c 533 2007-12-22 15:25:42Z lukasz $ */
/*
 *  FedStage DRMAA for PBS Pro
 *  Copyright (C) 2006-2007  Fedstage Systems Inc.
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
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * @file drmaa_base.c
 * DRM independant part of DRMAA library.
 */

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include <drmaa_utils/attrib.h>
#include <drmaa_utils/common.h>
#include <drmaa_utils/conf.h>
#include <drmaa_utils/drmaa_base.h>
#include <drmaa_utils/drmaa_impl.h>
#include <drmaa_utils/lookup3.h>
#include <drmaa_utils/util.h>

#ifndef lint
static char rcsid[]
#	ifdef __GNUC__
		__attribute__ ((unused))
#	endif
	= "$Id: drmaa_base.c 533 2007-12-22 15:25:42Z lukasz $";
#endif

/** Mutex for accessing drmaa_session global variable. */
drmaa_mutex_t drmaa_session_mutex = DRMAA_MUTEX_INITIALIZER;
/** Current DRMAA session. */
drmaa_session_t *drmaa_session = NULL;


int
drmaa_init( const char *contact, char *errmsg, size_t errlen )
{
	drmaa_err_ctx_t errctx, *err=&errctx;
	drmaa_err_init( err, errmsg, errlen );
	DEBUG(( "-> drmaa_init( contact=%s )", contact ));
	drmaa_mutex_lock( &drmaa_session_mutex, err );
	if( drmaa_session != NULL )
		RAISE_DRMAA_1( DRMAA_ERRNO_ALREADY_ACTIVE_SESSION );
	if( OK(err) )
		drmaa_session = drmaa_session_create( contact, err );
	drmaa_mutex_unlock( &drmaa_session_mutex, err );
	DEBUG(( "<- drmaa_init() =%d", err->rc ));
	return err->rc;
}


int
drmaa_exit( char *errmsg, size_t errlen )
{
	drmaa_err_ctx_t errctx, *err=&errctx;
	drmaa_err_init( err, errmsg, errlen );
	DEBUG(( "-> drmaa_exit()" ));
	drmaa_mutex_lock( &drmaa_session_mutex, err );
	if( drmaa_session != NULL )
	 {
		drmaa_session_destroy( drmaa_session, err );
		drmaa_session = NULL;
	 }
	else
	 {
		RAISE_DRMAA_1( DRMAA_ERRNO_NO_ACTIVE_SESSION );
	 }
	drmaa_mutex_unlock( &drmaa_session_mutex, err );
	DEBUG(( "<- drmaa_exit() =%d", err->rc ));
	return err->rc;
}


drmaa_session_t *
drmaa_session_create( const char *contact, drmaa_err_ctx_t *err )
{
	drmaa_session_t *c = NULL;

	DRMAA_MALLOC( c, drmaa_session_t );
	if( OK(err) )
	 {
		c->contact = NULL;
		c->attributes = NULL;
		c->attributes_capacity = 0;
		c->n_attributes = 0;
		c->jt_list =  NULL;
		c->jobs = NULL;
		c->ref_cnt = 0;
		c->end = false;
		c->configuration = NULL;
		c->pool_delay.tv_sec = 5;
		c->pool_delay.tv_nsec = 0;
		c->with_wait_thread = false;
		c->job_categories = NULL;
		c->missing_jobs = DRMAA_RAISE_MISSING_JOBS;
		c->impl = NULL;
		drmaa_mutex_init( &c->mutex, err );
		drmaa_mutex_init( &c->jt_mutex, err );
		drmaa_mutex_init( &c->end_mutex, err );
		drmaa_cond_init( &c->wait_cond, err );
		drmaa_cond_init( &c->destroy_cond, err );
	 }
	if( OK(err) )
		DRMAA_MALLOC( c->jt_list, drmaa_job_template_t );
	if( OK(err) )
	 {
		c->jt_list->next = c->jt_list->prev = c->jt_list;
		c->jt_list->impl = NULL;
	 }
	if( OK(err) )
		c->jobs = drmaa_job_set_create( err );
	if( OK(err) )
		drmaa_register_drmaa_attributes( c, err );
	if( OK(err) )
		c->contact = drmaa_strdup( contact, err );

	if( OK(err) )
		drmaa_session_create_impl( c, err );

	if( c != NULL  &&  !OK(err) )
	 {
		drmaa_session_destroy( c, err );
		c = NULL;
	 }
	return c;
}


void
drmaa_session_destroy( drmaa_session_t *c, drmaa_err_ctx_t *err )
{
	bool already_destroying = false;
	if( c == NULL )
		return;

	drmaa_mutex_lock( &c->end_mutex, err );
	if( c->end )
		already_destroying = true;
	else
	 {
		c->end = true;
		drmaa_cond_broadcast( &c->wait_cond, err );
	 }
	drmaa_mutex_unlock( &c->end_mutex, err );
	if( already_destroying )
	 { /* XXX: actually it can not happen */
		RAISE_DRMAA_1( DRMAA_ERRNO_NO_ACTIVE_SESSION );
		return;
	 }

	drmaa_job_set_signal_all( c->jobs, err );

	drmaa_mutex_lock( &c->mutex, err );
	while( c->ref_cnt > 0 )
		drmaa_cond_wait( &c->destroy_cond, &c->mutex, err );
	drmaa_mutex_unlock( &c->mutex, err );

	drmaa_session_destroy_impl( c, err );

	drmaa_conf_dict_destroy( c->configuration );

	DRMAA_FREE( c->contact );

	if( c->jt_list != NULL )
	 {
		drmaa_job_template_t *i;
		for( i = c->jt_list->next;  i != c->jt_list;  )
		 {
			drmaa_job_template_t *jt = i;
			i = i->next;
			drmaa_delete_async_job_template( jt, err );
		 }
		DRMAA_FREE( c->jt_list );
	 }

	if( c->jobs )
		drmaa_job_set_destroy( c->jobs, err );

	drmaa_delete_attributes_list( c, err );

	drmaa_mutex_destroy( &c->mutex, err );
	drmaa_mutex_destroy( &c->jt_mutex, err );
	drmaa_mutex_destroy( &c->end_mutex, err );
	drmaa_cond_destroy( &c->wait_cond, err );
	drmaa_cond_destroy( &c->destroy_cond, err );

	DRMAA_FREE( c );
}



int
drmaa_read_configuration_file(
		const char *filename,
		char *error_diagnosis, size_t error_diag_len
		)
{
	drmaa_err_ctx_t errctx, *err=&errctx;
	drmaa_session_t *session = NULL;
	drmaa_err_init( err, error_diagnosis, error_diag_len );
	DEBUG(( "-> drmaa_read_configuration_file( filename=%s )", filename ));
	session = drmaa_session_get( err );
	if( OK(err) )
		session->configuration = drmaa_conf_read(
			 session->configuration,
			 filename, true,
			 NULL, 0,
			 err );
	if( OK(err) )
		drmaa_session_apply_config( session, err );
	drmaa_session_release( session, err );
	DEBUG(( "<- drmaa_read_configuration_file =%d", err->rc ));
	return err->rc;
}


int
drmaa_read_configuration(
		const char *configuration, size_t conf_len,
		char *error_diagnosis, size_t error_diag_len
		)
{
	drmaa_err_ctx_t errctx, *err=&errctx;
	drmaa_session_t *session = NULL;
	drmaa_err_init( err, error_diagnosis, error_diag_len );
	DEBUG(( "-> drmaa_read_configuration( configuration=\"%.*s\" )", conf_len, configuration ));
	session = drmaa_session_get( err );
	if( OK(err) )
		session->configuration = drmaa_conf_read(
			 session->configuration,
			 NULL, false,
			 configuration, conf_len,
			 err );
	if( OK(err) )
		drmaa_session_apply_config( session, err );
	drmaa_session_release( session, err );
	DEBUG(( "<- drmaa_read_configuration =%d", err->rc ));
	return err->rc;
}


void
drmaa_session_apply_config( drmaa_session_t *c, drmaa_err_ctx_t *err )
{
	drmaa_conf_option_t *pool_delay = NULL;
	drmaa_conf_option_t *wait_thread = NULL;
	drmaa_conf_option_t *job_categories = NULL;
	drmaa_conf_option_t *missing_jobs = NULL;

	DEBUG(( "-> drmaa_session_apply_config" ));
	if( OK(err)  &&  c->configuration )
	 {}
	else
		return;

	pool_delay = drmaa_conf_dict_get(
			c->configuration, "pool_delay", err );
	wait_thread = drmaa_conf_dict_get(
			c->configuration, "wait_thread", err );
	job_categories = drmaa_conf_dict_get(
			c->configuration, "job_categories", err );
	missing_jobs = drmaa_conf_dict_get(
			c->configuration, "missing_jobs", err );
	if( OK(err) && pool_delay )
	 {
		if( pool_delay->type == DRMAA_CONF_INTEGER
				&&  pool_delay->val.integer > 0 )
			c->pool_delay.tv_sec = pool_delay->val.integer;
		else
			RAISE_DRMAA_2(
					DRMAA_ERRNO_INTERNAL_ERROR,
					"configuration: 'pool_delay' must be positive integer"
					);
	 }
	if( OK(err) && wait_thread )
	 {
		if( wait_thread->type == DRMAA_CONF_INTEGER )
			c->with_wait_thread = (wait_thread->val.integer != 0 );
		else
			RAISE_DRMAA_2(
					DRMAA_ERRNO_INTERNAL_ERROR,
					"configuration: 'wait_thread' should be 0 or 1"
					);
	 }
	if( OK(err) && job_categories )
	 {
		if( job_categories->type == DRMAA_CONF_DICT )
			c->job_categories = job_categories->val.dict;
		else
			RAISE_DRMAA_2(
					DRMAA_ERRNO_INTERNAL_ERROR,
					"configuration: 'job_categories' should be dictionary"
					);
	 }
	if( OK(err) && missing_jobs )
	 {
		bool ok = true;
		if( missing_jobs->type != DRMAA_CONF_STRING )
		 {
			const char *value = missing_jobs->val.string;
			if( !strcmp( value, "ignore" ) )
				c->missing_jobs = DRMAA_IGNORE_MISSING_JOBS;
			else if( !strcmp( value, "ignore-queued" ) )
				c->missing_jobs = DRMAA_IGNORE_QUEUED_MISSING_JOBS;
			else if( !strcmp( value, "raise" ) )
				c->missing_jobs = DRMAA_RAISE_MISSING_JOBS;
			else
				ok = false;
		 }
		else
			ok = false;

		if( !ok )
			RAISE_DRMAA_2(
					DRMAA_ERRNO_INTERNAL_ERROR,
					"configuration: 'missing_jobs' should be one of: "
					"'ignore', 'ignore-queued' or 'raise'"
					);
	 }

	DEBUG(( "<- drmaa_session_apply_config" ));
}


drmaa_session_t *
drmaa_session_get( drmaa_err_ctx_t *err )
{
	drmaa_session_t *session = NULL;
	drmaa_mutex_lock( &drmaa_session_mutex, err );
	session = drmaa_session;
	drmaa_mutex_unlock( &drmaa_session_mutex, err );
	if( session != NULL )
	 {
		drmaa_mutex_lock( &session->mutex, err );
		session->ref_cnt ++;
		drmaa_mutex_unlock( &session->mutex, err );
	 }
	else
		RAISE_DRMAA_1( DRMAA_ERRNO_NO_ACTIVE_SESSION );
	return session;
}


void
drmaa_session_release( drmaa_session_t *session, drmaa_err_ctx_t *err )
{
	if( session != NULL )
	 {
		/* drmaa_mutex_lock( &drmaa_session_mutex, err ); */
		drmaa_mutex_lock( &session->mutex, err );
		session->ref_cnt--;
		if( session->ref_cnt == 0 )
			drmaa_cond_broadcast( &session->destroy_cond, err );
		drmaa_mutex_unlock( &session->mutex, err );
		/* drmaa_mutex_unlock( &drmaa_session_mutex, err ); */
	 }
}



int
drmaa_allocate_job_template(
		drmaa_job_template_t **p_jt,
		char *errmsg, size_t errlen
		)
{
	drmaa_err_ctx_t errctx, *err=&errctx;
	drmaa_session_t *session = NULL;
	drmaa_job_template_t *jt = NULL;

	drmaa_err_init( err, errmsg, errlen );
	DEBUG(( "-> drmaa_allocate_job_template" ));
	if( OK(err) )  session = drmaa_session_get( err );
	if( OK(err) )  DRMAA_MALLOC( jt, drmaa_job_template_t );
	if( OK(err) )  jt->session = session;
	if( OK(err) )  DRMAA_CALLOC( jt->attrib, N_DRMAA_ATTRIBS, void* );
	if( OK(err) )  drmaa_mutex_init( &jt->mutex, err );

	if( OK(err) )
	 {
		drmaa_mutex_lock( & session->jt_mutex, err );
		jt->next = session->jt_list->next;
		jt->prev = session->jt_list;
		jt->next->prev = jt;
		jt->prev->next = jt;
		drmaa_mutex_unlock( & session->jt_mutex, err );
	 }

	if( session )
		drmaa_session_release( session, err );

	if( OK(err) )
		*p_jt = jt;
	else
		DRMAA_FREE( jt );

	DEBUG(( "<- drmaa_allocate_job_template =%d; jt=%p", err->rc, (void*)jt ));
	return err->rc;
}


int
drmaa_delete_job_template( drmaa_job_template_t *jt, char *errmsg, size_t errlen )
{
	drmaa_err_ctx_t err_ctx, *err=&err_ctx;
	drmaa_session_t *session = NULL;

	DEBUG(( "-> drmaa_delete_job_template( %p )", (void*)jt ));
	drmaa_err_init( err, errmsg, errlen );
	if( jt != NULL )
	 {
		session = jt->session;
		drmaa_mutex_lock( &session->jt_mutex, err );
		jt->prev->next = jt->next;
		jt->next->prev = jt->prev;
		drmaa_mutex_unlock( &session->jt_mutex, err );

		drmaa_delete_async_job_template( jt, err );
	 }
	DEBUG(( "<- drmaa_delete_job_template; err=%d", err->rc ));
	return err->rc;
}


void
drmaa_delete_async_job_template(
		drmaa_job_template_t *jt, drmaa_err_ctx_t *err )
{
	if( jt->attrib != NULL )
	 {
		unsigned i;
		for( i = 0;  i < N_DRMAA_ATTRIBS;  i++ )
			if( drmaa_is_vector( &jt->session->attributes[i] ) )
				drmaa_free_vector( jt->attrib[i] );
			else DRMAA_FREE( jt->attrib[i] );
	 }
	drmaa_mutex_destroy( &jt->mutex, err );
	DRMAA_FREE( jt );
}


int
drmaa_set_attribute(
		drmaa_job_template_t *jt,
		const char *name, const char *value,
		char *errmsg, size_t errlen
		)
{
	drmaa_err_ctx_t err_ctx, *err=&err_ctx;
	const drmaa_attrib_info_t *attr = NULL;
	int attr_no;
	drmaa_err_init( err, errmsg, errlen );
	attr = attr_by_drmaa_name( jt->session, name, err );
	if( OK(err)  &&  drmaa_is_vector(attr) )
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT );
	if( OK(err) )
	 {
		attr_no = attr->code;
		drmaa_mutex_lock( &jt->mutex, err );
		if( jt->attrib[ attr_no ] != NULL )
			free( jt->attrib[ attr_no ] );
		jt->attrib[ attr_no ] = strdup( value );
		drmaa_mutex_unlock( &jt->mutex, err );
	 }
	return err->rc;
}


int
drmaa_get_attribute(
	drmaa_job_template_t *jt,
	const char *name, char *value, size_t value_len,
	char *errmsg, size_t errlen
	)
{
	drmaa_err_ctx_t err_ctx, *err=&err_ctx;
	const drmaa_attrib_info_t *attr = NULL;
	int attr_no;
	drmaa_err_init( err, errmsg, errlen );
	attr = attr_by_drmaa_name( jt->session, name, err );
	if( OK(err) && drmaa_is_vector(attr) )
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT );
	if( OK(err) )
	 {
		attr_no = attr->code;
		drmaa_mutex_lock( &jt->mutex, err );
		if( jt->attrib[attr_no] != NULL )
			strlcpy( value, jt->attrib[attr_no], value_len );
		else
			strlcpy( value, "", value_len );
		drmaa_mutex_unlock( &jt->mutex, err );
	 }
	return err->rc;
}


int
drmaa_set_vector_attribute(
		drmaa_job_template_t *jt,
		const char *name, const char *value[],
		char *errmsg, size_t errlen
		)
{
	drmaa_err_ctx_t err_ctx, *err=&err_ctx;
	const drmaa_attrib_info_t *attr = NULL;
	char **v = NULL;
	int attr_no;

	drmaa_err_init( err, errmsg, errlen );

	if( jt == NULL )
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT );

	if( OK(err) )
	 {
		attr = attr_by_drmaa_name( jt->session, name, err );
		if( OK(err) && !drmaa_is_vector(attr) )
			RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT );
		if( OK(err) )
			attr_no = attr->code;
	 }

	if( OK(err)  &&  value )
		v = drmaa_copy_vector( value, err );

	if( OK(err) )
	 {
		drmaa_mutex_lock( &jt->mutex, err );
		if( jt->attrib[ attr_no ] != NULL )
			drmaa_free_vector( (char**)jt->attrib[attr_no] );
		jt->attrib[ attr_no ] = v;
		v = NULL;
		drmaa_mutex_unlock( &jt->mutex, err );
	 }

	if( v )
		drmaa_free_vector( v );

	return err->rc;
}


int
drmaa_get_vector_attribute(
		drmaa_job_template_t *jt,
		const char *name, drmaa_attr_values_t **out_values,
		char *errmsg, size_t errlen
		)
{
	drmaa_err_ctx_t err_ctx, *err=&err_ctx;
	const drmaa_attrib_info_t *attr = NULL;
	char **value = NULL;
	drmaa_attr_values_t *result = NULL;

	drmaa_err_init( err, errmsg, errlen );

	if( jt == NULL )
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT );

	if( OK(err) )
	 {
		attr = attr_by_drmaa_name( jt->session, name, err );
		if( OK(err) && !drmaa_is_vector(attr) )
			RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT );
	 }

	if( OK(err) )
	 {
		drmaa_mutex_lock( &jt->mutex, err );
		value = drmaa_copy_vector(
				(const char*const *)jt->attrib[ attr->code ], err );
		drmaa_mutex_unlock( &jt->mutex, err );
	 }

	if( OK(err) )
		DRMAA_MALLOC( result, drmaa_attr_values_t );
	if( OK(err) )
	 {
		result->list = result->iter = value;
		*out_values = result;
	 }
	else
	 {
		*out_values = NULL;
		if( value )
			drmaa_free_vector( value );
	 }

	return err->rc;
}


int
drmaa_get_attribute_names(
		drmaa_attr_names_t **values,
		char *errmsg, size_t errlen )
{
	drmaa_err_ctx_t err_ctx, *err=&err_ctx;
	drmaa_attr_names_t *result = NULL;

	drmaa_err_init( err, errmsg, errlen );
	if( OK(err) )
		DRMAA_MALLOC( result, drmaa_attr_names_t );
	if( OK(err) )
	 {
		result->list = result->iter = drmaa_copy_vector(
				drmaa_get_implementation_info( err )->attributes, err );
		*values = result;
	 }
	else
		*values = NULL;

	return err->rc;
}


int
drmaa_get_vector_attribute_names(
		drmaa_attr_names_t **values,
		char *errmsg, size_t errlen )
{
	drmaa_err_ctx_t err_ctx, *err=&err_ctx;
	drmaa_attr_names_t *result = NULL;

	drmaa_err_init( err, errmsg, errlen );
	if( OK(err) )
		DRMAA_MALLOC( result, drmaa_attr_names_t );
	if( OK(err) )
	 {
		result->list = result->iter = drmaa_copy_vector(
				drmaa_get_implementation_info( err )->vector_attributes, err );
		*values = result;
	 }
	else
		*values = NULL;

	return err->rc;
}


#define DRMAA_GET_NEXT_VALUE()                         \
	if( values == NULL || *values->iter == NULL )        \
		return DRMAA_ERRNO_NO_MORE_ELEMENTS;               \
	strlcpy( value, *values->iter++, value_len );  \
	return DRMAA_ERRNO_SUCCESS;
int drmaa_get_next_attr_name( drmaa_attr_names_t* values, char *value, size_t value_len )
{ DRMAA_GET_NEXT_VALUE(); }
int drmaa_get_next_attr_value( drmaa_attr_values_t* values, char *value, size_t value_len )
{ DRMAA_GET_NEXT_VALUE(); }
int drmaa_get_next_job_id( drmaa_job_ids_t* values, char *value, size_t value_len )
{ DRMAA_GET_NEXT_VALUE(); }

#define DRMAA_GET_NUM_VALUES()   \
	char **i;                      \
	size_t cnt = 0;                \
	if( values != NULL )           \
		for( i = values->list;  *i != NULL;  i++ ) \
			cnt++;                     \
	*size = cnt;                   \
	return DRMAA_ERRNO_SUCCESS;
int drmaa_get_num_attr_names( drmaa_attr_names_t* values, size_t *size )
{ DRMAA_GET_NUM_VALUES(); }
int drmaa_get_num_attr_values( drmaa_attr_values_t* values, size_t *size )
{ DRMAA_GET_NUM_VALUES(); }
int drmaa_get_num_job_ids( drmaa_job_ids_t* values, size_t *size )
{ DRMAA_GET_NUM_VALUES(); }


void drmaa_release_attr_names( drmaa_attr_names_t* values )
{ drmaa_free_vector( values->list );  free(values); }
void drmaa_release_attr_values( drmaa_attr_values_t* values )
{ drmaa_free_vector( values->list );  free(values); }
void drmaa_release_job_ids( drmaa_job_ids_t* values )
{ drmaa_free_vector( values->list );  free(values); }




drmaa_job_set_t *
drmaa_job_set_create( drmaa_err_ctx_t *err )
{
	drmaa_job_set_t *set = NULL;
	const size_t initial_size = 1024;

	DEBUG(( "-> drmaa_job_set_create()" ));
	if( OK(err) )  DRMAA_MALLOC( set, drmaa_job_set_t );
	if( OK(err) )
	 {
		set->tab = NULL;
		DRMAA_CALLOC( set->tab, initial_size, drmaa_job_t* );
	 }
	if( OK(err) )
	 {
		set->tab_size = initial_size;
		set->tab_mask = set->tab_size - 1;
		if( OK(err) )
			drmaa_mutex_init( &set->mutex, err );
	 }

	if( !OK(err) && set )
	 {
		if( set->tab )
			DRMAA_FREE( set->tab );
		DRMAA_FREE( set );
		set = NULL;
	 }
	DEBUG(( "<- drmaa_job_set_create(); err=%d", err->rc ));
	return set;
}


void
drmaa_job_set_destroy( drmaa_job_set_t *set, drmaa_err_ctx_t *err )
{
	unsigned i;
	drmaa_job_t *j;

	DEBUG(( "-> drmaa_job_set_destroy()" ));
	for( i = 0;  i < set->tab_size;  i++ )
		for( j = set->tab[i];  j != NULL;  )
		 {
			drmaa_job_t *job = j;
			j = j->next;
			drmaa_mutex_lock( &job->mutex, err );
			drmaa_job_release( &job, err );
#if 0
			job->ref_cnt ++;
			drmaa_job_destroy( job, err );
#endif
		 }
	DRMAA_FREE( set->tab );
	DRMAA_FREE( set );
	DEBUG(( "<- drmaa_job_set_destroy(); err=%d", err->rc ));
}


void
drmaa_job_set_add( drmaa_job_set_t *set, drmaa_job_t *job,
		drmaa_err_ctx_t *err )
{
	uint32_t h;
	DEBUG(( "-> drmaa_job_set_add( job=%p, job_id=%s )",
				(void*)job, job->job_id ));
	drmaa_mutex_lock( &set->mutex, err );
	h = hashstr( job->job_id, strlen(job->job_id), 0 );
	h &= set->tab_mask;
	job->next = set->tab[ h ];
	set->tab[ h ] = job;
	job->ref_cnt++;
	drmaa_mutex_unlock( &set->mutex, err );
	DEBUG(( "<- drmaa_job_set_add; err=%d, job->ref_cnt=%d",
				err->rc, job->ref_cnt ));
}


void
drmaa_job_set_remove( drmaa_job_set_t *set, drmaa_job_t *job,
		drmaa_err_ctx_t *err )
{
	drmaa_job_t **pjob = NULL;
	uint32_t h;

	DEBUG(( "-> drmaa_job_set_remove( job_id=%s )", job->job_id ));
	drmaa_mutex_lock( &set->mutex, err );
	h = hashstr( job->job_id, strlen(job->job_id), 0 );
	h &= set->tab_mask;
	for( pjob = &set->tab[ h ];  *pjob;  pjob = &(*pjob)->next )
	 {
		if( *pjob == job )
			break;
	 }
	if( *pjob )
	 {
		*pjob = (*pjob)->next;
		job->next = NULL;
		drmaa_job_release( &job, err );
	 }
	else
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_JOB );
	drmaa_mutex_unlock( &set->mutex, err );
	DEBUG(( "<- drmaa_job_set_remove; err=%d", err->rc ));
}


drmaa_job_t *
drmaa_job_find(
		drmaa_job_set_t *set, const char *job_id,
		drmaa_err_ctx_t *err
		)
{
	uint32_t h;
	drmaa_job_t *job = NULL;

	DEBUG(( "-> drmaa_job_find( job_id=%s )", job_id ));
	drmaa_mutex_lock( &set->mutex, err );
	h = hashstr( job_id, strlen(job_id), 0 );
	h &= set->tab_mask;
	for( job = set->tab[ h ];  job;  job = job->next )
		if( !strcmp( job->job_id, job_id ) )
			break;
	if( job )
	 {
		drmaa_mutex_lock( &job->mutex, err );
		if( job->flags & DRMAA_JOB_DISPOSED )
		 {
			drmaa_mutex_unlock( &job->mutex, err );
			job = NULL;
		 }
		else
			job->ref_cnt ++;
		/* drmaa_mutex_unlock( &job->mutex ); */
	 }
	drmaa_mutex_unlock( &set->mutex, err );
	if( job==NULL )
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_JOB );
	DEBUG(( "<- drmaa_job_find( job_id=%s ) =%p; err=%d, job->ref_cnt=%d",
				job_id, (void*)job, err->rc, job ? job->ref_cnt : 0 ));
	return job;
}


drmaa_job_t *
drmaa_job_find_terminated( drmaa_job_set_t *set, drmaa_err_ctx_t *err )
{
	drmaa_job_t *job = NULL;
	bool any_job = false;
	size_t i;
	DEBUG(( "-> drmaa_job_find_terminated()" ));
	drmaa_mutex_lock( &set->mutex, err );
	for( i = 0;  i < set->tab_size;  i++ )
		for( job = set->tab[ i ];  job;  job = job->next )
			if( !(job->flags & DRMAA_JOB_DISPOSED) )
			 {
				any_job = true;
				if( job->status >= DRMAA_PS_DONE )
					goto found;
			 }
found:
	if( job )
	 {
		drmaa_mutex_lock( &job->mutex, err );
		job->ref_cnt ++;
	 }
	else if( !any_job )
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_JOB );
	drmaa_mutex_unlock( &set->mutex, err );
	DEBUG(( "<- drmaa_job_find_terminated(); err=%d, job=%p, job_id=%s",
				err->rc, (void*)job, job ? job->job_id : "(none)" ));
	return job;
}


char **
drmaa_get_all_job_ids( drmaa_job_set_t *set, drmaa_err_ctx_t *err )
{
	drmaa_job_t *job = NULL;
	char **job_ids = NULL;
	size_t n_jobs = 0, capacity = 0;
	size_t i;
	DEBUG(( "-> drmaa_get_all_job_ids" ));
	drmaa_mutex_lock( &set->mutex, err );
	DRMAA_CALLOC( job_ids, capacity=16, char* );
	for( i = 0;  OK(err) && i < set->tab_size;  i++ )
		for( job = set->tab[ i ];  OK(err) && job;  job = job->next )
			if( !(job->flags & DRMAA_JOB_DISPOSED) )
			 {
				if( n_jobs == capacity )
					DRMAA_REALLOC( job_ids, capacity *= 2, char* );
				if( OK(err) )
					job_ids[ n_jobs++ ] = drmaa_strdup( job->job_id, err );
			 }
	drmaa_mutex_unlock( &set->mutex, err );
	if( !OK(err) )
	 {
		drmaa_free_vector( job_ids );
		job_ids = NULL;
	 }
	DEBUG(( "<- drmaa_get_all_job_ids =%p; err=%d",
				(void*)job_ids, err->rc ));
	return job_ids;
}


void
drmaa_job_set_signal_all( drmaa_job_set_t *set, drmaa_err_ctx_t *err )
{
	size_t i;
	drmaa_job_t *job = NULL;

	DEBUG(( "-> drmaa_job_set_signal_all" ));
	drmaa_mutex_lock( &set->mutex, err );
	for( i = 0;  OK(err) && i < set->tab_size;  i++ )
	 {
		for( job = set->tab[ i ];  OK(err) && job;  job = job->next )
		 {
			drmaa_mutex_lock( &job->mutex, err );
			if( OK(err) )
				drmaa_cond_broadcast( &job->status_cond, err );
			drmaa_mutex_unlock( &job->mutex, err );
		 }
	 }
	drmaa_mutex_unlock( &set->mutex, err );
	DEBUG(( "<- drmaa_job_set_signal_all; err=%d", err->rc ));
}



void
drmaa_job_init( drmaa_job_t *job, drmaa_err_ctx_t *err )
{
	/* DEBUG(( "-> drmaa_job_init(%p)", (void*)job )); */
	job->next              = NULL;
	job->session           = NULL;
	job->ref_cnt           = 0;
	job->job_id            = NULL;
	job->last_update_time  = 0;
	job->flags             = 0;
	job->status            = DRMAA_PS_UNDETERMINED;
	job->exit_status       = 0;
	job->submit_time       = 0;
	job->start_time        = 0;
	job->end_time          = 0;
	job->cpu_usage         = 0;
	job->mem_usage         = 0;
	job->walltime          = 0;
	job->impl              = NULL;
	drmaa_mutex_init( &job->mutex, err );
	drmaa_cond_init( &job->status_cond, err );
	drmaa_cond_init( &job->destroy_cond, err );
}


void
drmaa_job_release( drmaa_job_t **pjob, drmaa_err_ctx_t *err )
{
	bool destroy;
	drmaa_job_t *job = *pjob;
	if( job == NULL )
		return;
	DEBUG(( "-> drmaa_job_release( job_id=%s ); job->ref_cnt=%d",
				job->job_id, job->ref_cnt ));
	assert( job->ref_cnt > 0 );
	destroy = ( --(job->ref_cnt) == 0 );
	drmaa_mutex_unlock( &job->mutex, err );
	if( destroy )
	 {
		DEBUG(( "drmaa_job_release: destroying job" ));
		drmaa_cond_destroy( &job->status_cond, err );
		drmaa_cond_destroy( &job->destroy_cond, err );
		drmaa_mutex_destroy( &job->mutex, err );
		DRMAA_FREE( job );
	 }
	DEBUG(( "<- drmaa_job_release; err=%d", err->rc ));
	*pjob = NULL;
}



int
drmaa_control( const char *job_id, int action, char *errmsg, size_t errlen )
{
	drmaa_err_ctx_t errctx, *err=&errctx;
	drmaa_session_t *session = NULL;
	char **job_ids = NULL;
	char **i;

	drmaa_err_init( err, errmsg, errlen );
	DEBUG(( "-> drmaa_control( job_id=%s, action=%s )",
				job_id, drmaa_control_to_str(action) ));

	if( job_id == NULL )
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT );
	if( OK(err) )
		session = drmaa_session_get( err );

	if( OK(err) )
	 {
		if( !strcmp( job_id, DRMAA_JOB_IDS_SESSION_ALL ) )
			job_ids = drmaa_get_all_job_ids( session->jobs, err );
		else
		 {
			DRMAA_CALLOC( job_ids, 2, char* );
			if( OK(err) )
				job_ids[0] = drmaa_strdup( job_id, err );
		 }
	 }

	for( i = job_ids;  OK(err) && *i != NULL;  i++ )
	 {
		drmaa_job_t *job = NULL;
		job = drmaa_job_find( session->jobs, *i, err );
		if( OK(err) )
			drmaa_control_impl( session, job, action, err );
		drmaa_job_release( &job, err );
	 }

	drmaa_free_vector( job_ids );
	drmaa_session_release( session, err );
	DEBUG(( "<- drmaa_control() =%d", err->rc ));
	return err->rc;
}



int
drmaa_job_ps( const char *job_id, int *remote_ps, char *errmsg, size_t errlen )
{
	drmaa_err_ctx_t errctx, *err=&errctx;
	drmaa_session_t *c = NULL;
	drmaa_job_t *job = NULL;

	DEBUG(( "-> drmaa_job_ps( job_id=%s )", job_id ));
	drmaa_err_init( err, errmsg, errlen );
	if( job_id == NULL )
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT );
	if( OK(err) )
		c = drmaa_session_get( err );
	if( OK(err) )
		job = drmaa_job_find( c->jobs, job_id, err );
	if( OK(err) )
		drmaa_job_update_status( job, err );
	if( OK(err) )
		*remote_ps = job->status;
	drmaa_job_release( &job, err );
	drmaa_session_release( c, err );

	DEBUG(( "<- drmaa_job_ps( job_id=%s ) =%d, remote_ps=%s (0x%02x)",
				job_id, err->rc, drmaa_job_ps_to_str(*remote_ps), *remote_ps ));
	return err->rc;
}



int
drmaa_run_job(
		char *job_id, size_t job_id_len,
		const drmaa_job_template_t *jt,
		char *errmsg, size_t errlen
		)
{
	drmaa_err_ctx_t errctx, *err=&errctx;

	drmaa_err_init( err, errmsg, errlen );
	DEBUG(( "-> drmaa_run_job" ));
	drmaa_run_job_impl( job_id, job_id_len, jt, -1, err );
	DEBUG(( "<- drmaa_run_job =%d", err->rc ));
	return err->rc;
}


int
drmaa_run_bulk_jobs(
		drmaa_job_ids_t **job_ids,
		const drmaa_job_template_t *jt,
		int start, int end, int incr,
		char *errmsg, size_t errlen
		)
{
	drmaa_err_ctx_t errctx, *err=&errctx;
	drmaa_job_ids_t *result = NULL;
	unsigned n_jobs;
	unsigned i;
	char **j;

	drmaa_err_init( err, errmsg, errlen );
	DEBUG(( "-> drmaa_run_bulk_jobs( start=%d, end=%d, incr=%d, jt=%p )",
		start, end, incr, (void*)jt ));

	/* Be conform with general DRMAA specifiaction
	 * -- accept negative incr with end <= start.
	 */
	if( incr < 0 )
	 { /* swap(start,end) */
		int tmp;
		tmp   = start;
		start = end;
		end   = tmp;
		incr  = - incr;
	 }

	if( 0 < start  &&  start <= end  &&  0 < incr )
	 {}
	else
	 {
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT );
		return err->rc;
	 }
	n_jobs = (end-start) / incr + 1;

	DRMAA_MALLOC( result, drmaa_job_ids_t );
	if( OK(err) )
	 {
		DRMAA_CALLOC( result->list, n_jobs+1, char* );
		result->iter = result->list;
	 }
	j = result->list;
	for( i = start;  i <= (unsigned)end && OK(err);  i += incr )
	 {
		char *job_id = NULL;
		DRMAA_CALLOC( job_id, DRMAA_JOBNAME_BUFFER, char );
		if( OK(err) )
			drmaa_run_job_impl( job_id, DRMAA_JOBNAME_BUFFER, jt, i, err );
		if( OK(err) )
			*j++ = job_id;
	 }
	*j++ = NULL;

	if( OK(err) )
		*job_ids = result;
	else
		drmaa_release_job_ids( result );

	DEBUG(( "<- drmaa_run_bulk_jobs =%d", err->rc ));
	return err->rc;
}



static struct timespec *
drmaa_timeout_time( signed long timeout, struct timespec *ts,
		drmaa_err_ctx_t *err	)
{
	if( timeout == DRMAA_TIMEOUT_WAIT_FOREVER )
		return NULL;
	else
	 {
		drmaa_get_time( ts, err );
		if( OK(err) )
		 {
			if( timeout != DRMAA_TIMEOUT_NO_WAIT )
				ts->tv_sec += timeout;
			return ts;
		 }
		else
			return NULL;
	 }
}


int
drmaa_synchronize(
		const char **input_job_ids, signed long timeout,
		int dispose,
		char *errmsg, size_t errlen
		)
{
	drmaa_err_ctx_t errctx, *err=&errctx;
	drmaa_session_t *session = NULL;
	bool wait_for_all = false;
	struct timespec ts;
	const char **job_ids = NULL;
	const char **i;

	drmaa_err_init( err, errmsg, errlen );
	DEBUG(( "-> drmaa_synchronize( job_ids={...}, timeout=%ld, dispose=%d )",
			timeout, dispose ));

	if( input_job_ids == NULL )
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT );

	if( OK(err) )
		for( i = input_job_ids;  *i != NULL;  i++ )
			if( !strcmp(*i,DRMAA_JOB_IDS_SESSION_ALL) )
				wait_for_all = true;

	if( OK(err) )
		session = drmaa_session_get( err );

	if( OK(err) )
	 {
		if( wait_for_all )
			job_ids = (const char**)drmaa_get_all_job_ids( session->jobs, err );
		else
			job_ids = input_job_ids;
	 }

	for( i = job_ids;  OK(err) && *i != NULL;  i++ )
		drmaa_wait_for_single_job( session, *i, NULL, NULL, dispose,
					drmaa_timeout_time(timeout,&ts,err), err );

	if( job_ids != input_job_ids )
		drmaa_free_vector( (char**)job_ids );

	drmaa_session_release( session, err );

	DEBUG(( "<- drmaa_synchronize =%d", err->rc ));
	return err->rc;
}


int
drmaa_wait(
		const char *job_id, char *job_id_out, size_t job_id_out_len,
		int *stat, signed long timeout, drmaa_attr_values_t **rusage,
		char *errmsg, size_t errlen
		)
{
	drmaa_err_ctx_t err_ctx, *err=&err_ctx;
	drmaa_session_t *session = NULL;
	struct timespec ts;
	char *result_job_id = NULL;

	drmaa_err_init( err, errmsg, errlen );
	DEBUG(( "-> drmaa_wait( job_id=%s, timeout=%ld )", job_id, timeout ));

	session = drmaa_session_get( err );

	if( OK(err) )
	 {
		if( !strcmp( job_id, DRMAA_JOB_IDS_SESSION_ANY ) )
		 { /* wait for any job in session */
			result_job_id = drmaa_wait_for_any_job(
					session, stat, rusage, true,
					drmaa_timeout_time(timeout,&ts,err), err );
		 }
		else /* wait for given job id */
		 {
			if( OK(err) )
				drmaa_wait_for_single_job( session, job_id, stat, rusage, true,
						drmaa_timeout_time(timeout,&ts,err), err );
			if( OK(err) )
				result_job_id = (char*)job_id;
		 }
	 }

	if( OK(err) )
		strlcpy( job_id_out, result_job_id, job_id_out_len );
	if( result_job_id != job_id )
		DRMAA_FREE( result_job_id );

	if( session )
		drmaa_session_release( session, err );

	DEBUG(( "<- drmaa_wait =%d; job_id=%s",
				err->rc, err->rc ? NULL : job_id_out ));
	return err->rc;
}




int
drmaa_job_status_by_drmaa( drmaa_job_t *job )
{
	switch( job->flags & DRMAA_JOB_STATE_MASK )
	 {
		case DRMAA_JOB_QUEUED:
			return DRMAA_PS_QUEUED_ACTIVE;
		case DRMAA_JOB_QUEUED | DRMAA_JOB_HOLD:
			return DRMAA_PS_USER_ON_HOLD;
		case DRMAA_JOB_RUNNING:
			return DRMAA_PS_RUNNING;
		case DRMAA_JOB_RUNNING | DRMAA_JOB_SUSPENDED:
			return DRMAA_PS_USER_SUSPENDED;
		case DRMAA_JOB_TERMINATED:
			return DRMAA_PS_DONE;
		default:
			return DRMAA_PS_UNDETERMINED;
	 }
}



void
drmaa_job_get_termination_state(
		drmaa_job_t *job, int *status, drmaa_attr_values_t **rusage_out,
		drmaa_err_ctx_t *err
		)
{
	drmaa_attr_values_t *rusage = NULL;
	char **rlist = NULL;
	int i=0;

	if( OK(err)  &&  status )
		*status = job->exit_status;

	if( OK(err) )
		DRMAA_MALLOC( rusage, drmaa_attr_values_t );

	if( OK(err) )
	 {
		DRMAA_CALLOC( rlist, 6, char* );
		rusage->list = rusage->iter = rlist;
	 }
	if( OK(err) )
		rlist[i++] = drmaa_asprintf( err,
				"submission_time=%ld", (long)job->submit_time );
	if( OK(err) )
		rlist[i++] = drmaa_asprintf( err,
				"start_time=%ld", (long)job->start_time );
	if( OK(err) )
		rlist[i++] = drmaa_asprintf( err,
				"end_time=%ld", (long)job->end_time );
	if( OK(err) )
		rlist[i++] = drmaa_asprintf( err,
				"cpu=%ld", job->cpu_usage );
	if( OK(err) )
		rlist[i++] = drmaa_asprintf( err,
				"mem=%ld", job->mem_usage );
	if( OK(err) )
		rlist[i++] = drmaa_asprintf( err,
				"walltime=%ld", job->walltime );
	if( rlist )
		rlist[i++] = NULL;

	if( !OK(err) && rusage )
	 {
		drmaa_release_attr_values( rusage );
		rusage = NULL;
	 }
	if( rusage_out )
		*rusage_out = rusage;
}


int
drmaa_get_contact(
		char *contact, size_t contact_len,
		char *errmsg, size_t errlen
		)
{
	drmaa_err_ctx_t errctx, *err = &errctx;
	drmaa_session_t *session = NULL;
	const drmaa_implementation_info_t *impl_info = NULL;
	const char *result = NULL;

	drmaa_err_init( err, errmsg, errlen );
	impl_info = drmaa_get_implementation_info( err );
	if( OK(err) )
	 {
		session = drmaa_session_get( err );
		switch( err->rc )
		 {
			case DRMAA_ERRNO_SUCCESS:
				if( session->contact )
					result = session->contact;
				else
					result = impl_info->default_contact;
				break;
			case DRMAA_ERRNO_NO_ACTIVE_SESSION:
				result = impl_info->default_contact;
				drmaa_err_clear( err );
				break;
			default:
				break;
		 }
	 }
	if( OK(err) )
		strlcpy( contact, result, contact_len );
	if( session )
		drmaa_session_release( session, err );
	return err->rc;
}


int
drmaa_version(
		unsigned int *major, unsigned int *minor,
		char *errmsg, size_t errlen
		)
{
	*major = 1;  *minor = 0;
	return DRMAA_ERRNO_SUCCESS;
}


int
drmaa_get_DRM_system(
		char *drm_system, size_t drm_system_len,
		char *errmsg, size_t errlen
		)
{
	drmaa_err_ctx_t errctx, *err=&errctx;
	const drmaa_implementation_info_t *impl_info = NULL;

	drmaa_err_init( err, errmsg, errlen );
	if( OK(err)  &&  drm_system == NULL )
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT );
	if( OK(err) )
		impl_info = drmaa_get_implementation_info( err );
	if( OK(err) )
		strlcpy( drm_system, impl_info->drm_system, drm_system_len );
	return err->rc;
}


int
drmaa_get_DRMAA_implementation(
		char *drmaa_impl, size_t drmaa_impl_len,
		char *errmsg, size_t errlen
		)
{
	drmaa_err_ctx_t errctx, *err=&errctx;
	const drmaa_implementation_info_t *impl_info = NULL;

	drmaa_err_init( err, errmsg, errlen );
	if( OK(err)  &&  drmaa_impl == NULL )
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT );
	if( OK(err) )
		impl_info = drmaa_get_implementation_info( err );
	if( OK(err) )
		strlcpy( drmaa_impl, impl_info->drmaa_implementation, drmaa_impl_len );
	return err->rc;
}


struct pbs_attrib { const char *name; int code; };

const struct pbs_attrib *
pbs_attrib_lookup( const char *str, unsigned int len );

const drmaa_attrib_info_t *
attr_by_drm_name( drmaa_session_t *c, const char *drm_name,
	drmaa_err_ctx_t *err )
{
	const struct pbs_attrib *attr = NULL;
	attr = pbs_attrib_lookup( drm_name, strlen(drm_name) );
	if( attr == NULL )
	 {
		/* RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT ); */
		return NULL;
	 }
	else if( attr->code < c->n_attributes )
		return & c->attributes[ attr->code ];
	else
	 {
		RAISE_DRMAA_1( DRMAA_ERRNO_INTERNAL_ERROR );
		return NULL;
	 }
}

