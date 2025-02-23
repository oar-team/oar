MODULE=man

MAN1DIR_FILES=$(wildcard sources/core/man/man1/*.pod) $(wildcard sources/core/man/man1/*.pod.in)
MAN8DIR_FILES=$(wildcard sources/core/man/man8/*.pod) $(wildcard sources/core/man/man8/*.pod.in)

include Makefiles/shared/shared.mk

clean: clean_shared

build: build_shared

.PHONY: install setup uninstall build clean
