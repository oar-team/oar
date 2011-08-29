MODULE=monika
SRCDIR=sources/visualization_interfaces/Monika

OAR_PERLLIB=$(SRCDIR)/lib

EXAMPLEDIR_FILES= $(SRCDIR)/monika.conf.in \
		  $(SRCDIR)/userInfos.cgi

PROCESS_TEMPLATE_FILES= $(DESTDIR)$(CGIDIR)/monika.cgi.in \
			$(DESTDIR)$(EXAMPLEDIR)/monika.conf.in

include Makefiles/shared/shared.mk

clean:
	# Nothing to do

build:
	# Nothing to do

install: install_before install_shared

install_before:
	install -d $(DESTDIR)$(CGIDIR)
	install -t $(DESTDIR)$(CGIDIR) $(SRCDIR)/monika.cgi.in
	
	install         -d $(DESTDIR)$(WWWDIR)
	install -m 0644 -t $(DESTDIR)$(WWWDIR) $(SRCDIR)/monika.css

setup: setup_shared
	chmod 0644 $(DESTDIR)$(WWWDIR)/monika.css

uninstall: uninstall_shared
	@rm -f \
	    $(DESTDIR)$(CGIDIR)/monika.cgi \
	    $(DESTDIR)$(WWWDIR)/monika.css
	
	@rmdir --ignore-fail-on-non-empty \
	    $(DESTDIR)$(EXAMPLEDIR) || true

.PHONY: install setup uninstall build clean
