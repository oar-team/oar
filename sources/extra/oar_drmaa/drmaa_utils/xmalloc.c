/* $Id: xmalloc.c 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file xmalloc.c
 * Memory allocation/deallocation routines.
 */

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include <drmaa_utils/xmalloc.h>
#include <drmaa_utils/compat.h>
#include <drmaa_utils/error.h>

#ifndef SIZE_T_MAX
#  define SIZE_T_MAX ((size_t) -1)
#endif

#ifndef lint
static char rcsid[]
#	ifdef __GNUC__
		__attribute__ ((unused))
#	endif
	= "$Id: xmalloc.c 533 2007-12-22 15:25:42Z lukasz $";
#endif


void
drmaa_malloc( void **p, size_t size, drmaa_err_ctx_t *err )
{
	void *ptr = NULL;
	DEBUG_2(( "-> drmaa_malloc(%lu)", (unsigned long)size ));
	if( size )
	 {
		ptr = malloc( size );
		if( ptr )
			memset( ptr, 0, size );
		else
		 {
			errno = ENOMEM;
			RAISE_ERRNO();
		 }
	 }
	*p = ptr;
	DEBUG_2(( "<- drmaa_malloc(); err=%d; ptr=%p", err->rc, *p ));
}


void
drmaa_calloc( void **p, size_t n, size_t size, drmaa_err_ctx_t *err )
{
	void *ptr = NULL;
	DEBUG_2(( "-> drmaa_calloc(%lu,%lu)", (unsigned long)n, (unsigned long)size ));
	if( n && size )
	 {
		if( n <= SIZE_T_MAX / size )
			ptr = calloc( n, size );
		if( !ptr )
		 {
			errno = ENOMEM;
			RAISE_ERRNO();
		 }
	 }
	*p = ptr;
	DEBUG_2(( "<- drmaa_calloc(); err=%d, ptr=%p", err->rc, *p ));
}


void
drmaa_realloc( void **p, size_t size, drmaa_err_ctx_t *err )
{
	void *ptr = *p;

	DEBUG_2(( "-> drmaa_realloc(%p,%lu)", *p, (unsigned long)size ));
	if( size )
	 {
		if( ptr )
			ptr = realloc( ptr, size );
		else
			ptr = malloc( size );

		if( ptr != NULL )
			*p = ptr;
		else
		 {
			errno = ENOMEM;
			RAISE_ERRNO();
		 }
	 }
	else if( ptr != NULL )
	 {
		free( ptr );
		*p = NULL;
	 }

	DEBUG_2(( "<- drmaa_realloc(); err=%d, ptr=%p", err->rc, *p ));
}


void
drmaa_free( void *p )
{
	DEBUG_2(( "-> drmaa_free(%p)", p ));
	if( p )
		free( p );
}

