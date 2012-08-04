/* $Id: thread.h 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file thread.h
 *
 * Thread and synchronization primitives.
 */

#ifndef __DRMAA__THREAD_H
#define __DRMAA__THREAD_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/errctx.h>

#include <pthread.h>
#include <time.h>

/**
 * @defgroup recursive_mutex  Recursive mutexes implementation.
 * It uses recursive mutexes if supplied by POSIX threads library
 * or implements it over plain mutexes.
 */
/* @{ */

#if defined(PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP)
#	define HAVE_RECURSIVE_MUTEXES 1
#else
#	define HAVE_RECURSIVE_MUTEXES 0
#endif /* ! PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP */


#if HAVE_RECURSIVE_MUTEXES

	typedef pthread_mutex_t drmaa_mutex_t;
#	define DRMAA_MUTEX_INITIALIZER  PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP
	typedef pthread_cond_t  drmaa_cond_t;
#	define DRMAA_COND_INITIALIZER  PTHREAD_COND_INITAILIZER

#else /* !HAVE_RECURSIVE_MUTEXES */

	/**
	 * Recursive mutex build on top of non-recursive mutex
	 * (used when recursive mutexes are not provided by POSIX
	 * thread library).
	 */
	typedef struct drmaa_mutex_s {
		pthread_mutex_t mutex; /**< Non-recursive mutex. */
		pthread_t       owner; /**< Thread which owns critical section. */
		int             acquired; /**< How many times
			owning thread acquired this mutex. */
	} drmaa_mutex_t;
#	define DRMAA_MUTEX_INITIALIZER  { PTHREAD_MUTEX_INITIALIZER, (pthread_t)-1, 0 }
	typedef pthread_cond_t  drmaa_cond_t;
#	define DRMAA_COND_INITIALIZER  PTHREAD_COND_INITAILIZER

#endif /* ! HAVE_RECURSIVE_MUTEXES */


/** pthread_mutex_init wrapper.  Initializes recursive mutex. */
void drmaa_mutex_init     ( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err );
void drmaa_mutex_destroy  ( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err );
void drmaa_mutex_lock     ( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err );
void drmaa_mutex_unlock   ( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err );
bool drmaa_mutex_trylock  ( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err );

void drmaa_cond_init      ( drmaa_cond_t *cond, drmaa_err_ctx_t *err );
void drmaa_cond_destroy   ( drmaa_cond_t *cond, drmaa_err_ctx_t *err );
void drmaa_cond_signal    ( drmaa_cond_t *cond, drmaa_err_ctx_t *err );
void drmaa_cond_broadcast ( drmaa_cond_t *cond, drmaa_err_ctx_t *err );
void drmaa_cond_wait      ( drmaa_cond_t *cond, drmaa_mutex_t *mutex,
		drmaa_err_ctx_t *err );
bool drmaa_cond_timedwait ( drmaa_cond_t *cond, drmaa_mutex_t *mutex,
		const struct timespec *abstime, drmaa_err_ctx_t *err );
/* @} */


/**
 * @defgroup thread  Wrapper around POSIX thread functions.
 */
/* @{ */
typedef pthread_t drmaa_thread_t;
/** pthread_create wrapper */
void drmaa_thread_create( drmaa_thread_t *thread, void* (*func)(void*), void *arg, drmaa_err_ctx_t *err );
#define drmaa_thread_self    pthraed_self
#define drmaa_thraed_equal   pthread_equal
#define drmaa_thread_exit    pthread_exit
/** pthread_join wrapper */
void drmaa_thread_join( drmaa_thread_t th, void *thread_return, drmaa_err_ctx_t *err );
/** pthread_detach wrapper */
void drmaa_thread_detach( drmaa_thread_t th, drmaa_err_ctx_t *err );
/* void drmaa_thread_cancel( drmaa_thread_t th, drmaa_err_ctx_t *err ); */
/* @} */


/** Returns thread identifier. */
int drmaa_thread_id(void);

#endif /* __DRMAA__THREAD_H */

