MODULE=monika
SRCDIR=sources/visualization_interfaces/Monika

OAR_PERLLIB=$(SRCDIR)/lib

EXAMPLEDIR_FILES= $(SRCDIR)/monika.conf.in \
		  $(SRCDIR)/userInfos.cgi

CGIDIR_FILES = $(SRCDIR)/monika.cgi.in


WWWDIR_FILES = $(SRCDIR)/monika.css

include Makefiles/shared/shared.mk

clean: clean_shared
	# Nothing to do

build: build_shared
	# Nothing to do

install: install_shared
	# Nothing to do

uninstall: uninstall_shared
	# Nothing to do

.PHONY: install setup uninstall build clean
