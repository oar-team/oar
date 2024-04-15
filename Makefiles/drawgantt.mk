MODULE=drawgantt
SRCDIR=sources/visualization_interfaces/DrawGantt

SHAREDIR_FILES=$(SRCDIR)/drawgantt.conf

PROCESS_TEMPLATE_FILES= $(SRCDIR)/drawgantt.conf.in \
			$(SRCDIR)/drawgantt.cgi.in

include Makefiles/shared/shared.mk

clean: clean_shared
	# Nothing to do

build: build_shared
	# Nothing to do

install: install_shared
	install -d $(DESTDIR)$(CGIDIR)
	install -m 0755 $(SRCDIR)/drawgantt.cgi $(DESTDIR)$(CGIDIR)

	install -d $(DESTDIR)$(WWWDIR)/drawgantt-files/Icons
	install -m 0644  $(SRCDIR)/Icons/*.png $(DESTDIR)$(WWWDIR)/drawgantt-files/Icons

uninstall: uninstall_shared
	rm -f \
	    $(DESTDIR)$(CGIDIR)/drawgantt.cgi \
	    $(DESTDIR)$(WWWDIR)/drawgantt-files/Icons/*.png \

	-rmdir \
	    $(DESTDIR)$(OARHOMEDIR)/drawgantt-files/cache \
	    $(DESTDIR)$(WWWDIR)/drawgantt-files/Icons \
	    $(DESTDIR)$(WWWDIR)/drawgantt-files

.PHONY: install setup uninstall build clean

