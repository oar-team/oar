#!/usr/bin/make
SHELL=/bin/bash

DESTDIR=
PREFIX=usr/local
MANDIR=$(PREFIX)/man
BINDIR=$(PREFIX)/bin
SBINDIR=$(PREFIX)/sbin

install:
	mkdir -p $(DESTDIR)/$(SBINDIR)
	install -m 755 lustre_mds_init.bash $(DESTDIR)/$(SBINDIR)/lustre_mds_init
	install -m 755 lustre_oss_init.bash $(DESTDIR)/$(SBINDIR)/lustre_oss_init
	install -m 755 lustre_client_init.bash $(DESTDIR)/$(SBINDIR)/lustre_client_init

uninstall:
	-rm -f $(DESTDIR)/$(SBINDIR)/lustre_mds_init \
	$(DESTDIR)/$(SBINDIR)/lustre_oss_init \
	$(DESTDIR)/$(SBINDIR)/lustre_client_init

deb:
	debuild -rfakeroot -us -uc

clean: 
	-rm -f build-arch-stamp build-indep-stamp configure-stamp debian/files debian/lustre-g5kutils.debhelper.log debian/lustre-g5kutils.substvars
	rm -rf debian/lustre-g5kutils

update-repo:
	scp ../lustre-g5kutils*.deb intra-id.id:/www-id/sites/oar/www/debian/lustre/dists/unstable/main/binary-amd64
	ssh intra-id.id "cd /www-id/sites/oar/www/debian/lustre && ./update.sh"
