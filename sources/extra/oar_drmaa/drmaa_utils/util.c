/* $Id: util.c 533 2007-12-22 15:25:42Z lukasz $ */
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

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <fcntl.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>

#include <ctype.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include <drmaa_utils/attrib.h>
#include <drmaa_utils/common.h>
#include <drmaa_utils/drmaa_base.h>
#include <drmaa_utils/util.h>

#ifndef lint
static char rcsid[]
#	ifdef __GNUC__
		__attribute__ ((unused))
#	endif
	= "$Id: util.c 533 2007-12-22 15:25:42Z lukasz $";
#endif


drmaa_submit_ctx_t *
drmaa_create_submit_ctx(
		const drmaa_job_template_t *jt, int bulk_no,
		drmaa_err_ctx_t *err )
{
	drmaa_submit_ctx_t *sc = NULL;
	DRMAA_MALLOC( sc, drmaa_submit_ctx_t );
	if( OK(err) )
	 {
		sc->jt = jt;
		sc->home_directory = strdup( getenv("HOME") );
		if( jt->attrib[ATTR_JOB_WORKING_DIR] != NULL )
			sc->working_directory = strdup( jt->attrib[ATTR_JOB_WORKING_DIR] );
		else
			sc->working_directory = strdup( sc->home_directory );
		asprintf( &sc->bulk_incr, "%d", bulk_no );
	 }

	if( OK(err) )
		return sc;
	else
	 {
		drmaa_free_submit_ctx( sc );
		return NULL;
	 }
}


void
drmaa_free_submit_ctx( drmaa_submit_ctx_t *sc )
{
	if( sc )
	 {
		DRMAA_FREE( sc->working_directory );
		DRMAA_FREE( sc->home_directory    );
		DRMAA_FREE( sc->bulk_incr         );
		DRMAA_FREE( sc );
	 }
}


char *
drmaa_expand_placeholders(
		drmaa_submit_ctx_t *c, char *s, unsigned set,
		drmaa_err_ctx_t *err )
{
	unsigned mask;
	for( mask=1;  ;  mask*=2 )
	 {
		const char *ph;
		const char *value;
		char *r;

		switch( mask )
		 {
			case DRMAA_PLACEHOLDER_MASK_HD:
				ph = DRMAA_PLACEHOLDER_HD;
				value = c->home_directory;
				break;
			case DRMAA_PLACEHOLDER_MASK_WD:
				ph = DRMAA_PLACEHOLDER_WD;
				value = c->working_directory;
				break;
			case DRMAA_PLACEHOLDER_MASK_INCR:
				ph = DRMAA_PLACEHOLDER_INCR;
				value = c->bulk_incr;
				break;
			default:
				return s;
		 }
		if( mask & set )
		 {
			r = drmaa_replace( s, ph, value, err );
			if( OK(err) )
				s = r;
			else
			 {
				DRMAA_FREE( s );
			 }
			if( r != NULL )
				s = r;
			else
			 {
				DRMAA_FREE( s );
				return NULL;
			 }
		 }
	 }
}


const char *
drmaa_control_to_str( int action )
{
	switch( action )
	 {
		case DRMAA_CONTROL_SUSPEND:
			return "suspend";
		case DRMAA_CONTROL_RESUME:
			return "resume";
		case DRMAA_CONTROL_HOLD:
			return "hold";
		case DRMAA_CONTROL_RELEASE:
			return "release";
		case DRMAA_CONTROL_TERMINATE:
			return "terminate";
		default:
			return "?";
	 }
}


const char *
drmaa_job_ps_to_str( int ps )
{
	switch( ps )
	 {
		case DRMAA_PS_UNDETERMINED:
			return "undetermined";
		case DRMAA_PS_QUEUED_ACTIVE:
			return "queued_active";
		case DRMAA_PS_SYSTEM_ON_HOLD:
			return "systen_on_hold";
		case DRMAA_PS_USER_ON_HOLD:
			return "user_on_hold";
		case DRMAA_PS_USER_SYSTEM_ON_HOLD:
			return "user_systen_on_hold";
		case DRMAA_PS_RUNNING:
			return "running";
		case DRMAA_PS_SYSTEM_SUSPENDED:
			return "system_suspended";
		case DRMAA_PS_USER_SUSPENDED:
			return "user_suspended";
		case DRMAA_PS_USER_SYSTEM_SUSPENDED:
			return "user_system_suspended";
		case DRMAA_PS_DONE:
			return "done";
		case DRMAA_PS_FAILED:
			return "failed";
		default:
			return "?";
	 }
}


