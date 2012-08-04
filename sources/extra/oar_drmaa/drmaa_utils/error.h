/* $Id: error.h 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file error.h
 * Error reporting and logging functions.
 */

#ifndef __DRMAA__ERROR_H
#define __DRMAA__ERROR_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/drmaa.h>
#include <drmaa_utils/errctx.h>

void
drmaa_err_init( drmaa_err_ctx_t *err, char *error_diagnosis, size_t error_diag_len );

int
drmaa_err_create( drmaa_err_ctx_t *err, drmaa_err_ctx_t *parent_err );

void
drmaa_err_destroy( drmaa_err_ctx_t *err );

void
drmaa_err_clear( drmaa_err_ctx_t *err );

void
drmaa_err_copy( drmaa_err_ctx_t *dest, const drmaa_err_ctx_t *src );

/**
 * Stores error message of last system call / libc function.
 * @param errno_code System error code.  If 0 value is taken from @c errno.
 */
void
drmaa_err_perror( drmaa_err_ctx_t *err, int errno_code );

void
drmaa_err_drmaa_error( drmaa_err_ctx_t *err, int error_code,
		const char *message );

#define RAISE_ERRNO()   RAISE_ERRNO_1( 0 )
#define RAISE_ERRNO_1( errno_code ) \
	drmaa_err_perror( err, errno_code )

#define RAISE_DRMAA_1( errcode ) \
	drmaa_err_drmaa_error( err, errcode, NULL )
#define RAISE_DRMAA_2( errcode, message ) \
	drmaa_err_drmaa_error( err, errcode, message )

void drmaa_log( const char *fmt, ... )
	__attribute__(( format( printf, 1, 2 ) ));

void drmaa_log_stacktrace(void);

extern drmaa_verbose_level_t drmaa_verbose_level;

#if DRMAA_DEBUG
# define DEBUG( args ) \
	do{ if( drmaa_verbose_level <= DRMAA_LOG_DEBUG_1 ) drmaa_log args ; }while(0)
# define DEBUG_2( args ) \
	do{ if( drmaa_verbose_level <= DRMAA_LOG_DEBUG_2 ) drmaa_log args ; }while(0)
#	define LOG_STACKTRACE()  drmaa_log_stacktrace()
#else
#	define DEBUG( args )     do{ /* nothing */ }while(0)
#	define DEBUG_2( args )   do{ /* nothing */ }while(0)
#	define LOG_STACKTRACE()  do{ /* nothing */ }while(0)
#endif


#endif /* __DRMAA__ERROR_H */

