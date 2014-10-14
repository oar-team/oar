AC_INIT([DRMAA for OAR], [1.0.1], [http://oar.imag.fr], [oar-drmaa])
AC_PREREQ(2.59)
AC_REVISION([$Id: $])
AC_COPYRIGHT([
DRMAA for OAR Copyright (C) 2011-2012 Joseph Fourier University
based on
DRMAA for PBS Pro
Copyright (C) 2006-2009  FedStage Systems

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
])

OAR_DRMAA_MAJOR=1
OAR_DRMAA_MINOR=0
OAR_DRMAA_MICRO=1
OAR_DRMAA_VERSION_INFO=1:0:1
AC_SUBST([OAR_DRMAA_MAJOR])
AC_SUBST([OAR_DRMAA_MINOR])
AC_SUBST([OAR_DRMAA_MICRO])
AC_SUBST([OAR_DRMAA_VERSION_INFO])

AC_CONFIG_SRCDIR([oar_drmaa/drmaa.c])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([scripts])

AM_INIT_AUTOMAKE

# command-line arguments:
AC_ARG_ENABLE(debug, AC_HELP_STRING([--enable-debug],
			[produce code suiteable for debugging and print logs at runtime]))
AC_ARG_ENABLE(development, AC_HELP_STRING([--enable-development],
			[enable development mode: make additional checks (suiteable for FedStage DRMAA for PBS Pro developers)]))

# programs:
AC_PROG_CC
AC_PROG_CPP
AC_PROG_INSTALL
AC_PROG_LIBTOOL
AC_PROG_MAKE_SET
AC_PROG_LN_S

# code generation tools:
AX_GPERF

# reStructuredText processing:
AX_DOCUTILS()
if test x$RST2HTML = x; then
	RST2HTML="sh m4/missing-dev-prog.sh docutils"
fi
if test x$RST2LATEX = x; then
	RST2LATEX="sh m4/missing-dev-prog.sh docutils"
fi

# check compiler / set basic flags:
if test x$ac_cv_prog_cc_stdc = xno; then
	AC_MSG_ERROR([ANSI C compiler is required])
fi

if test x$GCC = xyes; then
	CFLAGS="-pedantic -ansi ${CFLAGS}"
fi
AM_CONDITIONAL([GCC], [test x$GCC = xyes])

AX_GCC_WARNINGS()

AH_TEMPLATE([DEBUGGING], [Produce debugging code])
if test x$enable_debug = xyes; then
	AC_DEFINE(DEBUGGING,[1])
	CFLAGS="${CFLAGS} -O0"
else
	CPPFLAGS="-DNDEBUG ${CPPFLAGS}"
fi

AH_TEMPLATE([DEVELOPMENT], [Development mode])
if test x$enable_development = xyes; then
	AC_DEFINE(DEVELOPMENT, [1])
fi

AH_BOTTOM([
#ifndef __GNUC__
#	define __attribute__ /* nothing */
#endif
])

# system:
CPPFLAGS="-D_REENTRANT -D_THREAD_SAFE ${CPPFLAGS}"

AC_CANONICAL_HOST
case "$host_os" in
	*linux*)
		CPPFLAGS="${CPPFLAGS} -D_GNU_SOURCE"
		;;
	*solaris*)
		CPPFLAGS="${CPPFLAGS} -D_XOPEN_SOURCE=500 -D__EXTENSIONS__"
		;;
	*freebsd*)
		;;
	*darwin*)
		CPPFLAGS="${CPPFLAGS} -D_XOPEN_SOURCE=400"
		;;
	*)
		CPPFLAGS="${CPPFLAGS} -D_XOPEN_SOURCE=500"
		;;
esac

# project prerequisites:

# libraries:
ACX_PTHREAD([CFLAGS="$CFLAGS $PTHREAD_CFLAGS" LIBS="$PTHREAD_LIBS $LIBS"],
		[AC_MSG_ERROR([POSIX threads library is required.])])

CPPFLAGS="${CPPFLAGS} -DCONFDIR=${sysconfdir}"

# headers:
AC_HEADER_STDC
AC_HEADER_TIME
AC_HEADER_STDBOOL
AC_CHECK_HEADERS([stddef.h stdlib.h string.h strings.h sys/time.h unistd.h])

# types and structures:
AC_TYPE_SIZE_T
AC_STRUCT_TM

# compiler characteristic
AC_C_CONST
AC_C_INLINE
AC_C_VOLATILE

# functions:
AC_FUNC_MALLOC
AC_FUNC_STRFTIME
AC_FUNC_VPRINTF
AC_CHECK_FUNCS([ \
	asprintf \
	fstat \
	getcwd \
	gettimeofday \
	localtime_r \
	memset \
	mkstemp \
	setenv \
	strcasecmp \
	strchr \
	strdup \
	strerror \
	strlcpy \
	strndup \
	strstr \
	strtol \
	vasprintf \
	])

# system services:

# turn on warning after all tests
if test x$GCC = xyes; then
	if test x$enable_development = xyes; then
		CFLAGS="-Werror ${CFLAGS}"
	fi
	CFLAGS="-Wall -W -Wno-unused-parameter $GCC_W_NO_FORMAT_ZERO_LENGTH ${CFLAGS}"
fi

AC_CONFIG_FILES([
	Makefile
  oar_drmaa/Makefile
])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_SUBDIRS([drmaa_utils])
AC_OUTPUT

echo
echo "Run 'make' now."

