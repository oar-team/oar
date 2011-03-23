# $Id: $
# 
# Adapted by Auguste
#
# FedStage DRMAA for PBS Professional
# Copyright (C) 2006-2009  FedStage Systems
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#GPERF       = @GPERF@
#GPERFFLAGS  = --readonly-tables

AM_CPPFLAGS = -I$(top_srcdir)/drmaa_utils -fPIC

lib_LTLIBRARIES = liboardrmaa.la

# Below do we need of oar_attrib.gperf and oar_attrib.h ?
liboardrmaa_la_SOURCES = \
 drmaa.c \
 job.c job.h \
 session.c session.h \
 submit.c submit.h \
 util.c util.h \
 oar.c oar.h \
 oar_error.h

#BUILT_SOURCES       = pbs_attrib.c
#EXTRA_DIST          = pbs_attrib.c
#dist_sysconf_DATA   = oar_drmaa.conf.example

liboardrmaa_la_LIBADD  = ../drmaa_utils/drmaa_utils/libdrmaa_utils.la 

# see ../m4/ax_pbs.m4 for @OAR_xxx@ 
#liboardrmaa_la_LIBADD  = ../drmaa_utils/drmaa_utils/libdrmaa_utils.la @OAR_LIBS@
#liboardrmaa_la_LDFLAGS = @OAR_LDFLAGS@ -version-info @OAR_DRMAA_VERSION_INFO@


.gperf.c:
	$(GPERF) $(GPERFFLAGS) --output-file=$@ $<

#if GCC
#pbs_attrib.lo: CFLAGS += @GCC_W_NO_MISSING_FIELD_INITIALIZERS@
#endif
