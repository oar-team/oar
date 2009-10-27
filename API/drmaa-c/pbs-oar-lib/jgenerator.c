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

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "jgenerator.h"

gchar* json_strescape (const gchar *source) {

  if (source==NULL) {
	  return NULL;
  }

  gchar *dest, *q;
  gunichar *ucs4;
  gint i, length;

  if (!g_utf8_validate (source, -1, NULL))
    return g_strescape (source, NULL);

  length = g_utf8_strlen (source, -1);
  dest = q = g_malloc (length * 6 + 1);

  ucs4 = g_utf8_to_ucs4_fast (source, -1, NULL);
  
  for (i = 0; i < length; i++)
    {
      switch (ucs4 [i]) {
      case '\\':
        *q++ = '\\';
        *q++ = '\\';
        break;
      case '"':
        *q++ = '\\';
        *q++ = '"';
        break;
      case '\b':
        *q++ = '\\';
        *q++ = 'b';
        break;
      case '\f':
        *q++ = '\\';
        *q++ = 'f';
        break;
      case '\n':
        *q++ = '\\';
        *q++ = 'n';
        break;
      case '\r':
        *q++ = '\\';
        *q++ = 'r';
        break;
      case '\t':
        *q++ = '\\';
        *q++ = 't';
        break;
      case '/' :
	      *q++ = '\\';
        *q++ = '/';
	break;
      default:
        if ((ucs4 [i] >= (gunichar)0x7F) || (ucs4 [i] <= (gunichar)0x1F)) 
	      // characters in the range of 0x01-0x1F (everything below SPACE) and in the range 0x7F-0xFF
        // (all non-ASCII chars) should not be escaped (see the JSON website for more information)
	      // Glib don't escape the SLASH character (which should be escaped when we serialize a JSON stream) !!!
          {
            g_sprintf (q, "\\u%04x", ucs4 [i]);
            q += 6;
          }
        else
          *q++ = ((gchar)ucs4 [i]);
      }
    }

  *q++ = 0;

  g_free (ucs4);

  return dest;
}


