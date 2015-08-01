MODULE=monika
SRCDIR=sources/visualization_interfaces/Monika

OAR_PERLLIB=$(SRCDIR)/lib

SHAREDIR_FILES= $(SRCDIR)/monika.conf.in \
		  $(SRCDIR)/userInfos.cgi \
		  $(SRCDIR)/monika.cgi.in \


WWWDIR_FILES = $(SRCDIR)/monika.css

include Makefiles/shared/shared.mk

clean: clean_shared
	# Nothing to do

build: build_shared
	# Nothing to do

install: install_shared
	install -d $(DESTDIR)$(CGIDIR)/monika
	install -m 0644  $(SRCDIR)/monika.cgi $(DESTDIR)$(CGIDIR)/monika/monika.cgi

uninstall: uninstall_shared
	rm -f \
	    $(DESTDIR)$(CGIDIR)/monika/monika.cgi
	-rmdir \
	    $(DESTDIR)$(CGIDIR)/monika

.PHONY: install setup uninstall build clean
