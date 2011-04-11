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
#define OARDRMAA_WALLTIME       "walltime"
#define OARDRMAA_ARGS           "args"
#define OARDRMAA_JOB_STATE      "job_state"
#define OARDRMAA_HOLD           "hold"

typedef enum {
        OARDRMAA_ATTR_JOB_NAME,
        OARDRMAA_ATTR_STDOUT_FILE,
        OARDRMAA_ATTR_STDERR_FILE,
        OARDRMAA_ATTR_WALLTIME,
        OARDRMAA_ATTR_ARGS,
        OARDRMAA_ATTR_JOB_STATE,
        OARDRMAA_ATTR_HOLD,
        OARDRMAA_N_OAR_ATTRIBUTES
} oar_attribute_t;

#endif /* __OAR_DRMAA__OAR_ATTRIB_H */

