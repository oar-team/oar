/******************************************************************


OAR DRMAA-C : A C library for using the OAR DRMS
Copyright (C) 2009  LIG <http://www.liglab.fr/>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
<http://www.gnu.org/licenses/>

**********************************************************************/


#ifndef _OAR_PBS_H
#define _OAR_PBS_H 

#include "pbs_ifl.h"
#include "pbs_error.h"
#include "oar_exchange.h" 	// A JSON parser for OAR-API responses

#define MAX_OAR_URL_LENGTH 200

// A set of type definition in order to make their use easier
typedef struct batch_status batch_status;
typedef struct attrl attrl;
typedef struct attropl attropl;

// List of PBS functions used in the PBS DRMAA
int pbs_connect(char *server);

char * pbs_default(void);

int pbs_deljob(int connect, char *job_id, char *extend);

int pbs_disconnect(int connect);

char * pbs_geterrmsg(int connect);

int pbs_holdjob(int connect, char *job_id, char *hold_type, 
		       char *extend);

int pbs_rlsjob(int connect, char *job_id, char *hold_type, char *extend);

int pbs_sigjob(int connect, char *job_id, char *signal, char *extend);

void pbs_statfree(struct batch_status *stat);

struct batch_status *pbs_statjob(int connect, char *id, struct attrl *attrib, char *extend);

struct batch_status *pbs_statque(int connect, char *id, struct attrl *attrib, char *extend); 

struct batch_status *pbs_statserver(int connect, struct attrl *attrib, char *extend);

char *pbs_submit(int connect, struct attropl *attrib, char *script,
	char *destination, char *extend);
	
int pbs_terminate(int connect, int manner, char *extend);

char *pbse_to_txt(int err);


// Global variables
char * pbs_server;		
int pbs_errno;			


// List of additional functions used in PBS/OAR conversion
void show_BatchStatus(batch_status *status);					// A test function to show the content of a batch_status structure

attrl *addNewAttribute(attrl **list, char* name, char* resource, char* value); 	// Add a new attribute to a PBS ATTRIBUTE LIST

#endif
