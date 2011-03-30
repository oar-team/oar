
#ifndef __OAR_DRMAA__OAR_ERROR_H
#define __OAR_DRMAA__OAR_ERROR_H

/* from number and text from pbs_error.h must replaced by OAR code */
#define OAR_ERRNO_NONE       0		/* no error */
#define OAR_ERRNO_UNKJOBID	15001		/* Unknown Job Identifier */
#define OAR_ERRNO_NOATTR	15002		/* Undefined Attribute */
#define OAR_ERRNO_ATTRRO	15003		/* attempt to set READ ONLY attribute */
#define OAR_ERRNO_IVALREQ	15004		/* Invalid request */
#define OAR_ERRNO_UNKREQ	15005		/* Unknown batch request */
#define OAR_ERRNO_TOOMANY	15006		/* Too many submit retries */
#define OAR_ERRNO_PERM	15007		/* No permission */
#define OAR_ERRNO_BADHOST	15008		/* access from host not allowed */
#define OAR_ERRNO_JOBEXIST	15009		/* job already exists */
#define OAR_ERRNO_SYSTEM	15010		/* system error occurred */
#define OAR_ERRNO_INTERNAL	15011		/* internal server error occurred */
#define OAR_ERRNO_REGROUTE	15012		/* parent job of dependent in rte que */
#define OAR_ERRNO_UNKSIG	15013		/* unknown signal name */
#define OAR_ERRNO_BADATVAL	15014		/* bad attribute value */
#define OAR_ERRNO_MODATRRUN	15015		/* Cannot modify attrib in run state */
#define OAR_ERRNO_BADSTATE	15016		/* request invalid for job state */
#define OAR_ERRNO_UNKQUE	15018		/* Unknown queue name */
#define OAR_ERRNO_BADCRED	15019		/* Invalid Credential in request */
#define OAR_ERRNO_EXPIRED	15020		/* Expired Credential in request */
#define OAR_ERRNO_QUNOENB	15021		/* Queue not enabled */
#define OAR_ERRNO_QACESS	15022		/* No access permission for queue */
#define OAR_ERRNO_BADUSER	15023		/* Bad user - no password entry */
#define OAR_ERRNO_HOPCOUNT	15024		/* Max hop count exceeded */
#define OAR_ERRNO_QUEEXIST	15025		/* Queue already exists */
#define OAR_ERRNO_ATTRTYPE	15026		/* incompatable queue attribute type */
#define OAR_ERRNO_QUEBUSY	15027		/* Queue Busy (not empty) */
#define OAR_ERRNO_QUENBIG	15028		/* Queue name too long */
#define OAR_ERRNO_NOSUP	15029		/* Feature/function not supported */
#define OAR_ERRNO_QUENOEN	15030		/* Cannot enable queue,needs add def */
#define OAR_ERRNO_PROTOCOL	15031		/* Protocol (ASN.1) error */
#define OAR_ERRNO_BADATLST	15032		/* Bad attribute list structure */
#define OAR_ERRNO_NOCONNECTS	15033		/* No free connections */
#define OAR_ERRNO_NOSERVER	15034		/* No server to connect to */
#define OAR_ERRNO_UNKRESC	15035		/* Unknown resource */
#define OAR_ERRNO_EXCQRESC	15036		/* Job exceeds Queue resource limits */
#define OAR_ERRNO_QUENODFLT	15037		/* No Default Queue Defined */
#define OAR_ERRNO_NORERUN	15038		/* Job Not Rerunnable */
#define OAR_ERRNO_ROUTEREJ	15039		/* Route rejected by all destinations */
#define OAR_ERRNO_ROUTEEXPD	15040		/* Time in Route Queue Expired */
#define OAR_ERRNO_MOMREJECT  15041		/* Request to MOM failed */
#define OAR_ERRNO_BADSCRIPT	15042		/* (qsub) cannot access script file */
#define OAR_ERRNO_STAGEIN	15043		/* Stage In of files failed */
#define OAR_ERRNO_RESCUNAV	15044		/* Resources temporarily unavailable */
#define OAR_ERRNO_BADGRP	15045		/* Bad Group specified */
#define OAR_ERRNO_MAXQUED	15046		/* Max number of jobs in queue */
#define OAR_ERRNO_CKPBSY	15047		/* Checkpoint Busy, may be retries */
#define OAR_ERRNO_EXLIMIT	15048		/* Limit exceeds allowable */
#define OAR_ERRNO_BADACCT	15049		/* Bad Account attribute value */
#define OAR_ERRNO_ALRDYEXIT	15050		/* Job already in exit state */
#define OAR_ERRNO_NOCOPYFILE	15051		/* Job files not copied */
#define OAR_ERRNO_CLEANEDOUT	15052		/* unknown job id after clean init */
#define OAR_ERRNO_NOSYNCMSTR	15053		/* No Master in Sync Set */
#define OAR_ERRNO_BADDEPEND	15054		/* Invalid dependency */
#define OAR_ERRNO_DUPLIST	15055		/* Duplicate entry in List */
#define OAR_ERRNO_DISPROTO	15056		/* Bad DIS based Request Protocol */
#define OAR_ERRNO_EXECTHERE	15057		/* cannot execute there */
#define OAR_ERRNO_SISREJECT	15058		/* sister rejected */
#define OAR_ERRNO_SISCOMM	15059		/* sister could not communicate */
#define OAR_ERRNO_SVRDOWN	15060		/* req rejected -server shutting down */
#define OAR_ERRNO_CKPSHORT	15061		/* not all tasks could checkpoint */
#define OAR_ERRNO_UNKNODE	15062		/* Named node is not in the list */
#define OAR_ERRNO_UNKNODEATR	15063		/* node-attribute not recognized */
#define OAR_ERRNO_NONODES	15064		/* Server has no node list */
#define OAR_ERRNO_NODENBIG	15065		/* Node name is too big */
#define OAR_ERRNO_NODEEXIST	15066		/* Node name already exists */
#define OAR_ERRNO_BADNDATVAL	15067		/* Bad node-attribute value */
#define OAR_ERRNO_MUTUALEX	15068		/* State values are mutually exclusive */
#define OAR_ERRNO_GMODERR	15069		/* Error(s) during global modification of nodes */
#define OAR_ERRNO_NORELYMOM	15070		/* could not contact Mom */
#define OAR_ERRNO_NOTSNODE	15071		/* no time-shared nodes */

/* TODO: to adapt */
#define USER_HOLD 0 /* TODO */


struct oar_err_to_txt {
        int    err_no;
        char **err_txt;
};

char *oar_errno_to_txt(int err_no);

extern int oar_errno; /* global value to store oar error from OAR_REST_API request. TODO: to verify */

#endif /* __OAR_DRMAA__OAR_ERROR_H */


