MODULE=keyring


include Makefiles/shared/shared.mk

clean:
	# Nothing to do

build:
	# Nothing to do

uninstall: uninstall_shared
	# Nothing to do

install: install_shared 
	install -d $(DESTDIR)/usr/share/oar-keyring
	install -m 0644 misc/apt_keyring/oar.gpg $(DESTDIR)/usr/share/oar-keyring
	install -m 0644 misc/apt_keyring/oarmaster.gpg $(DESTDIR)/usr/share/oar-keyring

.PHONY: install setup uninstall build clean
