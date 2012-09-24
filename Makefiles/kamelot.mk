MODULE=kamelot
SRCDIR=sources/core/modules/scheduler/kamelot

include Makefiles/shared/shared.mk

clean: clean_shared
	$(MAKE) -C $(SRCDIR) clean

build: build_shared
	$(MAKE) -C $(SRCDIR) 

install: install_shared
	install -d $(DESTDIR)$(OARDIR)/schedulers
	install \
	    $(SRCDIR)/kamelot_mysql \
	    $(DESTDIR)$(OARDIR)/schedulers/kamelot_mysql

uninstall: uninstall_shared
	rm -f $(DESTDIR)$(OARDIR)/schedulers/kamelot_mysql

.PHONY: install setup uninstall build clean
