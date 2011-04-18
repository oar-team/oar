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


clean:
	# Nothing to do

build:
	# Noting to do


install: 
ifeq "$(CMD_TARGET)" ""
	echo "no CMD_TARGET given. Fail !"
	exit 1
endif
	install -m $(CMD_RIGHTS) tools/oardo $(CMD_TARGET)
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
            s#Oarconffile = .*#Oarconffile = '$(OARCONFFILE)'\;#;;\
            s#Oarxauthlocation = .*#Oarxauthlocation = '$(OARXAUTHLOCATION)'\;#;;\
            s#Cmd_wrapper = .*#Cmd_wrapper = '$(CMD_WRAPPER)'\;#;;\
            " $(CMD_TARGET)
	chown $(CMD_OWNER).$(CMD_GROUP) $(CMD_TARGET)
	chmod $(CMD_RIGHTS) $(CMD_TARGET)

uninstall:
ifeq "$(CMD_TARGET)" ""
	echo "no CMD_TARGET given. Fail !"
	exit 1
endif
	rm -f $(CMD_TARGET)

