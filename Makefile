#!/usr/bin/make
# $Id$
SHELL=/bin/bash

OARCONFDIR=/etc/oar
# OARUSER and OAROWNER should be the same value except for special needs 
# (Debian packaging) 
OARUSER=oar
# OAROWNER is the variable expanded to set the ownership of the files
OAROWNER=$(OARUSER)
OAROWNERGROUP=$(OAROWNER)

# Set the user of web server (for CGI installation)
WWWUSER=www-data

PREFIX=/usr/local
MANDIR=$(PREFIX)/man
OARDIR=$(PREFIX)/oar
BINDIR=$(PREFIX)/bin
SBINDIR=$(PREFIX)/sbin
DOCDIR=$(PREFIX)/doc/oar
WWWDIR=/var/www
CGIDIR=/usr/lib/cgi-bin
REAL_OARCONFDIR=$(OARCONFDIR)
REAL_OARDIR=$(OARDIR)
REAL_SBINDIR=$(SBINDIR)
REAL_BINDIR=$(BINDIR)
XAUTHCMDPATH=$(shell which xauth)
ifeq "$(XAUTHCMDPATH)" ""
	XAUTHCMDPATH=/usr/bin/xauth
endif

.PHONY: man

all: usage
install: usage
usage:
	@echo "Usage: make [ OPTIONS=<...> ] MODULES"
	@echo "Where MODULES := { server-install | user-install | node-install | monika-install | draw-gantt-install | doc-install | desktop-computing-agent-install | desktop-computing-cgi-install }"
	@echo "      OPTIONS := { OARCONFDIR | OARUSER | OAROWNER | PREFIX | MANDIR | OARDIR | BINDIR | SBINDIR | DOCDIR }"

sanity-check:
	@[ "`id root`" = "`id`" ] || echo "Warning: root-privileges are required to install some files !"
	@id $(OAROWNER) > /dev/null || ( echo "Error: User $(OAROWNER) does not exist!" ; exit -1 )

man:
	@cd man/man1/ && for i in `ls *.pod | sed -ne 's/.pod//p'`; do pod2man --section=1 --release=$$1 --center "OAR commands" --name $$i "$$i.pod" > $$i.1 ; done

configuration:
	install -d -m 0755 $(OARCONFDIR)
	@if [ -f $(OARCONFDIR)/oar.conf ]; then echo "Warning: $(OARCONFDIR)/oar.conf already exists, not overwriting it." ; else install -m 0600 -o $(OAROWNER) -g root Tools/oar.conf $(OARCONFDIR) ; fi

desktop-computing-agent:
	install -d -m 0755 $(BINDIR)
	install -m 0755 DesktopComputing/oar-agent.pl $(BINDIR)/oar-agent

desktop-computing-cgi:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(SBINDIR)
	install -m 0755 DesktopComputing/oarcache.pl $(OARDIR)/oarcache
	install -m 6750 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(SBINDIR)/oarcache
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oarcache'\;#;;\
				" $(SBINDIR)/oarcache
	install -m 0755 DesktopComputing/oarres.pl $(OARDIR)/oarres
	install -m 6750 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(SBINDIR)/oarres
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oarres'\;#;;\
				" $(SBINDIR)/oares
	install -m 0755 DesktopComputing/oar-cgi.pl $(OARDIR)/oar-cgi.pl
	install -d -m 0755 $(CGIDIR)
	install -m 6750 -o $(OAROWNER) -g $(WWWUSER) Tools/oardo $(CGIDIR)/oar-cgi
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oar-cgi.pl'\;#;;\
				" $(CGIDIR)/oar-cgi

