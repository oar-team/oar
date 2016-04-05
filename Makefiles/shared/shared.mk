
export OARDO_BUILD     = $(MAKE) -f Makefiles/oardo/oardo.mk build
export OARDO_CLEAN     = $(MAKE) -f Makefiles/oardo/oardo.mk clean
export OARDO_INSTALL   = $(MAKE) -f Makefiles/oardo/oardo.mk install
export OARDO_UNINSTALL = $(MAKE) -f Makefiles/oardo/oardo.mk uninstall

SHARED_INSTALL   = $(MAKE) -f Makefiles/shared/common_target.mk install
SHARED_UNINSTALL = $(MAKE) -f Makefiles/shared/common_target.mk uninstall

# == 
TARGET_DIST?=$(shell if [ -f /etc/debian_version ]; then echo "debian"; fi; \
	             if [ -f /etc/redhat-release ]; then echo "redhat"; fi; \
	      )
# ==

# == debian
ifeq "$(TARGET_DIST)" "debian"

ifeq "$(SETUP_TYPE)" "deb"
include Makefiles/shared/dist/debian-deb.mk
else
include Makefiles/shared/dist/debian-tgz.mk
endif 

endif 
# == debian

# == redhat
ifeq "$(TARGET_DIST)" "redhat"

ifeq "$(SETUP_TYPE)" "rpm"
include Makefiles/shared/dist/redhat-rpm.mk
else
include Makefiles/shared/dist/redhat-tgz.mk
endif 

endif 
# == redhat

include Makefiles/shared/dist/common.mk

all:

setup: setup_shared

SHARED_ACTIONS=perllib oardata oarbin doc man1 bin sbin examples setup_scripts init logrotate default cron cgi www


clean_shared: clean_templates clean_man1 clean_setup_scripts
build_shared: build_templates build_man1 build_setup_scripts
	rm -f setup/templates/header.sh

install_shared: $(patsubst %, install_%,$(SHARED_ACTIONS)) install_setup_scripts
setup_shared: run_setup_scripts
uninstall_shared: $(patsubst %, uninstall_%,$(SHARED_ACTIONS)) uninstall_setup_scripts


#
# template processing (*.in)
#
MODULE_SETUP_SOURCE_FILES  = $(wildcard setup/$(MODULE).*.in)
MODULE_SETUP_TOBUILD_FILES  = $(patsubst %.in, %, $(MODULE_SETUP_SOURCE_FILES))
MODULE_SETUP_BUILDED_FILES  = $(patsubst %.in, %.out, $(MODULE_SETUP_SOURCE_FILES))
MODULE_SETUP_TARGET_FILES  = $(addprefix $(DESTDIR)$(OARDIR)/setup/,$(notdir $(basename $(MODULE_SETUP_SOURCE_FILES))))

TEMPLATE_SOURCE_FILES=$(filter %.in, $(PROCESS_TEMPLATE_FILES) \
                                     $(MANDIR_FILES) \
                                     $(INITDIR_FILES) \
                                     $(DEFAULTDIR_FILES) \
                                     $(LOGROTATEDIR_FILES) \
                                     $(CRONDIR_FILES) \
                                     $(CRONHOURLYDIR_FILES) \
				     $(OARDIR_BINFILES) \
				     $(OARDIR_DATAFILES) \
				     $(DOCDIR_FILES) \
				     $(BINDIR_FILES) \
				     $(SBINDIR_FILES) \
				     $(SHAREDIR_FILES) \
				     $(CGIDIR_FILES) \
				     $(WWWDIR_FILES) \
				     $(MODULE_SETUP_SOURCE_FILES) \
				     setup/templates/header.sh.in \
			)
TEMPLATE_BUILDED_FILES=$(patsubst %.in,%,$(TEMPLATE_SOURCE_FILES))


build_templates: $(TEMPLATE_BUILDED_FILES)

