MODULE=poar
SRCDIR=sources/visualization_interfaces/poar

include Makefiles/shared/shared.mk

build: 
	# Nohting to do

clean:
	# Nothing to do

install: install_shared
	install -d $(DESTDIR)$(WWWDIR)
	install -d $(DESTDIR)$(WWWDIR)/poar
	cp -rf \
	    $(SRCDIR)/external \
	    $(SRCDIR)/poar.css  \
	    $(SRCDIR)/poar.js  \
	    $(SRCDIR)/resources \
  	    $(SRCDIR)/User_Manual.txt \
	    $(SRCDIR)/ext_lib \
	    $(SRCDIR)/pages \
	    $(SRCDIR)/poar.html \
	    $(SRCDIR)/Readme \
	    $(SRCDIR)/tree-nav-poar.json \
	    $(SRCDIR)/variables.js \
	    $(DESTDIR)$(WWWDIR)/poar 

uninstall: uninstall_shared
	rm -rf "$(DESTDIR)$(WWWDIR)/poar/"

.PHONY: install setup uninstall build clean
