#! /usr/bin/make

include Makefiles/shared/shared.mk

OARDIR_FILES = tools/oarsh/oarsh_shell \
	       tools/oarsh/oarsh \

MANDIR_FILES = man/man1/oarsh.1 \
	       man/man1/oarprint.1 


clean:
	$(MAKE) -f Makefiles/man.mk clean
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarsh

build:
	$(MAKE) -f Makefiles/man.mk build
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarsh 

install: 
	install -m 0755 -d $(DESTDIR)$(OARDIR)
	install -m 0755 -t $(DESTDIR)$(OARDIR) $(OARDIR_FILES)
	perl -i -pe "s#^XAUTH_LOCATION=.*#XAUTH_LOCATION=$(XAUTHCMDPATH)#;;\
				 s#^OARDIR=.*#OARDIR=$(OARDIR)#;;\
				" $(DESTDIR)$(OARDIR)/oarsh_shell
	perl -i -pe "s#^XAUTH_LOCATION=.*#XAUTH_LOCATION=$(XAUTHCMDPATH)#" $(DESTDIR)$(OARDIR)/oarsh
	
	$(OARDO_INSTALL) CMD_TARGET=$(DESTDIR)$(OARDIR)/oarsh_oardo CMD_WRAPPER=$(OARDIR)/oarsh CMD_RIGHTS=6755
	chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(OARDIR)/oarsh_oardo
	chmod 6755 $(DESTDIR)$(OARDIR)/oarsh_oardo
	
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	install -d -m 0755 $(DESTDIR)$(BINDIR)
	install -m 0755 qfunctions/oarprint $(DESTDIR)$(BINDIR)
	install -m 0755 tools/oarsh/oarsh_sudowrapper.sh $(DESTDIR)$(BINDIR)/oarsh
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(OARDIR)#;;\
				 s#^OARSHCMD=.*#OARSHCMD=oarsh_oardo#\
				" $(DESTDIR)$(BINDIR)/oarsh
	install -m 0755 tools/oarsh/oarcp $(DESTDIR)$(BINDIR)
	perl -i -pe "s#^OARSHCMD=.*#OARSHCMD=$(BINDIR)/oarsh#" $(DESTDIR)$(BINDIR)/oarcp
	
	install -d -m 0755 $(DESTDIR)$(OARDIR)/oardodo
	install -m 6750 tools/oardodo $(DESTDIR)$(OARDIR)/oardodo
	-chown root.$(OAROWNERGROUP) $(DESTDIR)$(OARDIR)/oardodo
	-chown root.$(OAROWNERGROUP) $(DESTDIR)$(OARDIR)/oardodo/oardodo
	chmod 6750 $(DESTDIR)$(OARDIR)/oardodo
	chmod 6750 $(DESTDIR)$(OARDIR)/oardodo/oardodo
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oaruser = .*#Oaruser = '$(OARUSER)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				" $(DESTDIR)$(OARDIR)/oardodo/oardodo
	
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/oar.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/oar.conf already exists, not overwriting it." ; else install -m 0600 tools/oar.conf $(DESTDIR)$(OARCONFDIR) ; chown $(OAROWNER).root $(DESTDIR)$(OARCONFDIR)/oar.conf || /bin/true ; fi
	
	install -m 0755 -d $(DESTDIR)$(MANDIR)/man1
	install -m 0644 -t $(DESTDIR)$(MANDIR)/man1 $(MANDIR_FILES)
	cp -a $(DESTDIR)$(MANDIR)/man1/oarsh.1 $(DESTDIR)$(MANDIR)/man1/oarcp.1
	
	install -d -m 0755 $(DESTDIR)$(OARDIR)/db_upgrade
	cp -f database/*upgrade*.sql $(DESTDIR)$(OARDIR)/db_upgrade/

uninstall:
	@for file in $(OARDIR_FILES); do rm $(DESTDIR)$(OARDIR)/`basename $$file`; done
	@for file in $(MANDIR_FILES); do rm $(DESTDIR)$(MANDIR)/man1/`basename $$file`; done
	$(OARDO_UNINSTALL) CMD_TARGET=$(DESTDIR)$(OARDIR)/oarsh_oardo CMD_WRAPPER=$(OARDIR)/oarsh CMD_RIGHTS=6755
	rm $(DESTDIR)$(MANDIR)/man1/oarcp.1
	rm -f $(DESTDIR)$(OARDIR)/db_upgrade/*upgrade*.sql

