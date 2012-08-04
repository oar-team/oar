/* $Id: util.h 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file util.h
 * Various functions.
 */

#ifndef __DRMAA__UTIL_H
#define __DRMAA__UTIL_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <time.h>

#include <drmaa_utils/common.h>
#include <drmaa_utils/compat.h>
#include <drmaa_utils/drmaa_base.h>
#include <drmaa_utils/errctx.h>


drmaa_submit_ctx_t *
drmaa_create_submit_ctx(
		const drmaa_job_template_t *jt, int bulk_no,
		drmaa_err_ctx_t *err );

void
drmaa_free_submit_ctx( drmaa_submit_ctx_t *sc );

enum{
	DRMAA_PLACEHOLDER_MASK_HD    = 1<<0,
	DRMAA_PLACEHOLDER_MASK_WD    = 1<<1,
	DRMAA_PLACEHOLDER_MASK_INCR  = 1<<2
};

/**
 * Expands placeholders in DRMAA job attribute value.
 * @param ctx    Submission context.
 * @param input  String to transform.  Should be malloc'ed
 *   and ownership should be passed to callee.
 * @param set    Set of placeholders to expand.  Bitwise
 *   `or' of any of following bits:
 *   - DRMAA_PLACEHOLDER_MASK_HD,
 *   - DRMAA_PLACEHOLDER_MASK_WD,
 *   - DRMAA_PLACEHOLDER_MASK_INCR
 * @param err  Error context.
 * @return Value with expanded placeholders.
 *   Caller is responsible for free()'ing it.
 */
char *
drmaa_expand_placeholders(
		drmaa_submit_ctx_t *ctx, char *input, unsigned set,
		drmaa_err_ctx_t *err );

/**
 * Return textual representation of action
 * - argument of drmaa_control().
 */
const char *drmaa_control_to_str( int action );

/**
 * Return textual representation of job status
 * - result of drmaa_job_ps().
 */
const char *drmaa_job_ps_to_str( int ps );

char *drmaa_explode( const char *const *vector, char glue,
		drmaa_err_ctx_t *err );
void drmaa_free_vector( char **vector );
char **drmaa_copy_vector( const char *const * vector, drmaa_err_ctx_t *err );
char *drmaa_replace( char *input, const char *placeholder, const char *value,
	 drmaa_err_ctx_t *err	);

char *drmaa_strdup( const char *s, drmaa_err_ctx_t *err );
char *drmaa_strndup( const char *s, size_t n, drmaa_err_ctx_t *err );

/**
 * Behaves like asprintf function from standard C library
 * except any errors are marked in error context structure.
 */
char *drmaa_asprintf( drmaa_err_ctx_t *err, const char *fmt, ... );

/**
 * Behaves like vasprintf function from standard C library
 * except any errors are marked in error context structure.
 */
char *drmaa_vasprintf( const char *fmt, va_list args, drmaa_err_ctx_t *err );

/** Retrievs current system timestamp. */
void drmaa_get_time( struct timespec *ts, drmaa_err_ctx_t *err );

/** Add delta to timestamp. */
void drmaa_ts_add( struct timespec *a, const struct timespec *b );

/**
 * Compares two timestamps.
 * @return Negative integer when a < b (a represents earlier timestamp),
 *   positive integer when a > b or 0 when timestamps are equal.
 */
int drmaa_ts_cmp( const struct timespec *a, const struct timespec *b );

/**
 * Reads file contents.
 * @param filename  Path to the file.
 * @param must_exist  Controls behaviour when file not exist
 *   (or is not readable).  If set to \c true DRMAA_ERRNO_INTERNAL_ERROR
 *   is raised on such occasion.  If set to \c false only
 *   \a content is set to \c NULL and no error is raised.
 * @param content  Filled with pointer to buffer with file contents
 *   or \c NULL when error is encoureged.  Caller is responsible
 *   for free()'ing it.
 * @param length  Filled with length of \a content buffer.
 * @param err  Error context.
 */
void
drmaa_read_file(
		const char *filename, bool must_exist,
		char **content, size_t *length,
		drmaa_err_ctx_t *err
		);

typedef struct drmaa_rope_s drmaa_rope_t;

drmaa_rope_t *
drmaa_rope_create( drmaa_err_ctx_t *err );

drmaa_rope_t *
drmaa_rope_append( drmaa_rope_t *, const char *string, drmaa_err_ctx_t *err );

drmaa_rope_t *
drmaa_rope_printf( drmaa_rope_t *, drmaa_err_ctx_t *err, const char *fmt, ... );

char *
drmaa_rope_to_string( drmaa_rope_t *, drmaa_err_ctx_t *err );

#endif /* __DRMAA__UTIL_H */
