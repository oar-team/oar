#! /usr/bin/make

include Makefiles/shared/shared.mk

DRAWGANTT_DIR=visualization_interfaces/DrawGantt

clean:
	# Nothing to do

build: 
	# Nothing to do

install:
	install -d -m 0755 $(DESTDIR)$(CGIDIR)
	install -d -m 0755 $(DESTDIR)$(WWWDIR)
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)
	install -d -m 0755 $(DESTDIR)$(VARLIBDIR)
	install -d -m 0755 $(DESTDIR)$(VARLIBDIR)/drawgantt-files/Icons
	install -d -m 0755 $(DESTDIR)$(VARLIBDIR)/drawgantt-files/js
	install -d -m 0755 $(DESTDIR)$(VARLIBDIR)/drawgantt-files/cache
	-chown $(WWWUSER) $(DESTDIR)$(VARLIBDIR)/drawgantt-files/cache
	
	install -m 0755 $(DRAWGANTT_DIR)/drawgantt.cgi $(DESTDIR)$(CGIDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/drawgantt.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/drawgantt.conf already exists, not overwriting it." ; else install -m 0600 $(DRAWGANTT_DIR)/drawgantt.conf $(DESTDIR)$(OARCONFDIR) ; chown $(WWWUSER) $(DESTDIR)$(OARCONFDIR)/drawgantt.conf || /bin/true ; perl -i -pe "s#^web_root: .*#web_root: '$(VARLIBDIR)'#" $(DESTDIR)$(OARCONFDIR)/drawgantt.conf ; perl -i -pe "s#^directory: .*#directory: 'drawgantt-files'#" $(DESTDIR)$(OARCONFDIR)/drawgantt.conf ; fi
	install -m 0644 $(DRAWGANTT_DIR)/Icons/*.png $(DESTDIR)$(VARLIBDIR)/drawgantt-files/Icons
	install -m 0644 $(DRAWGANTT_DIR)/js/*.js $(DESTDIR)$(VARLIBDIR)/drawgantt-files/js

uninstall:
	rm -f \
	    $(DESTDIR)$(CGIDIR)/drawgantt.cgi \
	    $(DESTDIR)$(VARLIBDIR)/drawgantt-files/Icons/*.png \
	    $(DESTDIR)$(VARLIBDIR)/drawgantt-files/js/*.js
	
	rmdir --ignore-fail-on-non-empty \
	    $(DESTDIR)$(VARLIBDIR)/drawgantt-files/cache \
	    $(DESTDIR)$(VARLIBDIR)/drawgantt-files/js \
	    $(DESTDIR)$(VARLIBDIR)/drawgantt-files/Icons \
	    $(DESTDIR)$(VARLIBDIR)/drawgantt-files