void
drmaa_free_vector( char **vector )
{
	char **i;
	if( vector == NULL )
		return;
	for( i = vector;  *i != NULL;  i++ )
		DRMAA_FREE( *i );
	DRMAA_FREE( vector );
}


char **
drmaa_copy_vector( const char *const * vector, drmaa_err_ctx_t *err )
{
	unsigned n_items, i;
	char **result = NULL;

	if( !OK(err) )
		return NULL;

	if( vector )
		for( n_items = 0;  vector[ n_items ] != NULL;  n_items++ ) {}
	else
		n_items = 0;

	DRMAA_CALLOC( result, n_items+1, char* );
	for( i = 0;  OK(err)  &&  i < n_items;  i++ )
		result[i] = drmaa_strdup( vector[i], err );

	if( OK(err) )
		return result;
	else
	 {
		drmaa_free_vector( result );
		return NULL;
	 }
}


char *
drmaa_replace( char *str, const char *placeholder, const char *value,
	 drmaa_err_ctx_t *err )
{
	size_t ph_len, v_len;
	char *found = NULL;

	if( str == NULL )
	 {
		RAISE_DRMAA_1( DRMAA_ERRNO_INTERNAL_ERROR );
		return NULL;
	 }

	ph_len = strlen( placeholder );
	v_len  = strlen( value );
	do {
		size_t str_len;
		str_len = strlen( str );
		found = strstr( str, placeholder );
		if( found )
		 {
			char *result;
			size_t pos = found - str;
			result = (char*)malloc( str_len - ph_len + v_len + 1 );
			if( result == NULL )
				return NULL;
			memcpy( result, str, pos );
			memcpy( result+pos, value, v_len );
			memcpy( result+pos+v_len, str+pos+ph_len, str_len-pos-ph_len );
			result[ str_len-ph_len+v_len ] = 0;
			free( str );
			str = result;
		 }
	} while( found );

	return str;
}


char *
drmaa_explode( const char *const *vector, char glue, drmaa_err_ctx_t *err )
{
	char *result = NULL, *s;
	const char *const *i;
	size_t size =0;
	for( i = vector;  *i != NULL;  i++ )
	 {
		if( i != vector )
			size++;
		size += strlen(*i);
	 }
	DRMAA_CALLOC( result, size+1, char );
	if( OK(err) )
	 {
		s = result;
		for( i = vector;  *i != NULL;  i++ )
		 {
			if( i != vector )
				*s++ = glue;
			strcpy( s, *i );
			s += strlen( *i );
		 }
	 }

	if( !OK(err) )
	 {
		DRMAA_FREE( result );
		result = NULL;
	 }
	return result;
}


char *
drmaa_strdup( const char *s, drmaa_err_ctx_t *err )
{
	char *result;
	if( s == NULL )
		return NULL;
	result = strdup( s );
	if( result == NULL )
		RAISE_ERRNO();
	return result;
}


char *
drmaa_strndup( const char *s, size_t n, drmaa_err_ctx_t *err )
{
	char *result;
	if( s == NULL )
		return NULL;
	result = strndup( s, n );
	if( result == NULL )
		RAISE_ERRNO();
	return result;
}


char *
drmaa_asprintf( drmaa_err_ctx_t *err, const char *fmt, ... )
{
	va_list args;
	char *result = NULL;
	va_start( args, fmt );
	result = drmaa_vasprintf( fmt, args, err );
	va_end( args );
	return result;
}


char *
drmaa_vasprintf( const char *fmt, va_list args, drmaa_err_ctx_t *err )
{
	char *result = NULL;
	int rc;
	rc = vasprintf( &result, fmt, args );
	if( rc == -1 )
	 {
		RAISE_ERRNO();
		result = NULL;
	 }
	return result;
}


void
drmaa_get_time( struct timespec *ts, drmaa_err_ctx_t *err )
{
	struct timeval tv;
	int rc;
	rc = gettimeofday( &tv, NULL );
	if( rc )
		RAISE_ERRNO();
	else
	 {
		ts->tv_sec = tv.tv_sec;
		ts->tv_nsec = 1000 * tv.tv_usec;
	 }
}


void
drmaa_ts_add( struct timespec *a, const struct timespec *b )
{
	const int nano = 1000000000;
	a->tv_sec += b->tv_sec;
	a->tv_nsec += b->tv_nsec;
	if( a->tv_nsec >= nano )
	 {
		a->tv_nsec -= nano;
		a->tv_sec ++;
	 }
}


int
drmaa_ts_cmp( const struct timespec *a, const struct timespec *b )
{
	if( a->tv_sec != b->tv_sec )
		return a->tv_sec - b->tv_sec;
	else
		return a->tv_nsec - b->tv_nsec;
}


