MODULE=man

MANDIR_FILES=$(wildcard sources/core/man/man1/*.pod) $(wildcard sources/core/man/man1/*.pod.in)

include Makefiles/shared/shared.mk

clean: clean_shared

build: build_shared

.PHONY: install setup uninstall build clean
