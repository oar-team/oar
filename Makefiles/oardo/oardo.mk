MODULE=oardo

include Makefiles/shared/shared.mk

ifeq "$(OARCONFFILE)" ""
OARCONFFILE=$(OARCONFDIR)/oar.conf
endif

ifeq "$(OARXAUTHLOCATION)" ""
OARXAUTHLOCATION=$(XAUTHCMDPATH)
endif

ifeq "$(CMD_OWNER)" ""
CMD_OWNER=$(OAROWNER)
endif

ifeq "$(CMD_USERTOBECOME)" ""
CMD_USERTOBECOME=$(OARUSER)
endif

ifeq "$(CMD_GROUP)" ""
CMD_GROUP=$(OAROWNERGROUP)
endif

ifeq "$(CMD_RIGHTS)" ""
CMD_RIGHTS=6750
endif

ifeq "$(CMD_WRAPPER)" ""
echo "no CMD_WRAPPER given. Fail !"
exit 1
endif


CMD_BUILDTARGET=Makefiles/oardo/build/$(subst /,%,$(CMD_TARGET))

clean:
	-rm -rf $$(dirname $(CMD_BUILDTARGET))

build: $(CMD_BUILDTARGET)
	# Nothing to do

$(CMD_BUILDTARGET).c:
	mkdir -p $$(dirname $(CMD_BUILDTARGET))
	sed -e 's#\(define CMD_WRAPPER \).*#\1 "$(CMD_WRAPPER)"#' \
			sources/core/tools/oardo.c > "$(CMD_BUILDTARGET).c"

$(CMD_BUILDTARGET): $(CMD_BUILDTARGET).c
ifeq "$(CMD_TARGET)" ""
	echo "no CMD_TARGET given. Fail !"
	exit 1
endif

	$(CC) $(CFLAGS) $(LDFLAGS) $(CPPFLAGS) -o $(CMD_BUILDTARGET) "$(CMD_BUILDTARGET).c"


install: $(CMD_TARGET)

$(CMD_TARGET): $(CMD_BUILDTARGET)
	install -d `dirname $(CMD_TARGET)`
	install -m 0750 $(CMD_BUILDTARGET) $(CMD_TARGET)

uninstall:
ifeq "$(CMD_TARGET)" ""
	echo "no CMD_TARGET given. Fail !"
	exit 1
endif
	rm -f $(CMD_TARGET)

.PHONY: install setup uninstall build clean
