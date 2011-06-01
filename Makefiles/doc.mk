#! /usr/bin/make

include Makefiles/shared/shared.mk

clean:
	$(MAKE) -C docs/documentation clean
	rm -f docs/documentation/oar-documentation-devel.html

build: build-html-doc

install: build
	install -d -m 0755 $(DESTDIR)$(DOCDIR)
	install -d -m 0755 $(DESTDIR)$(DOCDIR)/html
	install -d -m 0755 $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue
	install -d -m 0755 $(DESTDIR)$(DOCDIR)/scripts
	install -d -m 0755 $(DESTDIR)$(DOCDIR)/scripts/job_resource_manager
	
	install -m 0644 docs/documentation/OAR-DOCUMENTATION-USER.html $(DESTDIR)$(DOCDIR)/html
	install -m 0644 docs/documentation/OAR-DOCUMENTATION-ADMIN.html $(DESTDIR)$(DOCDIR)/html
	install -m 0644 docs/documentation/OAR-DOCUMENTATION-API-USER.html $(DESTDIR)$(DOCDIR)/html
	install -m 0644 docs/documentation/OAR-DOCUMENTATION-API-ADMIN.html $(DESTDIR)$(DOCDIR)/html
	install -m 0644 docs/documentation/OAR-DOCUMENTATION-API-DEVEL.html $(DESTDIR)$(DOCDIR)/html
	install -m 0644 docs/schemas/oar_logo.png $(DESTDIR)$(DOCDIR)/html
	install -m 0644 docs/schemas/db_scheme.png $(DESTDIR)$(DOCDIR)/html
	install -m 0644 docs/schemas/interactive_oarsub_scheme.png $(DESTDIR)$(DOCDIR)/html
	install -m 0644 docs/schemas/Almighty.fig $(DESTDIR)$(DOCDIR)/html
	install -m 0644 docs/schemas/Almighty.ps $(DESTDIR)$(DOCDIR)/html
	
	install -m 0644 sources/core/tools/job_resource_manager.pl $(DESTDIR)$(DOCDIR)/scripts/job_resource_manager/
	
	install -m 0644 sources/core/scripts/oar_prologue $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 sources/core/scripts/oar_epilogue $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 sources/core/scripts/oar_prologue_local $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 sources/core/scripts/oar_epilogue_local $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 sources/core/scripts/oar_diffuse_script $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 sources/core/scripts/lock_user.sh $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 sources/core/scripts/oar_server_proepilogue.pl $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/

uninstall:
	rm -rf \
	    $(DESTDIR)$(DOCDIR)/html \
	    $(DESTDIR)$(DOCDIR)/scripts/job_resource_manager/ \
	    $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/

build-html-doc:
	$(MAKE) -C docs/documentation all


