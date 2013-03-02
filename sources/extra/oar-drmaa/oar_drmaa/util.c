/* $Id: util.c 323 2010-09-21 21:31:29Z mmatloka $ */
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
 * Adapted from pbs_drmaa/util.c
 */

/**
 * @file oar_drmaa/util.c
 * OAR DRMAA utilities.
 */

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <drmaa_utils/common.h>
#include <oar_drmaa/util.h>
#include <oar_drmaa/oar_error.h>
#include <oar_drmaa/oar.h>

#ifndef lint
static char rcsid[]
#	ifdef __GNUC__
		__attribute__ ((unused))
#	endif
	= "$Id: util.c 323 2010-09-21 21:31:29Z mmatloka $";
#endif


void
oardrmaa_dump_attrl( const struct attrl *attribute_list, const char *prefix )
{
	const struct attrl *i;

	if( prefix == NULL )
		prefix = "";
	for( i = attribute_list;  i != NULL;  i = i->next )

            fsd_log_info(("var:%s value:%s \n",i->name, i->value ? i->value : "null"));
}


void
oardrmaa_free_attrl( struct attrl *attr )
{
	while( attr != NULL )
	 {
		struct attrl *p = attr;
		attr = attr->next;
		fsd_free( p->name );
		fsd_free( p->value );
		fsd_free( p->resource );
		fsd_free( p );
	 }
}


void
oardrmaa_exc_raise_oar( const char *function )
{
        int _oar_errno;
	int fsd_errno;
	const char *message = NULL;

  _oar_errno = oar_errno;
	/*
	 * Gathering error messages differ between PBS forks.
	 * - OpenPBS - ...
	 * - Torque - pbse_to_txt takes PBS error code (stored in pbs_errno)
	 *  and returns corresponding error message.
	 * - PBS Pro - stores errno of last operation inside pbs_errno variable;
	 *  pbse_to_txt always return NULL.
	 * All of them define pbs_geterrmsg which returns last error message
	 * for given connection.
	 */
	/* XXX: PBSPro has some link problems with pbse_to_txt function */
  
  message = oar_errno_to_txt( oar_errno );

  fsd_errno = oardrmaa_map_oar_errno( _oar_errno );
	fsd_log_error((
    "call to %s returned with error %d:%s mapped to %d:%s",
		function,  _oar_errno, message,
		fsd_errno, fsd_strerror(fsd_errno)
	));
	fsd_exc_raise_fmt( fsd_errno, "%s: %s", function, message );
}


