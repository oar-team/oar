#! /usr/bin/make

include Makefiles/shared/shared.mk

clean:
	rm -f visualization_interfaces/apache.conf

build:
	echo "ScriptAlias /monika $(CGIDIR)/monika.cgi" > visualization_interfaces/apache.conf
	echo "ScriptAlias /drawgantt $(CGIDIR)/drawgantt.cgi" >> visualization_interfaces/apache.conf
	echo "Alias /monika.css $(WWWDIR)/monika.css" >> visualization_interfaces/apache.conf
	echo "Alias /drawgantt-files $(VARLIBDIR)/drawgantt-files" >> visualization_interfaces/apache.conf
	echo "Alias /poar $(WWWDIR)/poar" >> visualization_interfaces/apache.conf

install:
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/apache.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/apache.conf already exists, not overwriting it." ; else install -m 0644 visualization_interfaces/apache.conf $(DESTDIR)$(OARCONFDIR) ; chown $(WWWUSER) $(DESTDIR)$(OARCONFDIR)/apache.conf || /bin/true ; fi

