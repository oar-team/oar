#!/usr/bin/make
# $Id$
SHELL=/bin/bash

OARCONFDIR=/etc/oar
# OARUSER and OAROWNER should be the same value except for special needs 
# (Debian packaging) 
OARUSER=oar
# OAROWNER is the variable expanded to set the ownership of the files
OAROWNER=$(OARUSER)

PREFIX=/usr/local
MANDIR=$(PREFIX)/man
OARDIR=$(PREFIX)/oar
BINDIR=$(PREFIX)/bin
SBINDIR=$(PREFIX)/sbin
DOCDIR=$(PREFIX)/doc/oar
WWWDIR=/var/www
CGIDIR=/usr/lib/cgi-bin
DEB_INSTALL=$(OARDIR)
DEB_SBINDIR=$(SBINDIR)
DEB_BINDIR=$(BINDIR)
XAUTHCMDPATH=$(shell which xauth)
ifeq "$(XAUTHCMDPATH)" ""
	XAUTHCMDPATH=/usr/bin/xauth
endif

.PHONY: man

all: usage
install: usage
usage:
	@echo "Usage: make [ OPTIONS=<...> ] MODULES"
	@echo "Where MODULES := { server-install | user-install | node-install | doc-install | desktop-computing-agent-install | desktop-computing-cgi-install }"
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
	install -m 6750 $(OARDIR)/oardo $(SBINDIR)/oarcache
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oarcache'\;#" $(SBINDIR)/oarcache
	install -m 0755 DesktopComputing/oarres.pl $(OARDIR)/oarres
	install -m 6750 $(OARDIR)/oardo $(SBINDIR)/oarres
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oarres'\;#" $(SBINDIR)/oarres
	install -m 0755 DesktopComputing/oar-cgi.pl $(OARDIR)/oar-cgi
	install -m 6750 $(OARDIR)/oardo $(SBINDIR)/oar-cgi
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oar-cgi'\;#" $(CGIDIR)/oar-cgi
	install -d -m 0755 $(CGIDIR)

dbinit:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(SBINDIR)
	install -m 0755 DB/oar_mysql_db_init.pl $(OARDIR)/oar_mysql_db_init
	install -m 6750 $(OARDIR)/oardo $(SBINDIR)/oar_mysql_db_init
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oar_mysql_db_init'\;#" $(SBINDIR)/oar_mysql_db_init
	install -m 0644 DB/oar_jobs.sql $(OARDIR)
	install -m 0644 DB/oar_postgres.sql $(OARDIR)

oardo:
	install -d -m 0755 $(OARDIR)
	install -m 6755 Tools/oardo $(OARDIR)
	perl -i -pe "s#Oardir = .*#Oardir = '$(DEB_INSTALL)'\;#;;\
			     s#Oaruser = .*#Oaruser = '$(OARUSER)'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				" $(OARDIR)/oardo
common: man
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -d -m 0755 $(SBINDIR)
	install -m 0755 Tools/oarsh/oarsh $(OARDIR)
	perl -i -pe "s#^XAUTH_LOCATION=.*#XAUTH_LOCATION=$(XAUTHCMDPATH)#" $(OARDIR)/oarsh
	install -m 6755 $(OARDIR)/oardo $(BINDIR)/oardo
	install -m 6755 $(OARDIR)/oardo $(OARDIR)/oarsh_oardo
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oarsh'\;#" $(OARDIR)/oarsh_oardo
	install -m 0755 Tools/oarsh/oarsh_sudowrapper.sh $(BINDIR)/oarsh
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(DEB_INSTALL)#;;\
				 s#^OARSHCMD=.*#OARSHCMD=oarsh_oardo#\
				" $(BINDIR)/oarsh
	install -m 0755 Tools/oarsh/oarcp $(BINDIR)
	perl -i -pe "s#^OARSHCMD=.*#OARSHCMD=$(DEB_BINDIR)/oarsh#" $(BINDIR)/oarcp
	install -d -m 0755 $(MANDIR)/man1
	install -m 0644 man/man1/oarsh.1 $(MANDIR)/man1/oarcp.1
	