dbinit:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(SBINDIR)
	install -m 0755 DB/oar_mysql_db_init.pl $(OARDIR)/oar_mysql_db_init
	install -m 0755 DB/init_pg_server.pl $(OARDIR)/init_pg_server
	install -m 0755 DB/oar_pg_db_filling.pl $(OARDIR)/oar_pg_db_filling
	install -m 6750 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(SBINDIR)/oar_mysql_db_init
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oar_mysql_db_init'\;#;;\
				" $(SBINDIR)/oar_mysql_db_init
	install -m 0644 DB/default_data.sql $(OARDIR)
	install -m 0644 DB/mysql_default_admission_rules.sql $(OARDIR)
	install -m 0644 DB/mysql_structure.sql $(OARDIR)
	install -m 0644 DB/pg_default_admission_rules.sql $(OARDIR)
	install -m 0644 DB/pg_structure.sql $(OARDIR)

common: man
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -d -m 0755 $(SBINDIR)
	install -m 0755 Tools/oarsh/oarsh $(OARDIR)
	perl -i -pe "s#^XAUTH_LOCATION=.*#XAUTH_LOCATION=$(XAUTHCMDPATH)#" $(OARDIR)/oarsh
	install -d -m 0755 $(OARDIR)/oardodo
	install -m 6750 -o root -g $(OAROWNERGROUP) Tools/oardodo $(OARDIR)/oardodo
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oaruser = .*#Oaruser = '$(OARUSER)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				" $(OARDIR)/oardodo/oardodo
	install -m 6755 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(OARDIR)/oarsh_oardo
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oarsh'\;#;;\
				" $(OARDIR)/oarsh_oardo
	install -m 0755 Tools/oarsh/oarsh_sudowrapper.sh $(BINDIR)/oarsh
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(REAL_OARDIR)#;;\
				 s#^OARSHCMD=.*#OARSHCMD=oarsh_oardo#\
				" $(BINDIR)/oarsh
	install -m 0755 Tools/oarsh/oarcp $(BINDIR)
	perl -i -pe "s#^OARSHCMD=.*#OARSHCMD=$(REAL_BINDIR)/oarsh#" $(BINDIR)/oarcp
	install -d -m 0755 $(MANDIR)/man1
	install -m 0644 man/man1/oarsh.1 $(MANDIR)/man1/oarcp.1
	install -m 0644 man/man1/oarsh.1 $(MANDIR)/man1/oarsh.1
	
libs: man
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -d -m 0755 $(SBINDIR)
	install -m 0644 ConfLib/oar_conflib.pm $(OARDIR)
	install -m 0644 Iolib/oar_iolib.pm $(OARDIR)
	install -m 0644 Judas/oar_Judas.pm $(OARDIR)
	install -m 0755 Qfunctions/oarnodesetting $(OARDIR)
	install -m 6750 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(SBINDIR)/oarnodesetting
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oarnodesetting'\;#;;\
				" $(SBINDIR)/oarnodesetting
	install -m 0644 Scheduler/data_structures/oar_resource_tree.pm $(OARDIR)
	install -m 0644 Tools/oarversion.pm $(OARDIR)
	install -m 0644 Tools/oar_Tools.pm $(OARDIR)
	install -m 0755 Tools/sentinelle.pl $(OARDIR)
	install -m 0755 Tools/oarnodesetting_ssh $(OARDIR)
	perl -i -pe "s#^OARNODESETTINGCMD=.*#OARNODESETTINGCMD=$(REAL_SBINDIR)/oarnodesetting#" $(OARDIR)/oarnodesetting_ssh
	install -d -m 0755 $(MANDIR)/man1
	install -m 0644 man/man1/oarnodesetting.1 $(MANDIR)/man1/oarnodesetting.1

