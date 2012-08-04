# $Id: Makefile.am 533 2007-12-22 15:25:42Z lukasz $
# 
# FedStage DRMAA for PBS Pro
# Copyright (C) 2006-2007  Fedstage Systems Inc.
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

GPERF       = @GPERF@
GPERFFLAGS  = --language=ANSI-C --struct-type --readonly-tables --includes --pic
#AM_CPPFLAGS = -I$(srcdir)/..
AM_YFLAGS   = -d
YLWRAP = $(top_srcdir)/m4/bison_ylwrap.sh
pkgincludedir = $(includedir)/drmaa_utils

lib_LTLIBRARIES = libdrmaa_utils.la

libdrmaa_utils_la_SOURCES = \
 attrib.c attrib.h \
 compat.c compat.h \
 conf.c conf.h \
 conf_impl.h conf_tab.y \
 datetime.c datetime.h \
 datetime_impl.h datetime_tab.y \
 drmaa_attrib.gperf \
 drmaa_base.c drmaa_base.h \
 drmaa_impl.h \
 error.c error.h \
 lookup3.c lookup3.h \
 thread.c thread.h \
 util.c util.h \
 xmalloc.c xmalloc.h

include_HEADERS     = drmaa.h
pkginclude_HEADERS  = \
 attrib.h \
 common.h \
 conf.h \
 compat.h \
 datetime.h \
 drmaa_base.h \
 drmaa_impl.h \
 errctx.h \
 error.h \
 lookup3.h \
 thread.h \
 util.h \
 xmalloc.h

BUILT_SOURCES = \
 drmaa_attrib.c \
 datetime_tab.c datetime_tab.h \
 conf_tab.c conf_tab.h
EXTRA_DIST = drmaa_attrib.c
libdrmaa_utils_la_LDFLAGS = --version-info 0:0:0

.gperf.c:
	base=`basename $< .gperf`; \
	if $(GPERF) $(GPERFFLAGS) --hash-function-name=$${base}_hash \
		--lookup-function-name=$${base}_lookup $< >$@; \
	then exit 0; \
	else rm $@; exit 1; \
	fi
# gperf produce non pure code; suppress compiler warnings
drmaa_attrib.lo: CFLAGS += -w
# Bison generated code have many unused symbols
datetime_tab.lo conf_tab.lo: CFLAGS += -Wno-unused

