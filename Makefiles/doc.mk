MODULE=doc
SRCDIR=

include Makefiles/shared/shared.mk

clean: clean_shared 
	$(MAKE) -C docs clean

build: build_shared build-html-doc

install: build install_shared
	install -d $(DESTDIR)$(DOCDIR)/html
	install -d $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue
	install -d $(DESTDIR)$(DOCDIR)/scripts
	install -d $(DESTDIR)$(DOCDIR)/scripts/job_resource_manager

	install -m 0644 sources/core/tools/job_resource_manager.pl $(DESTDIR)$(DOCDIR)/scripts/job_resource_manager/
	
	install -m 0644 sources/core/scripts/oar_prologue $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 sources/core/scripts/oar_epilogue $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 sources/core/scripts/oar_prologue_local $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 sources/core/scripts/oar_epilogue_local $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 sources/core/scripts/oar_diffuse_script $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 sources/core/scripts/lock_user.sh $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 sources/core/scripts/oar_server_proepilogue.pl $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/

uninstall: uninstall_shared
	rm -rf \
	    $(DESTDIR)$(DOCDIR)/html \
	    $(DESTDIR)$(DOCDIR)/scripts/job_resource_manager/ \
	    $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/

build-html-doc:
	$(MAKE) -C docs html BUILDDIR=$(DESTDIR)$(DOCDIR)

.PHONY: install setup uninstall build clean

