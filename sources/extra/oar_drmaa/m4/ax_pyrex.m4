# $Id: ax_pyrex.m4 529 2007-12-20 21:04:22Z lukasz $
#
# SYNOPSIS
#
#   AX_PYREX(MINIMUM-VERSION, [ACTION-IF-FOUND[, [ACTION-IF-NOT-FOUND]])
#
# DESCRIPTION
#
#   Test for the Pyrex - tool for writing Python extension modules.
#   AX_PYTHON must be called before and PYTHON_BIN sets.
#
#   This macro calls::
#
#     AC_SUBST(PYREX_VERSION)
#
#   Major Pyrex features which when used may make code
#   incompatible with older versions:
#
#    * 0.9.6.3 - grouping multiple C declarations
#    * 0.9.6 - `__new__' replaced with `__cinit__'
#      (`__new__' produce deprecation warning),
#      conditional compilation, keyword only functions,
#      defining entry points for C code, `with' keyword, GIL support,
#      importing C functions from other module
#    * 0.9.5 - allow throwing instances of new-style classes
#      (as from Python 2.5 standard exceptions and descendants
#      are new-style classes)
#    * 0.9.4 - weak referencable extenstion types
#    * 0.9 - properties, C (cdef'ed) methods
#
# LAST MODIFICATION
#
#   2007-09-07
#
# LICENSE
#
#   Written by Łukasz Cieśnik <lukasz.ciesnik@gmail.com>
#   and placed under Public Domain
#

AC_DEFUN([AX_PYREX], [
AC_REQUIRE([AX_PYTHON])
AC_MSG_CHECKING([for Pyrex version])
[
version_prog="
from Pyrex.Compiler.Version import version
print version
"

cmp_prog="
import sys

def reversed( l ):
	l = list( l )
	l.reverse()
	return l

def numeric_compare( a, b ):
	def partition( s ):
		i = 0
		while i < len(s):
			j = i
			while j < len(s) and s[i:j+1].isdigit():
				j += 1
			if i != j:
				yield (1, int(s[i:j]) )
				i = j
			else:
				yield (0, s[i:i+1])
				i += 1
		raise StopIteration()

	def compose( *functions ):
		# Function composition
		def wrapper( x ):
			for f in reversed( functions ):
				x = f(x)
			return x
		return wrapper

	c = compose( list, partition, str )
	return cmp( c(a), c(b) )

min_version, version = sys.argv[1:3]
if numeric_compare( min_version, version ) <= 0:
	sys.exit( 0 )
else:
	sys.exit( 1 )
"
]

if PYREX_VERSION=`$PYTHON_BIN -c "$version_prog" 2>/dev/null`; then
	ax_pyrex_ok=yes
	AC_MSG_RESULT([$PYREX_VERSION])
else
	ax_pyrex_ok=no
	AC_MSG_RESULT([no])
fi

if test $ax_pyrex_ok = yes; then
	AC_MSG_CHECKING([for Pyrex >= $1])
	if ! $PYTHON_BIN -c "$cmp_prog" "$1" "$PYREX_VERSION"; then
		ax_pyrex_ok=no
	fi
	AC_MSG_RESULT([$ax_pyrex_ok])
fi

AC_SUBST(PYREX_VERSION)
if test x$ax_pyrex_ok = xyes; then
	$2
	:
else
	$3
	:
fi
])
