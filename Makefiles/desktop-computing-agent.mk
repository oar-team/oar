MODULE=desktop-computing-agent
SRCDIR=sources/desktop_computing/agent

AGENTDIR_FILES = $(SRCDIR)/lib/job.rb \
		 $(SRCDIR)/lib/client.rb \
		 $(SRCDIR)/lib/config.rb \
		 $(SRCDIR)/lib/job_execution_exception.rb \
		 $(SRCDIR)/lib/job_resource.rb

INITDIR_FILES = setup/init.d/oar-desktop-computing-agent.in

MANDIR_FILES = $(SRCDIR)/man/man1/oar-agent.pod \
	       $(SRCDIR)/man/man1/oar-agent-daemon.pod

include Makefiles/shared/shared.mk

build: build_shared
	# Nothing to do

clean: clean_shared
	# Nothing to do

install: install_shared
	install -d $(DESTDIR)$(OARDIR)/desktop_computing
	install -m 0644  $(AGENTDIR_FILES) $(DESTDIR)$(OARDIR)/desktop_computing
	
	install -d $(DESTDIR)$(BINDIR)
	install -m 0755 $(SRCDIR)/lib/agent.rb $(DESTDIR)$(BINDIR)/oar-agent
	
	install -d $(DESTDIR)$(SBINDIR)
	install -m 0755 $(SRCDIR)/lib/daemon.rb $(DESTDIR)$(SBINDIR)/oar-agent-daemon

uninstall: uninstall_shared
	for file in $(AGENTDIR_FILES); do rm -f $(DESTDIR)$(OARDIR)/desktop_computing/`basename $$file`; done
	rm -f $(DESTDIR)$(BINDIR)/oar-agent
	rm -f $(DESTDIR)$(SBINDIR)/oar-agent-daemon
	rm -rf $(DESTDIR)$(EXAMPLEDIR)
	  
.PHONY: install setup uninstall build clean
	 
