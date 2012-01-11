#!/usr/bin/make
#Under Debian or Ubuntu you must install the package "python-docutils"

RST2LATEX := $(shell if which "rst2newlatex" > /dev/null 2>/dev/null; then echo "rst2newlatex"; else echo "rst2latex"; fi)
RST2HTML := rst2html
PDFLATEX := pdflatex

all: doc-admin doc-user doc-usecases doc-api
	
doc-admin: OAR-DOCUMENTATION-ADMIN.html
	
doc-user: OAR-DOCUMENTATION-USER.html

doc-usecases: doc_usecases.html

doc-api: OAR-DOCUMENTATION-API.html

latex: OAR-DOCUMENTATION-ADMIN.tex OAR-DOCUMENTATION-USER.tex OAR-DOCUMENTATION-API.tex

pdf: OAR-DOCUMENTATION-ADMIN.pdf OAR-DOCUMENTATION-USER.pdf OAR-DOCUMENTATION-API.pdf

%.html: %.rst
	$(RST2HTML) -stg $< $@

%.tex: %.rst
	$(RST2LATEX) $< $@

%.pdf: %.tex
	$(PDFLATEX) $< $@
	$(PDFLATEX) $< $@

clean:
	rm -f *.pdf *.html *.tex *.aux *.log *.out *.toc

