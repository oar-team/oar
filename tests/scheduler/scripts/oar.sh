#!/bin/bash
# $Id$
# Function set to handle oar setup within tests

BUILDDIR=${BUILDDIR:-build}
DATADIR=${DATADIR:-data}

oar_copy_config() {
	local FILE=${1:-oar.conf}
	if [ -r "$DATADIR/${BASEPREFIX}_$FILE" ]; then
		debug "Copying OAR config file from $FILE"
		mkdir -p $BUILDDIR/etc/oar
		cp $DATADIR/${BASEPREFIX}_$FILE $BUILDDIR/etc/oar/oar.conf
		debug "done"	
	else
		echo "Can't read file: $FILE"
		exit 1
	fi
}

oar_source_config() {
	debug "Sourcing OAR config"
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
		OARCONFFILE=$BUILDDIR/etc/oar/oar.conf OARDIR=$BUILDDIR/usr/local/oar ./oar_meta_sched 1>&2
	)
	debug "done"
}
