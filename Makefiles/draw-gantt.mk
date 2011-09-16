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
	install $(SRCDIR)/drawgantt.cgi.in $(DESTDIR)$(CGIDIR)
	
	install -d $(DESTDIR)$(SHAREDIR)/drawgantt-files/Icons
	install -m 0644  $(SRCDIR)/Icons/*.png $(DESTDIR)$(SHAREDIR)/drawgantt-files/Icons 
	
	install -d $(DESTDIR)$(SHAREDIR)/drawgantt-files/js
	install -m 0644  $(SRCDIR)/js/*.js $(DESTDIR)$(SHAREDIR)/drawgantt-files/js 

setup:  setup_shared
	chown $(WWWUSER) $(DESTDIR)$(OARHOMEDIR)/drawgantt-files/cache
	chmod 0644       $(DESTDIR)$(SHAREDIR)/drawgantt-files/Icons/*.png
	chmod 0644       $(DESTDIR)$(SHAREDIR)/drawgantt-files/js/*.js

uninstall: uninstall_shared
	rm -f \
	    $(DESTDIR)$(CGIDIR)/drawgantt.cgi \
	    $(DESTDIR)$(SHAREDIR)/drawgantt-files/Icons/*.png \
	    $(DESTDIR)$(SHAREDIR)/drawgantt-files/js/*.js
	
	-rmdir \
	    $(DESTDIR)$(OARHOMEDIR)/drawgantt-files/cache \
	    $(DESTDIR)$(SHAREDIR)/drawgantt-files/js \
	    $(DESTDIR)$(SHAREDIR)/drawgantt-files/Icons \
	    $(DESTDIR)$(SHAREDIR)/drawgantt-files

.PHONY: install setup uninstall build clean

