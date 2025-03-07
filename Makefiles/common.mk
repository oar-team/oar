MODULE=common
SRCDIR=sources/core

OARDIR_BINFILES = $(SRCDIR)/tools/$(OARSH_DIR)/oarsh_shell.in \
	          $(SRCDIR)/tools/$(OARSH_DIR)/oarsh.in \
                  $(SRCDIR)/qfunctions/oarnodesetting \
		  $(SRCDIR)/tools/sentinelle.pl

MAN1DIR_FILES = $(SRCDIR)/man/man1/oarsh.1 \
	       $(SRCDIR)/man/man1/oarprint.1
MAN8DIR_FILES = $(SRCDIR)/man/man8/oarnodesetting.8

SHAREDIR_FILES = $(SRCDIR)/tools/oar.conf.in \
                   $(SRCDIR)/tools/oarnodesetting_ssh.in \
		   $(SRCDIR)/tools/update_cpuset_id.sh.in

LOGROTATEDIR_FILES = setup/logrotate.d/oar-common.in

PROCESS_TEMPLATE_FILES = $(SRCDIR)/tools/$(OARSH_DIR)/oarcp.in \
			 $(SRCDIR)/tools/oardodo.c.in \
			 $(SRCDIR)/tools/oardo.c.in \
			 $(SRCDIR)/tools/oarcgdev/oarcgdev.c.in


include Makefiles/shared/shared.mk

clean: clean_shared
	$(MAKE) -f Makefiles/man.mk clean
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarsh CMD_TARGET=$(DESTDIR)$(BINDIR)/oarsh
	$(OARDO_CLEAN) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting
	-rm -f $(SRCDIR)/tools/oardodo
ifndef OAR_CGV1
	-rm -f $(SRCDIR)/tools/oarcgdev/oarcgdev
	-rm -f $(SRCDIR)/tools/oarcgdev/oarcgdev-ebpf
endif

build: build_shared
	$(MAKE) -f Makefiles/man.mk build
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarsh CMD_TARGET=$(DESTDIR)$(BINDIR)/oarsh
	$(OARDO_BUILD) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting

	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $(SRCDIR)/tools/oardodo $(SRCDIR)/tools/oardodo.c
ifndef OAR_CGV1
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $(SRCDIR)/tools/oarcgdev/oarcgdev.c -lelf -lz -lbpf -o $(SRCDIR)/tools/oarcgdev/oarcgdev
	clang -I /usr/include/$(shell gcc -print-multiarch) -O2 -target bpf -mcpu=v3 -g -c $(SRCDIR)/tools/oarcgdev/oarcgdev-ebpf.c -o $(SRCDIR)/tools/oarcgdev/oarcgdev.bpf
endif

install: install_shared

	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarsh CMD_TARGET=$(DESTDIR)$(BINDIR)/oarsh
	$(OARDO_INSTALL) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting

	install -d $(DESTDIR)$(BINDIR)
	install -m 0755 $(SRCDIR)/tools/$(OARSH_DIR)/oarcp $(DESTDIR)$(BINDIR)/
	install -m 0755 $(SRCDIR)/qfunctions/oarprint $(DESTDIR)$(BINDIR)

	install -d $(DESTDIR)$(OARDIR)/oardodo
	install -m 0754 $(SRCDIR)/tools/oardodo $(DESTDIR)$(OARDIR)/oardodo

	cp -f $(DESTDIR)$(MANDIR)/man1/oarsh.1 $(DESTDIR)$(MANDIR)/man1/oarcp.1

ifndef OAR_CGV1
	install -m 0700 $(SRCDIR)/tools/oarcgdev/oarcgdev $(DESTDIR)$(OARDIR)/oarcgdev
	install -m 0700 $(SRCDIR)/tools/oarcgdev/oarcgdev.bpf $(DESTDIR)$(OARDIR)/oarcgdev.bpf
endif

uninstall: uninstall_shared
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarsh CMD_TARGET=$(DESTDIR)$(BINDIR)/oarsh
	$(OARDO_UNINSTALL) CMD_WRAPPER=$(OARDIR)/oarnodesetting CMD_TARGET=$(DESTDIR)$(SBINDIR)/oarnodesetting
	rm -f $(DESTDIR)$(MANDIR)/man1/oarcp.1
	rm -rf $(DESTDIR)$(OARDIR)/oardodo
	rm -rf $(DESTDIR)$(EXAMPLEDIR)
ifndef OAR_CGV1
	rm -f $(DESTDIR)$(OARDIR)/oarcgdev
	rm -f $(DESTDIR)$(OARDIR)/oarcgdev.bpf
endif


.PHONY: install setup uninstall build clean
