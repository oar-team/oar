#! /usr/bin/make

include Makefiles/shared/shared.mk

SRCDIR=sources/core

OARDIR_BINFILES = $(SRCDIR)/modules/almighty.pl \
	          $(SRCDIR)/modules/leon.pl \
		  $(SRCDIR)/modules/runner/runner \
	          $(SRCDIR)/modules/sarko.pl \
	          $(SRCDIR)/modules/finaud.pl \
	          $(SRCDIR)/modules/scheduler/oar_meta_sched \
		  $(SRCDIR)/qfunctions/oarnotify \
		  $(SRCDIR)/modules/node_change_state.pl \
		  $(SRCDIR)/qfunctions/oarremoveresource \
		  $(SRCDIR)/qfunctions/oaraccounting \
		  $(SRCDIR)/qfunctions/oarproperty \
		  $(SRCDIR)/qfunctions/oarmonitor \
		  $(SRCDIR)/modules/runner/bipbip \
		  $(SRCDIR)/tools/detect_resources \
		  $(SRCDIR)/tools/oar_checkdb.pl


OAR_PERLLIB = $(SRCDIR)/server/lib
OARDIR_DATAFILES = $(SRCDIR)/modules/runner/oarexec

	  
OARSCHEDULER_BINFILES = $(SRCDIR)/modules/scheduler/oar_sched_gantt_with_timesharing \
		        $(SRCDIR)/modules/scheduler/oar_sched_gantt_with_timesharing_and_fairsharing \
		        $(SRCDIR)/modules/scheduler/oar_sched_gantt_with_timesharing_and_fairsharing_and_placeholder  
OARCONFDIR_BINFILES = $(SRCDIR)/tools/oar_phoenix.pl

MANDIR_FILES = $(SRCDIR)/man/man1/Almighty.1 \
	       $(SRCDIR)/man/man1/oar_mysql_db_init.1 \
	       $(SRCDIR)/man/man1/oaraccounting.1 \
	       $(SRCDIR)/man/man1/oarmonitor.1 \
	       $(SRCDIR)/man/man1/oarnotify.1 \
	       $(SRCDIR)/man/man1/oarproperty.1 \
	       $(SRCDIR)/man/man1/oarremoveresource.1 \

clean:
	$(MAKE) -f Makefiles/man.mk clean
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/detect_resources CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_resources_init
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/Almighty CMD_TARGET=$(DESTDIR)$(SBINDIR)/Almighty
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarnotify CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnotify
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarremoveresource CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarremoveresource
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oaraccounting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaraccounting
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarproperty CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarproperty
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarmonitor CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarmonitor
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/detect_resources CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_resources_init
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oar_checkdb.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_checkdb
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARCONFDIR)/oar_phoenix.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_phoenix	
	

build:
	$(MAKE) -f Makefiles/man.mk build
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/detect_resources CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_resources_init
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/Almighty CMD_TARGET=$(DESTDIR)$(SBINDIR)/Almighty
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarnotify CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnotify
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarremoveresource CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarremoveresource
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oaraccounting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaraccounting
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarproperty CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarproperty
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarmonitor CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarmonitor
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/detect_resources CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_resources_init
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oar_checkdb.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_checkdb
	$(OARDO_BUILD) CMD_WRAPPER=$(OARCONFDIR)/oar_phoenix.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_phoenix	
	



