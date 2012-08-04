/* $Id: error.c 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file error.c
 * Error reporting and logging functions.
 */

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>
#if defined(__GNUC__)
#	include <execinfo.h>
#endif

#include <pthread.h>

#include <drmaa_utils/error.h>
#include <drmaa_utils/thread.h>
#include <drmaa_utils/lookup3.h>

#ifndef lint
static char rcsid[]
#	ifdef __GNUC__
		__attribute__ ((unused))
#	endif
	= "$Id: error.c 533 2007-12-22 15:25:42Z lukasz $";
#endif


static FILE *drmaa_logging_output = NULL;
drmaa_verbose_level_t drmaa_verbose_level =
#if DRMAA_DEBUG
	DRMAA_LOG_DEBUG_1
#else
	DRMAA_LOG_WARNING
#endif
;

#if 0
static pthread_key_t current_err_ctx;
static pthread_once_t init_cec_once = PTHREAD_ONCE_INIT;

static void
init_current_err_ctx(void)
{
	pthread_key_create( &current_err_ctx, NULL );
}


drmaa_err_ctx_t *
drmaa_err_get_current(void)
{
	pthread_once( &init_cec_once, init_current_err_ctx );
	return (drmaa_err_ctx_t*)pthread_getspecific( current_err_ctx );
}


void
drmaa_err_set_current( drmaa_err_ctx_t *err )
{
	pthread_once( &init_cec_once, init_current_err_ctx );
	pthread_setspecific( current_err_ctx, err );
}
#endif


void
drmaa_err_init(
		drmaa_err_ctx_t *err,
		char *error_diagnosis, size_t error_diag_len
		)
{
	/* drmaa_err_set_current( err ); */
	err->rc = DRMAA_ERRNO_SUCCESS;
	err->n_errors = 0;
	err->msg = error_diagnosis;
	err->msgsize = error_diag_len;
	err->free_msg = false;
}


int
drmaa_err_create( drmaa_err_ctx_t *err, drmaa_err_ctx_t *parent_err )
{
	int rc = DRMAA_ERRNO_SUCCESS;
	/* drmaa_err_set_current( err ); */
	err->rc = DRMAA_ERRNO_SUCCESS;
	err->n_errors = 0;
	err->msgsize = DRMAA_ERROR_STRING_BUFFER;
	err->msg = malloc( err->msgsize );
	err->free_msg = true;
	if( err->msg == NULL )
	 {
		err->rc = rc = DRMAA_ERRNO_NO_MEMORY;
		if( parent_err )
			drmaa_err_perror( parent_err, ENOMEM );
	 }
	return rc;
}


void
drmaa_err_destroy( drmaa_err_ctx_t *err )
{
	/* drmaa_err_set_current( NULL ); */
	if( err->msg  &&  err->free_msg )
	 {
		free( err->msg );
		err->msg = NULL;
	 }
}


void
drmaa_err_clear( drmaa_err_ctx_t *err )
{
	/* drmaa_err_set_current( err ); */
	err->rc = DRMAA_ERRNO_SUCCESS;
	err->n_errors = 0;
}


void
drmaa_err_copy( drmaa_err_ctx_t *dest, const drmaa_err_ctx_t *src )
{
	if( dest->n_errors > 0 )
	 {
		dest->n_errors += src->n_errors;
		return;
	 }
	dest->rc = src->rc;
	dest->n_errors = src->n_errors;
	if( dest->rc == DRMAA_ERRNO_SUCCESS )
		return;
	if( dest->msgsize > 0  &&  src->msgsize == 0 )
		dest->msg[0] = '\0';
	else
		strlcpy( dest->msg, src->msg, dest->msgsize );
}


