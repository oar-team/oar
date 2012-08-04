/* $Id: conf.h 533 2007-12-22 15:25:42Z lukasz $ */
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

#ifndef __DRMAA__CONF_H
#define __DRMAA__CONF_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/common.h>

typedef enum {
	DRMAA_CONF_INTEGER,
	DRMAA_CONF_STRING,
	DRMAA_CONF_DICT
} drmaa_conf_type_t;

struct drmaa_conf_option_s {
	drmaa_conf_type_t type;
	union {
		int integer;
		char *string;
		drmaa_conf_dict_t *dict;
	} val;
};


/**
 * Read configuration.
 */
drmaa_conf_dict_t *
drmaa_conf_read(
		drmaa_conf_dict_t *configuration,
		const char *filename, bool must_exist,
		const char *content, size_t content_len,
		drmaa_err_ctx_t *err
		);


drmaa_conf_dict_t *
drmaa_conf_load( const char *filename, drmaa_err_ctx_t *err );

drmaa_conf_option_t *
drmaa_conf_option_create(
		drmaa_conf_type_t type,
		void *value,
		drmaa_err_ctx_t *err
		);

void
drmaa_conf_option_destroy( drmaa_conf_option_t *option );

drmaa_conf_option_t *
drmaa_conf_option_merge(
		drmaa_conf_option_t *lhs, drmaa_conf_option_t *rhs, drmaa_err_ctx_t *err
		);

void
drmaa_conf_option_dump( drmaa_conf_option_t *option );



drmaa_conf_dict_t *
drmaa_conf_dict_create( drmaa_err_ctx_t *err );

void
drmaa_conf_dict_destroy( drmaa_conf_dict_t *dict );

drmaa_conf_option_t *
drmaa_conf_dict_get( drmaa_conf_dict_t *dict, const char *key, drmaa_err_ctx_t *err );

void
drmaa_conf_dict_set(
		drmaa_conf_dict_t *dict, const char *key, drmaa_conf_option_t *value,
		drmaa_err_ctx_t *err
		);

drmaa_conf_dict_t *
drmaa_conf_dict_merge(
		drmaa_conf_dict_t *lhs, drmaa_conf_dict_t *rhs,
		drmaa_err_ctx_t *err
		);

void
drmaa_conf_dict_dump( drmaa_conf_dict_t *dict );

#endif /* __DRMAA__CONF_H */

