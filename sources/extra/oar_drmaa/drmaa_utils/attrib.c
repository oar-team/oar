/* $Id: attrib.c 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file attrib.c
 * DRMAA attributes.
 */

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <string.h>
#include <drmaa_utils/attrib.h>
#include <drmaa_utils/drmaa_base.h>
#include <drmaa_utils/util.h>
#include <assert.h>

#ifndef lint
static char rcsid[]
#	ifdef __GNUC__
		__attribute__ ((unused))
#	endif
	= "$Id: attrib.c 533 2007-12-22 15:25:42Z lukasz $";
#endif

struct drmaa_attrib { const char *name; int code; };

extern const struct drmaa_attrib *
drmaa_attrib_lookup( const char *str, unsigned int len );

const drmaa_attrib_info_t *
attr_by_drmaa_name( drmaa_session_t *c, const char *drmaa_name,
	drmaa_err_ctx_t *err )
{
	const struct drmaa_attrib *attr = NULL;
	attr = drmaa_attrib_lookup( drmaa_name, strlen(drmaa_name) );
	if( attr == NULL )
	 {
		RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ARGUMENT );
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


/* unsigned int __drmaa_n_attrs = N_DRMAA_ATTRIBS; */

void
drmaa_register_attribute(
	drmaa_session_t *c,
	int code,
	const char *drmaa_name,
	const char *drm_name,
	unsigned flags,
	drmaa_err_ctx_t *err
	)
{
	if( !OK(err) )
		return;

	if( ! (code < c->attributes_capacity) )
	 {
		int new_capacity = c->attributes_capacity;
		while( new_capacity <= code )
		 {
			if( new_capacity == 0 )
				new_capacity = 16;
			else
				new_capacity *= 2;
		 }
		DRMAA_REALLOC( c->attributes, new_capacity, drmaa_attrib_info_t );
		if( OK(err) )
		 {
			int i;
			for( i = c->attributes_capacity;  i < new_capacity;  i++ )
			 {
				drmaa_attrib_info_t *attr = & c->attributes[ i ];
				attr->code = i;
				attr->drmaa_name = NULL;
				attr->drm_name = NULL;
				attr->flags = 0;
			 }
			c->attributes_capacity = new_capacity;
		 }
	 }

	if( OK(err) )
	 {
		drmaa_attrib_info_t *attr = & c->attributes[ code ];
		if( drmaa_name )
		 {
			DRMAA_FREE( attr->drmaa_name );
			attr->drmaa_name = drmaa_strdup( drmaa_name, err );
		 }
		if( drm_name )
		 {
			DRMAA_FREE( attr->drm_name );
			attr->drm_name = drmaa_strdup( drm_name, err );
		 }
		attr->flags |= flags;
	 }

	if( OK(err) && code >= c->n_attributes )
		c->n_attributes = code+1;
}


void
drmaa_delete_attributes_list( drmaa_session_t *session, drmaa_err_ctx_t *err )
{
	drmaa_attrib_info_t *i;
	drmaa_attrib_info_t *attributes = session->attributes;
	drmaa_attrib_info_t *end = attributes + session->n_attributes;

	if( attributes == NULL )
		return;

	for( i = attributes;  i != end;  i++ )
	 {
		DRMAA_FREE( i->drmaa_name );
		DRMAA_FREE( i->drm_name );
	 }
	DRMAA_FREE( attributes );
}


void
drmaa_register_drmaa_attributes( drmaa_session_t *c, drmaa_err_ctx_t *err )
{
	int i;
	for( i = 0;  OK(err) && i < N_DRMAA_ATTRIBS;  i++ )
	 {
		const drmaa_attrib_info_t *attr = & drmaa_attr_table[ i ];
		assert( attr->code == i );
		drmaa_register_attribute( c, i,
				attr->drmaa_name, attr->drm_name, attr->flags, err );
	 }
}


const drmaa_attrib_info_t drmaa_attr_table[] = {
	/* DRMAA 1.0 attributes: */
 { ATTR_JOB_NAME,            "drmaa_job_name",        NULL, ATTR_F_STR   },
 { ATTR_JOB_PATH,            "drmaa_remote_command",  NULL, ATTR_F_PATH  },
 { ATTR_ARGV,                "drmaa_v_argv",          NULL, ATTR_F_VECTOR | ATTR_F_STR  },
 { ATTR_ENV,                 "drmaa_v_env",           NULL, ATTR_F_VECTOR | ATTR_F_STR  },
 { ATTR_INPUT_PATH,          "drmaa_input_path",      NULL, ATTR_F_PATH  },
 { ATTR_OUTPUT_PATH,         "drmaa_output_path",     NULL, ATTR_F_PATH  },
 { ATTR_ERROR_PATH,          "drmaa_error_path",      NULL, ATTR_F_PATH  },
 { ATTR_JOIN_FILES,          "drmaa_join_files",      NULL, ATTR_F_BOOL  },
 { ATTR_TRANSFER_FILES,      "drmaa_transfer_files",  NULL, ATTR_F_BOOL  },
 { ATTR_JOB_WORKING_DIR,     "drmaa_wd",              NULL, ATTR_F_PATH  },
 { ATTR_EMAIL,               "drmaa_v_email",         NULL, ATTR_F_VECTOR | ATTR_F_STR },
 { ATTR_BLOCK_EMAIL,         "drmaa_block_email",     NULL, ATTR_F_BOOL  },
 { ATTR_START_TIME,          "drmaa_start_time",      NULL, ATTR_F_TIME  },
 { ATTR_JOB_SUBMIT_STATE,    "drmaa_js_state",        NULL, ATTR_F_STR   },
 { ATTR_HARD_CPU_TIME_LIMIT, "drmaa_duration_hlimit", NULL, ATTR_F_TIMED },
 { ATTR_SOFT_CPU_TIME_LIMIT, "drmaa_duration_slimit", NULL, ATTR_F_TIMED },
 { ATTR_HARD_WCT_LIMIT,      "drmaa_wct_hlimit",      NULL, ATTR_F_TIMED },
 { ATTR_SOFT_WCT_LIMIT,      "drmaa_wct_slimit",      NULL, ATTR_F_TIMED },
 { ATTR_DEADLINE_TIME,       "drmaa_deadline_time",   NULL, ATTR_F_TIME  },
 { ATTR_JOB_CATEGORY,        "drmaa_job_category",    NULL, ATTR_F_STR   },
 { ATTR_NATIVE,              "drmaa_native_specification", NULL, ATTR_F_STR },

 { -1, NULL, NULL, 0 } /* sentinel */
};


