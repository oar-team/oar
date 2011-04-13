#! /usr/bin/make

include Makefiles/shared/shared.mk

OARDIR_BINFILES = oaradmin/oaradmin.rb \
		  oaradmin/oar_modules.rb \
		  oaradmin/oaradmin_modules.rb

MANDIR_FILES = man/man1/oaradmin.1

clean:
	$(MAKE) -f Makefiles/man.mk clean
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oaradmin.rb 

build:
	$(MAKE) -f Makefiles/man.mk build
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oaradmin.rb

install: build
	install -m 0755 -d $(DESTDIR)$(OARDIR)
	install -m 0755 -t $(DESTDIR)$(OARDIR) $(OARDIR_BINFILES)
	
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oaradmin.rb CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaradmin 
	
	install -m 0755 -d $(DESTDIR)$(MANDIR)/man1
	install -m 0644 -t $(DESTDIR)$(MANDIR)/man1 $(MANDIR_FILES)


uninstall:
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oaradmin.rb CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaradmin 
