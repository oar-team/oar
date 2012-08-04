/* $Id: drmaa_base.h 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file drmaa_base.h
 * DRM independant part of DRMAA library.
 */
#ifndef __DRMAA__DRMAA_BASE_H
#define __DRMAA__DRMAA_BASE_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/common.h>

/** @defgroup drmaa_session  Session managing functions.
	@{ */
/** Creates DRMAA session and opens connection with DRM. */
drmaa_session_t *
drmaa_session_create( const char *contact, drmaa_err_ctx_t *err );

/** Closes connection with DRM (if any) and destroys DRMAA session data. */
void
drmaa_session_destroy( drmaa_session_t *session, drmaa_err_ctx_t *err );

void
drmaa_session_apply_config( drmaa_session_t *session, drmaa_err_ctx_t *err );

drmaa_session_t *
drmaa_session_get( drmaa_err_ctx_t *err );

void
drmaa_session_release( drmaa_session_t *session, drmaa_err_ctx_t *err );
/** @} */


/**
 * Frees memory associated with @a jt job template
 * without locking associated session.
 */
void
drmaa_delete_async_job_template(
		drmaa_job_template_t *jt, drmaa_err_ctx_t *err );


/** @defgroup drmaa_jobs  Job managing functions.
	@{ */

/** Create empty set of jobs. */
drmaa_job_set_t *
drmaa_job_set_create( drmaa_err_ctx_t *err );

/** Destroy set of jobs (including contained job handles). */
void
drmaa_job_set_destroy( drmaa_job_set_t *job_set, drmaa_err_ctx_t *err );

/**
 * Finds job with given job_id.
 * @param job_set Set of jobs to search in.
 * @param job_id Job identifier.
 * @param err  Error context.
 * @return If successful job handle is returned
 * and caller have exclusive access right to it.
 * It should be released by drmaa_job_release().
 * @c NULL is returned upon failure.
 */
drmaa_job_t *
drmaa_job_find(
		drmaa_job_set_t *job_set, const char *job_id,
		drmaa_err_ctx_t *err
		);

/**
 * Find any job in set which was terminated (either successfully or not).
 * It is usefull for drmaa_wait( DRMAA_JOB_IDS_ANY ) implementation.
 * @param job_set Set of jobs to search in.
 * @param err  Error context.
 * @return Terminated job handle (it should be released by drmaa_job_release())
 *   or @c NULL if no such job is present in set.
 * @see drmaa_job_find
 */
drmaa_job_t *
drmaa_job_find_terminated( drmaa_job_set_t *job_set, drmaa_err_ctx_t *err );

/**
 * Return idenetifiers of all jobs in set.
 * @param job_set Set of jobs.
 * @param err  Error context.
 * @return Vector of job idenetifiers
 *   when done free it with drmaa_free_vector.
 */
char **
drmaa_get_all_job_ids( drmaa_job_set_t *job_set, drmaa_err_ctx_t *err );

void drmaa_job_set_signal_all( drmaa_job_set_t *job_set, drmaa_err_ctx_t *err );

/** Adds job to set. */
void
drmaa_job_set_add(
		drmaa_job_set_t *job_set, drmaa_job_t *job,
		drmaa_err_ctx_t *err
		);

/** Remove job from set. */
void
drmaa_job_set_remove( drmaa_job_set_t *job_set, drmaa_job_t *job,
		drmaa_err_ctx_t *err );

/** Initializes drmaa_job_t structure with default values. */
void
drmaa_job_init( drmaa_job_t *job, drmaa_err_ctx_t *err );

void
drmaa_job_release( drmaa_job_t **pjob, drmaa_err_ctx_t *err );
/** @} */


/** @defgroup drmaa_wait  Waiting/notification functions:
	@{ */

