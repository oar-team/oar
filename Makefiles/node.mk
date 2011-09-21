MODULE=node
SRCDIR=sources/core

OARDIR_BINFILES=$(SRCDIR)/tools/oarnodecheck/oarnodecheckrun.in
BINDIR_FILES=$(SRCDIR)/tools/oarnodecheck/oarnodechecklist.in \
	     $(SRCDIR)/tools/oarnodecheck/oarnodecheckquery.in

EXAMPLEDIR_FILES= $(SRCDIR)/scripts/prologue \
		  $(SRCDIR)/scripts/epilogue \
		  $(SRCDIR)/tools/sshd_config.in

PROCESS_TEMPLATE_FILES = $(DESTDIR)$(EXAMPLEDIR)/init.d/oar-node.in \
		 $(DESTDIR)$(EXAMPLEDIR)/cron.d/oar-node.in \
		 $(DESTDIR)$(EXAMPLEDIR)/default/oar-node.in \
		 $(DESTDIR)$(EXAMPLEDIR)/sshd_config.in \
		 $(DESTDIR)$(OARDIR)/oarnodecheckrun.in \
		 $(DESTDIR)$(BINDIR)/oarnodechecklist.in \
		 $(DESTDIR)$(BINDIR)/oarnodecheckquery.in 

include Makefiles/shared/shared.mk

build:
	$(MAKE) -f Makefiles/man.mk build

clean:
	$(MAKE) -f Makefiles/man.mk clean

install: build install_before install_shared

install_before:
	install -d $(DESTDIR)$(OARCONFDIR)/check.d
	
	install -d $(DESTDIR)$(EXAMPLEDIR)/init.d	
	install setup/init.d/oar-node.in $(DESTDIR)$(EXAMPLEDIR)/init.d
	
	install -d $(DESTDIR)$(EXAMPLEDIR)/default
	install -m 0644  setup/default/oar-node.in $(DESTDIR)$(EXAMPLEDIR)/default
		
	install -d $(DESTDIR)$(EXAMPLEDIR)/cron.d
	install -m 0644  setup/cron.d/oar-node.in $(DESTDIR)$(EXAMPLEDIR)/cron.d
	
	install -d $(DESTDIR)$(DOCDIR)/oarnodecheck 
	install -m 0644  sources/core/tools/oarnodecheck/README $(DESTDIR)$(DOCDIR)/oarnodecheck
	install -m 0644  sources/core/tools/oarnodecheck/template $(DESTDIR)$(DOCDIR)/oarnodecheck
	
setup: setup_shared
	for file in $(OARCONFDIR_FILES); do chmod 0600 $(DESTDIR)$(OARCONFDIR)/`basename $$file`; done
	for file in $(OARCONFDIR_FILES); do chown $(OAROWNER):$(ROOTGROUP) $(DESTDIR)$(OARCONFDIR)/`basename $$file`; done
	
uninstall: uninstall_shared
	rm -rf $(DESTDIR)$(EXAMPLEDIR)
	


.PHONY: install setup uninstall build clean