server: man
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(OARCONFDIR)
	install -d -m 0755 $(SBINDIR)
	install -m 0755 Almighty/Almighty $(OARDIR)
	install -m 6750 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(SBINDIR)/Almighty
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/Almighty'\;#;;\
				" $(SBINDIR)/Almighty
	install -m 0755 Leon/Leon	$(OARDIR)
	install -m 0755 Runner/runner $(OARDIR)
	install -m 0755 Sarko/sarko $(OARDIR)
	install -m 0755 Sarko/finaud $(OARDIR)
	install -m 0644 Scheduler/data_structures/Gantt_hole_storage.pm $(OARDIR)
	install -m 0755 Scheduler/oar_sched_gantt_with_timesharing $(OARDIR)
	install -m 0755 Scheduler/oar_sched_gantt_with_timesharing_and_fairsharing $(OARDIR)
	install -m 0755 Scheduler/oar_meta_sched $(OARDIR)
	install -m 0644 Scheduler/oar_scheduler.pm $(OARDIR)
	install -m 0755 Qfunctions/oarnotify $(OARDIR)
	install -m 6750 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(SBINDIR)/oarnotify
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oarnotify'\;#;;\
				" $(SBINDIR)/oarnotify
	install -m 0755 NodeChangeState/NodeChangeState $(OARDIR)
	install -m 0755 Qfunctions/oarremoveresource $(OARDIR)
	install -m 6750 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(SBINDIR)/oarremoveresource
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oarremoveresource'\;#;;\
				" $(SBINDIR)/oarremoveresource
	install -m 0755 Qfunctions/oaraccounting $(OARDIR)
	install -m 6750 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(SBINDIR)/oaraccounting
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oaraccounting'\;#;;\
				" $(SBINDIR)/oaraccounting
	install -m 0755 Qfunctions/oarproperty $(OARDIR)
	install -m 6750 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(SBINDIR)/oarproperty
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oarproperty'\;#;;\
				" $(SBINDIR)/oarproperty
	install -m 0755 Qfunctions/oarmonitor $(OARDIR)
	install -m 6750 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(SBINDIR)/oarmonitor
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oarmonitor'\;#;;\
				" $(SBINDIR)/oarmonitor
	install -m 0755 Runner/bipbip $(OARDIR)
	install -m 0644 Runner/ping_checker.pm $(OARDIR)
	install -m 0644 Runner/oarexec $(OARDIR)
	@if [ -f $(OARCONFDIR)/job_resource_manager.pl ]; then echo "Warning: $(OARCONFDIR)/job_resource_manager.pl already exists, not overwriting it." ; else install -m 0644 Tools/job_resource_manager.pl $(OARCONFDIR); fi
	@if [ -f $(OARCONFDIR)/suspend_resume_manager.pl ]; then echo "Warning: $(OARCONFDIR)/suspend_resume_manager.pl already exists, not overwriting it." ; else install -m 0644 Tools/suspend_resume_manager.pl $(OARCONFDIR); fi
	@if [ -f $(OARCONFDIR)/oarmonitor_sensor.pl ]; then echo "Warning: $(OARCONFDIR)/oarmonitor_sensor.pl already exists, not overwriting it." ; else install -m 0644 Tools/oarmonitor_sensor.pl $(OARCONFDIR); fi
	@if [ -f $(OARCONFDIR)/server_prologue ]; then echo "Warning: $(OARCONFDIR)/server_prologue already exists, not overwriting it." ; else install -m 0755 Scripts/server_prologue $(OARCONFDIR) ; fi
	@if [ -f $(OARCONFDIR)/server_epilogue ]; then echo "Warning: $(OARCONFDIR)/server_epilogue already exists, not overwriting it." ; else install -m 0755 Scripts/server_epilogue $(OARCONFDIR) ; fi
	install -d -m 0755 $(MANDIR)/man1
	install -m 0644 man/man1/Almighty.1 $(MANDIR)/man1/Almighty.1
	install -m 0644 man/man1/oar_mysql_db_init.1 $(MANDIR)/man1/oar_mysql_db_init.1
	install -m 0644 man/man1/oaraccounting.1 $(MANDIR)/man1/oaraccounting.1
	install -m 0644 man/man1/oarmonitor.1 $(MANDIR)/man1/oarmonitor.1
	install -m 0644 man/man1/oarnotify.1 $(MANDIR)/man1/oarnotify.1
	install -m 0644 man/man1/oarproperty.1 $(MANDIR)/man1/oarproperty.1
	install -m 0644 man/man1/oarremoveresource.1 $(MANDIR)/man1/oarremoveresource.1

