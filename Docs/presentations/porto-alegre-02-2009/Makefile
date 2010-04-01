all: pdf view
pdf:
	pdflatex oar_brasil2010.tex
	pdflatex oar_brasil2010.tex
view:	
	xpdf -geometry 800x600 -z page oar_brasil2010.pdf
clean:
	rm -f *.aux *.nav *.out *.snm *.log *.toc *.xhtml oar_brasil2010.pdf
