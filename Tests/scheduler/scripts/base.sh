#!/bin/bash
# $Id$
# function set for the test base setup

DEBUG=${DEBUG:-0}
BUILDDIR=${BUILDDIR:-build}

debug() {
	if [ $DEBUG -gt 0 ]; then
		echo $1
	fi
}

base_prepare() {
	debug "Create base directories in the build directory"
	mkdir -p $BUILDDIR/etc
	mkdir -p $BUILDDIR/tmp
	mkdir -p $BUILDDIR/usr/local/lib
	mkdir -p $BUILDDIR/usr/local/bin
	mkdir -p $BUILDDIR/var/lib
	mkdir -p $BUILDDIR/var/run
	debug "done"
}

base_cleanup() {
	debug "Clean-up build directory"
	rm $BUILDDIR/* -rf
	debug "done"
}