/**
 * Waits until given job terminates (either successfuly or not).
 * @param session  DRMAA session.
 * @param job_id  Identifier of job to wait for.
 * @param status  If not @c NULL job status code is stored here.
 * @param rusage  If not @c NULL list of used resources is returned.
 * @param dispose  If @c true job information is removed from session
 *   at the end of call and further accesses to this job_id will
 *   raise DRMAA_ERRNO_INVALID_JOB.  Otherwise job data is held.
 * @param timeout  If not @c NULL and job does not terminate
 *   in given amount of time function returns and
 *   DRMAA_ERRNO_EXIT_TIMEOUT is raised.
 */
void
drmaa_wait_for_single_job(
		drmaa_session_t *session,
		const char *job_id,
		int *status, drmaa_attr_values_t **rusage,
		bool dispose,
		const struct timespec *timeout,
		drmaa_err_ctx_t *err
		);

/**
 * Wait until and job left in session terminates.
 * @return  Identifier of waited job.
 *   Freeing responsobility is left to the callee.
 * @see drmaa_wait_for_single_job
 */
char *
drmaa_wait_for_any_job(
		drmaa_session_t *session,
		int *status, drmaa_attr_values_t **rusage,
		bool dispose,
		const struct timespec *timeout,
		drmaa_err_ctx_t *err
		);

void
drmaa_job_get_termination_state(
		drmaa_job_t *job, int *status, drmaa_attr_values_t **rusage,
		drmaa_err_ctx_t *err
		);
/** @} */





typedef struct drmaa_session_impl_s drmaa_session_impl_t;
typedef struct drmaa_job_template_impl_s drmaa_job_template_impl_t;
typedef struct drmaa_job_impl_s drmaa_job_impl_t;
typedef struct drmaa_submit_impl_s drmaa_submit_impl_t;


struct drmaa_implementation_info_s {
	const char *drm_system; /**< Name of DRM system. */
	const char *default_contact; /**< Default contact string. */
	const char *drmaa_implementation; /**< DRMAA implementation string. */
	const char *const *attributes; /**< List of implemented scalar attributes. */
	const char *const *vector_attributes; /**< List of implemented
																		vector attributes. */
};

/**
 * Whether to ignore jobs missing from queue
 * and treat them as finished.
 */
typedef enum {
	DRMAA_RAISE_MISSING_JOBS,
	DRMAA_IGNORE_MISSING_JOBS,
	DRMAA_IGNORE_QUEUED_MISSING_JOBS
} drmaa_missing_jobs_behaviour_t;


/** Session data. */
struct drmaa_session_s {
	char                 *contact;  /**< Copy of contact string passed to drmaa_init. */

	/**
	 * Cyclic list (with sentinel) of job
	 * templates created in this DRMAA session.
	 */
	drmaa_job_template_t *jt_list;
	drmaa_job_set_t      *jobs;

	drmaa_attrib_info_t  *attributes;
	int                   attributes_capacity;
	int                   n_attributes;

	drmaa_mutex_t         mutex;
	drmaa_mutex_t         jt_mutex;  /**< Mutex for \a jt_list */
	drmaa_mutex_t         end_mutex;
	drmaa_cond_t          wait_cond;  /**< Conditional for drmaa_wait */
	drmaa_cond_t          destroy_cond;  /**< Conditional for ref_cnt==0 */
	int                   ref_cnt;
	bool                  end;

	drmaa_conf_dict_t    *configuration;
	struct timespec       pool_delay;  /**< Queue pooling delay. */
	bool                  with_wait_thread;  /**< Wait for jobs in separate thread? */
	drmaa_conf_dict_t    *job_categories;
	drmaa_missing_jobs_behaviour_t  missing_jobs;

	drmaa_session_impl_t *impl;
};


/** Job template data. */
struct drmaa_job_template_s {
	drmaa_session_t      *session; /**< DRMAA session in which job template was created. */
	drmaa_job_template_t *prev;    /**< Previous job template in list. */
	drmaa_job_template_t *next;    /**< Next job template in list. */
	void                **attrib;  /**< Table of DRMAA attributes [0..N_DRMAA_ATTRIBS-1]. */
	drmaa_mutex_t         mutex;   /**< Mutex for accessing job attributes. */
	drmaa_job_template_impl_t *impl;
};

