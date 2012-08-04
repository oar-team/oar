/* $Id: thread.c 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file thread.c
 * Implementation of recursive mutexes for systems without native support
 * for it.
 */


#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/thread.h>
#include <drmaa_utils/error.h>
#include <assert.h>
#include <errno.h>
#include <unistd.h>

#ifdef HAVE_GETTID
#include <sys/types.h>
#include <sys/syscall.h>
pid_t gettid(void)
{
	return (pid_t)syscall( __NR_gettid );
}
#endif

#ifndef lint
static char rcsid[]
#	ifdef __GNUC__
		__attribute__ ((unused))
#	endif
	= "$Id: thread.c 533 2007-12-22 15:25:42Z lukasz $";
#endif


void
drmaa_thread_create( drmaa_thread_t *thread, void* (*func)(void*), void *arg,
		drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_create( thread, NULL, func, arg );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_thread_join(
		drmaa_thread_t th, void *thread_return, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_join( th, thread_return );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_thread_detach(
		drmaa_thread_t th, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_detach( th );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}


#if HAVE_RECURSIVE_MUTEXES

void
drmaa_mutex_init( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	pthread_mutexattr_t attr;
	do {
		errno_ = pthread_mutexattr_init( &attr );
		if( errno_ )  break;
		errno_ = pthread_mutexattr_settype( &attr, PTHREAD_MUTEX_RECURSIVE_NP );
		if( errno_ )  break;
		errno_ = pthread_mutex_init( mutex, &attr );
		if( errno_ )  break;
		errno_ = pthread_mutexattr_destroy( &attr );
	} while( false );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_mutex_destroy( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_mutex_destroy( mutex );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_mutex_lock( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_mutex_lock( mutex );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_mutex_unlock( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_mutex_unlock( mutex );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

bool
drmaa_mutex_trylock( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_mutex_trylock( mutex );
	switch( errno_ )
	 {
		case 0:
			return true;
		case EBUSY:
			return false;
		default:
			RAISE_ERRNO_1( errno_ );
			return false;
	 }
}

void
drmaa_cond_init( drmaa_cond_t *cond, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_cond_init( cond, NULL );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_cond_destroy( drmaa_cond_t *cond, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_cond_destroy( cond );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_cond_signal( drmaa_cond_t *cond, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_cond_signal( cond );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_cond_broadcast( drmaa_cond_t *cond, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_cond_broadcast( cond );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_cond_wait( drmaa_cond_t *cond, drmaa_mutex_t *mutex, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_cond_wait( cond, mutex );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

bool
drmaa_cond_timedwait( drmaa_cond_t *cond, drmaa_mutex_t *mutex,
		const struct timespec *abstime, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_cond_timedwait( cond, mutex, abstime );
	switch( errno_ )
	 {
		case 0:
			return true;
		case ETIMEDOUT:
			return false;
		default:
			RAISE_ERRNO_1( errno_ );
			return false;
	 }
}

#else /* ! HAVE_RECURSIVE_MUTEXES */

void
drmaa_mutex_init( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	mutex->owner = (pthread_t)-1;
	mutex->acquired = 0;
	errno_ = pthread_mutex_init( &mutex->mutex, NULL );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_mutex_destroy( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_mutex_destroy( &mutex->mutex );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_mutex_lock( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err )
{
	/* Note: The order of checks is significant. */
	if( mutex->acquired  &&  pthread_equal( mutex->owner, pthread_self() ) )
		mutex->acquired ++;
	else
	 {
		int errno_ = 0;
		errno_ = pthread_mutex_lock( &mutex->mutex );
		if( errno_ == 0 )
		 {
			mutex->owner    = pthread_self();
			mutex->acquired = 1;
		 }
		else
			RAISE_ERRNO_1( errno_ );
	 }
}

void
drmaa_mutex_unlock( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err )
{
	assert( mutex->acquired  &&  pthread_equal( mutex->owner, pthread_self() ) );
	if( -- (mutex->acquired) == 0 )
	 {
		int errno_ = 0;
		errno_ = pthread_mutex_unlock( &mutex->mutex );
		if( errno_ )
			RAISE_ERRNO_1( errno_ );
	 }
}

bool
drmaa_mutex_trylock( drmaa_mutex_t *mutex, drmaa_err_ctx_t *err )
{
	if( mutex->acquired  &&  pthread_equal( mutex->owner, pthread_self() ) )
	 {
		mutex->acquired ++;
		return true;
	 }
	else
	 {
		int errno_ = 0;
		errno_ = pthread_mutex_trylock( &mutex->mutex );
		switch( errno_ )
		 {
			case 0:
				mutex->owner    = pthread_self();
				mutex->acquired = 1;
				return true;
			case ETIMEDOUT:
				return false;
			default:
				RAISE_ERRNO_1( errno_ );
				return false;
		 }
	 }
}

void
drmaa_cond_init( drmaa_cond_t *cond, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_cond_init( cond, NULL );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_cond_destroy( drmaa_cond_t *cond, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_cond_destroy( cond );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_cond_signal( drmaa_cond_t *cond, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_cond_signal( cond );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_cond_broadcast( drmaa_cond_t *cond, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	errno_ = pthread_cond_broadcast( cond );
	if( errno_ )
		RAISE_ERRNO_1( errno_ );
}

void
drmaa_cond_wait( drmaa_cond_t *cond, drmaa_mutex_t *mutex, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	int acquired_save = mutex->acquired;
	assert( mutex->acquired  &&  pthread_equal( mutex->owner, pthread_self() ) );
	errno_ = pthread_cond_wait( cond, &mutex->mutex );
	if( errno_ == 0 )
	 {
		mutex->owner = pthread_self();
		mutex->acquired = acquired_save;
	 }
	else
		RAISE_ERRNO_1( errno_ );
}

bool
drmaa_cond_timedwait( drmaa_cond_t *cond, drmaa_mutex_t *mutex,
		const struct timespec *abstime, drmaa_err_ctx_t *err )
{
	int errno_ = 0;
	int acquired_save = mutex->acquired;
	assert( mutex->acquired  &&  pthread_equal( mutex->owner, pthread_self() ) );
	errno_ = pthread_cond_timedwait( cond, &mutex->mutex, abstime );
	switch( errno_ )
	 {
		case 0:
			mutex->owner = pthread_self();
			mutex->acquired = acquired_save;
			return true;
		case ETIMEDOUT:
			mutex->owner = pthread_self();
			mutex->acquired = acquired_save;
			return false;
		default:
			RAISE_ERRNO_1( errno_ );
			return false;
	 }
}

#endif /* ! HAVE_RECURSIVE_MUTEXES */



int
drmaa_thread_id(void)
{
#if HAVE_GETTID
	/*
	 * On Linux 2.6 (with NPTL) getpid() returns
	 * same value for all threads in single process.
	 */
	return (int)gettid();
#else
	return (int)getpid();
#endif
}

