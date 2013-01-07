MODULE=kamelot-pg
SRCDIR=sources/core/modules/scheduler/kamelot

include Makefiles/shared/shared.mk

clean: clean_shared
	$(MAKE) -C $(SRCDIR) clean

build: build_shared
	$(MAKE) POSTGRESQL=true -C $(SRCDIR) 

install: install_shared
	install -d $(DESTDIR)$(OARDIR)/schedulers
	install \
	    $(SRCDIR)/kamelot_postgresql \
	    $(DESTDIR)$(OARDIR)/schedulers/kamelot_postgresql
	install \
	    $(SRCDIR)/kamelot_ts_ph_postgresql \
	    $(DESTDIR)$(OARDIR)/schedulers/kamelot_ts_ph_postgresql

uninstall: uninstall_shared
	rm -f $(DESTDIR)$(OARDIR)/schedulers/kamelot_postgresql
	rm -f $(DESTDIR)$(OARDIR)/schedulers/kamelot_ts_ph_postgresql

.PHONY: install setup uninstall build clean
