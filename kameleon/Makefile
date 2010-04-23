#/usr/bin/make
SHELL=/bin/bash
DESTDIR=
PREFIX=/usr/local
KAMELEON_DIR=$(PREFIX)/share/kameleon
MANDIR=$(PREFIX)/man
BINDIR=$(PREFIX)/bin
SBINDIR=$(PREFIX)/sbin
DOCDIR=$(PREFIX)/share/doc/kameleon
VARLIBDIR=/var/lib

install-engine:
	install -d -m 0755 $(DESTDIR)$(BINDIR)
	install -d -m 0755 $(DESTDIR)$(KAMELEON_DIR)
	install -m 755 kameleon.rb $(DESTDIR)$(KAMELEON_DIR)
	echo "RUBYOPT=rubygems $(KAMELEON_DIR)/kameleon.rb \$$*" > $(DESTDIR)$(BINDIR)/kameleon
	-chmod 755 $(DESTDIR)$(BINDIR)/kameleon

install-data:
	install -d -m 0755 $(DESTDIR)$(KAMELEON_DIR)
	install -d -m 0755 $(DESTDIR)$(KAMELEON_DIR)/steps
	install -d -m 0755 $(DESTDIR)$(KAMELEON_DIR)/recipes
	for dir in steps/*; do [ $$dir != "steps/old" ] && cp -r $$dir $(DESTDIR)$(KAMELEON_DIR)/steps || true; done
	for file in recipes/*; do [ $$file != "recipes/old" ] && install $$file $(DESTDIR)$(KAMELEON_DIR)/recipes || true; done
	install -d -m 755 $(VARLIBDIR)/kameleon/steps
	install -d -m 755 $(VARLIBDIR)/kameleon/recipes

install: install-engine install-data

uninstall: 
	rm -rf $(DESTDIR)$(KAMELEON_DIR)
