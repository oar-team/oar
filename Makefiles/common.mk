MODULE=common
SRCDIR=sources/core

OARDIR_BINFILES = $(SRCDIR)/tools/oarsh/oarsh_shell.in \
	          $(SRCDIR)/tools/oarsh/oarsh.in \
                  $(SRCDIR)/qfunctions/oarnodesetting \
		  $(SRCDIR)/tools/sentinelle.pl

MANDIR_FILES = $(SRCDIR)/man/man1/oarsh.1 \
	       $(SRCDIR)/man/man1/oarprint.1 \
	       $(SRCDIR)/man/man1/oarnodesetting.1

EXAMPLEDIR_FILES = $(SRCDIR)/tools/oar.conf.in \
                   $(SRCDIR)/tools/oarnodesetting_ssh.in \
		   $(SRCDIR)/tools/update_cpuset_id.sh.in

PROCESS_TEMPLATE_FILES = $(DESTDIR)$(EXAMPLEDIR)/logrotate.d/oar-common.in \
			 $(DESTDIR)$(EXAMPLEDIR)/oarnodesetting_ssh.in \
			 $(DESTDIR)$(EXAMPLEDIR)/update_cpuset_id.sh.in \
			 $(DESTDIR)$(EXAMPLEDIR)/oar.conf.in \
			 $(DESTDIR)$(OARDIR)/oarsh.in \
			 $(DESTDIR)$(OARDIR)/oarsh_shell.in \
			 $(DESTDIR)$(BINDIR)/oarsh.in \
			 $(DESTDIR)$(BINDIR)/oarcp.in \
			 $(DESTDIR)$(OARDIR)/setup/shared/shared.sh.in

include Makefiles/shared/shared.mk

clean:
	$(MAKE) -f Makefiles/man.mk clean
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarsh CMD_TARGET=$(DESTDIR)$(OARDIR)/oarsh_oardo 
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting
	rm -rf Makefiles/oardodo_tmp
build: 
	$(MAKE) -f Makefiles/man.mk build
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarsh CMD_TARGET=$(DESTDIR)$(OARDIR)/oarsh_oardo
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting
	
	mkdir -p Makefiles/oardodo_tmp
	cp $(SRCDIR)/tools/oardodo.c Makefiles/oardodo_tmp/oardodo.c 
	perl -i -pe "s#define OARDIR .*#define OARDIR \"$(OARDIR)\"#;;\
			     s#define OARUSER .*#define OARUSER \"$(OAROWNER)\"#;;\
			     s#define OARCONFFILE .*#define OARCONFFILE \"$(OARCONFDIR)/oar.conf\"#;;\
			     s#define OARXAUTHLOCATION .*#define OARXAUTHLOCATION \"$(XAUTHCMDPATH)\"#;;\
				" Makefiles/oardodo_tmp/oardodo.c
	$(CC) $(CFLAGS) -o Makefiles/oardodo_tmp/oardodo "Makefiles/oardodo_tmp/oardodo.c"
	
install: install_before install_shared
	
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarsh CMD_TARGET=$(DESTDIR)$(OARDIR)/oarsh_oardo
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting
	
	install -m 0755 $(SRCDIR)/qfunctions/oarprint $(DESTDIR)$(BINDIR)
	
	install -d $(DESTDIR)$(OARDIR)/oardodo
	install -m 0754 Makefiles/oardodo_tmp/oardodo $(DESTDIR)$(OARDIR)/oardodo
	
	cp -f $(DESTDIR)$(MANDIR)/man1/oarsh.1 $(DESTDIR)$(MANDIR)/man1/oarcp.1
	
	install -d $(DESTDIR)$(OARDIR)/db_upgrade
	cp -f $(SRCDIR)/database/*upgrade*.sql $(DESTDIR)$(OARDIR)/db_upgrade/
	
install_before:
	install -d $(DESTDIR)$(EXAMPLEDIR)/logrotate.d
	install -m 0644  setup/logrotate.d/oar-common.in $(DESTDIR)$(EXAMPLEDIR)/logrotate.d
	install -d $(DESTDIR)$(BINDIR)
	install -m 0755 $(SRCDIR)/tools/oarsh/oarsh_sudowrapper.sh.in $(DESTDIR)$(BINDIR)/oarsh.in
	install -m 0755 $(SRCDIR)/tools/oarsh/oarcp.in $(DESTDIR)$(BINDIR)/oarcp.in

uninstall: uninstall_shared
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarsh CMD_TARGET=$(DESTDIR)$(OARDIR)/oarsh_oardo
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting
	rm -f $(DESTDIR)$(MANDIR)/man1/oarcp.1
	rm -f $(DESTDIR)$(OARDIR)/db_upgrade/*upgrade*.sql
	rm -rf $(DESTDIR)$(OARDIR)/oardodo
	rm -rf $(DESTDIR)$(EXAMPLEDIR)
	

.PHONY: install setup uninstall build clean
