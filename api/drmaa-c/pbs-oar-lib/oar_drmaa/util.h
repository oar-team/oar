/* $Id: util.h 323 2010-09-21 21:31:29Z mmatloka $ */
/*
 *  FedStage DRMAA for PBS Pro
 *  Copyright (C) 2006-2009  FedStage Systems
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
 * Adapted from pbs_drmaa/util.h
 */


#ifndef __OAR_DRMAA__UTIL_H
#define __OAR_DRMAA__UTIL_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

void oardrmaa_exc_raise_oar( const char *function );
int oardrmaa_map_oar_errno( int _oar_errno );

struct attrl;

void oardrmaa_free_attrl( struct attrl *list );
void oardrmaa_dump_attrl(
		const struct attrl *attribute_list, const char *prefix );

/**
 * Writes temporary file.
 * @param content   Buffer with content to write.
 * @param len       Buffer's length.
 * @return Path to temporary file.
 */
char *
oardrmaa_write_tmpfile( const char *content, size_t len );

#endif /* __OAR_DRMAA__UTIL_H */

