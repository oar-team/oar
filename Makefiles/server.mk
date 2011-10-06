MODULE=server
SRCDIR=sources/core

OARDIR_BINFILES = $(SRCDIR)/modules/runner/runner \
	          $(SRCDIR)/modules/scheduler/oar_meta_sched \
		  $(SRCDIR)/qfunctions/oarnotify \
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
	       $(SRCDIR)/man/man1/oaraccounting.1 \
	       $(SRCDIR)/man/man1/oarmonitor.1 \
	       $(SRCDIR)/man/man1/oarnotify.1 \
	       $(SRCDIR)/man/man1/oarproperty.1 \
	       $(SRCDIR)/man/man1/oarremoveresource.1 \
	       $(SRCDIR)/man/man1/oar-server.1 \
	       $(SRCDIR)/man/man1/oar_resources_init.1 \
	       $(SRCDIR)/man/man1/oar_phoenix.1 \
	       $(SRCDIR)/man/man1/oar_checkdb.1

SBINDIR_FILES = $(SRCDIR)/server/sbin/oar-server.in

EXAMPLEDIR_FILES = $(SRCDIR)/tools/job_resource_manager.pl \
		   $(SRCDIR)/tools/suspend_resume_manager.pl \
		   $(SRCDIR)/tools/oarmonitor_sensor.pl \
		   $(SRCDIR)/scripts/server_epilogue \
		   $(SRCDIR)/scripts/server_prologue \
		   $(SRCDIR)/tools/wake_up_nodes.sh \
		   $(SRCDIR)/tools/shut_down_nodes.sh

PROCESS_TEMPLATE_FILES = $(DESTDIR)$(EXAMPLEDIR)/default/oar-server.in \
			 $(DESTDIR)$(EXAMPLEDIR)/init.d/oar-server.in \
			 $(DESTDIR)$(EXAMPLEDIR)/cron.d/oar-server.in \
			 $(DESTDIR)$(SBINDIR)/oar-server.in 


include Makefiles/shared/shared.mk

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
	
install: build install_before install_shared

install_before:
	install -d $(DESTDIR)$(OARDIR)/schedulers
	install -m 0755 $(OARSCHEDULER_BINFILES) $(DESTDIR)$(OARDIR)/schedulers 
	
	install -d $(DESTDIR)$(OARCONFDIR)
	install -m 0750 $(OARCONFDIR_BINFILES) $(DESTDIR)$(OARCONFDIR)
	
	install -m 0755 $(SRCDIR)/modules/almighty.pl $(DESTDIR)$(OARDIR)/Almighty
	install -m 0755 $(SRCDIR)/modules/leon.pl $(DESTDIR)$(OARDIR)/Leon
	install -m 0755 $(SRCDIR)/modules/sarko.pl $(DESTDIR)$(OARDIR)/sarko
	install -m 0755 $(SRCDIR)/modules/finaud.pl $(DESTDIR)$(OARDIR)/finaud
	install -m 0755 $(SRCDIR)/modules/node_change_state.pl $(DESTDIR)$(OARDIR)/NodeChangeState
	
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
	
	install -d $(DESTDIR)$(EXAMPLEDIR)/init.d	
	install -m 0755 setup/init.d/oar-server.in $(DESTDIR)$(EXAMPLEDIR)/init.d
	
	install -d $(DESTDIR)$(EXAMPLEDIR)/default
	install -m 0644  setup/default/oar-server.in $(DESTDIR)$(EXAMPLEDIR)/default
	
	install -d $(DESTDIR)$(EXAMPLEDIR)/cron.d
	install -m 0644  setup/cron.d/oar-server.in $(DESTDIR)$(EXAMPLEDIR)/cron.d

uninstall: uninstall_shared
	@for file in $(OARCONFDIR_FILES); do rm -f $(DESTDIR)$(OARCONFDIR)/`basename $$file`; done
	@for file in $(OARSCHEDULER_BINFILES); do rm -f $(DESTDIR)$(OARDIR)/schedulers/`basename $$file`; done
	rm -f $(DESTDIR)$(OARDIR)/Almighty
	rm -f $(DESTDIR)$(OARDIR)/Leon
	rm -f $(DESTDIR)$(OARDIR)/sarko
	rm -f $(DESTDIR)$(OARDIR)/finaud
	rm -f $(DESTDIR)$(OARDIR)/NodeChangeState
	
	rm -rf $(DESTDIR)$(EXAMPLEDIR)
	
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

.PHONY: install setup uninstall build clean
