/* $Id: common.h 533 2007-12-22 15:25:42Z lukasz $ */
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

#ifndef __DRMAA__COMMON_H
#define __DRMAA__COMMON_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/drmaa.h>
#include <drmaa_utils/compat.h>
#include <drmaa_utils/error.h>
#include <drmaa_utils/errctx.h>
#include <drmaa_utils/thread.h>
#include <drmaa_utils/xmalloc.h>

typedef struct drmaa_session_s      drmaa_session_t;
typedef struct drmaa_job_set_s      drmaa_job_set_t;
typedef struct drmaa_job_s          drmaa_job_t;
typedef struct drmaa_submit_ctx_s   drmaa_submit_ctx_t;
typedef struct drmaa_attrib_info_s  drmaa_attrib_info_t;

typedef struct drmaa_conf_option_s  drmaa_conf_option_t;
typedef struct drmaa_conf_dict_s    drmaa_conf_dict_t;

typedef struct drmaa_implementation_info_s drmaa_implementation_info_t;

#endif /* __DRMAA__COMMON_H */