void
drmaa_err_perror( drmaa_err_ctx_t *err, int errno_code )
{
	/* drmaa_err_set_current( err ); */
	if( ++err->n_errors > 1 )
		return;
	if( !errno_code )
		errno_code = errno;
	switch( errno_code )
	 {
		case ENOMEM:     err->rc = DRMAA_ERRNO_NO_MEMORY;  break;
		case ETIMEDOUT:  err->rc = DRMAA_ERRNO_EXIT_TIMEOUT;  break;
		default:         err->rc = DRMAA_ERRNO_INTERNAL_ERROR;  break;
	 }

	if( err->msg != NULL )
	 {
#		ifdef HAVE_DECL_STRERROR_R
#			ifdef _GNU_SOURCE
				char *buf = strerror_r( errno_code, err->msg, err->msgsize );
				if( buf != err->msg )
					strlcpy( err->msg, buf, err->msgsize );
#			else
				strerror_r( errno_code, err->msg, err->msgsize );
#			endif /* !_GNU_SOURCE */
#		else /* assume strerror is thread safe -- returned string is constant */
			strlcpy( err->msg, strerror(errno_code), err->msgsize );
#		endif /* ! HAVE_STRERROR_R */
	 }

	LOG_STACKTRACE();
	DEBUG(( "<- drmaa_err_perror(); errno=%d, rc=%d, msg=%s",
				errno_code, err->rc, err->msg ));
}


void
drmaa_err_drmaa_error(
		drmaa_err_ctx_t *err, int error_code,
		const char *message
		)
{
	/* drmaa_err_set_current( err ); */
	if( error_code == DRMAA_ERRNO_SUCCESS )
		return;
	if( ++err->n_errors > 1 )
		return;
	err->rc = error_code;
	if( message == NULL )
		message = drmaa_strerror( err->rc );
	if( err->msg != NULL )
		snprintf( err->msg, err->msgsize,
			"drmaa: %s", message );
	LOG_STACKTRACE();
	DEBUG(( "<- drmaa_err_drmaa_error(); rc=%d, msg=%s", err->rc, err->msg ));
}


void
drmaa_set_verbosity_level( drmaa_verbose_level_t level )
{
	drmaa_verbose_level = level;
}

void
drmaa_set_logging_output( FILE *file )
{
	drmaa_logging_output = file;
}


void
drmaa_color( char *output, size_t len, int n )
{
	uint32_t k = n;
	k = hashword( &k, 1, 0 );
	k %= 12;
	snprintf( output, len, "\033[0;%d;%dm", k>=6, 31+k%6 );
}


void
drmaa_log( const char *fmt, ... )
{
	long int seconds, microseconds;
	const bool color = false;
	va_list args;
	char *line = NULL, *linefmt = NULL;
	int tid;

	if( drmaa_logging_output == NULL )
		drmaa_logging_output = stderr;

	 {
		struct timeval tv;
		gettimeofday( &tv, NULL );
		seconds = tv.tv_sec;
		microseconds = tv.tv_usec;
	 }

	tid = drmaa_thread_id();
	linefmt = (char*)malloc(
			strlen("drmaa @COLORBEG012345678COLOREND [1234567890]: ")
			+strlen(fmt)+2 );
	if( linefmt == NULL )
	 {
		perror( "malloc" );
		return;
	 }
	if( color )
	 {
		char colorbeg[16];
		drmaa_color( colorbeg, sizeof(colorbeg), tid );
		sprintf( linefmt, "drmaa @%s%04x\033[0m [%ld.%02ld]: %s\n",
				colorbeg, tid, seconds, microseconds/10000, fmt );
		/*sprintf( linefmt, "drmaa tid=\033[%02d;%02dm%d\033[00m: %s\n",
			(tid>>3)&1, 30+(tid&7), tid, fmt ); */
	 }
	else
		sprintf( linefmt, "drmaa @%04x [%ld.%02ld]: %s\n",
				tid, seconds, microseconds/10000, fmt );
		/* sprintf( linefmt, "drmaa tid=%d: %s\n", tid, fmt ); */
	va_start( args, fmt );
	if( -1 == vasprintf( &line, linefmt, args ) )
	 { free(linefmt);  return; }
	va_end( args );

	fwrite( line, 1, strlen(line), drmaa_logging_output );
	fflush( drmaa_logging_output );

	free( linefmt );
	free( line );
}


