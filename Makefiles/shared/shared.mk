
export OARDO_BUILD     = $(MAKE) -f Makefiles/oardo/oardo.mk build
export OARDO_CLEAN     = $(MAKE) -f Makefiles/oardo/oardo.mk clean
export OARDO_INSTALL   = $(MAKE) -f Makefiles/oardo/oardo.mk install
export OARDO_SETUP     = $(MAKE) -f Makefiles/oardo/oardo.mk setup
export OARDO_UNINSTALL = $(MAKE) -f Makefiles/oardo/oardo.mk uninstall

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


#
# shared install (all the modules use the *_shared target)
#
MODULE_SETUP_FILES=$(wildcard setup/$(MODULE)*.in)
MODULE_SETUP_FILES_DEST=$(addprefix $(DESTDIR)$(OARDIR)/setup/,$(notdir $(basename $(MODULE_SETUP_FILES))))
PROCESS_TEMPLATE_FILES+=$(MODULE_SETUP_FILES_DEST)
install_shared: install_perllib install_oardata install_oarbin install_doc install_man1 install_bin install_sbin install_examples
	install -d $(DESTDIR)$(OARDIR)/Makefiles
	install -m 0644  Makefiles/$(MODULE).mk $(DESTDIR)$(OARDIR)/Makefiles
	
	if [ -n "$(wildcard setup/$(MODULE)*.in)" ]; then \
		install -d $(DESTDIR)$(OARDIR)/setup; \
		for file in $(wildcard setup/$(MODULE)*.in); do \
	    		cp $$file $(DESTDIR)$(OARDIR)/setup/`basename $$file .in`; \
		done ;\
	fi
ifdef PROCESS_TEMPLATE_FILES
	for file in $(PROCESS_TEMPLATE_FILES); do \
	    perl -i -pe "s#%%PREFIX%%#$(PREFIX)#g;;\
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
			 s#%%OARUSER%%#$(OARUSER)#g;;\
			 s#%%OAROWNER%%#$(OAROWNER)#g;;\
			 s#%%OAROWNERGROUP%%#$(OAROWNERGROUP)#g;;\
			 s#%%WWWUSER%%#$(WWWUSER)#g;;\
			 s#%%WWW_ROOTDIR%%#$(WWW_ROOTDIR)#g;;\
			 s#%%WWWDIR%%#$(WWWDIR)#g;;\
			 s#%%XAUTHCMDPATH%%#$(XAUTHCMDPATH)#g;;\
			 s#%%OARSHCMD%%#$(OARSHCMD)#g;;\
			 s#%%INITDIR%%#$(INITDIR)#g;;\
			 s#%%DEFAULTDIR%%#$(DEFAULTDIR)#g;;\
			 s#%%SETUP_TYPE%%#$(SETUP_TYPE)#g;;\
			 s#%%TARGET_DIST%%#$(TARGET_DIST)#g;;\
			 " "$$file"; \
	   if [ "`basename $$file .in`" != "`basename $$file`" ]; then \
	   	mv $$file "$$(dirname $$file)/$$(basename $$file .in)" ;\
	   fi \
	done
endif

uninstall_shared: uninstall_perllib uninstall_oardata uninstall_oarbin uninstall_doc uninstall_man1 uninstall_bin uninstall_sbin uninstall_examples
	rm -f $(DESTDIR)$(OARDIR)/Makefiles/$(MODULE).mk
	rm -f $(DESTDIR)$(OARDIR)/setup/$(MODULE).*


MODULE_SETUP_FILE:=$(DESTDIR)$(OARDIR)/setup/$(MODULE).sh
MODULE_SETUP_FUNC:=$(subst -,_,$(MODULE))_setup
setup_shared: setup_perllib setup_oardata setup_oarbin setup_doc setup_man1 setup_bin setup_sbin setup_examples
	if [ -f "$(MODULE_SETUP_FILE)" ]; then . $(MODULE_SETUP_FILE) && $(MODULE_SETUP_FUNC); fi


