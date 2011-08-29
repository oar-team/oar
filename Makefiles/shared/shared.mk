
export OARDO_BUILD     = $(MAKE) -f Makefiles/oardo/oardo.mk build
export OARDO_CLEAN     = $(MAKE) -f Makefiles/oardo/oardo.mk clean
export OARDO_INSTALL   = $(MAKE) -f Makefiles/oardo/oardo.mk install
export OARDO_UNINSTALL = $(MAKE) -f Makefiles/oardo/oardo.mk uninstall

ifndef CFLAGS
export CFLAGS=-g
endif

ifndef OARCONFDIR
export OARCONFDIR=/etc/oar
endif
# OARUSER and OAROWNER should be the same value except for special needs 
# (Debian packaging) 
ifndef OARUSER
export OARUSER=oar
endif

ifndef OAROWNER
# OAROWNER is the variable expanded to set the ownership of the files
export OAROWNER=$(OARUSER)
endif

ifndef OAROWNERGROUP
export OAROWNERGROUP=$(OAROWNER)
endif

# Set the user of web server (for CGI installation)
export WWWUSER=www-data

ifndef PREFIX
export PREFIX=/usr/local
endif

ifndef MANDIR 
export MANDIR=$(PREFIX)/share/man
endif

ifndef OARDIR
export OARDIR=$(PREFIX)/lib/oar
endif

ifndef BINDIR
export BINDIR=$(PREFIX)/bin
endif

ifndef SBINDIR
export SBINDIR=$(PREFIX)/sbin
endif

ifndef DOCDIR
export DOCDIR=$(PREFIX)/share/doc/oar
endif

ifndef WWWDIR
export WWWDIR=$(PREFIX)/share/oar-www
endif

ifndef CGIDIR
export CGIDIR=$(PREFIX)/lib/cgi-bin
endif

ifndef PERLLIBDIR
export PERLLIBDIR=$(PREFIX)/lib/site_perl
endif

ifndef VARLIBDIR
export VARLIBDIR=/var/lib
endif

ifndef WWW_ROOTDIR
export WWW_ROOTDIR=
endif

ifndef XAUTHCMDPATH
export XAUTHCMDPATH=$(shell which xauth)
endif

ifndef
export XAUTHCMDPATH=/usr/bin/xauth
endif

all:


install_perllib:
	install -m 755 -d $(DESTDIR)$(PERLLIBDIR)
	cp -r $(OAR_PERLLIB)/* $(DESTDIR)$(PERLLIBDIR)/

uninstall_perllib:
	CDIR=`pwd`; cd $(DESTDIR); DDIR=`pwd`; cd $${CDIR}/$(OAR_PERLLIB) && find . -type f -exec rm -f /$${DDIR}$(PERLLIBDIR)/{} \;

install_oardata:
	install -m 0755 -d $(DESTDIR)$(OARDIR)
	install -m 0644 -t $(DESTDIR)$(OARDIR) $(OARDIR_DATAFILES) 

uninstall_oardata:
	for file in $(OARDIR_DATAFILES); do rm -f $(DESTDIR)$(OARDIR)/`basename $$file`; done


install_oarbin:
	install -m 0755 -d $(DESTDIR)$(OARDIR)
	install -m 0755 -t $(DESTDIR)$(OARDIR) $(OARDIR_BINFILES)

uninstall_oarbin:
	for file in $(OARDIR_BINFILES); do rm -f $(DESTDIR)$(OARDIR)/`basename $$file`; done

install_doc:
	install -m 0755 -d $(DESTDIR)$(DOCDIR)
	install -m 0644 -t $(DESTDIR)$(DOCDIR) $(DOCDIR_FILES)

uninstall_doc:
	@for file in $(DOCDIR_FILES); do rm -f $(DESTDIR)$(DOCDIR)/`basename $$file`; done

install_man1:
	install -m 0755 -d $(DESTDIR)$(MANDIR)/man1
	install -m 0644 -t $(DESTDIR)$(MANDIR)/man1 $(MANDIR_FILES)

uninstall_man1:
	@for file in $(MANDIR_FILES); do rm -f $(DESTDIR)$(MANDIR)/man1/`basename $$file`; done

install_bin:
	install -m 0755 -d $(DESTDIR)$(BINDIR)
	install -m 0755 -t $(DESTDIR)$(BINDIR) $(BINDIR_FILES)

uninstall_bin:
	@for file in $(BINDIR_FILES); do rm -f $(DESTDIR)$(BINDIR)/`basename $$file`; done

install_sbin:
	install -m 0755 -d $(DESTDIR)$(SBINDIR)
	install -m 0755 -t $(DESTDIR)$(SBINDIR) $(SBINDIR_FILES)

uninstall_sbin:
	@for file in $(SBINDIR_FILES); do rm -f $(DESTDIR)$(SBINDIR)/`basename $$file`; done


install_examples:
	install -m 0755 -d $(DESTDIR)$(DOCDIR)/examples
	install -m 0644 -t $(DESTDIR)$(DOCDIR)/examples $(EXAMPLEDIR_FILES)

uninstall_examples:
	@for file in $(EXAMPLEDIR_FILES); do rm -f $(DESTDIR)$(DOCDIR)/examples/`basename $$file`; done