libs:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -d -m 0755 $(SBINDIR)
	install -m 0644 ConfLib/oar_conflib.pm $(OARDIR)
	install -m 0644 Iolib/oar_iolib.pm $(OARDIR)
	install -m 0644 Judas/oar_Judas.pm $(OARDIR)
	install -m 0755 Qfunctions/oarnodesetting $(OARDIR)
	install -m 6750 $(OARDIR)/oardo $(SBINDIR)/oarnodesetting
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oarnodesetting'\;#" $(SBINDIR)/oarnodesetting
	install -m 0644 Scheduler/data_structures/oar_resource_tree.pm $(OARDIR)
	install -m 0644 Tools/oarversion.pm $(OARDIR)
	install -m 0644 Tools/oar_Tools.pm $(OARDIR)
	install -m 0755 Tools/sentinelle.pl $(OARDIR)
	install -m 0755 Tools/oarnodesetting_ssh $(OARDIR)
	perl -i -pe "s#^OARNODESETTINGCMD=.*#OARNODESETTINGCMD=$(DEB_SBINDIR)/oarnodesetting#" $(OARDIR)/oarnodesetting_ssh

server:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(OARCONFDIR)
	install -d -m 0755 $(BINDIR)
	install -d -m 0755 $(SBINDIR)
	install -m 0755 Almighty/Almighty $(OARDIR)
	install -m 6750 $(OARDIR)/oardo $(SBINDIR)/Almighty
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/Almighty'\;#" $(SBINDIR)/Almighty
	install -m 0755 Leon/Leon	$(OARDIR)
	install -m 0755 Runner/runner $(OARDIR)
	install -m 0755 Sarko/sarko $(OARDIR)
	install -m 0755 Sarko/finaud $(OARDIR)
	install -m 0644 Scheduler/data_structures/Gantt.pm $(OARDIR)
	install -m 0644 Scheduler/data_structures/Gantt_2.pm $(OARDIR)
	install -m 0755 Scheduler/oar_sched_gantt_with_timesharing $(OARDIR)
	install -m 0755 Scheduler/oar_sched_gantt_with_timesharing_and_fairsharing $(OARDIR)
	install -m 0755 Scheduler/oar_meta_sched $(OARDIR)
	install -m 0644 Scheduler/oar_scheduler.pm $(OARDIR)
	install -m 0755 Qfunctions/oarnotify $(OARDIR)
	install -m 6750 $(OARDIR)/oardo $(SBINDIR)/oarnotify
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oarnotify'\;#" $(SBINDIR)/oarnotify
	install -m 0755 NodeChangeState/NodeChangeState $(OARDIR)
	install -m 0755 Qfunctions/oarremoveresource $(OARDIR)
	install -m 6750 $(OARDIR)/oardo $(SBINDIR)/oarremoveresource
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oarremoveresource'\;#" $(SBINDIR)/oarremoveresource
	install -m 0755 Qfunctions/oaraccounting $(OARDIR)
	install -m 6750 $(OARDIR)/oardo $(SBINDIR)/oaraccounting
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oaraccounting'\;#" $(SBINDIR)/oaraccounting
	install -m 0755 Qfunctions/oarproperty $(OARDIR)
	install -m 6750 $(OARDIR)/oardo $(SBINDIR)/oarproperty
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oarproperty'\;#" $(SBINDIR)/oarproperty
	install -m 0755 Qfunctions/oarmonitor $(OARDIR)
	install -m 6750 $(OARDIR)/oardo $(SBINDIR)/oarmonitor
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oarmonitor'\;#" $(SBINDIR)/oarmonitor
	install -m 0644 Scheduler/data_structures/sorted_chained_list.pm $(OARDIR)
	install -m 0755 Runner/bipbip $(OARDIR)
	install -m 0644 Runner/ping_checker.pm $(OARDIR)
	install -m 0644 Runner/oarexec $(OARDIR)
	@if [ -f $(OARCONFDIR)/cpuset_manager.pl ]; then echo "Warning: $(OARCONFDIR)/cpuset_manager.pl already exists, not overwriting it." ; else install -m 0644 Tools/cpuset_manager.pl $(OARCONFDIR); fi
	@if [ -f $(OARCONFDIR)/suspend_resume_manager.pl ]; then echo "Warning: $(OARCONFDIR)/suspend_resume_manager.pl already exists, not overwriting it." ; else install -m 0644 Tools/suspend_resume_manager.pl $(OARCONFDIR); fi
	@if [ -f $(OARCONFDIR)/oarmonitor_sensor.pl ]; then echo "Warning: $(OARCONFDIR)/oarmonitor_sensor.pl already exists, not overwriting it." ; else install -m 0644 Tools/oarmonitor_sensor.pl $(OARCONFDIR); fi
	@if [ -f $(OARCONFDIR)/server_prologue ]; then echo "Warning: $(OARCONFDIR)/server_prologue already exists, not overwriting it." ; else install -m 0755 Scripts/server_prologue $(OARCONFDIR) ; fi
	@if [ -f $(OARCONFDIR)/server_epilogue ]; then echo "Warning: $(OARCONFDIR)/server_epilogue already exists, not overwriting it." ; else install -m 0755 Scripts/server_epilogue $(OARCONFDIR) ; fi

