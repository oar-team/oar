#! /usr/bin/make

include Makefiles/shared/shared.mk

clean:
	$(MAKE) -C modules/scheduler/ocaml-schedulers/simple_cbf_mb_h_ct_oar clean
	rm -rf  \
	    modules/scheduler/ocaml-schedulers/simple_cbf_mb_h_ct_oar/._d \
	    modules/scheduler/ocaml-schedulers/simple_cbf_mb_h_ct_oar/common 

build:
	$(MAKE) -C modules/scheduler/ocaml-schedulers/simple_cbf_mb_h_ct_oar 

install:
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -m 0755 modules/scheduler/ocaml-schedulers/misc/hierarchy_extractor.rb $(DESTDIR)$(OARDIR)
	
	install -d -m 0755 $(DESTDIR)$(OARDIR)/schedulers
	install -m 0755 modules/scheduler/ocaml-schedulers/simple_cbf_mb_h_ct_oar/simple_cbf_mb_h_ct_oar_my $(DESTDIR)$(OARDIR)/schedulers/oar_sched_ocaml_simple_cbf_mysql


uninstall:
	rm -f $(DESTDIR)$(OARDIR)/hierarchy_extractor.rb
	rm -f $(DESTDIR)$(OARDIR)/schedulers/oar_sched_ocaml_simple_cbf_mysql



