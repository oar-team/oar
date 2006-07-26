#!/usr/bin/make
#Under Debian or Ubuntu you must install the package "python-docutils"

all:
	rst2html -stg OAR-DOCUMENTATION.rst OAR-DOCUMENTATION.html

latex:
	rst2newlatex OAR-DOCUMENTATION.rst OAR-DOCUMENTATION.tex

pdf: latex
	pdflatex OAR-DOCUMENTATION.tex OAR-DOCUMENTATION.pdf
	pdflatex OAR-DOCUMENTATION.tex OAR-DOCUMENTATION.pdf

