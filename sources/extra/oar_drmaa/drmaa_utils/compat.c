/* $Id: compat.c 533 2007-12-22 15:25:42Z lukasz $ */
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

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <drmaa_utils/compat.h>


#ifndef lint
static char rcsid[]
#	ifdef __GNUC__
		__attribute__ ((unused))
#	endif
	= "$Id: compat.c 533 2007-12-22 15:25:42Z lukasz $";
#endif


#ifndef HAVE_STRLCPY
size_t
strlcpy( char *dest, const char *src, size_t size )
{
	size_t result = 0;
	if( size == 0 )
		return 0;
	while( *src  &&  --size > 0 )
	 {
		*dest++ = *src++;
		result++;
	 }
	*dest++ = '\0';
	return result;
}
#endif /* ! HAVE_STRLCPY */


#ifndef HAVE_ASPRINTF
int
asprintf( char **strp, const char *fmt, ... )
{
	va_list args;
	int result;
	va_start( args, fmt );
	result = vasprintf( strp, fmt, args );
	va_end( args );
	return result;
}
#endif /* ! HAVE_ASPRINTF */


#ifndef HAVE_VASPRINTF
int
vasprintf( char **strp, const char *fmt, va_list ap )
{
	size_t size;
	char *buf;
	buf = (char*)malloc( size = 128 );
	if( buf == NULL )
		return -1;

	while( 1 )
	 {
		int len;
		char *oldbuf;

#		ifdef HAVE_VA_COPY
		va_list args;
		va_copy( args, ap );
		len = sprintfv( fmt, args );
#		else /* ! HAVE_VA_COPY */
		len = sprintfv( fmt, ap );
#		endif

		if( len < size )
		 {
			buf = realloc( buf, len+1 );
			*strp = buf;
			return len;
		 }
		if( len == -1 )
			size *= 2;
		else size = len + 1;

		buf = realloc( oldbuf = buf, size *= 2 );
		if( buf == NULL )
		 {
			free( oldbuf );
			return -1;
		 }
	 }
}
#endif /* ! HAVE_VASPRINTF */

