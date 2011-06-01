#! /usr/bin/make

include Makefiles/shared/shared.mk

SRCDIR=sources

clean:
	rm -f $(SRCDIR)/visualization_interfaces/apache.conf

build:
	echo "ScriptAlias /monika $(CGIDIR)/monika.cgi" > $(SRCDIR)/visualization_interfaces/apache.conf
	echo "ScriptAlias /drawgantt $(CGIDIR)/drawgantt.cgi" >> $(SRCDIR)/visualization_interfaces/apache.conf
	echo "Alias /monika.css $(WWWDIR)/monika.css" >> $(SRCDIR)/visualization_interfaces/apache.conf
	echo "Alias /drawgantt-files $(VARLIBDIR)/drawgantt-files" >> $(SRCDIR)/visualization_interfaces/apache.conf
	echo "Alias /poar $(WWWDIR)/poar" >> $(SRCDIR)/visualization_interfaces/apache.conf

install:
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/apache.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/apache.conf already exists, not overwriting it." ; else install -m 0644 $(SRCDIR)/visualization_interfaces/apache.conf $(DESTDIR)$(OARCONFDIR) ; chown $(WWWUSER) $(DESTDIR)$(OARCONFDIR)/apache.conf || /bin/true ; fi

uninstall:
