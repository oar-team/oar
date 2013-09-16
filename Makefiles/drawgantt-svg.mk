MODULE=drawgantt-svg
SRCDIR=sources/visualization_interfaces/DrawGantt-SVG

EXAMPLEDIR_FILES=$(SRCDIR)/drawgantt-config.inc.php

PROCESS_TEMPLATE_FILES=$(SRCDIR)/drawgantt-svg.php.in \
			$(SRCDIR)/drawgantt.php.in

include Makefiles/shared/shared.mk

clean: clean_shared
	# Nothing to do

build: build_shared
	# Nothing to do

install: install_shared
	install -d $(DESTDIR)$(WWWDIR)/drawgantt-svg
	install -m 0644  $(SRCDIR)/drawgantt.php $(DESTDIR)$(WWWDIR)/drawgantt-svg/drawgantt.php
	install -m 0644  $(SRCDIR)/drawgantt-svg.php $(DESTDIR)$(WWWDIR)/drawgantt-svg/drawgantt-svg.php
	ln -sf drawgantt.php $(DESTDIR)$(WWWDIR)/drawgantt-svg/index.php

uninstall: uninstall_shared
	rm -f \
	    $(DESTDIR)$(WWWDIR)/drawgantt-svg/drawgantt.php \
	    $(DESTDIR)$(WWWDIR)/drawgantt-svg/drawgantt-svg.php \
	    $(DESTDIR)$(WWWDIR)/drawgantt-svg/index.php
	
	-rmdir \
	    $(DESTDIR)$(WWWDIR)/drawgantt-svg

.PHONY: install setup uninstall build clean

