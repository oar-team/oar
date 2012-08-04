/* $Id: drmaa_impl.h 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file drmaa_impl.h
 * Function which should be defined by DRMAA implementation.
 */
#ifndef __DRMAA__DRMAA_IMPL_H
#define __DRMAA__DRMAA_IMPL_H

#include <drmaa_utils/drmaa_base.h>

const drmaa_implementation_info_t *
drmaa_get_implementation_info( drmaa_err_ctx_t *err );

void
drmaa_session_create_impl( drmaa_session_t *session, drmaa_err_ctx_t *err );

void
drmaa_session_destroy_impl( drmaa_session_t *session, drmaa_err_ctx_t *err );

/**
 * Submits job.  In addtion do drmaa_run_job() it has @a bulk_no which
 * should be -1 for submiting single job or bulk job index for bulk jobs.
 * @see drmaa_run_job
 * @see drmaa_run_bulk_jobs
 */
void
drmaa_run_job_impl(
		char *job_id, size_t job_id_len,
		const drmaa_job_template_t *jt, int bulk_no,
		drmaa_err_ctx_t *err
		);

void
drmaa_control_impl(
		drmaa_session_t *session, drmaa_job_t *job, int action,
		drmaa_err_ctx_t *err
		);

void
drmaa_job_update_status( drmaa_job_t *job, drmaa_err_ctx_t *err );

void
drmaa_update_all_jobs_status( drmaa_session_t *session, drmaa_err_ctx_t *err );

const drmaa_attrib_info_t *
attr_by_drm_name(
		drmaa_session_t *c, const char *drm_name, drmaa_err_ctx_t *err );

#endif /* __DRMAA__DRMAA_IMPL_H */

