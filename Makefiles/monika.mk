#! /usr/bin/make

include Makefiles/shared/shared.mk

MONIKA_DIR=visualization_interfaces/Monika

clean:
	# Nothing to do

build:
	# Nothing to do

install:
	install -d -m 0755 $(DESTDIR)$(DOCDIR)/examples
	install -d -m 0755 $(DESTDIR)$(CGIDIR)
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)
	install -d -m 0755 $(DESTDIR)$(WWWDIR)
	install -d -m 0755 $(DESTDIR)$(PERLLIBDIR)/monika
	
	@if [ -f $(DESTDIR)$(OARCONFDIR)/monika.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/monika.conf already exists, not overwriting it." ; else install -m 0600 $(MONIKA_DIR)/monika.conf $(DESTDIR)$(OARCONFDIR) ; chown $(WWWUSER) $(DESTDIR)$(OARCONFDIR)/monika.conf || /bin/true ; perl -i -pe "s#^css_path = .*#css_path = $(WWW_ROOTDIR)/monika.css#" $(DESTDIR)$(OARCONFDIR)/monika.conf; fi
	install -m 0755 $(MONIKA_DIR)/monika.cgi $(DESTDIR)$(CGIDIR)
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARCONFDIR)'\;#;;" $(DESTDIR)$(CGIDIR)/monika.cgi
	install -m 0755 $(MONIKA_DIR)/userInfos.cgi $(DESTDIR)$(DOCDIR)/examples
	install -m 0644 $(MONIKA_DIR)/monika.css $(DESTDIR)$(WWWDIR)
	install -m 0644 $(MONIKA_DIR)/monika/VERSION $(DESTDIR)$(PERLLIBDIR)/monika
	install -m 0755 $(MONIKA_DIR)/monika/*.pm $(DESTDIR)$(PERLLIBDIR)/monika

uninstall:
	rm -f \
	    $(DESTDIR)$(CGIDIR)/monika.cgi \
	    $(DESTDIR)$(DOCDIR)/examples/userInfos.cgi \
	    $(DESTDIR)$(WWWDIR)/monika.css \
	    $(DESTDIR)$(PERLLIBDIR)/monika/VERSION \
	    $(DESTDIR)$(PERLLIBDIR)/monika/*.pm
	
	rmdir --ignore-fail-on-non-empty \
	    $(DESTDIR)$(PERLLIBDIR)/monika \
	    $(DESTDIR)$(DOCDIR)/examples