struct drmaa_job_set_s {
	drmaa_job_t    **tab;
	size_t           tab_size;
	uint32_t         tab_mask;
	/** Mutex for job set data (e.g. for adding/removing job from set). */
	drmaa_mutex_t  mutex;
};


typedef enum {
	DRMAA_JOB_QUEUED             = 1<<0,
	/** Job is hold in queue. */
	DRMAA_JOB_HOLD               = 1<<1,
	/** Job is running (suspended or not). */
	DRMAA_JOB_RUNNING            = 1<<2,
	/** Set when job was suspended within session by drmaa_control(). */
	DRMAA_JOB_SUSPENDED          = 1<<3,
	/**
	 * Whether we know that job terminated and its status
	 * is waiting to rip.
	 */
	DRMAA_JOB_TERMINATED         = 1<<4,
	/**
	 * It is known that job was terminated by user.
	 */
	DRMAA_JOB_ABORTED            = 1<<5,
	/**
	 * Job is being removed from session
	 * (but still references to job still exist).
	 */
	DRMAA_JOB_DISPOSED           = 1<<6,

	DRMAA_JOB_MISSING            = 1<<7,

	DRMAA_JOB_QUEUED_MASK      = DRMAA_JOB_QUEUED | DRMAA_JOB_HOLD,
	DRMAA_JOB_RUNNING_MASK     = DRMAA_JOB_RUNNING | DRMAA_JOB_SUSPENDED,
	DRMAA_JOB_TERMINATED_MASK  = DRMAA_JOB_TERMINATED | DRMAA_JOB_ABORTED,
	DRMAA_JOB_STATE_MASK       = DRMAA_JOB_HOLD | DRMAA_JOB_RUNNING
		| DRMAA_JOB_SUSPENDED | DRMAA_JOB_TERMINATED
} job_flag_t;


/** Submit job data. */
struct drmaa_job_s {
	drmaa_job_t  *next;

	/** DRMAA session which job was submited in. */
	drmaa_session_t *session;

	/** Mutex for accessing drmaa_job_s structure (despite \a next pointer). */
	drmaa_mutex_t  mutex;
	/** Job status changed condition. */
	drmaa_cond_t   status_cond;
	/** Able to destroy condition variable (ref_cnt==1). */
	drmaa_cond_t   destroy_cond;

	/** Number of references. */
	int ref_cnt;

	/** Job identifier (as null terminated string). */
	char *job_id;

	/**
	 * Time of last update of job status and rusage information
	 * (when status, exit_status, cpu_usage, mem_usage and flags
	 * fields was updated according to DRM).
	 */
	time_t last_update_time;

	/** Job state flags.  @see job_flag_t */
	unsigned flags;

	/**
	 * Status of job (as returned by drmaa_job_ps())
	 * from last retrieval from DRM.
	 */
	int status;

	/** Exit status of job as from <tt>wait(2)</tt>. */
	int exit_status;
	/** Time of job submission (local). */
	time_t submit_time;
	/** Time when job started execution (taken from DRM). */
	time_t start_time;
	/** Time when job ended execution (taken from DRM). */
	time_t end_time;
	/** CPU time usage in seconds. */
	long cpu_usage;
	/** Memory usage in bytes. */
	long mem_usage;
	/** Total run time in seconds. */
	long walltime;

	/** Implementation dependant additional data. */
	drmaa_job_impl_t *impl;
};


/**
 * Keeps data used during job submission.
 */
struct drmaa_submit_ctx_s {
	const drmaa_job_template_t *jt;
	char *home_directory;
	char *working_directory;
	char *bulk_incr;
	drmaa_submit_impl_t *impl;
};


struct drmaa_attr_names_s  { char **list, **iter; };
struct drmaa_attr_values_s { char **list, **iter; };
struct drmaa_job_ids_s     { char **list, **iter; };

#endif /* __DRMAA__DRMAA_BASE_H */

