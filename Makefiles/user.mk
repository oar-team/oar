#! /usr/bin/make

include Makefiles/shared/shared.mk

SRCDIR=sources/core

OARDIR_BINFILES = $(SRCDIR)/qfunctions/oarnodes \
		  $(SRCDIR)/qfunctions/oarnodes.v2_3 \
		  $(SRCDIR)/qfunctions/oardel \
		  $(SRCDIR)/qfunctions/oarstat \
		  $(SRCDIR)/qfunctions/oarstat.v2_3 \
		  $(SRCDIR)/qfunctions/oarsub \
		  $(SRCDIR)/qfunctions/oarhold \
		  $(SRCDIR)/qfunctions/oarresume

BINDIR_FILES = $(SRCDIR)/tools/oarmonitor_graph_gen.pl

MANDIR_FILES = $(SRCDIR)/man/man1/oardel.1 \
	       $(SRCDIR)/man/man1/oarnodes.1 \
	       $(SRCDIR)/man/man1/oarresume.1 \
	       $(SRCDIR)/man/man1/oarstat.1 \
	       $(SRCDIR)/man/man1/oarsub.1 \
	       $(SRCDIR)/man/man1/oarhold.1 \
	       $(SRCDIR)/man/man1/oarmonitor_graph_gen.1

clean:
	$(MAKE) -f Makefiles/man.mk clean
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarnodes.v2_3 CMD_TARGET=$(DESTDIR)$(BINDIR)/oarnodes.old 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarnodes CMD_TARGET=$(DESTDIR)$(BINDIR)/oarnodes
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oardel CMD_TARGET=$(DESTDIR)$(BINDIR)/oardel
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarstat.v2_3 CMD_TARGET=$(DESTDIR)$(BINDIR)/oarstat.old
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarstat CMD_TARGET=$(DESTDIR)$(BINDIR)/oarstat
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarsub CMD_TARGET=$(DESTDIR)$(BINDIR)/oarsub
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarhold CMD_TARGET=$(DESTDIR)$(BINDIR)/oarhold
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarresume CMD_TARGET=$(DESTDIR)$(BINDIR)/oarresume


build:
	$(MAKE) -f Makefiles/man.mk build
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarnodes.v2_3 CMD_TARGET=$(DESTDIR)$(BINDIR)/oarnodes.old 
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarnodes CMD_TARGET=$(DESTDIR)$(BINDIR)/oarnodes
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oardel CMD_TARGET=$(DESTDIR)$(BINDIR)/oardel
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarstat.v2_3 CMD_TARGET=$(DESTDIR)$(BINDIR)/oarstat.old
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarstat CMD_TARGET=$(DESTDIR)$(BINDIR)/oarstat
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarsub CMD_TARGET=$(DESTDIR)$(BINDIR)/oarsub
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarhold CMD_TARGET=$(DESTDIR)$(BINDIR)/oarhold
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarresume CMD_TARGET=$(DESTDIR)$(BINDIR)/oarresume


install: install_oarbin install_bin install_man1
	# Rename installed files
	mv $(DESTDIR)$(BINDIR)/oarmonitor_graph_gen.pl $(DESTDIR)$(BINDIR)/oarmonitor_graph_gen	
	
	# Install wrappers
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarnodes.v2_3 CMD_TARGET=$(DESTDIR)$(BINDIR)/oarnodes.old  CMD_RIGHTS=6755
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarnodes CMD_TARGET=$(DESTDIR)$(BINDIR)/oarnodes CMD_RIGHTS=6755
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oardel CMD_TARGET=$(DESTDIR)$(BINDIR)/oardel CMD_RIGHTS=6755
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarstat.v2_3 CMD_TARGET=$(DESTDIR)$(BINDIR)/oarstat.old CMD_RIGHTS=6755
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarstat CMD_TARGET=$(DESTDIR)$(BINDIR)/oarstat CMD_RIGHTS=6755
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarsub CMD_TARGET=$(DESTDIR)$(BINDIR)/oarsub CMD_RIGHTS=6755
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarhold CMD_TARGET=$(DESTDIR)$(BINDIR)/oarhold CMD_RIGHTS=6755
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarresume CMD_TARGET=$(DESTDIR)$(BINDIR)/oarresume CMD_RIGHTS=6755

uninstall: uninstall_oarbin uninstall_bin uninstall_man1
	rm -f $(DESTDIR)$(BINDIR)/oarmonitor_graph_gen	
	
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarnodes.v2_3 CMD_TARGET=$(DESTDIR)$(BINDIR)/oarnodes.old 
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarnodes CMD_TARGET=$(DESTDIR)$(BINDIR)/oarnodes
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oardel CMD_TARGET=$(DESTDIR)$(BINDIR)/oardel
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarstat.v2_3 CMD_TARGET=$(DESTDIR)$(BINDIR)/oarstat.old
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarstat CMD_TARGET=$(DESTDIR)$(BINDIR)/oarstat
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarsub CMD_TARGET=$(DESTDIR)$(BINDIR)/oarsub
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarhold CMD_TARGET=$(DESTDIR)$(BINDIR)/oarhold
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarresume CMD_TARGET=$(DESTDIR)$(BINDIR)/oarresume


