/* $Id: drmaa.c 353 2010-10-18 13:45:14Z mamonski $ */
/*
 *  FedStage DRMAA for PBS Pro
 *  Copyright (C) 2006-2007  FedStage Systems
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
 * Adapted from pbs_drmaa/drmaa.c
 */

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <signal.h>
#include <drmaa_utils/drmaa_base.h>
#include <drmaa_utils/session.h>
#include <drmaa_utils/template.h>
#include <drmaa_utils/drmaa_attrib.h>
#include <drmaa_utils/iter.h>
#include <drmaa_utils/logging.h>
#include <oar_drmaa/session.h>


static fsd_drmaa_session_t *
oardrmaa_new_session( fsd_drmaa_singletone_t *self, const char *contact )
{
        return oardrmaa_session_new( contact );
}

static fsd_template_t *
oardrmaa_new_job_template( fsd_drmaa_singletone_t *self )
{
	return drmaa_template_new();
}

static const char *
oardrmaa_get_contact( fsd_drmaa_singletone_t *self )
{
	const char *contact = NULL;
	fsd_mutex_lock( &self->session_mutex );
	if( self->session )
		contact = self->session->contact;
	if( contact == NULL )
		contact = "localhost";
	fsd_mutex_unlock( &self->session_mutex );
	return contact;
}

static void
oardrmaa_get_version( fsd_drmaa_singletone_t *self,
		unsigned *major, unsigned *minor )
{
	*major = 1;  *minor = 0;
}

static const char *
oardrmaa_get_DRM_system( fsd_drmaa_singletone_t *self )
{
    return "OAR";
}

static const char *
oardrmaa_get_DRMAA_implementation( fsd_drmaa_singletone_t *self )
{
	return PACKAGE_NAME" v. "PACKAGE_VERSION" <http://oar.imag.fr/>";
}


fsd_iter_t *
oardrmaa_get_attribute_names( fsd_drmaa_singletone_t *self )
{
	static const char *attribute_names[] = {
		DRMAA_REMOTE_COMMAND,
		DRMAA_JS_STATE,
		DRMAA_WD,
		DRMAA_JOB_CATEGORY,
		DRMAA_NATIVE_SPECIFICATION,
		DRMAA_BLOCK_EMAIL,
		DRMAA_START_TIME,
		DRMAA_JOB_NAME,
		DRMAA_INPUT_PATH,
		DRMAA_OUTPUT_PATH,
		DRMAA_ERROR_PATH,
		DRMAA_JOIN_FILES,
		DRMAA_TRANSFER_FILES,
		DRMAA_WCT_HLIMIT,
		DRMAA_DURATION_HLIMIT,
		NULL
	};
	return fsd_iter_new_const( attribute_names, -1 );
}

fsd_iter_t *
oardrmaa_get_vector_attribute_names( fsd_drmaa_singletone_t *self )
{
	static const char *attribute_names[] = {
		DRMAA_V_ARGV,
		DRMAA_V_ENV,
		DRMAA_V_EMAIL,
		NULL
	};
	return fsd_iter_new_const( attribute_names, -1 );
}

static int
oardrmaa_wifexited(
		int *exited, int stat,
		char *error_diagnosis, size_t error_diag_len
		)
{
	*exited = (stat <= 125);
	return DRMAA_ERRNO_SUCCESS;
}

static int
oardrmaa_wexitstatus(
		int *exit_status, int stat,
		char *error_diagnosis, size_t error_diag_len
		)
{
	*exit_status = stat & 0xff;
	return DRMAA_ERRNO_SUCCESS;
}

static int
oardrmaa_wifsignaled(
		int *signaled, int stat,
		char *error_diagnosis, size_t error_diag_len
		)
{
	*signaled = (stat > 128 );
	return DRMAA_ERRNO_SUCCESS;
}	

static int
oardrmaa_wtermsig(
		char *signal, size_t signal_len, int stat,
		char *error_diagnosis, size_t error_diag_len
		)
{
	int sig = stat & 0x7f;
	strlcpy( signal, fsd_strsignal(sig), signal_len );
	return DRMAA_ERRNO_SUCCESS;
}

static int
oardrmaa_wcoredump(
		int *core_dumped, int stat,
		char *error_diagnosis, size_t error_diag_len
		)
{
  /* TODO: Can OAR support it ? */
	*core_dumped = 0;
	return DRMAA_ERRNO_SUCCESS;
}

static int
oardrmaa_wifaborted(
		int *aborted, int stat,
		char *error_diagnosis, size_t error_diag_len
		)
{
  fsd_log_info(("wifaborted(%d)>>>>", stat));
	fsd_log_debug(("wifaborted(%d)", stat));

	if ( stat == -1 )
	 {
		*aborted = true;
	 }
	else if ( stat <= 125 )
	 {
		*aborted = false;
	 }
	else if ( stat == 126 || stat == 127 )
         {
		*aborted = true;
	 } 
	else switch( stat & 0x7f )
	 {
		case SIGTERM:  case SIGKILL:
			*aborted = true;
			break;
		default:
			*aborted = false;
			break;
	 }
	return DRMAA_ERRNO_SUCCESS;
}


fsd_drmaa_singletone_t _fsd_drmaa_singletone = {
	NULL,
	FSD_MUTEX_INITIALIZER,

        oardrmaa_new_session,
        oardrmaa_new_job_template,

        oardrmaa_get_contact,
        oardrmaa_get_version,
        oardrmaa_get_DRM_system,
        oardrmaa_get_DRMAA_implementation,

        oardrmaa_get_attribute_names,
        oardrmaa_get_vector_attribute_names,

        oardrmaa_wifexited,
        oardrmaa_wexitstatus,
        oardrmaa_wifsignaled,
        oardrmaa_wtermsig,
        oardrmaa_wcoredump,
        oardrmaa_wifaborted
};

