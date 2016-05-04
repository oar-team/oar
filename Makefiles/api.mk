MODULE=api


SRCDIR= sources/api

OAR_PERLLIB = $(SRCDIR)/lib

OARDIR_BINFILES = $(SRCDIR)/oarapi.pl

SHAREDIR_FILES = $(SRCDIR)/apache2.conf.in \
		   $(SRCDIR)/api_html_header.pl \
		   $(SRCDIR)/api_html_postform.pl \
		   $(SRCDIR)/api_html_postform_resources.pl \
		   $(SRCDIR)/api_html_postform_rule.pl \
		   $(SRCDIR)/stress_factor.sh

EXAMPLEDIR_FILES = $(SRCDIR)/examples/oarapi_examples.txt \
		   $(SRCDIR)/examples/chandler.rb \
		   $(SRCDIR)/examples/chandler_timesharing.rb \
		   $(SRCDIR)/INSTALL \
		   $(SRCDIR)/TODO

include Makefiles/shared/shared.mk

clean: clean_shared
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi

build: build_shared
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi

install: install_shared
	install -d $(DESTDIR)$(CGIDIR)
	install -d $(DESTDIR)$(CGIDIR)/oarapi
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi

uninstall: uninstall_shared
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi
	-rmdir \
	    $(DESTDIR)$(CGIDIR)/oarapi
	-rmdir \
	    $(DESTDIR)$(CGIDIR)


.PHONY: install setup uninstall build clean


