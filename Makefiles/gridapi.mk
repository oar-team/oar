#! /usr/bin/make

include Makefiles/shared/shared.mk

OARDIR_BINFILES = api/oargridapi.pl

DOCDIR_FILES = api/oargridapi.txt \
	       api/API_INSTALL \
	       api/API_TODO

EXAMPLEDIR_FILES = api/oargridapi_examples.txt

clean:
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oargridapi.pl 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oargridapi.pl
	rm -f api/API_INSTALL api/API_TODO

build:
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oargridapi.pl
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oargridapi.pl
	cp api/INSTALL api/API_INSTALL
	cp api/TODO api/API_TODO

install:
	install -m 0755 -d $(DESTDIR)$(OARDIR)
	install -m 0755 -t $(DESTDIR)$(OARDIR) $(OARDIR_BINFILES)
	
	install -m 0755 -d $(DESTDIR)$(CGIDIR)
	install -m 0750 -o $(OAROWNER) -g $(WWWUSER) -d $(DESTDIR)$(CGIDIR)/oarapi
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oargridapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oargridapi.cgi CMD_RIGHTS=6755
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oargridapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oargridapi-debug.cgi CMD_RIGHTS=6755
	
	install -m 0755 -d $(DESTDIR)$(DOCDIR)
	install -m 0644 -t $(DESTDIR)$(DOCDIR) $(DOCDIR_FILES)
	
	install -m 0755 -d $(DESTDIR)$(DOCDIR)/examples
	install -m 0644 -t $(DESTDIR)$(DOCDIR)/examples $(EXAMPLEDIR_FILES)
	
	install -m 0755 -d $(DESTDIR)$(OARCONFDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/apache-gridapi.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/apache-gridapi.conf already exists, not overwriting it." ; else install -m 0600 api/apache2-grid.conf $(DESTDIR)$(OARCONFDIR)/apache-gridapi.conf ; chown $(WWWUSER) $(DESTDIR)$(OARCONFDIR)/apache-gridapi.conf || /bin/true ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/gridapi_html_header.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/gridapi_html_header.pl already exists, not overwriting it." ; else install -m 0600 api/gridapi_html_header.pl $(DESTDIR)$(OARCONFDIR)/gridapi_html_header.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/gridapi_html_header.pl || /bin/true ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/gridapi_html_postform.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/gridapi_html_postform.pl already exists, not overwriting it." ; else install -m 0644 api/gridapi_html_postform.pl $(DESTDIR)$(OARCONFDIR)/gridapi_html_postform.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/gridapi_html_postform.pl || /bin/true ; fi


uninstall:
	@for file in $(OARDIR_BINFILES); do rm -f $(DESTDIR)$(OARDIR)/`basename $$file`; done
	@for file in $(DOCDIR_FILES); do rm -f $(DESTDIR)$(DOCDIR)/`basename $$file`; done
	@for file in $(EXAMPLEDIR_FILES); do rm -f $(DESTDIR)$(DOCDIR)/examples/`basename $$file`; done
	
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oargridapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oargridapi.cgi CMD_RIGHTS=6755
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oargridapi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oarapi/oargridapi-debug.cgi CMD_RIGHTS=6755


