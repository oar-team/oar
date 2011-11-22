MODULE=node
SRCDIR=sources/core

OARDIR_BINFILES=$(SRCDIR)/tools/oarnodecheck/oarnodecheckrun.in
BINDIR_FILES=$(SRCDIR)/tools/oarnodecheck/oarnodechecklist.in \
	     $(SRCDIR)/tools/oarnodecheck/oarnodecheckquery.in

EXAMPLEDIR_FILES= $(SRCDIR)/scripts/prologue \
		  $(SRCDIR)/scripts/epilogue \
		  $(SRCDIR)/tools/sshd_config.in

MANDIR_FILES = $(SRCDIR)/man/man1/oarnodechecklist.1 \
	       $(SRCDIR)/man/man1/oarnodecheckquery.1

INITDIR_FILES = setup/init.d/oar-node.in

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
	install -m 0644 sources/core/tools/oarnodecheck/README $(DESTDIR)$(DOCDIR)/oarnodecheck
	install -m 0644 sources/core/tools/oarnodecheck/template $(DESTDIR)$(DOCDIR)/oarnodecheck
	
uninstall: uninstall_shared
	


.PHONY: install setup uninstall build clean