user: man
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -m 0755 Qfunctions/oarnodes $(OARDIR)
	install -m 6755 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(BINDIR)/oarnodes
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oarnodes'\;#;;\
				" $(BINDIR)/oarnodes
	install -m 0755 Qfunctions/oardel $(OARDIR)
	install -m 6755 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(BINDIR)/oardel
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oardel'\;#;;\
				" $(BINDIR)/oardel
	install -m 0755 Qfunctions/oarstat $(OARDIR)
	install -m 6755 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(BINDIR)/oarstat
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oarstat'\;#;;\
				" $(BINDIR)/oarstat
	perl -i -pe "s#^OARSH_OARSTAT_CMD=.*#OARSH_OARSTAT_CMD=$(REAL_BINDIR)/oarstat#" $(OARDIR)/oarsh
	install -m 0755 Qfunctions/oarsub $(OARDIR)
	install -m 6755 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(BINDIR)/oarsub
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oarsub'\;#;;\
				" $(BINDIR)/oarsub
	install -m 0755 Qfunctions/oarhold $(OARDIR)
	install -m 6755 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(BINDIR)/oarhold
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oarhold'\;#;;\
				" $(BINDIR)/oarhold
	install -m 0755 Qfunctions/oarresume $(OARDIR)
	install -m 6755 -o $(OAROWNER) -g $(OAROWNERGROUP) Tools/oardo $(BINDIR)/oarresume
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(REAL_OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(REAL_OARDIR)/oarresume'\;#;;\
				" $(BINDIR)/oarresume
	install -m 0755 Tools/oarmonitor_graph_gen.pl $(BINDIR)/oarmonitor_graph_gen
	install -d -m 0755 $(MANDIR)/man1
	install -m 0644 man/man1/oardel.1 $(MANDIR)/man1
	install -m 0644 man/man1/oarnodes.1 $(MANDIR)/man1
	install -m 0644 man/man1/oarresume.1 $(MANDIR)/man1
	install -m 0644 man/man1/oarstat.1 $(MANDIR)/man1
	install -m 0644 man/man1/oarsub.1 $(MANDIR)/man1
	install -m 0644 man/man1/oarhold.1 $(MANDIR)/man1
	install -m 0644 man/man1/oarmonitor_graph_gen.1 $(MANDIR)/man1/oarmonitor_graph_gen.1

node: man
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(OARCONFDIR)
	install -m 0600 -o $(OAROWNER) -g root Tools/sshd_config $(OARCONFDIR)
	perl -i -pe "s#^XAuthLocation.*#XAuthLocation $(XAUTHCMDPATH)#" $(OARCONFDIR)/sshd_config
	install -m 0755 Tools/oarsh/oarsh_shell $(OARDIR)
	perl -i -pe "s#^XAUTH_LOCATION=.*#XAUTH_LOCATION=$(XAUTHCMDPATH)#;;\
				 s#^OARDIR=.*#OARDIR=$(REAL_OARDIR)#;;\
				" $(OARDIR)/oarsh_shell
	install -m 0755 Tools/detect_resources $(OARDIR)
	@if [ -f $(OARCONFDIR)/prologue ]; then echo "Warning: $(OARCONFDIR)/prologue already exists, not overwriting it." ; else install -m 0755 Scripts/prologue $(OARCONFDIR) ; fi
	@if [ -f $(OARCONFDIR)/epilogue ]; then echo "Warning: $(OARCONFDIR)/epilogue already exists, not overwriting it." ; else install -m 0755 Scripts/epilogue $(OARCONFDIR) ; fi

build-html-doc: Docs/html/
	(cd Docs/html && $(MAKE) )

doc: build-html-doc
	install -d -m 0755 $(DOCDIR)
	install -d -m 0755 $(DOCDIR)/html
	install -m 0644 Docs/html/OAR-DOCUMENTATION-USER.html $(DOCDIR)/html
	install -m 0644 Docs/html/OAR-DOCUMENTATION-ADMIN.html $(DOCDIR)/html
	install -m 0644 Docs/schemas/oar_logo.png $(DOCDIR)/html
	install -m 0644 Docs/schemas/db_scheme.png $(DOCDIR)/html
	install -m 0644 Docs/schemas/interactive_oarsub_scheme.png $(DOCDIR)/html
	install -m 0644 Docs/schemas/Almighty.fig $(DOCDIR)/html
	install -m 0644 Docs/schemas/Almighty.ps $(DOCDIR)/html
	install -d -m 0755 $(DOCDIR)/scripts
	install -d -m 0755 $(DOCDIR)/scripts/job_resource_manager
	install -m 0644 Tools/job_resource_manager.pl $(DOCDIR)/scripts/job_resource_manager/
	install -d -m 0755 $(DOCDIR)/scripts/prologue_epilogue
	install -m 0644 Scripts/oar_prologue $(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_epilogue $(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_prologue_local $(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_epilogue_local $(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_diffuse_script $(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/lock_user.sh $(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_server_proepilogue.pl $(DOCDIR)/scripts/prologue_epilogue/

draw-gantt:
	install -d -m 0755 $(CGIDIR)
	install -d -m 0755 $(WWWDIR)
	install -m 0755 VisualizationInterfaces/DrawGantt/drawgantt.cgi $(CGIDIR)
	install -d -m 0755 $(OARCONFDIR)
	@if [ -f $(OARCONFDIR)/drawgantt.conf ]; then echo "Warning: $(OARCONFDIR)/drawgantt.conf already exists, not overwriting it." ; else install -o $(WWWUSER) -m 0600 VisualizationInterfaces/DrawGantt/drawgantt.conf $(OARCONFDIR) ; fi
	install -d -m 0755 $(WWWDIR)/drawgantt/Icons
	install -d -m 0755 $(WWWDIR)/drawgantt/js
	install -m 0644 VisualizationInterfaces/DrawGantt/Icons/*.png $(WWWDIR)/drawgantt/Icons
	install -m 0644 VisualizationInterfaces/DrawGantt/js/*.js $(WWWDIR)/drawgantt/js
	install -d -o $(WWWUSER) -m 0755 $(WWWDIR)/drawgantt/cache

monika:
	install -d -m 0755 $(CGIDIR)
	install -d -m 0755 $(OARCONFDIR)
	@if [ -f $(OARCONFDIR)/monika.conf ]; then echo "Warning: $(OARCONFDIR)/monika.conf already exists, not overwriting it." ; else install -o $(WWWUSER) -m 0600 VisualizationInterfaces/Monika/monika.conf $(OARCONFDIR) ; fi
	install -m 0755 VisualizationInterfaces/Monika/monika.cgi $(CGIDIR)
	perl -i -pe "s#Oardir = .*#Oardir = '$(REAL_OARCONFDIR)'\;#;;" $(CGIDIR)/monika.cgi
	install -m 0755 VisualizationInterfaces/Monika/userInfos.cgi $(CGIDIR)
	install -m 0644 VisualizationInterfaces/Monika/monika.css $(WWWDIR)
	install -d -m 0755 $(CGIDIR)/monika
	install -m 0644 VisualizationInterfaces/Monika/monika/VERSION $(CGIDIR)/monika
	install -d -m 0755 $(CGIDIR)/monika/Sort
	install -m 0755 VisualizationInterfaces/Monika/monika/Sort/Naturally.pm $(CGIDIR)/monika/Sort
	install -m 0755 VisualizationInterfaces/Monika/monika/*.pm $(CGIDIR)/monika
	install -m 0644 VisualizationInterfaces/Monika/monika/overlib.js $(CGIDIR)/monika

server-install: sanity-check configuration common libs server dbinit

user-install: sanity-check configuration common libs user

node-install: sanity-check configuration common libs node
	@chsh -s $(OARDIR)/oarsh_shell $(OAROWNER)

doc-install: doc

draw-gantt-install: draw-gantt

monika-install: monika

desktop-computing-cgi-install: sanity-check configuration common libs desktop-computing-cgi

desktop-computing-agent-install: desktop-computing-agent
