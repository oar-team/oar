MODULE=www-conf
SRCDIR=sources

SHAREDIR_FILES= $(SRCDIR)/visualization_interfaces/apache.conf.in

include Makefiles/shared/shared.mk

clean: clean_shared
# nothing to do

build: build_shared
# nothing to do

install: install_shared
# nothing to do

uninstall: uninstall_shared
# Nothing to do

.PHONY: install setup uninstall build clean

