/* $Id: attrib.h 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file attrib.h
 * DRMAA attributes.
 */
#ifndef __DRMAA__ATTRIB_H
#define __DRMAA__ATTRIB_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/compat.h>
#include <drmaa_utils/drmaa.h>
#include <drmaa_utils/common.h>

/**
 * Flags for attributes.
 * Bit 0: scalar/vector attribute, bits 1-2: type,
 * bits 3-4: (string) format.
 */
enum drmaa_attrib_flags {
	ATTR_F_VECTOR  = 1 << 0, /**< Vector attribute. */
	ATTR_F_BOOL    = 1 << 1, /**< Boolean attribute. */
	ATTR_F_INT     = 2 << 1, /**< Integer attribute. */
	ATTR_F_STR     = 3 << 1, /**< String attribute. */
	ATTR_F_PATH    = 1 << 3, /**< Attributes represents path. */
	ATTR_F_TIME    = 2 << 3, /**< Attribute represents timestamp. */
	ATTR_F_TIMED   = 3 << 3, /**< Attribute represents time delta. */
	ATTR_F_TYPE_MASK   =  06,
	ATTR_F_FORMAT_MASK = 030
};

/** Attribute information structure (DRMAA and/or DRM specific). */
struct drmaa_attrib_info_s {
	int         code;        /**< Attribute code. */
	char       *drmaa_name;  /**< DRMAA name (if exist). */
	char       *drm_name;    /**< DRM name (if exist). */
	unsigned    flags;       /**< Attribute flags. \sa drmaa_attrib_flags. */
};

extern const drmaa_attrib_info_t drmaa_attr_table[];

#define drmaa_is_vector( attr )         ( ((attr)->flags & ATTR_F_VECTOR) != 0 )
#define drmaa_is_implemented( attr )    ( ((attr)->flags & ATTR_F_IMPL) != 0 )

const drmaa_attrib_info_t *
attr_by_drmaa_name(
		drmaa_session_t *c, const char *drmaa_name, drmaa_err_ctx_t *err );

void
drmaa_register_attribute(
	drmaa_session_t *session,
	int code,
	const char *drmaa_name,
	const char *drm_name,
	unsigned flags,
	drmaa_err_ctx_t *err
	);

void
drmaa_delete_attributes_list(
		drmaa_session_t *session, drmaa_err_ctx_t *err );

void
drmaa_register_drmaa_attributes(
		drmaa_session_t *session, drmaa_err_ctx_t *err );


/**
 * Attributes codes.
 * Keep it synchronized with @ref drmaa_attr_table.
 */
typedef enum {

	/* DRMAA 1.0 attributes: */
	ATTR_JOB_NAME,
	ATTR_JOB_PATH,
	ATTR_ARGV,
	ATTR_ENV,
	ATTR_INPUT_PATH,
	ATTR_OUTPUT_PATH,
	ATTR_ERROR_PATH,
	ATTR_JOIN_FILES,
	ATTR_TRANSFER_FILES, /* optional */
	ATTR_JOB_WORKING_DIR,
	ATTR_EMAIL,
	ATTR_BLOCK_EMAIL,
	ATTR_START_TIME,
	ATTR_JOB_SUBMIT_STATE,
	ATTR_HARD_CPU_TIME_LIMIT, /* optional */
	ATTR_SOFT_CPU_TIME_LIMIT, /* optional */
	ATTR_HARD_WCT_LIMIT, /* optional */
	ATTR_SOFT_WCT_LIMIT, /* optional */
	ATTR_DEADLINE_TIME, /* optional */
	ATTR_JOB_CATEGORY,
	ATTR_NATIVE,

	/* ... optionaly some extra attribs outside of DRMAA spec: */

	MIN_DRMAA_ATTR = ATTR_JOB_NAME,
	MAX_DRMAA_ATTR = ATTR_NATIVE,
	N_DRMAA_ATTRIBS = MAX_DRMAA_ATTR + 1
} drmaa_attribute_t;

#endif /* __DRMAA__ATTRIB_H */

