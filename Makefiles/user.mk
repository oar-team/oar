#! /usr/bin/make

include Makefiles/shared/shared.mk

OARDIR_BINFILES = qfunctions/oarnodes \
		  qfunctions/oarnodes.v2_3 \
		  qfunctions/oardel \
		  qfunctions/oarstat \
		  qfunctions/oarstat.v2_3 \
		  qfunctions/oarsub \
		  qfunctions/oarhold \
		  qfunctions/oarresume

BINDIR_FILES = tools/oarmonitor_graph_gen.pl

MANDIR_FILES = man/man1/oardel.1 \
	       man/man1/oarnodes.1 \
	       man/man1/oarresume.1 \
	       man/man1/oarstat.1 \
	       man/man1/oarsub.1 \
	       man/man1/oarhold.1 \
	       man/man1/oarmonitor_graph_gen.1

clean:
	$(MAKE) -f Makefiles/man.mk clean
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarnodes.v2_3 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarnodes 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oardel 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarstat.v2_3 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarstat 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarsub 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarhold 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarresume


build:
	$(MAKE) -f Makefiles/man.mk build
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarnodes.v2_3 
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarnodes 
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oardel 
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarstat.v2_3 
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarstat 
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarsub 
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarhold 
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarresume 


install:
	install -m 0755 -d $(DESTDIR)$(OARDIR)
	install -m 0755 -t $(DESTDIR)$(OARDIR) $(OARDIR_BINFILES)
	
	install -m 0755 -d $(DESTDIR)$(BINDIR)
	install -m 0755 -t $(DESTDIR)$(BINDIR) $(BINDIR_FILES)
	
	install -m 0755 -d $(DESTDIR)$(MANDIR)/man1
	install -m 0644 -t $(DESTDIR)$(MANDIR)/man1 $(MANDIR_FILES)
	
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

uninstall:
	@for file in $(OARDIR_BINFILES); do rm -f $(DESTDIR)$(OARDIR)/`basename $$file`; done
	@for file in $(BINDIR_FILES); do rm -f $(DESTDIR)$(BINDIR)/`basename $$file`; done
	@for file in $(MANDIR_FILES); do rm -f $(DESTDIR)$(MANDIR)/man1/`basename $$file`; done
	
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarnodes.v2_3 CMD_TARGET=$(DESTDIR)$(BINDIR)/oarnodes.old  CMD_RIGHTS=6755
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarnodes CMD_TARGET=$(DESTDIR)$(BINDIR)/oarnodes CMD_RIGHTS=6755
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oardel CMD_TARGET=$(DESTDIR)$(BINDIR)/oardel CMD_RIGHTS=6755
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarstat.v2_3 CMD_TARGET=$(DESTDIR)$(BINDIR)/oarstat.old CMD_RIGHTS=6755
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarstat CMD_TARGET=$(DESTDIR)$(BINDIR)/oarstat CMD_RIGHTS=6755
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarsub CMD_TARGET=$(DESTDIR)$(BINDIR)/oarsub CMD_RIGHTS=6755
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarhold CMD_TARGET=$(DESTDIR)$(BINDIR)/oarhold CMD_RIGHTS=6755
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarresume CMD_TARGET=$(DESTDIR)$(BINDIR)/oarresume CMD_RIGHTS=6755


