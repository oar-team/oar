#! /bin/sh

### BEGIN INIT INFO
# Provides:         oar-server
# Required-Start:   $network $local_fs $remote_fs
# Required-Stop:
# Default-Start:    2 3 4 5
# Default-Stop:     0 1 6
# Short-Description:    OAR server init script
### END INIT INFO

# $Id$

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/sbin/Almighty
NAME=oar-server
DESC=oar-server

test -x $DAEMON || exit 0

# Include oar defaults if available
if [ -f /etc/default/oar-server ] ; then
	. /etc/default/oar-server
fi

set -e

case "$1" in
  start)
	echo -n "Starting $DESC: "
	start-stop-daemon --start --quiet --pidfile /var/run/$NAME.pid \
		--make-pidfile --background --exec $DAEMON -- $DAEMON_OPTS
	echo "$NAME."
	;;
  stop)
	echo -n "Stopping $DESC: "
	start-stop-daemon --stop --quiet --pidfile /var/run/$NAME.pid && \
		rm -f /var/run/$NAME.pid
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
