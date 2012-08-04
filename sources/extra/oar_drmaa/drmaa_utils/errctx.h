/* $Id: errctx.h 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file errctx.h
 * Error context structure.
 */

#ifndef __DRMAA__ERRCTX_H
#define __DRMAA__ERRCTX_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/compat.h>

#define OK(err)  ( err->rc == DRMAA_ERRNO_SUCCESS )
/** Error context structure. */
typedef struct drmaa_err_ctx_s drmaa_err_ctx_t;
/** Error context structure. */
struct drmaa_err_ctx_s {
	int rc;          /**< DRMAA error code. */
	char *msg;       /**< Buffer for error message. */
	size_t msgsize;  /**< Size of \a msg buffer. */
  bool free_msg;   /**< Whether drmaa_err_destroy()
										    should free() \a msg buffer. */
	int n_errors;    /**< Number of raised errors.
	  Only first raised error sets \a rc and fill \a msg buffer.
		Later errors only increases \a n_errors member. */
};

#endif /* __DRMAA__ERRCTX_H */

