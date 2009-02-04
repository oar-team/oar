SITE = intra-id:/www-id/sites/oar/www
INDEX = output/index.html
MANUALPAGE = src/docs/manual.page
TODOPAGE = src/docs/TODO.page

all: html

$(MANUALPAGE):
	cd rst-doc-oar; ./generate_manual.page

$(TODOPAGE):
	cd rst-doc-oar; ./generate_TODO.page

output/%.html: $(MANUALPAGE) 
#	export LC_ALL=C;webgen run
	export LC_ALL=C;ruby -I ./webgen-0.3.8/lib ./webgen-0.3.8/bin/webgen run
	mkdir output/docs/bib
	 \cp bib/oar_bib.html output/docs/bib/
	sed s/\<title\>Home/\<title\>OAR/ output/index.html > /tmp/index.html.tmp
	mv /tmp/index.html.tmp  output/index.html 
	cp src/docs/*.svg output/docs/
	cp src/docs/*.pdf output/docs/
	cp src/CHANGELOG output/

upload: $(INDEX)  
	scp -r output/* $(SITE)
	touch upload

fastupload: $(INDEX)
	mv output/images images
	scp -r output/* $(SITE)
	touch upload
	mv images output/images 

html: $(INDEX)

clean:
	\rm -rf output/* update $(MANUALPAGE) $(TODOPAGE) oar_bib.html  oar.html
