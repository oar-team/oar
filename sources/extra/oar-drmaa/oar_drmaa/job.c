/* $Id: job.c 370 2010-11-16 09:51:00Z mamonski $ */
/*
 *  FedStage DRMAA for PBS Pro
 *  Copyright (C) 2006-2009  FedStage Systems/
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
 *  along with this program.  If not, see <http:/www.gnu.org/licenses/>.
 */

/*
 * Adapted from pbs_drmaa/job.c
 */

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <drmaa_utils/drmaa.h>
#include <drmaa_utils/drmaa_util.h>

#include <oar_drmaa/oar.h>
#include <oar_drmaa/oar_error.h>

#include <oar_drmaa/job.h>
#include <oar_drmaa/oar_attrib.h>
#include <oar_drmaa/session.h>
#include <oar_drmaa/util.h>

#ifndef lint
static char rcsid[]
#	ifdef __GNUC__
		__attribute__ ((unused))
#	endif
	= "$Id: job.c 370 2010-11-16 09:51:00Z mamonski $";
#endif


static void
oardrmaa_job_control( fsd_job_t *self, int action );

static void
oardrmaa_job_update_status( fsd_job_t *self );

static void
oardrmaa_job_on_missing( fsd_job_t *self );

void
oardrmaa_job_on_missing_standard( fsd_job_t *self );

void
oardrmaa_job_on_missing_log_based( fsd_job_t *self );

static void
oardrmaa_job_update( fsd_job_t *self, struct batch_status* );


fsd_job_t *
oardrmaa_job_new( char *job_id )
{
        oardrmaa_job_t *self = (oardrmaa_job_t*)fsd_job_new( job_id );
        fsd_realloc( self, 1, oardrmaa_job_t );
        self->super.control = oardrmaa_job_control;
        self->super.update_status = oardrmaa_job_update_status;
        self->super.on_missing = oardrmaa_job_on_missing;
        self->update = oardrmaa_job_update;
	return (fsd_job_t*)self;
}


static void
oardrmaa_job_control( fsd_job_t *self, int action )
{
	volatile bool conn_lock = false;
        oardrmaa_session_t *session = (oardrmaa_session_t*)self->session;
	const char *job_id = self->job_id;
	const char *apicall = NULL;
        int rc = OAR_ERRNO_NONE; /*TODO: to adapt */

	fsd_log_enter(( "({job_id=%s}, action=%d)",
			self->job_id, action ));

	TRY
	 {
		int try_count;
		const int max_tries = 3;

		conn_lock = fsd_mutex_lock( &self->session->drm_connection_mutex );

		/*TODO reconnect */
		for( try_count=0;  try_count < max_tries;  try_count++ )
		 {
			switch( action )
			 {
				/*
				 * We cannot know whether we did suspend job
                                 * in other way than remembering this inside DRMAA session.
                                 * Note: With OAR we can (job event):) Can we exploit this ?
				 */
				case DRMAA_CONTROL_SUSPEND:
                                        apicall = "oar_job_control_rhold";
                                        rc = oar_control_job(session->oar_conn, (char*)job_id, action);
                                        fsd_log_info(("oar_job_control (%s, RHOLD) =%d", job_id, rc));
                                        if( rc ==  OAR_ERRNO_NONE)
						self->flags |= FSD_JOB_SUSPENDED;
					break;
				case DRMAA_CONTROL_RESUME:
                                        apicall = "oar_job_control_resumptions";
                                        rc = oar_control_job(session->oar_conn, (char*)job_id, action);
                                        fsd_log_info(("oar_job_control(%s, RESUMPTIONS/RESUMES) =%d", job_id, rc));
                                        if( rc == OAR_ERRNO_NONE )
						self->flags &= ~FSD_JOB_SUSPENDED;
					break;
				case DRMAA_CONTROL_HOLD:
                                        apicall = "oar_job_control_hold";
                                        rc = oar_control_job(session->oar_conn, (char*)job_id, action);

                                        fsd_log_info(("oar_job_control(%s, HOLD) =%d", job_id, rc));
                                        if( rc ==  OAR_ERRNO_NONE )
						self->flags |= FSD_JOB_HOLD;
					break;
				case DRMAA_CONTROL_RELEASE:
                                        apicall = "oar_job_control_resumptions";
                                        rc = oar_control_job(session->oar_conn, (char*)job_id, action);
                                        fsd_log_info(("oar_job_control(%s, RESUMPTIONS/RELEASE) =%d", job_id, rc));
                                        if( rc == OAR_ERRNO_NONE )
						self->flags &= FSD_JOB_HOLD;
					break;
				case DRMAA_CONTROL_TERMINATE:
                                        apicall = "oar_job_control_deletions";
                                        rc = oar_control_job(session->oar_conn, (char*)job_id, action);
                                        fsd_log_info(("oar_job_control(%s, DELETIONS) =%d", job_id, rc));

                                        if( rc == OAR_ERRNO_NONE )
					 {
						self->flags &= FSD_JOB_TERMINATED_MASK;
						if( (self->flags & FSD_JOB_TERMINATED) == 0 )
							self->flags |= FSD_JOB_TERMINATED | FSD_JOB_ABORTED;
					 }
					break;
			 }

                        if( rc == OAR_ERRNO_NONE )
				break;
                        else if( rc == OAR_ERRNO_INTERNAL ) /*TODO: to adapt: PBSE_INTERNAL */
			 {
                           /* TODO: to remove ? */
                           /*
                            * In PBS Pro pbs_sigjob raises internal server error (PBSE_INTERNAL)
                            * when job just changed its state to running.
                            */
                            fsd_log_debug(( "repeating request (%d of %d)", try_count+2, max_tries ));
                            sleep( 1 );
			 }
			else
                            oardrmaa_exc_raise_oar( apicall );
		 } /* end for */
	 }
	FINALLY
	 {
		if( conn_lock )
			conn_lock = fsd_mutex_unlock( &self->session->drm_connection_mutex );
	 }
	END_TRY

	fsd_log_return((""));
}


