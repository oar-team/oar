#! /usr/bin/make

include Makefiles/shared/shared.mk

clean:
	# Nothing to do

build:
	# Nothing to do

uninstall:
	# Nothing to do

install: 
	install -d -m 0755 $(DESTDIR)/usr/share/oar-keyring
	install -m 0644 misc/pkg_building/oar.gpg $(DESTDIR)/usr/share/oar-keyring
	install -m 0644 misc/pkg_building/oarmaster.gpg $(DESTDIR)/usr/share/oar-keyring


