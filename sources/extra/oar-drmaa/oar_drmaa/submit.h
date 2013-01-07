/* $Id: submit.h 338 2010-09-28 14:48:45Z mamonski $ */
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
 * Adpated for oar from pbs_drmaa/submit.h by august
 */

#ifndef __OAR_DRMAA__SUBMIT_H
#define __OAR_DRMAA__SUBMIT_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/drmaa_util.h>

typedef struct oardrmaa_submit_s oardrmaa_submit_t;

oardrmaa_submit_t * oardrmaa_submit_new( fsd_drmaa_session_t *session, const fsd_template_t *job_template, int bulk_idx );

struct oardrmaa_submit_s {
	void (*destroy)( oardrmaa_submit_t *self );

	char * (*submit)( oardrmaa_submit_t *self );

	void (*eval)( oardrmaa_submit_t *self );

  void (*apply_defaults)( oardrmaa_submit_t *self );
  void (*apply_job_script)( oardrmaa_submit_t *self );
  void (*apply_job_state)( oardrmaa_submit_t *self );
  void (*apply_job_files)( oardrmaa_submit_t *self );
  void (*apply_file_staging)( oardrmaa_submit_t *self );
  void (*apply_job_resources)( oardrmaa_submit_t *self );
  void (*apply_job_environment)( oardrmaa_submit_t *self );
  void (*apply_email_notification)( oardrmaa_submit_t *self );
  void (*apply_job_category)( oardrmaa_submit_t *self );
	void (*apply_native_specification)(oardrmaa_submit_t *self, const char *native_specification );

  void (*set)( oardrmaa_submit_t *self, const char *oar_attr, char *value, unsigned placeholders );

	fsd_drmaa_session_t *session;
	const fsd_template_t *job_template;

  char *script_path; /* job script command with path and args */
  char *workdir;     /* work directory */
  char *walltime;    /* oar walltime */
  char *environment; /* export 'variables environment';  to begin script_path if not null */

	char *destination_queue;
  
  fsd_template_t *oar_job_attributes;
	fsd_expand_drmaa_ph_t *expand_ph;
  /* struct attrl *oar_attribs; */
};

void oardrmaa_submit_apply_native_specification(oardrmaa_submit_t *self, const char *native_specification );

#endif /* __OAR_DRMAA__SUBMIT_H */

