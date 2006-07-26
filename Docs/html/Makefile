#!/usr/bin/make

all:
	rst2html -stg OAR-DOCUMENTATION.rst OAR-DOCUMENTATION.html
	@alsaplayer -i text /usr/share/sounds/gnibbles/reverse.wav 
	@echo Make finished

latex:
	rst2newlatex OAR-DOCUMENTATION.rst OAR-DOCUMENTATION.tex

pdf: latex
	pdflatex OAR-DOCUMENTATION.tex OAR-DOCUMENTATION.pdf
	pdflatex OAR-DOCUMENTATION.tex OAR-DOCUMENTATION.pdf

