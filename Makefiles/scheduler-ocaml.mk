MODULE=scheduler-ocaml
SRCDIR=sources/extra/ocaml-schedulers

include Makefiles/shared/shared.mk

OARDIR_BINFILES= $(SRCDIR)/misc/hierarchy_extractor.rb

clean: clean_shared
	$(MAKE) -C $(SRCDIR)/simple_cbf_mb_h_ct_oar clean
	rm -rf  \
	    $(SRCDIR)/simple_cbf_mb_h_ct_oar/._d \
	    $(SRCDIR)/simple_cbf_mb_h_ct_oar/common

build: build_shared
	$(MAKE) -C $(SRCDIR)/simple_cbf_mb_h_ct_oar

install: install_shared
	install -d $(DESTDIR)$(OARDIR)/schedulers
	install \
	    $(SRCDIR)/simple_cbf_mb_h_ct_oar/simple_cbf_mb_h_ct_oar_mysql \
	    $(DESTDIR)$(OARDIR)/schedulers/oar_sched_ocaml_simple_cbf_mysql

uninstall: uninstall_shared
	rm -f $(DESTDIR)$(OARDIR)/schedulers/oar_sched_ocaml_simple_cbf_mysql

.PHONY: install setup uninstall build clean