void
oardrmaa_job_update_status( fsd_job_t *self )
{
	volatile bool conn_lock = false;
	struct batch_status *volatile status = NULL;
        oardrmaa_session_t *session = (oardrmaa_session_t*)self->session;

	fsd_log_enter(( "({job_id=%s})", self->job_id ));
	TRY
	 {
		conn_lock = fsd_mutex_lock( &self->session->drm_connection_mutex );
retry:        
                status = oar_statjob( session->oar_conn, self->job_id);

                fsd_log_info(( "oar_statjob(fd=%d, job_id=%s, attribs={...}) =%p",
                                 session->oar_conn, self->job_id, (void*)status ));
		if( status == NULL )
		 {
                        fsd_log_error(("oar_statjob error: %d, %s", oar_errno, oar_errno_to_txt(oar_errno)));

                        switch( oar_errno )
			 {
                                case OAR_ERRNO_UNKJOBID: /*TODO: to adapt */
					break;
                                case OAR_ERRNO_PROTOCOL:
                                case OAR_ERRNO_EXPIRED:
                                        if ( session->oar_conn >= 0 )
                                                oar_disconnect( session->oar_conn );
					sleep(1);
                                        session->oar_conn = oar_connect( session->super.contact );
                                        if( session->oar_conn < 0 )
                                                oardrmaa_exc_raise_oar( "oar_connect" );
					else 
					 {
						fsd_log_error(("retry:"));
						goto retry;
					 }
				default:
                                        oardrmaa_exc_raise_oar( "oar_statjob" );
					break;
				case 0:  /* ? */
					fsd_exc_raise_code( FSD_ERRNO_INTERNAL_ERROR );
					break;
			 }
		 }

		conn_lock = fsd_mutex_unlock( &self->session->drm_connection_mutex );

		if( status != NULL )
		 {
                        ((oardrmaa_job_t*)self)->update( self, status );
		 }
		else if( self->state < DRMAA_PS_DONE )
			self->on_missing( self );
	 }
	FINALLY
	 {
		if( conn_lock )
			conn_lock = fsd_mutex_unlock( &self->session->drm_connection_mutex );
		if( status != NULL )
                        oar_statfree( status );
	 }
	END_TRY

	fsd_log_return((""));
}