/** Maps OAR error code into DMRAA code. */
/* TODO */
int
oardrmaa_map_oar_errno( int _oar_errno )
{
        fsd_log_enter(( "(oar_errno=%d)", _oar_errno ));
        switch( _oar_errno )
	 {
                case OAR_ERRNO_NONE:  /* no error */
			return FSD_ERRNO_SUCCESS;
                case OAR_ERRNO_UNKJOBID:	 /* Unknown Job Identifier */
			return FSD_DRMAA_ERRNO_INVALID_JOB;
                case OAR_ERRNO_NOATTR: /* Undefined Attribute */
                case OAR_ERRNO_ATTRRO: /* attempt to set READ ONLY attribute */
                case OAR_ERRNO_IVALREQ:  /* Invalid request */
                case OAR_ERRNO_UNKREQ:  /* Unknown batch request */
			return FSD_ERRNO_INTERNAL_ERROR;
                case OAR_ERRNO_PERM:  /* No permission */
                case OAR_ERRNO_BADHOST:  /* access from host not allowed */
			return FSD_ERRNO_AUTHZ_FAILURE;
                case OAR_ERRNO_JOBEXIST:  /* job already exists */
                case OAR_ERRNO_SVRDOWN:  /* req rejected -server shutting down */
                case OAR_ERRNO_EXECTHERE:  /* cannot execute there */
                case OAR_ERRNO_NOSUP:  /* Feature/function not supported */
                case OAR_ERRNO_EXCQRESC:  /* Job exceeds Queue resource limits */
                case OAR_ERRNO_QUENODFLT:  /* No Default Queue Defined */
                case OAR_ERRNO_NOTSNODE:  /* no time-shared nodes */
			return FSD_ERRNO_DENIED_BY_DRM;
                case OAR_ERRNO_SYSTEM:  /* system error occurred */
                case OAR_ERRNO_INTERNAL:  /* internal server error occurred */
                case OAR_ERRNO_REGROUTE:  /* parent job of dependent in rte que */
                case OAR_ERRNO_UNKSIG:  /* unknown signal name */
			return FSD_ERRNO_INTERNAL_ERROR;
                case OAR_ERRNO_BADATVAL:  /* bad attribute value */
                case OAR_ERRNO_BADATLST:  /* Bad attribute list structure */
                case OAR_ERRNO_BADUSER:  /* Bad user - no password entry */
                case OAR_ERRNO_BADGRP:  /* Bad Group specified */
                case OAR_ERRNO_BADACCT:  /* Bad Account attribute value */
                case OAR_ERRNO_UNKQUE:  /* Unknown queue name */
                case OAR_ERRNO_UNKRESC:  /* Unknown resource */
                case OAR_ERRNO_UNKNODEATR:  /* node-attribute not recognized */
                case OAR_ERRNO_BADNDATVAL:  /* Bad node-attribute value */
                case OAR_ERRNO_BADDEPEND:  /* Invalid dependency */
                case OAR_ERRNO_DUPLIST:  /* Duplicate entry in List */
			return FSD_ERRNO_INVALID_VALUE;
                case OAR_ERRNO_MODATRRUN:  /* Cannot modify attrib in run state */
                case OAR_ERRNO_BADSTATE:  /* request invalid for job state */
                case OAR_ERRNO_BADCRED:  /* Invalid Credential in request */
                case OAR_ERRNO_EXPIRED:  /* Expired Credential in request */
                case OAR_ERRNO_QUNOENB:  /* Queue not enabled */
			return FSD_ERRNO_INTERNAL_ERROR;
                case OAR_ERRNO_QACESS:  /* No access permission for queue */
			return FSD_ERRNO_AUTHZ_FAILURE;
                case OAR_ERRNO_HOPCOUNT:  /* Max hop count exceeded */
                case OAR_ERRNO_QUEEXIST:  /* Queue already exists */
                case OAR_ERRNO_ATTRTYPE:  /* incompatable queue attribute type */
			return FSD_ERRNO_INTERNAL_ERROR;
#		ifdef OAR_ERRNO_QUEBUSY
                case OAR_ERRNO_QUEBUSY:  /* Queue Busy (not empty) */
#		endif
                case OAR_ERRNO_MAXQUED:  /* Max number of jobs in queue */
                case OAR_ERRNO_NOCONNECTS:  /* No free connections */
                case OAR_ERRNO_TOOMANY:  /* Too many submit retries */
                case OAR_ERRNO_RESCUNAV:  /* Resources temporarily unavailable */
			return FSD_ERRNO_TRY_LATER;
		case 111:
                case OAR_ERRNO_PROTOCOL:  /* Protocol (ASN.1) error */
                case OAR_ERRNO_DISPROTO:  /* Bad DIS based Request Protocol */
			return FSD_ERRNO_DRM_COMMUNICATION_FAILURE;
#if 0
                case OAR_ERRNO_QUENBIG:  /* Queue name too long */
                case OAR_ERRNO_QUENOEN:  /* Cannot enable queue,needs add def */
                case OAR_ERRNO_NOSERVER:  /* No server to connect to */
                case OAR_ERRNO_NORERUN:  /* Job Not Rerunnable */
                case OAR_ERRNO_ROUTEREJ:  /* Route rejected by all destinations */
                case OAR_ERRNO_ROUTEEXPD:  /* Time in Route Queue Expired */
                case OAR_ERRNO_MOMREJECT:  /* Request to MOM failed */
                case OAR_ERRNO_BADSCRIPT:  /* (qsub) cannot access script file */
                case OAR_ERRNO_STAGEIN:  /* Stage In of files failed */
                case OAR_ERRNO_CKPBSY:  /* Checkpoint Busy, may be retries */
                case OAR_ERRNO_EXLIMIT:  /* Limit exceeds allowable */
                case OAR_ERRNO_ALRDYEXIT:  /* Job already in exit state */
                case OAR_ERRNO_NOCOPYFILE:  /* Job files not copied */
                case OAR_ERRNO_CLEANEDOUT:  /* unknown job id after clean init */
                case OAR_ERRNO_NOSYNCMSTR:  /* No Master in Sync Set */
                case OAR_ERRNO_SISREJECT:  /* sister rejected */
                case OAR_ERRNO_SISCOMM:  /* sister could not communicate */
                case OAR_ERRNO_CKPSHORT:  /* not all tasks could checkpoint */
                case OAR_ERRNO_UNKNODE:  /* Named node is not in the list */
                case OAR_ERRNO_NONODES:  /* Server has no node list */
                case OAR_ERRNO_NODENBIG:  /* Node name is too big */
                case OAR_ERRNO_NODEEXIST:  /* Node name already exists */
                case OAR_ERRNO_MUTUALEX:  /* State values are mutually exclusive */
                case OAR_ERRNO_GMODERR:  /* Error(s) during global modification of nodes */
                case OAR_ERRNO_NORELYMOM:  /* could not contact Mom */
			return FSD_ERRNO_INTERNAL_ERROR;
#endif
		default:
			return FSD_ERRNO_INTERNAL_ERROR;
	 }
}

