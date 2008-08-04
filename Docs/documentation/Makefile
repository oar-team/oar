#!/usr/bin/make
#Under Debian or Ubuntu you must install the package "python-docutils"

all:
	rst2html -stg OAR-DOCUMENTATION-ADMIN.rst OAR-DOCUMENTATION-ADMIN.html
	rst2html -stg OAR-DOCUMENTATION-USER.rst OAR-DOCUMENTATION-USER.html
	rst2html -stg doc_usecases.rst doc_usecases.html
	
doc-admin:
	rst2html -stg OAR-DOCUMENTATION-ADMIN.rst OAR-DOCUMENTATION-ADMIN.html
	
doc-user:
	rst2html -stg OAR-DOCUMENTATION-USER.rst OAR-DOCUMENTATION-USER.html

latex:
	rst2newlatex OAR-DOCUMENTATION-ADMIN.rst OAR-DOCUMENTATION-ADMIN.tex
	rst2newlatex OAR-DOCUMENTATION-USER.rst OAR-DOCUMENTATION-USER.tex

pdf: latex
	pdflatex OAR-DOCUMENTATION-ADMIN.tex OAR-DOCUMENTATION-ADMIN.pdf; true
	pdflatex OAR-DOCUMENTATION-USER.tex OAR-DOCUMENTATION-USER.pdf
