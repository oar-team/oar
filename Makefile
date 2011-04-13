#/usr/bin/make
# $Id$
export SHELL=/bin/bash

include Makefiles/shared/shared.mk


# Modules that can be builded
MODULES = server user node monika draw-gantt doc desktop-computing-agent desktop-computing-cgi tools api gridapi poar scheduler-ocaml www-conf libs gridlibs common database  

MODULES_LIST= $(patsubst %,% |, $(MODULES))|
OPTIONS_LIST= OARCONFDIR | OARUSER | OAROWNER | PREFIX | MANDIR | OARDIR | BINDIR | SBINDIR | DOCDIR

# Define the makefile targets
TARGETS_SUFFIX = build clean install uninstall

TARGETS_BUILD     = $(MODULES:=-build)
TARGETS_CLEAN     = $(MODULES:=-clean)
TARGETS_INSTALL   = $(MODULES:=-install)
TARGETS_UNINSTALL = $(MODULES:=-uninstall)
TARGETS = $(TARGETS_BUILD) $(TARGETS_CLEAN) $(TARGETS_INSTALL) $(TARGETS_UNINSTALL)

all:       usage
build:     $(TARGETS_BUILD)
install:   $(TARGETS_INSTALL)
clean:     $(TARGETS_CLEAN)
uninstall: $(TARGETS_UNINSTALL)

usage:
	@echo "Usage: make [ OPTIONS=<...> ] { MODULES-install | MODULES-build | MODULES-clean | MODULES-uninstall }"
	@echo "Where MODULES := { $(MODULES_LIST:||=) }"
	@echo "      OPTIONS := { $(OPTIONS_LIST) }"

sanity-check:
	@[ "`id root`" = "`id`" ] || echo "Warning: root-privileges are required to install some files !"

sanity-setup-check: sanity-check
	@id $(OAROWNER) > /dev/null || ( echo "Error: User $(OAROWNER) does not exist!" ; exit -1 )


# Meta targets
$(TARGETS_BUILD):     MODULE = $(patsubst %-build,%,$@)
$(TARGETS_BUILD):     ACTION = build
$(TARGETS_INSTALL):   MODULE = $(patsubst %-install,%,$@) 
$(TARGETS_INSTALL):   ACTION = install
$(TARGETS_UNINSTALL): MODULE = $(patsubst %-uninstall,%,$@) 
$(TARGETS_UNINSTALL): ACTION = uninstall 
$(TARGETS_CLEAN):     MODULE = $(patsubst %-clean,%,$@) 
$(TARGETS_CLEAN):     ACTION = clean 

$(TARGETS_INSTALL):  sanity-check
	$(MAKE) $(strip $(MODULE))-build
	$(MAKE) -f Makefiles/$(strip $(MODULE)).mk install

$(TARGETS_UNINSTALL):
	$(MAKE) -f Makefiles/$(strip $(MODULE)).mk uninstall

$(TARGETS_CLEAN):
	$(MAKE) -f Makefiles/$(strip $(MODULE)).mk clean

$(TARGETS_BUILD):
	$(MAKE) -f Makefiles/$(strip $(MODULE)).mk build


# Dependencies
server-install: sanity-check common-install libs-install database-install 
server-clean: common-clean libs-clean database-clean 
server-build: common-build libs-build database-build 
server-uninstall: common-uninstall libs-uninstall database-uninstall 

user-install: sanity-check common-install libs-install
user-clean: common-clean libs-clean
user-build: common-build libs-build
user-uninstall: common-uninstall libs-uninstall

node-install: sanity-check common-install libs-install
node-clean: common-clean libs-clean
node-build: common-build libs-build
node-uninstall: common-uninstall libs-uninstall

draw-gantt-install: www-conf-install
draw-gantt-clean: www-conf-clean
draw-gantt-build: www-conf-build
draw-gantt-uninstall: www-conf-uninstall

monika-install: www-conf-install
monika-clean: www-conf-clean
monika-build: www-conf-build
monika-uninstall: www-conf-uninstall

poar-install: www-conf-install
poar-clean: www-conf-clean
poar-build: www-conf-build
poar-uninstall: www-conf-uninstall

desktop-computing-cgi-install: sanity-check common-install libs-install
desktop-computing-cgi-clean: common-clean libs-clean
desktop-computing-cgi-build: common-build libs-build
desktop-computing-cgi-uninstall: common-uninstall libs-uninstall

tools-install: sanity-check common-install libs-install 
tools-clean: common-clean libs-clean 
tools-build: common-build libs-build 
tools-uninstall: common-uninstall libs-uninstall 

api-install: sanity-check common-install libs-install
api-build: common-build libs-build
api-clean: common-clean libs-clean
api-uninstall: common-uninstall libs-uninstall

gridapi-install: sanity-check common-install libs-install gridlibs-install
gridapi-build: common-build libs-build gridlibs-build
gridapi-clean: common-clean libs-clean gridlibs-clean
gridapi-uninstall: common-uninstall libs-uninstall gridlibs-uninstall

# Ugly hack because there isn't yet separate setup scripts.
common-install: setup

setup: sanity-setup-check
	$(MAKE) -f Makefiles/setup.mk setup


