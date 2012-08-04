# $Id: ax_docutils.m4 529 2007-12-20 21:04:22Z lukasz $
#
# SYNOPSIS
#
#   AX_DOCUTILS([ACTION-IF-FOUND[, ACTION-IF-NOT-FOUND]])
#
# DESCRIPTION
#
#   Test for the Docutils -- Python driven reStructuredText processor.
#   This macro calls (through AC_CHECK_PROGS)::
#
#     AC_SUBST(RST2HTML)
#     AC_SUBST(RST2LATEX)
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

AC_DEFUN([AX_DOCUTILS], [
	ax_docutils_ok=no
	ax_rst2html_ok=no
	ax_rst2latex_ok=no
	for rest in rst2html rst2html.py; do
		AC_CHECK_PROGS(RST2HTML, [$rest])
		if test x$RST2HTML != x; then
			ax_rst2html_ok=yes
			break
		fi
	done
	for rest in rst2latex rst2latex.py; do
		AC_CHECK_PROGS(RST2LATEX, [$rest])
		if test x$RST2LATEX != x; then
			ax_rst2latex_ok=yes
			break
		fi
	done
	if test $ax_rst2html_ok = yes  -a  $ax_rst2latex_ok = yes; then
		ax_docutils_ok=yes
	fi
	if test x$ax_docutils_ok = xyes; then
		$1
		:
	else
		$2
		:
	fi
])
