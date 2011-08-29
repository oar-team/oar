#! /usr/bin/make

include Makefiles/shared/shared.mk

SRCDIR=sources/core

OAR_PERLLIB= $(SRCDIR)/libs/lib

OARDIR_BINFILES = $(SRCDIR)/qfunctions/oarnodesetting \
		  $(SRCDIR)/tools/sentinelle.pl

MANDIR_FILES = $(SRCDIR)/man/man1/oarnodesetting.1

clean:
	$(MAKE) -f Makefiles/man.mk clean
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting


build:
	$(MAKE) -f Makefiles/man.mk build
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting


install: install_oarbin install_perllib
	
	install -m 0755 -d $(DESTDIR)$(SBINDIR)
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting
	
	install -m 0755 -d $(DESTDIR)$(OARCONFDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/oarnodesetting_ssh ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/oarnodesetting_ssh already exists, not overwriting it." ; else install -m 0755 $(SRCDIR)/tools/oarnodesetting_ssh $(DESTDIR)$(OARCONFDIR); fi
	perl -i -pe "s#^OARNODESETTINGCMD=.*#OARNODESETTINGCMD=$(SBINDIR)/oarnodesetting#" $(DESTDIR)$(OARCONFDIR)/oarnodesetting_ssh
	@if [ -f $(DESTDIR)$(OARCONFDIR)/update_cpuset_id.sh ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/update_cpuset_id.sh already exists, not overwriting it." ; else install -m 0755 $(SRCDIR)/tools/update_cpuset_id.sh $(DESTDIR)$(OARCONFDIR); fi
	perl -i -pe "s#^OARNODESETTINGCMD=.*#OARNODESETTINGCMD=$(SBINDIR)/oarnodesetting#" $(DESTDIR)$(OARCONFDIR)/update_cpuset_id.sh
	perl -i -pe "s#^OARNODESCMD=.*#OARNODESCMD=$(BINDIR)/oarnodes#" $(DESTDIR)$(OARCONFDIR)/update_cpuset_id.sh
	
	install -m 0755 -d $(DESTDIR)$(MANDIR)/man1
	install -m 0644 -t $(DESTDIR)$(MANDIR)/man1 $(MANDIR_FILES)


uninstall: uninstall_oarbin uninstall_perllib
	@for file in $(MANDIR_FILES); do rm -f $(DESTDIR)$(MANDIR)/man1/`basename $$file`; done
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting



