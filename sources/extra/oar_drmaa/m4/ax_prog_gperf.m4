# $Id: ax_prog_gperf.m4 529 2007-12-20 21:04:22Z lukasz $
#
# SYNOPSIS
#
#   AX_PROG_GPERF([ACTION-IF-FOUND[, [ACTION-IF-NOT-FOUND]])
#
# DESCRIPTION
#
#   Test for Gperf perfect hash function generator binary.
#   When not found GPERF is set with location of fallback
#   script which prints error message and exits with non-zero
#   error code.
#
#   This macro calls::
#
#     AC_SUBST(GPERF)
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

AC_DEFUN([AX_PROG_GPERF], [
	AC_MSG_CHECKING([for gperf])
	if { echo a; echo b; echo c; } | gperf >/dev/null 2>&1; then
		ax_prog_gperf_ok=yes
		GPERF=gperf
	else
		if echo $srcdir | grep -q "^/"; then
			abs_srcdir="$srcdir"
		else
			abs_srcdir="`pwd`/$srcdir"
		fi
		GPERF="${abs_builddir}/scripts/gperf-fallback.sh"
		cat >$GPERF <<EOF
#!/bin/sh
cat >&2 <<MESSAGE
 * ERROR: gperf was not found at configuration time while some sources are
 * build by it.  Either install gperf <http://www.gnu.org/software/gperf/>
 * or download tarball with generated sources included (than you will
 * not be able to modify .gperf files).
MESSAGE
exit 1
EOF
		chmod +x $GPERF
		ax_prog_gperf_ok=no
	fi
	AC_SUBST(GPERF)
	AC_MSG_RESULT([$ax_prog_gperf_ok])
	if test x$ax_prog_gperf_ok = xyes; then
		$1
		:
	else
		$2
		:
	fi
])
