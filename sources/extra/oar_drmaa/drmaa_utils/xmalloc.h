/* $Id: xmalloc.h 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file xmalloc.h
 * Memory allocation/deallocation routines.
 */

#ifndef __DRMAA__XMALLOC_H
#define __DRMAA__XMALLOC_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/compat.h>
#include <drmaa_utils/errctx.h>

/**
 * @defgroup xmalloc  Memory allocation/deallocation routines.
 */
/* @{ */

/**
 * Allocates <code> sizeof(type) </code> bytes.  Address of block is stored
 * in @a p.  Upon failure DRMAA_ERRNO_NO_MEMORY is raised and @a p is NULL.
 */
#define DRMAA_MALLOC( p, type ) \
	drmaa_malloc( (void**)(void*)&(p), sizeof(type), err )

/**
 * Allocates <code> n * sizeof(type) </code> bytes of memory and stores
 * address in @a p.  Allocated block is filled with zeros.  Upon failure
 * error DRMAA_ERRNO_NO_MEMORY is raised.
 * @c NULL is assigned to @a p on error or when <code> n == 0 </code>.
 */
#define DRMAA_CALLOC( p, n, type ) \
	drmaa_calloc( (void**)(void*)&(p), (n), sizeof(type), err )

/**
 *
 */
#define DRMAA_REALLOC( p, n, type ) \
	drmaa_realloc( (void**)(void*)&(p), (n)*sizeof(type), err )

/**
 * Fress previously allocated memory pointed by @a p.
 * When <code> p == NULL </code> it does nothing.
 */
#define DRMAA_FREE( p ) \
	drmaa_free( p )

void drmaa_malloc( void **p, size_t size, drmaa_err_ctx_t *err );
void drmaa_calloc( void **p, size_t n, size_t size, drmaa_err_ctx_t *err );
void drmaa_realloc( void **p, size_t size, drmaa_err_ctx_t *err );
void drmaa_free( void *p );

/* @} */

#endif /* __DRMAA__XMALLOC_H */

