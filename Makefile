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

BINLINKPATH=../oar
SBINLINKPATH=../oar

all: usage
install: usage
usage:
	@echo "Usage: make [ OPTIONS=<...> ] MODULES"
	@echo "Where MODULES := { server-install | user-install | node-install | doc-install | desktop-computing-agent-install | desktop-computing-cgi-install | debian-packages | rpm-packages }"
	@echo "      OPTIONS := { OARHOMEDIR | OARCONFDIR | OARUSER | OARGROUP | PREFIX | MANDIR | OARDIR | BINDIR | SBINDIR | DOCDIR }"

sanity-check:
	@[ $$UID -eq 0 ] || echo "Warning: root-privileges are required to install some files !"
	@id $(OARUSER) > /dev/null || ( echo "Error: User $(OARUSER) does not exist!" ; exit -1 )
	@[ -d $(OARHOMEDIR) ] || ( echo "Error: OAR home directory $(OARHOMEDIR) does not exist!" ; exit -1 )

configuration:
	install -d -m 0755 $(OARCONFDIR)
	@if [ -e $(OARCONFDIR)/oar.conf ]; then echo "Warning: $(OARCONFDIR)/oar.conf already exists, not overwriting it." ; else install -m 0600 -o $(OARUSER) -g root Tools/oar.conf $(OARCONFDIR) ; fi

desktop-computing-agent:
	install -d -m 0755 $(BINDIR)
	install -m 0755 DesktopComputing/oar-agent.pl $(BINDIR)/oar-agent

desktop-computing-cgi:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(SBINDIR)
	install -m 0755 DesktopComputing/oarcache.pl $(OARDIR)/oarcache
	ln -s -f $(SBINLINKPATH)/sudowrapper.sh $(SBINDIR)/oarcache
	install -m 0755 DesktopComputing/oarres.pl $(OARDIR)/oarres
	ln -s -f $(SBINLINKPATH)/sudowrapper.sh $(SBINDIR)/oarres
	install -m 0755 DesktopComputing/oar-cgi.pl $(OARDIR)/oar-cgi
	install -d -m 0755 $(CGIDIR)
	install -m 0755 Tools/sudowrapper.sh $(CGIDIR)/oar-cgi
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(OARDIR)#;;s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(CGIDIR)/oar-cgi 

dbinit:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(SBINDIR)
	install -m 0755 DB/oar_db_init.pl $(OARDIR)/oar_db_init
	ln -s -f $(SBINLINKPATH)/sudowrapper.sh $(SBINDIR)/oar_db_init
	install -m 0644 DB/oar_jobs.sql $(OARDIR)

common:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -d -m 0755 $(SBINDIR)
	install -m 0755 Tools/sudowrapper.sh $(OARDIR)
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(OARDIR)#;;s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(OARDIR)/sudowrapper.sh 
	install -m 0644 ConfLib/oar_conflib.pm $(OARDIR)
	install -m 0644 Iolib/oar_iolib.pm $(OARDIR)
	install -m 0644 Judas/oar_Judas.pm $(OARDIR)
#	install -o $(OARUSER) -g $(OARGROUP) -m 700 Leon/oarkill $(OARDIR)
#	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oarkill
#	install -m 0755 Runner/bipbip $(OARDIR)
#	install -m 0644 Runner/ping_checker.pm $(OARDIR)
	install -m 0755 Qfunctions/oarnodesetting $(OARDIR)
	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oarnodesetting
	install -m 0755 Tools/deploy_nodes.sh $(OARDIR)
	install -m 0644 Tools/oarversion.pm $(OARDIR)
	install -m 0644 Tools/oar_Tools.pm $(OARDIR)

server:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -d -m 0755 $(SBINDIR)
	install -m 0755 Almighty/Almighty $(OARDIR)
	ln -s -f $(SBINLINKPATH)/sudowrapper.sh $(SBINDIR)/Almighty
	install -m 0755 Leon/Leon	$(OARDIR)
	install -m 0755 Runner/runner $(OARDIR)
	install -m 0755 Sarko/sarko $(OARDIR)
	install -m 0755 Sarko/finaud $(OARDIR)
	install -m 0644 Scheduler/data_structures/Gantt.pm $(OARDIR)
	install -m 0644 Scheduler/data_structures/Gantt_2.pm $(OARDIR)
	install -m 0755 Scheduler/oar_sched_gantt $(OARDIR)
	install -m 0755 Scheduler/oar_sched_gantt_with_timesharing $(OARDIR)
	install -m 0755 Scheduler/oar_meta_sched $(OARDIR)
	install -m 0644 Scheduler/oar_scheduler.pm $(OARDIR)
	install -m 0755 Qfunctions/oarnotify $(OARDIR)
	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oarnotify
	install -m 0755 NodeChangeState/NodeChangeState $(OARDIR)
	install -m 0755 DesktopComputing/oar-cgi.pl $(OARDIR)
	install -m 0755 Qfunctions/oarremoveresource $(OARDIR)
	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(SBINDIR)/oarremoveresource
	install -m 0755 Qfunctions/oaraccounting $(OARDIR)
	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oaraccounting
	install -m 0755 Qfunctions/oarproperty $(OARDIR)
	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oarproperty
	install -m 0644 Scheduler/data_structures/oar_resource_tree.pm $(OARDIR)
	install -m 0644 Scheduler/data_structures/sorted_chained_list.pm $(OARDIR)
	install -m 0755 Runner/bipbip $(OARDIR)
	install -m 0644 Runner/ping_checker.pm $(OARDIR)
	install -m 0755 Runner/oarexec $(OARDIR)

user:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
	install -m 0755 Qfunctions/oarnodes $(OARDIR)
	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oarnodes
	install -m 0755 Qfunctions/oardel $(OARDIR)
	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oardel
	install -m 0755 Qfunctions/oarstat $(OARDIR)
	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oarstat
	install -m 0755 Qfunctions/oarsub $(OARDIR)
	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oarsub
	install -m 0755 Qfunctions/oarhold $(OARDIR)
	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oarhold
	install -m 0755 Qfunctions/oarresume $(OARDIR)
	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oarresume
#	install -m 0755 DesktopComputing/oarfetch.sh $(OARDIR)/oarfetch
#	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oarfetch
	install -d -m 0755 $(MANDIR)/man1
	install -m 0644 Docs/man/oardel.1 $(MANDIR)/man1
	install -m 0644 Docs/man/oarnodes.1 $(MANDIR)/man1
	install -m 0644 Docs/man/oarresume.1 $(MANDIR)/man1
	install -m 0644 Docs/man/oarstat.1 $(MANDIR)/man1
	install -m 0644 Docs/man/oarsub.1 $(MANDIR)/man1
	install -m 0644 Docs/man/oarhold.1 $(MANDIR)/man1
	install -m 0644 Scheduler/data_structures/oar_resource_tree.pm $(OARDIR)

node:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(BINDIR)
#	install -m 0755 Runner/oarexec $(OARDIR)
#	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oarexec
#	install -o $(OARUSER) -g $(OARGROUP) -m 0755 Runner/oarexecuser.sh $(OARDIR)
	install -o $(OARUSER) -g $(OARGROUP) -m 0755 Scripts/oar_prologue $(OARHOMEDIR)
	install -o $(OARUSER) -g $(OARGROUP) -m 0755 Scripts/oar_epilogue $(OARHOMEDIR)
	install -o $(OARUSER) -g $(OARGROUP) -m 0755 Scripts/oar_diffuse_script $(OARHOMEDIR)
	install -o $(OARUSER) -g $(OARGROUP) -m 0755 Scripts/oar_epilogue_local $(OARHOMEDIR)
	install -o $(OARUSER) -g $(OARGROUP) -m 0755 Scripts/oar_prologue_local $(OARHOMEDIR)
	install -o $(OARUSER) -g $(OARGROUP) -m 0644 Scripts/lock_user.sh $(OARHOMEDIR)

cpuset:
	install -m 0755 Tools/oarsh/oarsh $(OARDIR)
	ln -s -f $(BINLINKPATH)/sudowrapper.sh $(BINDIR)/oarsh
	install -m 0755 Tools/oarsh/oarsh_shell $(OARDIR)

doc:
	install -d -m 0755 $(DOCDIR)
	install -m 0644 Docs/Almighty.fig $(DOCDIR)
	install -m 0644 Docs/Almighty.ps $(DOCDIR)
	install -d -m 0755 $(DOCDIR)/html
	install -m 0644 Docs/html/index.html $(DOCDIR)/html
	install -m 0644 Docs/html/oar_logo.png $(DOCDIR)/html
	install -m 0644 Docs/html/HOWTO-OAR.html $(DOCDIR)/html

draw-gantt:
	install -d -m 0755 $(OARDIR)
	install -d -m 0755 $(CGIDIR)
	install -d -m 0755 $(WWWDIR)
	install -m 0755 DrawGantt/DrawOARGantt.pl $(CGIDIR)
	install -d -m 0755 $(OARCONFDIR)
	@if [ -e $(OARCONFDIR)/DrawGantt.conf ]; then echo "Warning: $(OARCONFDIR)/DrawGantt.conf already exists, not overwriting it." ; else install -m 0644 DrawGantt/DrawGantt.conf $(OARCONFDIR) ; fi
	install -m 0644 ConfLib/oar_conflib.pm $(CGIDIR)
	install -d -m 0755 $(WWWDIR)/DrawGantt/Icons
	install -d -m 0755 $(WWWDIR)/DrawGantt/js
	install -m 0644 DrawGantt/Icons/*.png $(WWWDIR)/DrawGantt/Icons
	install -m 0644 DrawGantt/js/*.js $(WWWDIR)/DrawGantt/js

debian-packages:
	dpkg-buildpackage -rfakeroot $(DPKGOPTS)

rpm-packages:
	rpm/rpmbuilder.sh

server-install: sanity-check configuration common server dbinit

user-install: sanity-check configuration common user

node-install: sanity-check configuration common node

cpuset-install: sanity-check configuration common cpuset

doc-install: doc

draw-gantt-install: user-install draw-gantt

desktop-computing-cgi-install: sanity-check configuration common desktop-computing-cgi

desktop-computing-agent-install: desktop-computing-agent
