MODULE=api


SRCDIR= sources/api

OAR_PERLLIB = $(SRCDIR)/lib

OARDIR_BINFILES = $(SRCDIR)/oarapi.pl

EXAMPLEDIR_FILES = $(SRCDIR)/oarapi_examples.txt \
		   $(SRCDIR)/chandler.rb \
		   $(SRCDIR)/apache2.conf.in \
		   $(SRCDIR)/api_html_header.pl \
		   $(SRCDIR)/api_html_postform.pl \
		   $(SRCDIR)/api_html_postform_resources.pl \
		   $(SRCDIR)/api_html_postform_rule.pl \
		   $(SRCDIR)/INSTALL \
		   $(SRCDIR)/TODO

PROCESS_TEMPLATE_FILES = $(DESTDIR)$(EXAMPLEDIR)/apache2.conf.in

include Makefiles/shared/shared.mk

clean:
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi

build:
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi

install: install_shared
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi

setup: setup_shared
	chmod 0755 $(DESTDIR)$(EXAMPLEDIR)/chandler.rb
	chown $(OAROWNER):$(WWWUSER) $(DESTDIR)$(CGIDIR)/oarapi
	chmod 0750 $(DESTDIR)$(CGIDIR)/oarapi
	$(OARDO_SETUP) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi CMD_RIGHTS=6755
	$(OARDO_SETUP) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi CMD_RIGHTS=6755

uninstall: uninstall_shared
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi


.PHONY: install setup uninstall build clean


