#!/bin/bash

usage() {
	echo "Usage: `basename $0` [-e <method>] <node file>"
	echo "Where method := { rsh | ssh | rshp/rsh | rshp/ssh }"
	exit 1
}

# Home brewed getopt
OPT=$1
shift
while [ -n "$OPT" ]; do
	case $OPT in
		-e)
			[ -z "$METHOD" ] || usage
			METHOD=$1
			shift
		;;
		-H)
			[ -z "$OARHOME" ] || usage
			OARHOME=$1
			shift
		;;
		-C)
			[ -z "$OARCONF" ] || usage
			OARCONF=$1
			shift
		;;
		-h)
			usage
		;;
		*)
			[ -z $NODE_FILE ] || usage
			NODE_FILE=$OPT
		;;
	esac
	OPT=$1
	shift
done

# Is oar home ok ?
[ -n "$OARHOME" ] || OARHOME=/var/lib/oar
[ -d "$OARHOME" -a -r "$OARHOME" ] || ( echo "Error: oar home not readable ($OARHOME)"; usage )

# Is oar configuration ok ?
[ -n "$OARCONF" ] || OARCONF=/etc/oar.conf
[ -r "$OARCONF" ] || ( echo "Error: oar configuration file not readable ($OARCONF)"; usage )

# Is node file readable ?
[ -n "$NODE_FILE" ] || usage
[ -r "$NODE_FILE" ] || ( echo "Error: Can't read node file: $NODE_FILE"; usage )

# Is deployment method ok ? Defaulting to ssh
case "$METHOD" in
	rsh|ssh|rshp/rsh|rshp/ssh)
	;;
	*)
	[ -n "$METHOD" ] && echo "Warning: unknown method: $METHOD, defaulting to ssh."
	METHOD="ssh"
esac


# The real stuff: 
# deploy oar .ssh directory and oar.conf file using piped tar
case "$METHOD" in
	rsh)
		for n in `cat $NODE_FILE`; do
			tar c $OARHOME/.ssh $OARCONF | rsh $n tar x -C /
			oarnodesetting -h $n -s Alive
		done
	;;
	ssh)
		for n in `cat $NODE_FILE`; do
			tar c $OARHOME/.ssh $OARCONF | ssh -x -o StrictHostKeyChecking=no $n tar x -C /
			oarnodesetting -h $n -s Alive
		done
	;;
	rshp/rsh)
		tar c $OARHOME/.ssh $OARCONF | rshp -d -c rsh -f $NODE_FILE -- tar x -C /
		for n in `cat $NODE_FILE`; do
			oarnodesetting -h $n -s Alive
		done
	;;
	rshp/ssh)
		tar c $OARHOME/.ssh $OARCONF | rshp -d -c ssh -f $NODE_FILE -- tar x -C /
		for n in `cat $NODE_FILE`; do
			oarnodesetting -h $n -s Alive
		done
	;;
esac
