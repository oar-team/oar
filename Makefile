#/usr/bin/make
# $Id$
export SHELL=/bin/bash

# Modules that can be builded
MODULES = server user node monika draw-gantt doc desktop-computing-agent desktop-computing-cgi tools api poar scheduler-ocaml www-conf common common-libs database  

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
build:     $(TARGETS_BUILD)
install:   $(TARGETS_INSTALL)
clean:     $(TARGETS_CLEAN)
uninstall: $(TARGETS_UNINSTALL)
setup:     $(TARGETS_SETUP)

usage:
	@echo "Usage: make [ OPTIONS=<...> ] { MODULES-install | MODULES-build | MODULES-clean | MODULES-uninstall | MODULES-setup }"
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
	$(MAKE) -f Makefiles/$(strip $(MODULE)).mk setup


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

draw-gantt-setup: www-conf-setup
draw-gantt-install: www-conf-install
draw-gantt-clean: www-conf-clean
draw-gantt-build: www-conf-build
draw-gantt-uninstall: www-conf-uninstall

monika-setup: www-conf-setup
monika-install: www-conf-install
monika-clean: www-conf-clean
monika-build: www-conf-build
monika-uninstall: www-conf-uninstall

poar-setup: www-conf-setup
poar-install: www-conf-install
poar-clean: www-conf-clean
poar-build: www-conf-build
poar-uninstall: www-conf-uninstall

desktop-computing-cgi-setup: common-setup common-libs-setup
desktop-computing-cgi-install: sanity-check common-install common-libs-install
desktop-computing-cgi-clean: common-clean common-libs-clean
desktop-computing-cgi-build: common-build common-libs-build
desktop-computing-cgi-uninstall: common-uninstall common-libs-uninstall

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

# Build packages structures for debian/rpm packaging tools
packages-build:
	# oar-doc
	$(MAKE) -f Makefiles/doc.mk build \
	    DESTDIR=$(PACKAGES_DIR)/oar-doc
	
	# oar-common
	mkdir -p $(PACKAGES_DIR)/oar-common/var/lib/oar	
	$(MAKE) -f Makefiles/common.mk build \
	    DESTDIR=$(PACKAGES_DIR)/oar-common
	
	perl -i -pe 's#^\#?OAR_RUNTIME_DIRECTORY=.*#OAR_RUNTIME_DIRECTORY="/var/lib/oar"#' $(PACKAGES_DIR)/oar-common/etc/oar/oar.conf
	perl -i -pe 's/^\#*OPENSSH_CMD=.*/OPENSSH_CMD="\/usr\/bin\/ssh -p 6667"/' $(PACKAGES_DIR)/oar-common/etc/oar/oar.conf
	
	# liboar-perl
	mkdir -p $(PACKAGES_DIR)/liboar-perl/var/lib/oar	
	$(MAKE) -f Makefiles/common-libs.mk build \
	    DESTDIR=$(PACKAGES_DIR)/liboar-perl
	
	# oar-server
	mkdir -p $(PACKAGES_DIR)/oar-server/var/lib/oar
	$(MAKE) -f Makefiles/server.mk build\
                DESTDIR=$(PACKAGES_DIR)/oar-server
	
	$(MAKE) -f Makefiles/database.mk build\
                DESTDIR=$(PACKAGES_DIR)/oar-server \
		DOCDIR=/usr/share/doc/oar-server
	
	# oar-node
	mkdir -p $(PACKAGES_DIR)/oar-node/var/lib/oar
	mkdir -p $(PACKAGES_DIR)/oar-node/etc/init.d
	$(MAKE) -f Makefiles/node.mk build\
                DESTDIR=$(PACKAGES_DIR)/oar-node
	
	# oar-user
	mkdir -p $(PACKAGES_DIR)/oar-user/var/lib/oar
	$(MAKE) -f Makefiles/user.mk build\
                DESTDIR=$(PACKAGES_DIR)/oar-user 
	
	# oar-web-status
	$(MAKE) -f Makefiles/monika.mk build \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		DOCDIR=/usr/share/doc/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	$(MAKE) -f Makefiles/poar.mk build \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		DOCDIR=/usr/share/doc/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	$(MAKE) -f Makefiles/draw-gantt.mk build \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		DOCDIR=/usr/share/doc/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	$(MAKE) -f Makefiles/www-conf.mk build \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		DOCDIR=/usr/share/doc/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	
	# oar-admin
	$(MAKE) -f Makefiles/tools.mk build \
                DESTDIR=$(PACKAGES_DIR)/oar-admin \
		DOCDIR=/usr/share/doc/oar-admin
	
	# oar-desktop-computing-agent
	$(MAKE) -f Makefiles/desktop-computing-agent.mk build \
		DESTDIR=$(PACKAGES_DIR)/oar-desktop-computing-agent
	
	# oar-desktop-computing-cgi
	$(MAKE) -f Makefiles/desktop-computing-cgi.mk build \
	    DESTDIR=$(PACKAGES_DIR)/oar-desktop-computing-cgi
	
	# api
	$(MAKE) -f Makefiles/api.mk build \
	    DESTDIR=$(PACKAGES_DIR)/oar-api 
	
	# keyring
	$(MAKE) -f Makefiles/keyring.mk build \
	    DESTDIR=$(PACKAGES_DIR)/oar-keyring 
	
	# scheduler-ocaml-mysql
	#$(MAKE) -f Makefiles/scheduler-ocaml.mk build \
	#    DESTDIR=$(PACKAGES_DIR)/oar-scheduler-ocaml-mysql 

