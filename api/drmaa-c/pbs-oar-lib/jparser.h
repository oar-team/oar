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


#ifndef _JSON_PARSER_H
#define _JSON_PARSER_H 

#include "presult.h"


// The structure that will contain the answer of OAR (the body of the request sent back by the OARAPI)
struct jresult_
{
    int status;			// the parsing exit status 
    presult *data;		// the parsing result
};

typedef struct jresult_ jresult;


// This function allows us to get information from a JSON stream
jresult* load_json_from_stream();

#endif
