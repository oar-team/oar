#!/bin/bash
# function set for the test base setup

DEBUG=${DEBUG:-0}
BUILDDIR=${BUILDDIR:-build}

debug() {
	if [ $DEBUG -gt 0 ]; then
		echo $* 1>&2
	fi
}

test_print_ok() {
	echo OK: $*
}

test_print_ko() {
	echo KO: $*
}

test_exit_status () {
	local TXT=$1
	shift
	if eval $*; then
		test_print_ok $TXT
	else
		test_print_ko $TXT
	fi
}

test_prepare() {
	debug "Create base directories in the build directory"
	mkdir -p $BUILDDIR/etc
	mkdir -p $BUILDDIR/tmp
	mkdir -p $BUILDDIR/usr/local/lib
	mkdir -p $BUILDDIR/usr/local/bin
	mkdir -p $BUILDDIR/var/lib
	mkdir -p $BUILDDIR/var/run
	debug "done"
}

test_cleanup() {
	debug "Clean-up build directory"
	rm $BUILDDIR/* -rf
	debug "done"
}