$(TEMPLATE_BUILDED_FILES) : %: %.in
	perl -pe "s#%%PREFIX%%#$(PREFIX)#g;;\
	    s#%%BINDIR%%#$(BINDIR)#g;;\
	    s#%%CGIDIR%%#$(CGIDIR)#g;;\
	    s#%%DOCDIR%%#$(DOCDIR)#g;;\
	    s#%%EXAMPLEDIR%%#$(EXAMPLEDIR)#g;;\
	    s#%%ETCDIR%%#$(ETCDIR)#g;;\
	    s#%%OARCONFDIR%%#$(OARCONFDIR)#g;;\
	    s#%%OARDIR%%#$(OARDIR)#g;;\
	    s#%%SHAREDIR%%#$(SHAREDIR)#g;;\
	    s#%%PERLLIBDIR%%#$(PERLLIBDIR)#g;;\
	    s#%%RUNDIR%%#$(RUNDIR)#g;;\
	    s#%%LOGDIR%%#$(LOGDIR)#g;;\
	    s#%%MANDIR%%#$(MANDIR)#g;;\
	    s#%%SBINDIR%%#$(SBINDIR)#g;;\
	    s#%%VARLIBDIR%%#$(VARLIBDIR)#g;;\
	    s#%%OARHOMEDIR%%#$(OARHOMEDIR)#g;;\
	    s#%%ROOTUSER%%#$(ROOTUSER)#g;;\
	    s#%%ROOTGROUP%%#$(ROOTGROUP)#g;;\
	    s#%%OARDO_DEFAULTUSER%%#$(OARDO_DEFAULTUSER)#g;;\
	    s#%%OARDO_DEFAULTGROUP%%#$(OARDO_DEFAULTGROUP)#g;;\
	    s#%%OARUSER%%#$(OARUSER)#g;;\
	    s#%%OAROWNER%%#$(OAROWNER)#g;;\
	    s#%%OAROWNERGROUP%%#$(OAROWNERGROUP)#g;;\
	    s#%%WWWUSER%%#$(WWWUSER)#g;;\
	    s#%%APACHECONFDIR%%#$(APACHECONFDIR)#g;;\
	    s#%%WWWROOTDIR%%#$(WWWROOTDIR)#g;;\
	    s#%%WWWDIR%%#$(WWWDIR)#g;;\
	    s#%%XAUTHCMDPATH%%#$(XAUTHCMDPATH)#g;;\
	    s#%%OARSHCMD%%#$(OARSHCMD)#g;;\
	    s#%%INITDIR%%#$(INITDIR)#g;;\
	    s#%%DEFAULTDIR%%#$(DEFAULTDIR)#g;;\
	    s#%%SETUP_TYPE%%#$(SETUP_TYPE)#g;;\
	    s#%%TARGET_DIST%%#$(TARGET_DIST)#g;;\
	    s#%%OARDOPATH%%#/bin:/sbin:/usr/bin:/usr/sbin:$(BINDIR):$(SBINDIR):$(OARDIR)/oardodo#;;\
	    " "$@.in" > $@ 

clean_templates:
	-rm -f $(TEMPLATE_BUILDED_FILES)


#
# setup scripts
#

MODULE_SETUP_FILE:=$(DESTDIR)$(OARDIR)/setup/$(MODULE).sh
MODULE_SETUP_FUNC:=$(subst -,_,$(MODULE))_setup
run_setup_scripts:
	if [ -f "$(MODULE_SETUP_FILE)" ]; then . $(MODULE_SETUP_FILE) && $(MODULE_SETUP_FUNC); fi

install_setup_scripts: $(MODULE_SETUP_TARGET_FILES)

build_setup_scripts: $(MODULE_SETUP_BUILDED_FILES)

$(MODULE_SETUP_BUILDED_FILES): $(MODULE_SETUP_TOBUILD_FILES)
	cat setup/templates/header.sh $< > $@

clean_setup_scripts:
	-rm -f $(MODULE_SETUP_BUILDED_FILES)

uninstall_setup_scripts:
	-rm -f $(MODULE_SETUP_TARGET_FILES)

$(MODULE_SETUP_TARGET_FILES): $(MODULE_SETUP_BUILDED_FILES)
	install -d $(DESTDIR)$(OARDIR)/setup
	install -m 0755 $< $@

#
# OAR_PERLLIB
#

