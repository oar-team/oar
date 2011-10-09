MODULE=database
SRCDIR=sources/core

OARDIR_DATAFILES = $(SRCDIR)/database/default_data.sql \
		   $(SRCDIR)/database/mysql_default_admission_rules.sql \
		   $(SRCDIR)/database/mysql_structure.sql \
		   $(SRCDIR)/database/pg_default_admission_rules.sql \
		   $(SRCDIR)/database/pg_structure.sql

include Makefiles/shared/shared.mk

clean:
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oar_mysql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oar_psql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_psql_db_init

build:
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oar_mysql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oar_psql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_psql_db_init CMD_USERTOBECOME=root

install: install_shared
	install $(SRCDIR)/database/oar_mysql_db_init.pl $(DESTDIR)$(OARDIR)/oar_mysql_db_init
	install $(SRCDIR)/database/oar_psql_db_init.pl $(DESTDIR)$(OARDIR)/oar_psql_db_init
	
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oar_mysql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oar_psql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_psql_db_init

setup: setup_shared
	$(OARDO_SETUP) CMD_WRAPPER=$(OARDIR)/oar_mysql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	$(OARDO_SETUP) CMD_WRAPPER=$(OARDIR)/oar_psql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_psql_db_init
	
	chmod 0755 $(DESTDIR)$(OARDIR)/oar_mysql_db_init
	chmod 0755 $(DESTDIR)$(OARDIR)/oar_psql_db_init

uninstall: uninstall_shared
	rm -f $(DESTDIR)$(OARDIR)/oar_mysql_db_init
	rm -f $(DESTDIR)$(OARDIR)/oar_psql_db_init
	
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oar_mysql_db_init.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oar_psql_db_init.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_psql_db_init

.PHONY: install setup uninstall build clean

