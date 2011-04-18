#! /usr/bin/make

include Makefiles/shared/shared.mk

OARDIR_DATAFILES = libs/oar_conflib.pm \
		   libs/oar_iolib.pm \
		   libs/oarnodes_lib.pm \
		   libs/oarstat_lib.pm \
		   libs/oarsub_lib.pm \
		   modules/judas.pm \
		   modules/scheduler/data_structures/oar_resource_tree.pm \
		   tools/oarversion.pm \
		   tools/oar_Tools.pm

OARDIR_BINFILES = qfunctions/oarnodesetting \
		  tools/sentinelle.pl

MANDIR_FILES = man/man1/oarnodesetting.1

clean:
	$(MAKE) -f Makefiles/man.mk clean
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarnodesetting 

build:
	$(MAKE) -f Makefiles/man.mk build
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarnodesetting

install:
	install -m 0755 -d $(DESTDIR)$(OARDIR)
	install -m 0755 -t $(DESTDIR)$(OARDIR) $(OARDIR_BINFILES)
	install -m 0644 -t $(DESTDIR)$(OARDIR) $(OARDIR_DATAFILES)
	
	# Rename installed files
	mv $(DESTDIR)$(OARDIR)/judas.pm $(DESTDIR)$(OARDIR)/oar_Judas.pm
	
	install -m 0755 -d $(DESTDIR)$(SBINDIR)
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting
	
	install -m 0755 -d $(DESTDIR)$(OARCONFDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/oarnodesetting_ssh ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/oarnodesetting_ssh already exists, not overwriting it." ; else install -m 0755 tools/oarnodesetting_ssh $(DESTDIR)$(OARCONFDIR); fi
	perl -i -pe "s#^OARNODESETTINGCMD=.*#OARNODESETTINGCMD=$(SBINDIR)/oarnodesetting#" $(DESTDIR)$(OARCONFDIR)/oarnodesetting_ssh
	@if [ -f $(DESTDIR)$(OARCONFDIR)/update_cpuset_id.sh ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/update_cpuset_id.sh already exists, not overwriting it." ; else install -m 0755 tools/update_cpuset_id.sh $(DESTDIR)$(OARCONFDIR); fi
	perl -i -pe "s#^OARNODESETTINGCMD=.*#OARNODESETTINGCMD=$(SBINDIR)/oarnodesetting#" $(DESTDIR)$(OARCONFDIR)/update_cpuset_id.sh
	perl -i -pe "s#^OARNODESCMD=.*#OARNODESCMD=$(BINDIR)/oarnodes#" $(DESTDIR)$(OARCONFDIR)/update_cpuset_id.sh
	
	install -m 0755 -d $(DESTDIR)$(MANDIR)/man1
	install -m 0644 -t $(DESTDIR)$(MANDIR)/man1 $(MANDIR_FILES)

uninstall:
	@for file in $(OARDIR_BINFILES); do rm $(DESTDIR)$(OARDIR)/`basename $$file`; done
	@for file in $(OARDIR_DATAFILES); do rm $(DESTDIR)$(OARDIR)/`basename $$file`; done
	@for file in $(MANDIR_FILES); do rm $(DESTDIR)$(MANDIR)/man1/`basename $$file`; done
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting



