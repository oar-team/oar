# $Id: ax_gettid.m4 529 2007-12-20 21:04:22Z lukasz $
#
# SYNOPSIS
#
#   AX_GETTID([ACTION-IF-FOUND[, ACTION-IF-NOT-FOUND]])
#
# DESCRIPTION
#
#   Check for gettid system call.  When found this macro
#   defines HAVE_GETTID.  It may be used after following
#   definition (it is not defined in Linux headers)::
#
#     #include <sys/types.h>
#     #include <sys/syscall.h>
#     pid_t gettid(void) {  return (pid_t)syscall( __NR_gettid );  }
#
# LAST MODIFICATION
#
#   2007-12-14
#
# LICENSE
#
#   Written by Łukasz Cieśnik <lukasz.ciesnik@gmail.com>
#   and placed under Public Domain
#

AC_DEFUN([AX_GETTID],[
AC_MSG_CHECKING([for gettid])
AC_REQUIRE([AC_PROG_CC])

AC_LANG_PUSH([C])
AC_COMPILE_IFELSE(
	AC_LANG_PROGRAM([[
@%:@include <sys/types.h>
@%:@include <sys/syscall.h>
@%:@include <unistd.h>
pid_t gettid(void) { return (pid_t)syscall(__NR_gettid); }]],
	[[pid_t tid = gettid(); return 0;]]),
[ax_gettid_ok=yes], [ax_gettid_ok=no])
AC_LANG_POP([C])

AC_MSG_RESULT([$ax_gettid_ok])
if test x$ax_gettid_ok = xyes; then
	AC_DEFINE([HAVE_GETTID],1,[Define to 1 if you have the gettid() syscall.])
fi
if test x$ax_gettid_ok = xyes; then
	$1
	:
else
	$2
	:
fi
])