void
oardrmaa_job_update( fsd_job_t *self, struct batch_status *b_status )
{

        char *oar_state = NULL;
	int exit_status = -2;
        struct oar_job_status *status = b_status->status;
        /* TODO to remove ???
	const char *cpu_usage = NULL;
	const char *mem_usage = NULL;
	const char *vmem_usage = NULL;
        */
        const char *walltime = NULL;

        long unsigned int modify_time = 0; /* TODO */

	fsd_log_enter(( "({job_id=%s})", self->job_id ));
#ifdef DEBUGGING
	//        oardrmaa_dump_attrl( attribs, NULL );
#endif
        fsd_assert( !strcmp( self->job_id, b_status->name ) );
/* TODO: to adapt */

        oar_status_dump(b_status);

        oar_state = status->state;
        exit_status = status->exit_status;
        self->walltime = status -> walltime;

        if (!self->queue)
                self->queue = fsd_strdup(status->queue);
        /* TODO in oar.c*/
        /*
        if (!self->project)
                self->project = fsd_strdup(status->project);
        */
        /* TODO
        if (!self->execution_hosts) {
                fsd_log_debug(("execution_hosts = %s", i->value));
                self->execution_hosts = fsd_strdup(i->value);
        */
        /* TODO
				  long unsigned int start_time;
				  if (self->start_time == 0 && sscanf(i->value, "%lu", &start_time) == 1)
					self->start_time = start_time;
				  break;
				}
                        case OARDRMAA_ATTR_MTIME:
				if (sscanf(i->value, "%lu", &modify_time) != 1)
					modify_time = 0;
        */

        /*
        if (!strcmp(oar_state,OAR_JS_TERMINATED))
        {
            fsd_log_debug((("YOP %s %s\n",oar_state,OAR_JS_TERMINATED);
        } else
        {
            fsd_log_debug((("PAS GLOP %s %s\n",oar_state,OAR_JS_TERMINATED);
        }
*/
        if( oar_state )
                fsd_log_debug(( "oar_state: %s", oar_state ));

	if( exit_status != -2 )
	 {
                fsd_log_debug(( "exit_status: %d", exit_status ));
		self->exit_status = exit_status;
	 }
        if(oar_state)
        {
            if(!strcmp(oar_state,OAR_JS_WAITING)||!strcmp(oar_state,OAR_JS_TOLAUNCH))
            { /* DRMAA_PS_QUEUED_ACTIVE */
                self->state = DRMAA_PS_QUEUED_ACTIVE;
                self->flags &= ~FSD_JOB_HOLD;
            } else
            if (!strcmp(oar_state,OAR_JS_HOLD))
            { /* DRMAA_PS_SYSTEM_ON_HOLD / DRMAA_PS_USER_ON_HOLD [default] / DRMAA_PS_USER_SYSTEM_ON_HOLD */
                /* TODO: system/user */
                self->state = DRMAA_PS_USER_ON_HOLD;
                self->flags |= FSD_JOB_HOLD;
            } else
            if (!strcmp(oar_state,OAR_JS_TOERROR)||!strcmp(oar_state,OAR_JS_ERROR))
            { /* DRMAA_PS_FAILED */
                printf("OAR_JS_TOERROR||OAR_JS_ERROR -> DRMAA_PS_FAILED\n");
                self->state = DRMAA_PS_FAILED;
                self->exit_status = -1;
            } else
            if (!strcmp(oar_state,OAR_JS_LAUNCHING)||!strcmp(oar_state,OAR_JS_RUNNING)||!strcmp(oar_state,OAR_JS_FINISHING))
            { /* DRMAA_PS_RUNNING */
                self->state = DRMAA_PS_RUNNING;
            } else
            if (!strcmp(oar_state,OAR_JS_SUSPENDED)||!strcmp(oar_state,OAR_JS_RESUMING))
            { /* DRMAA_PS_SYSTEM_SUSPENDED / DRMAA_PS_USER_SUSPENDED [default] */
                 /* TODO: system/user */
                self->state = DRMAA_PS_USER_SUSPENDED;
            } else
            if (!strcmp(oar_state,OAR_JS_TERMINATED))
            { /* DRMAA_PS_DONE */
                fsd_log_debug(("strcmp(oar_state,OAR_JS_TERMINATED)/n"));
                self->flags &= FSD_JOB_TERMINATED_MASK;
                self->flags |= FSD_JOB_TERMINATED;
                if (exit_status != -2)
                { /*has exit code */
                    if( self->exit_status == 0)
                    {
                        fsd_log_debug(("DRMAA_PS_DONE\n"));
                        self->state = DRMAA_PS_DONE;
                    } else
                    {
                        /* TODO: is not possible with OAR ??? */
                        fsd_log_debug(("DRMAA_PS_FAILED\n"));
                        self->state = DRMAA_PS_FAILED;
                    }
                } else {
                        /* TODO: is not possible with OAR ??? */
                        self->state = DRMAA_PS_FAILED;
                        self->exit_status = -1;
                }
                self->end_time = modify_time; /* END_TIME */ /* TODO */

            } else /* OAR_JS_TOASKRESERV || other */
            { /* DRMAA_PS_UNDETERMINED */
                self->state = DRMAA_PS_UNDETERMINED;
            }

        }

            /*
                switch( oar_state )
                */
                    /* TODO: must be adapted
		 {
                 case 'C': #*Job is completed after having run. *#
				self->flags &= FSD_JOB_TERMINATED_MASK;
				self->flags |= FSD_JOB_TERMINATED;
                                if (exit_status != -2) { #*has exit code *#
					if( self->exit_status == 0) 
						self->state = DRMAA_PS_DONE;
					else 
						self->state = DRMAA_PS_FAILED;
				} else {
					self->state = DRMAA_PS_FAILED;
					self->exit_status = -1;
				}
                                self->end_time = modify_time; #*take last modify time as end time *#
				break;
                        case 'E': #*Job is exiting after having run. - MM: ignore exiting state (transient state) - outputs might have not been transfered yet,
                                        MM2: mark job as running if current job status is undetermined - fix "ps after job was ripped" *#
				if (self->state == DRMAA_PS_UNDETERMINED)
					self->state = DRMAA_PS_RUNNING;
				break;
                        case 'H': #*Job is held. *#
				self->state = DRMAA_PS_USER_ON_HOLD;
				self->flags |= FSD_JOB_HOLD;
				break;
                        case 'Q': #*Job is queued, eligible to run or routed. *#
                        case 'W': #*Job is waiting for its execution time to be reached. *#
				self->state = DRMAA_PS_QUEUED_ACTIVE;
				self->flags &= ~FSD_JOB_HOLD;
				break;
                        case 'R': #*Job is running. *#
                        case 'T': #*Job is being moved to new location (?). *#
			 {
				if( self->flags & FSD_JOB_SUSPENDED )
					self->state = DRMAA_PS_USER_SUSPENDED;
				else
					self->state = DRMAA_PS_RUNNING;
				break;
			 }
                        case 'S': #*(Unicos only) job is suspend. *#
				self->state = DRMAA_PS_SYSTEM_SUSPENDED;
				break;
			case 0:  default:
				self->state = DRMAA_PS_UNDETERMINED;
				break;
	 }
         */

	fsd_log_debug(( "job_ps: %s", drmaa_job_ps_to_str(self->state) ));
        /* TODO adapt ??? */
/*
	 {
		int hours, minutes, seconds;
		long mem;
		if( cpu_usage && sscanf( cpu_usage, "%d:%d:%d",
				&hours, &minutes, &seconds ) == 3 )
		 {
			self->cpu_usage = 60*( 60*hours + minutes ) + seconds;
			fsd_log_debug(( "cpu_usage: %s=%lds", cpu_usage, self->cpu_usage ));
		 }
		if( mem_usage && sscanf( mem_usage, "%ldkb", &mem ) == 1 )
		 {
			self->mem_usage = 1024*mem;
			fsd_log_debug(( "mem_usage: %s=%ldB", mem_usage, self->mem_usage ));
		 }
		if( vmem_usage && sscanf( vmem_usage, "%ldkb", &mem ) == 1 )
		 {
			self->vmem_usage = 1024*mem;
			fsd_log_debug(( "vmem_usage: %s=%ldB", vmem_usage, self->vmem_usage ));
		 }
		if( walltime && sscanf( walltime, "%d:%d:%d",
					&hours, &minutes, &seconds ) == 3 )
		 {
			self->walltime = 60*( 60*hours + minutes ) + seconds;
			fsd_log_debug(( "walltime: %s=%lds", walltime, self->walltime ));
		 }
	 }
*/

}

