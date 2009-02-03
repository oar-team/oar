#!/usr/bin/make
# $Id: Makefile,v 1.5 2006/01/31 10:09:40 capitn Exp $
SHELL=/bin/bash

DESTDIR=

OARGRIDCONFDIR=etc
OARGRIDUSER=oargrid
OARGRIDGROUP=oargrid

PREFIX=usr/local
OARGRIDDIR=$(PREFIX)/lib/oargrid
MANDIR=$(PREFIX)/man
BINDIR=$(PREFIX)/bin
SBINDIR=$(PREFIX)/sbin

BINLINKPATH=../oargrid
SBINLINKPATH=../oargrid
CMDSLINKPATH=../
CONFIG_CMDS=$(OARGRIDDIR)/cmds

CGIDIR=usr/lib/cgi-bin

all: usage
usage:
	@echo "Usage: make [ OPTIONS=<...> ] MODULES"
	@echo "Where MODULES := { install | deb }"
	@echo "      OPTIONS := { DESTDIR | OARGRIDCONFDIR | OARGRIDUSER | OARGRIDGROUP | PREFIX | MANDIR | OARGRIDDIR | BINDIR | SBINDIR | CGIDIR }"

sanity-check:
	@[ `whoami` == 'root' ] || echo "Warning: You may need to be root in order to install some files!"
	@id $(OARGRIDUSER) > /dev/null || ( echo "Error: User $(OARGRIDUSER) does not exist!" ; exit -1 )

configuration:
	mkdir -p $(DESTDIR)/$(OARGRIDCONFDIR)
	@if [ -e $(DESTDIR)/$(OARGRIDCONFDIR)/oargrid.conf ]; then echo "Warning: $(DESTDIR)/$(OARGRIDCONFDIR)/oargrid.conf already exists, not overwritting it." ; else install -m 600 oargrid.conf $(DESTDIR)/$(OARGRIDCONFDIR) ;	fi
	-chown $(OARGRIDUSER).$(OARGRIDGROUP) $(DESTDIR)/$(OARGRIDCONFDIR)

common:
	mkdir -p $(DESTDIR)/$(OARGRIDDIR)
	mkdir -p $(DESTDIR)/$(CONFIG_CMDS)
	mkdir -p $(DESTDIR)/$(BINDIR)
	install -m 0755 configurator_wrapper.sh $(DESTDIR)/$(OARGRIDDIR)
	perl -i -pe "s#^OARGRIDDIR=.*#OARGRIDDIR=/$(OARGRIDDIR)#;;s#^OARGRIDUSER=.*#OARGRIDUSER=$(OARGRIDUSER)#" $(DESTDIR)/$(OARGRIDDIR)/configurator_wrapper.sh 
	install -m 755 oargrid_sudowrapper.sh $(DESTDIR)/$(OARGRIDDIR)
	perl -i -pe "s#^OARGRIDDIR=.*#OARGRIDDIR=/$(OARGRIDDIR)#;;s#^OARGRIDUSER=.*#OARGRIDUSER=$(OARGRIDUSER)#" $(DESTDIR)/$(OARGRIDDIR)/oargrid_sudowrapper.sh 
	install -m 755 oargrid_conflib.pm $(DESTDIR)/$(OARGRIDDIR)
	install -m 755 oargrid_lib.pm $(DESTDIR)/$(OARGRIDDIR)
	install -m 755 mailer.pm $(DESTDIR)/$(OARGRIDDIR)
	install -m 755 oargriddel $(DESTDIR)/$(OARGRIDDIR)
	ln -sf /$(OARGRIDDIR)/configurator_wrapper.sh $(DESTDIR)/$(CONFIG_CMDS)/oargriddel
	ln -sf /$(OARGRIDDIR)/oargrid_sudowrapper.sh $(DESTDIR)/$(BINDIR)/oargriddel
	install -m 755 oargridsub $(DESTDIR)/$(OARGRIDDIR)
	ln -sf /$(OARGRIDDIR)/configurator_wrapper.sh $(DESTDIR)/$(CONFIG_CMDS)/oargridsub
	ln -sf /$(OARGRIDDIR)/oargrid_sudowrapper.sh $(DESTDIR)/$(BINDIR)/oargridsub
	install -m 755 oargridstat $(DESTDIR)/$(OARGRIDDIR)
	ln -sf /$(OARGRIDDIR)/configurator_wrapper.sh $(DESTDIR)/$(CONFIG_CMDS)/oargridstat
	ln -sf /$(OARGRIDDIR)/oargrid_sudowrapper.sh $(DESTDIR)/$(BINDIR)/oargridstat
	mkdir -p $(DESTDIR)/$(CGIDIR)
	install -m 755 oargridmonitor.cgi $(DESTDIR)/$(CGIDIR)

manual:
	mkdir -p $(DESTDIR)/$(MANDIR)/man1
	install -m 644 man/oargriddel.1 $(DESTDIR)/$(MANDIR)/man1
	install -m 644 man/oargridsub.1 $(DESTDIR)/$(MANDIR)/man1
	install -m 644 man/oargridstat.1 $(DESTDIR)/$(MANDIR)/man1

install: sanity-check configuration common manual

clean:
	-rm -f $(DESTDIR)/$(CONFIG_CMDS)/oargriddel \
	 $(DESTDIR)/$(CONFIG_CMDS)/oargridsub \
	 $(DESTDIR)/$(CONFIG_CMDS)/oargridstat \
	 $(DESTDIR)/$(CGIDIR)/oargridmonitor.cgi \
	 $(DESTDIR)/$(OARGRIDDIR)/configurator_wrapper.sh \
	 $(DESTDIR)/$(OARGRIDDIR)/oargrid_sudowrapper.sh \
	 $(DESTDIR)/$(OARGRIDDIR)/oargrid_conflib.pm \
	 $(DESTDIR)/$(OARGRIDDIR)/mailer.pm \
	 $(DESTDIR)/$(OARGRIDDIR)/oargrid_lib.pm \
	 $(DESTDIR)/$(OARGRIDDIR)/oargriddel \
	 $(DESTDIR)/$(OARGRIDDIR)/oargridsub \
	 $(DESTDIR)/$(OARGRIDDIR)/oargridstat \
	 $(DESTDIR)/$(BINDIR)/oargridsub \
	 $(DESTDIR)/$(BINDIR)/oargridstat \
	 $(DESTDIR)/$(BINDIR)/oargriddel
	-rmdir $(DESTDIR)/$(CONFIG_CMDS)
	-rmdir $(DESTDIR)/$(OARGRIDDIR)

deb:
	svn-buildpackage -rfakeroot -us -uc --svn-ignore