install: build install_perllib install_oarbin install_oardata install_man1
	
	install -m 0755 -d $(DESTDIR)$(OARDIR)/schedulers
	install -m 0755 -t $(DESTDIR)$(OARDIR)/schedulers $(OARSCHEDULER_BINFILES) 
	
	install -m 0755 -d $(DESTDIR)$(OARCONFDIR)
	install -m 0750 -t $(DESTDIR)$(OARCONFDIR) $(OARCONFDIR_BINFILES)
	
	# Rename installed files
	mv $(DESTDIR)$(OARDIR)/almighty.pl $(DESTDIR)$(OARDIR)/Almighty
	mv $(DESTDIR)$(OARDIR)/leon.pl $(DESTDIR)$(OARDIR)/Leon
	mv $(DESTDIR)$(OARDIR)/sarko.pl $(DESTDIR)$(OARDIR)/sarko
	mv $(DESTDIR)$(OARDIR)/finaud.pl $(DESTDIR)$(OARDIR)/finaud
	mv $(DESTDIR)$(OARDIR)/node_change_state.pl $(DESTDIR)$(OARDIR)/NodeChangeState
	
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/detect_resources CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_resources_init
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/Almighty CMD_TARGET=$(DESTDIR)$(SBINDIR)/Almighty
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarnotify CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnotify
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarremoveresource CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarremoveresource
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oaraccounting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaraccounting
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarproperty CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarproperty
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarmonitor CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarmonitor
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/detect_resources CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_resources_init
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oar_checkdb.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_checkdb
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARCONFDIR)/oar_phoenix.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_phoenix	
	
	@if [ -f $(DESTDIR)$(OARCONFDIR)/job_resource_manager.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/job_resource_manager.pl already exists, not overwriting it." ; else install -m 0644 $(SRCDIR)/tools/job_resource_manager.pl $(DESTDIR)$(OARCONFDIR); fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/suspend_resume_manager.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/suspend_resume_manager.pl already exists, not overwriting it." ; else install -m 0644 $(SRCDIR)/tools/suspend_resume_manager.pl $(DESTDIR)$(OARCONFDIR); fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/oarmonitor_sensor.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/oarmonitor_sensor.pl already exists, not overwriting it." ; else install -m 0644 $(SRCDIR)/tools/oarmonitor_sensor.pl $(DESTDIR)$(OARCONFDIR); fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/server_prologue ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/server_prologue already exists, not overwriting it." ; else install -m 0755 $(SRCDIR)/scripts/server_prologue $(DESTDIR)$(OARCONFDIR) ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/server_epilogue ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/server_epilogue already exists, not overwriting it." ; else install -m 0755 $(SRCDIR)/scripts/server_epilogue $(DESTDIR)$(OARCONFDIR) ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/wake_up_nodes.sh ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/wake_up_nodes.sh already exists, not overwriting it." ; else install -m 0755 $(SRCDIR)/tools/wake_up_nodes.sh $(DESTDIR)$(OARCONFDIR) ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/shut_down_nodes.sh ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/shut_down_nodes.sh already exists, not overwriting it." ; else install -m 0755 $(SRCDIR)/tools/shut_down_nodes.sh $(DESTDIR)$(OARCONFDIR) ; fi
	
uninstall: uninstall_oarbin uninstall_perllib uninstall_oardata uninstall_man1
	@for file in $(OARCONFDIR_FILES); do rm -f $(DESTDIR)$(OARCONFDIR)/`basename $$file`; done
	@for file in $(OARSCHEDULER_BINFILES); do rm -f $(DESTDIR)$(OARDIR)/schedulers/`basename $$file`; done
	rm -f $(DESTDIR)$(OARDIR)/Almighty
	rm -f $(DESTDIR)$(OARDIR)/Leon
	rm -f $(DESTDIR)$(OARDIR)/Pythia
	rm -f $(DESTDIR)$(OARDIR)/sarko
	rm -f $(DESTDIR)$(OARDIR)/finaud
	rm -f $(DESTDIR)$(OARDIR)/NodeChangeState
	
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/detect_resources CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_resources_init
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/Almighty CMD_TARGET=$(DESTDIR)$(SBINDIR)/Almighty
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarnotify CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnotify
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarremoveresource CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarremoveresource
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oaraccounting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oaraccounting
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarproperty CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarproperty
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarmonitor CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarmonitor
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/detect_resources CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_resources_init
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oar_checkdb.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_checkdb
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARCONFDIR)/oar_phoenix.pl CMD_TARGET=$(DESTDIR)$(SBINDIR)/oar_phoenix	

