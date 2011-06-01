#! /usr/bin/make

include Makefiles/shared/shared.mk

OARDIR_BINFILES = modules/almighty.pl \
	          modules/leon.pl \
		  modules/runner/runner \
	          modules/sarko.pl \
	          modules/finaud.pl \
	          modules/scheduler/oar_meta_sched \
		  qfunctions/oarnotify \
		  modules/node_change_state.pl \
		  qfunctions/oarremoveresource \
		  qfunctions/oaraccounting \
		  qfunctions/oarproperty \
		  qfunctions/oarmonitor \
		  modules/runner/bipbip \
		  tools/detect_resources \
		  tools/oar_checkdb.pl


OARDIR_DATAFILES = modules/scheduler/data_structures/Gantt_hole_storage.pm \
		   modules/scheduler/oar_scheduler.pm \
		   modules/hulot.pm \
		   libs/window_forker.pm \
		   modules/runner/ping_checker.pm \
		   modules/runner/oarexec

	  
OARSCHEDULER_BINFILES = modules/scheduler/oar_sched_gantt_with_timesharing \
		        modules/scheduler/oar_sched_gantt_with_timesharing_and_fairsharing 
OARCONFDIR_BINFILES = tools/oar_phoenix.pl

MANDIR_FILES = man/man1/Almighty.1 \
	       man/man1/oar_mysql_db_init.1 \
	       man/man1/oaraccounting.1 \
	       man/man1/oarmonitor.1 \
	       man/man1/oarnotify.1 \
	       man/man1/oarproperty.1 \
	       man/man1/oarremoveresource.1 \

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
	



install: build
	install -m 0755 -d $(DESTDIR)$(OARDIR)
	install -m 0755 -t $(DESTDIR)$(OARDIR) $(OARDIR_BINFILES) 
	install -m 0644 -t $(DESTDIR)$(OARDIR) $(OARDIR_DATAFILES)
	
	install -m 0755 -d $(DESTDIR)$(OARDIR)/schedulers
	install -m 0755 -t $(DESTDIR)$(OARDIR)/schedulers $(OARSCHEDULER_BINFILES) 
	
	install -m 0755 -d $(DESTDIR)$(OARCONFDIR)
	install -m 0750 -t $(DESTDIR)$(OARCONFDIR) $(OARCONFDIR_BINFILES)
	
	# Rename installed files
	mv $(DESTDIR)$(OARDIR)/almighty.pl $(DESTDIR)$(OARDIR)/Almighty
	mv $(DESTDIR)$(OARDIR)/leon.pl $(DESTDIR)$(OARDIR)/Leon
	mv $(DESTDIR)$(OARDIR)/sarko.pl $(DESTDIR)$(OARDIR)/sarko
	mv $(DESTDIR)$(OARDIR)/finaud.pl $(DESTDIR)$(OARDIR)/finaud
	mv $(DESTDIR)$(OARDIR)/hulot.pm $(DESTDIR)$(OARDIR)/oar_Hulot.pm
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
	
	install -m 0755 -d $(DESTDIR)$(MANDIR)/man1
	install -m 0644 -t $(DESTDIR)$(MANDIR)/man1 $(MANDIR_FILES)
	
	@if [ -f $(DESTDIR)$(OARCONFDIR)/job_resource_manager.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/job_resource_manager.pl already exists, not overwriting it." ; else install -m 0644 tools/job_resource_manager.pl $(DESTDIR)$(OARCONFDIR); fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/suspend_resume_manager.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/suspend_resume_manager.pl already exists, not overwriting it." ; else install -m 0644 tools/suspend_resume_manager.pl $(DESTDIR)$(OARCONFDIR); fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/oarmonitor_sensor.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/oarmonitor_sensor.pl already exists, not overwriting it." ; else install -m 0644 tools/oarmonitor_sensor.pl $(DESTDIR)$(OARCONFDIR); fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/server_prologue ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/server_prologue already exists, not overwriting it." ; else install -m 0755 scripts/server_prologue $(DESTDIR)$(OARCONFDIR) ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/server_epilogue ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/server_epilogue already exists, not overwriting it." ; else install -m 0755 scripts/server_epilogue $(DESTDIR)$(OARCONFDIR) ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/wake_up_nodes.sh ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/wake_up_nodes.sh already exists, not overwriting it." ; else install -m 0755 tools/wake_up_nodes.sh $(DESTDIR)$(OARCONFDIR) ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/shut_down_nodes.sh ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/shut_down_nodes.sh already exists, not overwriting it." ; else install -m 0755 tools/shut_down_nodes.sh $(DESTDIR)$(OARCONFDIR) ; fi
	
uninstall:
	@for file in $(OARDIR_BINFILES); do rm -f $(DESTDIR)$(OARDIR)/`basename $$file`; done
	@for file in $(OARDIR_DATAFILES); do rm -f $(DESTDIR)$(OARDIR)/`basename $$file`; done
	@for file in $(OARCONFDIR_FILES); do rm -f $(DESTDIR)$(OARCONFDIR)/`basename $$file`; done
	@for file in $(OARSCHEDULER_BINFILES); do rm -f $(DESTDIR)$(OARDIR)/schedulers/`basename $$file`; done
	@for file in $(MANDIR_FILES); do rm -f $(DESTDIR)$(MANDIR)/man1/`basename $$file`; done
	rm -f $(DESTDIR)$(OARDIR)/Almighty
	rm -f $(DESTDIR)$(OARDIR)/Leon
	rm -f $(DESTDIR)$(OARDIR)/Pythia
	rm -f $(DESTDIR)$(OARDIR)/sarko
	rm -f $(DESTDIR)$(OARDIR)/finaud
	rm -f $(DESTDIR)$(OARDIR)/hulot.pm $(DESTDIR)$(OARDIR)/oar_Hulot.pm
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

