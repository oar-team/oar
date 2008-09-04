#!/usr/bin/make
#Under Debian or Ubuntu you must install the package "python-docutils"

all: doc-admin doc-user doc-usecases
	
doc-admin: OAR-DOCUMENTATION-ADMIN.html
	
doc-user: OAR-DOCUMENTATION-USER.html

doc-usecases: doc_usecases.html

latex: OAR-DOCUMENTATION-ADMIN.tex OAR-DOCUMENTATION-USER.tex

pdf: OAR-DOCUMENTATION-ADMIN.pdf OAR-DOCUMENTATION-USER.pdf

%.html: %.rst
	rst2html -stg $< $@

%.tex: %.rst
	rst2newlatex $< $@

%.pdf: %.tex
	pdflatex $< $@
	pdflatex $< $@
