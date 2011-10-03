MODULE=draw-gantt
SRCDIR=sources/visualization_interfaces/DrawGantt

EXAMPLEDIR_FILES=$(SRCDIR)/drawgantt.conf.in

PROCESS_TEMPLATE_FILES= $(DESTDIR)$(EXAMPLEDIR)/drawgantt.conf.in \
			$(DESTDIR)$(CGIDIR)/drawgantt.cgi.in

include Makefiles/shared/shared.mk

clean:
	# Nothing to do

build: 
	# Nothing to do

install: install_before install_shared

install_before:
	install -d $(DESTDIR)$(OARHOMEDIR)/drawgantt-files/cache
	
	install -d $(DESTDIR)$(CGIDIR)
	install -m 0755 $(SRCDIR)/drawgantt.cgi.in $(DESTDIR)$(CGIDIR)
	
	install -d $(DESTDIR)$(WWWDIR)/drawgantt-files/Icons
	install -m 0644  $(SRCDIR)/Icons/*.png $(DESTDIR)$(WWWDIR)/drawgantt-files/Icons 
	
	install -d $(DESTDIR)$(WWWDIR)/drawgantt-files/js
	install -m 0644  $(SRCDIR)/js/*.js $(DESTDIR)$(WWWDIR)/drawgantt-files/js 

uninstall: uninstall_shared
	rm -f \
	    $(DESTDIR)$(CGIDIR)/drawgantt.cgi \
	    $(DESTDIR)$(WWWDIR)/drawgantt-files/Icons/*.png \
	    $(DESTDIR)$(WWWDIR)/drawgantt-files/js/*.js
	
	-rmdir \
	    $(DESTDIR)$(OARHOMEDIR)/drawgantt-files/cache \
	    $(DESTDIR)$(WWWDIR)/drawgantt-files/js \
	    $(DESTDIR)$(WWWDIR)/drawgantt-files/Icons \
	    $(DESTDIR)$(WWWDIR)/drawgantt-files

.PHONY: install setup uninstall build clean

