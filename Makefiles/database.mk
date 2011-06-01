#! /usr/bin/make

include Makefiles/shared/shared.mk

SRCDIR=sources/core

OARDIR_DATAFILES = $(SRCDIR)/database/default_data.sql \
		   $(SRCDIR)/database/mysql_default_admission_rules.sql \
		   $(SRCDIR)/database/mysql_structure.sql \
		   $(SRCDIR)/database/pg_default_admission_rules.sql \
		   $(SRCDIR)/database/pg_structure.sql

OARDIR_BINFILES = $(SRCDIR)/database/oar_mysql_db_init.pl \
		  $(SRCDIR)/database/oar_psql_db_init.pl

clean:
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oar_mysql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oar_psql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_psql_db_init

build:
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oar_mysql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oar_psql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_psql_db_init

install: install_oarbin install_oardata
	
	# Rename installed files
	mv $(DESTDIR)$(OARDIR)/oar_mysql_db_init.pl $(DESTDIR)$(OARDIR)/oar_mysql_db_init
	mv $(DESTDIR)$(OARDIR)/oar_psql_db_init.pl $(DESTDIR)$(OARDIR)/oar_psql_db_init
	
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oar_mysql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oar_psql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_psql_db_init

uninstall: uninstall_oarbin uninstall_oardata
	rm -f $(DESTDIR)$(OARDIR)/oar_mysql_db_init
	rm -f $(DESTDIR)$(OARDIR)/oar_psql_db_init
	
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oar_mysql_db_init.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oar_psql_db_init.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_psql_db_init