# Install target for packaging
packages-install:
	# oar-doc
	$(MAKE) -f Makefiles/doc.mk install \
	    DESTDIR=$(PACKAGES_DIR)/oar-doc 
	
	# oar-common
	mkdir -p $(PACKAGES_DIR)/oar-common/var/lib/oar	
	$(MAKE) -f Makefiles/common.mk install \
	    DESTDIR=$(PACKAGES_DIR)/oar-common 
	
	perl -i -pe 's#^\#?OAR_RUNTIME_DIRECTORY=.*#OAR_RUNTIME_DIRECTORY="/var/lib/oar"#' $(PACKAGES_DIR)/oar-common/etc/oar/oar.conf
	perl -i -pe 's/^\#*OPENSSH_CMD=.*/OPENSSH_CMD="\/usr\/bin\/ssh -p 6667"/' $(PACKAGES_DIR)/oar-common/etc/oar/oar.conf
	
	# liboar-perl
	mkdir -p $(PACKAGES_DIR)/liboar-perl/var/lib/oar	
	$(MAKE) -f Makefiles/common-libs.mk install \
	    DESTDIR=$(PACKAGES_DIR)/liboar-perl
	
	# oar-server
	mkdir -p $(PACKAGES_DIR)/oar-server/var/lib/oar
	$(MAKE) -f Makefiles/server.mk install\
                DESTDIR=$(PACKAGES_DIR)/oar-server
	$(MAKE) -f Makefiles/database.mk install\
		DOCDIR=/usr/share/doc/oar-server \
                DESTDIR=$(PACKAGES_DIR)/oar-server
	
	# oar-node
	mkdir -p $(PACKAGES_DIR)/oar-node/var/lib/oar
	mkdir -p $(PACKAGES_DIR)/oar-node/etc/init.d
	$(MAKE) -f Makefiles/node.mk install\
                DESTDIR=$(PACKAGES_DIR)/oar-node
	
	# oar-user
	mkdir -p $(PACKAGES_DIR)/oar-user/var/lib/oar
	$(MAKE) -f Makefiles/user.mk install\
                DESTDIR=$(PACKAGES_DIR)/oar-user
	
	# oar-web-status
	$(MAKE) -f Makefiles/monika.mk install \
		DOCDIR=/usr/share/doc/oar-web-status \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	$(MAKE) -f Makefiles/poar.mk install \
		DOCDIR=/usr/share/doc/oar-web-status \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	$(MAKE) -f Makefiles/draw-gantt.mk install \
		DOCDIR=/usr/share/doc/oar-web-status \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	$(MAKE) -f Makefiles/www-conf.mk install \
		DOCDIR=/usr/share/doc/oar-web-status \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	
	# oar-admin
	$(MAKE) -f Makefiles/tools.mk install \
		DOCDIR=/usr/share/doc/oar-admin \
                DESTDIR=$(PACKAGES_DIR)/oar-admin
	
	# oar-desktop-computing-agent
	$(MAKE) -f Makefiles/desktop-computing-agent.mk install \
	    DESTDIR=$(PACKAGES_DIR)/oar-desktop-computing-agent
	
	# oar-desktop-computing-cgi
	$(MAKE) -f Makefiles/desktop-computing-cgi.mk install \
	    DESTDIR=$(PACKAGES_DIR)/oar-desktop-computing-cgi
	
	# api
	$(MAKE) -f Makefiles/api.mk install \
	    DESTDIR=$(PACKAGES_DIR)/oar-api 
	
	# keyring
	$(MAKE) -f Makefiles/keyring.mk install \
	    DESTDIR=$(PACKAGES_DIR)/oar-keyring 
	
	# scheduler-ocaml-mysql
	# $(MAKE) -f Makefiles/scheduler-ocaml.mk install \
	#    DESTDIR=$(PACKAGES_DIR)/oar-scheduler-ocaml-mysql

