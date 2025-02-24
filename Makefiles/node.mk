MODULE=node
SRCDIR=sources/core

SBINDIR_FILES=$(SRCDIR)/tools/oarnodecheck/oarnodecheckrun.in \
		$(SRCDIR)/tools/oarnodecheck/oarnodechecklist.in \
		$(SRCDIR)/tools/oarnodecheck/oarnodecheckquery.in

SHAREDIR_FILES= $(SRCDIR)/scripts/prologue \
		$(SRCDIR)/scripts/epilogue \
		$(SRCDIR)/tools/sshd_config.in \
		$(SRCDIR)/scripts/oar-node-service

MAN8DIR_FILES = $(SRCDIR)/man/man8/oarnodecheckrun.8

INITDIR_FILES = setup/init.d/oar-node.in

SYSTEMDDIR_FILES = setup/systemd/oar.target \
	           setup/systemd/oar-node.service.in \
	           setup/systemd/oar-nodecheck.timer \
	           setup/systemd/oar-nodecheck.service.in \
	           setup/systemd/oar-node-script.service.in

CRONDIR_FILES = setup/cron.d/oar-node.in

DEFAULTDIR_FILES = setup/default/oar-node.in \
                   setup/default/oar-node.exemple1.in

include Makefiles/shared/shared.mk

build: build_shared
	$(MAKE) -f Makefiles/man.mk build

clean: clean_shared
	$(MAKE) -f Makefiles/man.mk clean

install: install_shared
	install -d $(DESTDIR)$(OARCONFDIR)/check.d
	install -d $(DESTDIR)$(DOCDIR)/oarnodecheck
	install -m 0644 $(SRCDIR)/tools/oarnodecheck/template $(DESTDIR)$(DOCDIR)/oarnodecheck
	cp -f $(DESTDIR)$(MANDIR)/man8/oarnodecheckrun.8 $(DESTDIR)$(MANDIR)/man8/oarnodecheckquery.8
	cp -f $(DESTDIR)$(MANDIR)/man8/oarnodecheckrun.8 $(DESTDIR)$(MANDIR)/man8/oarnodechecklist.8

uninstall: uninstall_shared
	rm -f $(DESTDIR)$(MANDIR)/man8/oarnodecheckquery.8
	rm -f $(DESTDIR)$(MANDIR)/man8/oarnodechecklist.8



.PHONY: install setup uninstall build clean
