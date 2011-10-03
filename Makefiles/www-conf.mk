MODULE=www-conf
SRCDIR=sources

EXAMPLEDIR_FILES= $(SRCDIR)/visualization_interfaces/apache.conf.in

PROCESS_TEMPLATE_FILES= $(EXAMPLEDIR)/apache.conf.in

include Makefiles/shared/shared.mk

clean:
	# nothing to do
build:
	# nothing to do

install: install_shared

uninstall: uninstall_shared
	# Nothing to do

.PHONY: install setup uninstall build clean

