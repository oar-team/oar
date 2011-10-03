MODULE=desktop-computing-cgi
SRCDIR=sources/desktop_computing

OARDIR_BINFILES = $(SRCDIR)/oarcache.pl \
		  $(SRCDIR)/oarres.pl \
		  $(SRCDIR)/oar-cgi.pl

PROCESS_TEMPLATE_FILES = $(DESTDIR)$(EXAMPLEDIR)/cron.hourly/oar-desktop-computing-cgi.in

include Makefiles/shared/shared.mk

clean:
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarcache.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarcache
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarres.pl CMD_TARGET=$(DESTDIR)$(OARDIR)/oarres 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oar-cgi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oar-cgi

build:
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarcache.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarcache
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarres.pl CMD_TARGET=$(DESTDIR)$(OARDIR)/oarres
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oar-cgi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oar-cgi

install: install_before install_shared

install_before:
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarcache.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarcache
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarres.pl CMD_TARGET=$(DESTDIR)$(OARDIR)/oarres
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oar-cgi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oar-cgi
	
	install -d $(DESTDIR)$(EXAMPLEDIR)/cron.hourly
	install -m 0644  setup/cron.hourly/oar-desktop-computing-cgi.in $(DESTDIR)$(EXAMPLEDIR)/cron.hourly 

uninstall: uninstall_shared
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarcache.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarcache
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarres.pl CMD_TARGET=$(DESTDIR)$(OARDIR)/oarres
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oar-cgi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oar-cgi
	rm -rf $(DESTDIR)$(EXAMPLEDIR)

.PHONY: install setup uninstall build clean
