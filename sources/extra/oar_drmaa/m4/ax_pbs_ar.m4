# $Id: ax_pbs_ar.m4 529 2007-12-20 21:04:22Z lukasz $
#
# SYNOPSIS
#
#   AX_PBS_AR([ACTION-IF-FOUND[, ACTION-IF-NOT-FOUND]])
#
# DESCRIPTION
#
#   Check for PBS advanced reservation functions (available in PBS Pro)::
#
#     char *
#     pbs_submit_resv(
#     	int connection, struct attropl *attrib, char *extend );
#
#     int
#     pbs_delresv( int connect, char *resv_id, char *extend );
#
#     struct batch_status *
#     pbs_statresv(
#     		int connect, char *id, struct attrl *attrib, char *extend );
#
#
# LAST MODIFICATION
#
#   2007-12-15
#
# LICENSE
#
#   Written by Łukasz Cieśnik <lukasz.ciesnik@gmail.com>
#   and placed under Public Domain
#

AC_DEFUN([AX_PBS_AR],[
AC_REQUIRE([AX_PBS])
AC_REQUIRE([AC_PROG_CC])
AC_MSG_CHECKING([for PBS advanced reservation functions])

CPPFLAGS_save="$CPPFLAGS"
LDFLAGS_save="$LDFLAGS"
LIBS_save="$LIBS"

CPPFLAGS="$CPPFLAGS $PBS_INCLUDES"
LIBS="$LIBS $PBS_LIBS"
LDFLAGS="$LDFLAGS $PBS_LDFLAGS"

AC_LANG_PUSH([C])
AC_LINK_IFELSE(AC_LANG_PROGRAM([[
@%:@include <pbs_ifl.h>
]],[[
	int c;
	struct attropl *attr_list = NULL;
	char *resv_id = NULL;
	c = pbs_connect( NULL );
	resv_id = pbs_submit_resv( c, attr_list, NULL );
	pbs_statresv( c, resv_id, attr_list, NULL );
	pbs_delresv( c, resv_id, NULL );
]]),[ax_pbs_ar_ok=yes],[ax_pbs_ar_ok=no])
AC_LANG_POP([C])

CPPFLAGS="$CPPFLAGS_save"
LIBS="$LIBS_save"
LDFLAGS="$LDFLAGS_save"

AC_MSG_RESULT([$ax_pbs_ar_ok])

if test x$ax_pbs_ar_ok = xyes; then
	$1
	:
else
	$2
	:
fi
])