void
drmaa_read_file(
		const char *filename, bool must_exist,
		char **content, size_t *length,
		drmaa_err_ctx_t *err
		)
{
	char *buffer = NULL;
	size_t size = 0;
	size_t capacity = 0;
	int fd = -1;

	if( OK(err) )
	 {
		fd = open( filename, O_RDONLY );
		if( fd == -1 )
		 {
			if( errno==ENOENT && !must_exist )
			 {
				*content = NULL;
				*length = 0;
				return;
			 }
			else
				RAISE_ERRNO();
		 }
	 }

	while( OK(err) )
	 {
		ssize_t n_read;
		capacity = size + 1024;
		DRMAA_REALLOC( buffer, capacity, err );
		if( OK(err) )
		 {
			n_read = read( fd, buffer, capacity-size );
			if( n_read == (ssize_t)-1 )
				RAISE_ERRNO();
			else if( n_read == 0 )
				break;
			else
				size += n_read;
		 }
	 }

	if( OK(err) )
		DRMAA_REALLOC( buffer, size+1, err );
	if( OK(err) )
		buffer[ size ] = '\0';

	if( fd != -1 )
		close( fd );

	if( OK(err) )
	 {
		*content = buffer;
		*length = size;
	 }
	else
	 {
		if( buffer )
		 {
			DRMAA_FREE( buffer );
			buffer = NULL;
		 }
		*content = NULL;
		*length = 0;
	 }
}


struct drmaa_rope_s {
	drmaa_rope_t *prev;
	char *buffer;
	size_t buflen;
};

drmaa_rope_t *
drmaa_rope_create( drmaa_err_ctx_t *err )
{
	drmaa_rope_t *rope = NULL;
	if( OK(err) )
		DRMAA_MALLOC( rope, drmaa_rope_t );
	if( OK(err) )
	 {
		rope->prev = NULL;
		rope->buffer = NULL;
		rope->buflen = 0;
	 }
	return rope;
}

void
drmaa_rope_destroy( drmaa_rope_t *rope, drmaa_err_ctx_t *err )
{
	while( rope )
	 {
		drmaa_rope_t *prev = rope->prev;
		DRMAA_FREE( rope->buffer );
		DRMAA_FREE( rope );
		rope = prev;
	 }
}

drmaa_rope_t *
drmaa_rope_append( drmaa_rope_t *rope, const char *string, drmaa_err_ctx_t *err )
{
	drmaa_rope_t *rhs = NULL;
	if( OK(err) )
		DRMAA_MALLOC( rhs, drmaa_rope_t );
	if( OK(err) )
	 {
		rhs->prev = NULL;
		rhs->buffer = NULL;
		rhs->buflen = 0;
	 }
	if( OK(err) )
	 {
		rhs->buffer = drmaa_strdup( string, err );
		rhs->buflen = strlen( string );
	 }
	if( OK(err) )
		rhs->prev = rope;
	else if( rhs )
	 {
		DRMAA_FREE( rhs );
		rhs = NULL;
	 }
	return rhs;
}

drmaa_rope_t *
drmaa_rope_printf( drmaa_rope_t *rope, drmaa_err_ctx_t *err,
		const char *fmt, ... )
{
	drmaa_rope_t *rhs = NULL;
	if( OK(err) )
		DRMAA_MALLOC( rhs, drmaa_rope_t );
	if( OK(err) )
	 {
		rhs->prev = NULL;
		rhs->buffer = NULL;
		rhs->buflen = 0;
	 }
	if( OK(err) )
	 {
		va_list args;
		va_start( args, fmt );
		rhs->buffer = drmaa_vasprintf( fmt, args, err );
		va_end( args );
	 }
	if( OK(err) )
	 {
		rhs->buflen = strlen( rhs->buffer );
		rhs->prev = rope;
	 }
	else if( rhs )
	 {
		DRMAA_FREE( rhs );
		rhs = NULL;
	 }
	return rhs;
}

char *
drmaa_rope_to_string( drmaa_rope_t *rope, drmaa_err_ctx_t *err )
{
	size_t len = 0;
	char *result = NULL;
	char *pos;
	drmaa_rope_t *i;

	if( !OK(err) )
		return NULL;

	for( i = rope;  i;  i = i->prev );
		len += i->buflen;

	DRMAA_CALLOC( result, len+1, char );
	if( OK(err) )
	 {
		result[ len ] = '\0';
		pos = result + len;
		for( i = rope;  i;  i = i->prev )
		 {
			pos -= i->buflen;
			memcpy( pos, i->buffer, i->buflen );
		 }
	 }

	return result;
}

