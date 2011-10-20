MODULE=database
SRCDIR=sources/core

MANDIR_FILES = $(SRCDIR)/man/man1/oar-database.pod.in

BINDIR_FILES = $(SRCDIR)/database/oar-database.in

include Makefiles/shared/shared.mk

clean: clean_shared

build: build_shared

install: install_shared
	install -d $(DESTDIR)$(OARDIR)/database/
	cp -f $(SRCDIR)/database/*.sql $(DESTDIR)$(OARDIR)/database/

uninstall: uninstall_shared
	rm -f $(DESTDIR)$(OARDIR)/oar_mysql_db_init
	rm -f $(DESTDIR)$(OARDIR)/oar_psql_db_init
	rm -rf $(DESTDIR)$(OARDIR)/database
	
.PHONY: install setup uninstall build clean