#
# OAR_PERLLIB
#
ifdef OAR_PERLLIB
install_perllib:
	install -m 0755 -d $(DESTDIR)$(PERLLIBDIR)
	cp -r $(OAR_PERLLIB)/* $(DESTDIR)$(PERLLIBDIR)/

uninstall_perllib:
	
	(cd $(OAR_PERLLIB) && find . -type f -exec rm -f $(DESTDIR)$(PERLLIBDIR)/{} \;)
	

setup_perllib:
	# nothing to do
else
install_perllib:
uninstall_perllib:
setup_perllib:
endif

#
# OARDIR_DATAFILES
#
ifdef OARDIR_DATAFILES
OARDIR_DATAFILES_DEST=$(addprefix $(DESTDIR)$(OARDIR)/,$(patsubst %.in,%,$(notdir $(OARDIR_DATAFILES))))
install_oardata:
	install -d $(DESTDIR)$(OARDIR)
	install -m 0644  $(OARDIR_DATAFILES) $(DESTDIR)$(OARDIR)

setup_oardata:
	chmod 0755 $(DESTDIR)$(OARDIR)
	-chmod 0644 -f $(OARDIR_DATAFILES_DEST)

uninstall_oardata:
	-rm -f $(OARDIR_DATAFILES_DEST)
else
install_oardata:
setup_oardata:
uninstall_oardata:
endif

#
# OARDIR_BINFILES
#
ifdef OARDIR_BINFILES
OARDIR_BINFILES_DEST=$(addprefix $(DESTDIR)$(OARDIR)/,$(patsubst %.in,%,$(notdir $(OARDIR_BINFILES))))
install_oarbin:
	install -m 0755 -d $(DESTDIR)$(OARDIR)
	install -m 0755  $(OARDIR_BINFILES) $(DESTDIR)$(OARDIR)

setup_oarbin:
	-chmod 0755 $(DESTDIR)$(OARDIR)
	-chmod 0755 -f $(OARDIR_BINFILES_DEST)

uninstall_oarbin:
	-rm -f $(OARDIR_BINFILES_DEST)
else
install_oarbin:
setup_oarbin:
uninstall_oarbin:
endif

#
# DOCDIR_FILES
#
ifdef DOCDIR_FILES
DOCDIR_FILES_DEST=$(addprefix $(DESTDIR)$(DOCDIR)/,$(patsubst %.in,%,$(notdir $(DOCDIR_FILES))))
install_doc:
	install -d $(DESTDIR)$(DOCDIR)
	install -m 0644  $(DOCDIR_FILES) $(DESTDIR)$(DOCDIR)

setup_doc:
	-chmod 0755 $(DESTDIR)$(DOCDIR)
	-chmod 0644 -f $(DOCDIR_FILES_DEST)

uninstall_doc:
	-rm -f $(DOCDIR_FILES_DEST)
else
install_doc:
setup_doc:
uninstall_doc:
endif

#
# MANDIR_FILES
#
ifdef MANDIR_FILES
MANDIR_FILES_DEST=$(addprefix $(DESTDIR)$(MANDIR)/man1/,$(patsubst %.in,%,$(notdir $(MANDIR_FILES))))
install_man1:
	install -d $(DESTDIR)$(MANDIR)/man1
	install -m 0644  $(MANDIR_FILES) $(DESTDIR)$(MANDIR)/man1

setup_man1:
	-chmod 0755 $(DESTDIR)$(MANDIR)/man1
	-chmod 0644 -f $(MANDIR_FILES_DEST)

uninstall_man1:
	-rm -f $(MANDIR_FILES_DEST)
else
install_man1:
setup_man1:
uninstall_man1:
endif

#
# BINDIR_FILES
#
ifdef BINDIR_FILES
BINDIR_FILES_DEST=$(addprefix $(DESTDIR)$(BINDIR)/,$(patsubst %.in,%,$(notdir $(BINDIR_FILES))))
install_bin:
	install -m 0755 -d $(DESTDIR)$(BINDIR)
	install -m 0755  $(BINDIR_FILES) $(DESTDIR)$(BINDIR)

setup_bin:
	-chmod 0755 -f $(BINDIR_FILES_DEST)

uninstall_bin:
	-rm -f $(BINDIR_FILES_DEST)
else
install_bin:
setup_bin:
uninstall_bin:
endif

#
# SBINDIR_FILES
#
ifdef SBINDIR_FILES
SBINDIR_FILES_DEST=$(addprefix $(DESTDIR)$(SBINDIR)/,$(patsubst %.in,%,$(notdir $(SBINDIR_FILES))))
install_sbin:
	install -m 0755 -d $(DESTDIR)$(SBINDIR)
	install -m 0755  $(SBINDIR_FILES) $(DESTDIR)$(SBINDIR)

setup_sbin:
	-chmod 0755 -f $(SBINDIR_FILES_DEST)

uninstall_sbin:
	-rm -f $(SBINDIR_FILES_DEST)
else
install_sbin:
setup_sbin:
uninstall_sbin:
endif

#
# EXAMPLEDIR_FILES
#
ifdef EXAMPLEDIR_FILES
EXAMPLEDIR_FILES_DEST=$(addprefix $(DESTDIR)$(EXAMPLEDIR)/,$(patsubst %.in,%,$(notdir $(EXAMPLEDIR_FILES))))
install_examples:
	install -m 0755 -d $(DESTDIR)$(EXAMPLEDIR)
	install -m 0644  $(EXAMPLEDIR_FILES) $(DESTDIR)$(EXAMPLEDIR)

setup_examples:
	-chmod 0644 -f $(EXAMPLEDIR_FILES_DEST)

uninstall_examples:
	-rm -f $(EXAMPLEDIR_FILES_DEST)
else
install_examples:
setup_examples:
uninstall_examples:
endif

.PHONY: install setup uninstall build clean

