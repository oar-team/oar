#! /usr/bin/make

include Makefiles/shared/shared.mk

SRCDIR=sources/core

OARDIR_BINFILES = $(SRCDIR)/qfunctions/oaradmin/oaradmin.rb \
		  $(SRCDIR)/qfunctions/oaradmin/oar_modules.rb \
		  $(SRCDIR)/qfunctions/oaradmin/oaradmin_modules.rb

MANDIR_FILES = $(SRCDIR)/man/man1/oaradmin.1

clean:
	$(MAKE) -f Makefiles/man.mk clean
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oaradmin.rb CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaradmin 

build:
	$(MAKE) -f Makefiles/man.mk build
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oaradmin.rb CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaradmin 

install: build install_oarbin install_man1
	install -m 0755 -d $(DESTDIR)$(OARDIR)
	install -m 0755 -t $(DESTDIR)$(OARDIR) $(OARDIR_BINFILES)
	
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oaradmin.rb CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaradmin 

uninstall: uninstall_oarbin uninstall_man1
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oaradmin.rb CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaradmin 