user: man
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -m 0755 Qfunctions/oarnodes $(OARDIR)
	install -m 6755 $(OARDIR)/oardo $(BINDIR)/oarnodes
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oarnodes'\;#" $(BINDIR)/oarnodes
	install -m 0755 Qfunctions/oardel $(OARDIR)
	install -m 6755 $(OARDIR)/oardo $(BINDIR)/oardel
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oardel'\;#" $(BINDIR)/oardel
	install -m 0755 Qfunctions/oarstat $(OARDIR)
	install -m 6755 $(OARDIR)/oardo $(BINDIR)/oarstat
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oarstat'\;#" $(BINDIR)/oarstat
	perl -i -pe "s#^OARSH_OARSTAT_CMD=.*#OARSH_OARSTAT_CMD=$(DEB_BINDIR)/oarstat#" $(OARDIR)/oarsh
	install -m 0755 Qfunctions/oarsub $(OARDIR)
	install -m 6755 $(OARDIR)/oardo $(BINDIR)/oarsub
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oarsub'\;#" $(BINDIR)/oarsub
	install -m 0755 Qfunctions/oarhold $(OARDIR)
	install -m 6755 $(OARDIR)/oardo $(BINDIR)/oarhold
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oarhold'\;#" $(BINDIR)/oarhold
	install -m 0755 Qfunctions/oarresume $(OARDIR)
	install -m 6755 $(OARDIR)/oardo $(BINDIR)/oarresume
	perl -i -pe "s#Cmd_wrapper = .*#Cmd_wrapper = '$(DEB_INSTALL)/oarresume'\;#" $(BINDIR)/oarresume
	install -m 0755 Tools/oarmonitor_graph_gen.pl $(BINDIR)
	install -d -m 0755 $(MANDIR)/man1
	install -m 0644 man/man1/oardel.1 $(MANDIR)/man1
	install -m 0644 man/man1/oarnodes.1 $(MANDIR)/man1
	install -m 0644 man/man1/oarresume.1 $(MANDIR)/man1
	install -m 0644 man/man1/oarstat.1 $(MANDIR)/man1
	install -m 0644 man/man1/oarsub.1 $(MANDIR)/man1
	install -m 0644 man/man1/oarhold.1 $(MANDIR)/man1

