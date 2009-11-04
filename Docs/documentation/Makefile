#!/usr/bin/make
#Under Debian or Ubuntu you must install the package "python-docutils"

all: doc-admin doc-user doc-usecases doc-api
	
doc-admin: OAR-DOCUMENTATION-ADMIN.html
	
doc-user: OAR-DOCUMENTATION-USER.html

doc-usecases: doc_usecases.html

doc-api: OAR-DOCUMENTATION-API.html

latex: OAR-DOCUMENTATION-ADMIN.tex OAR-DOCUMENTATION-USER.tex OAR-DOCUMENTATION-API.tex

pdf: OAR-DOCUMENTATION-ADMIN.pdf OAR-DOCUMENTATION-USER.pdf OAR-DOCUMENTATION-API.pdf

%.html: %.rst
	rst2html -stg $< $@

%.tex: %.rst
	rst2newlatex $< $@

%.pdf: %.tex
	pdflatex $< $@
	pdflatex $< $@

clean:
	rm *.pdf *.html *.tex *.aux *.log *.out

