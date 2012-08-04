# $Id: ax_pbs.m4 529 2007-12-20 21:04:22Z lukasz $
#
# SYNOPSIS
#
#   AX_PBS([ACTION-IF-FOUND[, ACTION-IF-NOT-FOUND]])
#
# DESCRIPTION
#
#   Check for PBS libraries and headers.
#
#   This macro calls::
#
#     AC_SUBST(PBS_INCLUDES)
#     AC_SUBST(PBS_LIBS)
#     AC_SUBST(PBS_LDFLAGS)
#
# LAST MODIFICATION
#
#   2007-10-27
#
# LICENSE
#
#   Written by Łukasz Cieśnik <lukasz.ciesnik@gmail.com>
#   and placed under Public Domain
#

AC_DEFUN([AX_PBS],[
AC_ARG_WITH([pbs], [AC_HELP_STRING([--with-pbs=<pbs-prefix>],
		[Path to existing PBS installation root])])
AC_SUBST(PBS_INCLUDES)
AC_SUBST(PBS_LIBS)
AC_SUBST(PBS_LDFLAGS)

if test x"$with_pbs" != x; then
	PBS_INCLUDES="$CPPFLAGS -I$with_pbs/include"
	PBS_LDFLAGS="-L$with_pbs/lib"
fi

LDFLAGS_save="$LDFLAGS"
CPPFLAGS_save="$CPPFLAGS"
LDFLAGS="$LDFLAGS $PBS_LDFLAGS"
CPPFLAGS="$CPPFLAGS $PBS_INCLUDES"

ax_pbs_ok="no"

if test x"$ax_pbs_ok" = xno; then
	ax_pbs_ok="yes"
	AC_CHECK_LIB([pbs], [pbs_submit], [:], [ax_pbs_ok="no"])
	AC_CHECK_LIB([log], [pbse_to_txt], [:], [ax_pbs_ok="no"])
	if test x"$ax_pbs_ok" = xyes; then
		ax_pbs_libs="-lpbs -llog"
	fi
fi

if test x"$ax_pbs_ok" = xno; then
	ax_pbs_ok="yes"
	AC_CHECK_LIB([torque], [pbs_submit], [:], [ax_pbs_ok="no"])
	AC_CHECK_LIB([torque], [pbse_to_txt], [:], [ax_pbs_ok="no"])
	if test x"$ax_pbs_ok" = xyes; then
		ax_pbs_libs="-ltorque"
	fi
fi

if test x"$ax_pbs_ok" = xyes; then
	AC_CHECK_HEADERS([pbs_ifl.h pbs_error.h],[:],[ax_pbs_ok="no"])
fi

dnl if test x"$ax_pbs_ok" = xyes; then
dnl 	AC_LANG_PUSH([C])
dnl 	AC_MSG_CHECKING([for working pbse_to_txt])
dnl 	LIBS_save="$LIBS"
dnl 	LIBS="$LIBS $ax_pbs_libs"
dnl 	AC_RUN_IFELSE([AC_LANG_PROGRAM([[
dnl #include <pbs_error.h>
dnl ]],[[
dnl 	pbs_errno = PBSE_UNKJOBID;
dnl 	if( pbse_to_txt( pbs_errno ) != NULL )
dnl 		return 1;
dnl 	else
dnl 		return 0;
dnl ]])], [ax_pbse_to_txt=yes], [ax_pbs_to_txt=no],
dnl 			[ax_pbse_to_txt=crosscompile])
dnl 	if test $ax_pbse_to_txt = crosscompile; then
dnl 		AC_LINK_IFELSE([AC_LANG_PROGRAM([[
dnl #include <pbs_error.h>
dnl ]],[[
dnl 	/* should not work when 
dnl 	pbse_to_
dnl ]])], [ax_pbse_to_txt=no], [ax_pbse_to_txt=yes])
dnl 	fi
dnl 	LIBS="$LIBS_save"
dnl 	AC_LANG_POP([C])
dnl fi

LDFLAGS="$LDFLAGS_save"
CPPFLAGS="$CPPFLAGS_save"

if test x"$ax_pbs_ok" = xyes; then
	PBS_LIBS="$ax_pbs_libs"
	$1
	:
else
	$2
	:
fi
])
