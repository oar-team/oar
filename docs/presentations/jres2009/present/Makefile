all: pdf view
pdf:
	pdflatex oar_jres2009.tex
	pdflatex oar_jres2009.tex
view:	
	xpdf -geometry 800x600 -z page oar_jres2009.pdf
clean:
	rm -f *.aux *.nav *.out *.snm *.log *.toc *.xhtml oar_jres2009.pdf
