MODULE=drawgantt-svg
SRCDIR=sources/visualization_interfaces/DrawGantt-SVG

EXAMPLEDIR_FILES=$(SRCDIR)/drawgantt-svg-config.inc.php

PROCESS_TEMPLATE_FILES=$(SRCDIR)/drawgantt-svg.php.in

include Makefiles/shared/shared.mk

clean: clean_shared
	# Nothing to do

build: build_shared
	# Nothing to do

install: install_shared
	install -d $(DESTDIR)$(WWWDIR)/drawgantt-svg
	install -m 0644  $(SRCDIR)/drawgantt.html $(DESTDIR)$(WWWDIR)/drawgantt-svg/drawgantt.html
	install -m 0644  $(SRCDIR)/drawgantt-nav.html $(DESTDIR)$(WWWDIR)/drawgantt-svg/drawgantt-nav.html
	install -m 0644  $(SRCDIR)/drawgantt-svg.php $(DESTDIR)$(WWWDIR)/drawgantt-svg/drawgantt-svg.php

uninstall: uninstall_shared
	rm -f \
	    $(DESTDIR)$(WWWDIR)/drawgantt-svg/drawgantt.html \
	    $(DESTDIR)$(WWWDIR)/drawgantt-svg/drawgantt-nav.html \
	    $(DESTDIR)$(WWWDIR)/drawgantt-svg/drawgantt-svg.php
	
	-rmdir \
	    $(DESTDIR)$(WWWDIR)/drawgantt-svg

.PHONY: install setup uninstall build clean

