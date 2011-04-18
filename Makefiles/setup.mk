#! /usr/bin/make

include Makefiles/shared/shared.mk

setup:
	@chsh -s $(OARDIR)/oarsh_shell $(OAROWNER) >/dev/null 2>&1