node: man
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(OARCONFDIR)
	install -m 0600 -o $(OAROWNER) -g root Tools/sshd_config $(OARCONFDIR)
	perl -i -pe "s#^XAuthLocation.*#XAuthLocation $(XAUTHCMDPATH)#" $(OARCONFDIR)/sshd_config
	install -m 0755 Tools/oarsh/oarsh_shell $(OARDIR)
	perl -i -pe "s#^XAUTH_LOCATION=.*#XAUTH_LOCATION=$(XAUTHCMDPATH)#;;\
				 s#^OARDIR=.*#OARDIR=$(DEB_INSTALL)#;;\
				" $(OARDIR)/oarsh_shell
	install -m 0755 Tools/detect_resources $(OARDIR)
	@if [ -f $(OARCONFDIR)/prologue ]; then echo "Warning: $(OARCONFDIR)/prologue already exists, not overwriting it." ; else install -m 0755 Scripts/prologue $(OARCONFDIR) ; fi
	@if [ -f $(OARCONFDIR)/epilogue ]; then echo "Warning: $(OARCONFDIR)/epilogue already exists, not overwriting it." ; else install -m 0755 Scripts/epilogue $(OARCONFDIR) ; fi

build-html-doc: Docs/html/OAR-DOCUMENTATION.rst
	(cd Docs/html && $(MAKE) )

doc: build-html-doc
	install -d -m 0755 $(DOCDIR)
	install -d -m 0755 $(DOCDIR)/html
	install -m 0644 Docs/html/OAR-DOCUMENTATION.html $(DOCDIR)/html
	install -m 0644 Docs/html/oar_logo.png $(DOCDIR)/html
	install -m 0644 Docs/html/db_scheme.png $(DOCDIR)/html
	install -m 0644 Docs/html/interactive_oarsub_scheme.png $(DOCDIR)/html
	install -m 0644 Docs/Almighty.fig $(DOCDIR)/html
	install -m 0644 Docs/Almighty.ps $(DOCDIR)/html
	install -d -m 0755 $(DOCDIR)/scripts
	install -d -m 0755 $(DOCDIR)/scripts/cpuset_manager
	install -m 0644 Tools/cpuset_manager_PAM.pl $(DOCDIR)/scripts/cpuset_manager/
	install -m 0644 Tools/cpuset_manager_SGI_Altix_350_SLES9.pl $(DOCDIR)/scripts/cpuset_manager/
	install -d -m 0755 $(DOCDIR)/scripts/prologue_epilogue
	install -m 0644 Scripts/oar_prologue $(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_epilogue $(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_prologue_local $(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_epilogue_local $(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_diffuse_script $(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/lock_user.sh $(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_server_proepilogue.pl $(DOCDIR)/scripts/prologue_epilogue/

draw-gantt:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(CGIDIR)
	install -d -m 0755 $(WWWDIR)
	install -m 0755 VisualizationInterfaces/DrawGantt/drawgantt.cgi $(CGIDIR)
	install -d -m 0755 $(OARCONFDIR)
	@if [ -f $(CGIDIR)/drawgantt.conf ]; then echo "Warning: $(CGIDIR)/drawgantt.conf already exists, not overwriting it." ; else install -m 0600 VisualizationInterfaces/DrawGantt/drawgantt.conf $(CGIDIR) ; fi
#	install -m 0644 ConfLib/oar_conflib.pm $(CGIDIR)
	install -d -m 0755 $(WWWDIR)/drawgantt/Icons
	install -d -m 0755 $(WWWDIR)/drawgantt/js
	install -m 0644 VisualizationInterfaces/DrawGantt/Icons/*.png $(WWWDIR)/drawgantt/Icons
	install -m 0644 VisualizationInterfaces/DrawGantt/js/*.js $(WWWDIR)/drawgantt/js

server-install: sanity-check configuration oardo common libs server dbinit

user-install: sanity-check configuration oardo common libs user

node-install: sanity-check configuration oardo common node
	@chsh -s $(OARDIR)/oarsh_shell $(OAROWNER)

doc-install: doc

draw-gantt-install: draw-gantt

desktop-computing-cgi-install: sanity-check oardo configuration common libs desktop-computing-cgi
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(DEB_INSTALL)#;;s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(CGIDIR)/oar-cgi 

desktop-computing-agent-install: desktop-computing-agent
