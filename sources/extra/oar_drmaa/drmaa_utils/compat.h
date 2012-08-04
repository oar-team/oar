/* $Id: compat.h 533 2007-12-22 15:25:42Z lukasz $ */
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

#ifndef __DRMAA__COMPAT_H
#define __DRMAA__COMPAT_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <sys/types.h>

#include <stddef.h>
#include <stdarg.h>

#ifdef HAVE_STDINT_H
#	include <stdint.h>
#else
#	ifdef HAVE_INTTYPES_H
#		include <inttypes.h>
#	else
#		warning "no stdint.h nor inttypes.h found"
#	endif
#endif /* ! HAVE_STDINT_H */

#ifdef HAVE_STDBOOL_H
#	include <stdbool.h>
#else
#	ifndef bool
#		define bool int
#	endif
#	ifndef true
#		define true 1
#	endif
#	ifndef false
#		define false 0
#	endif
#endif /* ! HAVE_STDBOOL_H */

#ifndef HAVE_STRLCPY
size_t strlcpy( char *dest, const char *src, size_t size )
	__attribute__(( weak ));
#endif

#ifndef HAVE_ASPRINTF
int asprintf( char **strp, const char *fmt, ... )
	__attribute__(( weak ));
#endif

#ifndef HAVE_VASPRINTF
int vasprintf( char **strp, const char *fmt, va_list ap )
	__attribute__(( weak ));
#endif

#endif /* __DRMAA__COMPAT_H */

