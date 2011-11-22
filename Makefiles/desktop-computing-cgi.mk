MODULE=desktop-computing-cgi
SRCDIR=sources/desktop_computing

OARDIR_BINFILES = $(SRCDIR)/oarcache.pl \
		  $(SRCDIR)/oarres.pl \
		  $(SRCDIR)/oar-cgi.pl

CRONHOURLYDIR_FILES = setup/cron.hourly/oar-desktop-computing-cgi.in

MANDIR_FILES = $(SRCDIR)/agent/man/man1/oarcache.pod

include Makefiles/shared/shared.mk

clean: clean_shared
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarcache.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarcache
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarres.pl CMD_TARGET=$(DESTDIR)$(OARDIR)/oarres 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oar-cgi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oar-cgi

build: build_shared
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarcache.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarcache
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarres.pl CMD_TARGET=$(DESTDIR)$(OARDIR)/oarres
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oar-cgi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oar-cgi

install: install_shared
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarcache.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarcache
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarres.pl CMD_TARGET=$(DESTDIR)$(OARDIR)/oarres
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oar-cgi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oar-cgi

uninstall: uninstall_shared
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarcache.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarcache
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarres.pl CMD_TARGET=$(DESTDIR)$(OARDIR)/oarres
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oar-cgi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oar-cgi

.PHONY: install setup uninstall build clean
