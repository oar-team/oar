#! /usr/bin/make

include Makefiles/shared/shared.mk

OARDIR_DATAFILES = oargrid/oargrid_lib.pm \
		   oargrid/oargrid_conflib.pm \
		   oargrid/oargrid_mailer.pm

clean:
	# Nothing to do

build:
	# Nothing to do

install:
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -m 0644 -t $(DESTDIR)$(OARDIR) $(OARDIR_DATAFILES)

uninstall:
	@for file in $(OARDIR_DATAFILES); do rm $(DESTDIR)$(OARDIR)/`basename $$file`; done