ifdef OAR_PERLLIB
install_perllib:
	install -m 0755 -d $(DESTDIR)$(PERLLIBDIR)
	cp -r $(OAR_PERLLIB)/* $(DESTDIR)$(PERLLIBDIR)/

uninstall_perllib:
	
	(cd $(OAR_PERLLIB) && find . -type f -exec rm -f $(DESTDIR)$(PERLLIBDIR)/{} \;)
else
install_perllib:
uninstall_perllib:
endif




#
# OARDIR_DATAFILES
#
install_oardata:
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(OARDIR)" SOURCE_FILES="$(OARDIR_DATAFILES)" TARGET_FILE_RIGHTS=0644

uninstall_oardata:
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(OARDIR)" SOURCE_FILES="$(OARDIR_DATAFILES)" TARGET_FILE_RIGHTS=0644

#
# OARDIR_BINFILES
#
install_oarbin:
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(OARDIR)" SOURCE_FILES="$(OARDIR_BINFILES)" TARGET_FILE_RIGHTS=0755

uninstall_oarbin:
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(OARDIR)" SOURCE_FILES="$(OARDIR_BINFILES)" TARGET_FILE_RIGHTS=0755

#
# DOCDIR_FILES
#
install_doc:
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(DOCDIR)" SOURCE_FILES="$(DOCDIR_FILES)" TARGET_FILE_RIGHTS=0644

uninstall_doc:
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(DOCDIR)" SOURCE_FILES="$(DOCDIR_FILES)" TARGET_FILE_RIGHTS=0644

#
# MANDIR_FILES
#
SOURCE_MANDIR_FILES = $(filter %.pod, $(patsubst %.pod.in, %.pod, $(MANDIR_FILES)))
BUILD_MANDIR_FILES = $(patsubst %.pod, %.1, $(SOURCE_MANDIR_FILES)) $(filter %.1,$(MANDIR_FILES))
TARGET_MANDIR_FILES = $(addprefix $(DESTDIR)$(MANDIR)/man1, $(notdir $(BUILD_MANDIR_FILES)))

install_man1: 
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(MANDIR)/man1" SOURCE_FILES="$(BUILD_MANDIR_FILES)" TARGET_FILE_RIGHTS=0644

uninstall_man1:
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(MANDIR)/man1" SOURCE_FILES="$(BUILD_MANDIR_FILES)" TARGET_FILE_RIGHTS=0644

build_man1: $(BUILD_MANDIR_FILES)

clean_man1:
	-rm -f $(BUILD_MANDIR_FILES)

%.1: %.pod
	pod2man --section=1 --release="$(notdir $(basename $<))" --center "OAR commands" --name="$(notdir $(basename $<))" "$<" > $@


#
# BINDIR_FILES
#
install_bin:
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(BINDIR)" SOURCE_FILES="$(BINDIR_FILES)" TARGET_FILE_RIGHTS=0755

uninstall_bin:
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(BINDIR)" SOURCE_FILES="$(BINDIR_FILES)" TARGET_FILE_RIGHTS=0755

#
# SBINDIR_FILES
#
install_sbin:
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(SBINDIR)" SOURCE_FILES="$(SBINDIR_FILES)" TARGET_FILE_RIGHTS=0755

uninstall_sbin:
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(SBINDIR)" SOURCE_FILES="$(SBINDIR_FILES)" TARGET_FILE_RIGHTS=0755

#
# SHAREDIR_FILES
#
install_examples:
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(SHAREDIR)" SOURCE_FILES="$(SHAREDIR_FILES)" TARGET_FILE_RIGHTS=0644

uninstall_examples:
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(SHAREDIR)" SOURCE_FILES="$(SHAREDIR_FILES)" TARGET_FILE_RIGHTS=0644

#
# INITDIR_FILES
#
install_init:
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(SHAREDIR)/init.d" SOURCE_FILES="$(INITDIR_FILES)" TARGET_FILE_RIGHTS=0755

uninstall_init:
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(SHAREDIR)/init.d" SOURCE_FILES="$(INITDIR_FILES)" TARGET_FILE_RIGHTS=0755


#
# CRONDIR_FILES
#
install_cron:
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(SHAREDIR)/cron.d" SOURCE_FILES="$(CRONDIR_FILES)" TARGET_FILE_RIGHTS=0644
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(SHAREDIR)/cron.hourly" SOURCE_FILES="$(CRONHOURLYDIR_FILES)" TARGET_FILE_RIGHTS=0755

uninstall_cron:
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(SHAREDIR)/cron.d" SOURCE_FILES="$(CRONDIR_FILES)" TARGET_FILE_RIGHTS=0644
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(SHAREDIR)/cron.hourly" SOURCE_FILES="$(CRONHOURLYDIR_FILES)" TARGET_FILE_RIGHTS=0755


#
# DEFAULTDIR_FILES
#
install_default:
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(SHAREDIR)/default" SOURCE_FILES="$(DEFAULTDIR_FILES)" TARGET_FILE_RIGHTS=0644

uninstall_default:
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(SHAREDIR)/default" SOURCE_FILES="$(DEFAULTDIR_FILES)" TARGET_FILE_RIGHTS=0644


#
# LOGROTATEDIR_FILES
#
install_logrotate:
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(SHAREDIR)/logrotate.d" SOURCE_FILES="$(LOGROTATEDIR_FILES)" TARGET_FILE_RIGHTS=0644

uninstall_logrotate:
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(SHAREDIR)/logrotate.d" SOURCE_FILES="$(LOGROTATEDIR_FILES)" TARGET_FILE_RIGHTS=0644

#
# CGIDIR_FILES
#
install_cgi:
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(CGIDIR)" SOURCE_FILES="$(CGIDIR_FILES)" TARGET_FILE_RIGHTS=0755

uninstall_cgi:
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(CGIDIR)" SOURCE_FILES="$(CGIDIR_FILES)" TARGET_FILE_RIGHTS=0755

#
# WWWDIR_FILES
#
install_www:
	$(SHARED_INSTALL) TARGET_DIR="$(DESTDIR)$(WWWDIR)" SOURCE_FILES="$(WWWDIR_FILES)" TARGET_FILE_RIGHTS=0644

uninstall_www:
	$(SHARED_UNINSTALL) TARGET_DIR="$(DESTDIR)$(WWWDIR)" SOURCE_FILES="$(WWWDIR_FILES)" TARGET_FILE_RIGHTS=0644






.PHONY: install setup uninstall build clean

