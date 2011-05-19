#! /usr/bin/make

include Makefiles/shared/shared.mk

AGENTDIR_FILES = desktop_computing/agent/lib/job.rb \
		 desktop_computing/agent/lib/client.rb \
		 desktop_computing/agent/lib/config.rb \
		 desktop_computing/agent/lib/job_execution_exception.rb \
		 desktop_computing/agent/lib/job_resource.rb

BINDIR_FILES = desktop_computing/agent/lib/agent.rb

SBINDIR_FILES = desktop_computing/agent/lib/daemon.rb

build:
	# Nothing to do

clean:
	# Nothing to do

install:
	install -m 0755 -d $(DESTDIR)$(OARDIR)
	install -m 0755 -d $(DESTDIR)$(OARDIR)/desktop_computing
	install -m 0644 -t $(DESTDIR)$(OARDIR)/desktop_computing $(AGENTDIR_FILES)
	
	install -m 0755 -d $(DESTDIR)$(BINDIR)
	install -m 0755 -t $(DESTDIR)$(BINDIR) $(BINDIR_FILES)
	
	install -m 0755 -d $(DESTDIR)$(SBINDIR)
	install -m 0755 -t $(DESTDIR)$(SBINDIR) $(SBINDIR_FILES)
	
	# Rename files 
	mv $(DESTDIR)$(BINDIR)/agent.rb $(DESTDIR)$(BINDIR)/oar-agent
	mv $(DESTDIR)$(SBINDIR)/daemon.rb $(DESTDIR)$(SBINDIR)/oar-agent-daemon
	
uninstall:
	for file in $(AGENTDIR_FILES); do rm -f $(DESTDIR)$(OARDIR)/desktop_computing/`basename $$file`; done
	@for file in $(BINDIR_FILES); do rm -f $(DESTDIR)$(BINDIR)/`basename $$file`; done
	@for file in $(SBINDIR_FILES); do rm -f $(DESTDIR)$(SBINDIR)/`basename $$file`; done
	   
