#! /usr/bin/make

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


CMD_BUILDTARGET=Makefiles/oardo/$(subst /,%,$(CMD_TARGET))

clean:
	rm -f $(CMD_BUILDTARGET) $(CMD_BUILDTARGET).c

build: 
ifeq "$(CMD_TARGET)" ""
	echo "no CMD_TARGET given. Fail !"
	exit 1
endif
	cp tools/oardo.c $(CMD_BUILDTARGET).c
	perl -i -pe "s#define OARDIR .*#define OARDIR \"$(OARDIR)\"#;;\
			s#define OARCONFFILE .*#define OARCONFFILE \"$(OARCONFFILE)\"#;;\
			s#define OARXAUTHLOCATION .*#define OARXAUTHLOCATION \"$(OARXAUTHLOCATION)\"#;;\
			s#define USERTOBECOME .*#define USERTOBECOME \"$(CMD_OWNER)\"#;;\
			s#define PATH2SET .*#define PATH2SET \"/bin:/sbin:/usr/bin:/usr/sbin:$(BINDIR):$(SBINDIR):$(OARDIR)/oardodo\"#;;\
			s#define CMD_WRAPPER .*#define CMD_WRAPPER \"$(CMD_WRAPPER)\"#;;\
			" "$(CMD_BUILDTARGET).c"

	$(CC) $(CFLAGS) -o $(CMD_BUILDTARGET) "$(CMD_BUILDTARGET).c"
	

install:
ifeq "$(CMD_TARGET)" ""
	echo "no CMD_TARGET given. Fail !"
	exit 1
endif
	install -m $(CMD_RIGHTS) $(CMD_BUILDTARGET) $(CMD_TARGET)
	chown root.$(CMD_GROUP) $(CMD_TARGET)
	chmod $(CMD_RIGHTS) $(CMD_TARGET)

uninstall:
ifeq "$(CMD_TARGET)" ""
	echo "no CMD_TARGET given. Fail !"
	exit 1
endif
	rm -f $(CMD_TARGET)