# Clean target for packaging
packages-clean:
	# oar-doc
	$(MAKE) -f Makefiles/doc.mk clean \
	    DESTDIR=$(PACKAGES_DIR)/oar-doc 
	
	# oar-common
	mkdir -p $(PACKAGES_DIR)/oar-common/var/lib/oar	
	$(MAKE) -f Makefiles/common.mk clean \
	    DESTDIR=$(PACKAGES_DIR)/oar-common 
	
	perl -i -pe 's#^\#?OAR_RUNTIME_DIRECTORY=.*#OAR_RUNTIME_DIRECTORY="/var/lib/oar"#' $(PACKAGES_DIR)/oar-common/etc/oar/oar.conf
	perl -i -pe 's/^\#*OPENSSH_CMD=.*/OPENSSH_CMD="\/usr\/bin\/ssh -p 6667"/' $(PACKAGES_DIR)/oar-common/etc/oar/oar.conf
	
	# liboar-perl
	mkdir -p $(PACKAGES_DIR)/liboar-perl/var/lib/oar	
	$(MAKE) -f Makefiles/common-libs.mk clean \
	    DESTDIR=$(PACKAGES_DIR)/liboar-perl
	
	# oar-server
	mkdir -p $(PACKAGES_DIR)/oar-server/var/lib/oar
	$(MAKE) -f Makefiles/server.mk clean\
                DESTDIR=$(PACKAGES_DIR)/oar-server
	$(MAKE) -f Makefiles/database.mk clean\
		DOCDIR=/usr/share/doc/oar-server \
                DESTDIR=$(PACKAGES_DIR)/oar-server
	
	# oar-node
	mkdir -p $(PACKAGES_DIR)/oar-node/var/lib/oar
	mkdir -p $(PACKAGES_DIR)/oar-node/etc/init.d
	$(MAKE) -f Makefiles/node.mk clean\
                DESTDIR=$(PACKAGES_DIR)/oar-node
	
	# oar-user
	mkdir -p $(PACKAGES_DIR)/oar-user/var/lib/oar
	$(MAKE) -f Makefiles/user.mk clean\
                DESTDIR=$(PACKAGES_DIR)/oar-user
	
	# oar-web-status
	$(MAKE) -f Makefiles/monika.mk clean \
		DOCDIR=/usr/share/doc/oar-web-status \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	$(MAKE) -f Makefiles/poar.mk clean \
		DOCDIR=/usr/share/doc/oar-web-status \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	$(MAKE) -f Makefiles/draw-gantt.mk clean \
		DOCDIR=/usr/share/doc/oar-web-status \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	$(MAKE) -f Makefiles/www-conf.mk clean \
		DOCDIR=/usr/share/doc/oar-web-status \
                DESTDIR=$(PACKAGES_DIR)/oar-web-status \
		WWWDIR=/usr/share/oar-web-status
	
	# oar-admin
	$(MAKE) -f Makefiles/tools.mk clean \
		DOCDIR=/usr/share/doc/oar-admin \
                DESTDIR=$(PACKAGES_DIR)/oar-admin
	
	# oar-desktop-computing-agent
	$(MAKE) -f Makefiles/desktop-computing-agent.mk clean \
	    DESTDIR=$(PACKAGES_DIR)/oar-desktop-computing-agent
	
	# oar-desktop-computing-cgi
	$(MAKE) -f Makefiles/desktop-computing-cgi.mk clean \
	    DESTDIR=$(PACKAGES_DIR)/oar-desktop-computing-cgi
	
	# api
	$(MAKE) -f Makefiles/api.mk clean \
	    DESTDIR=$(PACKAGES_DIR)/oar-api 
	
	# keyring
	$(MAKE) -f Makefiles/keyring.mk clean \
	    DESTDIR=$(PACKAGES_DIR)/oar-keyring 
	
	# scheduler-ocaml-mysql
	# $(MAKE) -f Makefiles/scheduler-ocaml.mk clean \
	#    DESTDIR=$(PACKAGES_DIR)/oar-scheduler-ocaml-mysql

