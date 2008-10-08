#!/bin/bash
# $Id$
# Function set to handle oar setup within tests

DEBUG=${DEBUG:-0}
BUILDDIR=${BUILDDIR:-build}
DATADIR=${DATADIR:-data}

debug() {
	if [ $DEBUG -gt 0 ]; then
		echo $1
	fi
}

oar_config() {
	debug "Copying config file"
	mkdir -p $BUILDDIR/etc/oar
	cp $DATADIR/etc/oar/oar.conf $BUILDDIR/etc/oar/oar.conf
	. $BUILDDIR/etc/oar/oar.conf
	debug "done"
}

oar_install() {
	debug "Installing OAR in the build dir"
	(
		cd $SRCDIR
		make server libs \
		OARCONFDIR=$BUILDDIR/etc/oar \
		OARUSER=$(id -un) \
		OAROWNER=$(id -un) \
		OAROWNERGROUP=$(id -gn) \
		PREFIX=$BUILDDIR/usr/local > /dev/null
	)
	debug "done"
}

oar_run_scheduler() {
	debug "Starting OAR Meta-Scheduler"
	( 
		cd $BUILDDIR/usr/local/oar
		OARCONFFILE=$BUILDDIR/etc/oar/oar.conf OARDIR=$BUILDDIR/usr/local/oar ./oar_meta_sched
	)
	debug "done"
}
