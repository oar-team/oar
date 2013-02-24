#/usr/bin/make
# $Id$
export SHELL=/bin/bash

# Modules that can be builded
MODULES = server user node monika drawgantt drawgantt-svg doc tools api scheduler-ocaml kamelot kamelot-pg www-conf common common-libs database  


MODULES_LIST= $(patsubst %,% |, $(MODULES))|
OPTIONS_LIST= OARCONFDIR | OARUSER | OAROWNER | PREFIX | MANDIR | OARDIR | BINDIR | SBINDIR | DOCDIR 

# Define the makefile targets
TARGETS_SUFFIX = build clean install uninstall

TARGETS_BUILD     = $(MODULES:=-build)
TARGETS_CLEAN     = $(MODULES:=-clean)
TARGETS_INSTALL   = $(MODULES:=-install)
TARGETS_SETUP     = $(MODULES:=-setup)
TARGETS_UNINSTALL = $(MODULES:=-uninstall)
TARGETS = $(TARGETS_BUILD) $(TARGETS_CLEAN) $(TARGETS_INSTALL) $(TARGETS_UNINSTALL) $(TARGETS_SETUP)

all:       usage
build:     $(filter-out scheduler-ocaml% , $(TARGETS_BUILD))
install:   $(filter-out scheduler-ocaml% , $(TARGETS_INSTALL))
clean:     $(filter-out scheduler-ocaml% , $(TARGETS_CLEAN))
uninstall: $(filter-out scheduler-ocaml% , $(TARGETS_UNINSTALL))
setup:     $(filter-out scheduler-ocaml% , $(TARGETS_SETUP))

tarball: .git
	./misc/make_tarball

.git:
	@echo "Must be used from a git repository!"
	exit 1

usage:
	@echo "Usage: make [ OPTIONS=<...> ] [MODULES-]{install|build|clean|uninstall|setup}"
	@echo ""
	@echo "Where MODULES := { $(MODULES_LIST:||=) }"
	@echo ""
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
$(TARGETS_SETUP):     MODULE = $(patsubst %-setup,%,$@) 
$(TARGETS_SETUP):     ACTION = setup
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

$(TARGETS_SETUP):
	-$(MAKE) -s -f Makefiles/$(strip $(MODULE)).mk setup


# Dependencies
server-setup: common-setup common-libs-setup database-setup
server-install: sanity-check common-install common-libs-install database-install	
server-clean: common-clean common-libs-clean database-clean 
server-build: common-build common-libs-build database-build 
server-uninstall: common-uninstall common-libs-uninstall database-uninstall 

user-setup: common-setup common-libs-setup
user-install: sanity-check common-install common-libs-install
user-clean: common-clean common-libs-clean
user-build: common-build common-libs-build
user-uninstall: common-uninstall common-libs-uninstall

node-setup: common-setup
node-install: sanity-check common-install
node-clean: common-clean 
node-build: common-build 
node-uninstall: common-uninstall

drawgantt-setup: www-conf-setup
drawgantt-install: www-conf-install
drawgantt-clean: www-conf-clean
drawgantt-build: www-conf-build
drawgantt-uninstall: www-conf-uninstall

drawgantt-svg-setup: www-conf-setup
drawgantt-svg-install: www-conf-install
drawgantt-svg-clean: www-conf-clean
drawgantt-svg-build: www-conf-build
drawgantt-svg-uninstall: www-conf-uninstall

monika-setup: www-conf-setup
monika-install: www-conf-install
monika-clean: www-conf-clean
monika-build: www-conf-build
monika-uninstall: www-conf-uninstall

tools-setup: common-setup common-libs-setup
tools-install: sanity-check common-install common-libs-install
tools-clean: common-clean common-libs-clean
tools-build: common-build common-libs-build
tools-uninstall: common-uninstall common-libs-uninstall

api-setup: common-setup common-libs-setup
api-install: sanity-check common-install common-libs-install
api-build: common-build common-libs-build
api-clean: common-clean common-libs-clean
api-uninstall: common-uninstall common-libs-uninstall


P_ACTIONS = build install clean
P_TARGETS = $(patsubst %,packages-%,$(P_ACTIONS))

packages-build:    P_ACTION = build
packages-install:  P_ACTION = install
packages-clean:    P_ACTION = clean 

$(P_TARGETS):
	# oar-doc
	$(MAKE) -f Makefiles/doc.mk $(P_ACTION) \
	    DESTDIR=$(PACKAGES_DIR)/oar-doc
	
	# oar-common
	mkdir -p $(PACKAGES_DIR)/oar-common/var/lib/oar	
	$(MAKE) -f Makefiles/common.mk $(P_ACTION) \
	    DESTDIR=$(PACKAGES_DIR)/oar-common
	
	
	# liboar-perl
	mkdir -p $(PACKAGES_DIR)/liboar-perl/var/lib/oar	
	$(MAKE) -f Makefiles/common-libs.mk $(P_ACTION) \
	    DESTDIR=$(PACKAGES_DIR)/liboar-perl
	
	# oar-server
	mkdir -p $(PACKAGES_DIR)/oar-server/var/lib/oar
	$(MAKE) -f Makefiles/server.mk $(P_ACTION)\
                DESTDIR=$(PACKAGES_DIR)/oar-server
	
	$(MAKE) -f Makefiles/database.mk $(P_ACTION)\
                DESTDIR=$(PACKAGES_DIR)/oar-server \
		DOCDIR=/usr/share/doc/oar-server
	
	# oar-node
	mkdir -p $(PACKAGES_DIR)/oar-node/var/lib/oar
	mkdir -p $(PACKAGES_DIR)/oar-node/etc/init.d
	$(MAKE) -f Makefiles/node.mk $(P_ACTION)\
                DESTDIR=$(PACKAGES_DIR)/oar-node
	
	# oar-user
	mkdir -p $(PACKAGES_DIR)/oar-user/var/lib/oar
	$(MAKE) -f Makefiles/user.mk $(P_ACTION)\
                DESTDIR=$(PACKAGES_DIR)/oar-user 
	
	# oar-web-status
	$(MAKE) -f Makefiles/monika.mk $(P_ACTION) \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		DOCDIR=/usr/share/doc/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	$(MAKE) -f Makefiles/drawgantt.mk $(P_ACTION) \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		DOCDIR=/usr/share/doc/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	$(MAKE) -f Makefiles/drawgantt-svg.mk $(P_ACTION) \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		DOCDIR=/usr/share/doc/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	$(MAKE) -f Makefiles/www-conf.mk $(P_ACTION) \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		DOCDIR=/usr/share/doc/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	
	# oar-admin
	$(MAKE) -f Makefiles/tools.mk $(P_ACTION) \
                DESTDIR=$(PACKAGES_DIR)/oar-admin \
		DOCDIR=/usr/share/doc/oar-admin
	
	# oar-restful-api
	$(MAKE) -f Makefiles/api.mk $(P_ACTION) \
	    DOCDIR=/usr/share/doc/oar-restful-api \
	    DESTDIR=$(PACKAGES_DIR)/oar-restful-api 
	
	# keyring
	$(MAKE) -f Makefiles/keyring.mk $(P_ACTION) \
	    DESTDIR=$(PACKAGES_DIR)/oar-keyring 
	
	# scheduler-ocaml-mysql
	#$(MAKE) -f Makefiles/scheduler-ocaml.mk $(P_ACTION) \
	#    DESTDIR=$(PACKAGES_DIR)/oar-scheduler-ocaml-mysql 
