/* $Id: pbs_attrib.h 256 2010-08-10 16:31:35Z mamonski $ */
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
 * Adapted from pbs_drmaa/pbs_attrib.h
 */

#ifndef __OAR_DRMAA__OAR_ATTRIB_H
#define __OAR_DRMAA__OAR_ATTRIB_H



#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/common.h>

fsd_template_t *oardrmaa_oar_template_new(void);
int oardrmaa_oar_attrib_by_name( const char *name );

#define OARDRMAA_JOB_NAME       "job_name"
#define OARDRMAA_STDOUT_FILE    "stdout"
#define OARDRMAA_STDERR_FILE    "stderr"
#define OARDRMAA_RESOURCE       "resource"
#define OARDRMAA_ARGS           "args"
#define OARDRMAA_JOB_STATE      "job_state"
#define OARDRMAA_HOLD           "hold"
#define OARDRMAA_PROPERTY  "property"
#define OARDRMAA_RESERVATION    "reservation"
#define OARDRMAA_CHECKPOINT     "checkpoint"
#define OARDRMAA_SIGNAL         "signal"
#define OARDRMAA_TYPE           "type"
#define OARDRMAA_DIRECTORY      "directory"
#define OARDRMAA_PROJECT        "project"
#define OARDRMAA_ANTERIOR       "anterior"
#define OARDRMAA_NOTIFY         "notify"
#define OARDRMAA_RESUBMIT       "resubmit"
#define OARDRMAA_I_JOB_KEY_FROM_FILE  "import-job-key-from-file"
#define OARDRMAA_I_JOB_KEY_INLINE     "import-job-key-inline"
#define OARDRMAA_USE_JOB_KEY          "use-job-key"

typedef enum {
        OARDRMAA_ATTR_JOB_NAME,
        OARDRMAA_ATTR_STDOUT_FILE,
        OARDRMAA_ATTR_STDERR_FILE,
        OARDRMAA_ATTR_RESOURCE,
        OARDRMAA_ATTR_ARGS,
        OARDRMAA_ATTR_JOB_STATE, 
        OARDRMAA_ATTR_HOLD,
        OARDRMAA_ATTR_PROPERTY,
        OARDRMAA_ATTR_RESERVATION,
        OARDRMAA_ATTR_CHECKPOINT,
        OARDRMAA_ATTR_SIGNAL,
        OARDRMAA_ATTR_TYPE,
        OARDRMAA_ATTR_DIRECTORY,
        OARDRMAA_ATTR_PROJECT,
        OARDRMAA_ATTR_ANTERIOR,
        OARDRMAA_ATTR_NOTIFY,
        OARDRMAA_ATTR_RESUBMIT,
        OARDRMAA_ATTR_I_JOB_KEY_FROM_FILE,
        OARDRMAA_ATTR_I_JOB_KEY_INLINE,
        OARDRMAA_ATTR_USE_JOB_KEY,
        OARDRMAA_N_OAR_ATTRIBUTES 
} oar_attribute_t;

#endif /* __OAR_DRMAA__OAR_ATTRIB_H */

