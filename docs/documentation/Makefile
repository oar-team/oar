#!/usr/bin/make
#Under Debian or Ubuntu you must install the package "python-docutils tetex-latex-recommended texlive-fonts-recommended make"

all: doc-admin doc-user doc-usecases doc-api doc-devel
	
doc-admin: OAR-DOCUMENTATION-ADMIN.html
	
doc-user: OAR-DOCUMENTATION-USER.html

doc-devel: oar-documentation-devel.html

doc-usecases: doc_usecases.html

doc-api: OAR-DOCUMENTATION-API-USER.html OAR-DOCUMENTATION-API-ADMIN.html OAR-DOCUMENTATION-API-DEVEL.html

latex: OAR-DOCUMENTATION-ADMIN.tex OAR-DOCUMENTATION-USER.tex OAR-DOCUMENTATION-API-USER.tex OAR-DOCUMENTATION-API-ADMIN.tex OAR-DOCUMENTATION-API-DEVEL.tex oar-documentation-devel.tex

pdf-api: OAR-DOCUMENTATION-API-USER.pdf OAR-DOCUMENTATION-API-ADMIN.pdf OAR-DOCUMENTATION-API-DEVEL.pdf oar-documentation-devel.pdf

pdf: OAR-DOCUMENTATION-ADMIN.pdf OAR-DOCUMENTATION-USER.pdf pdf-api

%.html: %.rst
	rst2html -stg $< $@

%.tex: %.rst
	rst2newlatex $< $@

%.pdf: %.tex
	pdflatex $< $@
	pdflatex $< $@

clean:
	for i in OAR-DOCUMENTATION-ADMIN OAR-DOCUMENTATION-USER OAR-DOCUMENTATION-API-USER OAR-DOCUMENTATION-API-ADMIN OAR-DOCUMENTATION-API-DEVEL doc_usecases; do rm -f $$i.pdf $$i.html $$i.tex $$i.aux $$i.log $$i.out; done

