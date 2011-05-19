#! /usr/bin/make

include Makefiles/shared/shared.mk

OARDIR_DATAFILES = database/default_data.sql \
		   database/mysql_default_admission_rules.sql \
		   database/mysql_structure.sql \
		   database/pg_default_admission_rules.sql \
		   database/pg_structure.sql

OARDIR_BINFILES = database/oar_mysql_db_init.pl \
		  database/oar_psql_db_init.pl

clean:
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oar_mysql_db_init 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oar_psql_db_init 

build:
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oar_mysql_db_init
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oar_psql_db_init

install:
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -m 0755 -t $(DESTDIR)$(OARDIR) $(OARDIR_BINFILES)
	install -m 0644 -t $(DESTDIR)$(OARDIR) $(OARDIR_DATAFILES)
	
	# Rename installed files
	mv $(DESTDIR)$(OARDIR)/oar_mysql_db_init.pl $(DESTDIR)$(OARDIR)/oar_mysql_db_init
	mv $(DESTDIR)$(OARDIR)/oar_psql_db_init.pl $(DESTDIR)$(OARDIR)/oar_psql_db_init
	
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oar_mysql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oar_psql_db_init CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_psql_db_init

uninstall:
	@for file in $(OARDIR_BINFILES); do rm -f $(DESTDIR)$(OARDIR)/`basename $$file`; done
	@for file in $(OARDIR_DATAFILES); do rm -f $(DESTDIR)$(OARDIR)/`basename $$file`; done
	
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oar_mysql_db_init.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oar_psql_db_init.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_psql_db_init