void
oardrmaa_job_on_missing( fsd_job_t *self )
/*TODO: do we need of this ? */
{
	fsd_drmaa_session_t *session = self->session;
	
	unsigned missing_mask = 0;

	fsd_log_enter(( "({job_id=%s})", self->job_id ));
	fsd_log_warning(( "self %s missing from DRM queue", self->job_id ));

	switch( session->missing_jobs )
	{
		case FSD_REVEAL_MISSING_JOBS:         missing_mask = 0;     break;
		case FSD_IGNORE_MISSING_JOBS:         missing_mask = 0x73;  break;
		case FSD_IGNORE_QUEUED_MISSING_JOBS:  missing_mask = 0x13;  break;
	}
	fsd_log_debug(( "last job_ps: %s (0x%02x); mask: 0x%02x",
				drmaa_job_ps_to_str(self->state), self->state, missing_mask ));

	if( self->state < DRMAA_PS_DONE
			&&  (self->state & ~missing_mask) )
		fsd_exc_raise_fmt(
				FSD_ERRNO_INTERNAL_ERROR,
				"self %s missing from queue", self->job_id
				);

	if( (self->flags & FSD_JOB_TERMINATED_MASK) == 0 )
	{
		self->flags &= FSD_JOB_TERMINATED_MASK;
		self->flags |= FSD_JOB_TERMINATED;
	}

	if( (self->flags & FSD_JOB_ABORTED) == 0
			&&  session->missing_jobs == FSD_IGNORE_MISSING_JOBS )
	{ /* assume everthing was ok */
		self->state = DRMAA_PS_DONE;
		self->exit_status = 0;
	}
	else
	{ /* job aborted */
		self->state = DRMAA_PS_FAILED;
		self->exit_status = -1;
	}

	fsd_log_return(( "; job_ps=%s, exit_status=%d",
				drmaa_job_ps_to_str(self->state), self->exit_status ));
}


