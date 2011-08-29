#! /usr/bin/make

include Makefiles/shared/shared.mk

SRCDIR=sources/core

OARDIR_BINFILES = $(SRCDIR)/tools/oarsh/oarsh_shell \
	          $(SRCDIR)/tools/oarsh/oarsh 

MANDIR_FILES = $(SRCDIR)/man/man1/oarsh.1 \
	       $(SRCDIR)/man/man1/oarprint.1 


clean:
	$(MAKE) -f Makefiles/man.mk clean
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarsh CMD_TARGET=$(DESTDIR)$(OARDIR)/oarsh_oardo 
	rm -rf Makefiles/oardodo_tmp
build: 
	$(MAKE) -f Makefiles/man.mk build
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarsh CMD_TARGET=$(DESTDIR)$(OARDIR)/oarsh_oardo
	
	mkdir -p Makefiles/oardodo_tmp
	cp $(SRCDIR)/tools/oardodo.c Makefiles/oardodo_tmp/oardodo.c 
	perl -i -pe "s#define OARDIR .*#define OARDIR \"$(OARDIR)\"#;;\
			     s#define OARUSER .*#define OARUSER \"$(OAROWNER)\"#;;\
			     s#define OARCONFFILE .*#define OARCONFFILE \"$(OARCONFDIR)/oar.conf\"#;;\
			     s#define OARXAUTHLOCATION .*#define OARXAUTHLOCATION \"$(XAUTHCMDPATH)\"#;;\
				" Makefiles/oardodo_tmp/oardodo.c
	$(CC) $(CFLAGS) -o Makefiles/oardodo_tmp/oardodo "Makefiles/oardodo_tmp/oardodo.c"
	
install: install_oarbin install_man1
	perl -i -pe "s#^XAUTH_LOCATION=.*#XAUTH_LOCATION=$(XAUTHCMDPATH)#;;\
				 s#^OARDIR=.*#OARDIR=$(OARDIR)#;;\
				" $(DESTDIR)$(OARDIR)/oarsh_shell
	perl -i -pe "s#^XAUTH_LOCATION=.*#XAUTH_LOCATION=$(XAUTHCMDPATH)#" $(DESTDIR)$(OARDIR)/oarsh
	
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarsh CMD_TARGET=$(DESTDIR)$(OARDIR)/oarsh_oardo CMD_RIGHTS=6755
	chmod 6755 $(DESTDIR)$(OARDIR)/oarsh_oardo
	
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	install -d -m 0755 $(DESTDIR)$(BINDIR)
	install -m 0755 $(SRCDIR)/qfunctions/oarprint $(DESTDIR)$(BINDIR)
	install -m 0755 $(SRCDIR)/tools/oarsh/oarsh_sudowrapper.sh $(DESTDIR)$(BINDIR)/oarsh
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(OARDIR)#;;\
				 s#^OARSHCMD=.*#OARSHCMD=oarsh_oardo#\
				" $(DESTDIR)$(BINDIR)/oarsh
	install -m 0755 $(SRCDIR)/tools/oarsh/oarcp $(DESTDIR)$(BINDIR)
	perl -i -pe "s#^OARSHCMD=.*#OARSHCMD=$(BINDIR)/oarsh#" $(DESTDIR)$(BINDIR)/oarcp
	
	install -d -m 0755 $(DESTDIR)$(OARDIR)/oardodo
	install -m 6750 Makefiles/oardodo_tmp/oardodo $(DESTDIR)$(OARDIR)/oardodo
	chown root.$(OAROWNERGROUP) $(DESTDIR)$(OARDIR)/oardodo
	chown root.$(OAROWNERGROUP) $(DESTDIR)$(OARDIR)/oardodo/oardodo
	chmod 6750 $(DESTDIR)$(OARDIR)/oardodo
	chmod 6750 $(DESTDIR)$(OARDIR)/oardodo/oardodo
	
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/oar.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/oar.conf already exists, not overwriting it." ; else install -m 0600 $(SRCDIR)/tools/oar.conf $(DESTDIR)$(OARCONFDIR) ; chown $(OAROWNER).root $(DESTDIR)$(OARCONFDIR)/oar.conf || /bin/true ; fi
	
	cp -a $(DESTDIR)$(MANDIR)/man1/oarsh.1 $(DESTDIR)$(MANDIR)/man1/oarcp.1
	
	install -d -m 0755 $(DESTDIR)$(OARDIR)/db_upgrade
	cp -f $(SRCDIR)/database/*upgrade*.sql $(DESTDIR)$(OARDIR)/db_upgrade/

uninstall: uninstall_oarbin uninstall_man1
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarsh CMD_TARGET=$(DESTDIR)$(OARDIR)/oarsh_oardo
	rm -f $(DESTDIR)$(MANDIR)/man1/oarcp.1
	rm -f $(DESTDIR)$(OARDIR)/db_upgrade/*upgrade*.sql
	rm -rf $(DESTDIR)$(OARDIR)/oardodo

