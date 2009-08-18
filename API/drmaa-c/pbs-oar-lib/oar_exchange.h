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


#ifndef _OAR_EXCHANGE_H
#define _OAR_EXCHANGE_H 

#include "jparser.h"
#include "jgenerator.h"

// A structure to store the results of an OARAPI request
struct exchange_result_		
{
    int   code; 		// HTTP return code
    presult *data; 		// JSON STREAM PARSING DATA
};

typedef struct exchange_result_ exchange_result;


// A function to send requests to the OARAPI
exchange_result* oar_request_transmission();

MAX_OAR_URL_LENGTH;

#endif
