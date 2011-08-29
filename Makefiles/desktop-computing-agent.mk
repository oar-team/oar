#! /usr/bin/make

include Makefiles/shared/shared.mk

SRCDIR=sources/desktop_computing/agent

AGENTDIR_FILES = $(SRCDIR)/lib/job.rb \
		 $(SRCDIR)/lib/client.rb \
		 $(SRCDIR)/lib/config.rb \
		 $(SRCDIR)/lib/job_execution_exception.rb \
		 $(SRCDIR)/lib/job_resource.rb

BINDIR_FILES =  $(SRCDIR)/lib/agent.rb

SBINDIR_FILES = $(SRCDIR)/lib/daemon.rb

build:
	# Nothing to do

clean:
	# Nothing to do

install: install_bin install_sbin
	install -m 0755 -d $(DESTDIR)$(OARDIR)
	install -m 0755 -d $(DESTDIR)$(OARDIR)/desktop_computing
	install -m 0644 -t $(DESTDIR)$(OARDIR)/desktop_computing $(AGENTDIR_FILES)
	
	# Rename files 
	mv $(DESTDIR)$(BINDIR)/agent.rb $(DESTDIR)$(BINDIR)/oar-agent
	mv $(DESTDIR)$(SBINDIR)/daemon.rb $(DESTDIR)$(SBINDIR)/oar-agent-daemon
	
uninstall: uninstall_bin uninstall_sbin
	for file in $(AGENTDIR_FILES); do rm -f $(DESTDIR)$(OARDIR)/desktop_computing/`basename $$file`; done
	rm -f $(DESTDIR)$(BINDIR)/oar-agent
	rm -f $(DESTDIR)$(SBINDIR)/oar-agent-daemon
	   
