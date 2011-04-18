/* $Id: job.h 2 2009-10-12 09:51:22Z mamonski $ */
/*
 *  FedStage DRMAA for PBS Pro
 *  Copyright (C) 2006-2009  FedStage Systems
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

/*
 * Adapted from pbs_drmaa/job.h
 */


#ifndef __OAR_DRMAA__JOB_H
#define __OAR_DRMAA__JOB_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/job.h>

typedef struct oardrmaa_job_s oardrmaa_job_t;

/* Do not depend on <pbs_ifl.h> */
struct batch_status;

fsd_job_t *
oardrmaa_job_new( char *job_id );

struct oardrmaa_job_s {
	fsd_job_t super;

	void (*
	update)( fsd_job_t *self, struct batch_status *status );
};

void
oardrmaa_job_on_missing_standard( fsd_job_t *self );

#endif /* __OAR_DRMAA__JOB_H */

