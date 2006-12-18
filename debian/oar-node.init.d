#! /bin/sh
#
# skeleton	example file to build /etc/init.d/ scripts.
#		This file should be used to construct scripts for /etc/init.d.
#
#		Written by Miquel van Smoorenburg <miquels@cistron.nl>.
#		Modified for Debian 
#		by Ian Murdock <imurdock@gnu.ai.mit.edu>.
#
# Version:	@(#)skeleton  1.9  26-Feb-2001  miquels@cistron.nl
#

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
NAME=oar-node
DESC=oar-node
OAR_NODE_NAME=$(hostname -f)
OARSERVER=""

# Include oar defaults if available
if [ -f /etc/default/oar-node ] ; then
	. /etc/default/oar-node
fi

test -n "$OARSERVER" || exit 0
test -n "$OAR_NODE_NAME" || exit 0

set -e

case "$1" in
  start)
	echo -n "Starting $DESC: "
	sudo -u oar /usr/bin/ssh $OARSERVER "oarnodesetting -s Alive -h $OAR_NODE_NAME"
    echo "$NAME."
	;;
  stop)
	echo -n "Stopping $DESC: "
	sudo -u oar /usr/bin/ssh $OARSERVER "oarnodesetting -s Absent -h $OAR_NODE_NAME"
	echo "$NAME."
	;;
  reload|force-reload|restart)
        $0 stop
        sleep 1
        $0 start
        ;;
  *)
	N=/etc/init.d/$NAME
	echo "Usage: $N {start|restart|stop}" >&2
	exit 1
	;;
esac

exit 0
