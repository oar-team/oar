MODULE=tools
SRCDIR=sources/core

OARDIR_BINFILES = $(SRCDIR)/qfunctions/oaradmin/oaradmin.rb \
		  $(SRCDIR)/qfunctions/oaradmin/oar_modules.rb \
		  $(SRCDIR)/qfunctions/oaradmin/oaradmin_modules.rb

MANDIR_FILES = $(SRCDIR)/man/man1/oaradmin.1

include Makefiles/shared/shared.mk

clean: clean_shared
	$(MAKE) -f Makefiles/man.mk clean
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oaradmin.rb CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaradmin

build: build_shared
	$(MAKE) -f Makefiles/man.mk build
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oaradmin.rb CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaradmin

install: build install_shared
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oaradmin.rb CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaradmin

uninstall: uninstall_shared
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oaradmin.rb CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaradmin

.PHONY: install setup uninstall build clean
