# $Id: ax_python.m4 529 2007-12-20 21:04:22Z lukasz $
#
# SYNOPSIS
#
#   AX_PYTHON([MINIMUM-VERSION[, ACTION-IF-FOUND[, ACTION-IF-NOT-FOUND]]])
#
# DESCRIPTION
#
#   This macro does a complete Python development environment check.
#   This macro calls::
#
#     AC_SUBST(PYTHON_BIN)
#     AC_SUBST(PYTHON_INCLUDES)
#     AC_SUBST(PYTHON_LIBS)
#     AC_SUBST(PYTHON_CONFIG)
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

AC_DEFUN([AX_PYTHON],[

AC_MSG_NOTICE([checking Python development environment])

ax_python_min=$1

for ver in 2.6 2.5 2.4 2.3 2.2 2.1; do
	AC_CHECK_PROGS(PYTHON_CONFIG, [python$ver-config python-config-$ver])
	if test x$PYTHON_CONFIG != x; then
		ax_python_ver=$ver
		break
	fi
done

AC_CHECK_PROGS(PYTHON_CONFIG, [python-config])

if test x$PYTHON_CONFIG != x; then
	ax_python_path="`$PYTHON_CONFIG --exec-prefix`:$PATH"
	if test x$ax_python_ver != x; then
		ax_python_bins="python${ax_python_ver} python"
	else
		ax_python_bins="python"
	fi
	AC_CHECK_PROGS(PYTHON_BIN, [$ax_python_bins],, [$ax_python_path])
	PYTHON_INCLUDES=`$PYTHON_CONFIG --includes`
	PYTHON_LIBS=`$PYTHON_CONFIG --libs`
fi
AC_SUBST(PYTHON_VERSION)
AC_SUBST(PYTHON_BIN)
AC_SUBST(PYTHON_INCLUDES)
AC_SUBST(PYTHON_LIBS)

[
version_prog="
import sys
print sys.version.split(' ')[0]
"
version_check_prog="
import sys
def to_hex( s ):
	pos = [
		0x01000000,
		0x00010000,
		0x00000100,
	]
	parts = str(s).split('.')
	hex = 0
	for i in range(len(parts)):
		hex += pos[i] * int(parts[i])
	return hex
if sys.hexversion >= to_hex( sys.argv[1] ):
	sys.exit( 0 )
else:
	sys.exit( 1 )
"
]


if test x$ax_python_min != x; then
	AC_MSG_CHECKING([for Python >= $ax_python_min])
else
	AC_MSG_CHECKING([for Python])
fi

ax_python_ok=no
if test x$PYTHON_BIN != x; then
	PYTHON_VERSION=`$PYTHON_BIN -c "$version_prog"`
	if test x$ax_python_min != x; then
		if $PYTHON_BIN -c "$version_check_prog" "$ax_python_min"; then
			ax_python_ok=yes
		fi
	else
		ax_python_ok=yes
	fi
fi

AC_MSG_RESULT([$ax_python_ok])
if test x$ax_python_ok = xyes; then
	AC_MSG_RESULT([  Version:      $PYTHON_VERSION])
	AC_MSG_RESULT([  Binary:       $PYTHON_BIN])
	AC_MSG_RESULT([  Libraries:    $PYTHON_LIBS])
	AC_MSG_RESULT([  Include dirs: $PYTHON_INCLUDES])
	$2
else
	$3
	:
fi
])
