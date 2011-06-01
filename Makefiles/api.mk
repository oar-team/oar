#! /usr/bin/make

include Makefiles/shared/shared.mk

SRCDIR= sources/api

OAR_PERLLIB = $(SRCDIR)/lib

OARDIR_BINFILES = $(SRCDIR)/oarapi.pl

EXAMPLEDIR_FILES = $(SRCDIR)/oarapi_examples.txt \
		   $(SRCDIR)/chandler.rb

DOCDIR_FILES = $(SRCDIR)/API_INSTALL \
	       $(SRCDIR)/API_TODO

clean:
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi
	rm -f $(SRCDIR)/API_INSTALL $(SRCDIR)/API_TODO

build:
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi
	cp $(SRCDIR)/INSTALL $(SRCDIR)/API_INSTALL
	cp $(SRCDIR)/TODO $(SRCDIR)/API_TODO

install: install_perllib install_oarbin install_doc install_examples
	
	chmod 0755 $(DESTDIR)$(DOCDIR)/examples/chandler.rb
	
	install -m 0750 -o $(OAROWNER) -g $(WWWUSER) -d $(DESTDIR)$(CGIDIR)/oarapi
	
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi CMD_RIGHTS=6755
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi CMD_RIGHTS=6755
	
	install -m 0755 -d $(DESTDIR)$(OARCONFDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/apache-api.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/apache-api.conf already exists, not overwriting it." ; else install -m 0600 $(SRCDIR)/apache2.conf $(DESTDIR)$(OARCONFDIR)/apache-api.conf ; chown $(WWWUSER) $(DESTDIR)$(OARCONFDIR)/apache-api.conf || /bin/true ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/api_html_header.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/api_html_header.pl already exists, not overwriting it." ; else install -m 0600 $(SRCDIR)api_html_header.pl $(DESTDIR)$(OARCONFDIR)/api_html_header.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/api_html_header.pl || /bin/true ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/api_html_postform.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/api_html_postform.pl already exists, not overwriting it." ; else install -m 0644 $(SRCDIR)/api_html_postform.pl $(DESTDIR)$(OARCONFDIR)/api_html_postform.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/api_html_postform.pl || /bin/true ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/api_html_postform_resources.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/api_html_postform_resources.pl already exists, not overwriting it." ; else install -m 0644 $(SRCDIR)/api_html_postform_resources.pl $(DESTDIR)$(OARCONFDIR)/api_html_postform_resources.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/api_html_postform_resources.pl || /bin/true ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/api_html_postform_rule.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/api_html_postform_rule.pl already exists, not overwriting it." ; else install -m 0644 $(SRCDIR)/api_html_postform_rule.pl $(DESTDIR)$(OARCONFDIR)/api_html_postform_rule.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/api_html_postform_rule.pl || /bin/true ; fi


uninstall: uninstall_perllib uninstall_oarbin uninstall_doc uninstall_examples
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi




