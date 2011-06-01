#! /usr/bin/make

include Makefiles/shared/shared.mk

SRCDIR=sources/desktop_computing

OARDIR_BINFILES = $(SRCDIR)/oarcache.pl \
		  $(SRCDIR)/oarres.pl \
		  $(SRCDIR)/oar-cgi.pl


clean:
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarcache.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarcache
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarres.pl CMD_TARGET=$(DESTDIR)$(OARDIR)/oarres 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oar-cgi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oar-cgi

build:
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarcache.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarcache
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarres.pl CMD_TARGET=$(DESTDIR)$(OARDIR)/oarres
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oar-cgi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oar-cgi

install: install_oarbin
	
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	install -d -m 0755 $(DESTDIR)$(CGIDIR)
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarcache.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarcache
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarres.pl CMD_TARGET=$(DESTDIR)$(OARDIR)/oarres CMD_RIGHTS=6755
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oar-cgi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oar-cgi CMD_GROUP=$(WWWUSER)

uninstall: uninstall_oarbin
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarcache.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarcache
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarres.pl CMD_TARGET=$(DESTDIR)$(OARDIR)/oarres
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oar-cgi.pl CMD_TARGET=$(DESTDIR)$(CGIDIR)/oar-cgi