#if defined(__GNUC__)
#define MAX_STACKTRACE 128
void
drmaa_log_stacktrace(void)
{
	void *ptr_buf[ MAX_STACKTRACE ];
	const char **symbols = NULL;
	int i, n = 0;
	n = backtrace( ptr_buf, MAX_STACKTRACE );
	symbols = (const char**)backtrace_symbols( ptr_buf, n );
	if( symbols != NULL )
	 {
		drmaa_log( "Stacktrace (most recent call last):" );
		/* without drmaa_log_stacktrace() frame */
		for( i = n-1;  i >= 1;  i-- )
			drmaa_log( "  %s", symbols[i] );
		free( symbols );
	 }
}
#endif


const char *
drmaa_strerror( int drmaa_errno )
{
	switch( drmaa_errno )
	 {
		case DRMAA_ERRNO_SUCCESS:
			return "Success.";
		case DRMAA_ERRNO_INTERNAL_ERROR:
			return "Unexpected or internal DRMAA error.";
		case DRMAA_ERRNO_DRM_COMMUNICATION_FAILURE:
			return "Could not contact DRM system for this request.";
		case DRMAA_ERRNO_AUTH_FAILURE:
			return "Authorization failure.";
		case DRMAA_ERRNO_INVALID_ARGUMENT:
			return "Invalid argument value.";
		case DRMAA_ERRNO_NO_ACTIVE_SESSION:
			return "No active DRMAA session.";
		case DRMAA_ERRNO_NO_MEMORY:
			return "Not enough memory.";
		case DRMAA_ERRNO_INVALID_CONTACT_STRING:
			return "Invalid contact string.";
		case DRMAA_ERRNO_DEFAULT_CONTACT_STRING_ERROR:
			return "Can not determine default contact to DRM system.";
		case DRMAA_ERRNO_NO_DEFAULT_CONTACT_STRING_SELECTED:
			return "Contact to DRM must be set explicitly "
				"because there is no default.";
		case DRMAA_ERRNO_DRMS_INIT_FAILED:
			return "Unable to initialize DRM system.";
		case DRMAA_ERRNO_ALREADY_ACTIVE_SESSION:
			return "DRMAA session already exist.";
		case DRMAA_ERRNO_DRMS_EXIT_ERROR:
			return "Disengagement from the DRM system failed.";
		case DRMAA_ERRNO_INVALID_ATTRIBUTE_FORMAT:
			return "Invalid format of job attribute.";
		case DRMAA_ERRNO_INVALID_ATTRIBUTE_VALUE:
			return "Invalid value of job attribute.";
		case DRMAA_ERRNO_CONFLICTING_ATTRIBUTE_VALUES:
			return "Value of attribute conflicts with other attribute value.";
		case DRMAA_ERRNO_TRY_LATER:
			return "DRM system is overloaded.  Try again later.";
		case DRMAA_ERRNO_DENIED_BY_DRM:
			return "DRM rejected job due to its configuration or job attributes.";
		case DRMAA_ERRNO_INVALID_JOB:
			return "Job does not exist in DRMs queue.";
		case DRMAA_ERRNO_RESUME_INCONSISTENT_STATE:
			return "Can not resume job (not in valid state).";
		case DRMAA_ERRNO_SUSPEND_INCONSISTENT_STATE:
			return "Can not suspend job (not in valid state).";
		case DRMAA_ERRNO_HOLD_INCONSISTENT_STATE:
			return "Can not hold job (not in valid state).";
		case DRMAA_ERRNO_RELEASE_INCONSISTENT_STATE:
			return "Can not release job (not in valid state).";
		case DRMAA_ERRNO_EXIT_TIMEOUT:
			return "Waiting for job to terminate finished due to time-out.";
		case DRMAA_ERRNO_NO_RUSAGE:
			return "Job finished but resource usage information "
				"and/or termination status could not be provided.";
		case DRMAA_ERRNO_NO_MORE_ELEMENTS:
			return "Vector have no more elements.";
		default:
			return "?? unknown DRMAA error code ??";
	 }
}

