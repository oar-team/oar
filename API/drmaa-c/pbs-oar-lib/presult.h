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


#ifndef _P_RESULT_H
#define _P_RESULT_H 


// List of possible types for a "presult" variable
enum{
   UNKNOWN,
   INTEGER,
   FLOAT,
   STRING,
   COMPLEX	// If it is an object or an array (See http://www.json.org/)
};

 
// Structure of presult
struct element_
{
    char* key;			// Name of the attribute (It can be NULL for the some imbricated structures)
    int type;			// Type of the variable  (UNKNOWN when created but MUST be changed when initialized)
    union {
       int i;
       float f;
       char* s;
    } immValue; 		// If it is not a complex value, the variable can be either an Integer, a Float or a String
    struct element_ *compValue; // If it is a JSON object or a JSON array (for the moment it is also a presult)
    struct element_ *next;	// next presult element in the structure
};

// In order to avoid the "struct element_"
typedef struct element_ presult;


// The list of functions
presult* addElement();
void showResult();
void showResult_();
int isEmpty();
presult deleteElement();
presult findElement();
presult findElementNumber();
void removeResult();
void getDrmaaState();
char* extractStringAttribute();

#endif
