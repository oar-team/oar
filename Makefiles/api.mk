#! /usr/bin/make

include Makefiles/shared/shared.mk

OARDIR_DATAFILES = libs/oar_apilib.pm

OARDIR_BINFILES = api/oarapi.pl

EXAMPLEDIR_FILES = api/oarapi_examples.txt \
		   api/chandler.rb

DOCDIR_FILES = api/API_INSTALL \
	       api/API_TODO

clean:
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarapi.pl 
	rm -f api/API_INSTALL api/API_TODO

build:
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarapi.pl 
	cp api/INSTALL api/API_INSTALL
	cp api/TODO api/API_TODO

install:
	install -m 0755 -d $(DESTDIR)$(OARDIR)
	install -m 0755 -t $(DESTDIR)$(OARDIR) $(OARDIR_BINFILES) 
	install -m 0644 -t $(DESTDIR)$(OARDIR) $(OARDIR_DATAFILES) 
	
	install -m 0755 -d $(DESTDIR)$(DOCDIR)
	install -m 0644 -t $(DESTDIR)$(DOCDIR) $(DOCDIR_FILES)
	
	install -m 0755 -d $(DESTDIR)$(DOCDIR)/examples
	install -m 0644 -t $(DESTDIR)$(DOCDIR)/examples $(EXAMPLEDIR_FILES)
	chmod 0755 $(DESTDIR)$(DOCDIR)/examples/chandler.rb
	
	install -m 0755 -d $(DESTDIR)$(CGIDIR)
	install -m 0750 -o $(OAROWNER) -g $(WWWUSER) -d $(DESTDIR)$(CGIDIR)/oarapi
	
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi CMD_RIGHTS=6755
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi CMD_RIGHTS=6755
	
	install -m 0755 -d $(DESTDIR)$(OARCONFDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/apache-api.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/apache-api.conf already exists, not overwriting it." ; else install -m 0600 api/apache2.conf $(DESTDIR)$(OARCONFDIR)/apache-api.conf ; chown $(WWWUSER) $(DESTDIR)$(OARCONFDIR)/apache-api.conf || /bin/true ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/api_html_header.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/api_html_header.pl already exists, not overwriting it." ; else install -m 0600 api/api_html_header.pl $(DESTDIR)$(OARCONFDIR)/api_html_header.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/api_html_header.pl || /bin/true ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/api_html_postform.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/api_html_postform.pl already exists, not overwriting it." ; else install -m 0644 api/api_html_postform.pl $(DESTDIR)$(OARCONFDIR)/api_html_postform.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/api_html_postform.pl || /bin/true ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/api_html_postform_resources.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/api_html_postform_resources.pl already exists, not overwriting it." ; else install -m 0644 api/api_html_postform_resources.pl $(DESTDIR)$(OARCONFDIR)/api_html_postform_resources.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/api_html_postform_resources.pl || /bin/true ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/api_html_postform_rule.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/api_html_postform_rule.pl already exists, not overwriting it." ; else install -m 0644 api/api_html_postform_rule.pl $(DESTDIR)$(OARCONFDIR)/api_html_postform_rule.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/api_html_postform_rule.pl || /bin/true ; fi

uninstall:
	@for file in $(OARDIR_BINFILES); do rm $(DESTDIR)$(OARDIR)/`basename $$file`; done
	@for file in $(OARDIR_DATAFILES); do rm $(DESTDIR)$(OARDIR)/`basename $$file`; done
	@for file in $(DOCDIR_FILES); do rm $(DESTDIR)$(DOCDIR)/`basename $$file`; done
	@for file in $(EXAMPLEDIR_FILES); do rm $(DESTDIR)$(DOCDIR)/examples/`basename $$file`; done
	
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi




