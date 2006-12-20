#!/usr/bin/make
# $Id: Makefile,v 1.35 2005/07/28 12:45:19 capitn Exp $
SHELL=/bin/sh

OARHOMEDIR=/var/lib/oar
OARCONFDIR=/etc/
OARUSER=oar
OARGROUP=oar

PREFIX=/usr/local
MANDIR=$(PREFIX)/man
OARDIR=$(PREFIX)/oar
BINDIR=$(PREFIX)/bin
SBINDIR=$(PREFIX)/sbin
DOCDIR=$(PREFIX)/doc/oar
WWWDIR=/var/www
CGIDIR=/usr/lib/cgi-bin
CONFIG_CMDS=$(OARDIR)/cmds
DEB_INSTALL=$(OARDIR)

BINLINKPATH=$(OARDIR)
SBINLINKPATH=$(OARDIR)
CMDSLINKPATH=$(OARDIR)

all: usage
install: usage
usage:
	@echo "Usage: make [ OPTIONS=<...> ] MODULES"
	@echo "Where MODULES := { server-install | user-install | node-install | doc-install | desktop-computing-agent-install | desktop-computing-cgi-install | debian-packages | rpm-packages }"
	@echo "      OPTIONS := { OARHOMEDIR | OARCONFDIR | OARUSER | OARGROUP | PREFIX | MANDIR | OARDIR | BINDIR | SBINDIR | DOCDIR }"

sanity-check:
	@[ "`id root`" = "`id`" ] || echo "Warning: root-privileges are required to install some files !"
	@id $(OARUSER) > /dev/null || ( echo "Error: User $(OARUSER) does not exist!" ; exit -1 )
	@[ -d $(OARHOMEDIR) ] || ( echo "Error: OAR home directory $(OARHOMEDIR) does not exist!" ; exit -1 )

configuration:
	install -d -m 0755 $(OARCONFDIR)
	@if [ -f $(OARCONFDIR)/oar.conf ]; then echo "Warning: $(OARCONFDIR)/oar.conf already exists, not overwriting it." ; else install -m 0600 -o $(OARUSER) -g root Tools/oar.conf $(OARCONFDIR) ; fi

desktop-computing-agent:
	install -d -m 0755 $(BINDIR)
	install -m 0755 DesktopComputing/oar-agent.pl $(BINDIR)/oar-agent

desktop-computing-cgi:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(SBINDIR)
	install -d -m 0755 $(CONFIG_CMDS)
	install -m 0755 Tools/sudowrapper.sh $(OARDIR)
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(DEB_INSTALL)#;;s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 DesktopComputing/oarcache.pl $(OARDIR)/oarcache
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oarcache
	perl -i -pe "s#^OARCMD=.*#OARCMD=oarcache#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(SBINDIR)/oarcache
	install -m 0755 DesktopComputing/oarres.pl $(OARDIR)/oarres
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oarres
	perl -i -pe "s#^OARCMD=.*#OARCMD=oarres#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(SBINDIR)/oarres
	install -m 0755 DesktopComputing/oar-cgi.pl $(OARDIR)/oar-cgi
	install -d -m 0755 $(CGIDIR)
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oar-cgi
	install -m 0755 Tools/sudowrapper.sh $(CGIDIR)/oar-cgi
	rm $(OARDIR)/sudowrapper.sh

dbinit:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(SBINDIR)
	install -d -m 0755 $(CONFIG_CMDS)
	install -m 0755 Tools/sudowrapper.sh $(OARDIR)
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(DEB_INSTALL)#;;s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 DB/oar_mysql_db_init.pl $(OARDIR)/oar_mysql_db_init
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oar_mysql_db_init
	perl -i -pe "s#^OARCMD=.*#OARCMD=oar_mysql_db_init#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(SBINDIR)/oar_mysql_db_init
	install -m 0644 DB/oar_jobs.sql $(OARDIR)
	install -m 0644 DB/oar_postgres.sql $(OARDIR)
	rm $(OARDIR)/sudowrapper.sh

sudowrapper:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -d -m 0755 $(CONFIG_CMDS)
	install -m 0755 Tools/sudowrapper.sh $(OARDIR)
	install -m 0755 Tools/configurator_wrapper.sh $(OARDIR)
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(DEB_INSTALL)#;;s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(OARDIR)/configurator_wrapper.sh
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(DEB_INSTALL)#;;s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(OARDIR)/sudowrapper.sh 
	@if [ -f $(OARDIR)/oarsh ]; then echo "Warning: $(OARDIR)/oarsh already exists, not overwriting it." ; else install -m 0755 Tools/oarsh/oarsh $(OARDIR); fi
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oarsh
	perl -i -pe "s#^OARCMD=.*#OARCMD=oarsh#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(BINDIR)/oarsh
	rm $(OARDIR)/sudowrapper.sh
	
common:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -d -m 0755 $(SBINDIR)
	install -d -m 0755 $(CONFIG_CMDS)
	install -m 0755 Tools/sudowrapper.sh $(OARDIR)
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(DEB_INSTALL)#;;s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(OARDIR)/sudowrapper.sh 
	install -m 0644 ConfLib/oar_conflib.pm $(OARDIR)
	install -m 0644 Iolib/oar_iolib.pm $(OARDIR)
	install -m 0644 Judas/oar_Judas.pm $(OARDIR)
	install -m 0755 Qfunctions/oarnodesetting $(OARDIR)
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oarnodesetting
	perl -i -pe "s#^OARCMD=.*#OARCMD=oarnodesetting#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(SBINDIR)/oarnodesetting
	install -m 0644 Scheduler/data_structures/oar_resource_tree.pm $(OARDIR)
	install -m 0755 Tools/deploy_nodes.sh $(OARDIR)
	install -m 0644 Tools/oarversion.pm $(OARDIR)
	install -m 0644 Tools/oar_Tools.pm $(OARDIR)
	install -m 0755 Tools/sentinelle.pl $(OARDIR)
	rm $(OARDIR)/sudowrapper.sh

server:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -d -m 0755 $(SBINDIR)
	install -d -m 0755 $(CONFIG_CMDS)
	install -m 0755 Tools/sudowrapper.sh $(OARDIR)
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(DEB_INSTALL)#;;s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 Almighty/Almighty $(OARDIR)
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/Almighty
	perl -i -pe "s#^OARCMD=.*#OARCMD=Almighty#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(SBINDIR)/Almighty
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
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oarnotify
	perl -i -pe "s#^OARCMD=.*#OARCMD=oarnotify#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(BINDIR)/oarnotify
	install -m 0755 NodeChangeState/NodeChangeState $(OARDIR)
	install -m 0755 Qfunctions/oarremoveresource $(OARDIR)
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oarremoveresource
	perl -i -pe "s#^OARCMD=.*#OARCMD=oarremoveresource#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(SBINDIR)/oarremoveresource
	install -m 0755 Qfunctions/oaraccounting $(OARDIR)
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oaraccounting
	perl -i -pe "s#^OARCMD=.*#OARCMD=oaraccounting#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(SBINDIR)/oaraccounting
	install -m 0755 Qfunctions/oarproperty $(OARDIR)
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oarproperty
	perl -i -pe "s#^OARCMD=.*#OARCMD=oarproperty#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(SBINDIR)/oarproperty
	install -m 0644 Scheduler/data_structures/sorted_chained_list.pm $(OARDIR)
	install -m 0755 Runner/bipbip $(OARDIR)
	install -m 0644 Runner/ping_checker.pm $(OARDIR)
	install -m 0644 Runner/oarexec $(OARDIR)
	@if [ -f $(OARDIR)/cpuset_manager.pl ]; then echo "Warning: $(OARDIR)/cpuset_manager.pl already exists, not overwriting it." ; else install -m 0644 Tools/cpuset_manager.pl $(OARDIR); fi
	@if [ -f $(OARDIR)/suspend_resume_manager.pl ]; then echo "Warning: $(OARDIR)/suspend_resume_manager.pl already exists, not overwriting it." ; else install -m 0644 Tools/suspend_resume_manager.pl $(OARDIR); fi
	rm $(OARDIR)/sudowrapper.sh

user:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -d -m 0755 $(CONFIG_CMDS)
	install -m 0755 Tools/sudowrapper.sh $(OARDIR)
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(DEB_INSTALL)#;;s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 Qfunctions/oarnodes $(OARDIR)
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oarnodes
	perl -i -pe "s#^OARCMD=.*#OARCMD=oarnodes#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(BINDIR)/oarnodes
	install -m 0755 Qfunctions/oardel $(OARDIR)
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oardel
	perl -i -pe "s#^OARCMD=.*#OARCMD=oardel#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(BINDIR)/oardel
	install -m 0755 Qfunctions/oarstat $(OARDIR)
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oarstat
	perl -i -pe "s#^OARCMD=.*#OARCMD=oarstat#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(BINDIR)/oarstat
	perl -i -pe "s#^OARSTAT_CMD=.*#OARSTAT_CMD=$(CONFIG_CMDS)/oarstat#" $(OARDIR)/oarsh
	install -m 0755 Qfunctions/oarsub $(OARDIR)
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oarsub
	perl -i -pe "s#^OARCMD=.*#OARCMD=oarsub#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(BINDIR)/oarsub
	install -m 0755 Qfunctions/oarhold $(OARDIR)
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oarhold
	perl -i -pe "s#^OARCMD=.*#OARCMD=oarhold#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(BINDIR)/oarhold
	install -m 0755 Qfunctions/oarresume $(OARDIR)
	ln -s -f $(CMDSLINKPATH)/configurator_wrapper.sh $(CONFIG_CMDS)/oarresume
	perl -i -pe "s#^OARCMD=.*#OARCMD=oarresume#" $(OARDIR)/sudowrapper.sh 
	install -m 0755 $(OARDIR)/sudowrapper.sh $(BINDIR)/oarresume
	install -d -m 0755 $(MANDIR)/man1
	install -m 0644 Docs/man/oardel.1 $(MANDIR)/man1
	install -m 0644 Docs/man/oarnodes.1 $(MANDIR)/man1
	install -m 0644 Docs/man/oarresume.1 $(MANDIR)/man1
	install -m 0644 Docs/man/oarstat.1 $(MANDIR)/man1
	install -m 0644 Docs/man/oarsub.1 $(MANDIR)/man1
	install -m 0644 Docs/man/oarhold.1 $(MANDIR)/man1
	rm $(OARDIR)/sudowrapper.sh

node:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -m 0755 Tools/oarsh/oarsh_shell $(OARDIR)
	@if [ -f $(OARDIR)/detect_new_resources.sh ]; then echo "Warning: $(OARDIR)/detect_new_resources.sh already exists, not overwriting it." ; else install -m 0755 Tools/detect_new_resources.sh $(OARDIR) ; fi
	@if [ -f $(OARHOMEDIR)/oar_prologue ]; then echo "Warning: $(OARHOMEDIR)/oar_prologue already exists, not overwriting it." ; else install -o $(OARUSER) -g $(OARGROUP) -m 0755 Scripts/oar_prologue $(OARHOMEDIR) ; fi
	@if [ -f $(OARHOMEDIR)/oar_epilogue ]; then echo "Warning: $(OARHOMEDIR)/oar_epilogue already exists, not overwriting it." ; else install -o $(OARUSER) -g $(OARGROUP) -m 0755 Scripts/oar_epilogue $(OARHOMEDIR) ; fi
	@if [ -f $(OARHOMEDIR)/oar_diffuse_script ]; then echo "Warning: $(OARHOMEDIR)/oar_diffuse_script already exists, not overwriting it." ; else install -o $(OARUSER) -g $(OARGROUP) -m 0755 Scripts/oar_diffuse_script $(OARHOMEDIR) ; fi
	@if [ -f $(OARHOMEDIR)/oar_epilogue_local ]; then echo "Warning: $(OARHOMEDIR)/oar_epilogue_local already exists, not overwriting it." ; else install -o $(OARUSER) -g $(OARGROUP) -m 0755 Scripts/oar_epilogue_local $(OARHOMEDIR) ; fi
	@if [ -f $(OARHOMEDIR)/oar_prologue_local ]; then echo "Warning: $(OARHOMEDIR)/oar_prologue_local already exists, not overwriting it." ; else install -o $(OARUSER) -g $(OARGROUP) -m 0755 Scripts/oar_prologue_local $(OARHOMEDIR) ; fi
	@if [ -f $(OARHOMEDIR)/lock_user.sh ]; then echo "Warning: $(OARHOMEDIR)/lock_user.sh already exists, not overwriting it." ; else install -o $(OARUSER) -g $(OARGROUP) -m 0755 Scripts/lock_user.sh $(OARHOMEDIR) ; fi

doc:
	install -d -m 0755 $(DOCDIR)
	install -m 0644 Docs/Almighty.fig $(DOCDIR)
	install -m 0644 Docs/Almighty.ps $(DOCDIR)
	install -d -m 0755 $(DOCDIR)/html
	install -m 0644 Docs/html/OAR-DOCUMENTATION.html $(DOCDIR)/html
	install -m 0644 Docs/html/oar_logo.png $(DOCDIR)/html
	install -m 0644 Docs/html/db_scheme.png $(DOCDIR)/html
	install -m 0644 Docs/html/interactive_oarsub_scheme.png $(DOCDIR)/html

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

debian-packages:
	dpkg-buildpackage -rfakeroot $(DPKGOPTS)

rpm-packages:
	rpm/rpmbuilder.sh

server-install: sanity-check configuration sudowrapper common server dbinit

user-install: sanity-check configuration sudowrapper common user

node-install: sanity-check configuration sudowrapper node
	@chsh -s $(OARDIR)/oarsh_shell oar

doc-install: doc

draw-gantt-install: draw-gantt

desktop-computing-cgi-install: sanity-check configuration sudowrapper common desktop-computing-cgi
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(DEB_INSTALL)#;;s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(CGIDIR)/oar-cgi 

desktop-computing-agent-install: desktop-computing-agent
