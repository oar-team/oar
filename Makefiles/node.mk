#! /usr/bin/make

include Makefiles/shared/shared.mk

OARDIR_FILES=tools/oarnodecheck/oarnodecheckrun
BINDIR_FILES=tools/oarnodecheck/oarnodechecklist tools/oarnodecheck/oarnodecheckquery
OARCONFDIR_FILES=tools/sshd_config

build:
	$(MAKE) -f Makefiles/man.mk build

clean:
	$(MAKE) -f Makefiles/man.mk clean

install: build
	install -d -m 0755 $(DESTDIR)$(BINDIR)
	install -m 0755 -t $(DESTDIR)$(BINDIR) $(BINDIR_FILES)
	
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -m 0755 -t $(DESTDIR)$(OARDIR) $(OARDIR_FILES)
	
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)/check.d
	install -m 0600 -t $(DESTDIR)$(OARCONFDIR) -o $(OAROWNER) -g root $(OARCONFDIR_FILES)
	
	perl -i -pe "s#^XAuthLocation.*#XAuthLocation $(XAUTHCMDPATH)#" $(DESTDIR)$(OARCONFDIR)/sshd_config
	perl -i -pe "s#^OARUSER=.*#OARUSER=$(OARUSER)#;s#^CHECKSCRIPTDIR=.*#CHECKSCRIPTDIR=$(OARCONFDIR)/check.d#" $(DESTDIR)$(OARDIR)/oarnodecheckrun
	perl -i -pe "s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(DESTDIR)$(BINDIR)/oarnodechecklist
	perl -i -pe "s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(DESTDIR)$(BINDIR)/oarnodecheckquery
	
	@if [ -f $(DESTDIR)$(OARCONFDIR)/prologue ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/prologue already exists, not overwriting it." ; else install -m 0755 scripts/prologue $(DESTDIR)$(OARCONFDIR) ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/epilogue ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/epilogue already exists, not overwriting it." ; else install -m 0755 scripts/epilogue $(DESTDIR)$(OARCONFDIR) ; fi

uninstall:
	@for file in $(OARDIR_FILES); do rm $(DESTDIR)$(OARDIR)/`basename $$file`; done
	@for file in $(BINDIR_FILES); do rm $(DESTDIR)$(BINDIR)/`basename $$file`; done
	


